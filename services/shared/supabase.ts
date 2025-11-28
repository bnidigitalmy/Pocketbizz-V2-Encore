import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { secret } from "encore.dev/config";

const supabaseUrl = secret("SUPABASE_URL");
const supabaseAnonKey = secret("SUPABASE_ANON_KEY");
const supabaseServiceKey = secret("SUPABASE_SERVICE_KEY");

export class SupabaseError extends Error {
  constructor(
    public readonly operation: string,
    public readonly table: string,
    public readonly cause?: unknown
  ) {
    super(`Supabase ${operation} failed on ${table}`);
  }
}

type FilterValue = string | number | boolean | null;
export interface QueryFilters {
  match?: Record<string, FilterValue>;
  eq?: Record<string, FilterValue>;
  order?: { column: string; ascending?: boolean };
  limit?: number;
}

export const getClient = (authUserId?: string): SupabaseClient => {
  const key = authUserId ? supabaseAnonKey() : supabaseServiceKey();

  const client = createClient(supabaseUrl(), key, {
    auth: {
      persistSession: false,
      detectSessionInUrl: false,
      autoRefreshToken: false,
    },
  });

  if (authUserId) {
    client.auth.setSession({
      access_token: authUserId,
      refresh_token: authUserId,
    });
  }

  return client;
};

const handleError = (
  operation: string,
  table: string,
  error: unknown
): never => {
  throw new SupabaseError(operation, table, error);
};

export const select = async <T = unknown>(
  table: string,
  filters?: QueryFilters,
  client: SupabaseClient = getClient()
): Promise<T[]> => {
  let query = client.from(table).select("*");

  if (filters?.match) {
    query = query.match(filters.match);
  }
  if (filters?.eq) {
    for (const [column, value] of Object.entries(filters.eq)) {
      query = query.eq(column, value);
    }
  }
  if (filters?.order) {
    query = query.order(filters.order.column, {
      ascending: filters.order.ascending ?? true,
    });
  }
  if (filters?.limit) {
    query = query.limit(filters.limit);
  }

  const { data, error } = await query;
  if (error) {
    handleError("select", table, error);
  }
  return (data ?? []) as T[];
};

export const insert = async <T extends Record<string, unknown>>(
  table: string,
  payload: T,
  client: SupabaseClient = getClient()
): Promise<void> => {
  const { error } = await client.from(table).insert(payload);
  if (error) {
    handleError("insert", table, error);
  }
};

export const update = async <T extends Record<string, FilterValue>>(
  table: string,
  id: string,
  payload: T,
  client: SupabaseClient = getClient()
): Promise<void> => {
  const { error } = await client.from(table).update(payload).eq("id", id);
  if (error) {
    handleError("update", table, error);
  }
};

export const remove = async (
  table: string,
  id: string,
  client: SupabaseClient = getClient()
): Promise<void> => {
  const { error } = await client.from(table).delete().eq("id", id);
  if (error) {
    handleError("delete", table, error);
  }
};

export interface FileUploadOptions {
  bucket: string;
  path: string;
  file: ArrayBuffer | Buffer | Blob | Uint8Array | string;
  contentType?: string;
  upsert?: boolean;
}

export const uploadReceiptFile = async (
  options: FileUploadOptions,
  client: SupabaseClient = getClient()
): Promise<string> => {
  const { data, error } = await client.storage
    .from(options.bucket)
    .upload(options.path, options.file, {
      contentType: options.contentType,
      upsert: options.upsert ?? false,
    });

  if (error) {
    handleError("upload", options.bucket, error);
  }

  return data?.path ?? options.path;
};

export const supabaseSelect = select;
export const supabaseInsert = insert;
export const supabaseUpdate = update;
export const supabaseRemove = remove;
export const supabaseUploadFile = uploadReceiptFile;

export const supabaseQuery = async <T>(
  queryFn: (client: SupabaseClient) => Promise<T>
): Promise<T> => {
  const client = getClient();
  return queryFn(client);
};

