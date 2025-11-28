# Inventory Service

Tracks stock availability, manages batch ingestion, and powers low-stock automations used by sales and analytics.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/inventory/batch/add` | ✅ | Validates + inserts batches tied to Supabase `inventory_batches`. |
| POST | `/inventory/consume` | ✅ | FIFO deduction that updates affected batches. |
| GET | `/inventory/list` | ✅ | Lists all batches (newest first). |
| GET | `/inventory/:id` | ✅ | Returns a single batch. |
| GET | `/inventory/low-stock` | ✅ | Aggregated low-stock snapshot (threshold = 5). |

## Automations

- **Cron** `daily-low-stock-check` → calls the low-stock endpoint to schedule downstream alerts.
- **Subscription** `inventory-update-on-sale` → consumes `OnSaleCreated` line items and deducts stock.

## TODO Roadmap

- **P1** Enforce workspace-level permissions / ownership on mutations & queries.
- **P1** Introduce configurable low-stock thresholds per ingredient/product.
- **P2** Emit events (e.g., `InventoryLowStock`) for downstream notification service.
- **P2** Add pagination and filtering for `/inventory/list`.
- **P2** Record audit trails for each batch consumption event.

