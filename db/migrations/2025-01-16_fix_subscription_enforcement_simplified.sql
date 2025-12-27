-- ============================================================================
-- FIX: Simplified Subscription Enforcement
-- Approach: Exclude subscriptions table completely from triggers
-- ============================================================================
-- 
-- Instead of checking TG_TABLE_NAME in function, we simply don't attach
-- triggers to subscriptions table. This is cleaner and more explicit.

BEGIN;

-- ============================================================================
-- STEP 1: Remove any existing triggers on subscriptions table (if any)
-- ============================================================================

DROP TRIGGER IF EXISTS enforce_subscription_subscriptions_insert ON subscriptions;
DROP TRIGGER IF EXISTS enforce_subscription_subscriptions_update ON subscriptions;

-- ============================================================================
-- STEP 2: Update enforcement functions to be simpler
-- (Keep subscriptions check as safety, but triggers won't be attached)
-- ============================================================================

CREATE OR REPLACE FUNCTION enforce_subscription_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Safety check: Never enforce on subscriptions table
  -- (Even though triggers won't be attached, this is extra safety)
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW;
  END IF;
  
  -- Check if user has active subscription
  IF NOT check_subscription_active(auth.uid()) THEN
    RAISE EXCEPTION 'Subscription required: User does not have active subscription. Please renew your subscription to continue.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enforce_subscription_on_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Safety check: Never enforce on subscriptions table
  IF TG_TABLE_NAME = 'subscriptions' THEN
    RETURN NEW;
  END IF;
  
  -- Check if user has active subscription
  IF NOT check_subscription_active(auth.uid()) THEN
    RAISE EXCEPTION 'Subscription required: User does not have active subscription. Please renew your subscription to continue.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 3: Verify triggers are NOT attached to subscriptions table
-- ============================================================================
-- 
-- Triggers should ONLY be on these tables:
-- - products
-- - stock_items  
-- - sales
-- - production_batches
-- - expenses
-- - bookings
-- - vendor_deliveries
-- - consignment_claims
-- - stock_movements
-- - shopping_cart_items
--
-- subscriptions table should have NO triggers

-- ============================================================================
-- STEP 4: Test verification query
-- ============================================================================
-- Run this to verify subscriptions table has no enforcement triggers:
--
-- SELECT tgname, tgrelid::regclass
-- FROM pg_trigger
-- WHERE tgname LIKE '%subscription%'
-- AND tgrelid = 'subscriptions'::regclass;
--
-- Should return 0 rows

COMMIT;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 
-- 1. Subscriptions table is completely excluded from enforcement
-- 2. No triggers attached to subscriptions table
-- 3. Function still has safety check (but won't be called)
-- 4. Trial subscriptions can be created freely
-- 5. Enforcement only applies to business data tables (products, sales, etc.)
--
-- ============================================================================


