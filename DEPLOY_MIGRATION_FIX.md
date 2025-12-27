# 🚨 CRITICAL: Deploy Migration Fix untuk Trial Creation

## Masalah

Registration baru pun masih kena block kerana:
- Migration fix belum di-deploy ke Supabase
- Function `enforce_subscription_on_insert()` masih block `subscriptions` table
- Trial creation gagal → User tidak ada subscription → Blocked

## Solusi: Deploy Migration

### Step 1: Verify Current Function

Check function di Supabase SQL Editor:

```sql
-- Check current function definition
SELECT pg_get_functiondef('enforce_subscription_on_insert'::regproc);
```

**Jika masih TIDAK ada `IF TG_TABLE_NAME = 'subscriptions'` check** → Perlu deploy migration

### Step 2: Deploy Migration Fix

**Run SQL ini di Supabase SQL Editor:**

```sql
-- ============================================================================
-- FIX: Allow subscription creation for new users
-- ============================================================================

BEGIN;

-- Update INSERT enforcement function
CREATE OR REPLACE FUNCTION enforce_subscription_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- CRITICAL: Exclude subscriptions table from enforcement
  -- This allows trial subscriptions to be created for new users
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW; -- Allow subscription creation without subscription check
  END IF;
  
  -- Check if user has active subscription
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
  -- CRITICAL: Exclude subscriptions table from enforcement
  -- This allows subscription status updates (e.g., trial → active)
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW; -- Allow subscription updates without subscription check
  END IF;
  
  -- Check if user has active subscription
  IF NOT check_subscription_active(auth.uid()) THEN
    RAISE EXCEPTION 'Subscription required: User does not have active subscription. Please renew your subscription to continue.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
```

### Step 3: Verify Fix

```sql
-- Test: Check function definition (should include subscriptions check)
SELECT pg_get_functiondef('enforce_subscription_on_insert'::regproc);
```

**Expected:** Function harus ada `IF TG_TABLE_NAME = 'subscriptions'` check

### Step 4: Test Registration

1. Register new account
2. Check `subscriptions` table → Trial subscription harus auto-create
3. Try add product/stock → Harus success

---

## Alternative: Quick Fix (If Migration File Already Updated)

Jika migration file dah updated, boleh:

1. **Copy migration file content** (`db/migrations/2025-01-16_backend_subscription_enforcement.sql`)
2. **Run di Supabase SQL Editor**
3. Atau **deploy via Supabase CLI** (jika ada setup)

---

## Verification Checklist

- [ ] Migration deployed to Supabase
- [ ] Function `enforce_subscription_on_insert()` includes subscriptions check
- [ ] Function `enforce_subscription_on_update()` includes subscriptions check
- [ ] Test registration → Trial auto-creates
- [ ] Test add product → Success
- [ ] Test add stock → Success

---

## After Migration Deployed

1. **New registrations** → Trial auto-creates ✅
2. **Existing users without subscription** → Run `2025-01-16_fix_existing_users_without_trial.sql`
3. **All users** → Should have access with trial/active subscription ✅


