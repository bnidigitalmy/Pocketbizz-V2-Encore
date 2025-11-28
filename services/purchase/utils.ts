import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import { getClient } from "../../pkg/supabase";
import { FINISHED_BATCHES_TABLE, INVENTORY_TABLE } from "../production/utils";
import type {
  CreateGRNItemInput,
  CreatePOItem,
  GoodsReceivedItem,
  GoodsReceivedNote,
  PurchaseOrder,
  PurchaseOrderItem,
  VendorSummary,
} from "./types";

export const PURCHASE_ORDERS_TABLE = "purchase_orders";
export const PURCHASE_ORDER_ITEMS_TABLE = "purchase_order_items";
export const GRN_TABLE = "grn";
export const GRN_ITEMS_TABLE = "grn_items";
export const PO_LOGS_TABLE = "po_logs";
export const SHOPPING_LIST_TABLE = "shopping_list";
export const VENDORS_TABLE = "vendors";

export const sanitizeString = (value?: string | null): string | undefined => {
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

export const generateReference = (prefix: string): string => {
  const now = new Date();
  const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(
    now.getDate()
  ).padStart(2, "0")}-${now.getTime()}`;
  return `${prefix}-${stamp}`;
};

export const computePOTotals = (items: CreatePOItem[]): { total_value: number } => {
  let total = 0;
  for (const it of items) {
    total += Number(it.qty_ordered) * Number(it.unit_price ?? 0);
  }
  return { total_value: Number(total.toFixed(2)) };
};

export interface VendorRow {
  id: string;
  business_owner_id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
}

export const mapVendor = (row: VendorRow): VendorSummary => ({
  id: row.id,
  name: row.name,
  email: row.email ?? undefined,
  phone: row.phone ?? undefined,
});

export const ensureVendorOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<VendorRow> => {
  const { data, error } = await client
    .from(VENDORS_TABLE)
    .select("id, business_owner_id, name, email, phone")
    .eq("business_owner_id", ownerId)
    .eq("id", vendorId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Vendor not found");
  }
  return data as VendorRow;
};

export const mergeShoppingItemsIntoPO = async (
  client: SupabaseClient,
  ownerId: string,
  shoppingItemIds: string[],
  poId: string
): Promise<void> => {
  if (!shoppingItemIds.length) return;

  const { data, error } = await client
    .from(SHOPPING_LIST_TABLE)
    .select("id")
    .eq("business_owner_id", ownerId)
    .in("id", shoppingItemIds);

  if (error) {
    throw APIError.internal(error.message);
  }

  if (!data?.length) {
    return;
  }

  const { error: updateError } = await client
    .from(SHOPPING_LIST_TABLE)
    .update({
      linked_production_batch: poId,
      updated_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .in("id", shoppingItemIds);

  if (updateError) {
    throw APIError.internal(updateError.message);
  }
};

export const markShoppingItemsAsPurchased = async (
  client: SupabaseClient,
  ownerId: string,
  shoppingItemIds: string[]
): Promise<void> => {
  if (!shoppingItemIds.length) return;
  const { error } = await client
    .from(SHOPPING_LIST_TABLE)
    .update({
      is_purchased: true,
      updated_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .in("id", shoppingItemIds);
  if (error) {
    throw APIError.internal(error.message);
  }
};

export interface PurchaseOrderRow {
  id: string;
  business_owner_id: string;
  vendor_id: string;
  reference: string;
  status: string;
  currency: string;
  total_value: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface PurchaseOrderItemRow {
  id: string;
  po_id: string;
  ingredient_id: string | null;
  product_id: string | null;
  description: string | null;
  qty_ordered: number;
  qty_received: number;
  unit: string;
  unit_price: number;
  total_price: number;
  created_at: string;
  updated_at: string;
}

export interface GRNRow {
  id: string;
  business_owner_id: string;
  po_id: string | null;
  reference: string;
  status: string;
  total_received_value: number;
  created_at: string;
  updated_at: string;
}

export interface GRNItemRow {
  id: string;
  grn_id: string;
  po_item_id: string | null;
  ingredient_id: string | null;
  product_id: string | null;
  qty_received: number;
  unit: string;
  unit_price: number;
  total_price: number;
  description: string | null;
  created_at: string;
}

interface InventoryBatchInsert {
  business_owner_id: string;
  product_id: string;
  quantity: number;
  available_quantity: number;
  cost_per_unit: number;
  total_cost: number;
  manufacture_date?: string | null;
  expiry_date?: string | null;
  batch_code?: string | null;
}

const createIngredientBatch = async (
  client: SupabaseClient,
  payload: InventoryBatchInsert
) => {
  const { data, error } = await client
    .from(INVENTORY_TABLE)
    .insert(payload)
    .select("id, product_id, available_quantity, cost_per_unit")
    .single();
  if (error) {
    throw APIError.internal(error.message);
  }
  return data as { id: string; product_id: string; available_quantity: number; cost_per_unit: number };
};

const createFinishedProductBatch = async (
  client: SupabaseClient,
  payload: {
    business_owner_id: string;
    product_id: string;
    quantity: number;
    available_quantity: number;
    cost_per_unit: number;
    total_cost: number;
    production_date: string;
  }
) => {
  const { data, error } = await client
    .from(FINISHED_BATCHES_TABLE)
    .insert({
      ...payload,
      recipe_id: null,
      expiry_date: null,
      notes: "GRN stock-in",
    })
    .select("id, product_id, available_quantity, cost_per_unit")
    .single();
  if (error) {
    throw APIError.internal(error.message);
  }
  return data as { id: string; product_id: string; available_quantity: number; cost_per_unit: number };
};

export const createInventoryBatchFromGRNItem = async (
  client: SupabaseClient,
  ownerId: string,
  grnItem: CreateGRNItemInput
): Promise<{
  type: "ingredient" | "finished";
  referenceId: string;
  quantity: number;
  costPerUnit: number;
}> => {
  const qty = ensurePositiveNumber(grnItem.qty_received, "qty_received");
  const unitPrice = Number(grnItem.unit_price ?? 0);
  const totalCost = Number((qty * unitPrice).toFixed(4));

  if (grnItem.ingredient_id) {
    const batch = await createIngredientBatch(client, {
      business_owner_id: ownerId,
      product_id: grnItem.ingredient_id,
      quantity: qty,
      available_quantity: qty,
      cost_per_unit: unitPrice,
      total_cost: totalCost,
    });
    return {
      type: "ingredient",
      referenceId: batch.id,
      quantity: qty,
      costPerUnit: unitPrice,
    };
  }

  if (grnItem.product_id) {
    const batch = await createFinishedProductBatch(client, {
      business_owner_id: ownerId,
      product_id: grnItem.product_id,
      quantity: qty,
      available_quantity: qty,
      cost_per_unit: unitPrice,
      total_cost: totalCost,
      production_date: new Date().toISOString().slice(0, 10),
    });
    return {
      type: "finished",
      referenceId: batch.id,
      quantity: qty,
      costPerUnit: unitPrice,
    };
  }

  throw APIError.invalidArgument("GRN item must reference ingredient_id or product_id");
};

export const mapPOItem = (row: PurchaseOrderItemRow): PurchaseOrderItem => ({
  id: row.id,
  ingredientId: row.ingredient_id ?? undefined,
  productId: row.product_id ?? undefined,
  description: row.description ?? undefined,
  qtyOrdered: Number(row.qty_ordered ?? 0),
  qtyReceived: Number(row.qty_received ?? 0),
  unit: row.unit ?? "",
  unitPrice: Number(row.unit_price ?? 0),
  totalPrice: Number(row.total_price ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapPurchaseOrder = (
  row: PurchaseOrderRow,
  items: PurchaseOrderItemRow[],
  vendor?: VendorRow
): PurchaseOrder => ({
  id: row.id,
  vendorId: row.vendor_id,
  vendor: vendor ? mapVendor(vendor) : undefined,
  reference: row.reference,
  status: row.status,
  currency: row.currency,
  totalValue: Number(row.total_value ?? 0),
  notes: row.notes ?? undefined,
  items: items.map(mapPOItem),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapGRNItem = (row: GRNItemRow): GoodsReceivedItem => ({
  id: row.id,
  grnId: row.grn_id,
  ingredientId: row.ingredient_id ?? undefined,
  productId: row.product_id ?? undefined,
  description: row.description ?? undefined,
  qtyReceived: Number(row.qty_received ?? 0),
  unit: row.unit ?? "",
  unitPrice: Number(row.unit_price ?? 0),
  totalPrice: Number(row.total_price ?? 0),
  createdAt: row.created_at,
});

export const mapGRN = (row: GRNRow, items: GRNItemRow[]): GoodsReceivedNote => ({
  id: row.id,
  reference: row.reference,
  status: row.status,
  totalReceivedValue: Number(row.total_received_value ?? 0),
  purchaseOrderId: row.po_id ?? undefined,
  items: items.map(mapGRNItem),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const fetchPurchaseOrderById = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<{ order: PurchaseOrderRow; items: PurchaseOrderItemRow[]; vendor: VendorRow }> => {
  const { data: order, error: poError } = await client
    .from(PURCHASE_ORDERS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .maybeSingle();

  if (poError) {
    throw APIError.internal(poError.message);
  }
  if (!order) {
    throw APIError.notFound("Purchase order not found");
  }

  const { data: items, error: itemsError } = await client
    .from(PURCHASE_ORDER_ITEMS_TABLE)
    .select("*")
    .eq("po_id", id)
    .order("created_at", { ascending: true });

  if (itemsError) {
    throw APIError.internal(itemsError.message);
  }

  const vendor = await ensureVendorOwnership(client, ownerId, (order as PurchaseOrderRow).vendor_id);
  return {
    order: order as PurchaseOrderRow,
    items: (items ?? []) as PurchaseOrderItemRow[],
    vendor,
  };
};

export const fetchGRNById = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<{ grn: GRNRow; items: GRNItemRow[] }> => {
  const { data: grnRow, error } = await client
    .from(GRN_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!grnRow) {
    throw APIError.notFound("GRN not found");
  }

  const { data: itemsData, error: itemsError } = await client
    .from(GRN_ITEMS_TABLE)
    .select("*")
    .eq("grn_id", id)
    .order("created_at", { ascending: true });

  if (itemsError) {
    throw APIError.internal(itemsError.message);
  }

  return {
    grn: grnRow as GRNRow,
    items: (itemsData ?? []) as GRNItemRow[],
  };
};

export const updatePOStatusFromItems = async (
  client: SupabaseClient,
  ownerId: string,
  poId: string
): Promise<void> => {
  const { data, error } = await client
    .from(PURCHASE_ORDER_ITEMS_TABLE)
    .select("qty_ordered, qty_received")
    .eq("po_id", poId);

  if (error) {
    throw APIError.internal(error.message);
  }

  const rows = (data ?? []) as { qty_ordered: number; qty_received: number }[];
  if (!rows.length) return;

  const isFullyReceived = rows.every(
    (row) => Number(row.qty_received ?? 0) >= Number(row.qty_ordered ?? 0)
  );
  const status = isFullyReceived ? "received" : "partial";

  const { error: updateError } = await client
    .from(PURCHASE_ORDERS_TABLE)
    .update({ status, updated_at: new Date().toISOString() })
    .eq("business_owner_id", ownerId)
    .eq("id", poId);

  if (updateError) {
    throw APIError.internal(updateError.message);
  }
};

export const insertPOLog = async (
  client: SupabaseClient,
  ownerId: string,
  refType: "po" | "grn",
  refId: string,
  action: string,
  payload: Record<string, unknown>
): Promise<void> => {
  const { error } = await client.from(PO_LOGS_TABLE).insert({
    business_owner_id: ownerId,
    ref_type: refType,
    ref_id: refId,
    action,
    payload,
    created_at: new Date().toISOString(),
  });
  if (error) {
    throw APIError.internal(error.message);
  }
};

export const getSupabaseClient = (ownerToken?: string): SupabaseClient => getClient(ownerToken);

