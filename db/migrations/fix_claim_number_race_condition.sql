-- Fix race condition in claim_number generation
-- Use advisory locks to prevent concurrent inserts from getting same number
-- ============================================================================

-- Drop and recreate function with advisory lock
DROP FUNCTION IF EXISTS generate_claim_number();

CREATE OR REPLACE FUNCTION generate_claim_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'CLM';
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_claim_number TEXT;
    v_lock_key INTEGER;
BEGIN
    -- Use advisory lock to prevent race conditions
    -- Lock key based on year and month to allow parallel inserts for different months
    v_lock_key := ('x' || LPAD(TO_CHAR(NOW(), 'YYYYMM'), 8, '0'))::bit(32)::int;
    
    -- Acquire advisory lock (exclusive, non-blocking if possible)
    PERFORM pg_advisory_xact_lock(v_lock_key);
    
    -- Get next sequence number for this month (now safe from race conditions)
    SELECT COALESCE(MAX(CAST(SUBSTRING(claim_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM consignment_claims
    WHERE claim_number LIKE v_prefix || '-' || v_year || v_month || '-%';
    
    -- Format: CLM-YYMM-0001
    v_claim_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
    
    -- Lock is automatically released at end of transaction
    
    RETURN v_claim_number;
END;
$$ LANGUAGE plpgsql;

-- Verify trigger still exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trigger_set_claim_number'
    ) THEN
        CREATE TRIGGER trigger_set_claim_number
            BEFORE INSERT ON consignment_claims
            FOR EACH ROW
            EXECUTE FUNCTION set_claim_number();
    END IF;
END $$;

