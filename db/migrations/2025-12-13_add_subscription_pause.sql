-- ============================================================================
-- ADD SUBSCRIPTION PAUSE FUNCTIONALITY
-- ============================================================================

-- Add pause fields to subscriptions table
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS is_paused BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS paused_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pause_reason TEXT,
ADD COLUMN IF NOT EXISTS paused_days INTEGER DEFAULT 0; -- Days paused (to extend expiry)

-- Update status check constraint to include 'paused'
ALTER TABLE subscriptions
DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_status_check 
CHECK (status IN ('trial', 'active', 'expired', 'cancelled', 'pending_payment', 'grace', 'paused'));

-- Add index for paused subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_paused 
ON subscriptions (is_paused, paused_until) 
WHERE is_paused = TRUE;

-- Add comment
COMMENT ON COLUMN subscriptions.is_paused IS 'Whether subscription is currently paused';
COMMENT ON COLUMN subscriptions.paused_at IS 'When subscription was paused';
COMMENT ON COLUMN subscriptions.paused_until IS 'When subscription pause ends (if scheduled)';
COMMENT ON COLUMN subscriptions.pause_reason IS 'Reason for pausing subscription';
COMMENT ON COLUMN subscriptions.paused_days IS 'Total days paused (to extend expiry date)';

