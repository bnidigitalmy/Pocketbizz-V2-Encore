import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type { Supplier, SupplierPO, SupplierPOItem, SupplierProduct } from "./types";

export const SUPPLIERS_TABLE = "suppliers";
export const SUPPLIER_PRODUCTS_TABLE = "supplier_products";
export const PRODUCTS_TABLE = "products";
export const PURCHASE_ORDERS_TABLE = "purchase_orders";
export const PURCHASE_ORDER_ITEMS_TABLE = "purchase_order_items";

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

export interface SupplierRow {
  id: string;
  business_owner_id: string;
  name: string;
  phone: string | null;
  address: string | null;
  commission: number | null;
  created_at: string;
  updated_at: string;
}

export interface SupplierProductRow {
  id: string;
  product_id: string;
  product_name: string;
  commission: number | null;
  created_at: string;
  updated_at: string;
}

export interface SupplierPORow {
  id: string;
  business_owner_id: string;
  supplier_id: string | null;
  reference: string;
  status: string;
  total_value: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface SupplierPOItemRow {
  id: string;
  po_id: string;
  product_id: string | null;
  description: string | null;
  qty_ordered: number;
  qty_received: number;
  unit: string | null;
  unit_price: number | null;
  total_price: number | null;
  created_at: string;
  updated_at: string;
}

export const mapSupplier = (row: SupplierRow): Supplier => ({
  id: row.id,
  name: row.name,
  phone: row.phone ?? undefined,
  address: row.address ?? undefined,
  commission: Number(row.commission ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapSupplierProduct = (row: SupplierProductRow): SupplierProduct => ({
  id: row.id,
  productId: row.product_id,
  productName: row.product_name,
  commission: Number(row.commission ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapSupplierPOItem = (row: SupplierPOItemRow): SupplierPOItem => ({
  id: row.id,
  productId: row.product_id ?? "",
  description: row.description ?? undefined,
  qtyOrdered: Number(row.qty_ordered ?? 0),
  qtyReceived: Number(row.qty_received ?? 0),
  unit: row.unit ?? "",
  unitPrice: Number(row.unit_price ?? 0),
  totalPrice: Number(row.total_price ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const mapSupplierPO = (
  row: SupplierPORow,
  items: SupplierPOItemRow[]
): SupplierPO => ({
  id: row.id,
  supplierId: row.supplier_id ?? "",
  reference: row.reference,
  status: row.status,
  totalValue: Number(row.total_value ?? 0),
  notes: row.notes ?? undefined,
  items: items.map(mapSupplierPOItem),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const ensureSupplierOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  supplierId: string
): Promise<SupplierRow> => {
  const { data, error } = await client
    .from(SUPPLIERS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", supplierId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Supplier not found");
  }
  return data as SupplierRow;
};

export const ensureProductOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<void> => {
  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id")
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Product not found");
  }
  // TODO: enforce ownership by joining business_owner_id when available on products.
};

export const fetchSupplierPOById = async (
  client: SupabaseClient,
  ownerId: string,
  poId: string
): Promise<{ order: SupplierPORow; items: SupplierPOItemRow[] }> => {
  const { data, error } = await client
    .from(PURCHASE_ORDERS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", poId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Purchase order not found");
  }

  const { data: items, error: itemsError } = await client
    .from(PURCHASE_ORDER_ITEMS_TABLE)
    .select("*")
    .eq("po_id", poId)
    .order("created_at", { ascending: true });

  if (itemsError) {
    throw APIError.internal(itemsError.message);
  }

  return {
    order: data as SupplierPORow,
    items: (items ?? []) as SupplierPOItemRow[],
  };
};

