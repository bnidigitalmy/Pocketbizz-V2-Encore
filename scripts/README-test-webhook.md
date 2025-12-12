# 🧪 BCL Webhook Test Script

Test script untuk verify BCL webhook berfungsi dengan betul.

## Prerequisites

1. **BCL API Secret Key** - Dapat dari BCL.my dashboard
2. **Deno** (recommended) atau **Node.js** dengan `tsx`

## Setup

### Option 1: Deno (Recommended)

```bash
# Install Deno (jika belum ada)
# Windows: irm https://deno.land/install.ps1 | iex
# Mac/Linux: curl -fsSL https://deno.land/install.sh | sh

# Set environment variable
export BCL_API_SECRET_KEY='your-bcl-secret-key-from-dashboard'

# Run test
deno run --allow-net --allow-env scripts/test-bcl-webhook.ts
```

### Option 2: Node.js dengan tsx

```bash
# Install tsx
npm install -g tsx

# Set environment variable
export BCL_API_SECRET_KEY='your-bcl-secret-key-from-dashboard'

# Run test
npx tsx scripts/test-bcl-webhook.ts
```

### Option 3: Windows PowerShell

```powershell
# Set environment variable
$env:BCL_API_SECRET_KEY = "your-bcl-secret-key-from-dashboard"

# Run test (dengan Deno)
deno run --allow-net --allow-env scripts/test-bcl-webhook.ts
```

## Test Scenarios

Script akan test:

1. ✅ **Payment Success** - Valid signature, status "success"
2. ✅ **Payment Failed** - Valid signature, status "failed"
3. ❌ **Invalid Signature** - Should return 401
4. ❌ **Missing Checksum** - Should return 401
5. ⚠️ **Missing Order Number** - Should return 200 with message
6. ✅ **Different Status Formats** - "1", "completed", "paid"

## Expected Results

- **Valid signatures**: Status 200, webhook processed
- **Invalid signatures**: Status 401, webhook rejected
- **Missing order_number**: Status 200, but no database update

## Verify Results

1. **Check Supabase Logs**:
   - Go to Edge Functions → `bcl-webhook` → Logs
   - Look for request/response logs

2. **Check Database**:
   ```sql
   -- Check payment records
   SELECT * FROM subscription_payments 
   WHERE payment_reference LIKE 'PBZ-TEST-%'
   ORDER BY created_at DESC;

   -- Check subscriptions
   SELECT * FROM subscriptions 
   WHERE payment_reference LIKE 'PBZ-TEST-%'
   ORDER BY created_at DESC;
   ```

## Troubleshooting

### Error: "BCL_API_SECRET_KEY is required"
- Pastikan environment variable dah set
- Verify secret key betul (sama dengan BCL.my dashboard)

### Error: "Invalid signature" (401)
- Verify `BCL_API_SECRET_KEY` sama dengan BCL.my dashboard
- Check signature generation logic matches webhook

### Error: "No payment found"
- Normal untuk test order_number yang tidak wujud dalam database
- Create test subscription dengan `payment_reference = "PBZ-TEST-001"` untuk test full flow

## Manual Test dengan Real Payment

1. Create subscription dalam app dengan order_number: `PBZ-TEST-REAL-001`
2. Buat payment melalui BCL.my
3. Check webhook logs dalam Supabase
4. Verify database updates

## Notes

- Test order_number menggunakan prefix `PBZ-TEST-*` untuk mudah identify
- Real payments akan guna order_number format: `PBZ-{uuid}`
- Signature verification adalah critical untuk security

