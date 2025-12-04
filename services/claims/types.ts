import { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

interface BaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export type ClaimStatus = "draft" | "submitted" | "approved" | "rejected" | "settled";
export type PaymentMethod = "bill_to_bill" | "per_claim" | "partial" | "carry_forward";

// Claim Types
export interface Claim {
  id: string;
  businessOwnerId: string;
  vendorId: string;
  vendorName?: string;
  claimNumber: string;
  claimDate: string;
  status: ClaimStatus;
  grossAmount: number;
  commissionRate: number;
  commissionAmount: number;
  netAmount: number;
  paidAmount: number;
  balanceAmount: number;
  notes?: string;
  dueDate?: string;
  submittedAt?: string;
  approvedAt?: string;
  settledAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ClaimItem {
  id: string;
  claimId: string;
  deliveryId: string;
  deliveryItemId: string;
  quantityDelivered: number;
  quantitySold: number;
  quantityUnsold: number;
  quantityExpired: number;
  quantityDamaged: number;
  unitPrice: number;
  grossAmount: number;
  commissionRate: number;
  commissionAmount: number;
  netAmount: number;
  paidAmount: number;
  balanceAmount: number;
  carryForward: boolean;
  createdAt: string;
  updatedAt: string;
  // Denormalized fields
  productId?: string;
  productName?: string;
  deliveryNumber?: string;
}

export interface ClaimDetail extends Claim {
  items: ClaimItem[];
}

// Request/Response Types
export interface CreateClaimRequest extends AuthorizedRequest {
  vendorId: string;
  deliveryIds: string[];
  claimDate: string;
  notes?: string;
}

export type CreateClaimResponse = BaseResponse<{
  claim: ClaimDetail;
}>;

export interface SubmitClaimRequest extends AuthorizedRequest {
  id: string;
}

export type SubmitClaimResponse = BaseResponse<{
  claim: Claim;
}>;

export interface ApproveClaimRequest extends AuthorizedRequest {
  id: string;
}

export type ApproveClaimResponse = BaseResponse<{
  claim: Claim;
}>;

export interface RejectClaimRequest extends AuthorizedRequest {
  id: string;
  reason: string;
}

export type RejectClaimResponse = BaseResponse<{
  claim: Claim;
}>;

export interface ListClaimsRequest extends AuthorizedRequest {
  vendorId?: string;
  status?: ClaimStatus;
  fromDate?: string;
  toDate?: string;
  limit?: number;
  offset?: number;
}

export type ListClaimsResponse = BaseResponse<{
  claims: Claim[];
  total: number;
  hasMore: boolean;
}>;

export interface GetClaimRequest extends AuthorizedRequest {
  id: string;
}

export type GetClaimResponse = BaseResponse<{
  claim: ClaimDetail;
}>;

export interface UpdateClaimItemQuantitiesRequest extends AuthorizedRequest {
  id: string;
  itemId: string;
  quantitySold: number;
  quantityUnsold: number;
  quantityExpired: number;
  quantityDamaged: number;
}

export type UpdateClaimItemQuantitiesResponse = BaseResponse<{
  claim: ClaimDetail;
}>;

// Payment Types
export interface Payment {
  id: string;
  businessOwnerId: string;
  vendorId: string;
  vendorName?: string;
  paymentNumber: string;
  paymentDate: string;
  paymentMethod: PaymentMethod;
  totalAmount: number;
  paymentReference?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PaymentAllocation {
  id: string;
  paymentId: string;
  claimId: string;
  claimItemId?: string;
  allocatedAmount: number;
  createdAt: string;
  // Denormalized
  claimNumber?: string;
}

export interface PaymentDetail extends Payment {
  allocations: PaymentAllocation[];
}

export interface CreatePaymentRequest extends AuthorizedRequest {
  vendorId: string;
  paymentMethod: PaymentMethod;
  paymentDate: string;
  totalAmount: number;
  claimIds?: string[];
  claimId?: string;
  claimItemIds?: string[];
  paymentReference?: string;
  notes?: string;
}

export type CreatePaymentResponse = BaseResponse<{
  payment: PaymentDetail;
}>;

export interface AllocatePaymentRequest extends AuthorizedRequest {
  paymentId: string;
  allocations: Array<{
    claimId: string;
    claimItemId?: string;
    amount: number;
  }>;
}

export type AllocatePaymentResponse = BaseResponse<{
  payment: PaymentDetail;
}>;

export interface ListPaymentsRequest extends AuthorizedRequest {
  vendorId?: string;
  fromDate?: string;
  toDate?: string;
  limit?: number;
  offset?: number;
}

export type ListPaymentsResponse = BaseResponse<{
  payments: Payment[];
  total: number;
  hasMore: boolean;
}>;

export interface GetPaymentRequest extends AuthorizedRequest {
  id: string;
}

export type GetPaymentResponse = BaseResponse<{
  payment: PaymentDetail;
}>;

export interface GetOutstandingBalanceRequest extends AuthorizedRequest {
  vendorId: string;
}

export type GetOutstandingBalanceResponse = BaseResponse<{
  totalOutstanding: number;
  claims: Array<{
    claimId: string;
    claimNumber: string;
    balanceAmount: number;
  }>;
}>;



