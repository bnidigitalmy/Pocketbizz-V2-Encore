-- ============================================================================
-- Auto-create Trial Subscription on New User (Server-side, guaranteed)
-- ============================================================================
-- Problem: Trial creation previously relied on client-side calls (LoginPage),
-- and failures were swallowed. That results in no row in `subscriptions`,
-- so backend enforcement blocks all INSERT/UPDATE operations.
--
-- Fix: Create trial subscription in DB on auth.users insert (handle_new_user).
-- This runs regardless of client flow (web/mobile, auto-login, deep links).
--
-- Notes:
-- - Uses SECURITY DEFINER to bypass RLS.
-- - Best-effort early adopter registration (does not block signup).
-- - Respects trial reuse prevention via `has_ever_had_trial`.
-- ============================================================================

BEGIN;

-- Ensure columns exist (idempotent safety)
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS has_ever_had_trial BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN NOT NULL DEFAULT FALSE;

-- DB helper to ensure trial exists for a given user id (does not require auth.uid())
CREATE OR REPLACE FUNCTION public.ensure_trial_subscription_for_user(user_uuid UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_id UUID;
  v_plan_id UUID;
  v_is_early BOOLEAN := FALSE;
  v_trial_ends_at TIMESTAMPTZ;
  v_new_id UUID;
  v_user_email TEXT;
BEGIN
  -- If user already has active access, return it.
  SELECT id INTO v_existing_id
  FROM public.subscriptions
  WHERE user_id = user_uuid
    AND status IN ('active', 'trial', 'grace')
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  -- Trial once in a lifetime.
  IF EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = user_uuid
      AND has_ever_had_trial = TRUE
  ) THEN
    RETURN NULL;
  END IF;

  -- Find 1-month plan to attach to trial.
  SELECT id INTO v_plan_id
  FROM public.subscription_plans
  WHERE duration_months = 1
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'No 1-month subscription plan found';
  END IF;

  -- Get email (best-effort)
  BEGIN
    SELECT email INTO v_user_email FROM auth.users WHERE id = user_uuid;
  EXCEPTION WHEN OTHERS THEN
    v_user_email := NULL;
  END;

  -- Early adopter (best-effort)
  BEGIN
    IF v_user_email IS NOT NULL THEN
      PERFORM public.register_early_adopter(user_uuid, v_user_email);
    END IF;
    v_is_early := public.is_early_adopter(user_uuid);
  EXCEPTION WHEN OTHERS THEN
    v_is_early := FALSE;
  END;

  v_trial_ends_at := NOW() + INTERVAL '7 days';

  INSERT INTO public.subscriptions (
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
    auto_renew,
    created_at,
    updated_at
  ) VALUES (
    user_uuid,
    v_plan_id,
    CASE WHEN v_is_early THEN 29.0 ELSE 39.0 END,
    0.0,
    0.0,
    v_is_early,
    'trial',
    NOW(),
    v_trial_ends_at,
    v_trial_ends_at,
    TRUE,
    FALSE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

-- Replace handle_new_user to ALSO ensure trial subscription exists.
-- Keep existing behavior (create/update public.users + phone sync) but never fail signup.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_phone TEXT;
BEGIN
  user_phone := NEW.raw_user_meta_data->>'phone';

  -- 1) Create/Update profile row (best-effort, never block signup)
  BEGIN
    INSERT INTO public.users (id, email, full_name, phone)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
      user_phone
    )
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, users.full_name),
      phone = COALESCE(EXCLUDED.phone, users.phone),
      updated_at = NOW();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to insert user profile for user %: %', NEW.id, SQLERRM;
  END;

  -- 2) Ensure trial subscription exists (best-effort, never block signup)
  BEGIN
    PERFORM public.ensure_trial_subscription_for_user(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to create trial subscription for user %: %', NEW.id, SQLERRM;
  END;

  -- 3) Try to sync auth.users.phone (optional)
  IF user_phone IS NOT NULL AND user_phone != '' THEN
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE phone = user_phone
          AND id != NEW.id
      ) THEN
        UPDATE auth.users
        SET phone = user_phone,
            updated_at = NOW()
        WHERE id = NEW.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to update auth.users.phone for user %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;


