import { Header } from "encore.dev/api";

export type CommissionType = "percent" | "fixed";
export type ConsignmentStatus = "open" | "submitted" | "claimed" | "closed";
export type ClaimStatus = "pending" | "paid";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

interface BaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface ConsignmentItemInput {
  productId: string;
  quantity: number;
  commissionType: CommissionType;
  commissionValue: number;
}

export interface CreateConsignmentSessionRequest extends AuthorizedRequest {
  vendorId: string;
  note?: string;
  items: ConsignmentItemInput[];
}

export type ConsignmentSessionSummary = {
  id: string;
  vendorId: string;
  reference: string;
  status: ConsignmentStatus;
  totalItems: number;
  totalValue: number;
  createdAt: string;
  updatedAt: string;
  note?: string;
};

export type ConsignmentItemDetail = {
  id: string;
  sessionId: string;
  productId: string;
  qtySent: number;
  qtySold: number;
  qtyReturned: number;
  listPrice: number;
  unitPrice: number;
  commissionType: CommissionType;
  commissionRate?: number;
  commissionAmount: number;
  totalValue: number;
};

export type VendorSummary = {
  id: string;
  name: string;
  type?: string;
  contact?: {
    email?: string;
    phone?: string;
  };
};

export interface SessionMetrics {
  grossPotential: number;
  grossSold: number;
  totalCommission: number;
  totalPayout: number;
  remainingQty: number;
}

export type ConsignmentSessionDetail = ConsignmentSessionSummary & {
  vendor: VendorSummary;
  items: ConsignmentItemDetail[];
  metrics: SessionMetrics;
};

export type CreateConsignmentSessionResponse = BaseResponse<{
  session: ConsignmentSessionDetail;
}>;

export interface ListConsignmentSessionsRequest extends AuthorizedRequest {}

export type ListConsignmentSessionsResponse = BaseResponse<{
  sessions: ConsignmentSessionSummary[];
}>;

export interface GetConsignmentSessionRequest extends AuthorizedRequest {
  id: string;
}

export type GetConsignmentSessionResponse = BaseResponse<{
  session: ConsignmentSessionDetail;
}>;

export interface ReconcileConsignmentRequest extends AuthorizedRequest {
  sessionId: string;
  updates: Array<{
    itemId: string;
    qtySold: number;
    qtyReturned: number;
  }>;
}

export type ReconcileConsignmentResponse = BaseResponse<{
  session: ConsignmentSessionDetail;
}>;

export interface GenerateClaimRequest extends AuthorizedRequest {
  sessionId: string;
}

export type ConsignmentClaim = {
  id: string;
  sessionId: string;
  totalSoldValue: number;
  totalCommission: number;
  totalPayout: number;
  claimDate: string;
  status: ClaimStatus;
  createdAt: string;
  updatedAt: string;
};

export type GenerateClaimResponse = BaseResponse<{
  claim: ConsignmentClaim;
}>;

export interface GetClaimRequest extends AuthorizedRequest {
  id: string;
}

export type GetClaimResponse = BaseResponse<{
  claim: ConsignmentClaim;
}>;

export interface InvoiceRequest extends AuthorizedRequest {
  id: string;
}

export type InvoiceResponse = BaseResponse<{
  document: string;
}>;

export interface ClaimPrintRequest extends AuthorizedRequest {
  id: string;
}

export type ClaimPrintResponse = BaseResponse<{
  document: string;
}>;

export interface HistoryRequest extends AuthorizedRequest {
  sessionId: string;
}

export type HistoryEvent = {
  id: string;
  sessionId: string;
  eventType: string;
  details?: Record<string, unknown>;
  createdAt: string;
};

export type HistoryResponse = BaseResponse<{
  events: HistoryEvent[];
}>;

