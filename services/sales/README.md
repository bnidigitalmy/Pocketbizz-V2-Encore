# Sales Service

Owns POS/MyShop sales capture, emits `OnSaleCreated` events, and will coordinate downstream COGS/deduction logic.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/sales/create` | ✅ | Validates payload, stores sale + items, computes COGS/profit, emits event. |
| GET | `/sales/list` | ✅ | Lists recent sales ordered by `occurred_at`. |
| GET | `/sales/:id` | ✅ | Fetches individual sale. |
| GET | `/sales/daily` | ✅ | Aggregated totals for the last 30 days. |
| GET | `/sales/monthly` | ✅ | Aggregated totals for the last 12 months. |

## Events

- **Topic** `sales-created` carries line items + ingredient consumption requirements for Inventory to deduct stock.

## TODO Roadmap

- **P1** Enforce workspace scoping/auth on all list/detail endpoints.
- **P1** Include sale_items data in `/sales/:id` response when front-end needs detail.
- **P2** Add pagination/filter parameters (channel, timeframe) for `/sales/list`.
- **P2** Emit analytics events or push to data warehouse after sale persistence.

