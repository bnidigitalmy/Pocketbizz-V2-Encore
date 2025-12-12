-- ============================================================================
-- ADD REFUND SYSTEM
-- ============================================================================

-- Add refund fields to subscription_payments table
ALTER TABLE subscription_payments
ADD COLUMN IF NOT EXISTS refunded_amount NUMERIC(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS refund_reason TEXT,
ADD COLUMN IF NOT EXISTS refund_reference TEXT, -- Gateway refund reference
ADD COLUMN IF NOT EXISTS refund_receipt_url TEXT;

-- Update status check constraint to include 'refunding'
ALTER TABLE subscription_payments
DROP CONSTRAINT IF EXISTS subscription_payments_status_check;

ALTER TABLE subscription_payments
ADD CONSTRAINT subscription_payments_status_check 
CHECK (status IN ('pending', 'completed', 'failed', 'refunded', 'refunding'));

-- Add index for refunded payments
CREATE INDEX IF NOT EXISTS idx_subscription_payments_refunded 
ON subscription_payments (status, refunded_at) 
WHERE status IN ('refunded', 'refunding');

-- Add refund tracking table
CREATE TABLE IF NOT EXISTS subscription_refunds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES subscription_payments(id) ON DELETE CASCADE,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Refund details
    refund_amount NUMERIC(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'MYR',
    refund_reason TEXT NOT NULL,
    
    -- Gateway
    payment_gateway TEXT NOT NULL DEFAULT 'bcl_my',
    refund_reference TEXT, -- Gateway refund transaction ID
    gateway_response JSONB, -- Full gateway response
    
    -- Status
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    failure_reason TEXT,
    
    -- Metadata
    processed_by UUID REFERENCES auth.users(id), -- Admin who processed refund
    receipt_url TEXT, -- URL to refund receipt
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add index for refunds
CREATE INDEX IF NOT EXISTS idx_subscription_refunds_status 
ON subscription_refunds (status, created_at);

CREATE INDEX IF NOT EXISTS idx_subscription_refunds_payment 
ON subscription_refunds (payment_id);

CREATE INDEX IF NOT EXISTS idx_subscription_refunds_user 
ON subscription_refunds (user_id);

-- Add comments
COMMENT ON COLUMN subscription_payments.refunded_amount IS 'Amount refunded (partial or full)';
COMMENT ON COLUMN subscription_payments.refunded_at IS 'When refund was processed';
COMMENT ON COLUMN subscription_payments.refund_reason IS 'Reason for refund';
COMMENT ON COLUMN subscription_payments.refund_reference IS 'Gateway refund transaction ID';
COMMENT ON COLUMN subscription_payments.refund_receipt_url IS 'URL to refund receipt PDF';

