# ⚡ APPLY GRACE TRANSITIONS CRON JOB

**Purpose:** Move subscription grace/expiry transitions from read path to scheduled cron job for better performance

---

## 📋 WHAT THIS FIXES

**Problem:**
- `_applyGraceTransitions()` was called on every `getUserSubscription()` read
- Database write operations on read path
- Performance bottleneck under load
- Potential database locks

**Solution:**
- Move transitions to scheduled cron job (runs hourly)
- Remove transitions from `getUserSubscription()` method
- Better performance - reads are now pure reads

---

## 🚀 STEP 1: DEPLOY SUPABASE EDGE FUNCTION

### File: `supabase/functions/subscription-transitions/index.ts`

1. **Deploy Function via Supabase CLI:**
   ```bash
   supabase functions deploy subscription-transitions
   ```

   **Or via Supabase Dashboard:**
   - Go to **Edge Functions** → **Create new function**
   - Name: `subscription-transitions`
   - Copy code from `index.ts`
   - Set environment variables:
     - `SUPABASE_URL`: Your Supabase project URL
     - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key (from Settings → API)

2. **Test Function:**
   ```bash
   # Via CLI
   supabase functions invoke subscription-transitions
   
   # Or via HTTP
   curl -X POST https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions \
     -H "Authorization: Bearer <anon-key>"
   ```

---

## ⏰ STEP 2: SET UP CRON JOB

### Option A: Supabase pg_cron (Recommended if available)

If your Supabase project has `pg_cron` extension enabled:

```sql
-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly subscription transitions
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *', -- Every hour at minute 0
  $$
  PERFORM net.http_post(
    url := 'https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <service-role-key>'
    )
  );
  $$
);
```

**Note:** Replace `<your-project-ref>` and `<service-role-key>` with actual values.

### Option B: External Cron Service (Recommended for Supabase Free/Pro)

Use external service seperti **cron-job.org** atau **EasyCron**:

1. **Sign up** untuk cron service
2. **Create new cron job:**
   - **URL:** `https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions`
   - **Method:** POST
   - **Headers:**
     - `Authorization: Bearer <anon-key>` (atau service-role-key)
     - `Content-Type: application/json`
   - **Schedule:** Every hour (0 * * * *)
   - **Timezone:** UTC

3. **Test:** Trigger manually to verify it works

### Option C: Vercel Cron (if using Vercel)

If you deploy to Vercel, add to `vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/subscription-transitions",
      "schedule": "0 * * * *"
    }
  ]
}
```

---

## ✅ STEP 3: REMOVE TRANSITIONS FROM CODE

**Already done in:** `subscription_repository_supabase.dart`

The code has been updated to remove `_applyGraceTransitions()` call from `getUserSubscription()`.

---

## 🧪 STEP 4: VERIFY CRON JOB

1. **Check Function Logs:**
   - Supabase Dashboard → Edge Functions → `subscription-transitions` → Logs
   - Should see successful runs every hour

2. **Test Manually:**
   ```bash
   # Trigger function manually
   curl -X POST https://<project-ref>.supabase.co/functions/v1/subscription-transitions \
     -H "Authorization: Bearer <anon-key>"
   ```

3. **Verify Transitions:**
   - Check subscriptions that should transition
   - Wait for cron to run
   - Verify status updates correctly

---

## 📝 WHAT THE CRON JOB DOES

The Edge Function processes subscriptions hourly and:

1. **Activates pending_payment** subscriptions if:
   - Payment status is "completed"
   - Start date has been reached

2. **Moves active → grace** if:
   - Current time > expires_at
   - Sends grace reminder email (once)

3. **Moves grace → expired** if:
   - Current time > grace_until

---

## ⚠️ IMPORTANT NOTES

- **Schedule:** Runs every hour (adjust if needed)
- **Performance:** No longer blocks user subscription reads
- **Email:** Grace emails sent once (prevents duplicates)
- **Backward Compatible:** Old code removed, but function can be called manually if needed

---

## 🔄 ROLLBACK (if needed)

If cron job fails, you can temporarily re-enable transitions on read:

```dart
// In getUserSubscription(), change back to:
final updated = await _applyGraceTransitions(json);
return Subscription.fromJson(updated);
```

But this should only be temporary until cron is fixed.

---

**Status:** Code updated ✅ - Deploy function and set up cron
