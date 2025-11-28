# Products Service

Maintains the master product catalog (SKUs, pricing, and metadata) consumed by inventory, sales, and MyShop channels.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/products/add` | ✅ | Validates + inserts product via Supabase. |
| GET | `/products/list` | ✅ | Lists active products ordered by creation date. |
| GET | `/products/:id` | ✅ | Fetches a single active product. |
| PUT | `/products/update` | ✅ | Updates product fields with validation + SKU uniqueness. |
| DELETE | `/products/delete` | ✅ | Soft-deletes product by toggling `is_active`. |

## TODO Roadmap

- **P1** Replace placeholder `owner_id` fallback with authenticated workspace owner.
- **P1** Wire authorization (Encore auth) so users can only CRUD their own products.
- **P2** Add pagination/filtering for `/products/list`.
- **P2** Emit domain events (e.g., `ProductUpdated`) for downstream analytics/inventory sync.

