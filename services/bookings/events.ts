import { topic } from "encore.dev/pubsub";

export interface BookingCreatedEvent {
  bookingId: string;
  businessOwnerId: string;
  status: string;
}

export interface BookingStatusUpdatedEvent {
  bookingId: string;
  businessOwnerId: string;
  status: string;
}

export const OnBookingCreated = topic<BookingCreatedEvent>("booking-created");
export const OnBookingStatusUpdated = topic<BookingStatusUpdatedEvent>(
  "booking-status-updated"
);

