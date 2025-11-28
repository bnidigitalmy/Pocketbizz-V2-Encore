import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { Ingredient } from "../../pkg/types";
import {
  AddIngredientRequest,
  DeleteIngredientRequest,
  DeleteIngredientResponse,
  GetIngredientRequest,
  IngredientCreate,
  IngredientListResponse,
  IngredientResponse,
  IngredientUpdate,
  ListIngredientsRequest,
  UpdateIngredientRequest,
} from "./types";

const INGREDIENTS_TABLE = "ingredients";
const VENDORS_TABLE = "vendors";

interface IngredientRow {
  id: string;
  business_owner_id: string;
  name: string;
  unit: string;
  cost_per_unit: number;
  supplier_id: string | null;
  created_at: string;
  updated_at: string;
}

interface DbError {
  code?: string;
  message?: string;
}

const sanitizeString = (value?: string): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

const requireString = (value: string | undefined, field: string): string => {
  const sanitized = sanitizeString(value);
  if (!sanitized) {
    throw APIError.invalidArgument(`${field} is required`);
  }
  return sanitized;
};

const requireMoney = (value: number | undefined, field: string): number => {
  if (value === undefined || value === null || Number.isNaN(value)) {
    throw APIError.invalidArgument(`${field} must be provided`);
  }
  if (value < 0) {
    throw APIError.invalidArgument(`${field} must be zero or greater`);
  }
  return Number(value);
};

const validateCreate = (input: IngredientCreate): IngredientCreate => ({
  name: requireString(input.name, "name"),
  unit: requireString(input.unit, "unit"),
  costPerUnit: requireMoney(input.costPerUnit, "costPerUnit"),
  vendorId: sanitizeString(input.vendorId),
});

const validateUpdate = (input: IngredientUpdate): IngredientUpdate => {
  const normalized: IngredientUpdate = {
    id: requireString(input.id, "id"),
  };

  if (input.name !== undefined) {
    normalized.name = requireString(input.name, "name");
  }
  if (input.unit !== undefined) {
    normalized.unit = requireString(input.unit, "unit");
  }
  if (input.costPerUnit !== undefined) {
    normalized.costPerUnit = requireMoney(input.costPerUnit, "costPerUnit");
  }
  if (input.vendorId !== undefined) {
    normalized.vendorId = sanitizeString(input.vendorId);
  }

  if (Object.keys(normalized).length === 1) {
    throw APIError.invalidArgument("At least one field must be provided to update");
  }

  return normalized;
};

const buildInsertPayload = (
  ingredient: IngredientCreate,
  ownerId: string
): Omit<IngredientRow, "id" | "created_at" | "updated_at"> => ({
  business_owner_id: ownerId,
  name: ingredient.name,
  unit: ingredient.unit,
  cost_per_unit: ingredient.costPerUnit,
  supplier_id: ingredient.vendorId ?? null,
});

const buildUpdatePayload = (
  ingredient: IngredientUpdate
): Partial<IngredientRow> => {
  const payload: Partial<IngredientRow> = {};

  if (ingredient.name !== undefined) payload.name = ingredient.name;
  if (ingredient.unit !== undefined) payload.unit = ingredient.unit;
  if (ingredient.costPerUnit !== undefined)
    payload.cost_per_unit = ingredient.costPerUnit;
  if (ingredient.vendorId !== undefined)
    payload.supplier_id = ingredient.vendorId ?? null;

  if (Object.keys(payload).length === 0) {
    throw APIError.invalidArgument("No ingredient fields provided to update");
  }

  payload.updated_at = new Date().toISOString();
  return payload;
};

const mapIngredient = (row: IngredientRow): Ingredient => ({
  id: row.id,
  name: row.name,
  unit: row.unit,
  costPerUnit: Number(row.cost_per_unit),
  supplierId: row.supplier_id ?? undefined,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const translateDbError = (error: DbError | null | undefined, notFound?: string): never => {
  if (error?.code === "PGRST116" && notFound) {
    throw APIError.notFound(notFound);
  }
  throw APIError.internal(error?.message ?? "Unexpected database error");
};

// TODO(p2): extend vendor ownership validation with archived vendors once soft delete exists.
const ensureVendorExists = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<void> => {
  const { error } = await client
    .from(VENDORS_TABLE)
    .select("id")
    .eq("id", vendorId)
    .eq("business_owner_id", ownerId)
    .maybeSingle();

  if (error) {
    if (error.code === "PGRST116") {
      throw APIError.invalidArgument("vendorId does not exist");
    }
    translateDbError(error);
  }
};

const ensureIngredientExists = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<IngredientRow> => {
  const { data, error } = await client
    .from(INGREDIENTS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .single();

  if (error) {
    translateDbError(error, `Ingredient ${id} not found`);
  }

  const row = data as IngredientRow | null;
  if (!row) {
    throw APIError.notFound(`Ingredient ${id} not found`);
  }

  return row;
};

export const addIngredient = api<AddIngredientRequest, IngredientResponse>(
  {
    method: "POST",
    path: "/ingredients/add",
  },
  async ({ authorization, ingredient }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = validateCreate(ingredient);

    if (normalized.vendorId) {
      await ensureVendorExists(client, ownerId, normalized.vendorId);
    }

    const { data, error } = await client
      .from(INGREDIENTS_TABLE)
      .insert(buildInsertPayload(normalized, ownerId))
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const row = data as IngredientRow | null;
    if (!row) {
      throw APIError.internal("Unable to create ingredient");
    }

    return { success: true, data: { ingredient: mapIngredient(row) } };
  }
);

export const listIngredients = api<
  ListIngredientsRequest,
  IngredientListResponse
>({
  method: "GET",
  path: "/ingredients/list",
},
async ({ authorization }) => {
  const { client, ownerId } = resolveAuthContext(authorization);
  const { data, error } = await client
    .from(INGREDIENTS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .order("created_at", { ascending: false });

  if (error) {
    translateDbError(error);
  }

  const rows = (data ?? []) as IngredientRow[];
  return { success: true, data: { ingredients: rows.map(mapIngredient) } };
});

export const getIngredient = api<GetIngredientRequest, IngredientResponse>(
  {
    method: "GET",
    path: "/ingredients/:id",
  },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const row = await ensureIngredientExists(client, ownerId, id);
    return { success: true, data: { ingredient: mapIngredient(row) } };
  }
);

export const updateIngredient = api<UpdateIngredientRequest, IngredientResponse>(
  {
    method: "PUT",
    path: "/ingredients/update",
  },
  async ({ authorization, ingredient }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = validateUpdate(ingredient);

    await ensureIngredientExists(client, ownerId, normalized.id);
    if (normalized.vendorId) {
      await ensureVendorExists(client, ownerId, normalized.vendorId);
    }

    const { data, error } = await client
      .from(INGREDIENTS_TABLE)
      .update(buildUpdatePayload(normalized))
      .eq("id", normalized.id)
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const row = data as IngredientRow | null;
    if (!row) {
      throw APIError.internal("Unable to update ingredient");
    }

    return { success: true, data: { ingredient: mapIngredient(row) } };
  }
);

export const deleteIngredient = api<
  DeleteIngredientRequest,
  DeleteIngredientResponse
>({
  method: "DELETE",
  path: "/ingredients/delete",
},
async ({ authorization, ingredientId }) => {
  const trimmedId = sanitizeString(ingredientId);
  if (!trimmedId) {
    throw APIError.invalidArgument("ingredientId is required");
  }

  const { client, ownerId } = resolveAuthContext(authorization);
  await ensureIngredientExists(client, ownerId, trimmedId);

  const { error } = await client
    .from(INGREDIENTS_TABLE)
    .delete()
    .eq("business_owner_id", ownerId)
    .eq("id", trimmedId);

  if (error) {
    translateDbError(error);
  }

  return { success: true };
});

