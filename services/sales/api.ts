import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";
import { Topic } from "encore.dev/pubsub";

import { resolveAuthContext } from "../../pkg/auth";
import {
  CreateSaleRequest,
  GetSaleRequest,
  ProductInventoryMovement,
  SaleCreatedEvent,
  SaleListRequest,
  SaleListResponse,
  SaleResponse,
  SalesSummaryRequest,
  SalesSummaryResponse,
} from "./types";
import {
  FINISHED_PRODUCT_BATCHES_TABLE,
  INVENTORY_MOVEMENTS_TABLE,
  PRODUCTS_TABLE,
  SALES_ITEMS_TABLE,
  SALES_TABLE,
  SaleRow,
  buildSaleInsertPayload,
  buildSaleItemsPayload,
  computeSaleTotals,
  mapSaleRow,
  normalizeSalePayload,
} from "./utils";

export type { SaleCreatedEvent } from "./types";

export const saleCreatedTopic = new Topic<SaleCreatedEvent>("sales-created", {
  deliveryGuarantee: "at-least-once",
});

interface FinishedBatchRow {
  id: string;
  business_owner_id: string;
  product_id: string;
  available_quantity: number;
  cost_per_unit: number;
  created_at: string;
  updated_at: string;
}

interface DbError {
  code?: string;
  message?: string;
  details?: string | null;
}

const translateDbError = (error: DbError | null | undefined, notFound?: string): never => {
  if (error?.code === "PGRST116" && notFound) {
    throw APIError.notFound(notFound);
  }
  throw APIError.internal(error?.message ?? "Unexpected database error");
};

const ensureProductOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<void> => {
  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id")
    .eq("business_owner_id", ownerId)
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Product ${productId} not found`);
  }

  if (!data) {
    throw APIError.notFound(`Product ${productId} not found`);
  }
};

const fetchProductBatches = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<FinishedBatchRow[]> => {
  const { data, error } = await client
    .from(FINISHED_PRODUCT_BATCHES_TABLE)
    .select("id, business_owner_id, product_id, available_quantity, cost_per_unit, created_at, updated_at")
    .eq("business_owner_id", ownerId)
    .eq("product_id", productId)
    .order("created_at", { ascending: true });

  if (error) {
    translateDbError(error);
  }

  return (data ?? []) as FinishedBatchRow[];
};

interface BatchConsumption {
  batchId: string;
  quantity: number;
  unitCost: number;
  remainingBatchQuantity: number;
}

const consumeFinishedProduct = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string,
  quantity: number
): Promise<BatchConsumption[]> => {
  const batches = await fetchProductBatches(client, ownerId, productId);
  if (!batches.length) {
    throw APIError.failedPrecondition(`No finished goods inventory for ${productId}`);
  }

  let remaining = quantity;
  const updates: Array<{
    id: string;
    newAvailable: number;
    consumed: number;
    unitCost: number;
  }> = [];

  for (const batch of batches) {
    if (remaining <= 0) break;
    const available = Number(batch.available_quantity ?? 0);
    if (available <= 0) continue;
    const deduction = Math.min(available, remaining);
    remaining -= deduction;
    updates.push({
      id: batch.id,
      newAvailable: available - deduction,
      consumed: deduction,
      unitCost: Number(batch.cost_per_unit ?? 0),
    });
  }

  if (remaining > 0) {
    throw APIError.resourceExhausted(
      `Insufficient finished goods inventory for ${productId}; short by ${remaining}`
    );
  }

  const timestamp = new Date().toISOString();
  for (const update of updates) {
    const { error } = await client
      .from(FINISHED_PRODUCT_BATCHES_TABLE)
      .update({
        available_quantity: update.newAvailable,
        updated_at: timestamp,
      })
      .eq("business_owner_id", ownerId)
      .eq("id", update.id);

    if (error) {
      translateDbError(error);
    }
  }

  return updates.map((update) => ({
    batchId: update.id,
    quantity: update.consumed,
    unitCost: update.unitCost,
    remainingBatchQuantity: update.newAvailable,
  }));
};

const recordInventoryMovements = async (
  client: SupabaseClient,
  ownerId: string,
  productMovements: ProductInventoryMovement[],
  saleId: string
) => {
  const rows = productMovements.flatMap((movement) =>
    movement.movements.map((batch) => ({
      business_owner_id: ownerId,
      batch_id: null,
      product_id: movement.productId,
      type: "out",
      qty: batch.quantity,
      note: `sale:${saleId}|batch:${batch.batchId}`,
    }))
  );

  if (!rows.length) {
    return;
  }

  const { error } = await client.from(INVENTORY_MOVEMENTS_TABLE).insert(rows);
  if (error) {
    translateDbError(error);
  }
};

const fetchSaleById = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<SaleRow> => {
  const { data, error } = await client
    .from(SALES_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .single();

  if (error) {
    translateDbError(error, `Sale ${id} not found`);
  }

  const row = data as SaleRow | null;
  if (!row) {
    throw APIError.notFound(`Sale ${id} not found`);
  }

  return row;
};

const groupSalesByPeriod = (
  rows: SaleRow[],
  formatter: (date: Date) => string
) => {
  const groups = new Map<
    string,
    { total: number; cogs: number; profit: number }
  >();

  for (const row of rows) {
    const bucket = formatter(new Date(row.occurred_at));
    const entry = groups.get(bucket) ?? { total: 0, cogs: 0, profit: 0 };
    entry.total += Number(row.total ?? 0);
    entry.cogs += Number(row.cogs ?? 0);
    entry.profit += Number(row.profit ?? 0);
    groups.set(bucket, entry);
  }

  return Array.from(groups.entries())
    .map(([period, stats]) => ({
      period,
      total: stats.total,
      cogs: stats.cogs,
      profit: stats.profit,
    }))
    .sort((a, b) => (a.period < b.period ? 1 : -1));
};

const fetchSalesSince = async (
  client: SupabaseClient,
  ownerId: string,
  since: Date
): Promise<SaleRow[]> => {
  const { data, error } = await client
    .from(SALES_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .gte("occurred_at", since.toISOString());

  if (error) {
    translateDbError(error);
  }

  return (data ?? []) as SaleRow[];
};

export const createSale = api<CreateSaleRequest, SaleResponse>(
  {
    method: "POST",
    path: "/sales/create",
  },
  async ({ authorization, sale }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = normalizeSalePayload(sale);
    const totals = computeSaleTotals(
      normalized.lineItems,
      normalized.tax,
      normalized.discount
    );

    const lineItemsWithCost: Array<{
      productId: string;
      quantity: number;
      unitPrice: number;
      costOfGoods: number;
    }> = [];
    const productMovements: ProductInventoryMovement[] = [];
    let totalCogs = 0;

    for (const item of normalized.lineItems) {
      await ensureProductOwnership(client, ownerId, item.productId);
      const consumptions = await consumeFinishedProduct(
        client,
        ownerId,
        item.productId,
        item.quantity
      );

      const lineCost = consumptions.reduce(
        (sum, consumption) => sum + consumption.quantity * consumption.unitCost,
        0
      );
      totalCogs += lineCost;

      lineItemsWithCost.push({
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        costOfGoods: lineCost,
      });

      productMovements.push({
        productId: item.productId,
        movements: consumptions.map((consumption) => ({
          batchId: consumption.batchId,
          quantity: consumption.quantity,
          unitCost: consumption.unitCost,
          remainingBatchQuantity: consumption.remainingBatchQuantity,
        })),
      });
    }

    const profit = totals.total - totalCogs;

    const { data, error } = await client
      .from(SALES_TABLE)
      .insert(
        buildSaleInsertPayload(ownerId, normalized, totals, totalCogs, profit)
      )
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const saleRow = data as SaleRow | null;
    if (!saleRow) {
      throw APIError.internal("Unable to create sale");
    }

    const saleItemsPayload = buildSaleItemsPayload(
      ownerId,
      saleRow.id,
      lineItemsWithCost
    );
    const { error: itemsError } = await client
      .from(SALES_ITEMS_TABLE)
      .insert(saleItemsPayload);
    if (itemsError) {
      translateDbError(itemsError);
    }

    await recordInventoryMovements(client, ownerId, productMovements, saleRow.id);

    await saleCreatedTopic.publish({
      saleId: saleRow.id,
      customerId: normalized.customerId,
      lineItems: lineItemsWithCost,
      inventoryMovements: productMovements,
    });

    return { sale: mapSaleRow(saleRow) };
  }
);

export const listSales = api<SaleListRequest, SaleListResponse>(
  {
    method: "GET",
    path: "/sales/list",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(SALES_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("occurred_at", { ascending: false })
      .limit(100);

    if (error) {
      translateDbError(error);
    }

    const rows = (data ?? []) as SaleRow[];
    return { sales: rows.map(mapSaleRow) };
  }
);

export const getSale = api<GetSaleRequest, SaleResponse>(
  {
    method: "GET",
    path: "/sales/:id",
  },
  async ({ authorization, id }) => {
    const sanitizedId = id.trim();
    if (!sanitizedId) {
      throw APIError.invalidArgument("id is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    const row = await fetchSaleById(client, ownerId, sanitizedId);
    return { sale: mapSaleRow(row) };
  }
);

export const getDailySales = api<SalesSummaryRequest, SalesSummaryResponse>(
  {
    method: "GET",
    path: "/sales/daily",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const since = new Date();
    since.setDate(since.getDate() - 30);
    const rows = await fetchSalesSince(client, ownerId, since);
    const entries = groupSalesByPeriod(rows, (date) =>
      date.toISOString().slice(0, 10)
    );
    return { entries };
  }
);

export const getMonthlySales = api<SalesSummaryRequest, SalesSummaryResponse>(
  {
    method: "GET",
    path: "/sales/monthly",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const since = new Date();
    since.setMonth(since.getMonth() - 11);
    const rows = await fetchSalesSince(client, ownerId, since);
    const entries = groupSalesByPeriod(rows, (date) => {
      const year = date.getUTCFullYear();
      const month = (date.getUTCMonth() + 1).toString().padStart(2, "0");
      return `${year}-${month}`;
    });
    return { entries };
  }
);
