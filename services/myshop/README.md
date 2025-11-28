# MyShop Service

Provides the lightweight e-commerce backend for PocketBizz merchants, creating orders that sync with sales and inventory.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/myshop/order` | Stub | Creates MyShop orders + emits events. |
| GET | `/myshop/orders` | Stub | Lists orders (pagination pending). |

## Events

- **Topic** `myshop-order` (`OrderCreatedEvent`) → consumed by Customers service (notifications) and will later feed Analytics.

## TODO Roadmap

- **P1** Implement Supabase-backed listing with pagination, filters, and sorting.
- **P1** Validate incoming orders and ensure reference IDs are unique per workspace.
- **P2** Add payment/fulfilment webhooks and order status transitions.

