-- Add retry tracking fields to subscription_payments
ALTER TABLE subscription_payments
ADD COLUMN IF NOT EXISTS retry_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_retry_at TIMESTAMPTZ;

COMMENT ON COLUMN subscription_payments.retry_count IS 'Number of retry attempts made for this payment';
COMMENT ON COLUMN subscription_payments.last_retry_at IS 'Timestamp of the last retry attempt';

