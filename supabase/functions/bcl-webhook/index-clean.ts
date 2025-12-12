// Supabase Edge Function: BCL webhook handler
// Verifies HMAC-SHA256 checksum and activates subscriptions/payments.
// NOTE: This function uses Deno.serve() which does NOT verify JWT tokens.
// This is intentional - BCL.my webhooks come from external sources without JWT.
// Security is handled via HMAC signature verification instead.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BCL_API_SECRET_KEY = Deno.env.get("BCL_API_SECRET_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !BCL_API_SECRET_KEY) {
  throw new Error("Missing required environment variables");
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

type StatusLike = string | number | undefined;

interface BclPayload {
  transaction_id?: string;
  exchange_reference_number?: string;
  exchange_transaction_id?: string;
  order_number?: string;
  currency?: string;
  amount?: string | number;
  payer_bank_name?: string;
  status?: StatusLike;
  status_description?: string;
  checksum?: string;
  [key: string]: unknown;
}

const SUCCESS_STATUSES = new Set(["success", "1", "completed", "paid"]);

const buildSignatureString = (payload: BclPayload): string => {
  const payloadData: Record<string, string> = {
    amount: payload.amount?.toString() ?? "",
    currency: payload.currency ?? "",
    exchange_reference_number: payload.exchange_reference_number ?? "",
    exchange_transaction_id: payload.exchange_transaction_id ?? "",
    order_number: payload.order_number ?? "",
    payer_bank_name: payload.payer_bank_name ?? "",
    status: payload.status?.toString() ?? "",
    status_description: payload.status_description ?? "",
    transaction_id: payload.transaction_id ?? "",
  };

  return Object.keys(payloadData)
    .sort()
    .map((k) => payloadData[k])
    .join("|");
};

const computeHmacHex = async (value: string, secret: string): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
};

const isValidSignature = async (payload: BclPayload): Promise<boolean> => {
  const providedChecksum = payload.checksum;
  if (!providedChecksum) return false;
  const payloadString = buildSignatureString(payload);
  const computed = await computeHmacHex(payloadString, BCL_API_SECRET_KEY);
  return computed.toLowerCase() === providedChecksum.toString().toLowerCase();
};

const parseBody = async (req: Request): Promise<BclPayload> => {
  const contentType = req.headers.get("content-type") ?? "";
  const raw = await req.text();
  if (!raw) return {};

  if (contentType.includes("application/x-www-form-urlencoded")) {
    const params = new URLSearchParams(raw);
    const obj: Record<string, string> = {};
    params.forEach((value, key) => {
      obj[key] = value;
    });
    return obj;
  }

  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

Deno.serve(async (req) => {
  console.log(`[${new Date().toISOString()}] Webhook received: ${req.method} ${req.url}`);
  
  if (req.method !== "POST") {
    console.log(`[${new Date().toISOString()}] Method not allowed: ${req.method}`);
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const payload = await parseBody(req);
    console.log(`[${new Date().toISOString()}] Payload received:`, JSON.stringify(payload));

    const isValid = await isValidSignature(payload);
    console.log(`[${new Date().toISOString()}] Signature valid: ${isValid}`);
    
    if (!isValid) {
      console.error(`[${new Date().toISOString()}] Invalid signature - rejecting request`);
      return jsonResponse({ error: "Invalid signature" }, 401);
    }

    const orderNumber = payload.order_number?.toString() ?? "";
    console.log(`[${new Date().toISOString()}] Order number: ${orderNumber}`);
    
    if (!orderNumber) {
      console.warn(`[${new Date().toISOString()}] Missing order_number in payload`);
      return jsonResponse({ message: "Missing order_number" });
    }

    const { data: payment, error: paymentError } = await supabase
      .from("subscription_payments")
      .select("id, status, subscription_id, user_id, payment_reference")
      .eq("payment_reference", orderNumber)
      .maybeSingle();

    if (paymentError) {
      console.error(`[${new Date().toISOString()}] Fetch payment error:`, paymentError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    if (!payment) {
      console.warn(`[${new Date().toISOString()}] No payment found for order_number: ${orderNumber}`);
      return jsonResponse({ message: "No payment found (ok)" });
    }

    console.log(`[${new Date().toISOString()}] Payment found:`, {
      id: payment.id,
      status: payment.status,
      subscription_id: payment.subscription_id,
    });

    if (payment.status === "completed") {
      console.log(`[${new Date().toISOString()}] Payment already processed: ${payment.id}`);
      return jsonResponse({ message: "Already processed" });
    }

    const status = payload.status?.toString().toLowerCase() ?? "";
    const isSuccess = SUCCESS_STATUSES.has(status);
    const nowIso = new Date().toISOString();
    const gatewayTransactionId =
      payload.transaction_id ??
      payload.exchange_transaction_id ??
      payload.exchange_reference_number ??
      undefined;

    console.log(`[${new Date().toISOString()}] Processing payment:`, {
      status,
      isSuccess,
      gatewayTransactionId,
    });

    if (isSuccess) {
      console.log(`[${new Date().toISOString()}] Processing successful payment...`);
      
      const { data: subscription, error: subscriptionError } = await supabase
        .from("subscriptions")
        .select("id, user_id, plan_id")
        .eq("id", payment.subscription_id)
        .maybeSingle();

      if (subscriptionError) {
        console.error(`[${new Date().toISOString()}] Fetch subscription error:`, subscriptionError);
        return jsonResponse({ error: "Database error" }, 500);
      }
      
      if (!subscription) {
        console.error(`[${new Date().toISOString()}] No subscription found for payment: ${payment.id}`);
        return jsonResponse({ message: "No subscription found" });
      }

      const { data: plan, error: planError } = await supabase
        .from("subscription_plans")
        .select("duration_months")
        .eq("id", subscription.plan_id)
        .maybeSingle();

      if (planError) {
        console.error(`[${new Date().toISOString()}] Fetch plan error:`, planError);
        return jsonResponse({ error: "Database error" }, 500);
      }

      const durationMonths = plan?.duration_months ?? 1;
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);

      // Expire other active/trial subs for this user
      await supabase
        .from("subscriptions")
        .update({ status: "expired", updated_at: nowIso })
        .eq("user_id", subscription.user_id)
        .in("status", ["trial", "active"])
        .neq("id", subscription.id);

      // Activate subscription
      const { error: subUpdateError } = await supabase
        .from("subscriptions")
        .update({
          status: "active",
          started_at: nowIso,
          expires_at: expiresAt.toISOString(),
          payment_status: "completed",
          payment_completed_at: nowIso,
          updated_at: nowIso,
          payment_reference: orderNumber,
        })
        .eq("id", subscription.id);

      if (subUpdateError) {
        console.error(`[${new Date().toISOString()}] Failed to activate subscription:`, subUpdateError);
        return jsonResponse({ error: "Failed to activate subscription" }, 500);
      }

      // Update payment status
      const { error: paymentUpdateError } = await supabase
        .from("subscription_payments")
        .update({
          status: "completed",
          paid_at: nowIso,
          gateway_transaction_id: gatewayTransactionId,
          failure_reason: null,
          updated_at: nowIso,
        })
        .eq("id", payment.id);

      if (paymentUpdateError) {
        console.error(`[${new Date().toISOString()}] Failed to update payment:`, paymentUpdateError);
        return jsonResponse({ error: "Failed to update payment" }, 500);
      }

      console.log(`[${new Date().toISOString()}] Payment and subscription activated successfully`);
      return jsonResponse({ message: "OK" });
    }

    // Failure / unknown status
    console.log(`[${new Date().toISOString()}] Processing failed payment...`);
    
    const { error: paymentFailError } = await supabase
      .from("subscription_payments")
      .update({
        status: "failed",
        failure_reason: payload.status_description ?? "Payment failed",
        updated_at: nowIso,
      })
      .eq("id", payment.id);

    if (paymentFailError) {
      console.error(`[${new Date().toISOString()}] Failed to mark payment as failed:`, paymentFailError);
    }

    const { error: subFailError } = await supabase
      .from("subscriptions")
      .update({
        payment_status: "failed",
        status: "pending_payment",
        updated_at: nowIso,
      })
      .eq("id", payment.subscription_id);

    if (subFailError) {
      console.error(`[${new Date().toISOString()}] Failed to update subscription status:`, subFailError);
    }

    console.log(`[${new Date().toISOString()}] Payment marked as failed`);
    return jsonResponse({ message: "Marked failed" });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Unhandled error:`, error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

