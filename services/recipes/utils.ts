import { APIError } from "encore.dev/api";

import { Recipe } from "../../pkg/types";
import type { RecipeCreate, RecipeItemInput, RecipeUpdateInput } from "./types";

export const RECIPES_TABLE = "recipes";
export const RECIPE_ITEMS_TABLE = "recipe_items";
export const INGREDIENTS_TABLE = "ingredients";
export const PRODUCTS_TABLE = "products";

export interface RecipeRow {
  id: string;
  business_owner_id: string;
  product_id: string | null;
  name: string;
  yield_quantity: number | null;
  yield_unit: string | null;
  total_cost: number | null;
  created_at: string;
  updated_at: string;
}

export interface RecipeItemRow {
  id: string;
  business_owner_id: string;
  recipe_id: string;
  ingredient_id: string;
  quantity: number;
  unit: string;
  position: number | null;
  created_at: string;
  updated_at: string;
}

export interface IngredientRow {
  id: string;
  name: string;
  unit: string;
  cost_per_unit: number;
}

export interface NormalizedRecipeItem {
  ingredientId: string;
  quantity: number;
  unit: string;
  position: number;
}

export interface NormalizedRecipeInput
  extends Omit<RecipeCreate, "items" | "yieldQuantity"> {
  yieldQuantity?: number;
  productId?: string;
  items: NormalizedRecipeItem[];
}

export const sanitizeString = (value?: string): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

export const ensurePositiveNumber = (
  value: number,
  field: string
): number => {
  if (!Number.isFinite(value) || value <= 0) {
    throw APIError.invalidArgument(`${field} must be greater than zero`);
  }
  return Number(value);
};

const ensureOptionalPositiveNumber = (
  value: number | undefined,
  field: string
): number | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  return ensurePositiveNumber(value, field);
};

export const normalizeRecipeItems = (
  items: RecipeItemInput[]
): NormalizedRecipeItem[] => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("At least one ingredient item is required");
  }

  // TODO(p2): Handle automatic unit conversions; currently assumes recipe item unit matches ingredient base unit.
  return items.map((item, index) => {
    const ingredientId = sanitizeString(item.ingredientId);
    if (!ingredientId) {
      throw APIError.invalidArgument("ingredientId is required for each item");
    }

    const unit = sanitizeString(item.unit);
    if (!unit) {
      throw APIError.invalidArgument("unit is required for each item");
    }

    return {
      ingredientId,
      unit,
      quantity: ensurePositiveNumber(item.quantity, "quantity"),
      position: item.position ?? index,
    };
  });
};

export const normalizeRecipeInput = (
  recipe: RecipeCreate
): NormalizedRecipeInput => {
  const name = sanitizeString(recipe.name);
  if (!name) {
    throw APIError.invalidArgument("Recipe name is required");
  }

  return {
    name,
    productId: sanitizeString(recipe.productId),
    yieldQuantity: ensureOptionalPositiveNumber(
      recipe.yieldQuantity,
      "yieldQuantity"
    ),
    yieldUnit: sanitizeString(recipe.yieldUnit),
    items: normalizeRecipeItems(recipe.items),
  };
};

export const normalizeRecipeUpdate = (
  patch: RecipeUpdateInput
): RecipeUpdateInput => {
  const update: RecipeUpdateInput = {};

  if ("name" in patch) {
    const name = sanitizeString(patch.name);
    if (!name) {
      throw APIError.invalidArgument("name must not be empty");
    }
    update.name = name;
  }

  if ("productId" in patch) {
    const productId = sanitizeString(patch.productId);
    if (patch.productId && !productId) {
      throw APIError.invalidArgument("productId must not be empty");
    }
    update.productId = productId;
  }

  if ("yieldQuantity" in patch) {
    update.yieldQuantity =
      patch.yieldQuantity === undefined || patch.yieldQuantity === null
        ? undefined
        : ensurePositiveNumber(patch.yieldQuantity, "yieldQuantity");
  }

  if ("yieldUnit" in patch) {
    update.yieldUnit = sanitizeString(patch.yieldUnit);
  }

  if (!Object.keys(update).length) {
    throw APIError.invalidArgument("At least one recipe field must be provided");
  }

  return update;
};

export const mapRecipeRow = (row: RecipeRow): Recipe => ({
  id: row.id,
  name: row.name,
  productId: row.product_id ?? undefined,
  yieldQuantity: row.yield_quantity ?? undefined,
  yieldUnit: row.yield_unit ?? undefined,
  totalCost: row.total_cost ?? undefined,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const computeRecipeCost = (
  items: Array<{ quantity: number; cost: number }>
): number => items.reduce((total, item) => total + item.quantity * item.cost, 0);
