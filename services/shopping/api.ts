import { api, APIError, type Header } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import type {
  AddFromProductionRequest,
  AddFromProductionResponse,
  MarkPurchasedRequest,
  MarkPurchasedResponse,
  RemoveItemRequest,
  RemoveItemResponse,
  ShoppingListResponse,
} from "./types";
import {
  addItemsToShoppingList,
  fetchShoppingItem,
  fetchShoppingList,
  mapShoppingItem,
  markItemAsPurchased,
  normalizeShoppingItems,
  removeShoppingItem,
  sanitizeString,
} from "./utils";

export const addFromProduction = api<AddFromProductionRequest, AddFromProductionResponse>(
  { method: "POST", path: "/shopping/add-from-production" },
  async ({ authorization, items }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedItems = normalizeShoppingItems(items);

    const result = await addItemsToShoppingList(client, ownerId, normalizedItems);
    return {
      success: true,
      data: {
        added: result.added,
        merged: result.merged,
        totalItems: result.list.length,
        items: result.list.map(mapShoppingItem),
      },
    };
  }
);

export const listShoppingItems = api<AuthorizedOnly, ShoppingListResponse>(
  { method: "GET", path: "/shopping/list" },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const rows = await fetchShoppingList(client, ownerId);
    return { success: true, data: { items: rows.map(mapShoppingItem) } };
  }
);

export const markPurchased = api<MarkPurchasedRequest, MarkPurchasedResponse>(
  { method: "POST", path: "/shopping/mark-purchased" },
  async ({ authorization, itemId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedId = sanitizeString(itemId);
    if (!normalizedId) {
      throw APIError.invalidArgument("itemId is required");
    }

    await fetchShoppingItem(client, ownerId, normalizedId);
    const updated = await markItemAsPurchased(client, ownerId, normalizedId);

    return { success: true, data: { item: mapShoppingItem(updated) } };
  }
);

export const removeShoppingItemApi = api<RemoveItemRequest, RemoveItemResponse>(
  { method: "DELETE", path: "/shopping/remove" },
  async ({ authorization, itemId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedId = sanitizeString(itemId);
    if (!normalizedId) {
      throw APIError.invalidArgument("itemId is required");
    }

    await fetchShoppingItem(client, ownerId, normalizedId);
    await removeShoppingItem(client, ownerId, normalizedId);
    return { success: true };
  }
);

interface AuthorizedOnly {
  authorization: Header<"Authorization">;
}

