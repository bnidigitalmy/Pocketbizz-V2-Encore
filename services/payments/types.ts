import { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

interface BaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export type PaymentMethod = "bill_to_bill" | "per_claim" | "partial" | "carry_forward";

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



