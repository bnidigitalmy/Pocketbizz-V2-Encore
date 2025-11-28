import type { SupabaseClient } from "@supabase/supabase-js";
import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { Product } from "../../pkg/types";
import {
  AddProductRequest,
  DeleteProductRequest,
  DeleteProductResponse,
  GetProductRequest,
  ListProductsRequest,
  ProductCreate,
  ProductListResponse,
  ProductResponse,
  ProductUpdate,
  UpdateProductRequest,
} from "./types";

const PRODUCTS_TABLE = "products";

interface ProductRow {
  id: string;
  business_owner_id: string;
  sku: string;
  name: string;
  description: string | null;
  category: string | null;
  unit: string;
  cost_price: number;
  sale_price: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

interface DbError {
  code?: string;
  message?: string;
  details?: string | null;
}

const sanitizeString = (value?: string): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

const ensureRequiredString = (value: string | undefined, field: string): string => {
  const sanitized = sanitizeString(value);
  if (!sanitized) {
    throw APIError.invalidArgument(`${field} is required`);
  }
  return sanitized;
};

const ensureMoney = (value: number | undefined, field: string): number => {
  if (value === undefined || value === null || Number.isNaN(value)) {
    throw APIError.invalidArgument(`${field} must be provided`);
  }
  if (value < 0) {
    throw APIError.invalidArgument(`${field} must be zero or greater`);
  }
  return Number(value);
};

const validateProductCreate = (input: ProductCreate): ProductCreate => ({
  sku: ensureRequiredString(input.sku, "sku"),
  name: ensureRequiredString(input.name, "name"),
  unit: ensureRequiredString(input.unit, "unit"),
  description: sanitizeString(input.description),
  category: sanitizeString(input.category),
  costPrice: ensureMoney(input.costPrice, "costPrice"),
  salePrice: ensureMoney(input.salePrice, "salePrice"),
  isActive: input.isActive ?? true,
});

const validateProductUpdate = (input: ProductUpdate): ProductUpdate => {
  const normalized: ProductUpdate = {
    id: ensureRequiredString(input.id, "id"),
  };

  if (input.sku !== undefined) {
    normalized.sku = ensureRequiredString(input.sku, "sku");
  }
  if (input.name !== undefined) {
    normalized.name = ensureRequiredString(input.name, "name");
  }
  if (input.unit !== undefined) {
    normalized.unit = ensureRequiredString(input.unit, "unit");
  }
  if (input.description !== undefined) {
    normalized.description = sanitizeString(input.description);
  }
  if (input.category !== undefined) {
    normalized.category = sanitizeString(input.category);
  }
  if (input.costPrice !== undefined) {
    normalized.costPrice = ensureMoney(input.costPrice, "costPrice");
  }
  if (input.salePrice !== undefined) {
    normalized.salePrice = ensureMoney(input.salePrice, "salePrice");
  }
  if (input.isActive !== undefined) {
    normalized.isActive = Boolean(input.isActive);
  }

  if (Object.keys(normalized).length === 1) {
    throw APIError.invalidArgument("At least one field must be provided to update");
  }

  return normalized;
};

const buildInsertPayload = (
  product: ProductCreate,
  ownerId: string
): Omit<ProductRow, "id" | "created_at" | "updated_at"> => ({
  business_owner_id: ownerId,
  sku: product.sku,
  name: product.name,
  description: product.description ?? null,
  category: product.category ?? null,
  unit: product.unit,
  cost_price: product.costPrice,
  sale_price: product.salePrice,
  is_active: product.isActive ?? true,
});

const buildUpdatePayload = (product: ProductUpdate): Partial<ProductRow> => {
  const payload: Partial<ProductRow> = {};

  if (product.sku !== undefined) payload.sku = product.sku;
  if (product.name !== undefined) payload.name = product.name;
  if (product.description !== undefined)
    payload.description = product.description ?? null;
  if (product.category !== undefined) payload.category = product.category ?? null;
  if (product.unit !== undefined) payload.unit = product.unit;
  if (product.costPrice !== undefined) payload.cost_price = product.costPrice;
  if (product.salePrice !== undefined) payload.sale_price = product.salePrice;
  if (product.isActive !== undefined) payload.is_active = product.isActive;

  if (Object.keys(payload).length === 0) {
    throw APIError.invalidArgument("No product fields provided to update");
  }

  payload.updated_at = new Date().toISOString();
  return payload;
};

const translateDbError = (error: DbError | null | undefined, notFoundMessage?: string): never => {
  if (error?.code === "PGRST116" && notFoundMessage) {
    throw APIError.notFound(notFoundMessage);
  }

  if (error?.code === "23505") {
    throw APIError.alreadyExists("A product with the same SKU already exists");
  }

  throw APIError.internal(error?.message ?? "Unexpected database error");
};

const mapProductRow = (row: ProductRow): Product => ({
  id: row.id,
  ownerId: row.business_owner_id,
  sku: row.sku,
  name: row.name,
  description: row.description ?? undefined,
  category: row.category ?? undefined,
  unit: row.unit,
  costPrice: Number(row.cost_price),
  salePrice: Number(row.sale_price),
  isActive: Boolean(row.is_active),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const ensureProductExists = async (
  client: SupabaseClient,
  id: string
): Promise<ProductRow> => {
  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("*")
    .eq("id", id)
    .eq("is_active", true)
    .single();

  if (error) {
    translateDbError(error, `Product ${id} not found`);
  }

  const row = data as ProductRow | null;
  if (!row) {
    throw APIError.notFound(`Product ${id} not found`);
  }

  return row;
};

export const addProduct = api<AddProductRequest, ProductResponse>(
  {
    method: "POST",
    path: "/products/add",
  },
  async ({ authorization, product }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = validateProductCreate(product);

    const { data, error } = await client
      .from(PRODUCTS_TABLE)
      .insert(buildInsertPayload(normalized, ownerId))
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const row = data as ProductRow | null;
    if (!row) {
      throw APIError.internal("Unable to create product");
    }

    return { product: mapProductRow(row) };
  }
);

export const listProducts = api<ListProductsRequest, ProductListResponse>(
  {
    method: "GET",
    path: "/products/list",
  },
  async ({ authorization }) => {
    const { client } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(PRODUCTS_TABLE)
      .select("*")
      .eq("is_active", true)
      .order("created_at", { ascending: false });

    if (error) {
      translateDbError(error);
    }

    const rows = (data ?? []) as ProductRow[];
    return { products: rows.map(mapProductRow) };
  }
);

export const getProduct = api<GetProductRequest, ProductResponse>(
  {
    method: "GET",
    path: "/products/:id",
  },
  async ({ authorization, id }) => {
    const { client } = resolveAuthContext(authorization);
    const row = await ensureProductExists(client, id);
    return { product: mapProductRow(row) };
  }
);

export const updateProduct = api<UpdateProductRequest, ProductResponse>(
  {
    method: "PUT",
    path: "/products/update",
  },
  async ({ authorization, product }) => {
    const { client } = resolveAuthContext(authorization);
    const normalized = validateProductUpdate(product);

    await ensureProductExists(client, normalized.id);

    const updatePayload = buildUpdatePayload(normalized);
    const { data, error } = await client
      .from(PRODUCTS_TABLE)
      .update(updatePayload)
      .eq("id", normalized.id)
      .select("*")
      .single();

    if (error) {
      translateDbError(error);
    }

    const row = data as ProductRow | null;
    if (!row) {
      throw APIError.internal("Unable to update product");
    }

    return { product: mapProductRow(row) };
  }
);

export const deleteProduct = api<DeleteProductRequest, DeleteProductResponse>(
  {
    method: "DELETE",
    path: "/products/delete",
  },
  async ({ authorization, productId }) => {
    const trimmedId = sanitizeString(productId);
    if (!trimmedId) {
      throw APIError.invalidArgument("productId is required");
    }

    const { client } = resolveAuthContext(authorization);
    await ensureProductExists(client, trimmedId);

    const { error } = await client
      .from(PRODUCTS_TABLE)
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("id", trimmedId);

    if (error) {
      translateDbError(error);
    }

    return { success: true };
  }
);