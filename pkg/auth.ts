import { APIError } from "encore.dev/api";

import { getClient } from "./supabase";

export interface AuthContext {
  token: string;
  ownerId: string;
  client: ReturnType<typeof getClient>;
}

const extractBearerToken = (authorization?: string): string => {
  if (!authorization) {
    throw APIError.unauthenticated("Authorization header is required");
  }

  const trimmed = authorization.trim();
  if (!trimmed) {
    throw APIError.unauthenticated("Authorization header is invalid");
  }

  if (trimmed.toLowerCase().startsWith("bearer ")) {
    return trimmed.slice(7).trim();
  }

  return trimmed;
};

const decodeSupabaseUserId = (token: string): string => {
  const segments = token.split(".");
  if (segments.length < 2) {
    throw APIError.unauthenticated("Invalid Supabase token");
  }

  const normalized = segments[1].replace(/-/g, "+").replace(/_/g, "/");
  const paddingLength = (4 - (normalized.length % 4 || 4)) % 4;
  const payloadSegment = normalized.padEnd(normalized.length + paddingLength, "=");

  try {
    const json = Buffer.from(payloadSegment, "base64").toString("utf8");
    const payload = JSON.parse(json) as Record<string, unknown>;
    const userId =
      (payload.sub ?? payload.user_id ?? payload["userId"]) as string | undefined;

    if (!userId) {
      throw new Error("Missing sub claim");
    }

    return userId;
  } catch {
    throw APIError.unauthenticated("Invalid Supabase token");
  }
};

export const resolveAuthContext = (authorization?: string): AuthContext => {
  const token = extractBearerToken(authorization);
  const ownerId = decodeSupabaseUserId(token);
  const client = getClient(token);

  return { token, ownerId, client };
};

