-- ============================================================================
-- Ensure Trial Subscription RPC (DB-side, robust)
-- ============================================================================
-- Goal: Make sure trial subscription is created in DB for eligible users,
-- without relying on client-side inserts that can fail silently.
--
-- This function is SECURITY DEFINER so it can read auth.users and bypass RLS
-- when creating the trial row.
--
-- Usage (client):
--   await supabase.rpc('ensure_trial_subscription');
--
-- Returns: UUID of existing/created subscription, or NULL if not eligible.

BEGIN;

CREATE OR REPLACE FUNCTION public.ensure_trial_subscription()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
  v_existing_id UUID;
  v_plan_id UUID;
  v_is_early BOOLEAN := FALSE;
  v_trial_ends_at TIMESTAMPTZ;
  v_new_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- If user already has active access, return it.
  SELECT id INTO v_existing_id
  FROM public.subscriptions
  WHERE user_id = v_user_id
    AND status IN ('active', 'trial', 'grace')
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  -- Trial once in a lifetime: if user ever had trial, do nothing.
  IF EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = v_user_id
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

  -- Fetch email (best-effort; might be null on some setups)
  BEGIN
    SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;
  EXCEPTION WHEN OTHERS THEN
    v_user_email := NULL;
  END;

  -- Early adopter (best-effort, do not block trial if functions missing)
  BEGIN
    IF v_user_email IS NOT NULL THEN
      PERFORM public.register_early_adopter(v_user_id, v_user_email);
    END IF;
    v_is_early := public.is_early_adopter(v_user_id);
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
    v_user_id,
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

COMMIT;



