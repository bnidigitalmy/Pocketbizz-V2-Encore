import { Header } from "encore.dev/api";

import { Ingredient } from "../../pkg/types";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface IngredientCreate {
  name: string;
  unit: string;
  costPerUnit: number;
  vendorId?: string;
}

export interface IngredientUpdate extends Partial<IngredientCreate> {
  id: string;
}

export interface AddIngredientRequest extends AuthorizedRequest {
  ingredient: IngredientCreate;
}

export interface ListIngredientsRequest extends AuthorizedRequest {}

export interface GetIngredientRequest extends AuthorizedRequest {
  id: string;
}

export interface UpdateIngredientRequest extends AuthorizedRequest {
  ingredient: IngredientUpdate;
}

export interface DeleteIngredientRequest extends AuthorizedRequest {
  ingredientId: string;
}

interface BaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export type IngredientListResponse = BaseResponse<{
  ingredients: Ingredient[];
}>;

export type IngredientResponse = BaseResponse<{ ingredient: Ingredient }>;

export type DeleteIngredientResponse = BaseResponse<undefined>;

