// Supabase Edge Function: Create BCL.my Payment Link with Dynamic Amount
// This function creates a payment link with custom amount for proration payments

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BCL_API_KEY = Deno.env.get("BCL_API_KEY")!; // BCL.my API Key
const BCL_API_SECRET = Deno.env.get("BCL_API_SECRET_KEY")!;

interface CreatePaymentLinkRequest {
  orderId: string;
  amount: number;
  durationMonths: number;
  description?: string;
  redirectUrl?: string;
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      orderId,
      amount,
      durationMonths,
      description,
      redirectUrl,
    }: CreatePaymentLinkRequest = await req.json();

    if (!orderId || !amount || !durationMonths) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: orderId, amount, durationMonths" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Option 1: If BCL.my has Payment Link API
    // Call BCL.my API to create payment link with custom amount
    // const paymentLink = await createBCLPaymentLink({
    //   orderId,
    //   amount,
    //   description: description || `Subscription ${durationMonths} bulan (Prorated)`,
    //   redirectUrl: redirectUrl || `https://app.pocketbizz.my/#/payment-success`,
    // });

    // Option 2: Use Generic Payment Form (if available)
    // Create a generic payment form in BCL.my that accepts amount parameter
    // For now, we'll use a workaround: redirect to closest form and handle amount mismatch

    // Option 3: Temporary Solution - Use closest form and verify amount in webhook
    // This is a workaround until we have proper BCL.my API integration
    const baseUrl = getFormUrlForDuration(durationMonths);
    const paymentUrl = `${baseUrl}?order_id=${orderId}&amount=${amount.toFixed(2)}&prorated=true`;

    // Store prorated amount in database for webhook verification
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    await supabase
      .from("subscription_payments")
      .update({
        expected_amount: amount, // Store expected amount for verification
        notes: `Prorated payment for ${durationMonths} months`,
      })
      .eq("payment_reference", orderId);

    return new Response(
      JSON.stringify({
        success: true,
        paymentUrl,
        orderId,
        amount,
        note: "BCL.my form may show fixed amount, but webhook will verify actual prorated amount",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error creating payment link:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

function getFormUrlForDuration(durationMonths: number): string {
  const formUrls: Record<number, string> = {
    1: "https://bnidigital.bcl.my/form/1-bulan",
    3: "https://bnidigital.bcl.my/form/3-bulan",
    6: "https://bnidigital.bcl.my/form/6-bulan",
    12: "https://bnidigital.bcl.my/form/12-bulan",
  };
  return formUrls[durationMonths] || formUrls[12];
}

// TODO: Implement BCL.my Payment Link API call when available
// async function createBCLPaymentLink(params: {
//   orderId: string;
//   amount: number;
//   description: string;
//   redirectUrl: string;
// }): Promise<string> {
//   const response = await fetch("https://api.bcl.my/v1/payment-links", {
//     method: "POST",
//     headers: {
//       "Authorization": `Bearer ${BCL_API_KEY}`,
//       "Content-Type": "application/json",
//     },
//     body: JSON.stringify({
//       order_id: params.orderId,
//       amount: params.amount,
//       description: params.description,
//       redirect_url: params.redirectUrl,
//     }),
//   });
//   const data = await response.json();
//   return data.payment_url;
// }

