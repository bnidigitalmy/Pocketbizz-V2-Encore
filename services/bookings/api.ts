import { api, APIError, type Header } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { OnBookingCreated, OnBookingStatusUpdated } from "./events";
import type {
  BookingListResponse,
  BookingResponse,
  CreateBookingRequest,
  DeleteBookingRequest,
  GetBookingRequest,
  ListBookingsRequest,
  UpdateBookingStatusRequest,
} from "./types";
import {
  BOOKING_ITEMS_TABLE,
  BOOKINGS_TABLE,
  BOOKING_STATUS_VALUES,
  computeTotals,
  fetchBookingById,
  generateBookingNumber,
  mapBooking,
  normalizeBookingItems,
  sanitizeString,
  upsertCustomer,
} from "./utils";

const normalizeCreateRequest = (input: CreateBookingRequest["booking"]) => {
  const customerName = sanitizeString(input.customerName);
  const customerPhone = sanitizeString(input.customerPhone);
  const eventType = sanitizeString(input.eventType);
  const deliveryDate = sanitizeString(input.deliveryDate);

  if (!customerName) {
    throw APIError.invalidArgument("customerName is required");
  }
  if (!customerPhone) {
    throw APIError.invalidArgument("customerPhone is required");
  }
  if (!eventType) {
    throw APIError.invalidArgument("eventType is required");
  }
  if (!deliveryDate) {
    throw APIError.invalidArgument("deliveryDate is required");
  }

  const discountType =
    input.discountType === "percentage" || input.discountType === "fixed"
      ? input.discountType
      : "fixed";
  const discountValue = Math.max(0, Number(input.discountValue ?? 0));
  const depositAmount =
    input.depositAmount !== undefined && input.depositAmount !== null
      ? Math.max(0, Number(input.depositAmount))
      : undefined;

  return {
    customerName,
    customerPhone,
    customerEmail: sanitizeString(input.customerEmail) ?? undefined,
    eventType,
    eventDate: sanitizeString(input.eventDate),
    deliveryDate,
    deliveryTime: sanitizeString(input.deliveryTime),
    deliveryLocation: sanitizeString(input.deliveryLocation),
    notes: sanitizeString(input.notes),
    discountType,
    discountValue,
    depositAmount,
  };
};

export const createBooking = api<CreateBookingRequest, BookingResponse>(
  { method: "POST", path: "/bookings/create" },
  async ({ authorization, booking }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = normalizeCreateRequest(booking);
    const normalizedItems = await normalizeBookingItems(client, booking.items);

    const totals = computeTotals(
      normalizedItems.map((item) => ({
        quantity: item.quantity,
        unitPrice: item.unitPrice,
      })),
      normalized.discountType,
      normalized.discountValue
    );

    const bookingNumber = await generateBookingNumber(client, ownerId);
    const customerId = await upsertCustomer(client, ownerId, {
      name: normalized.customerName,
      phone: normalized.customerPhone,
      email: normalized.customerEmail,
    });

    const { data: bookingRow, error: insertError } = await client
      .from(BOOKINGS_TABLE)
      .insert({
        business_owner_id: ownerId,
        customer_id: customerId,
        booking_number: bookingNumber,
        customer_name: normalized.customerName,
        customer_phone: normalized.customerPhone,
        customer_email: normalized.customerEmail ?? null,
        event_type: normalized.eventType,
        event_date: normalized.eventDate ?? null,
        delivery_date: normalized.deliveryDate,
        delivery_time: normalized.deliveryTime ?? null,
        delivery_location: normalized.deliveryLocation ?? null,
        notes: normalized.notes ?? null,
        discount_type: normalized.discountType,
        discount_value: normalized.discountValue,
        discount_amount: totals.discountAmount,
        total_amount: totals.total,
        deposit_amount: normalized.depositAmount ?? null,
        status: "pending",
      })
      .select("*")
      .single();

    if (insertError) {
      throw APIError.internal(insertError.message);
    }

    const itemsPayload = normalizedItems.map((item) => ({
      business_owner_id: ownerId,
      booking_id: bookingRow.id,
      product_id: item.productId,
      product_name: item.productName,
      quantity: item.quantity,
      unit_price: item.unitPrice,
      subtotal: item.subtotal,
    }));

    const { error: itemsError } = await client
      .from(BOOKING_ITEMS_TABLE)
      .insert(itemsPayload);
    if (itemsError) {
      throw APIError.internal(itemsError.message);
    }

    const { booking: storedBooking, items } = await fetchBookingById(
      client,
      ownerId,
      bookingRow.id
    );

    await OnBookingCreated.publish({
      bookingId: bookingRow.id,
      businessOwnerId: ownerId,
      status: storedBooking.status,
    });

    return {
      success: true,
      data: { booking: mapBooking(storedBooking, items) },
    };
  }
);

export const listBookings = api<ListBookingsRequest, BookingListResponse>(
  { method: "GET", path: "/bookings" },
  async ({ authorization, status }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    let query = client
      .from(BOOKINGS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("created_at", { ascending: false });

    if (status && status !== "all") {
      if (!BOOKING_STATUS_VALUES.includes(status as any)) {
        throw APIError.invalidArgument("Invalid status filter");
      }
      query = query.eq("status", status);
    }

    const { data, error } = await query;
    if (error) {
      throw APIError.internal(error.message);
    }

    const bookingRows = (data ?? []) as any[];
    if (!bookingRows.length) {
      return { success: true, data: { bookings: [] } };
    }

    const bookingIds = bookingRows.map((row) => row.id);
    const { data: itemRows, error: itemsError } = await client
      .from(BOOKING_ITEMS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .in("booking_id", bookingIds);

    if (itemsError) {
      throw APIError.internal(itemsError.message);
    }

    const itemsByBooking: Record<string, any[]> = {};
    for (const item of itemRows ?? []) {
      itemsByBooking[item.booking_id] = itemsByBooking[item.booking_id] ?? [];
      itemsByBooking[item.booking_id].push(item);
    }

    const bookings = bookingRows.map((row) =>
      mapBooking(row, itemsByBooking[row.id] ?? [])
    );

    return { success: true, data: { bookings } };
  }
);

export const getBooking = api<GetBookingRequest, BookingResponse>(
  { method: "GET", path: "/bookings/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const bookingId = sanitizeString(id);
    if (!bookingId) {
      throw APIError.invalidArgument("id is required");
    }

    const { booking, items } = await fetchBookingById(client, ownerId, bookingId);
    return { success: true, data: { booking: mapBooking(booking, items) } };
  }
);

export const updateBookingStatus = api<UpdateBookingStatusRequest, BookingResponse>(
  { method: "PUT", path: "/bookings/:id/status" },
  async ({ authorization, id, status }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const bookingId = sanitizeString(id);
    if (!bookingId) {
      throw APIError.invalidArgument("id is required");
    }
    if (!BOOKING_STATUS_VALUES.includes(status)) {
      throw APIError.invalidArgument("Invalid status value");
    }

    const { data, error } = await client
      .from(BOOKINGS_TABLE)
      .update({ status, updated_at: new Date().toISOString() })
      .eq("business_owner_id", ownerId)
      .eq("id", bookingId)
      .select("*")
      .single();

    if (error) {
      throw APIError.internal(error.message);
    }
    if (!data) {
      throw APIError.notFound("Booking not found");
    }

    const { booking, items } = await fetchBookingById(client, ownerId, bookingId);

    await OnBookingStatusUpdated.publish({
      bookingId,
      businessOwnerId: ownerId,
      status,
    });

    // TODO: Trigger WhatsApp notifications, production planning, or calendar sync here.
    return { success: true, data: { booking: mapBooking(booking, items) } };
  }
);

export const deleteBooking = api<DeleteBookingRequest, BookingResponse>(
  { method: "DELETE", path: "/bookings/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const bookingId = sanitizeString(id);
    if (!bookingId) {
      throw APIError.invalidArgument("id is required");
    }

    const { error } = await client
      .from(BOOKINGS_TABLE)
      .delete()
      .eq("business_owner_id", ownerId)
      .eq("id", bookingId);

    if (error) {
      throw APIError.internal(error.message);
    }

    return { success: true };
  }
);

interface AuthorizedOnly {
  authorization: Header<"Authorization">;
}

