import { Topic } from "encore.dev/pubsub";

export interface ConsignmentSessionCreatedEvent {
  sessionId: string;
  ownerId: string;
  vendorId: string;
  reference: string;
}

export const consignmentSessionCreatedTopic = new Topic<ConsignmentSessionCreatedEvent>(
  "consignment-session-created",
  { deliveryGuarantee: "at-least-once" }
);

export interface ConsignmentClaimGeneratedEvent {
  claimId: string;
  sessionId: string;
  ownerId: string;
  totalPayout: number;
}

export const consignmentClaimGeneratedTopic = new Topic<ConsignmentClaimGeneratedEvent>(
  "consignment-claim-generated",
  { deliveryGuarantee: "at-least-once" }
);

