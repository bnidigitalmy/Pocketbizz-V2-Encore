import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Minimal Supabase client for server-side calls
import { createClient } from "npm:@supabase/supabase-js@2.46.1";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface BclPayload {
  event?: string;
  data?: {
    record_id?: string; // order_number
    main_data?: {
      id?: string; // transaction id
      order_number?: string;
      status?: number | string;
      status_description?: string;
      amount?: string;
      currency?: string;
    };
    receipt_url?: string;
  };
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const payload = (await req.json()) as BclPayload;
    const event = payload.event;
    const main = payload.data?.main_data ?? {};
    const orderNumber =
      main.order_number || payload.data?.record_id || main.id || "";

    if (!orderNumber) {
      return new Response(JSON.stringify({ error: "Missing order_number" }), {
        status: 400,
      });
    }

    const status = String(main.status ?? "").toLowerCase();
    const isSuccess =
      event === "payment-success" ||
      status === "3" ||
      status === "approved" ||
      status === "completed";

    // Find pending subscription by payment_reference
    const { data: sub, error: subErr } = await supabase
      .from("subscriptions")
      .select("id, user_id, plan_id, status")
      .eq("payment_reference", orderNumber)
      .eq("status", "pending_payment")
      .maybeSingle();

    if (subErr) {
      console.error("Failed to fetch subscription", subErr);
      return new Response(JSON.stringify({ error: "Failed to fetch subscription" }), {
        status: 500,
      });
    }

    if (!sub) {
      return new Response(JSON.stringify({ message: "No pending subscription found" }), {
        status: 200,
      });
    }

    const gatewayTransactionId = main.id ?? null;
    const paidAt = new Date().toISOString();

    if (isSuccess) {
      // Mark payment completed
      const { error: payErr } = await supabase
        .from("subscription_payments")
        .update({
          status: "completed",
          paid_at: paidAt,
          gateway_transaction_id: gatewayTransactionId,
          updated_at: paidAt,
        })
        .eq("payment_reference", orderNumber)
        .eq("subscription_id", sub.id);

      if (payErr) {
        console.error("Failed to update payment", payErr);
        return new Response(JSON.stringify({ error: "Failed to update payment" }), {
          status: 500,
        });
      }

      // Activate subscription
      const { error: subUpdateErr } = await supabase
        .from("subscriptions")
        .update({
          status: "active",
          started_at: paidAt,
          expires_at: null, // keep original expires_at untouched if already set by creation
          payment_status: "completed",
          payment_completed_at: paidAt,
          updated_at: paidAt,
        })
        .eq("id", sub.id);

      if (subUpdateErr) {
        console.error("Failed to activate subscription", subUpdateErr);
        return new Response(JSON.stringify({ error: "Failed to activate subscription" }), {
          status: 500,
        });
      }

      return new Response(JSON.stringify({ message: "Payment success processed" }), {
        status: 200,
      });
    }

    // Failed case
    const { error: payFailErr } = await supabase
      .from("subscription_payments")
      .update({
        status: "failed",
        gateway_transaction_id: gatewayTransactionId,
        updated_at: paidAt,
      })
      .eq("payment_reference", orderNumber)
      .eq("subscription_id", sub.id);

    if (payFailErr) {
      console.error("Failed to mark payment failed", payFailErr);
      return new Response(JSON.stringify({ error: "Failed to mark payment failed" }), {
        status: 500,
      });
    }

    return new Response(JSON.stringify({ message: "Payment failed processed" }), {
      status: 200,
    });
  } catch (e) {
    console.error("Webhook error", e);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});
// Supabase Edge Function: BCL webhook handler (uses only Supabase)
// Verifies HMAC-SHA256 checksum and activates subscriptions/payments.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BCL_API_SECRET_KEY = Deno.env.get("BCL_API_SECRET_KEY")!;

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
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const payload = await parseBody(req);

  if (!(await isValidSignature(payload))) {
    return jsonResponse({ error: "Invalid signature" }, 401);
  }

  const orderNumber = payload.order_number?.toString() ?? "";
  if (!orderNumber) {
    return jsonResponse({ message: "Missing order_number" });
  }

  const { data: payment, error: paymentError } = await supabase
    .from("subscription_payments")
    .select("id, status, subscription_id, user_id, payment_reference")
    .eq("payment_reference", orderNumber)
    .maybeSingle();

  if (paymentError) {
    console.error("fetch payment error", paymentError);
    return jsonResponse({ error: "Database error" }, 500);
  }

  if (!payment) {
    return jsonResponse({ message: "No payment found (ok)" });
  }

  if (payment.status === "completed") {
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

  if (isSuccess) {
    const { data: subscription, error: subscriptionError } = await supabase
      .from("subscriptions")
      .select("id, user_id, plan_id")
      .eq("id", payment.subscription_id)
      .maybeSingle();

    if (subscriptionError) {
      console.error("fetch subscription error", subscriptionError);
      return jsonResponse({ error: "Database error" }, 500);
    }
    if (!subscription) {
      return jsonResponse({ message: "No subscription found" });
    }

    const { data: plan, error: planError } = await supabase
      .from("subscription_plans")
      .select("duration_months")
      .eq("id", subscription.plan_id)
      .maybeSingle();

    if (planError) {
      console.error("fetch plan error", planError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    const durationMonths = plan?.duration_months ?? 1;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);

    // Expire other active/trial subs for this user (satisfy unique index)
    await supabase
      .from("subscriptions")
      .update({ status: "expired", updated_at: nowIso })
      .eq("user_id", subscription.user_id)
      .in("status", ["trial", "active"])
      .neq("id", subscription.id);

    await supabase
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

    await supabase
      .from("subscription_payments")
      .update({
        status: "completed",
        paid_at: nowIso,
        gateway_transaction_id: gatewayTransactionId,
        failure_reason: null,
        updated_at: nowIso,
      })
      .eq("id", payment.id);

    return jsonResponse({ message: "OK" });
  }

  // Failure / unknown status
  await supabase
    .from("subscription_payments")
    .update({
      status: "failed",
      failure_reason: payload.status_description ?? "Payment failed",
      updated_at: nowIso,
    })
    .eq("id", payment.id);

  await supabase
    .from("subscriptions")
    .update({
      payment_status: "failed",
      status: "pending_payment",
      updated_at: nowIso,
    })
    .eq("id", payment.subscription_id);

  return jsonResponse({ message: "Marked failed" });
});

