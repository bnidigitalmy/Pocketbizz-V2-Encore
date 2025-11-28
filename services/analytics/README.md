# Analytics Service

Aggregates KPIs for dashboards, exposes reporting APIs, and schedules recurring summary jobs.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| GET | `/analytics/overview` | Stub | Returns placeholder summary metrics. |
| POST | `/analytics/generate-report` | Stub | Triggers monthly KPI generation. |

## Automations

- **Cron** `monthly-report` → runs the monthly report generator.

## TODO Roadmap

- **P2** Aggregate Supabase metrics (sales, expenses, inventory) for dashboard cards.
- **P2** Produce downloadable KPI reports and store artifacts (PDF/CSV) in Supabase storage.
- **P3** Add ad-hoc analytics endpoints (daily, monthly, cohort) once data is available.

