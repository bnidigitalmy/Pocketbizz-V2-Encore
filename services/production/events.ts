import { Topic } from "encore.dev/pubsub";

export interface ProductionCreatedEvent {
  businessOwnerId: string;
  productionBatchId: string;
}

export const OnProductionCreated = new Topic<ProductionCreatedEvent>("production-created", {
  deliveryGuarantee: "at-least-once",
});

