import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type {
  Booking,
  BookingItem,
  BookingItemInput,
  BookingStatus,
} from "./types";

export const BOOKINGS_TABLE = "bookings";
export const BOOKING_ITEMS_TABLE = "booking_items";
export const CUSTOMERS_TABLE = "customers";
export const PRODUCTS_TABLE = "products";

export const BOOKING_STATUS_VALUES: BookingStatus[] = [
  "pending",
  "confirmed",
  "completed",
  "cancelled",
];

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

export const generateBookingNumber = async (
  client: SupabaseClient,
  ownerId: string
): Promise<string> => {
  const { data, error } = await client
    .from(BOOKINGS_TABLE)
    .select("booking_number")
    .eq("business_owner_id", ownerId)
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    throw APIError.internal(error.message);
  }

  if (!data?.length) {
    return "B0001";
  }

  const lastNumber = data[0].booking_number ?? "B0000";
  const numeric = Number(lastNumber.replace(/^\D+/g, "")) + 1;
  return `B${numeric.toString().padStart(4, "0")}`;
};

export const computeTotals = (
  items: Array<{ quantity: number; unitPrice: number }>,
  discountType: "percentage" | "fixed",
  discountValue: number
): { itemsTotal: number; discountAmount: number; total: number } => {
  const itemsTotal = items.reduce(
    (sum, item) => sum + item.quantity * item.unitPrice,
    0
  );
  let discountAmount = 0;
  if (discountType === "percentage") {
    discountAmount = (itemsTotal * discountValue) / 100;
  } else {
    discountAmount = discountValue;
  }
  discountAmount = Math.max(0, Math.min(discountAmount, itemsTotal));
  const total = Math.max(0, itemsTotal - discountAmount);
  return {
    itemsTotal: Number(itemsTotal.toFixed(2)),
    discountAmount: Number(discountAmount.toFixed(2)),
    total: Number(total.toFixed(2)),
  };
};

export const upsertCustomer = async (
  client: SupabaseClient,
  ownerId: string,
  payload: {
    name: string;
    phone: string;
    email?: string;
  }
): Promise<string> => {
  const trimmedPhone = payload.phone.replace(/\s+/g, "");
  const { data, error } = await client
    .from(CUSTOMERS_TABLE)
    .select("id")
    .eq("business_owner_id", ownerId)
    .eq("phone", trimmedPhone)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }

  if (data) {
    const { error: updateError } = await client
      .from(CUSTOMERS_TABLE)
      .update({
        name: payload.name,
        email: payload.email ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", data.id);
    if (updateError) {
      throw APIError.internal(updateError.message);
    }
    return data.id as string;
  }

  const { data: inserted, error: insertError } = await client
    .from(CUSTOMERS_TABLE)
    .insert({
      business_owner_id: ownerId,
      name: payload.name,
      phone: trimmedPhone,
      email: payload.email ?? null,
    })
    .select("id")
    .single();

  if (insertError) {
    throw APIError.internal(insertError.message);
  }
  return inserted.id as string;
};

export const fetchProductsMap = async (
  client: SupabaseClient,
  productIds: string[]
): Promise<Record<string, { id: string; name: string; salePrice: number }>> => {
  if (!productIds.length) {
    return {};
  }
  const { data, error } = await client
    .from(PRODUCTS_TABLE)
    .select("id, name, sale_price")
    .in("id", productIds);

  if (error) {
    throw APIError.internal(error.message);
  }

  const map: Record<
    string,
    { id: string; name: string; salePrice: number }
  > = {};
  for (const row of data ?? []) {
    map[row.id] = {
      id: row.id,
      name: row.name,
      salePrice: Number(row.sale_price ?? 0),
    };
  }
  return map;
};

export interface BookingRow {
  id: string;
  business_owner_id: string;
  customer_id: string | null;
  booking_number: string;
  customer_name: string;
  customer_phone: string;
  customer_email: string | null;
  event_type: string;
  event_date: string | null;
  delivery_date: string;
  delivery_time: string | null;
  delivery_location: string | null;
  notes: string | null;
  discount_type: "percentage" | "fixed";
  discount_value: number;
  discount_amount: number;
  total_amount: number;
  deposit_amount: number | null;
  status: BookingStatus;
  created_at: string;
  updated_at: string;
}

export interface BookingItemRow {
  id: string;
  booking_id: string;
  product_id: string;
  product_name: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
  created_at: string;
}

export const mapBookingItem = (row: BookingItemRow): BookingItem => ({
  id: row.id,
  productId: row.product_id,
  productName: row.product_name,
  quantity: Number(row.quantity ?? 0),
  unitPrice: Number(row.unit_price ?? 0),
  subtotal: Number(row.subtotal ?? 0),
  createdAt: row.created_at,
});

export const mapBooking = (
  row: BookingRow,
  items: BookingItemRow[]
): Booking => ({
  id: row.id,
  bookingNumber: row.booking_number,
  customerName: row.customer_name,
  customerPhone: row.customer_phone,
  customerEmail: row.customer_email ?? undefined,
  eventType: row.event_type,
  eventDate: row.event_date ?? undefined,
  deliveryDate: row.delivery_date,
  deliveryTime: row.delivery_time ?? undefined,
  deliveryLocation: row.delivery_location ?? undefined,
  notes: row.notes ?? undefined,
  discountType: row.discount_type,
  discountValue: Number(row.discount_value ?? 0),
  discountAmount: Number(row.discount_amount ?? 0),
  totalAmount: Number(row.total_amount ?? 0),
  depositAmount: row.deposit_amount ?? undefined,
  status: row.status,
  items: items.map(mapBookingItem),
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const fetchBookingById = async (
  client: SupabaseClient,
  ownerId: string,
  bookingId: string
): Promise<{ booking: BookingRow; items: BookingItemRow[] }> => {
  const { data, error } = await client
    .from(BOOKINGS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", bookingId)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }

  if (!data) {
    throw APIError.notFound("Booking not found");
  }

  const { data: itemRows, error: itemsError } = await client
    .from(BOOKING_ITEMS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("booking_id", bookingId)
    .order("created_at", { ascending: true });

  if (itemsError) {
    throw APIError.internal(itemsError.message);
  }

  return {
    booking: data as BookingRow,
    items: (itemRows ?? []) as BookingItemRow[],
  };
};

export const normalizeBookingItems = async (
  client: SupabaseClient,
  items: BookingItemInput[]
) => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("Booking requires at least one item");
  }
  const productIds = Array.from(new Set(items.map((item) => item.productId)));
  const productsMap = await fetchProductsMap(client, productIds);

  return items.map((item, index) => {
    const product = productsMap[item.productId];
    if (!product) {
      throw APIError.notFound(`Product ${item.productId} not found`);
    }
    const quantity = ensurePositiveNumber(item.quantity, `items[${index}].quantity`);
    const unitPrice =
      item.unitPrice !== undefined
        ? Number(item.unitPrice)
        : Number(product.salePrice ?? 0);
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      throw APIError.invalidArgument(`items[${index}].unitPrice must be zero or greater`);
    }
    return {
      productId: product.id,
      productName: product.name,
      quantity,
      unitPrice,
      subtotal: Number((quantity * unitPrice).toFixed(2)),
    };
  });
};

