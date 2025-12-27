# 🚨 CRITICAL: Deploy Subscription Enforcement Fix

## Masalah
Registration baru masih kena block kerana migration fix belum di-deploy ke Supabase database.

## Solusi: Deploy Quick Fix

### Step 1: Buka Supabase SQL Editor
1. Login ke Supabase Dashboard
2. Go to SQL Editor
3. Create new query

### Step 2: Copy & Run SQL Fix

Copy **SEMUA content** dari file `QUICK_FIX_SUBSCRIPTION_ENFORCEMENT.sql` dan run di SQL Editor.

**Atau copy ini terus:**

```sql
BEGIN;

-- Update INSERT enforcement function
CREATE OR REPLACE FUNCTION enforce_subscription_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- CRITICAL: Exclude subscriptions table completely
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW; -- Always allow subscription creation/updates
  END IF;
  
  -- For all other tables: check subscription
  IF NOT check_subscription_active(auth.uid()) THEN
    RAISE EXCEPTION 'Subscription required: User does not have active subscription. Please renew your subscription to continue.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update UPDATE enforcement function
CREATE OR REPLACE FUNCTION enforce_subscription_on_update()
RETURNS TRIGGER AS $$
BEGIN
  -- CRITICAL: Exclude subscriptions table completely
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW; -- Always allow subscription creation/updates
  END IF;
  
  -- For all other tables: check subscription
  IF NOT check_subscription_active(auth.uid()) THEN
    RAISE EXCEPTION 'Subscription required: User does not have active subscription. Please renew your subscription to continue.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
```

### Step 3: Verify Fix

Run query ini untuk verify:

```sql
-- Check function definition (should include subscriptions check)
SELECT pg_get_functiondef('enforce_subscription_on_insert'::regproc);
```

**Expected:** Function definition harus ada `IF TG_TABLE_NAME = 'subscriptions'`

### Step 4: Test

1. **Register new account** → Trial harus auto-create ✅
2. **Check subscriptions table:**
   ```sql
   SELECT * FROM subscriptions 
   WHERE user_id = 'your-user-id' 
   ORDER BY created_at DESC 
   LIMIT 1;
   ```
   → Harus ada trial subscription dengan status = 'trial'

3. **Try add stock/product** → Harus success ✅

---

## Jika Masih Tidak Bekerja

### Check 1: Verify Function Updated
```sql
-- Should return function with TG_TABLE_NAME check
SELECT pg_get_functiondef('enforce_subscription_on_insert'::regproc);
```

### Check 2: Verify No Triggers on Subscriptions Table
```sql
-- Should return 0 rows (no triggers on subscriptions table)
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname LIKE '%subscription%' 
AND tgrelid = 'subscriptions'::regclass;
```

### Check 3: Test Manual Subscription Insert
```sql
-- Test if subscription insert works (replace with actual user_id)
-- Should succeed without error
INSERT INTO subscriptions (
  user_id, plan_id, price_per_month, total_amount, 
  status, expires_at, has_ever_had_trial, auto_renew
) VALUES (
  'your-user-id'::uuid,
  (SELECT id FROM subscription_plans WHERE duration_months = 1 LIMIT 1),
  39.0, 0.0, 'trial', NOW() + INTERVAL '7 days', false, false
);
```

---

## After Fix Deployed

1. ✅ **New registrations** → Trial auto-creates
2. ✅ **Existing users without subscription** → Run `2025-01-16_fix_existing_users_without_trial.sql`
3. ✅ **All users** → Can access app with trial/active subscription


