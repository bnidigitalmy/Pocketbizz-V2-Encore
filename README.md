# PocketBizz V2 Backend (Encore.ts)

PocketBizz V2 is a modular SaaS platform for Malaysian SMEs, powered by Encore.ts and Supabase. This repository currently contains the backend architecture skeleton that will be extended with business logic in subsequent iterations.

## Project Layout

```
services/          # Encore services (products, inventory, sales, etc.)
pkg/               # Shared helpers (Supabase client, cross-cutting utils, shared types)
db/schema.sql      # Source of truth for the relational data model
encore.app         # Encore application manifest
```

## Service Documentation

Each service folder contains a focused README covering its endpoints, events, and TODO roadmap:

- `services/products/README.md`
- `services/inventory/README.md`
- `services/sales/README.md`
- `services/expenses/README.md`
- `services/recipes/README.md`
- `services/vendors/README.md`
- `services/customers/README.md`
- `services/myshop/README.md`
- `services/analytics/README.md`

## Getting Started

1. Install dependencies
   ```sh
   npm install
   ```
2. Configure Encore (login, secrets, etc.)
3. Start the local Encore runtime
   ```sh
   npm run dev
   ```

## What’s Implemented

- Service scaffolds with placeholder Encore APIs
- Shared Supabase helper along with core domain types
- Event topics, cron jobs, and TODO markers for future implementations
- SQL schema defining all major data structures

## Next Steps

- Add Supabase secrets (`SupabaseURL`, `SupabaseServiceKey`)
- Implement business logic and request validation
- Expand automated tests, linting, and CI workflows

