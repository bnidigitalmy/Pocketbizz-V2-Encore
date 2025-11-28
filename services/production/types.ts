import type { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface PlanPreviewRequest extends AuthorizedRequest {
  productId: string;
  quantity: number;
}

export interface ProductionProductSummary {
  id: string;
  name: string;
  unitsPerBatch: number;
  totalCostPerBatch: number;
}

export interface MaterialPlan {
  ingredientId: string;
  ingredientName: string;
  quantityNeeded: number;
  usageUnit: string;
  currentStock: number;
  stockUnit: string;
  isSufficient: boolean;
  shortage: number;
  convertedQuantity: number;
}

export interface ShortageItem {
  ingredientId: string;
  ingredientName: string;
  shortageQty: number;
  unit: string;
}

export interface ProductionPlanData {
  product: ProductionProductSummary;
  quantity: number;
  totalUnits: number;
  materialsNeeded: MaterialPlan[];
  allStockSufficient: boolean;
  canProduce: boolean;
  shortageItems: ShortageItem[];
  totalProductionCost: number;
}

export interface PlanPreviewResponse {
  success: boolean;
  data?: ProductionPlanData;
  error?: string;
}

export interface ConfirmProductionRequest extends AuthorizedRequest {
  productId: string;
  quantity: number;
  batchDate: string;
  expiryDate?: string;
  notes?: string;
  materialsNeeded?: MaterialPlan[];
}

export interface ConfirmProductionResponse {
  success: boolean;
  data?: {
    status: "success";
    batchId: string;
    totalCost: number;
    costPerUnit: number;
    totalUnits: number;
  };
  error?: string;
}

