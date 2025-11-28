import { APIError } from "encore.dev/api";

import { Batch, InventorySnapshot } from "../../pkg/types";
import { BatchCreate, BatchWithStats } from "./types";

export const INVENTORY_TABLE = "inventory_batches";
export const INVENTORY_MOVEMENTS_TABLE = "inventory_movements";
export const INGREDIENTS_TABLE = "ingredients";
export const DEFAULT_LOW_STOCK_THRESHOLD = 5;

export interface InventoryBatchRow {
  id: string;
  business_owner_id: string;
  product_id: string;
  batch_code: string | null;
  quantity: number;
  available_quantity: number;
  cost_per_unit: number | null;
  manufacture_date: string | null;
  expiry_date: string | null;
  warehouse: string | null;
  created_at: string;
  updated_at: string;
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

export const validateBatchCreate = (input: BatchCreate): BatchCreate => {
  const productId = sanitizeString(input.productId);
  if (!productId) {
    throw APIError.invalidArgument("productId is required");
  }

  return {
    ...input,
    productId,
    batchCode: sanitizeString(input.batchCode),
    warehouse: sanitizeString(input.warehouse),
    manufactureDate: sanitizeString(input.manufactureDate),
    expiryDate: sanitizeString(input.expiryDate),
    quantity: ensurePositiveNumber(input.quantity, "quantity"),
    costPerUnit: ensurePositiveNumber(input.costPerUnit, "costPerUnit"),
  };
};

export const buildBatchInsertPayload = (
  batch: BatchCreate,
  ownerId: string
): Omit<InventoryBatchRow, "id" | "created_at" | "updated_at"> => ({
  business_owner_id: ownerId,
  product_id: batch.productId,
  batch_code: batch.batchCode ?? null,
  quantity: batch.quantity,
  available_quantity: batch.quantity,
  cost_per_unit: batch.costPerUnit,
  manufacture_date: batch.manufactureDate ?? null,
  expiry_date: batch.expiryDate ?? null,
  warehouse: batch.warehouse ?? null,
});

export const mapBatchRow = (row: InventoryBatchRow): Batch => ({
  id: row.id,
  productId: row.product_id,
  batchCode: row.batch_code ?? undefined,
  quantity: Number(row.quantity),
  availableQuantity: Number(row.available_quantity),
  costPerUnit: row.cost_per_unit ?? undefined,
  manufactureDate: row.manufacture_date ?? undefined,
  expiryDate: row.expiry_date ?? undefined,
  warehouse: row.warehouse ?? undefined,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const sumAvailableQuantity = (rows: InventoryBatchRow[]): number =>
  rows.reduce((total, row) => total + Number(row.available_quantity ?? 0), 0);

export const buildLowStockSnapshots = (
  batches: Batch[],
  threshold = DEFAULT_LOW_STOCK_THRESHOLD
): InventorySnapshot[] => {
  const grouped = new Map<
    string,
    { totalQuantity: number; availableQuantity: number }
  >();

  for (const batch of batches) {
    const entry = grouped.get(batch.productId) ?? {
      totalQuantity: 0,
      availableQuantity: 0,
    };
    entry.totalQuantity += batch.quantity;
    entry.availableQuantity += batch.availableQuantity;
    grouped.set(batch.productId, entry);
  }

  const snapshots: InventorySnapshot[] = [];
  for (const [productId, summary] of grouped.entries()) {
    if (summary.availableQuantity <= threshold) {
      snapshots.push({
        productId,
        totalQuantity: summary.totalQuantity,
        availableQuantity: summary.availableQuantity,
        threshold,
        lowStock: true,
      });
    }
  }

  return snapshots;
};

export const calculateTotalsMap = (
  rows: InventoryBatchRow[]
): Map<string, number> => {
  const totals = new Map<string, number>();
  for (const row of rows) {
    const current = totals.get(row.product_id) ?? 0;
    totals.set(row.product_id, current + Number(row.available_quantity ?? 0));
  }
  return totals;
};

export const attachBatchStats = (
  row: InventoryBatchRow,
  totalsMap: Map<string, number>,
  threshold = DEFAULT_LOW_STOCK_THRESHOLD
): BatchWithStats => {
  const batch = mapBatchRow(row);
  const totalStock = totalsMap.get(row.product_id) ?? batch.availableQuantity;
  return {
    ...batch,
    totalStock,
    lowStock: totalStock <= threshold,
  };
};

export const buildMovementPayload = (params: {
  ownerId: string;
  batchId: string | null;
  productId: string;
  type: "in" | "out";
  quantity: number;
  note?: string;
}) => ({
  business_owner_id: params.ownerId,
  batch_id: params.batchId,
  product_id: params.productId,
  type: params.type,
  qty: params.quantity,
  note: params.note ?? null,
});

