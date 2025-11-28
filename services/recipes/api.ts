import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import {
  AddRecipeItemsRequest,
  AddRecipeRequest,
  GetRecipeRequest,
  ListRecipesRequest,
  RecipeDetailData,
  RecipeDetailResponse,
  RecipeItemInput,
  RecipeListResponse,
  RecipeUpdateRequest,
} from "./types";
import {
  INGREDIENTS_TABLE,
  NormalizedRecipeItem,
  PRODUCTS_TABLE,
  RECIPES_TABLE,
  RECIPE_ITEMS_TABLE,
  RecipeItemRow,
  RecipeRow,
  computeRecipeCost,
  mapRecipeRow,
  normalizeRecipeInput,
  normalizeRecipeItems,
  normalizeRecipeUpdate,
} from "./utils";

interface DbError {
  code?: string;
  message?: string;
  details?: string | null;
}

interface RecipeItemWithIngredient extends RecipeItemRow {
  ingredient?: {
    id: string;
    name: string;
    unit: string;
    cost_per_unit: number | null;
  } | null;
}

const translateDbError = (error: DbError | null | undefined, fallback?: string): never => {
  if (error?.code === "PGRST116" && fallback) {
    throw APIError.notFound(fallback);
  }
  throw APIError.internal(error?.message ?? "Unexpected database error");
};

const ensureProductOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  productId?: string
): Promise<void> => {
  if (!productId) {
    return;
  }

  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id")
    .eq("business_owner_id", ownerId)
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    translateDbError(error, `Product ${productId} not found`);
  }

  if (!data) {
    throw APIError.notFound(`Product ${productId} not found`);
  }
};

const fetchIngredientMap = async (
  client: SupabaseClient,
  ownerId: string,
  ingredientIds: string[]
) => {
  const uniqueIds = Array.from(new Set(ingredientIds));
  if (!uniqueIds.length) {
    throw APIError.invalidArgument("At least one ingredient is required");
  }

  const { data, error } = await client
    .from(INGREDIENTS_TABLE)
    .select("id, name, unit, cost_per_unit")
    .eq("business_owner_id", ownerId)
    .in("id", uniqueIds);

  if (error) {
    translateDbError(error);
  }

  const rows = data ?? [];
  if (rows.length !== uniqueIds.length) {
    throw APIError.invalidArgument("One or more ingredients do not exist");
  }

  const map = new Map<string, { name: string; unit: string; costPerUnit: number }>();
  for (const row of rows) {
    map.set(row.id, {
      name: row.name,
      unit: row.unit,
      costPerUnit: Number(row.cost_per_unit ?? 0),
    });
  }
  return map;
};

const ensureRecipeOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string
): Promise<RecipeRow> => {
  const { data, error } = await client
    .from(RECIPES_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", recipeId)
    .single();

  if (error) {
    translateDbError(error, `Recipe ${recipeId} not found`);
  }

  const row = data as RecipeRow | null;
  if (!row) {
    throw APIError.notFound(`Recipe ${recipeId} not found`);
  }

  return row;
};

const fetchRecipeItems = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string
): Promise<RecipeItemWithIngredient[]> => {
  const { data, error } = await client
    .from(RECIPE_ITEMS_TABLE)
    .select(
      "id, business_owner_id, recipe_id, ingredient_id, quantity, unit, position, ingredient:ingredients(id,name,unit,cost_per_unit)"
    )
    .eq("business_owner_id", ownerId)
    .eq("recipe_id", recipeId)
    .order("position", { ascending: true });

  if (error) {
    translateDbError(error);
  }

  const rows = (data ?? []) as Array<
    RecipeItemRow & { ingredient?: RecipeItemWithIngredient["ingredient"] | RecipeItemWithIngredient["ingredient"][] }
  >;

  return rows.map((row) => {
    const ingredientData = Array.isArray(row.ingredient)
      ? row.ingredient[0]
      : row.ingredient;

    return {
      ...row,
      ingredient: ingredientData ?? null,
    };
  });
};

const buildRecipeDetail = (
  recipeRow: RecipeRow,
  items: RecipeItemWithIngredient[]
): RecipeDetailData => {
  const mappedItems = items.map((item) => {
    const ingredient = item.ingredient;
    const costPerUnit = Number(ingredient?.cost_per_unit ?? 0);
    const quantity = Number(item.quantity ?? 0);
    return {
      itemId: item.id,
      ingredientId: item.ingredient_id,
      ingredientName: ingredient?.name ?? "Unknown ingredient",
      unit: item.unit,
      quantity,
      costPerUnit,
      totalCost: quantity * costPerUnit,
      position: item.position ?? 0,
    };
  });

  const totalCost = mappedItems.reduce((sum, item) => sum + item.totalCost, 0);
  const recipe = mapRecipeRow({ ...recipeRow, total_cost: totalCost });
  const costPerServing =
    recipe.yieldQuantity && recipe.yieldQuantity > 0
      ? totalCost / recipe.yieldQuantity
      : undefined;

  return {
    recipe: { ...recipe, totalCost },
    items: mappedItems,
    totalCost,
    costPerServing,
  };
};

const getRecipeDetail = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string
): Promise<RecipeDetailData> => {
  const recipeRow = await ensureRecipeOwnership(client, ownerId, recipeId);
  const items = await fetchRecipeItems(client, ownerId, recipeId);
  return buildRecipeDetail(recipeRow, items);
};

const updateRecipeTotalCost = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string,
  totalCost: number
) => {
  const { error } = await client
    .from(RECIPES_TABLE)
    .update({
      total_cost: totalCost,
      updated_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .eq("id", recipeId);

  if (error) {
    translateDbError(error);
  }
};

const recomputeRecipeTotals = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string
): Promise<RecipeDetailData> => {
  const detail = await getRecipeDetail(client, ownerId, recipeId);
  await updateRecipeTotalCost(client, ownerId, recipeId, detail.totalCost);
  return detail;
};

const insertRecipeItems = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string,
  items: NormalizedRecipeItem[],
  startPosition = 0
): Promise<void> => {
  if (!items.length) {
    return;
  }

  const payload = items.map((item, index) => ({
    business_owner_id: ownerId,
    recipe_id: recipeId,
    ingredient_id: item.ingredientId,
    quantity: item.quantity,
    unit: item.unit,
    position: startPosition + index,
  }));

  const { error } = await client.from(RECIPE_ITEMS_TABLE).insert(payload);
  if (error) {
    translateDbError(error);
  }
};

const fetchNextItemPosition = async (
  client: SupabaseClient,
  ownerId: string,
  recipeId: string
): Promise<number> => {
  const { data, error } = await client
    .from(RECIPE_ITEMS_TABLE)
    .select("position")
    .eq("business_owner_id", ownerId)
    .eq("recipe_id", recipeId)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    translateDbError(error);
  }

  return (data?.position ?? 0) + 1;
};

const ensureIngredientCosts = async (
  client: SupabaseClient,
  ownerId: string,
  items: NormalizedRecipeItem[]
): Promise<{ totalCost: number }> => {
  const ingredientMap = await fetchIngredientMap(
    client,
    ownerId,
    items.map((item) => item.ingredientId)
  );

  const totalCost = computeRecipeCost(
    items.map((item) => ({
      quantity: item.quantity,
      cost: ingredientMap.get(item.ingredientId)?.costPerUnit ?? 0,
    }))
  );

  return { totalCost };
};

export const addRecipe = api<AddRecipeRequest, RecipeDetailResponse>(
  {
    method: "POST",
    path: "/recipes/add",
  },
  async ({ authorization, recipe }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = normalizeRecipeInput(recipe);

    await ensureProductOwnership(client, ownerId, normalized.productId);
    const { totalCost } = await ensureIngredientCosts(client, ownerId, normalized.items);

    const { data, error } = await client
      .from(RECIPES_TABLE)
      .insert({
        business_owner_id: ownerId,
        product_id: normalized.productId ?? null,
        name: normalized.name,
        yield_quantity: normalized.yieldQuantity ?? null,
        yield_unit: normalized.yieldUnit ?? null,
        total_cost: totalCost,
      })
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const recipeRow = data as RecipeRow | null;
    if (!recipeRow) {
      throw APIError.internal("Unable to create recipe");
    }

    try {
      await insertRecipeItems(client, ownerId, recipeRow.id, normalized.items);
    } catch (err) {
      await client.from(RECIPES_TABLE).delete().eq("id", recipeRow.id);
      throw err;
    }

    const detail = await recomputeRecipeTotals(client, ownerId, recipeRow.id);
    return { success: true, data: detail };
  }
);

export const addRecipeItems = api<
  AddRecipeItemsRequest,
  RecipeDetailResponse
>(
  {
    method: "POST",
    path: "/recipes/items/add",
  },
  async ({ authorization, recipeId, items }) => {
    const sanitizedRecipeId = recipeId.trim();
    if (!sanitizedRecipeId) {
      throw APIError.invalidArgument("recipeId is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    await ensureRecipeOwnership(client, ownerId, sanitizedRecipeId);

    const normalizedItems = normalizeRecipeItems(items);
    await ensureIngredientCosts(client, ownerId, normalizedItems);

    const startPosition = await fetchNextItemPosition(
      client,
      ownerId,
      sanitizedRecipeId
    );
    await insertRecipeItems(
      client,
      ownerId,
      sanitizedRecipeId,
      normalizedItems,
      startPosition
    );

    const detail = await recomputeRecipeTotals(client, ownerId, sanitizedRecipeId);
    return { success: true, data: detail };
  }
);

export const listRecipes = api<ListRecipesRequest, RecipeListResponse>(
  {
    method: "GET",
    path: "/recipes/list",
  },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(RECIPES_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("updated_at", { ascending: false });

    if (error) {
      translateDbError(error);
    }

    const recipes = ((data ?? []) as RecipeRow[]).map(mapRecipeRow);
    return { success: true, data: { recipes } };
  }
);

export const getRecipe = api<GetRecipeRequest, RecipeDetailResponse>(
  {
    method: "GET",
    path: "/recipes/:id",
  },
  async ({ authorization, id }) => {
    const sanitizedId = id.trim();
    if (!sanitizedId) {
      throw APIError.invalidArgument("id is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    const detail = await getRecipeDetail(client, ownerId, sanitizedId);
    return { success: true, data: detail };
  }
);

export const updateRecipe = api<RecipeUpdateRequest, RecipeDetailResponse>(
  {
    method: "PUT",
    path: "/recipes/update",
  },
  async ({ authorization, recipeId, recipe }) => {
    const trimmedId = recipeId.trim();
    if (!trimmedId) {
      throw APIError.invalidArgument("recipeId is required");
    }

    const { client, ownerId } = resolveAuthContext(authorization);
    await ensureRecipeOwnership(client, ownerId, trimmedId);

    const normalized = normalizeRecipeUpdate(recipe);

    if (normalized.productId) {
      await ensureProductOwnership(client, ownerId, normalized.productId);
    }

    const payload: Record<string, unknown> = {};
    if (normalized.name !== undefined) {
      payload.name = normalized.name;
    }
    if (normalized.productId !== undefined) {
      payload.product_id = normalized.productId ?? null;
    }
    if (normalized.yieldQuantity !== undefined) {
      payload.yield_quantity = normalized.yieldQuantity ?? null;
    }
    if (normalized.yieldUnit !== undefined) {
      payload.yield_unit = normalized.yieldUnit ?? null;
    }
    payload.updated_at = new Date().toISOString();

    const { error } = await client
      .from(RECIPES_TABLE)
      .update(payload)
      .eq("business_owner_id", ownerId)
      .eq("id", trimmedId);

    if (error) {
      translateDbError(error);
    }

    // TODO(p2): Support updating and removing existing recipe items in this endpoint.
    const detail = await recomputeRecipeTotals(client, ownerId, trimmedId);
    return { success: true, data: detail };
  }
);