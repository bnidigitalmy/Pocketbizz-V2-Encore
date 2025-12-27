-- ============================================================================
-- Fix: check_subscription_active() should honor grace_until
-- ============================================================================
-- Previous behavior:
--   - Required expires_at > now() even for status='grace'
--   - This blocks users during grace period (grace_until still in future)
--
-- New behavior:
--   - Allow if:
--     - status in ('trial','active') AND expires_at > now()
--     - OR grace_until > now() (covers status='grace' and delayed transitions)
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION check_subscription_active(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_has_access BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM subscriptions
    WHERE user_id = user_uuid
      AND status IN ('active', 'trial', 'grace')
      AND (
        expires_at > NOW()
        OR (grace_until IS NOT NULL AND grace_until > NOW())
      )
  ) INTO v_has_access;

  RETURN v_has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;


