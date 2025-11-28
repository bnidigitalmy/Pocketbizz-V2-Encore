# Expenses Service

Handles manual expense entries, OCR receipt ingestion, and emits events to finalize expenses post-OCR.

## Endpoints

| Method | Path | Status | Notes |
| ------ | ---- | ------ | ----- |
| POST | `/expenses/add` | ✅ | Manual expense entry hook (basic validation). |
| POST | `/expenses/upload-receipt` | ✅ | Uploads receipt file → emits OCR event. |
| GET | `/expenses/list` | ✅ | Returns recent expenses. |
| POST | `/ocr/cleanup` | Stub | Placeholder cleanup cron. |

## Events & Jobs

- **Topic** `expense-receipt-uploaded` → triggers OCR worker that extracts totals and creates expenses.
- **Cron** `ocr-cleanup` → reserved for deleting old OCR assets (future).

## TODO Roadmap

- **P1** Replace placeholder OCR with real integration/service.
- **P1** Enforce workspace ownership + auth on uploads/listing.
- **P2** Delete Supabase objects + rows when cleanup job runs.
- **P2** Surface OCR processing status to clients (polling or websockets).

