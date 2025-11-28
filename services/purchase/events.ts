import { topic } from "encore.dev/pubsub";

export interface POCreatedEvent {
  po_id: string;
  business_owner_id: string;
}

export interface POApprovedEvent {
  po_id: string;
  business_owner_id: string;
}

export interface GRNCreatedEvent {
  grn_id: string;
  business_owner_id: string;
}

export const OnPOCreated = topic<POCreatedEvent>("OnPOCreated");
export const OnPOApproved = topic<POApprovedEvent>("OnPOApproved");
export const OnGRNCreated = topic<GRNCreatedEvent>("OnGRNCreated");

