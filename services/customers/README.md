# Customers Service

Stores customer profiles, loyalty metadata, and listens to order events for potential notifications.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/customers/create` | Stub | Creates/updates customer profiles. |
| GET | `/customers/list` | Stub | Lists customers (workspace filtering pending). |

## Automations

- **Subscription** `notify-user-on-order` → reacts to `OrderCreatedEvent` (future notification integration).

## TODO Roadmap

- **P1** Query customers scoped to the authenticated workspace/account.
- **P2** Send notifications (email/push/WhatsApp) upon new orders.
- **P2** Extend service with loyalty metrics & segmentation APIs.

