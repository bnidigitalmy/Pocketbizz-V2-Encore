-- Add PO and Booking number generators with prefix support
-- Format: USER_PREFIX-ORIGINAL_PREFIX-YYMM-0001
-- ============================================================================

BEGIN;

-- 1. CREATE PO NUMBER GENERATOR
DROP FUNCTION IF EXISTS generate_po_number(UUID);

CREATE OR REPLACE FUNCTION generate_po_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_prefix TEXT;
  v_original_prefix TEXT := 'PO'; -- Original hardcoded prefix
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_po_number TEXT;
  v_lock_key BIGINT;
  v_full_prefix_pattern TEXT;
BEGIN
  -- Get user-defined prefix from business_profile
  SELECT COALESCE(po_prefix, '')
    INTO v_user_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

  -- Construct the full prefix pattern for LIKE clause
  IF v_user_prefix = '' THEN
    v_full_prefix_pattern := v_original_prefix || '-' || v_year || v_month || '-%';
  ELSE
    v_full_prefix_pattern := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-%';
  END IF;

  -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
  v_lock_key := (
    (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
    + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);
  
  -- Get next sequence number for this month (per owner)
  SELECT COALESCE(MAX(
    CASE 
      -- New format: USER_PREFIX-ORIGINAL_PREFIX-YYMM-XXXX
      WHEN po_number ~ ('^' || v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
        CAST(SUBSTRING(po_number FROM LENGTH(v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
      -- Fallback to original prefix only if user_prefix is empty
      WHEN v_user_prefix = '' AND po_number ~ ('^' || v_original_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
        CAST(SUBSTRING(po_number FROM LENGTH(v_original_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
      ELSE 0
    END
  ), 0) + 1
  INTO v_seq_num
  FROM purchase_orders
  WHERE business_owner_id = p_owner_id
    AND po_number LIKE v_full_prefix_pattern;
  
  -- Construct final PO number
  IF v_user_prefix = '' THEN
    v_po_number := v_original_prefix || '-' || v_year || v_month || '-' || 
                   LPAD(v_seq_num::TEXT, 4, '0');
  ELSE
    v_po_number := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-' || 
                   LPAD(v_seq_num::TEXT, 4, '0');
  END IF;
  
  -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
  WHILE EXISTS (SELECT 1 FROM purchase_orders WHERE po_number = v_po_number AND business_owner_id = p_owner_id) LOOP
    v_seq_num := v_seq_num + 1;
    IF v_user_prefix = '' THEN
      v_po_number := v_original_prefix || '-' || v_year || v_month || '-' || 
                     LPAD(v_seq_num::TEXT, 4, '0');
    ELSE
      v_po_number := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-' || 
                     LPAD(v_seq_num::TEXT, 4, '0');
    END IF;
  END LOOP;
  
  RETURN v_po_number;
END;
$$ LANGUAGE plpgsql;

-- 2. CREATE BOOKING NUMBER GENERATOR
DROP FUNCTION IF EXISTS generate_booking_number(UUID);

CREATE OR REPLACE FUNCTION generate_booking_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_prefix TEXT;
  v_original_prefix TEXT := 'BKG'; -- Original hardcoded prefix
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_booking_number TEXT;
  v_lock_key BIGINT;
  v_full_prefix_pattern TEXT;
BEGIN
  -- Get user-defined prefix from business_profile
  SELECT COALESCE(booking_prefix, '')
    INTO v_user_prefix
    FROM business_profile
   WHERE business_owner_id = p_owner_id;

  -- Construct the full prefix pattern for LIKE clause
  IF v_user_prefix = '' THEN
    v_full_prefix_pattern := v_original_prefix || '-' || v_year || v_month || '-%';
  ELSE
    v_full_prefix_pattern := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-%';
  END IF;

  -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
  v_lock_key := (
    (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
    + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);
  
  -- Get next sequence number for this month (per owner)
  -- Handle both old format (B0001) and new format (USER_PREFIX-BKG-YYMM-0001)
  SELECT COALESCE(MAX(
    CASE 
      -- New format: USER_PREFIX-ORIGINAL_PREFIX-YYMM-XXXX
      WHEN booking_number ~ ('^' || v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
        CAST(SUBSTRING(booking_number FROM LENGTH(v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
      -- Old format: B0001, B0002, etc.
      WHEN booking_number ~ '^B[0-9]+$' THEN
        CAST(SUBSTRING(booking_number FROM 2) AS INTEGER)
      -- Fallback to original prefix only if user_prefix is empty
      WHEN v_user_prefix = '' AND booking_number ~ ('^' || v_original_prefix || '-' || v_year || v_month || '-[0-9]{4}$') THEN
        CAST(SUBSTRING(booking_number FROM LENGTH(v_original_prefix || '-' || v_year || v_month || '-') + 1 FOR 4) AS INTEGER)
      ELSE 0
    END
  ), 0) + 1
  INTO v_seq_num
  FROM bookings
  WHERE business_owner_id = p_owner_id
    AND (
      booking_number LIKE v_full_prefix_pattern
      OR booking_number ~ '^B[0-9]+$'  -- Include old format for migration
    );
  
  -- Construct final booking number
  IF v_user_prefix = '' THEN
    v_booking_number := v_original_prefix || '-' || v_year || v_month || '-' || 
                        LPAD(v_seq_num::TEXT, 4, '0');
  ELSE
    v_booking_number := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-' || 
                        LPAD(v_seq_num::TEXT, 4, '0');
  END IF;
  
  -- Double-check for uniqueness (shouldn't happen with lock, but safety check)
  WHILE EXISTS (SELECT 1 FROM bookings WHERE booking_number = v_booking_number AND business_owner_id = p_owner_id) LOOP
    v_seq_num := v_seq_num + 1;
    IF v_user_prefix = '' THEN
      v_booking_number := v_original_prefix || '-' || v_year || v_month || '-' || 
                          LPAD(v_seq_num::TEXT, 4, '0');
    ELSE
      v_booking_number := v_user_prefix || '-' || v_original_prefix || '-' || v_year || v_month || '-' || 
                          LPAD(v_seq_num::TEXT, 4, '0');
    END IF;
  END LOOP;
  
  RETURN v_booking_number;
END;
$$ LANGUAGE plpgsql;

COMMIT;

