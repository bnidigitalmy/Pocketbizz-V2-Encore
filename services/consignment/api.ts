import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import {
  consignmentClaimGeneratedTopic,
  consignmentSessionCreatedTopic,
} from "./events";
import { buildClaimForThermal, buildInvoiceForThermal } from "./print";
import {
  ClaimPrintRequest,
  ClaimPrintResponse,
  CreateConsignmentSessionRequest,
  CreateConsignmentSessionResponse,
  GenerateClaimRequest,
  GenerateClaimResponse,
  GetClaimRequest,
  GetClaimResponse,
  GetConsignmentSessionRequest,
  GetConsignmentSessionResponse,
  HistoryRequest,
  HistoryResponse,
  InvoiceRequest,
  InvoiceResponse,
  ListConsignmentSessionsRequest,
  ListConsignmentSessionsResponse,
  ReconcileConsignmentRequest,
  ReconcileConsignmentResponse,
} from "./types";
import {
  CONSIGNMENT_CLAIMS_TABLE,
  CONSIGNMENT_HISTORY_TABLE,
  CONSIGNMENT_ITEMS_TABLE,
  CONSIGNMENT_SESSIONS_TABLE,
  ConsignmentClaimRow,
  ConsignmentItemRow,
  ConsignmentSessionRow,
  HistoryRow,
  ProductRow,
  ensureNonNegativeNumber,
  ensurePositiveNumber,
  ensureVendorOwnership,
  fetchProductsMap,
  generateConsignmentReference,
  loadClaimById,
  loadSessionDetail,
  logHistoryEvent,
  mapClaimRow,
  mapHistoryRow,
  mapSessionRow,
  recalcSessionTotals,
  roundCurrency,
  sanitizeString,
  translateDbError,
} from "./utils";

interface NormalizedItemInput {
  productId: string;
  quantity: number;
  commissionType: "percent" | "fixed";
  commissionValue: number;
}

interface NormalizedUpdateInput {
  itemId: string;
  qtySold: number;
  qtyReturned: number;
}

const normalizeItems = (items: CreateConsignmentSessionRequest["items"]): NormalizedItemInput[] => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("At least one item is required");
  }

  return items.map((item, index) => {
    const productId = sanitizeString(item.productId);
    if (!productId) {
      throw APIError.invalidArgument(`items[${index}].productId is required`);
    }

    const quantity = ensurePositiveNumber(item.quantity, `items[${index}].quantity`);
    const commissionType =
      item.commissionType === "percent" || item.commissionType === "fixed"
        ? item.commissionType
        : undefined;

    if (!commissionType) {
      throw APIError.invalidArgument(`items[${index}].commissionType must be percent or fixed`);
    }

    const commissionValue = ensureNonNegativeNumber(
      item.commissionValue,
      `items[${index}].commissionValue`
    );

    if (commissionType === "percent" && commissionValue > 100) {
      throw APIError.invalidArgument(`items[${index}].commissionValue cannot exceed 100%`);
    }

    return {
      productId,
      quantity,
      commissionType,
      commissionValue,
    };
  });
};

const normalizeUpdates = (
  updates: ReconcileConsignmentRequest["updates"]
): NormalizedUpdateInput[] => {
  if (!Array.isArray(updates) || !updates.length) {
    throw APIError.invalidArgument("At least one update entry is required");
  }

  return updates.map((update, index) => {
    const itemId = sanitizeString(update.itemId);
    if (!itemId) {
      throw APIError.invalidArgument(`updates[${index}].itemId is required`);
    }

    return {
      itemId,
      qtySold: ensureNonNegativeNumber(update.qtySold, `updates[${index}].qtySold`),
      qtyReturned: ensureNonNegativeNumber(update.qtyReturned, `updates[${index}].qtyReturned`),
    };
  });
};

const fetchSessionRow = async (
  client: SupabaseClient,
  ownerId: string,
  sessionId: string
): Promise<ConsignmentSessionRow> => {
  const { data, error } = await client
    .from(CONSIGNMENT_SESSIONS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", sessionId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Consignment session ${sessionId} not found`);
  }
  if (!data) {
    throw APIError.notFound(`Consignment session ${sessionId} not found`);
  }
  return data as ConsignmentSessionRow;
};

const computeCommission = (
  product: ProductRow,
  item: NormalizedItemInput
): {
  salePrice: number;
  commissionPerUnit: number;
  unitPrice: number;
} => {
  const salePrice = Number(product.sale_price ?? 0);
  if (salePrice <= 0) {
    throw APIError.failedPrecondition(
      `Product ${product.id} is missing a valid sale_price for consignments`
    );
  }

  const commissionPerUnit =
    item.commissionType === "percent"
      ? roundCurrency((salePrice * item.commissionValue) / 100)
      : roundCurrency(item.commissionValue);

  if (commissionPerUnit > salePrice) {
    throw APIError.invalidArgument(
      `Commission exceeds sale price for product ${product.id}`
    );
  }

  const unitPrice = roundCurrency(salePrice - commissionPerUnit);
  return { salePrice, commissionPerUnit, unitPrice };
};

const fetchItemsForSession = async (
  client: SupabaseClient,
  ownerId: string,
  sessionId: string,
  itemIds: string[]
): Promise<Record<string, ConsignmentItemRow>> => {
  const query = client
    .from(CONSIGNMENT_ITEMS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("session_id", sessionId);

  if (itemIds.length) {
    query.in("id", itemIds);
  }

  const { data, error } = await query;
  if (error) {
    translateDbError(error);
  }

  const rows = (data ?? []) as ConsignmentItemRow[];
  return rows.reduce<Record<string, ConsignmentItemRow>>((acc, row) => {
    acc[row.id] = row;
    return acc;
  }, {});
};

const ensureClaimableTotals = (items: ConsignmentItemRow[]): {
  totalSoldValue: number;
  totalCommission: number;
  totalPayout: number;
} => {
  const totals = items.reduce(
    (acc, row) => {
      const qtySold = Number(row.qty_sold ?? 0);
      if (qtySold <= 0) {
        return acc;
      }

      const gross = qtySold * Number(row.list_price ?? 0);
      const commission = qtySold * Number(row.commission_amount ?? 0);
      acc.sold += gross;
      acc.commission += commission;
      return acc;
    },
    { sold: 0, commission: 0 }
  );

  if (totals.sold <= 0) {
    throw APIError.failedPrecondition("No sold quantity available for claim generation");
  }

  return {
    totalSoldValue: roundCurrency(totals.sold),
    totalCommission: roundCurrency(totals.commission),
    totalPayout: roundCurrency(totals.sold - totals.commission),
  };
};

export const createConsignmentSession = api<
  CreateConsignmentSessionRequest,
  CreateConsignmentSessionResponse
>(
  { method: "POST", path: "/consignment/sessions" },
  async ({ authorization, vendorId, note, items }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedVendorId = sanitizeString(vendorId);
    if (!normalizedVendorId) {
      throw APIError.invalidArgument("vendorId is required");
    }

    const normalizedItems = normalizeItems(items);
    const vendor = await ensureVendorOwnership(client, ownerId, normalizedVendorId);
    const productsMap = await fetchProductsMap(
      client,
      ownerId,
      normalizedItems.map((item) => item.productId)
    );

    const missingProduct = normalizedItems.find((item) => !productsMap[item.productId]);
    if (missingProduct) {
      throw APIError.notFound(`Product ${missingProduct.productId} not found`);
    }

    const reference = generateConsignmentReference();
    const timestamp = new Date().toISOString();

    const { data: sessionData, error: sessionError } = await client
      .from(CONSIGNMENT_SESSIONS_TABLE)
      .insert({
        business_owner_id: ownerId,
        vendor_id: vendor.id,
        reference,
        status: "open",
        note: sanitizeString(note) ?? null,
      })
      .select("*")
      .single();

    if (sessionError) {
      translateDbError(sessionError);
    }

    const sessionRow = sessionData as ConsignmentSessionRow;
    let totalItems = 0;
    let totalValue = 0;

    const preparedItems = normalizedItems.map((item) => {
      const product = productsMap[item.productId] as ProductRow;
      const { salePrice, commissionPerUnit, unitPrice } = computeCommission(product, item);
      const lineValue = roundCurrency(unitPrice * item.quantity);
      totalItems += item.quantity;
      totalValue += lineValue;

      return {
        business_owner_id: ownerId,
        session_id: sessionRow.id,
        product_id: item.productId,
        qty_sent: item.quantity,
        qty_sold: 0,
        qty_returned: 0,
        list_price: salePrice,
        unit_price: unitPrice,
        commission_type: item.commissionType,
        commission_rate: item.commissionType === "percent" ? item.commissionValue : null,
        commission_amount: commissionPerUnit,
        total_value: lineValue,
      };
    });

    const { error: itemsError } = await client.from(CONSIGNMENT_ITEMS_TABLE).insert(preparedItems);
    if (itemsError) {
      translateDbError(itemsError);
    }

    const { error: updateError } = await client
      .from(CONSIGNMENT_SESSIONS_TABLE)
      .update({
        total_items: Number(totalItems.toFixed(3)),
        total_value: roundCurrency(totalValue),
        updated_at: timestamp,
      })
      .eq("business_owner_id", ownerId)
      .eq("id", sessionRow.id);

    if (updateError) {
      translateDbError(updateError);
    }

    await logHistoryEvent(client, ownerId, sessionRow.id, "session_created", {
      totalItems,
      totalValue: roundCurrency(totalValue),
      itemsCount: normalizedItems.length,
    });

    await consignmentSessionCreatedTopic.publish({
      sessionId: sessionRow.id,
      ownerId,
      vendorId: vendor.id,
      reference,
    });

    const detail = await loadSessionDetail(client, ownerId, sessionRow.id);
    return { success: true, data: { session: detail } };
  }
);

export const listConsignmentSessions = api<
  ListConsignmentSessionsRequest,
  ListConsignmentSessionsResponse
>(
  { method: "GET", path: "/consignment/sessions" },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(CONSIGNMENT_SESSIONS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("created_at", { ascending: false });

    if (error) {
      translateDbError(error);
    }

    const rows = (data ?? []) as ConsignmentSessionRow[];
    return {
      success: true,
      data: { sessions: rows.map(mapSessionRow) },
    };
  }
);

export const getConsignmentSession = api<
  GetConsignmentSessionRequest,
  GetConsignmentSessionResponse
>(
  { method: "GET", path: "/consignment/sessions/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const sessionId = sanitizeString(id);
    if (!sessionId) {
      throw APIError.invalidArgument("id is required");
    }

    const detail = await loadSessionDetail(client, ownerId, sessionId);
    return { success: true, data: { session: detail } };
  }
);

export const reconcileConsignmentSession = api<
  ReconcileConsignmentRequest,
  ReconcileConsignmentResponse
>(
  { method: "POST", path: "/consignment/sessions/:sessionId/reconcile" },
  async ({ authorization, sessionId, updates }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedSessionId = sanitizeString(sessionId);
    if (!normalizedSessionId) {
      throw APIError.invalidArgument("sessionId is required");
    }

    const normalizedUpdates = normalizeUpdates(updates);
    await fetchSessionRow(client, ownerId, normalizedSessionId);

    const itemMap = await fetchItemsForSession(
      client,
      ownerId,
      normalizedSessionId,
      normalizedUpdates.map((update) => update.itemId)
    );

    const timestamp = new Date().toISOString();

    for (const update of normalizedUpdates) {
      const row = itemMap[update.itemId];
      if (!row) {
        throw APIError.notFound(`Consignment item ${update.itemId} not found`);
      }

      const maxAvailable = Number(row.qty_sent ?? 0);
      if (update.qtySold + update.qtyReturned > maxAvailable) {
        throw APIError.invalidArgument(
          `qtySold + qtyReturned exceeds qtySent for item ${update.itemId}`
        );
      }

      const { error } = await client
        .from(CONSIGNMENT_ITEMS_TABLE)
        .update({
          qty_sold: update.qtySold,
          qty_returned: update.qtyReturned,
          updated_at: timestamp,
        })
        .eq("business_owner_id", ownerId)
        .eq("id", update.itemId);

      if (error) {
        translateDbError(error);
      }
    }

    await recalcSessionTotals(client, ownerId, normalizedSessionId);
    await logHistoryEvent(client, ownerId, normalizedSessionId, "session_reconciled", {
      updates: normalizedUpdates.length,
    });

    const detail = await loadSessionDetail(client, ownerId, normalizedSessionId);
    return { success: true, data: { session: detail } };
  }
);

export const generateConsignmentClaim = api<
  GenerateClaimRequest,
  GenerateClaimResponse
>(
  { method: "POST", path: "/consignment/sessions/:sessionId/claim" },
  async ({ authorization, sessionId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedSessionId = sanitizeString(sessionId);
    if (!normalizedSessionId) {
      throw APIError.invalidArgument("sessionId is required");
    }

    const session = await fetchSessionRow(client, ownerId, normalizedSessionId);

    const { data: existingClaimData, error: existingClaimError } = await client
      .from(CONSIGNMENT_CLAIMS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .eq("session_id", normalizedSessionId)
      .order("created_at", { ascending: false })
      .limit(1);

    if (existingClaimError) {
      translateDbError(existingClaimError);
    }

    const existingRows = (existingClaimData ?? []) as ConsignmentClaimRow[];
    if (existingRows.length) {
      return {
        success: true,
        data: { claim: mapClaimRow(existingRows[0]) },
      };
    }

    const itemsMap = await fetchItemsForSession(client, ownerId, normalizedSessionId, []);
    const items = Object.values(itemsMap);
    const totals = ensureClaimableTotals(items);

    const { data: claimData, error: claimError } = await client
      .from(CONSIGNMENT_CLAIMS_TABLE)
      .insert({
        business_owner_id: ownerId,
        session_id: normalizedSessionId,
        total_sold_value: totals.totalSoldValue,
        total_commission: totals.totalCommission,
        total_payout: totals.totalPayout,
      })
      .select("*")
      .single();

    if (claimError) {
      translateDbError(claimError);
    }

    const claimRow = claimData as ConsignmentClaimRow;

    const { error: statusError } = await client
      .from(CONSIGNMENT_SESSIONS_TABLE)
      .update({
        status: "claimed",
        updated_at: new Date().toISOString(),
      })
      .eq("business_owner_id", ownerId)
      .eq("id", normalizedSessionId);

    if (statusError) {
      translateDbError(statusError);
    }

    await logHistoryEvent(client, ownerId, normalizedSessionId, "claim_generated", totals);
    await consignmentClaimGeneratedTopic.publish({
      claimId: claimRow.id,
      sessionId: normalizedSessionId,
      ownerId,
      totalPayout: totals.totalPayout,
    });

    return {
      success: true,
      data: { claim: mapClaimRow(claimRow) },
    };
  }
);

export const getConsignmentClaim = api<GetClaimRequest, GetClaimResponse>(
  { method: "GET", path: "/consignment/claims/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const claimId = sanitizeString(id);
    if (!claimId) {
      throw APIError.invalidArgument("id is required");
    }

    const row = await loadClaimById(client, ownerId, claimId);
    return { success: true, data: { claim: mapClaimRow(row) } };
  }
);

export const getConsignmentInvoice = api<InvoiceRequest, InvoiceResponse>(
  { method: "GET", path: "/consignment/sessions/:id/invoice" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const sessionId = sanitizeString(id);
    if (!sessionId) {
      throw APIError.invalidArgument("id is required");
    }

    const detail = await loadSessionDetail(client, ownerId, sessionId);
    const buffer = buildInvoiceForThermal(detail);
    return {
      success: true,
      data: { document: buffer.toString("base64") },
    };
  }
);

export const getClaimPrintDocument = api<ClaimPrintRequest, ClaimPrintResponse>(
  { method: "GET", path: "/consignment/claims/:id/print" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const claimId = sanitizeString(id);
    if (!claimId) {
      throw APIError.invalidArgument("id is required");
    }

    const claimRow = await loadClaimById(client, ownerId, claimId);
    const sessionDetail = await loadSessionDetail(client, ownerId, claimRow.session_id);
    const buffer = buildClaimForThermal(sessionDetail, mapClaimRow(claimRow));
    return {
      success: true,
      data: { document: buffer.toString("base64") },
    };
  }
);

export const getConsignmentHistory = api<HistoryRequest, HistoryResponse>(
  { method: "GET", path: "/consignment/sessions/:sessionId/history" },
  async ({ authorization, sessionId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedSessionId = sanitizeString(sessionId);
    if (!normalizedSessionId) {
      throw APIError.invalidArgument("sessionId is required");
    }

    await fetchSessionRow(client, ownerId, normalizedSessionId);

    const { data, error } = await client
      .from(CONSIGNMENT_HISTORY_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .eq("session_id", normalizedSessionId)
      .order("created_at", { ascending: false });

    if (error) {
      translateDbError(error);
    }

    const rows = ((data ?? []) as HistoryRow[]).map(mapHistoryRow);
    return {
      success: true,
      data: { events: rows },
    };
  }
);

