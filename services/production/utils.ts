import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type { MaterialPlan, ProductionPlanData } from "./types";

export const PRODUCTS_TABLE = "products";
export const RECIPES_TABLE = "recipes";
export const RECIPE_ITEMS_TABLE = "recipe_items";
export const INGREDIENTS_TABLE = "ingredients";
export const INVENTORY_TABLE = "inventory_batches";
export const INVENTORY_MOVEMENTS_TABLE = "inventory_movements";
export const FINISHED_BATCHES_TABLE = "finished_product_batches";
export const PRODUCTION_USAGE_TABLE = "production_ingredient_usage";

export const sanitizeString = (value?: string | null): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

export const ensurePositiveNumber = (value: number, field: string): number => {
  if (!Number.isFinite(value) || value <= 0) {
    throw APIError.invalidArgument(`${field} must be greater than zero`);
  }
  return Number(value);
};

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
  recipe_id: string;
  ingredient_id: string;
  quantity: number;
  unit: string;
  position: number | null;
}

export interface ProductRow {
  id: string;
  business_owner_id: string;
  name: string;
  unit: string;
}

export interface IngredientRow {
  id: string;
  business_owner_id: string;
  name: string;
  unit: string;
  cost_per_unit: number;
}

export interface InventoryBatchRow {
  id: string;
  product_id: string;
  business_owner_id: string;
  available_quantity: number;
  cost_per_unit: number;
  created_at: string;
}

export interface FinishedBatchRow {
  id: string;
  business_owner_id: string;
  product_id: string;
  recipe_id: string | null;
  quantity: number;
  available_quantity: number;
  cost_per_unit: number;
  total_cost: number;
  production_date: string;
  expiry_date: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface BatchConsumption {
  batchId: string;
  quantity: number;
  unitCost: number;
  remainingBatchQuantity: number;
}

export interface IngredientUsageRecord {
  ingredientId: string;
  ingredientName: string;
  unit: string;
  quantity: number;
  cost: number;
  batches: BatchConsumption[];
}

export interface ProductionPlanComputation {
  plan: ProductionPlanData;
  recipe: RecipeRow;
  recipeItems: RecipeItemRow[];
  ingredientMap: Record<string, IngredientRow>;
}

const fetchProduct = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<ProductRow> => {
  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id, business_owner_id, name, unit")
    .eq("business_owner_id", ownerId)
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Product not found");
  }
  return data as ProductRow;
};

const fetchRecipeWithItems = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string
): Promise<{ recipe: RecipeRow; items: RecipeItemRow[] }> => {
  const { data: recipe, error: recipeError } = await client
    .from(RECIPES_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("product_id", productId)
    .maybeSingle();

  if (recipeError) {
    throw APIError.internal(recipeError.message);
  }
  if (!recipe) {
    throw APIError.notFound("No recipe found for the specified product");
  }

  const { data: items, error: itemsError } = await client
    .from(RECIPE_ITEMS_TABLE)
    .select("id, recipe_id, ingredient_id, quantity, unit, position")
    .eq("recipe_id", (recipe as RecipeRow).id)
    .order("position", { ascending: true });

  if (itemsError) {
    throw APIError.internal(itemsError.message);
  }

  const typedItems = (items as RecipeItemRow[]) ?? [];
  if (!typedItems.length) {
    throw APIError.failedPrecondition("Recipe has no ingredient definitions");
  }

  return { recipe: recipe as RecipeRow, items: typedItems };
};

const fetchIngredientMap = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientIds: string[]
): Promise<Record<string, IngredientRow>> => {
  if (!ingredientIds.length) {
    return {};
  }

  const { data, error } = await client
    .from(INGREDIENTS_TABLE)
    .select("id, business_owner_id, name, unit, cost_per_unit")
    .eq("business_owner_id", ownerId)
    .in("id", ingredientIds);

  if (error) {
    throw APIError.internal(error.message);
  }

  const rows = (data ?? []) as IngredientRow[];
  const map: Record<string, IngredientRow> = {};
  for (const row of rows) {
    map[row.id] = row;
  }
  return map;
};

const fetchInventoryTotals = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientIds: string[]
): Promise<Record<string, number>> => {
  if (!ingredientIds.length) {
    return {};
  }
  const { data, error } = await client
    .from(INVENTORY_TABLE)
    .select("product_id, available_quantity")
    .eq("business_owner_id", ownerId)
    .in("product_id", ingredientIds);

  if (error) {
    throw APIError.internal(error.message);
  }

  const totals: Record<string, number> = {};
  for (const row of data ?? []) {
    const productId = (row as { product_id: string }).product_id;
    const available = Number((row as { available_quantity: number }).available_quantity ?? 0);
    totals[productId] = (totals[productId] ?? 0) + available;
  }
  return totals;
};

export const buildProductionPlan = async (
  client: SupabaseClient,
  ownerId: string,
  productId: string,
  batches: number
): Promise<ProductionPlanComputation> => {
  const quantity = ensurePositiveNumber(batches, "quantity");
  const product = await fetchProduct(client, ownerId, productId);
  const { recipe, items } = await fetchRecipeWithItems(client, ownerId, productId);

  const ingredientIds = Array.from(new Set(items.map((item) => item.ingredient_id)));
  const ingredientMap = await fetchIngredientMap(client, ownerId, ingredientIds);
  if (ingredientIds.some((id) => !ingredientMap[id])) {
    throw APIError.failedPrecondition("Recipe references an ingredient that does not exist");
  }
  const stockTotals = await fetchInventoryTotals(client, ownerId, ingredientIds);

  const unitsPerBatch =
    recipe.yield_quantity && Number(recipe.yield_quantity) > 0 ? Number(recipe.yield_quantity) : 1;

  const materials: MaterialPlan[] = [];
  let totalCostPerBatch = 0;

  for (const item of items) {
    const ingredient = ingredientMap[item.ingredient_id];
    const ingredientCost = Number(ingredient.cost_per_unit ?? 0);
    const perBatchQty = Number(item.quantity ?? 0);
    totalCostPerBatch += ingredientCost * perBatchQty;

    const quantityNeeded = perBatchQty * quantity;
    const currentStock = stockTotals[item.ingredient_id] ?? 0;
    const shortage = Math.max(0, quantityNeeded - currentStock);
    materials.push({
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      quantityNeeded: Number(quantityNeeded.toFixed(4)),
      usageUnit: item.unit,
      currentStock: Number(currentStock.toFixed(4)),
      stockUnit: ingredient.unit,
      isSufficient: shortage === 0,
      shortage: Number(shortage.toFixed(4)),
      convertedQuantity: Number(quantityNeeded.toFixed(4)),
    });
  }

  const totalUnits = Number((unitsPerBatch * quantity).toFixed(3));
  const totalProductionCost = Number((totalCostPerBatch * quantity).toFixed(4));

  const shortageItems = materials
    .filter((item) => !item.isSufficient)
    .map((item) => ({
      ingredientId: item.ingredientId,
      ingredientName: item.ingredientName,
      shortageQty: Number(item.shortage.toFixed(4)),
      unit: item.usageUnit,
    }));

  const allSufficient = materials.every((item) => item.isSufficient);

  const plan: ProductionPlanData = {
    product: {
      id: product.id,
      name: product.name,
      unitsPerBatch,
      totalCostPerBatch: Number(totalCostPerBatch.toFixed(4)),
    },
    quantity,
    totalUnits,
    materialsNeeded: materials,
    allStockSufficient: allSufficient,
    canProduce: allSufficient,
    shortageItems,
    totalProductionCost,
  };

  return { plan, recipe, recipeItems: items, ingredientMap };
};

export const fetchIngredientBatches = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientId: string
): Promise<InventoryBatchRow[]> => {
  const { data, error } = await client
    .from(INVENTORY_TABLE)
    .select("id, product_id, available_quantity, cost_per_unit, created_at")
    .eq("business_owner_id", ownerId)
    .eq("product_id", ingredientId)
    .order("created_at", { ascending: true });

  if (error) {
    throw APIError.internal(error.message);
  }

  return (data ?? []) as InventoryBatchRow[];
};

export const consumeIngredientStock = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientId: string,
  requiredQuantity: number
): Promise<{ batches: BatchConsumption[]; totalCost: number }> => {
  const batches = await fetchIngredientBatches(client, ownerId, ingredientId);
  let remaining = Number(requiredQuantity.toFixed(4));
  const updates: BatchConsumption[] = [];

  for (const batch of batches) {
    if (remaining <= 0) {
      break;
    }
    const available = Number(batch.available_quantity ?? 0);
    if (available <= 0) {
      continue;
    }
    const deduction = Math.min(available, remaining);
    remaining -= deduction;
    updates.push({
      batchId: batch.id,
      quantity: deduction,
      unitCost: Number(batch.cost_per_unit ?? 0),
      remainingBatchQuantity: Number((available - deduction).toFixed(4)),
    });
  }

  if (remaining > 0) {
    throw APIError.resourceExhausted(
      `Insufficient ingredient stock for ${ingredientId}; short by ${Number(remaining.toFixed(4))}`
    );
  }

  const timestamp = new Date().toISOString();
  for (const update of updates) {
    const { error } = await client
      .from(INVENTORY_TABLE)
      .update({
        available_quantity: update.remainingBatchQuantity,
        updated_at: timestamp,
      })
      .eq("business_owner_id", ownerId)
      .eq("id", update.batchId);

    if (error) {
      throw APIError.internal(error.message);
    }
  }

  const totalCost = updates.reduce((sum, record) => sum + record.quantity * record.unitCost, 0);
  return { batches: updates, totalCost: Number(totalCost.toFixed(4)) };
};

export const recordInventoryMovements = async (
  client: SupabaseClient,
  ownerId: string,
  rows: Array<{
    batchId: string | null;
    productId: string;
    type: "in" | "out";
    quantity: number;
    note: string;
  }>
): Promise<void> => {
  if (!rows.length) {
    return;
  }
  const payload = rows.map((row) => ({
    business_owner_id: ownerId,
    batch_id: row.batchId,
    product_id: row.productId,
    type: row.type,
    qty: row.quantity,
    note: row.note,
  }));
  const { error } = await client.from(INVENTORY_MOVEMENTS_TABLE).insert(payload);
  if (error) {
    throw APIError.internal(error.message);
  }
};

export const insertUsageRecords = async (
  client: SupabaseClient,
  ownerId: string,
  productionBatchId: string,
  usage: IngredientUsageRecord[]
): Promise<void> => {
  if (!usage.length) {
    return;
  }
  const rows = usage.map((item) => ({
    business_owner_id: ownerId,
    production_batch_id: productionBatchId,
    ingredient_id: item.ingredientId,
    quantity: Number(item.quantity.toFixed(4)),
    unit: item.unit,
    cost: Number(item.cost.toFixed(4)),
  }));
  const { error } = await client.from(PRODUCTION_USAGE_TABLE).insert(rows);
  if (error) {
    throw APIError.internal(error.message);
  }
};

