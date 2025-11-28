import { Expense, OCRResult } from "../../pkg/types";

export interface AddExpenseRequest {
  expense: Expense;
}

export interface AddExpenseResponse {
  expense?: Expense;
}

export interface UploadOCRRequest {
  ownerId?: string;
  fileName: string;
  contentType?: string;
  data: string; // base64 encoded file
}

export interface UploadOCRResponse {
  receiptId: string;
  status: OCRResult["status"];
}

export interface ExpenseListResponse {
  expenses: Expense[];
}

export interface ExpenseReceiptUploadedEvent {
  receiptId: string;
  ownerId: string;
  filePath: string;
  contentType?: string;
}

