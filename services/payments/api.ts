import { api, APIError } from "encore.dev/api";
import { Header } from "encore.dev/api";
import { resolveAuthContext } from "../../pkg/auth";
import {
  CreatePaymentRequest,
  CreatePaymentResponse,
  AllocatePaymentRequest,
  AllocatePaymentResponse,
  ListPaymentsRequest,
  ListPaymentsResponse,
  GetPaymentRequest,
  GetPaymentResponse,
  GetOutstandingBalanceRequest,
  GetOutstandingBalanceResponse,
} from "./types";
import {
  createPayment as createPaymentUtil,
  allocatePayment as allocatePaymentUtil,
  listPayments as listPaymentsUtil,
  getPaymentById,
  getOutstandingBalance,
} from "./utils";

export const createPayment = api<CreatePaymentRequest, CreatePaymentResponse>(
  {
    method: "POST",
    path: "/payments/create",
  },
  async ({
    authorization,
    vendorId,
    paymentMethod,
    paymentDate,
    totalAmount,
    claimIds,
    claimId,
    claimItemIds,
    paymentReference,
    notes,
  }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    if (!vendorId || !paymentMethod || !totalAmount) {
      throw APIError.invalidArgument("vendorId, paymentMethod, and totalAmount are required");
    }

    const result = await createPaymentUtil(
      client,
      ownerId,
      vendorId,
      paymentMethod,
      paymentDate,
      totalAmount,
      claimIds,
      claimId,
      claimItemIds,
      paymentReference,
      notes
    );

    return { success: true, data: { payment: result } };
  }
);

export const allocatePayment = api<AllocatePaymentRequest, AllocatePaymentResponse>(
  {
    method: "POST",
    path: "/payments/:id/allocate",
  },
  async ({ authorization, paymentId, allocations }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    if (!paymentId || !allocations || allocations.length === 0) {
      throw APIError.invalidArgument("paymentId and allocations are required");
    }

    const result = await allocatePaymentUtil(client, ownerId, paymentId, allocations);
    return { success: true, data: { payment: result } };
  }
);

export const listPayments = api<ListPaymentsRequest, ListPaymentsResponse>(
  {
    method: "GET",
    path: "/payments",
  },
  async ({ authorization, vendorId, fromDate, toDate, limit, offset }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    const result = await listPaymentsUtil(
      client,
      ownerId,
      vendorId,
      fromDate,
      toDate,
      limit,
      offset
    );

    return { success: true, data: result };
  }
);

export const getPayment = api<GetPaymentRequest, GetPaymentResponse>(
  {
    method: "GET",
    path: "/payments/:id",
  },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    if (!id) {
      throw APIError.invalidArgument("id is required");
    }

    const result = await getPaymentById(client, ownerId, id);
    return { success: true, data: { payment: result } };
  }
);

export const getOutstandingBalance = api<
  GetOutstandingBalanceRequest,
  GetOutstandingBalanceResponse
>(
  {
    method: "GET",
    path: "/payments/outstanding/:vendorId",
  },
  async ({ authorization, vendorId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    if (!vendorId) {
      throw APIError.invalidArgument("vendorId is required");
    }

    const result = await getOutstandingBalance(client, ownerId, vendorId);
    return { success: true, data: result };
  }
);

