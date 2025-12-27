-- Backend Subscription Enforcement
-- PHASE: Subscriber Expired System - Backend Enforcement
-- 
-- UI block SAHAJA ❌
-- Backend enforcement ✅ (kalau ada backend logic)
--
-- This migration adds database-level subscription checks to prevent
-- expired users from creating/updating data even if they bypass UI.

BEGIN;

-- ============================================================================
-- FUNCTION: Check if user has active subscription
-- ============================================================================

CREATE OR REPLACE FUNCTION check_subscription_active(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_subscription subscriptions%ROWTYPE;
BEGIN
  -- Get most recent subscription for user
  SELECT * INTO v_subscription
  FROM subscriptions
  WHERE user_id = user_uuid
    AND status IN ('active', 'trial', 'grace')
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Return true if subscription exists and is active
  RETURN v_subscription IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Enforce subscription on INSERT
-- ============================================================================

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

-- ============================================================================
-- FUNCTION: Enforce subscription on UPDATE
-- ============================================================================

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

-- ============================================================================
-- TRIGGERS: Apply to critical tables
-- ============================================================================
-- 
-- IMPORTANT: subscriptions table is NOT included in triggers
-- This allows trial subscriptions to be created for new users
--

-- Products
DROP TRIGGER IF EXISTS enforce_subscription_products_insert ON products;
CREATE TRIGGER enforce_subscription_products_insert
  BEFORE INSERT ON products
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

DROP TRIGGER IF EXISTS enforce_subscription_products_update ON products;
CREATE TRIGGER enforce_subscription_products_update
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_update();

-- Stock Items
DROP TRIGGER IF EXISTS enforce_subscription_stock_items_insert ON stock_items;
CREATE TRIGGER enforce_subscription_stock_items_insert
  BEFORE INSERT ON stock_items
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

DROP TRIGGER IF EXISTS enforce_subscription_stock_items_update ON stock_items;
CREATE TRIGGER enforce_subscription_stock_items_update
  BEFORE UPDATE ON stock_items
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_update();

-- Sales
DROP TRIGGER IF EXISTS enforce_subscription_sales_insert ON sales;
CREATE TRIGGER enforce_subscription_sales_insert
  BEFORE INSERT ON sales
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Production Batches
DROP TRIGGER IF EXISTS enforce_subscription_production_batches_insert ON production_batches;
CREATE TRIGGER enforce_subscription_production_batches_insert
  BEFORE INSERT ON production_batches
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Expenses
DROP TRIGGER IF EXISTS enforce_subscription_expenses_insert ON expenses;
CREATE TRIGGER enforce_subscription_expenses_insert
  BEFORE INSERT ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Bookings
DROP TRIGGER IF EXISTS enforce_subscription_bookings_insert ON bookings;
CREATE TRIGGER enforce_subscription_bookings_insert
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Deliveries (correct table name: vendor_deliveries)
DROP TRIGGER IF EXISTS enforce_subscription_vendor_deliveries_insert ON vendor_deliveries;
CREATE TRIGGER enforce_subscription_vendor_deliveries_insert
  BEFORE INSERT ON vendor_deliveries
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Claims (correct table name: consignment_claims)
DROP TRIGGER IF EXISTS enforce_subscription_consignment_claims_insert ON consignment_claims;
CREATE TRIGGER enforce_subscription_consignment_claims_insert
  BEFORE INSERT ON consignment_claims
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Stock Movements (for bulk operations)
DROP TRIGGER IF EXISTS enforce_subscription_stock_movements_insert ON stock_movements;
CREATE TRIGGER enforce_subscription_stock_movements_insert
  BEFORE INSERT ON stock_movements
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

-- Shopping Cart Items (for bulk add)
DROP TRIGGER IF EXISTS enforce_subscription_shopping_cart_items_insert ON shopping_cart_items;
CREATE TRIGGER enforce_subscription_shopping_cart_items_insert
  BEFORE INSERT ON shopping_cart_items
  FOR EACH ROW
  EXECUTE FUNCTION enforce_subscription_on_insert();

COMMIT;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 
-- 1. These triggers will prevent expired users from creating/updating data
--    even if they bypass the UI checks.
--
-- 2. SELECT operations are NOT blocked (read-only mode for expired users)
--
-- 3. DELETE operations are NOT blocked (users can still delete their own data)
--
-- 4. If you need to allow certain operations for expired users, you can:
--    - Modify the trigger function to check specific conditions
--    - Add exceptions for specific tables/operations
--
-- 5. To test backend enforcement:
--    - Set user subscription to expired
--    - Try to INSERT/UPDATE via direct SQL or API call
--    - Should receive error: "Subscription required: User does not have active subscription"
--
-- 6. IMPORTANT: subscriptions table is EXCLUDED from enforcement
--    - This allows trial subscriptions to be created for new users
--    - Subscription creation/updates bypass subscription check (no circular dependency)
--    - Without this exclusion, new users cannot create trial subscriptions
--
-- ============================================================================

