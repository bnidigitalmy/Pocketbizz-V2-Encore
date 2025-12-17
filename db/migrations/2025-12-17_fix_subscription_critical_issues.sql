-- ============================================================================
-- FIX SUBSCRIPTION CRITICAL ISSUES (Priority 1)
-- ============================================================================
-- 1. Add has_ever_had_trial flag to prevent trial reuse
-- 2. Add grace_email_sent flag to prevent duplicate grace emails
-- 3. Update grace period access logic (already handled in isActive getter)

-- Add has_ever_had_trial column
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS has_ever_had_trial BOOLEAN NOT NULL DEFAULT FALSE;

-- Add grace_email_sent column
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS grace_email_sent BOOLEAN NOT NULL DEFAULT FALSE;

-- Update existing subscriptions that have had trial
UPDATE subscriptions
SET has_ever_had_trial = TRUE
WHERE status = 'trial' OR status = 'expired' OR status = 'cancelled';

-- Add comments
COMMENT ON COLUMN subscriptions.has_ever_had_trial IS 'Whether user has ever started a trial (prevents reuse)';
COMMENT ON COLUMN subscriptions.grace_email_sent IS 'Whether grace period reminder email has been sent (prevents duplicates)';

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_has_ever_had_trial 
ON subscriptions (user_id, has_ever_had_trial) 
WHERE has_ever_had_trial = TRUE;

