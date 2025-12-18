# ✅ CRON JOB SETUP - NEXT STEPS

**Status:** Cron job created ✅  
**Next:** Verify dan test

---

## 🧪 STEP 1: VERIFY CRON JOB CREATED

### Check dalam Supabase Dashboard:
1. Go to **Database** → **Cron Jobs**
2. Should see `subscription-transitions-hourly` listed
3. Status should be **Active**
4. Schedule should show `0 * * * *` (every hour)

### Check via SQL (optional):
```sql
-- List all cron jobs
SELECT jobid, jobname, schedule, active 
FROM cron.job 
WHERE jobname = 'subscription-transitions-hourly';
```

**Expected:** Should return 1 row with `active = true`

---

## 🚀 STEP 2: TEST EDGE FUNCTION MANUALLY (OPTIONAL)

Sebelum tunggu cron run, test function manually untuk verify ia berfungsi:

### Option A: Via Supabase Dashboard
1. Go to **Edge Functions** → `subscription-transitions`
2. Click **"Invoke function"** button
3. Check response - should see:
   ```json
   {
     "message": "Subscription transitions processed",
     "processed": 0,
     "activated": 0,
     "movedToGrace": 0,
     "expired": 0
   }
   ```

### Option B: Via HTTP (curl/Postman)
```bash
curl -X POST https://gxllowlurizrkvpdircw.supabase.co/functions/v1/subscription-transitions \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

**Expected:** Should return success response

---

## ⏰ STEP 3: WAIT FOR CRON TO RUN (OR TRIGGER MANUALLY)

### Option A: Wait for Next Hour
- Cron akan run automatically pada minute 0 setiap hour
- Contoh: 2:00 PM, 3:00 PM, 4:00 PM, etc.

### Option B: Trigger Manually (Faster Testing)
Dalam Supabase Dashboard:
1. Go to **Database** → **Cron Jobs**
2. Click on `subscription-transitions-hourly`
3. Click **"Run now"** button (if available)
4. Atau wait untuk next scheduled run

---

## 📊 STEP 4: CHECK CRON JOB RUN HISTORY

### Via Dashboard:
1. Go to **Database** → **Cron Jobs**
2. Click on `subscription-transitions-hourly`
3. Check **"Run history"** tab
4. Should see runs listed dengan status (success/failed)

### Via SQL:
```sql
-- Check recent runs
SELECT 
  runid,
  jobid,
  start_time,
  end_time,
  status,
  return_message
FROM cron.job_run_details 
WHERE jobid = (
  SELECT jobid FROM cron.job 
  WHERE jobname = 'subscription-transitions-hourly'
)
ORDER BY start_time DESC 
LIMIT 10;
```

**Expected:**
- `status` should be `succeeded`
- `return_message` should show processed counts

---

## 📝 STEP 5: CHECK EDGE FUNCTION LOGS

1. Go to **Edge Functions** → `subscription-transitions`
2. Click **"Logs"** tab
3. Should see logs untuk setiap run:
   - Success messages
   - Processed counts
   - Any errors (if any)

**Look for:**
```
Subscription transitions processed
processed: X
activated: Y
movedToGrace: Z
expired: W
```

---

## ✅ STEP 6: VERIFY SUBSCRIPTION TRANSITIONS

### Check subscriptions that should transition:

```sql
-- Check subscriptions in grace period
SELECT id, user_id, status, expires_at, grace_until
FROM subscriptions
WHERE status IN ('active', 'grace', 'pending_payment')
ORDER BY expires_at;

-- Check if any moved to grace
SELECT id, user_id, status, expires_at, grace_until, updated_at
FROM subscriptions
WHERE status = 'grace'
ORDER BY updated_at DESC;

-- Check if any expired
SELECT id, user_id, status, expires_at, updated_at
FROM subscriptions
WHERE status = 'expired'
AND updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;
```

**Expected:**
- Subscriptions past `expires_at` should have `status = 'grace'`
- Subscriptions past `grace_until` should have `status = 'expired'`
- `pending_payment` with completed payment should be `active`

---

## 🎯 STEP 7: MONITOR FOR 24 HOURS

Monitor cron job untuk 24 jam untuk ensure:
- ✅ Runs every hour tanpa errors
- ✅ Transitions work correctly
- ✅ No performance issues
- ✅ Edge Function logs show success

---

## 🐛 TROUBLESHOOTING

### Cron job tidak run:
1. Check `cron.job` table - verify `active = true`
2. Check `cron.job_run_details` untuk error messages
3. Verify `pg_cron` extension enabled
4. Check Supabase project status

### Edge Function errors:
1. Check Edge Function logs
2. Verify environment variables set correctly
3. Check service role key valid
4. Verify function deployed correctly

### Transitions tidak berlaku:
1. Check subscription dates - mungkin belum sampai masa
2. Verify Edge Function actually running (check logs)
3. Check database for any constraint violations
4. Verify RLS policies allow updates

---

## 📋 CHECKLIST

- [ ] Cron job created dan active
- [ ] Edge Function tested manually (optional)
- [ ] Cron job run at least once
- [ ] Run history shows success
- [ ] Edge Function logs show processed counts
- [ ] Subscriptions transition correctly
- [ ] Monitor for 24 hours

---

## 🎉 DONE!

Jika semua checklist ✅, cron job setup complete!

**Next:** Monitor untuk ensure everything working smoothly. Jika ada issues, check logs dan troubleshoot.

---

**Status:** Ready to verify ✅
