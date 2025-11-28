# Vendors Service

Maintains suppliers and reseller contacts used across purchasing, expenses, and fulfillment.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/vendors/create` | Stub | Creates vendor entries. |
| POST | `/vendors/update` | Stub | Updates vendor metadata. |
| GET | `/vendors/list` | Stub | Lists vendors (query pending). |

## TODO Roadmap

- **P1** Implement Supabase-backed list queries with filtering/search.
- **P1** Enforce workspace ownership on create/update flows.
- **P2** Add soft-delete + vendor activity tracking when needed.

