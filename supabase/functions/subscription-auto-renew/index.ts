// Supabase Edge Function to handle subscription auto-renewal
// Should be called via cron job (daily, checks subscriptions expiring in 3 days)
// PHASE 8: Auto-renewal implementation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Helper to add calendar months (handles end-of-month edge cases)
const addCalendarMonths = (date: Date, months: number): Date => {
  const result = new Date(date);
  result.setMonth(result.getMonth() + months);
  // Handle end-of-month edge cases (e.g., Jan 31 + 1 month = Feb 28/29)
  if (result.getDate() !== date.getDate()) {
    result.setDate(0); // Set to last day of previous month
  }
  return result;
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get Supabase client with service role key (bypasses RLS)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const now = new Date();
    const nowIso = now.toISOString();
    
    // Check subscriptions expiring in 3 days (give time for payment processing)
    const renewWindow = new Date(now);
    renewWindow.setDate(renewWindow.getDate() + 3);
    const renewWindowIso = renewWindow.toISOString();

    // Get subscriptions that need auto-renewal:
    // - Status: active
    // - auto_renew: true
    // - expires_at within 3 days
    // - No pending renewal payment already created
    const { data: subscriptions, error: fetchError } = await supabase
      .from("subscriptions")
      .select(`
        *,
        subscription_plans:plan_id (
          id,
          name,
          duration_months,
          price_per_month
        )
      `)
      .eq("status", "active")
      .eq("auto_renew", true)
      .lte("expires_at", renewWindowIso)
      .gte("expires_at", nowIso); // Not expired yet

    if (fetchError) {
      throw new Error(`Failed to fetch subscriptions: ${fetchError.message}`);
    }

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: "No subscriptions to auto-renew", 
          processed: 0,
          renewed: 0,
          failed: 0 
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    let processed = 0;
    let renewed = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const sub of subscriptions) {
      try {
        processed++;

        // Check if renewal payment already exists for this subscription
        const { data: existingPayment, error: paymentCheckError } = await supabase
          .from("subscription_payments")
          .select("id, status")
          .eq("subscription_id", sub.id)
          .eq("status", "pending")
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (paymentCheckError) {
          console.error(`[${nowIso}] Error checking existing payment for subscription ${sub.id}:`, paymentCheckError);
          errors.push(`Subscription ${sub.id}: ${paymentCheckError.message}`);
          failed++;
          continue;
        }

        // If pending payment exists, skip (already processing)
        if (existingPayment) {
          console.log(`[${nowIso}] Subscription ${sub.id} already has pending renewal payment, skipping`);
          continue;
        }

        const plan = sub.subscription_plans as any;
        if (!plan) {
          console.error(`[${nowIso}] No plan data for subscription ${sub.id}`);
          errors.push(`Subscription ${sub.id}: No plan data`);
          failed++;
          continue;
        }

        const userId = sub.user_id as string;
        const planId = plan.id as string;
        const durationMonths = plan.duration_months as number ?? 1;
        const pricePerMonth = plan.price_per_month as number ?? 39.0;
        const isEarlyAdopter = sub.is_early_adopter as boolean ?? false;
        
        // Calculate total amount (early adopter gets RM 29/month, else RM 39/month)
        const actualPricePerMonth = isEarlyAdopter ? 29.0 : pricePerMonth;
        const totalAmount = actualPricePerMonth * durationMonths;

        // Generate order ID for renewal
        const orderId = `PBZ-RENEW-${Date.now()}-${sub.id.substring(0, 8)}`;

        // Calculate new expiry date (extend from current expiry, not from now)
        const currentExpiresAt = new Date(sub.expires_at as string);
        const newExpiresAt = addCalendarMonths(currentExpiresAt, durationMonths);
        const newGraceUntil = new Date(newExpiresAt);
        newGraceUntil.setDate(newGraceUntil.getDate() + 7);

        // Create pending payment record for auto-renewal
        const { error: paymentError } = await supabase
          .from("subscription_payments")
          .insert({
            subscription_id: sub.id,
            user_id: userId,
            amount: totalAmount,
            currency: "MYR",
            payment_gateway: "bcl_my",
            payment_reference: orderId,
            status: "pending",
            payment_method: "auto_renewal",
          });

        if (paymentError) {
          console.error(`[${nowIso}] Failed to create renewal payment for subscription ${sub.id}:`, paymentError);
          errors.push(`Subscription ${sub.id}: ${paymentError.message}`);
          failed++;
          continue;
        }

        // Create pending subscription for renewal (will be activated when payment succeeds)
        // This allows webhook to extend existing subscription
        const { error: pendingSubError } = await supabase
          .from("subscriptions")
          .insert({
            user_id: userId,
            plan_id: planId,
            price_per_month: actualPricePerMonth,
            total_amount: totalAmount,
            discount_applied: 0,
            is_early_adopter: isEarlyAdopter,
            status: "pending_payment",
            expires_at: newExpiresAt.toISOString(),
            grace_until: newGraceUntil.toISOString(),
            payment_gateway: "bcl_my",
            payment_reference: orderId,
            payment_status: "pending",
            auto_renew: true, // Keep auto-renew enabled
            notes: `Auto-renewal for subscription ${sub.id}`,
          });

        if (pendingSubError) {
          console.error(`[${nowIso}] Failed to create pending subscription for renewal ${sub.id}:`, pendingSubError);
          errors.push(`Subscription ${sub.id}: ${pendingSubError.message}`);
          failed++;
          continue;
        }

        // TODO: Call BCL.my API to create payment link and send email to user
        // For now, we create the payment record and pending subscription
        // User will need to complete payment manually or we can integrate BCL.my API
        
        console.log(`[${nowIso}] Created auto-renewal payment for subscription ${sub.id}, order: ${orderId}`);
        renewed++;

      } catch (error) {
        console.error(`[${nowIso}] Error processing subscription ${sub.id}:`, error);
        errors.push(`Subscription ${sub.id}: ${error.message}`);
        failed++;
      }
    }

    return new Response(
      JSON.stringify({
        message: "Auto-renewal processing completed",
        processed,
        renewed,
        failed,
        errors: errors.length > 0 ? errors : undefined,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error processing auto-renewal:`, error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});



