import { APIError } from "encore.dev/api";

import { Sale, SaleLineItem } from "../../pkg/types";
import { SaleCreateItem, SaleCreatePayload } from "./types";

export const SALES_TABLE = "sales";
export const SALES_ITEMS_TABLE = "sales_items";
export const FINISHED_PRODUCT_BATCHES_TABLE = "finished_product_batches";
export const INVENTORY_MOVEMENTS_TABLE = "inventory_movements";
export const PRODUCTS_TABLE = "products";

export interface SaleRow {
  id: string;
  business_owner_id: string;
  customer_id: string | null;
  channel: Sale["channel"];
  status: Sale["status"];
  subtotal: number;
  tax: number;
  discount: number;
  total: number;
  cogs: number | null;
  profit: number | null;
  occurred_at: string;
  created_at: string;
  updated_at: string;
}

export interface SaleItemRow {
  business_owner_id: string;
  sale_id: string;
  product_id: string;
  quantity: number;
  unit_price: number;
  total: number;
  cost_of_goods: number;
  created_at?: string;
  updated_at?: string;
}

export const ensurePositiveNumber = (value: number, label: string): number => {
  if (!Number.isFinite(value) || value <= 0) {
    throw APIError.invalidArgument(`${label} must be greater than zero`);
  }
  return Number(value);
};

export const sanitizeString = (value?: string): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

export interface NormalizedSalePayload extends SaleCreatePayload {
  channel: Sale["channel"];
  status: Sale["status"];
  tax: number;
  discount: number;
  occurredAt: string;
  lineItems: SaleCreateItem[];
}

export const normalizeSalePayload = (
  payload: SaleCreatePayload
): NormalizedSalePayload => {
  const channel = payload.channel;
  if (!channel) {
    throw APIError.invalidArgument("channel is required");
  }

  const lineItems = payload.lineItems ?? [];
  if (!lineItems.length) {
    throw APIError.invalidArgument("At least one line item is required");
  }

  for (const item of lineItems) {
    if (!sanitizeString(item.productId)) {
      throw APIError.invalidArgument("Each line item requires productId");
    }
    ensurePositiveNumber(item.quantity, "line item quantity");
    ensurePositiveNumber(item.unitPrice, "line item unitPrice");
  }

  return {
    customerId: sanitizeString(payload.customerId),
    channel,
    status: payload.status ?? "confirmed",
    tax: Number(payload.tax ?? 0),
    discount: Number(payload.discount ?? 0),
    occurredAt: payload.occurredAt
      ? new Date(payload.occurredAt).toISOString()
      : new Date().toISOString(),
    lineItems: payload.lineItems.map((item) => ({
      productId: sanitizeString(item.productId)!,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
    })),
  };
};

export interface SaleTotals {
  subtotal: number;
  tax: number;
  discount: number;
  total: number;
}

export const computeSaleTotals = (
  lineItems: SaleCreateItem[],
  tax: number,
  discount: number
): SaleTotals => {
  const subtotal = lineItems.reduce(
    (sum, item) => sum + item.quantity * item.unitPrice,
    0
  );

  return {
    subtotal,
    tax,
    discount,
    total: subtotal + tax - discount,
  };
};

export const mapSaleRow = (row: SaleRow): Sale => ({
  id: row.id,
  customerId: row.customer_id ?? undefined,
  channel: row.channel,
  status: row.status,
  subtotal: Number(row.subtotal ?? 0),
  tax: Number(row.tax ?? 0),
  discount: Number(row.discount ?? 0),
  total: Number(row.total ?? 0),
  cogs: Number(row.cogs ?? 0),
  profit: Number(row.profit ?? 0),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const buildSaleInsertPayload = (
  ownerId: string,
  payload: NormalizedSalePayload,
  totals: SaleTotals,
  cogs: number,
  profit: number
) => ({
  business_owner_id: ownerId,
  customer_id: payload.customerId ?? null,
  channel: payload.channel,
  status: payload.status,
  subtotal: totals.subtotal,
  tax: totals.tax,
  discount: totals.discount,
  total: totals.total,
  cogs,
  profit,
  occurred_at: payload.occurredAt,
});

export const buildSaleItemsPayload = (
  ownerId: string,
  saleId: string,
  lineItems: Array<SaleCreateItem & { costOfGoods: number }>
): SaleItemRow[] =>
  lineItems.map((item) => ({
    business_owner_id: ownerId,
    sale_id: saleId,
    product_id: item.productId,
    quantity: item.quantity,
    unit_price: item.unitPrice,
    total: item.quantity * item.unitPrice,
    cost_of_goods: item.costOfGoods,
  }));

