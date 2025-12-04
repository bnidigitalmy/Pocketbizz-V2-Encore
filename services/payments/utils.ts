import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";
import type {
  Payment,
  PaymentDetail,
  PaymentAllocation,
  PaymentMethod,
} from "./types";

export const CONSIGNMENT_PAYMENTS_TABLE = "consignment_payments";
export const CONSIGNMENT_PAYMENT_ALLOCATIONS_TABLE = "consignment_payment_allocations";
export const CONSIGNMENT_CLAIMS_TABLE = "consignment_claims";
export const CONSIGNMENT_CLAIM_ITEMS_TABLE = "consignment_claim_items";
export const VENDORS_TABLE = "vendors";

interface PaymentRow {
  id: string;
  business_owner_id: string;
  vendor_id: string;
  payment_number: string;
  payment_date: string;
  payment_method: string;
  total_amount: number;
  payment_reference?: string | null;
  notes?: string | null;
  created_at: string;
  updated_at: string;
}

interface PaymentAllocationRow {
  id: string;
  payment_id: string;
  claim_id: string;
  claim_item_id?: string | null;
  allocated_amount: number;
  created_at: string;
}

interface ClaimRow {
  id: string;
  claim_number: string;
  net_amount: number;
  paid_amount: number;
  balance_amount: number;
}

const roundCurrency = (value: number): number => {
  return Math.round(value * 100) / 100;
};

const translateDbError = (error: unknown, context?: string): never => {
  const message = context || "Database operation failed";
  throw APIError.internal(message, { cause: error });
};

const ensureVendorOwnership = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<{ id: string; name: string }> => {
  const { data, error } = await client
    .from(VENDORS_TABLE)
    .select("id, name")
    .eq("business_owner_id", ownerId)
    .eq("id", vendorId)
    .maybeSingle();

  if (error) {
    translateDbError(error);
  }
  if (!data) {
    throw APIError.notFound(`Vendor ${vendorId} not found`);
  }
  return data as { id: string; name: string };
};

export const createPayment = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string,
  paymentMethod: PaymentMethod,
  paymentDate: string,
  totalAmount: number,
  claimIds?: string[],
  claimId?: string,
  claimItemIds?: string[],
  paymentReference?: string,
  notes?: string
): Promise<PaymentDetail> => {
  // Validate vendor
  const vendor = await ensureVendorOwnership(client, ownerId, vendorId);

  // Create payment
  const { data: paymentData, error: paymentError } = await client
    .from(CONSIGNMENT_PAYMENTS_TABLE)
    .insert({
      business_owner_id: ownerId,
      vendor_id: vendorId,
      payment_date: paymentDate,
      payment_method: paymentMethod,
      total_amount: totalAmount,
      payment_reference: paymentReference || null,
      notes: notes || null,
    })
    .select("*")
    .single();

  if (paymentError) {
    translateDbError(paymentError);
  }

  const paymentRow = paymentData as PaymentRow;

  // Auto-allocate based on payment method
  let allocations: any[] = [];

  if (paymentMethod === "bill_to_bill" && claimIds && claimIds.length > 0) {
    // Allocate to multiple claims proportionally
    const { data: claimsData } = await client
      .from(CONSIGNMENT_CLAIMS_TABLE)
      .select("id, balance_amount")
      .eq("business_owner_id", ownerId)
      .in("id", claimIds)
      .eq("status", "approved");

    const claims = (claimsData ?? []) as ClaimRow[];
    const totalOutstanding = claims.reduce((sum, c) => sum + Number(c.balance_amount), 0);

    if (totalOutstanding === 0) {
      throw APIError.failedPrecondition("No outstanding balance to allocate");
    }

    for (const claim of claims) {
      const balance = Number(claim.balance_amount);
      if (balance <= 0) continue;

      const proportion = balance / totalOutstanding;
      const allocated = roundCurrency(totalAmount * proportion);

      if (allocated > 0) {
        allocations.push({
          payment_id: paymentRow.id,
          claim_id: claim.id,
          allocated_amount: Math.min(allocated, balance), // Don't exceed balance
        });
      }
    }
  } else if (paymentMethod === "per_claim" && claimId) {
    // Allocate to single claim
    const { data: claimData } = await client
      .from(CONSIGNMENT_CLAIMS_TABLE)
      .select("id, balance_amount")
      .eq("business_owner_id", ownerId)
      .eq("id", claimId)
      .eq("status", "approved")
      .maybeSingle();

    if (!claimData) {
      throw APIError.notFound(`Approved claim ${claimId} not found`);
    }

    const claim = claimData as ClaimRow;
    const balance = Number(claim.balance_amount);

    if (totalAmount > balance) {
      throw APIError.invalidArgument(
        `Payment amount (${totalAmount}) exceeds claim balance (${balance})`
      );
    }

    allocations.push({
      payment_id: paymentRow.id,
      claim_id: claim.id,
      allocated_amount: totalAmount,
    });
  } else if (paymentMethod === "partial" && claimId) {
    // Partial payment to single claim
    const { data: claimData } = await client
      .from(CONSIGNMENT_CLAIMS_TABLE)
      .select("id, balance_amount")
      .eq("business_owner_id", ownerId)
      .eq("id", claimId)
      .maybeSingle();

    if (!claimData) {
      throw APIError.notFound(`Claim ${claimId} not found`);
    }

    const claim = claimData as ClaimRow;
    const balance = Number(claim.balance_amount);

    if (totalAmount > balance) {
      throw APIError.invalidArgument(
        `Payment amount (${totalAmount}) exceeds claim balance (${balance})`
      );
    }

    allocations.push({
      payment_id: paymentRow.id,
      claim_id: claim.id,
      allocated_amount: totalAmount,
    });
  } else if (paymentMethod === "carry_forward" && claimItemIds && claimItemIds.length > 0) {
    // Mark items as carry forward (no allocation yet)
    // This will be handled when creating new claim
    // For now, just create payment without allocations
  }

  // Insert allocations
  if (allocations.length > 0) {
    const { error: allocError } = await client
      .from(CONSIGNMENT_PAYMENT_ALLOCATIONS_TABLE)
      .insert(allocations);

    if (allocError) {
      translateDbError(allocError);
    }
  }

  // Return payment detail (allocations will be auto-updated by trigger)
  return await getPaymentById(client, ownerId, paymentRow.id);
};

export const allocatePayment = async (
  client: SupabaseClient,
  ownerId: string,
  paymentId: string,
  allocations: Array<{ claimId: string; claimItemId?: string; amount: number }>
): Promise<PaymentDetail> => {
  // Validate payment ownership
  const { data: paymentData } = await client
    .from(CONSIGNMENT_PAYMENTS_TABLE)
    .select("id, total_amount")
    .eq("business_owner_id", ownerId)
    .eq("id", paymentId)
    .maybeSingle();

  if (!paymentData) {
    throw APIError.notFound(`Payment ${paymentId} not found`);
  }

  const payment = paymentData as PaymentRow;
  const totalAmount = Number(payment.total_amount);

  // Validate allocations don't exceed payment amount
  const totalAllocated = allocations.reduce((sum, a) => sum + a.amount, 0);
  if (totalAllocated > totalAmount) {
    throw APIError.invalidArgument(
      `Total allocated amount (${totalAllocated}) exceeds payment amount (${totalAmount})`
    );
  }

  // Validate claims exist and are approved
  const claimIds = allocations.map((a) => a.claimId);
  const { data: claimsData } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("id, balance_amount, status")
    .eq("business_owner_id", ownerId)
    .in("id", claimIds);

  const claims = (claimsData ?? []) as Array<ClaimRow & { status: string }>;
  const claimsMap = new Map(claims.map((c) => [c.id, c]));

  for (const allocation of allocations) {
    const claim = claimsMap.get(allocation.claimId);
    if (!claim) {
      throw APIError.notFound(`Claim ${allocation.claimId} not found`);
    }
    if (claim.status !== "approved" && claim.status !== "settled") {
      throw APIError.failedPrecondition(
        `Claim ${allocation.claimId} must be approved before payment allocation`
      );
    }
    if (allocation.amount > Number(claim.balance_amount)) {
      throw APIError.invalidArgument(
        `Allocated amount (${allocation.amount}) exceeds claim balance (${claim.balance_amount})`
      );
    }
  }

  // Delete existing allocations
  await client
    .from(CONSIGNMENT_PAYMENT_ALLOCATIONS_TABLE)
    .delete()
    .eq("payment_id", paymentId);

  // Insert new allocations
  const allocationRows = allocations.map((a) => ({
    payment_id: paymentId,
    claim_id: a.claimId,
    claim_item_id: a.claimItemId || null,
    allocated_amount: a.amount,
  }));

  const { error: allocError } = await client
    .from(CONSIGNMENT_PAYMENT_ALLOCATIONS_TABLE)
    .insert(allocationRows);

  if (allocError) {
    translateDbError(allocError);
  }

  // Return payment detail (claim balances will be auto-updated by trigger)
  return await getPaymentById(client, ownerId, paymentId);
};

export const listPayments = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId?: string,
  fromDate?: string,
  toDate?: string,
  limit: number = 20,
  offset: number = 0
): Promise<{ payments: Payment[]; total: number; hasMore: boolean }> => {
  let query = client
    .from(CONSIGNMENT_PAYMENTS_TABLE)
    .select("*", { count: "exact" })
    .eq("business_owner_id", ownerId);

  if (vendorId) {
    query = query.eq("vendor_id", vendorId);
  }
  if (fromDate) {
    query = query.gte("payment_date", fromDate);
  }
  if (toDate) {
    query = query.lte("payment_date", toDate);
  }

  query = query.order("payment_date", { ascending: false }).range(offset, offset + limit - 1);

  const { data, error, count } = await query;

  if (error) {
    translateDbError(error);
  }

  const payments = (data ?? []).map((row: PaymentRow) => mapPaymentRow(row));
  const total = count ?? 0;
  const hasMore = offset + payments.length < total;

  return { payments, total, hasMore };
};

export const getPaymentById = async (
  client: SupabaseClient,
  ownerId: string,
  paymentId: string
): Promise<PaymentDetail> => {
  const { data: paymentData, error: paymentError } = await client
    .from(CONSIGNMENT_PAYMENTS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", paymentId)
    .maybeSingle();

  if (paymentError) {
    translateDbError(paymentError);
  }
  if (!paymentData) {
    throw APIError.notFound(`Payment ${paymentId} not found`);
  }

  const paymentRow = paymentData as PaymentRow;

  // Get allocations
  const { data: allocationsData, error: allocationsError } = await client
    .from(CONSIGNMENT_PAYMENT_ALLOCATIONS_TABLE)
    .select(`
      *,
      claim:consignment_claims(claim_number)
    `)
    .eq("payment_id", paymentId);

  if (allocationsError) {
    translateDbError(allocationsError);
  }

  const allocations = (allocationsData ?? []).map((row: any) => {
    const allocRow = row as PaymentAllocationRow & {
      claim?: { claim_number?: string };
    };

    return {
      id: allocRow.id,
      paymentId: allocRow.payment_id,
      claimId: allocRow.claim_id,
      claimItemId: allocRow.claim_item_id ?? undefined,
      allocatedAmount: Number(allocRow.allocated_amount),
      createdAt: allocRow.created_at,
      claimNumber: allocRow.claim?.claim_number,
    } as PaymentAllocation;
  });

  // Get vendor name
  const { data: vendorData } = await client
    .from(VENDORS_TABLE)
    .select("name")
    .eq("id", paymentRow.vendor_id)
    .maybeSingle();

  return {
    ...mapPaymentRow(paymentRow),
    vendorName: (vendorData as any)?.name,
    allocations,
  } as PaymentDetail;
};

export const getOutstandingBalance = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<{ totalOutstanding: number; claims: Array<{ claimId: string; claimNumber: string; balanceAmount: number }> }> => {
  const { data, error } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("id, claim_number, balance_amount")
    .eq("business_owner_id", ownerId)
    .eq("vendor_id", vendorId)
    .in("status", ["approved", "submitted"])
    .gt("balance_amount", 0)
    .order("claim_date", { ascending: false });

  if (error) {
    translateDbError(error);
  }

  const claims = (data ?? []) as ClaimRow[];
  const totalOutstanding = claims.reduce((sum, c) => sum + Number(c.balance_amount), 0);

  return {
    totalOutstanding: roundCurrency(totalOutstanding),
    claims: claims.map((c) => ({
      claimId: c.id,
      claimNumber: c.claim_number,
      balanceAmount: Number(c.balance_amount),
    })),
  };
};

const mapPaymentRow = (row: PaymentRow): Payment => {
  return {
    id: row.id,
    businessOwnerId: row.business_owner_id,
    vendorId: row.vendor_id,
    paymentNumber: row.payment_number,
    paymentDate: row.payment_date,
    paymentMethod: row.payment_method as PaymentMethod,
    totalAmount: Number(row.total_amount),
    paymentReference: row.payment_reference ?? undefined,
    notes: row.notes ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};



