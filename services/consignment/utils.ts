import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type {
  ClaimStatus,
  ConsignmentClaim,
  ConsignmentItemDetail,
  ConsignmentSessionDetail,
  ConsignmentSessionSummary,
  HistoryEvent,
  SessionMetrics,
  VendorSummary,
} from "./types";

export const CONSIGNMENT_SESSIONS_TABLE = "consignment_sessions";
export const CONSIGNMENT_ITEMS_TABLE = "consignment_items";
export const CONSIGNMENT_CLAIMS_TABLE = "consignment_claims";
export const CONSIGNMENT_HISTORY_TABLE = "consignment_history";
export const VENDORS_TABLE = "vendors";
export const PRODUCTS_TABLE = "products";

interface DbError {
  code?: string;
  message?: string;
  details?: string | null;
}

export interface ConsignmentSessionRow {
  id: string;
  business_owner_id: string;
  vendor_id: string;
  reference: string;
  status: string;
  note?: string | null;
  total_items: number;
  total_value: number;
  created_at: string;
  updated_at: string;
}

export interface ConsignmentItemRow {
  id: string;
  session_id: string;
  product_id: string;
  qty_sent: number;
  qty_sold: number;
  qty_returned: number;
  list_price: number;
  unit_price: number;
  commission_type: "percent" | "fixed";
  commission_rate?: number | null;
  commission_amount: number;
  total_value: number;
  created_at: string;
  updated_at: string;
}

export interface VendorRow {
  id: string;
  business_owner_id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
  type?: string | null;
}

export interface ProductRow {
  id: string;
  business_owner_id: string;
  name: string;
  sale_price: number;
}

export interface ConsignmentClaimRow {
  id: string;
  business_owner_id: string;
  session_id: string;
  total_sold_value: number;
  total_commission: number;
  total_payout: number;
  claim_date: string;
  status: ClaimStatus;
  created_at: string;
  updated_at: string;
}

export interface HistoryRow {
  id: string;
  business_owner_id: string;
  session_id: string;
  event_type: string;
  details: Record<string, unknown> | null;
  created_at: string;
}

export const sanitizeString = (value?: string): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

export const ensurePositiveNumber = (value: number, field: string): number => {
  if (!Number.isFinite(value) || value <= 0) {
    throw APIError.invalidArgument(`${field} must be greater than zero`);
  }
  return Number(value);
};

export const ensureNonNegativeNumber = (value: number, field: string): number => {
  if (!Number.isFinite(value) || value < 0) {
    throw APIError.invalidArgument(`${field} must be zero or greater`);
  }
  return Number(value);
};

export const roundCurrency = (value: number, precision = 2): number =>
  Number(value.toFixed(precision));

export const generateConsignmentReference = (date = new Date()): string => {
  const stamp = `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, "0")}${String(
    date.getDate()
  ).padStart(2, "0")}`;
  const random = Math.floor(Math.random() * 1000)
    .toString()
    .padStart(3, "0");
  return `CONS-${stamp}-${random}`;
};

export const translateDbError = (error: DbError | null | undefined, notFound?: string): never => {
  if (error?.code === "PGRST116" && notFound) {
    throw APIError.notFound(notFound);
  }
  throw APIError.internal(error?.message ?? "Unexpected database error");
};

export const ensureVendorOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<VendorRow> => {
  const { data, error } = await client
    .from(VENDORS_TABLE)
    .select("id, business_owner_id, name, email, phone, type")
    .eq("business_owner_id", ownerId)
    .eq("id", vendorId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Vendor ${vendorId} not found`);
  }
  if (!data) {
    throw APIError.notFound(`Vendor ${vendorId} not found`);
  }
  return data as VendorRow;
};

export const fetchProductsMap = async (
  client: SupabaseClient,
  ownerId: string,
  productIds: string[]
): Promise<Record<string, ProductRow>> => {
  if (!productIds.length) {
    return {};
  }

  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id, business_owner_id, name, sale_price")
    .eq("business_owner_id", ownerId)
    .in("id", productIds);

  if (error) {
    translateDbError(error);
  }

  const rows = (data ?? []) as ProductRow[];
  const map: Record<string, ProductRow> = {};
  for (const row of rows) {
    map[row.id] = row;
  }
  return map;
};

export const mapVendorRow = (row: VendorRow): VendorSummary => ({
  id: row.id,
  name: row.name,
  type: row.type ?? undefined,
  contact: {
    email: row.email ?? undefined,
    phone: row.phone ?? undefined,
  },
});

export const mapSessionRow = (row: ConsignmentSessionRow): ConsignmentSessionSummary => ({
  id: row.id,
  vendorId: row.vendor_id,
  reference: row.reference,
  status: row.status as ConsignmentSessionSummary["status"],
  totalItems: Number(row.total_items ?? 0),
  totalValue: Number(row.total_value ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
  note: row.note ?? undefined,
});

export const mapItemRow = (row: ConsignmentItemRow): ConsignmentItemDetail => ({
  id: row.id,
  sessionId: row.session_id,
  productId: row.product_id,
  qtySent: Number(row.qty_sent ?? 0),
  qtySold: Number(row.qty_sold ?? 0),
  qtyReturned: Number(row.qty_returned ?? 0),
  listPrice: Number(row.list_price ?? 0),
  unitPrice: Number(row.unit_price ?? 0),
  commissionType: row.commission_type,
  commissionRate: row.commission_rate ?? undefined,
  commissionAmount: Number(row.commission_amount ?? 0),
  totalValue: Number(row.total_value ?? 0),
});

export const mapClaimRow = (row: ConsignmentClaimRow): ConsignmentClaim => ({
  id: row.id,
  sessionId: row.session_id,
  totalSoldValue: Number(row.total_sold_value ?? 0),
  totalCommission: Number(row.total_commission ?? 0),
  totalPayout: Number(row.total_payout ?? 0),
  claimDate: row.claim_date,
  status: row.status,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapHistoryRow = (row: HistoryRow): HistoryEvent => ({
  id: row.id,
  sessionId: row.session_id,
  eventType: row.event_type,
  details: row.details ?? undefined,
  createdAt: row.created_at,
});

export const computeSessionMetrics = (rows: ConsignmentItemRow[]): SessionMetrics => {
  const grossPotential = rows.reduce((sum, row) => sum + Number(row.list_price ?? 0) * Number(row.qty_sent ?? 0), 0);
  const grossSold = rows.reduce((sum, row) => sum + Number(row.list_price ?? 0) * Number(row.qty_sold ?? 0), 0);
  const totalCommission = rows.reduce(
    (sum, row) => sum + Number(row.qty_sold ?? 0) * Number(row.commission_amount ?? 0),
    0
  );
  const remainingQty = rows.reduce(
    (sum, row) => sum + Number(row.qty_sent ?? 0) - Number(row.qty_sold ?? 0) - Number(row.qty_returned ?? 0),
    0
  );
  const totalPayout = grossSold - totalCommission;

  return {
    grossPotential: roundCurrency(grossPotential),
    grossSold: roundCurrency(grossSold),
    totalCommission: roundCurrency(totalCommission),
    totalPayout: roundCurrency(totalPayout),
    remainingQty: Number(remainingQty.toFixed(3)),
  };
};

export const buildSessionDetail = (
  session: ConsignmentSessionRow,
  vendor: VendorRow,
  items: ConsignmentItemRow[]
): ConsignmentSessionDetail => ({
  ...mapSessionRow(session),
  vendor: mapVendorRow(vendor),
  items: items.map(mapItemRow),
  metrics: computeSessionMetrics(items),
});

export const loadSessionDetail = async (
  client: SupabaseClient,
  ownerId: string,
  sessionId: string
): Promise<ConsignmentSessionDetail> => {
  const { data: sessionRow, error: sessionError } = await client
    .from(CONSIGNMENT_SESSIONS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", sessionId)
    .maybeSingle();

  if (sessionError) {
    translateDbError(sessionError, `Consignment session ${sessionId} not found`);
  }

  if (!sessionRow) {
    throw APIError.notFound(`Consignment session ${sessionId} not found`);
  }

  const session = sessionRow as ConsignmentSessionRow;
  const vendor = await ensureVendorOwnership(client, ownerId, session.vendor_id);

  const { data: itemsData, error: itemsError } = await client
    .from(CONSIGNMENT_ITEMS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("session_id", session.id)
    .order("created_at", { ascending: true });

  if (itemsError) {
    translateDbError(itemsError);
  }

  const items = (itemsData ?? []) as ConsignmentItemRow[];
  return buildSessionDetail(session, vendor, items);
};

export const loadClaimById = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string
): Promise<ConsignmentClaimRow> => {
  const { data, error } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Consignment claim ${claimId} not found`);
  }
  if (!data) {
    throw APIError.notFound(`Consignment claim ${claimId} not found`);
  }
  return data as ConsignmentClaimRow;
};

export const logHistoryEvent = async (
  client: SupabaseClient,
  ownerId: string,
  sessionId: string,
  eventType: string,
  details?: Record<string, unknown>
): Promise<void> => {
  const { error } = await client.from(CONSIGNMENT_HISTORY_TABLE).insert({
    business_owner_id: ownerId,
    session_id: sessionId,
    event_type: eventType,
    details: details ?? null,
  });

  if (error) {
    translateDbError(error);
  }
};

export const recalcSessionTotals = async (
  client: SupabaseClient,
  ownerId: string,
  sessionId: string
): Promise<void> => {
  const { data, error } = await client
    .from(CONSIGNMENT_ITEMS_TABLE)
    .select("qty_sent, unit_price")
    .eq("business_owner_id", ownerId)
    .eq("session_id", sessionId);

  if (error) {
    translateDbError(error);
  }

  const rows = (data ?? []) as Array<{ qty_sent: number; unit_price: number }>;
  const totalItems = rows.reduce((sum, row) => sum + Number(row.qty_sent ?? 0), 0);
  const totalValue = rows.reduce(
    (sum, row) => sum + Number(row.qty_sent ?? 0) * Number(row.unit_price ?? 0),
    0
  );

  const { error: updateError } = await client
    .from(CONSIGNMENT_SESSIONS_TABLE)
    .update({
      total_items: Number(totalItems.toFixed(3)),
      total_value: roundCurrency(totalValue),
      updated_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .eq("id", sessionId);

  if (updateError) {
    translateDbError(updateError);
  }
};

