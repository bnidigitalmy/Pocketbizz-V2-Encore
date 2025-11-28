import { Header } from "encore.dev/api";

import { Recipe } from "../../pkg/types";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface RecipeItemInput {
  ingredientId: string;
  quantity: number;
  unit: string;
  position?: number;
}

export interface RecipeCreate {
  name: string;
  productId?: string;
  yieldQuantity?: number;
  yieldUnit?: string;
  items: RecipeItemInput[];
}

export interface RecipeUpdateInput {
  name?: string;
  productId?: string;
  yieldQuantity?: number;
  yieldUnit?: string;
}

export interface AddRecipeRequest extends AuthorizedRequest {
  recipe: RecipeCreate;
}

export interface AddRecipeItemsRequest extends AuthorizedRequest {
  recipeId: string;
  items: RecipeItemInput[];
}

export interface GetRecipeRequest extends AuthorizedRequest {
  id: string;
}

export interface ListRecipesRequest extends AuthorizedRequest {}

export interface RecipeUpdateRequest extends AuthorizedRequest {
  recipeId: string;
  recipe: RecipeUpdateInput;
}

export interface RecipeItemCost {
  itemId: string;
  ingredientId: string;
  ingredientName: string;
  unit: string;
  quantity: number;
  costPerUnit: number;
  totalCost: number;
  position: number;
}

export interface RecipeDetailData {
  recipe: Recipe;
  items: RecipeItemCost[];
  totalCost: number;
  costPerServing?: number;
}

export type RecipeDetailResponse = ApiResponse<RecipeDetailData>;

export type RecipeListResponse = ApiResponse<{
  recipes: Recipe[];
}>;
