import type { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface CreatePOItem {
  ingredient_id?: string | null;
  product_id?: string | null;
  description?: string | null;
  qty_ordered: number;
  unit: string;
  unit_price?: number;
}

export interface CreatePOInput {
  vendor_id: string;
  items: CreatePOItem[];
  notes?: string | null;
  currency?: string;
  linked_shopping_item_ids?: string[];
}

export interface PurchaseOrderItem {
  id: string;
  ingredientId?: string;
  productId?: string;
  description?: string;
  qtyOrdered: number;
  qtyReceived: number;
  unit: string;
  unitPrice: number;
  totalPrice: number;
  createdAt: string;
  updatedAt: string;
}

export interface VendorSummary {
  id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
}

export interface PurchaseOrder {
  id: string;
  vendorId: string;
  vendor?: VendorSummary;
  reference: string;
  status: string;
  currency: string;
  totalValue: number;
  notes?: string;
  items: PurchaseOrderItem[];
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseOrderResponse {
  success: boolean;
  data?: {
    purchaseOrder: PurchaseOrder;
  };
  error?: string;
}

export interface CreateGRNItemInput {
  po_item_id?: string | null;
  product_id?: string | null;
  ingredient_id?: string | null;
  qty_received: number;
  unit: string;
  unit_price?: number;
  description?: string | null;
}

export interface CreateGRNInput {
  po_id?: string | null;
  items: CreateGRNItemInput[];
  notes?: string | null;
  linked_shopping_item_ids?: string[];
}

export interface CreatePORequest extends AuthorizedRequest {
  po: CreatePOInput;
}

export interface CreateGRNRequest extends AuthorizedRequest {
  grn: CreateGRNInput;
}

export interface GoodsReceivedItem {
  id: string;
  grnId: string;
  ingredientId?: string;
  productId?: string;
  description?: string;
  qtyReceived: number;
  unit: string;
  unitPrice: number;
  totalPrice: number;
  createdAt: string;
}

export interface GoodsReceivedNote {
  id: string;
  reference: string;
  status: string;
  totalReceivedValue: number;
  purchaseOrderId?: string;
  items: GoodsReceivedItem[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateGRNResponse {
  success: boolean;
  data?: {
    grn: GoodsReceivedNote;
  };
  error?: string;
}

export interface ListPOResponse {
  success: boolean;
  data?: {
    purchaseOrders: PurchaseOrder[];
  };
  error?: string;
}

export interface ListGRNResponse {
  success: boolean;
  data?: {
    grns: GoodsReceivedNote[];
  };
  error?: string;
}

export interface ListPORequest extends AuthorizedRequest {
  status?: string;
}

export interface GetPORequest extends AuthorizedRequest {
  id: string;
}

export interface GetGRNRequest extends AuthorizedRequest {
  id: string;
}

export interface ApprovePORequest extends AuthorizedRequest {
  id: string;
}

export interface ApprovePOResponse {
  success: boolean;
  data?: {
    purchaseOrder: PurchaseOrder;
    thermalPayload: string;
  };
  error?: string;
}

export interface GRNPrintRequest extends AuthorizedRequest {
  id: string;
}

export interface GRNPrintResponse {
  success: boolean;
  data?: {
    thermalPayload: string;
  };
  error?: string;
}

export interface ReceiveGRNRequest extends AuthorizedRequest {
  id: string;
}

export interface ReceiveGRNResponse {
  success: boolean;
  data?: {
    grn: GoodsReceivedNote;
    inventoryBatches: Array<{
      type: "ingredient" | "finished";
      referenceId: string;
      quantity: number;
      costPerUnit: number;
    }>;
  };
  error?: string;
}

