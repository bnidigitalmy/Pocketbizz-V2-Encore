/**
 * Test script untuk verify BCL webhook berfungsi
 * 
 * Usage:
 *   deno run --allow-net --allow-env scripts/test-bcl-webhook.ts
 * 
 * Atau dengan Node.js (install crypto first):
 *   npx tsx scripts/test-bcl-webhook.ts
 */

const WEBHOOK_URL = Deno.env.get("WEBHOOK_URL") || 
  "https://gxllowlurizrkvpdircw.supabase.co/functions/v1/supabase-functions-deploy-bcl-webhook";

const BCL_API_SECRET_KEY = Deno.env.get("BCL_API_SECRET_KEY") || 
  Deno.env.get("TEST_BCL_SECRET") || "";

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

// Build signature string (same logic as webhook)
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

// Compute HMAC-SHA256 hex (same logic as webhook)
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

// Generate valid checksum for payload
const generateChecksum = async (payload: BclPayload, secret: string): Promise<string> => {
  const payloadString = buildSignatureString(payload);
  return await computeHmacHex(payloadString, secret);
};

// Test webhook with payload
const testWebhook = async (
  testName: string,
  payload: BclPayload,
  expectedStatus: number = 200
): Promise<void> => {
  console.log(`\n🧪 Testing: ${testName}`);
  console.log(`📤 Payload:`, JSON.stringify(payload, null, 2));

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const responseText = await response.text();
    let responseData;
    try {
      responseData = JSON.parse(responseText);
    } catch {
      responseData = responseText;
    }

    console.log(`📥 Status: ${response.status} ${response.statusText}`);
    console.log(`📥 Response:`, responseData);

    if (response.status === expectedStatus) {
      console.log(`✅ PASS: Status matches expected (${expectedStatus})`);
    } else {
      console.log(`❌ FAIL: Expected ${expectedStatus}, got ${response.status}`);
    }
  } catch (error) {
    console.error(`❌ ERROR:`, error);
  }
};

// Main test function
const runTests = async () => {
  console.log("🚀 Starting BCL Webhook Tests");
  console.log(`📍 Webhook URL: ${WEBHOOK_URL}`);
  console.log(`🔑 BCL Secret: ${BCL_API_SECRET_KEY ? "✅ Set" : "❌ Missing"}`);

  if (!BCL_API_SECRET_KEY) {
    console.error("\n❌ ERROR: BCL_API_SECRET_KEY is required!");
    console.log("\nSet it via environment variable:");
    console.log("  export BCL_API_SECRET_KEY='your-secret-key'");
    console.log("  deno run --allow-net --allow-env scripts/test-bcl-webhook.ts");
    Deno.exit(1);
  }

  // Test 1: Payment Success (valid signature)
  const successPayload: BclPayload = {
    order_number: "PBZ-TEST-001",
    transaction_id: "TXN-TEST-001",
    amount: "39.00",
    currency: "MYR",
    status: "success",
    status_description: "Payment successful",
    payer_bank_name: "Test Bank",
    exchange_reference_number: "REF-001",
    exchange_transaction_id: "EXCH-001",
  };
  successPayload.checksum = await generateChecksum(successPayload, BCL_API_SECRET_KEY);
  await testWebhook("Payment Success (Valid Signature)", successPayload, 200);

  // Test 2: Payment Failed (valid signature)
  const failedPayload: BclPayload = {
    order_number: "PBZ-TEST-002",
    transaction_id: "TXN-TEST-002",
    amount: "39.00",
    currency: "MYR",
    status: "failed",
    status_description: "Payment failed - insufficient funds",
    payer_bank_name: "Test Bank",
  };
  failedPayload.checksum = await generateChecksum(failedPayload, BCL_API_SECRET_KEY);
  await testWebhook("Payment Failed (Valid Signature)", failedPayload, 200);

  // Test 3: Invalid Signature (should fail)
  const invalidSignaturePayload: BclPayload = {
    order_number: "PBZ-TEST-003",
    transaction_id: "TXN-TEST-003",
    amount: "39.00",
    currency: "MYR",
    status: "success",
    checksum: "invalid-signature-12345",
  };
  await testWebhook("Invalid Signature (Should Fail)", invalidSignaturePayload, 401);

  // Test 4: Missing Checksum (should fail)
  const missingChecksumPayload: BclPayload = {
    order_number: "PBZ-TEST-004",
    transaction_id: "TXN-TEST-004",
    amount: "39.00",
    currency: "MYR",
    status: "success",
  };
  await testWebhook("Missing Checksum (Should Fail)", missingChecksumPayload, 401);

  // Test 5: Missing Order Number (should return 200 but with message)
  const missingOrderPayload: BclPayload = {
    transaction_id: "TXN-TEST-005",
    amount: "39.00",
    currency: "MYR",
    status: "success",
  };
  missingOrderPayload.checksum = await generateChecksum(missingOrderPayload, BCL_API_SECRET_KEY);
  await testWebhook("Missing Order Number", missingOrderPayload, 200);

  // Test 6: Different status formats
  const statusFormats = ["1", "completed", "paid"];
  for (const status of statusFormats) {
    const statusPayload: BclPayload = {
      order_number: `PBZ-TEST-STATUS-${status}`,
      transaction_id: `TXN-STATUS-${status}`,
      amount: "39.00",
      currency: "MYR",
      status: status,
      status_description: `Status: ${status}`,
    };
    statusPayload.checksum = await generateChecksum(statusPayload, BCL_API_SECRET_KEY);
    await testWebhook(`Status Format: "${status}"`, statusPayload, 200);
  }

  console.log("\n✅ All tests completed!");
  console.log("\n📝 Notes:");
  console.log("  - Tests with valid signatures should return 200");
  console.log("  - Tests with invalid/missing signatures should return 401");
  console.log("  - Check Supabase Edge Functions logs for detailed processing");
  console.log("  - Verify database updates in subscription_payments and subscriptions tables");
};

// Run tests
if (import.meta.main) {
  runTests().catch(console.error);
}

