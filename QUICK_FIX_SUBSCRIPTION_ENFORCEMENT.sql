-- ============================================================================
-- QUICK FIX: Allow Subscription Creation
-- ============================================================================
-- 
-- Run this in Supabase SQL Editor to fix subscription enforcement
-- This ensures subscriptions table is NOT blocked by enforcement triggers

BEGIN;

-- Step 1: Update enforcement functions to exclude subscriptions table
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

-- Step 2: Verify no triggers on subscriptions table
-- (Should return 0 rows if correct)
-- Run this separately to verify:
-- SELECT tgname, tgrelid::regclass
-- FROM pg_trigger
-- WHERE tgname LIKE '%subscription%' 
-- AND tgrelid = 'subscriptions'::regclass;

COMMIT;

-- ============================================================================
-- VERIFICATION:
-- ============================================================================
-- 
-- After running, test:
-- 1. Register new user → Trial should auto-create ✅
-- 2. Check subscriptions table → Should see trial subscription ✅
-- 3. Try add product/stock → Should work ✅
--
-- ============================================================================


