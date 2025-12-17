-- Update generator functions to use prefix as prepend to document number
-- Format: USER_PREFIX-ORIGINAL_PREFIX-YYMM-0001
-- Example: ABC-DEL-2512-0001 (if user prefix is ABC, original is DEL)
-- If no user prefix: DEL-2512-0001 (original format)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE DELIVERY INVOICE NUMBER GENERATOR
-- Format: USER_PREFIX-DEL-YYMM-XXXX-UUUUUU (or DEL-YYMM-XXXX-UUUUUU if no prefix)
-- ============================================================================

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
    v_timestamp_suffix TEXT;
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
    -- Handle patterns: USER_PREFIX-DEL-YYMM-XXXX-UUUUUU, USER_PREFIX-DEL-YYMM-XXXX, DEL-YYMM-XXXX-UUUUUU, DEL-YYMM-XXXX
    SELECT COALESCE(MAX(
        CASE 
            -- Format with microseconds: PREFIX-DEL-YYMM-XXXX-UUUUUU or DEL-YYMM-XXXX-UUUUUU
            WHEN invoice_number ~ ('^' || v_full_prefix || '-' || v_year || v_month || '-[0-9]{4}-[0-9]{6}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_full_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            -- Format without microseconds: PREFIX-DEL-YYMM-XXXX or DEL-YYMM-XXXX
            WHEN invoice_number ~ ('^' || v_full_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_full_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
    INTO v_seq_num
    FROM vendor_deliveries
    WHERE business_owner_id = p_owner_id
      AND invoice_number LIKE v_full_prefix || '-' || v_year || v_month || '-%';
    
    -- Get timestamp suffix (last 6 digits of microseconds) for additional uniqueness
    v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
    
    -- Format: USER_PREFIX-DEL-YYMM-XXXX-UUUUUU or DEL-YYMM-XXXX-UUUUUU
    v_invoice_number := v_full_prefix || '-' || v_year || v_month || '-' || 
                       LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    
    -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
    WHILE EXISTS (SELECT 1 FROM vendor_deliveries WHERE invoice_number = v_invoice_number) LOOP
        v_seq_num := v_seq_num + 1;
        v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
        v_invoice_number := v_full_prefix || '-' || v_year || v_month || '-' || 
                           LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    END LOOP;
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. UPDATE CLAIM NUMBER GENERATOR
-- Format: USER_PREFIX-CLM-YYMM-0001 (or CLM-YYMM-0001 if no prefix)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.generate_claim_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_prefix TEXT;
  v_original_prefix TEXT := 'CLM';
  v_full_prefix TEXT;
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_claim_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get user prefix from business_profile (optional)
  SELECT claim_prefix INTO v_user_prefix
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

  -- Get next sequence number, handle both formats: USER_PREFIX-CLM-YYMM-XXXX and CLM-YYMM-XXXX
  SELECT COALESCE(MAX(CAST(SUBSTRING(claim_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM public.consignment_claims
   WHERE business_owner_id = p_owner_id
     AND claim_number LIKE (v_full_prefix || '-' || v_year || v_month || '-%');

  v_claim_number := v_full_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_claim_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. UPDATE PAYMENT NUMBER GENERATOR
-- Format: USER_PREFIX-PAY-YYMM-0001 (or PAY-YYMM-0001 if no prefix)
-- ============================================================================

DROP FUNCTION IF EXISTS generate_payment_number(UUID);

CREATE OR REPLACE FUNCTION generate_payment_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_prefix TEXT;
  v_original_prefix TEXT := 'PAY';
  v_full_prefix TEXT;
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_payment_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get user prefix from business_profile (optional)
  SELECT payment_prefix INTO v_user_prefix
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

  SELECT COALESCE(MAX(CAST(SUBSTRING(payment_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM consignment_payments
   WHERE business_owner_id = p_owner_id
     AND payment_number LIKE (v_full_prefix || '-' || v_year || v_month || '-%');
    
  v_payment_number := v_full_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. UPDATE BOOKING PAYMENT NUMBER GENERATOR
-- Format: USER_PREFIX-PAY-YYMM-0001 (or PAY-YYMM-0001 if no prefix)
-- ============================================================================

DROP FUNCTION IF EXISTS generate_booking_payment_number(UUID);

CREATE OR REPLACE FUNCTION generate_booking_payment_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_prefix TEXT;
  v_original_prefix TEXT := 'PAY';
  v_full_prefix TEXT;
  v_year TEXT := TO_CHAR(CURRENT_DATE, 'YY');
  v_month TEXT := TO_CHAR(CURRENT_DATE, 'MM');
  v_seq_num INTEGER;
  v_payment_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get user prefix from business_profile (optional)
  SELECT payment_prefix INTO v_user_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

  -- Build full prefix: USER_PREFIX-ORIGINAL or just ORIGINAL
  IF v_user_prefix IS NOT NULL AND v_user_prefix != '' THEN
    v_full_prefix := v_user_prefix || '-' || v_original_prefix;
  ELSE
    v_full_prefix := v_original_prefix;
  END IF;

  -- Advisory lock key: hash(owner) + YYYYMM
  v_lock_key := (
    (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
    + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(CAST(SUBSTRING(payment_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM booking_payments
   WHERE business_owner_id = p_owner_id
     AND payment_number LIKE (v_full_prefix || '-' || v_year || v_month || '-%');

  v_payment_number := v_full_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

COMMIT;

