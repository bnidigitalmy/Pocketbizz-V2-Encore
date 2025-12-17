-- Update generator functions to use prefix from business_profile
-- All generators now accept business_owner_id and fetch custom prefix
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE DELIVERY INVOICE NUMBER GENERATOR
-- ============================================================================

DROP FUNCTION IF EXISTS generate_delivery_invoice_number();
DROP FUNCTION IF EXISTS generate_delivery_invoice_number(UUID);

CREATE OR REPLACE FUNCTION generate_delivery_invoice_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT;
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_timestamp_suffix TEXT;
    v_invoice_number TEXT;
    v_lock_key BIGINT;
BEGIN
    -- Get prefix from business_profile, default to 'DEL' if not found
    SELECT COALESCE(invoice_prefix, 'DEL')
      INTO v_prefix
      FROM business_profile
     WHERE business_owner_id = p_owner_id;
    
    -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
    v_lock_key := (
      (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
      + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
    );
    PERFORM pg_advisory_xact_lock(v_lock_key);
    
    -- Get next sequence number for this month (per owner)
    SELECT COALESCE(MAX(
        CASE 
            -- New format: PREFIX-YYMM-XXXX-UUUUUU
            WHEN invoice_number ~ ('^' || v_prefix || '-' || v_year || v_month || '-[0-9]{4}-[0-9]{6}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            -- Old format: PREFIX-YYMM-XXXX
            WHEN invoice_number ~ ('^' || v_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
                CAST(SUBSTRING(invoice_number FROM LENGTH(v_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
    INTO v_seq_num
    FROM vendor_deliveries
    WHERE business_owner_id = p_owner_id
      AND invoice_number LIKE v_prefix || '-' || v_year || v_month || '-%';
    
    -- Get timestamp suffix (last 6 digits of microseconds) for additional uniqueness
    v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
    
    -- Format: PREFIX-YYMM-XXXX-UUUUUU
    v_invoice_number := v_prefix || '-' || v_year || v_month || '-' || 
                       LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    
    -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
    WHILE EXISTS (SELECT 1 FROM vendor_deliveries WHERE invoice_number = v_invoice_number) LOOP
        v_seq_num := v_seq_num + 1;
        v_timestamp_suffix := LPAD(TO_CHAR(EXTRACT(MICROSECONDS FROM NOW())::BIGINT % 1000000, 'FM999999'), 6, '0');
        v_invoice_number := v_prefix || '-' || v_year || v_month || '-' || 
                           LPAD(v_seq_num::TEXT, 4, '0') || '-' || v_timestamp_suffix;
    END LOOP;
    
    RETURN v_invoice_number;
END;
$$ LANGUAGE plpgsql;

-- Update trigger function to pass business_owner_id
CREATE OR REPLACE FUNCTION set_delivery_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
        NEW.invoice_number := generate_delivery_invoice_number(NEW.business_owner_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. UPDATE CLAIM NUMBER GENERATOR (already updated in fix_consignment_claim_number_per_owner.sql)
-- Just need to update to use prefix from business_profile
-- ============================================================================

CREATE OR REPLACE FUNCTION public.generate_claim_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_claim_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get prefix from business_profile, default to 'CLM' if not found
  SELECT COALESCE(claim_prefix, 'CLM')
    INTO v_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

  -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
  v_lock_key := (
    (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
    + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(CAST(SUBSTRING(claim_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM public.consignment_claims
   WHERE business_owner_id = p_owner_id
     AND claim_number LIKE (v_prefix || '-' || v_year || v_month || '-%');

  v_claim_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_claim_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. UPDATE PAYMENT NUMBER GENERATOR
-- ============================================================================

DROP FUNCTION IF EXISTS generate_payment_number();
DROP FUNCTION IF EXISTS generate_payment_number(UUID);

CREATE OR REPLACE FUNCTION generate_payment_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_payment_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get prefix from business_profile, default to 'PAY' if not found
  SELECT COALESCE(payment_prefix, 'PAY')
    INTO v_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

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
     AND payment_number LIKE (v_prefix || '-' || v_year || v_month || '-%');
    
  v_payment_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

-- Update trigger function to pass business_owner_id
CREATE OR REPLACE FUNCTION set_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
        NEW.payment_number := generate_payment_number(NEW.business_owner_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. UPDATE BOOKING PAYMENT NUMBER GENERATOR (optional - if using same prefix)
-- ============================================================================

DROP FUNCTION IF EXISTS generate_booking_payment_number();
DROP FUNCTION IF EXISTS generate_booking_payment_number(UUID);

CREATE OR REPLACE FUNCTION generate_booking_payment_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_year TEXT := TO_CHAR(CURRENT_DATE, 'YY');
  v_month TEXT := TO_CHAR(CURRENT_DATE, 'MM');
  v_seq_num INTEGER;
  v_payment_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Get prefix from business_profile, default to 'PAY' if not found
  SELECT COALESCE(payment_prefix, 'PAY')
    INTO v_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

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
     AND payment_number LIKE (v_prefix || '-' || v_year || v_month || '-%');

  v_payment_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

-- Update trigger function to pass business_owner_id
CREATE OR REPLACE FUNCTION set_booking_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
        NEW.payment_number := generate_booking_payment_number(NEW.business_owner_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;

