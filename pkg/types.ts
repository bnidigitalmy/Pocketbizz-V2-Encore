export interface BaseEntity {
  id: string;
  createdAt: string;
  updatedAt: string;
}

export interface Product extends BaseEntity {
  ownerId?: string;
  sku: string;
  name: string;
  description?: string;
  category?: string;
  unit: string;
  costPrice: number;
  salePrice: number;
  isActive: boolean;
}

export interface Ingredient extends BaseEntity {
  name: string;
  unit: string;
  costPerUnit: number;
  supplierId?: string;
}

export interface Batch extends BaseEntity {
  productId: string;
  batchCode?: string;
  quantity: number;
  availableQuantity: number;
  costPerUnit?: number;
  manufactureDate?: string;
  expiryDate?: string;
  warehouse?: string;
}

export interface Sale extends BaseEntity {
  customerId?: string;
  channel: "POS" | "MYSHOP" | "WHOLESALE";
  status: "draft" | "confirmed" | "refunded";
  subtotal: number;
  tax: number;
  discount: number;
  total: number;
  cogs?: number;
  profit?: number;
}

export interface Expense extends BaseEntity {
  category: string;
  amount: number;
  currency: string;
  expenseDate: string;
  notes?: string;
  vendorId?: string;
  ocrReceiptId?: string;
}

export interface Vendor extends BaseEntity {
  name: string;
  email?: string;
  phone?: string;
  type: "supplier" | "reseller";
  address?: string;
}

export interface Customer extends BaseEntity {
  name: string;
  email?: string;
  phone?: string;
  loyaltyTier?: string;
  lifetimeValue: number;
}

export interface OrderItem {
  productId: string;
  quantity: number;
  unitPrice: number;
}

export interface Order extends BaseEntity {
  reference: string;
  customerId?: string;
  status: "pending" | "paid" | "fulfilled" | "cancelled";
  channel: "MYSHOP" | "B2B" | "POS";
  total: number;
  items: OrderItem[];
}

export interface OCRResult {
  receiptId: string;
  status: "pending" | "processing" | "completed" | "failed";
  detectedText?: string;
  amount?: number;
  currency?: string;
  expenseDate?: string;
  failureReason?: string;
}

export interface OCRReceipt extends BaseEntity {
  ownerId: string;
  filePath: string;
  status: OCRResult["status"];
  metadata?: Record<string, unknown>;
}

export interface Recipe extends BaseEntity {
  name: string;
  productId?: string;
  yieldQuantity?: number;
  yieldUnit?: string;
  totalCost?: number;
}

export interface RecipeItem {
  ingredientId: string;
  quantity: number;
  unit: string;
  cost?: number;
}

export interface SaleLineItem {
  productId: string;
  quantity: number;
  unitPrice: number;
  costOfGoods?: number;
}

export interface IngredientConsumption {
  ingredientId: string;
  quantity: number;
}

export interface InventorySnapshot {
  productId: string;
  totalQuantity: number;
  availableQuantity: number;
  threshold?: number;
  lowStock: boolean;
}

export interface AnalyticsSummary {
  totalSales: number;
  totalExpenses: number;
  grossProfit: number;
  generatedAt: string;
}

export type ReportStatus = "pending" | "processing" | "completed" | "failed";

