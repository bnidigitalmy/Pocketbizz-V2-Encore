import type { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface Supplier {
  id: string;
  name: string;
  phone?: string;
  address?: string;
  commission: number;
  createdAt: string;
  updatedAt: string;
}

export interface SupplierProduct {
  id: string;
  productId: string;
  productName: string;
  commission: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSupplierRequest extends AuthorizedRequest {
  supplier: {
    name: string;
    phone?: string;
    address?: string;
    commission?: number;
  };
}

export interface UpdateSupplierRequest extends AuthorizedRequest {
  supplier: {
    id: string;
    name?: string;
    phone?: string;
    address?: string;
    commission?: number;
  };
}

export interface DeleteSupplierRequest extends AuthorizedRequest {
  id: string;
}

export interface AssignProductRequest extends AuthorizedRequest {
  supplierId: string;
  productId: string;
  commission?: number;
}

export interface SupplierListResponse {
  success: boolean;
  data?: {
    suppliers: Supplier[];
  };
  error?: string;
}

export interface SupplierResponse {
  success: boolean;
  data?: {
    supplier: Supplier;
  };
  error?: string;
}

export interface SupplierProductsResponse {
  success: boolean;
  data?: {
    products: SupplierProduct[];
  };
  error?: string;
}

export interface SupplierPOItemInput {
  stockItemId: string;
  qty: number;
  unit: string;
  unitPrice?: number;
}

export interface CreateSupplierPORequest extends AuthorizedRequest {
  supplierId: string;
  items: SupplierPOItemInput[];
  notes?: string;
}

export interface SupplierPO {
  id: string;
  supplierId: string;
  reference: string;
  status: string;
  totalValue: number;
  notes?: string;
  items: SupplierPOItem[];
  createdAt: string;
  updatedAt: string;
}

export interface SupplierPOItem {
  id: string;
  productId: string;
  description?: string;
  qtyOrdered: number;
  qtyReceived: number;
  unit: string;
  unitPrice: number;
  totalPrice: number;
  createdAt: string;
  updatedAt: string;
}

export interface SupplierPOResponse {
  success: boolean;
  data?: {
    purchaseOrder: SupplierPO;
  };
  error?: string;
}

export interface ReceiveSupplierPORequest extends AuthorizedRequest {
  poId: string;
}

export interface ReceiveSupplierPOResponse {
  success: boolean;
  data?: {
    purchaseOrder: SupplierPO;
    inventoryBatches: InventoryBatchSummary[];
  };
  error?: string;
}

export interface InventoryBatchSummary {
  type: "ingredient" | "finished";
  referenceId: string;
  quantity: number;
  costPerUnit: number;
}

