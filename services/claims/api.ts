import { api, APIError } from "encore.dev/api";
import { Header } from "encore.dev/api";
import { resolveAuthContext } from "../../pkg/auth";
import {
  CreateClaimRequest,
  CreateClaimResponse,
  SubmitClaimRequest,
  SubmitClaimResponse,
  ApproveClaimRequest,
  ApproveClaimResponse,
  RejectClaimRequest,
  RejectClaimResponse,
  ListClaimsRequest,
  ListClaimsResponse,
  GetClaimRequest,
  GetClaimResponse,
  UpdateClaimItemQuantitiesRequest,
  UpdateClaimItemQuantitiesResponse,
} from "./types";
import {
  createClaim,
  submitClaim,
  approveClaim,
  rejectClaim,
  listClaims,
  getClaimById,
  updateClaimItemQuantities,
} from "./utils";

export const createClaim = api<CreateClaimRequest, CreateClaimResponse>(
  {
    method: "POST",
    path: "/claims/create",
  },
  async ({ authorization, vendorId, deliveryIds, claimDate, notes }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!vendorId || !deliveryIds || deliveryIds.length === 0) {
      throw APIError.invalidArgument("vendorId and deliveryIds are required");
    }

    const result = await createClaimUtil(
      client,
      ownerId,
      vendorId,
      deliveryIds,
      claimDate,
      notes
    );

    return { success: true, data: { claim: result } };
  }
);

export const submitClaim = api<SubmitClaimRequest, SubmitClaimResponse>(
  {
    method: "POST",
    path: "/claims/:id/submit",
  },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!id) {
      throw APIError.invalidArgument("id is required");
    }

    const result = await submitClaimUtil(client, ownerId, id);
    return { success: true, data: { claim: result } };
  }
);

export const approveClaim = api<ApproveClaimRequest, ApproveClaimResponse>(
  {
    method: "POST",
    path: "/claims/:id/approve",
  },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!id) {
      throw APIError.invalidArgument("id is required");
    }

    const result = await approveClaimUtil(client, ownerId, id);
    return { success: true, data: { claim: result } };
  }
);

export const rejectClaim = api<RejectClaimRequest, RejectClaimResponse>(
  {
    method: "POST",
    path: "/claims/:id/reject",
  },
  async ({ authorization, id, reason }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!id) {
      throw APIError.invalidArgument("id is required");
    }

    const result = await rejectClaimUtil(client, ownerId, id, reason);
    return { success: true, data: { claim: result } };
  }
);

export const listClaims = api<ListClaimsRequest, ListClaimsResponse>(
  {
    method: "GET",
    path: "/claims",
  },
  async ({ authorization, vendorId, status, fromDate, toDate, limit, offset }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    const result = await listClaimsUtil(
      client,
      ownerId,
      vendorId,
      status,
      fromDate,
      toDate,
      limit,
      offset
    );

    return { success: true, data: result };
  }
);

export const getClaim = api<GetClaimRequest, GetClaimResponse>(
  {
    method: "GET",
    path: "/claims/:id",
  },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!id) {
      throw APIError.invalidArgument("id is required");
    }

    const result = await getClaimById(client, ownerId, id);
    return { success: true, data: { claim: result } };
  }
);

export const updateClaimItemQuantities = api<
  UpdateClaimItemQuantitiesRequest,
  UpdateClaimItemQuantitiesResponse
>(
  {
    method: "PUT",
    path: "/claims/:id/items/:itemId/quantities",
  },
  async ({ authorization, id, itemId, quantitySold, quantityUnsold, quantityExpired, quantityDamaged }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    
    if (!id || !itemId) {
      throw APIError.invalidArgument("id and itemId are required");
    }

    const result = await updateClaimItemQuantities(
      client,
      ownerId,
      id,
      itemId,
      quantitySold,
      quantityUnsold,
      quantityExpired,
      quantityDamaged
    );

    return { success: true, data: { claim: result } };
  }
);

