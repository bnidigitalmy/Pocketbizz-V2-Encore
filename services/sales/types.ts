import { Header } from "encore.dev/api";

import { Sale, SaleLineItem } from "../../pkg/types";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface SaleCreateItem {
  productId: string;
  quantity: number;
  unitPrice: number;
}

export interface SaleCreatePayload {
  customerId?: string;
  channel: Sale["channel"];
  status?: Sale["status"];
  tax?: number;
  discount?: number;
  occurredAt?: string;
  lineItems: SaleCreateItem[];
}

export interface CreateSaleRequest extends AuthorizedRequest {
  sale: SaleCreatePayload;
}

export interface SaleResponse {
  sale: Sale;
}

export interface SaleListRequest extends AuthorizedRequest {}

export interface SaleListResponse {
  sales: Sale[];
}

export interface GetSaleRequest extends AuthorizedRequest {
  id: string;
}

export interface SalesSummaryEntry {
  period: string;
  total: number;
  cogs: number;
  profit: number;
}

export interface SalesSummaryResponse {
  entries: SalesSummaryEntry[];
}

export interface SalesSummaryRequest extends AuthorizedRequest {}

export interface ProductInventoryMovement {
  productId: string;
  movements: Array<{
    batchId: string;
    quantity: number;
    unitCost: number;
    remainingBatchQuantity: number;
  }>;
}

export interface SaleCreatedEvent {
  saleId: string;
  customerId?: string;
  lineItems: SaleLineItem[];
  inventoryMovements: ProductInventoryMovement[];
}

