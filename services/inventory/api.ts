import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import {
  AddBatchRequest,
  BatchWithStats,
  ConsumeInventoryRequest,
  ConsumeInventoryResponse,
  GetInventoryBatchRequest,
  InventoryListResponse,
  InventoryResponse,
  InventoryTotalRequest,
  InventoryTotalResponse,
  ListInventoryRequest,
  LowStockRequest,
  LowStockResponse,
} from "./types";
import {
  DEFAULT_LOW_STOCK_THRESHOLD,
  INGREDIENTS_TABLE,
  INVENTORY_MOVEMENTS_TABLE,
  INVENTORY_TABLE,
  InventoryBatchRow,
  attachBatchStats,
  buildBatchInsertPayload,
  buildLowStockSnapshots,
  buildMovementPayload,
  calculateTotalsMap,
  ensurePositiveNumber,
  mapBatchRow,
  sanitizeString,
  sumAvailableQuantity,
  validateBatchCreate,
} from "./utils";

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

const ensureIngredientOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientId: string
): Promise<void> => {
  const { data, error } = await client
    .from(INGREDIENTS_TABLE)
    .select("id")
    .eq("business_owner_id", ownerId)
    .eq("id", ingredientId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Ingredient ${ingredientId} not found`);
  }

  if (!data) {
    throw APIError.notFound(`Ingredient ${ingredientId} not found`);
  }
};

const fetchBatchById = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<InventoryBatchRow> => {
  const { data, error } = await client
    .from(INVENTORY_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .single();

  if (error) {
    translateDbError(error, `Inventory batch ${id} not found`);
  }

  const row = data as InventoryBatchRow | null;
  if (!row) {
    throw APIError.notFound(`Inventory batch ${id} not found`);
  }

  return row;
};

const fetchBatchesForProduct = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<InventoryBatchRow[]> => {
  const { data, error } = await client
    .from(INVENTORY_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("product_id", productId)
    .order("created_at", { ascending: true });

  if (error) {
    translateDbError(error);
  }

  return (data ?? []) as InventoryBatchRow[];
};

const attachStatsForRow = (
  row: InventoryBatchRow,
  totalsMap: Map<string, number>
): BatchWithStats => attachBatchStats(row, totalsMap, DEFAULT_LOW_STOCK_THRESHOLD);

const logInventoryMovement = async (
  client: SupabaseClient,
  params: {
    ownerId: string;
    batchId: string | null;
    productId: string;
    type: "in" | "out";
    quantity: number;
    note?: string;
  }
) => {
  const { error } = await client
    .from(INVENTORY_MOVEMENTS_TABLE)
    .insert(buildMovementPayload(params));

  if (error) {
    translateDbError(error);
  }
};

const consumeProductStock = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string,
  quantity: number,
  note?: string
): Promise<{
  movements: Array<{
    batchId: string;
    consumedQuantity: number;
    remainingBatchQuantity: number;
  }>;
  remainingQuantity: number;
}> => {
  const batches = await fetchBatchesForProduct(client, ownerId, productId);
  if (!batches.length) {
    throw APIError.failedPrecondition(`No inventory for ${productId}`);
  }

  let remaining = quantity;
  const updates: Array<{
    id: string;
    newAvailable: number;
    consumed: number;
  }> = [];

  for (const row of batches) {
    if (remaining <= 0) break;
    const available = Number(row.available_quantity ?? 0);
    if (available <= 0) continue;
    const deduction = Math.min(available, remaining);
    remaining -= deduction;
    updates.push({
      id: row.id,
      newAvailable: available - deduction,
      consumed: deduction,
    });
  }

  if (remaining > 0) {
    throw APIError.resourceExhausted(
      `Insufficient stock for ${productId}; short by ${remaining}`
    );
  }

  const timestamp = new Date().toISOString();
  for (const update of updates) {
    const { error } = await client
      .from(INVENTORY_TABLE)
      .update({
        available_quantity: update.newAvailable,
        updated_at: timestamp,
      })
      .eq("business_owner_id", ownerId)
      .eq("id", update.id);

    await logInventoryMovement(client, {
      ownerId,
      batchId: update.id,
      productId,
      type: "out",
      quantity: update.consumed,
      note,
    });

    if (error) {
      translateDbError(error);
    }
  }

  const latestRows = await fetchBatchesForProduct(client, ownerId, productId);
  return {
    movements: updates.map((u) => ({
      batchId: u.id,
      consumedQuantity: u.consumed,
      remainingBatchQuantity: u.newAvailable,
    })),
    remainingQuantity: sumAvailableQuantity(latestRows),
  };
};

export const addBatch = api<AddBatchRequest, InventoryResponse>(
  {
    method: "POST",
    path: "/inventory/batch/add",
  },
  async ({ authorization, batch }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const payload = validateBatchCreate(batch);

    await ensureIngredientOwnership(client, ownerId, payload.productId);

    const { data, error } = await client
      .from(INVENTORY_TABLE)
      .insert(buildBatchInsertPayload(payload, ownerId))
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const createdRow = data as InventoryBatchRow | null;
    if (!createdRow) {
      throw APIError.internal("Unable to create batch");
    }

    const rowsForProduct = await fetchBatchesForProduct(
      client,
      ownerId,
      payload.productId
    );
    const totalsMap = calculateTotalsMap(rowsForProduct);

    await logInventoryMovement(client, {
      ownerId,
      batchId: createdRow.id,
      productId: createdRow.product_id,
      type: "in",
      quantity: payload.quantity,
      note: payload.batchCode ?? undefined,
    });

    return {
      success: true,
      data: {
        batch: attachStatsForRow(createdRow, totalsMap),
      },
    };
  }
);

export const consumeInventory = api<
  ConsumeInventoryRequest,
  ConsumeInventoryResponse
>(
  {
    method: "POST",
    path: "/inventory/batch/consume",
  },
  async ({ authorization, productId, quantity, reason }) => {
    const trimmedProductId = sanitizeString(productId);
    if (!trimmedProductId) {
      throw APIError.invalidArgument("productId is required");
    }

    const normalizedQuantity = ensurePositiveNumber(quantity, "quantity");
    const { client, ownerId } = resolveAuthContext(authorization);

    const { movements, remainingQuantity } = await consumeProductStock(
      client,
      ownerId,
      trimmedProductId,
      normalizedQuantity,
      reason
    );

    return {
      success: true,
      data: {
        productId: trimmedProductId,
        consumedQuantity: normalizedQuantity,
        remainingQuantity,
        movements,
      },
    };
  }
);

export const listInventoryBatches = api<
  ListInventoryRequest,
  InventoryListResponse
>(
  {
    method: "GET",
    path: "/inventory/batch/list",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(INVENTORY_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("created_at", { ascending: false });

    if (error) {
      translateDbError(error);
    }

    const rows = (data ?? []) as InventoryBatchRow[];
    const totalsMap = calculateTotalsMap(rows);
    const batches = rows.map((row) => attachStatsForRow(row, totalsMap));

    return { success: true, data: { batches } };
  }
);

export const getInventoryBatch = api<
  GetInventoryBatchRequest,
  InventoryResponse
>(
  {
    method: "GET",
    path: "/inventory/batch/:id",
  },
  async ({ authorization, id }) => {
    const sanitizedId = sanitizeString(id);
    if (!sanitizedId) {
      throw APIError.invalidArgument("id is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    const row = await fetchBatchById(client, ownerId, sanitizedId);

    const productRows = await fetchBatchesForProduct(
      client,
      ownerId,
      row.product_id
    );
    const totalsMap = calculateTotalsMap(productRows);

    return {
      success: true,
      data: {
        batch: attachStatsForRow(row, totalsMap),
      },
    };
  }
);

export const lowStockReport = api<LowStockRequest, LowStockResponse>(
  {
    method: "GET",
    path: "/inventory/low-stock",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(INVENTORY_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId);

    if (error) {
      translateDbError(error);
    }

    const batches = ((data ?? []) as InventoryBatchRow[]).map(mapBatchRow);
    // TODO(p2): integrate with notification service to alert owners when low stock items are detected.
    return {
      success: true,
      data: {
        items: buildLowStockSnapshots(batches, DEFAULT_LOW_STOCK_THRESHOLD),
      },
    };
  }
);

export const getInventoryTotal = api<
  InventoryTotalRequest,
  InventoryTotalResponse
>(
  {
    method: "GET",
    path: "/inventory/total/:productId",
  },
  async ({ authorization, productId }) => {
    const trimmed = sanitizeString(productId);
    if (!trimmed) {
      throw APIError.invalidArgument("productId is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    await ensureIngredientOwnership(client, ownerId, trimmed);

    const batches = await fetchBatchesForProduct(client, ownerId, trimmed);

    return {
      success: true,
      data: {
        productId: trimmed,
        totalStock: sumAvailableQuantity(batches),
      },
    };
  }
);