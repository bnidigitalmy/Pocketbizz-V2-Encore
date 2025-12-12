-- Add grace period support to subscriptions

-- Allow new status 'grace'
ALTER TABLE subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE subscriptions
  ADD CONSTRAINT subscriptions_status_check
  CHECK (status IN ('trial', 'active', 'grace', 'expired', 'cancelled', 'pending_payment'));

-- Track end of grace period
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS grace_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_subscriptions_grace_until ON subscriptions(grace_until);
-- Add grace period support to subscriptions

-- Allow new status 'grace'
ALTER TABLE subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE subscriptions
  ADD CONSTRAINT subscriptions_status_check
  CHECK (status IN ('trial', 'active', 'grace', 'expired', 'cancelled', 'pending_payment'));

-- Track end of grace period
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS grace_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_subscriptions_grace_until ON subscriptions(grace_until);

