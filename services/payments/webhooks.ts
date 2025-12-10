import { api } from "encore.dev/api";
import log from "encore.dev/log";
import { secret } from "encore.dev/config";
import { createHmac } from "node:crypto";
import { getClient } from "../shared/supabase";

interface BclPayload {
  transaction_id?: string;
  exchange_reference_number?: string;
  exchange_transaction_id?: string;
  order_number?: string;
  currency?: string;
  amount?: string | number;
  payer_bank_name?: string;
  status?: string | number;
  status_description?: string;
  checksum?: string;
  [key: string]: unknown;
}

const bclApiSecret = secret("BCL_API_SECRET_KEY");

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

  const sortedKeys = Object.keys(payloadData).sort();
  return sortedKeys.map((key) => payloadData[key]).join("|");
};

const isValidSignature = (payload: BclPayload): boolean => {
  const providedChecksum = payload.checksum;
  if (!providedChecksum) return false;

  const payloadString = buildSignatureString(payload);
  const computed = createHmac("sha256", bclApiSecret()).update(payloadString).digest("hex");
  return computed.toLowerCase() === providedChecksum.toString().toLowerCase();
};

const parseBody = async (req: Parameters<Parameters<typeof api.raw>[1]>[0]["rawRequest"]) => {
  const chunks: Uint8Array[] = [];
  for await (const chunk of req) {
    if (typeof chunk === "string") {
      chunks.push(Buffer.from(chunk));
    } else {
      chunks.push(chunk);
    }
  }
  const bodyStr = Buffer.concat(chunks).toString("utf8").trim();
  if (!bodyStr) return {};

  const contentType = req.headers["content-type"] ?? "";
  if (typeof contentType === "string" && contentType.includes("application/x-www-form-urlencoded")) {
    const params = new URLSearchParams(bodyStr);
    const obj: Record<string, string> = {};
    params.forEach((value, key) => {
      obj[key] = value;
    });
    return obj;
  }

  try {
    return JSON.parse(bodyStr);
  } catch {
    return {};
  }
};

export const bclWebhook = api.raw(
  {
    path: "/webhooks/bcl",
    method: "POST",
    expose: true,
  },
  async (req, res) => {
    const body = (await parseBody(req.rawRequest)) as BclPayload;

    if (!isValidSignature(body)) {
      res.statusCode = 401;
      res.end("Invalid signature");
      return;
    }

    const orderNumber = body.order_number?.toString() ?? "";
    if (!orderNumber) {
      res.statusCode = 200;
      res.end("Missing order_number");
      return;
    }

    const client = getClient();

    const { data: payment, error: paymentError } = await client
      .from("subscription_payments")
      .select("id, status, subscription_id, user_id, payment_reference")
      .eq("payment_reference", orderNumber)
      .maybeSingle();

    if (paymentError) {
      log.error(paymentError, "Failed to fetch payment");
      res.statusCode = 500;
      res.end("Error");
      return;
    }

    if (!payment) {
      res.statusCode = 200;
      res.end("No payment");
      return;
    }

    if (payment.status === "completed") {
      res.statusCode = 200;
      res.end("Already processed");
      return;
    }

    const status = body.status?.toString().toLowerCase() ?? "";
    const isSuccess = SUCCESS_STATUSES.has(status);
    const now = new Date();
    const paidAt = now.toISOString();
    const gatewayTransactionId =
      body.transaction_id ??
      body.exchange_transaction_id ??
      body.exchange_reference_number ??
      undefined;

    if (isSuccess) {
      const { data: subscription, error: subscriptionError } = await client
        .from("subscriptions")
        .select("id, user_id, plan_id, status")
        .eq("id", payment.subscription_id)
        .maybeSingle();

      if (subscriptionError) {
        log.error(subscriptionError, "Failed to fetch subscription");
        res.statusCode = 500;
        res.end("Error");
        return;
      }

      if (!subscription) {
        log.warn("Subscription not found for payment", { paymentReference: orderNumber });
        res.statusCode = 200;
        res.end("No subscription");
        return;
      }

      const { data: plan, error: planError } = await client
        .from("subscription_plans")
        .select("duration_months")
        .eq("id", subscription.plan_id)
        .maybeSingle();

      if (planError) {
        log.error(planError, "Failed to fetch plan");
        res.statusCode = 500;
        res.end("Error");
        return;
      }

      const durationMonths = plan?.duration_months ?? 1;
      const expiresAt = new Date(now.getTime());
      expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);

      // Expire any existing active/trial subs (unique constraint safety)
      await client
        .from("subscriptions")
        .update({ status: "expired", updated_at: paidAt })
        .eq("user_id", subscription.user_id)
        .in("status", ["trial", "active"])
        .neq("id", subscription.id);

      await client
        .from("subscriptions")
        .update({
          status: "active",
          started_at: paidAt,
          expires_at: expiresAt.toISOString(),
          payment_status: "completed",
          payment_completed_at: paidAt,
          updated_at: paidAt,
          payment_reference: orderNumber,
        })
        .eq("id", subscription.id);

      await client
        .from("subscription_payments")
        .update({
          status: "completed",
          paid_at: paidAt,
          gateway_transaction_id: gatewayTransactionId,
          failure_reason: null,
          updated_at: paidAt,
        })
        .eq("id", payment.id);

      res.statusCode = 200;
      res.end("OK");
      return;
    }

    // Failed or unknown status
    await client
      .from("subscription_payments")
      .update({
        status: "failed",
        failure_reason: body.status_description ?? "Payment failed",
        updated_at: paidAt,
      })
      .eq("id", payment.id);

    await client
      .from("subscriptions")
      .update({
        payment_status: "failed",
        status: "pending_payment",
        updated_at: paidAt,
      })
      .eq("id", payment.subscription_id);

    res.statusCode = 200;
    res.end("Marked failed");
  }
);

