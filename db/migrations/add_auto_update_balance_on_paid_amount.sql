-- AUTO-UPDATE BALANCE_AMOUNT WHEN PAID_AMOUNT CHANGES
-- This trigger ensures balance_amount is always calculated correctly
-- when paid_amount is updated directly on consignment_claims
-- ============================================================================

BEGIN;

-- Function to auto-update balance_amount when paid_amount changes
CREATE OR REPLACE FUNCTION auto_update_balance_from_paid_amount()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-calculate balance_amount = net_amount - paid_amount
    NEW.balance_amount := NEW.net_amount - NEW.paid_amount;
    
    -- Auto-update status if fully paid
    IF NEW.balance_amount <= 0 AND NEW.status IN ('approved', 'submitted') THEN
        NEW.status := 'settled';
        NEW.settled_at := NOW();
    ELSIF NEW.paid_amount > 0 AND NEW.status = 'approved' THEN
        -- Keep as approved if partially paid
        NEW.status := 'approved';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to run before update on consignment_claims
CREATE TRIGGER trigger_auto_update_balance_from_paid
    BEFORE UPDATE OF paid_amount ON consignment_claims
    FOR EACH ROW
    WHEN (OLD.paid_amount IS DISTINCT FROM NEW.paid_amount)
    EXECUTE FUNCTION auto_update_balance_from_paid_amount();

COMMIT;

-- ============================================================================
-- NOTES:
-- This trigger ensures that whenever paid_amount is updated directly,
-- balance_amount is automatically recalculated as net_amount - paid_amount
-- and status is updated to 'settled' if balance_amount <= 0
-- ============================================================================



