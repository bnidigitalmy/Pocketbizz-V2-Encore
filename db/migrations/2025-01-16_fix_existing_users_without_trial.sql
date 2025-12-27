-- Fix: Create trial subscriptions for existing users who don't have one
-- This migration handles users created before the trial creation fix
-- 
-- Problem: Users registered before migration fix may not have trial subscriptions
-- Solution: Create trial subscriptions for users without active subscriptions

BEGIN;

-- ============================================================================
-- FUNCTION: Create trial for user without subscription
-- ============================================================================

CREATE OR REPLACE FUNCTION create_trial_for_user(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
  v_plan_id UUID;
  v_trial_id UUID;
  v_is_early_adopter BOOLEAN;
  v_early_adopter_count INT;
  v_trial_ends_at TIMESTAMPTZ;
BEGIN
  -- Check if user already has active subscription
  IF EXISTS (
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
    AND status IN ('active', 'trial', 'grace')
    AND expires_at > NOW()
  ) THEN
    RAISE NOTICE 'User % already has active subscription', p_user_id;
    RETURN NULL;
  END IF;

  -- Check if user has ever had trial (prevent reuse)
  IF EXISTS (
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
    AND has_ever_had_trial = true
  ) THEN
    RAISE NOTICE 'User % has already used trial', p_user_id;
    RETURN NULL;
  END IF;

  -- Get 1 month plan (for trial)
  SELECT id INTO v_plan_id
  FROM subscription_plans
  WHERE duration_months = 1
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'No 1-month plan found. Please create subscription plans first.';
  END IF;

  -- Check early adopter status
  SELECT COUNT(*) INTO v_early_adopter_count
  FROM early_adopters;

  IF v_early_adopter_count < 100 THEN
    -- Register as early adopter if under 100
    INSERT INTO early_adopters (user_id, email, registered_at)
    SELECT id, email, NOW()
    FROM users
    WHERE id = p_user_id
    ON CONFLICT (user_id) DO NOTHING;
    
    v_is_early_adopter := true;
  ELSE
    -- Check if already registered
    SELECT EXISTS (
      SELECT 1 FROM early_adopters WHERE user_id = p_user_id
    ) INTO v_is_early_adopter;
  END IF;

  -- Calculate trial end date (7 days from now)
  v_trial_ends_at := NOW() + INTERVAL '7 days';

  -- Create trial subscription
  INSERT INTO subscriptions (
    user_id,
    plan_id,
    price_per_month,
    total_amount,
    discount_applied,
    is_early_adopter,
    status,
    trial_started_at,
    trial_ends_at,
    expires_at,
    has_ever_had_trial,
    auto_renew
  ) VALUES (
    p_user_id,
    v_plan_id,
    CASE WHEN v_is_early_adopter THEN 29.0 ELSE 39.0 END,
    0.0, -- Trial is free
    0.0,
    v_is_early_adopter,
    'trial',
    NOW(),
    v_trial_ends_at,
    v_trial_ends_at,
    true, -- Mark that user has used trial
    false
  )
  RETURNING id INTO v_trial_id;

  RAISE NOTICE 'Trial subscription created for user %: %', p_user_id, v_trial_id;
  RETURN v_trial_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- AUTO-FIX: Create trials for all users without subscriptions
-- ============================================================================

DO $$
DECLARE
  v_user RECORD;
  v_trial_id UUID;
  v_fixed_count INT := 0;
BEGIN
  -- Find all users without active subscriptions
  FOR v_user IN
    SELECT u.id, u.email
    FROM users u
    WHERE NOT EXISTS (
      SELECT 1 FROM subscriptions s
      WHERE s.user_id = u.id
      AND s.status IN ('active', 'trial', 'grace')
      AND s.expires_at > NOW()
    )
    AND NOT EXISTS (
      SELECT 1 FROM subscriptions s
      WHERE s.user_id = u.id
      AND s.has_ever_had_trial = true
    )
  LOOP
    BEGIN
      v_trial_id := create_trial_for_user(v_user.id);
      IF v_trial_id IS NOT NULL THEN
        v_fixed_count := v_fixed_count + 1;
        RAISE NOTICE 'Created trial for user: % (%)', v_user.email, v_user.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to create trial for user % (%): %', v_user.email, v_user.id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE 'Migration complete: % users fixed with trial subscriptions', v_fixed_count;
END;
$$;

-- ============================================================================
-- CLEANUP: Drop function after use (optional - can keep for manual fixes)
-- ============================================================================

-- Uncomment to remove function after migration:
-- DROP FUNCTION IF EXISTS create_trial_for_user(UUID);

COMMIT;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 
-- This migration will:
-- 1. Find all users without active subscriptions
-- 2. Check if they've ever had a trial (prevent reuse)
-- 3. Create 7-day trial subscriptions for eligible users
-- 4. Register early adopter status if under 100 users
--
-- To manually create trial for specific user:
-- SELECT create_trial_for_user('user-uuid-here');
--
-- To check users without subscriptions:
-- SELECT u.id, u.email, u.created_at
-- FROM users u
-- WHERE NOT EXISTS (
--   SELECT 1 FROM subscriptions s
--   WHERE s.user_id = u.id
--   AND s.status IN ('active', 'trial', 'grace')
--   AND s.expires_at > NOW()
-- );
--
-- ============================================================================


