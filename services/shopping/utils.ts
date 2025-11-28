import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type { ShoppingItemInput, ShoppingListItem } from "./types";

export const SHOPPING_TABLE = "shopping_list";

export interface ShoppingListRow {
  id: string;
  business_owner_id: string;
  ingredient_id: string;
  ingredient_name: string;
  shortage_qty: number;
  unit: string;
  notes: string | null;
  linked_production_batch: string | null;
  is_purchased: boolean;
  created_at: string;
  updated_at: string;
}

export interface ShoppingListOperationResult {
  added: number;
  merged: number;
  list: ShoppingListRow[];
}

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

export const mapShoppingItem = (row: ShoppingListRow): ShoppingListItem => ({
  id: row.id,
  ingredientId: row.ingredient_id,
  ingredientName: row.ingredient_name,
  shortageQty: Number(row.shortage_qty ?? 0),
  unit: row.unit,
  notes: row.notes ?? undefined,
  linkedProductionBatch: row.linked_production_batch ?? undefined,
  isPurchased: row.is_purchased,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const fetchShoppingList = async (
  client: SupabaseClient,
  ownerId: string
): Promise<ShoppingListRow[]> => {
  const { data, error } = await client
    .from(SHOPPING_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("is_purchased", false)
    .order("created_at", { ascending: true });

  if (error) {
    throw APIError.internal(error.message);
  }

  return (data ?? []) as ShoppingListRow[];
};

export const addItemsToShoppingList = async (
  client: SupabaseClient,
  ownerId: string,
  items: ShoppingItemInput[]
): Promise<ShoppingListOperationResult> => {
  let added = 0;
  let merged = 0;
  const timestamp = new Date().toISOString();

  for (const item of items) {
    const { data: existing, error: existingError } = await client
      .from(SHOPPING_TABLE)
      .select("id, shortage_qty, notes")
      .eq("business_owner_id", ownerId)
      .eq("ingredient_id", item.ingredientId)
      .eq("is_purchased", false)
      .maybeSingle();

    if (existingError) {
      throw APIError.internal(existingError.message);
    }

    if (existing) {
      const currentQty = Number((existing as { shortage_qty: number }).shortage_qty ?? 0);
      const newQty = Number((currentQty + item.shortageQty).toFixed(4));
      const { error: updateError } = await client
        .from(SHOPPING_TABLE)
        .update({
          shortage_qty: newQty,
          notes: item.notes ? item.notes : existing.notes ?? null,
          updated_at: timestamp,
        })
        .eq("id", existing.id)
        .eq("business_owner_id", ownerId);

      if (updateError) {
        throw APIError.internal(updateError.message);
      }
      merged += 1;
      continue;
    }

    const { error: insertError } = await client.from(SHOPPING_TABLE).insert({
      business_owner_id: ownerId,
      ingredient_id: item.ingredientId,
      ingredient_name: item.ingredientName,
      shortage_qty: Number(item.shortageQty.toFixed(4)),
      unit: item.unit,
      notes: item.notes ?? null,
      linked_production_batch: item.linkedProductionBatch ?? null,
      is_purchased: false,
      created_at: timestamp,
      updated_at: timestamp,
    });

    if (insertError) {
      throw APIError.internal(insertError.message);
    }
    added += 1;
  }

  const list = await fetchShoppingList(client, ownerId);
  return { added, merged, list };
};

export const fetchShoppingItem = async (
  client: SupabaseClient,
  ownerId: string,
  itemId: string
): Promise<ShoppingListRow> => {
  const { data, error } = await client
    .from(SHOPPING_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", itemId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Shopping list item not found");
  }
  return data as ShoppingListRow;
};

export const markItemAsPurchased = async (
  client: SupabaseClient,
  ownerId: string,
  itemId: string
): Promise<ShoppingListRow> => {
  const timestamp = new Date().toISOString();
  const { data, error } = await client
    .from(SHOPPING_TABLE)
    .update({
      is_purchased: true,
      updated_at: timestamp,
    })
    .eq("business_owner_id", ownerId)
    .eq("id", itemId)
    .select("*")
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Shopping list item not found");
  }
  return data as ShoppingListRow;
};

export const removeShoppingItem = async (
  client: SupabaseClient,
  ownerId: string,
  itemId: string
): Promise<void> => {
  const { error } = await client
    .from(SHOPPING_TABLE)
    .delete()
    .eq("business_owner_id", ownerId)
    .eq("id", itemId);

  if (error) {
    throw APIError.internal(error.message);
  }
};

export const normalizeShoppingItems = (items: ShoppingItemInput[]): ShoppingItemInput[] => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("items must contain at least one ingredient");
  }

  return items.map((item, index) => {
    const ingredientId = sanitizeString(item.ingredientId);
    const ingredientName = sanitizeString(item.ingredientName);
    const unit = sanitizeString(item.unit);
    if (!ingredientId) {
      throw APIError.invalidArgument(`items[${index}].ingredientId is required`);
    }
    if (!ingredientName) {
      throw APIError.invalidArgument(`items[${index}].ingredientName is required`);
    }
    if (!unit) {
      throw APIError.invalidArgument(`items[${index}].unit is required`);
    }

    return {
      ingredientId,
      ingredientName,
      shortageQty: ensurePositiveNumber(item.shortageQty, `items[${index}].shortageQty`),
      unit,
      notes: sanitizeString(item.notes) ?? undefined,
      linkedProductionBatch: sanitizeString(item.linkedProductionBatch) ?? null,
    };
  });
};

