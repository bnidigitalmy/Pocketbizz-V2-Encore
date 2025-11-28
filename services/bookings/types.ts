import type { Header } from "encore.dev/api";

export type BookingStatus = "pending" | "confirmed" | "completed" | "cancelled";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface BookingItemInput {
  productId: string;
  quantity: number;
  unitPrice?: number;
}

export interface CreateBookingInput {
  customerName: string;
  customerPhone: string;
  customerEmail?: string;
  eventType: string;
  eventDate?: string;
  deliveryDate: string;
  deliveryTime?: string;
  deliveryLocation?: string;
  notes?: string;
  discountType?: "percentage" | "fixed";
  discountValue?: number;
  depositAmount?: number;
  items: BookingItemInput[];
}

export interface CreateBookingRequest extends AuthorizedRequest {
  booking: CreateBookingInput;
}

export interface BookingItem {
  id: string;
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  subtotal: number;
  createdAt: string;
}

export interface Booking {
  id: string;
  bookingNumber: string;
  customerName: string;
  customerPhone: string;
  customerEmail?: string;
  eventType: string;
  eventDate?: string;
  deliveryDate: string;
  deliveryTime?: string;
  deliveryLocation?: string;
  notes?: string;
  discountType: "percentage" | "fixed";
  discountValue: number;
  discountAmount: number;
  totalAmount: number;
  depositAmount?: number;
  status: BookingStatus;
  items: BookingItem[];
  createdAt: string;
  updatedAt: string;
}

export interface BookingResponse {
  success: boolean;
  data?: {
    booking: Booking;
  };
  error?: string;
}

export interface BookingListResponse {
  success: boolean;
  data?: {
    bookings: Booking[];
  };
  error?: string;
}

export interface ListBookingsRequest extends AuthorizedRequest {
  status?: BookingStatus | "all";
}

export interface GetBookingRequest extends AuthorizedRequest {
  id: string;
}

export interface UpdateBookingStatusRequest extends AuthorizedRequest {
  id: string;
  status: BookingStatus;
}

export interface DeleteBookingRequest extends AuthorizedRequest {
  id: string;
}

