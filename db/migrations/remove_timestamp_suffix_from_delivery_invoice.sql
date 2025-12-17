-- Remove timestamp suffix from delivery invoice number generation
-- Format: USER_PREFIX-ORIGINAL_PREFIX-YYMM-XXXX (without timestamp suffix)
-- ============================================================================

BEGIN;

-- Update delivery invoice number generator to remove timestamp suffix
DROP FUNCTION IF EXISTS generate_delivery_invoice_number(UUID);

CREATE OR REPLACE FUNCTION generate_delivery_invoice_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_user_prefix TEXT;
    v_original_prefix TEXT := 'DEL';
    v_full_prefix TEXT;
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_invoice_number TEXT;
    v_lock_key BIGINT;
BEGIN
    -- Get user prefix from business_profile (optional)
    SELECT invoice_prefix INTO v_user_prefix
      FROM business_profile
     WHERE business_owner_id = p_owner_id;
    
    -- Build full prefix: USER_PREFIX-ORIGINAL or just ORIGINAL
    IF v_user_prefix IS NOT NULL AND v_user_prefix != '' THEN
      v_full_prefix := v_user_prefix || '-' || v_original_prefix;
    ELSE
      v_full_prefix := v_original_prefix;
    END IF;
    
    -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
    v_lock_key := (
      (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
      + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
    );
    PERFORM pg_advisory_xact_lock(v_lock_key);
    
    -- Get next sequence number for this month (per owner)
    -- Handle both old formats (with/without timestamp suffix) and new format
    SELECT COALESCE(MAX(
        CASE 
            -- New format without timestamp: USER_PREFIX-DEL-YYMM-XXXX or DEL-YYMM-XXXX
            WHEN invoice_number ~ ('^' || v_full_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_full_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            -- Old format with timestamp: PREFIX-DEL-YYMM-XXXX-UUUUUU or DEL-YYMM-XXXX-UUUUUU
            WHEN invoice_number ~ ('^' || v_full_prefix || '-' || v_year || v_month || '-[0-9]{4}-[0-9]{6}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_full_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
    INTO v_seq_num
    FROM vendor_deliveries
    WHERE business_owner_id = p_owner_id
      AND (
        invoice_number LIKE v_full_prefix || '-' || v_year || v_month || '-%'
      );
    
    -- Format: USER_PREFIX-DEL-YYMM-XXXX or DEL-YYMM-XXXX (NO timestamp suffix)
    v_invoice_number := v_full_prefix || '-' || v_year || v_month || '-' || 
                       LPAD(v_seq_num::TEXT, 4, '0');
    
    -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
    WHILE EXISTS (SELECT 1 FROM vendor_deliveries WHERE invoice_number = v_invoice_number AND business_owner_id = p_owner_id) LOOP
        v_seq_num := v_seq_num + 1;
        v_invoice_number := v_full_prefix || '-' || v_year || v_month || '-' || 
                           LPAD(v_seq_num::TEXT, 4, '0');
    END LOOP;
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger function to use the updated generator function
CREATE OR REPLACE FUNCTION set_delivery_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        NEW.invoice_number := generate_delivery_invoice_number(NEW.business_owner_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_set_delivery_invoice_number ON vendor_deliveries;

CREATE TRIGGER trigger_set_delivery_invoice_number
    BEFORE INSERT ON vendor_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION set_delivery_invoice_number();

COMMIT;

