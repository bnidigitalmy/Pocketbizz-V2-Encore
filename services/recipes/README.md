# Recipes Service

Supports BOM/recipe definitions, costing, and links finished goods to their ingredient requirements.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/recipes/create` | Stub | Creates recipe + items (Supabase wiring pending). |
| GET | `/recipes/:id` | Stub | Returns recipe with aggregated costs. |
| POST | `/recipes/costing` | Stub | Computes costing for an existing recipe. |

## TODO Roadmap

- **P1** Persist recipe headers/items in Supabase and ensure referential integrity.
- **P1** Hydrate recipe detail responses with total cost + ingredients.
- **P1** Implement costing calculations via Supabase joins (recipes, recipe_items, ingredients).
- **P2** Connect recipes with products/inventory for automatic deductions (Prompt #4/#5).

