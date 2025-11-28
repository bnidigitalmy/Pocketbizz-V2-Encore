import { Expense } from "../../pkg/types";

export const RECEIPTS_BUCKET = "ocr-receipts";
export const EXPENSES_TABLE = "expenses";
export const OCR_TABLE = "ocr_receipts";
export const DEFAULT_OWNER_ID = "00000000-0000-0000-0000-000000000000";

export interface ExpenseRow {
  id: string;
  owner_id: string;
  category: string;
  amount: number;
  currency: string;
  expense_date: string;
  notes: string | null;
  vendor_id: string | null;
  ocr_receipt_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface ExpenseInsertInput {
  ownerId: string;
  category: string;
  amount: number;
  currency: string;
  expenseDate: string;
  notes?: string;
  vendorId?: string;
  ocrReceiptId?: string;
}

export const buildReceiptStoragePath = (ownerId: string, fileName: string) =>
  `receipts/${ownerId}/${Date.now()}_${fileName}`;

export const mapExpenseRow = (row: ExpenseRow): Expense => ({
  id: row.id,
  category: row.category,
  amount: Number(row.amount ?? 0),
  currency: row.currency,
  expenseDate: row.expense_date,
  notes: row.notes ?? undefined,
  vendorId: row.vendor_id ?? undefined,
  ocrReceiptId: row.ocr_receipt_id ?? undefined,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export const buildExpenseInsertPayload = (input: ExpenseInsertInput) => ({
  owner_id: input.ownerId,
  category: input.category,
  amount: input.amount,
  currency: input.currency,
  expense_date: input.expenseDate,
  notes: input.notes ?? null,
  vendor_id: input.vendorId ?? null,
  ocr_receipt_id: input.ocrReceiptId ?? null,
});

