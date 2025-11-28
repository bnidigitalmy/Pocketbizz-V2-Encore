import { Header } from "encore.dev/api";

import { Batch, InventorySnapshot } from "../../pkg/types";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

interface BaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface BatchCreate {
  productId: string;
  batchCode?: string;
  quantity: number;
  costPerUnit: number;
  manufactureDate?: string;
  expiryDate?: string;
  warehouse?: string;
}

export type BatchWithStats = Batch & {
  totalStock: number;
  lowStock: boolean;
};

export interface InventoryMovement {
  batchId: string;
  consumedQuantity: number;
  remainingBatchQuantity: number;
}

export interface AddBatchRequest extends AuthorizedRequest {
  batch: BatchCreate;
}

export type InventoryListResponse = BaseResponse<{
  batches: BatchWithStats[];
}>;

export type InventoryResponse = BaseResponse<{
  batch: BatchWithStats;
}>;

export interface ConsumeInventoryRequest extends AuthorizedRequest {
  productId: string;
  quantity: number;
  reason?: string;
}

export type ConsumeInventoryResponse = BaseResponse<{
  productId: string;
  consumedQuantity: number;
  remainingQuantity: number;
  movements: InventoryMovement[];
}>;

export interface ListInventoryRequest extends AuthorizedRequest {}

export interface GetInventoryBatchRequest extends AuthorizedRequest {
  id: string;
}

export interface InventoryTotalRequest extends AuthorizedRequest {
  productId: string;
}

export type InventoryTotalResponse = BaseResponse<{
  productId: string;
  totalStock: number;
}>;

export interface LowStockRequest extends AuthorizedRequest {}

export type LowStockResponse = BaseResponse<{
  items: InventorySnapshot[];
}>;
