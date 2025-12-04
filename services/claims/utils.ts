import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";
import type {
  Claim,
  ClaimDetail,
  ClaimItem,
  ClaimStatus,
} from "./types";

export const CONSIGNMENT_CLAIMS_TABLE = "consignment_claims";
export const CONSIGNMENT_CLAIM_ITEMS_TABLE = "consignment_claim_items";
export const VENDOR_DELIVERIES_TABLE = "vendor_deliveries";
export const VENDOR_DELIVERY_ITEMS_TABLE = "vendor_delivery_items";
export const VENDORS_TABLE = "vendors";
export const PRODUCTS_TABLE = "products";

interface ClaimRow {
  id: string;
  business_owner_id: string;
  vendor_id: string;
  claim_number: string;
  claim_date: string;
  status: string;
  gross_amount: number;
  commission_rate: number;
  commission_amount: number;
  net_amount: number;
  paid_amount: number;
  balance_amount: number;
  notes?: string | null;
  due_date?: string | null;
  submitted_at?: string | null;
  approved_at?: string | null;
  settled_at?: string | null;
  created_at: string;
  updated_at: string;
}

interface ClaimItemRow {
  id: string;
  claim_id: string;
  delivery_id: string;
  delivery_item_id: string;
  quantity_delivered: number;
  quantity_sold: number;
  quantity_unsold: number;
  quantity_expired: number;
  quantity_damaged: number;
  unit_price: number;
  gross_amount: number;
  commission_rate: number;
  commission_amount: number;
  net_amount: number;
  paid_amount: number;
  balance_amount: number;
  carry_forward: boolean;
  created_at: string;
  updated_at: string;
}

interface DeliveryRow {
  id: string;
  business_owner_id: string;
  vendor_id: string;
  vendor_name: string;
  delivery_date: string;
  status: string;
  payment_status: string;
  total_amount: number;
  invoice_number?: string | null;
}

interface DeliveryItemRow {
  id: string;
  delivery_id: string;
  product_id: string;
  product_name: string;
  quantity: number;
  unit_price: number;
  total_price: number;
  quantity_sold?: number | null;
  quantity_unsold?: number | null;
  quantity_expired?: number | null;
  quantity_damaged?: number | null;
}

interface VendorRow {
  id: string;
  name: string;
  phone?: string | null;
  email?: string | null;
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
): Promise<VendorRow> => {
  const { data, error } = await client
    .from(VENDORS_TABLE)
    .select("id, name, phone, email")
    .eq("business_owner_id", ownerId)
    .eq("id", vendorId)
    .maybeSingle();

  if (error) {
    translateDbError(error);
  }
  if (!data) {
    throw APIError.notFound(`Vendor ${vendorId} not found`);
  }
  return data as VendorRow;
};

const fetchDeliveries = async (
  client: SupabaseClient,
  ownerId: string,
  deliveryIds: string[]
): Promise<DeliveryRow[]> => {
  const { data, error } = await client
    .from(VENDOR_DELIVERIES_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .in("id", deliveryIds);

  if (error) {
    translateDbError(error);
  }

  const deliveries = (data ?? []) as DeliveryRow[];
  if (deliveries.length !== deliveryIds.length) {
    throw APIError.notFound("Some deliveries not found");
  }

  return deliveries;
};

const fetchDeliveryItems = async (
  client: SupabaseClient,
  ownerId: string,
  deliveryIds: string[]
): Promise<DeliveryItemRow[]> => {
  const { data, error } = await client
    .from(VENDOR_DELIVERY_ITEMS_TABLE)
    .select("*")
    .in("delivery_id", deliveryIds);

  if (error) {
    translateDbError(error);
  }

  // Verify ownership through deliveries
  const deliveries = await fetchDeliveries(client, ownerId, deliveryIds);
  const deliveryIdsSet = new Set(deliveries.map((d) => d.id));

  const items = (data ?? []) as DeliveryItemRow[];
  return items.filter((item) => deliveryIdsSet.has(item.delivery_id));
};

const calculateClaimAmounts = (
  items: DeliveryItemRow[],
  commissionRate: number
): {
  grossAmount: number;
  commissionAmount: number;
  netAmount: number;
} => {
  let grossAmount = 0;

  items.forEach((item) => {
    const quantitySold = item.quantity_sold ?? 0;
    const itemGross = quantitySold * item.unit_price;
    grossAmount += itemGross;
  });

  const commissionAmount = roundCurrency(grossAmount * (commissionRate / 100));
  const netAmount = roundCurrency(grossAmount - commissionAmount);

  return { grossAmount, commissionAmount, netAmount };
};

const getVendorCommissionRate = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string
): Promise<number> => {
  // Get commission rate from vendor, default to 0 if not set
  const { data } = await client
    .from(VENDORS_TABLE)
    .select("commission_rate")
    .eq("business_owner_id", ownerId)
    .eq("id", vendorId)
    .maybeSingle();

  // Assuming commission_rate column exists, otherwise default to 0
  return (data as any)?.commission_rate ?? 0;
};

export const createClaim = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId: string,
  deliveryIds: string[],
  claimDate: string,
  notes?: string
): Promise<ClaimDetail> => {
  // Validate vendor
  const vendor = await ensureVendorOwnership(client, ownerId, vendorId);

  // Validate deliveries
  const deliveries = await fetchDeliveries(client, ownerId, deliveryIds);

  // Check all deliveries are for the same vendor
  const vendorIds = new Set(deliveries.map((d) => d.vendor_id));
  if (vendorIds.size > 1 || !vendorIds.has(vendorId)) {
    throw APIError.invalidArgument("All deliveries must be for the same vendor");
  }

  // Get delivery items
  const deliveryItems = await fetchDeliveryItems(client, ownerId, deliveryIds);

  // Validate quantities balance
  for (const item of deliveryItems) {
    const sold = item.quantity_sold ?? 0;
    const unsold = item.quantity_unsold ?? 0;
    const expired = item.quantity_expired ?? 0;
    const damaged = item.quantity_damaged ?? 0;
    const total = sold + unsold + expired + damaged;

    if (Math.abs(total - item.quantity) > 0.01) {
      throw APIError.invalidArgument(
        `Quantities don't balance for item ${item.id}: delivered=${item.quantity}, sold+unsold+expired+damaged=${total}`
      );
    }
  }

  // Get commission rate
  const commissionRate = await getVendorCommissionRate(client, ownerId, vendorId);

  // Calculate amounts
  const { grossAmount, commissionAmount, netAmount } = calculateClaimAmounts(
    deliveryItems,
    commissionRate
  );

  // Create claim
  const { data: claimData, error: claimError } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .insert({
      business_owner_id: ownerId,
      vendor_id: vendorId,
      claim_date: claimDate,
      status: "draft",
      gross_amount: grossAmount,
      commission_rate: commissionRate,
      commission_amount: commissionAmount,
      net_amount: netAmount,
      paid_amount: 0,
      balance_amount: netAmount,
      notes: notes || null,
    })
    .select("*")
    .single();

  if (claimError) {
    translateDbError(claimError);
  }

  const claimRow = claimData as ClaimRow;

  // Create claim items
  const claimItems: any[] = [];
  for (const item of deliveryItems) {
    const quantitySold = item.quantity_sold ?? 0;
    if (quantitySold <= 0) continue; // Only include items with sold quantity

    const itemGross = quantitySold * item.unit_price;
    const itemCommission = roundCurrency(itemGross * (commissionRate / 100));
    const itemNet = roundCurrency(itemGross - itemCommission);

    claimItems.push({
      claim_id: claimRow.id,
      delivery_id: item.delivery_id,
      delivery_item_id: item.id,
      quantity_delivered: item.quantity,
      quantity_sold: quantitySold,
      quantity_unsold: item.quantity_unsold ?? 0,
      quantity_expired: item.quantity_expired ?? 0,
      quantity_damaged: item.quantity_damaged ?? 0,
      unit_price: item.unit_price,
      gross_amount: itemGross,
      commission_rate: commissionRate,
      commission_amount: itemCommission,
      net_amount: itemNet,
      paid_amount: 0,
      balance_amount: itemNet,
      carry_forward: false,
    });
  }

  if (claimItems.length === 0) {
    throw APIError.failedPrecondition("No items with sold quantity to claim");
  }

  const { error: itemsError } = await client
    .from(CONSIGNMENT_CLAIM_ITEMS_TABLE)
    .insert(claimItems);

  if (itemsError) {
    translateDbError(itemsError);
  }

  // Return claim detail
  return await getClaimById(client, ownerId, claimRow.id);
};

export const submitClaim = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string
): Promise<Claim> => {
  const { data, error } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .update({
      status: "submitted",
      submitted_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .select("*")
    .single();

  if (error) {
    translateDbError(error);
  }

  return mapClaimRow(data as ClaimRow);
};

export const approveClaim = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string
): Promise<Claim> => {
  const { data, error } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .update({
      status: "approved",
      approved_at: new Date().toISOString(),
    })
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .eq("status", "submitted") // Only approve submitted claims
    .select("*")
    .single();

  if (error) {
    translateDbError(error);
  }

  if (!data) {
    throw APIError.failedPrecondition("Claim must be submitted before approval");
  }

  return mapClaimRow(data as ClaimRow);
};

export const rejectClaim = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string,
  reason: string
): Promise<Claim> => {
  const { data, error } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .update({
      status: "rejected",
      notes: reason,
    })
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .select("*")
    .single();

  if (error) {
    translateDbError(error);
  }

  return mapClaimRow(data as ClaimRow);
};

export const listClaims = async (
  client: SupabaseClient,
  ownerId: string,
  vendorId?: string,
  status?: ClaimStatus,
  fromDate?: string,
  toDate?: string,
  limit: number = 20,
  offset: number = 0
): Promise<{ claims: Claim[]; total: number; hasMore: boolean }> => {
  let query = client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("*", { count: "exact" })
    .eq("business_owner_id", ownerId);

  if (vendorId) {
    query = query.eq("vendor_id", vendorId);
  }
  if (status) {
    query = query.eq("status", status);
  }
  if (fromDate) {
    query = query.gte("claim_date", fromDate);
  }
  if (toDate) {
    query = query.lte("claim_date", toDate);
  }

  query = query.order("claim_date", { ascending: false }).range(offset, offset + limit - 1);

  const { data, error, count } = await query;

  if (error) {
    translateDbError(error);
  }

  const claims = (data ?? []).map((row: ClaimRow) => mapClaimRow(row));
  const total = count ?? 0;
  const hasMore = offset + claims.length < total;

  return { claims, total, hasMore };
};

export const getClaimById = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string
): Promise<ClaimDetail> => {
  const { data: claimData, error: claimError } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .maybeSingle();

  if (claimError) {
    translateDbError(claimError);
  }
  if (!claimData) {
    throw APIError.notFound(`Claim ${claimId} not found`);
  }

  const claimRow = claimData as ClaimRow;

  // Get claim items
  const { data: itemsData, error: itemsError } = await client
    .from(CONSIGNMENT_CLAIM_ITEMS_TABLE)
    .select(`
      *,
      delivery:vendor_deliveries(invoice_number),
      delivery_item:vendor_delivery_items(product_id, product_name)
    `)
    .eq("claim_id", claimId);

  if (itemsError) {
    translateDbError(itemsError);
  }

  const items = (itemsData ?? []).map((row: any) => {
    const itemRow = row as ClaimItemRow & {
      delivery?: { invoice_number?: string };
      delivery_item?: { product_id?: string; product_name?: string };
    };

    return {
      id: itemRow.id,
      claimId: itemRow.claim_id,
      deliveryId: itemRow.delivery_id,
      deliveryItemId: itemRow.delivery_item_id,
      quantityDelivered: Number(itemRow.quantity_delivered),
      quantitySold: Number(itemRow.quantity_sold),
      quantityUnsold: Number(itemRow.quantity_unsold),
      quantityExpired: Number(itemRow.quantity_expired),
      quantityDamaged: Number(itemRow.quantity_damaged),
      unitPrice: Number(itemRow.unit_price),
      grossAmount: Number(itemRow.gross_amount),
      commissionRate: Number(itemRow.commission_rate),
      commissionAmount: Number(itemRow.commission_amount),
      netAmount: Number(itemRow.net_amount),
      paidAmount: Number(itemRow.paid_amount),
      balanceAmount: Number(itemRow.balance_amount),
      carryForward: itemRow.carry_forward,
      createdAt: itemRow.created_at,
      updatedAt: itemRow.updated_at,
      productId: itemRow.delivery_item?.product_id,
      productName: itemRow.delivery_item?.product_name,
      deliveryNumber: itemRow.delivery?.invoice_number,
    } as ClaimItem;
  });

  // Get vendor name
  const { data: vendorData } = await client
    .from(VENDORS_TABLE)
    .select("name")
    .eq("id", claimRow.vendor_id)
    .maybeSingle();

  return {
    ...mapClaimRow(claimRow),
    vendorName: (vendorData as any)?.name,
    items,
  } as ClaimDetail;
};

export const updateClaimItemQuantities = async (
  client: SupabaseClient,
  ownerId: string,
  claimId: string,
  itemId: string,
  quantitySold: number,
  quantityUnsold: number,
  quantityExpired: number,
  quantityDamaged: number
): Promise<ClaimDetail> => {
  // Validate claim ownership
  const { data: claimData } = await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .select("id, status")
    .eq("business_owner_id", ownerId)
    .eq("id", claimId)
    .maybeSingle();

  if (!claimData) {
    throw APIError.notFound(`Claim ${claimId} not found`);
  }

  const claim = claimData as ClaimRow;
  if (claim.status !== "draft") {
    throw APIError.failedPrecondition("Can only update quantities for draft claims");
  }

  // Get claim item
  const { data: itemData } = await client
    .from(CONSIGNMENT_CLAIM_ITEMS_TABLE)
    .select("*")
    .eq("claim_id", claimId)
    .eq("id", itemId)
    .maybeSingle();

  if (!itemData) {
    throw APIError.notFound(`Claim item ${itemId} not found`);
  }

  const itemRow = itemData as ClaimItemRow;

  // Validate quantities balance
  const total = quantitySold + quantityUnsold + quantityExpired + quantityDamaged;
  if (Math.abs(total - itemRow.quantity_delivered) > 0.01) {
    throw APIError.invalidArgument(
      `Quantities don't balance: delivered=${itemRow.quantity_delivered}, sum=${total}`
    );
  }

  // Update quantities
  const itemGross = quantitySold * itemRow.unit_price;
  const itemCommission = roundCurrency(itemGross * (itemRow.commission_rate / 100));
  const itemNet = roundCurrency(itemGross - itemCommission);

  await client
    .from(CONSIGNMENT_CLAIM_ITEMS_TABLE)
    .update({
      quantity_sold: quantitySold,
      quantity_unsold: quantityUnsold,
      quantity_expired: quantityExpired,
      quantity_damaged: quantityDamaged,
      gross_amount: itemGross,
      commission_amount: itemCommission,
      net_amount: itemNet,
      balance_amount: itemNet - itemRow.paid_amount,
    })
    .eq("id", itemId);

  // Recalculate claim totals
  const { data: allItems } = await client
    .from(CONSIGNMENT_CLAIM_ITEMS_TABLE)
    .select("gross_amount, commission_amount, net_amount, paid_amount")
    .eq("claim_id", claimId);

  const totals = (allItems ?? []).reduce(
    (acc, item: any) => ({
      gross: acc.gross + Number(item.gross_amount),
      commission: acc.commission + Number(item.commission_amount),
      net: acc.net + Number(item.net_amount),
      paid: acc.paid + Number(item.paid_amount),
    }),
    { gross: 0, commission: 0, net: 0, paid: 0 }
  );

  await client
    .from(CONSIGNMENT_CLAIMS_TABLE)
    .update({
      gross_amount: roundCurrency(totals.gross),
      commission_amount: roundCurrency(totals.commission),
      net_amount: roundCurrency(totals.net),
      balance_amount: roundCurrency(totals.net - totals.paid),
    })
    .eq("id", claimId);

  return await getClaimById(client, ownerId, claimId);
};

const mapClaimRow = (row: ClaimRow): Claim => {
  return {
    id: row.id,
    businessOwnerId: row.business_owner_id,
    vendorId: row.vendor_id,
    claimNumber: row.claim_number,
    claimDate: row.claim_date,
    status: row.status as ClaimStatus,
    grossAmount: Number(row.gross_amount),
    commissionRate: Number(row.commission_rate),
    commissionAmount: Number(row.commission_amount),
    netAmount: Number(row.net_amount),
    paidAmount: Number(row.paid_amount),
    balanceAmount: Number(row.balance_amount),
    notes: row.notes ?? undefined,
    dueDate: row.due_date ?? undefined,
    submittedAt: row.submitted_at ?? undefined,
    approvedAt: row.approved_at ?? undefined,
    settledAt: row.settled_at ?? undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};



