import type { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface ShoppingListItem {
  id: string;
  ingredientId: string;
  ingredientName: string;
  shortageQty: number;
  unit: string;
  notes?: string;
  linkedProductionBatch?: string | null;
  isPurchased: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ShoppingListResponse {
  success: boolean;
  data?: {
    items: ShoppingListItem[];
  };
  error?: string;
}

export interface ShoppingItemInput {
  ingredientId: string;
  ingredientName: string;
  shortageQty: number;
  unit: string;
  notes?: string;
  linkedProductionBatch?: string | null;
}

export interface AddFromProductionRequest extends AuthorizedRequest {
  items: ShoppingItemInput[];
}

export interface AddFromProductionResponse {
  success: boolean;
  data?: {
    added: number;
    merged: number;
    totalItems: number;
    items: ShoppingListItem[];
  };
  error?: string;
}

export interface MarkPurchasedRequest extends AuthorizedRequest {
  itemId: string;
}

export interface MarkPurchasedResponse {
  success: boolean;
  data?: {
    item: ShoppingListItem;
  };
  error?: string;
}

export interface RemoveItemRequest extends AuthorizedRequest {
  itemId: string;
}

export interface RemoveItemResponse {
  success: boolean;
  error?: string;
}

