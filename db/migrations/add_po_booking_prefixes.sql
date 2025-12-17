-- Add PO and Booking prefix columns to business_profile table
-- Auto-generate from business_name (first 3 letters), user can override
-- Default values: PO (Purchase Order), BKG (Booking)
-- ============================================================================

BEGIN;

-- Add prefix columns
ALTER TABLE business_profile
  ADD COLUMN IF NOT EXISTS po_prefix TEXT,
  ADD COLUMN IF NOT EXISTS booking_prefix TEXT;

-- Add constraint to ensure prefixes are uppercase and max 10 chars
ALTER TABLE business_profile
  DROP CONSTRAINT IF EXISTS po_prefix_format,
  DROP CONSTRAINT IF EXISTS booking_prefix_format;

ALTER TABLE business_profile
  ADD CONSTRAINT po_prefix_format CHECK (
    po_prefix IS NULL OR 
    (LENGTH(po_prefix) >= 2 AND LENGTH(po_prefix) <= 10 AND po_prefix = UPPER(po_prefix) AND po_prefix ~ '^[A-Z0-9]+$')
  ),
  ADD CONSTRAINT booking_prefix_format CHECK (
    booking_prefix IS NULL OR 
    (LENGTH(booking_prefix) >= 2 AND LENGTH(booking_prefix) <= 10 AND booking_prefix = UPPER(booking_prefix) AND booking_prefix ~ '^[A-Z0-9]+$')
  );

-- Update trigger function to include PO and Booking prefixes
CREATE OR REPLACE FUNCTION auto_set_prefixes()
RETURNS TRIGGER AS $$
DECLARE
  v_auto_prefix TEXT;
BEGIN
  -- Generate prefix from business_name (first 3 letters, uppercase)
  v_auto_prefix := auto_generate_prefix(NEW.business_name);
  
  -- Only set if not already set by user (preserve user overrides)
  IF NEW.invoice_prefix IS NULL THEN
    NEW.invoice_prefix := COALESCE(v_auto_prefix, 'DEL');
  END IF;
  
  IF NEW.claim_prefix IS NULL THEN
    NEW.claim_prefix := COALESCE(v_auto_prefix, 'CLM');
  END IF;
  
  IF NEW.payment_prefix IS NULL THEN
    NEW.payment_prefix := COALESCE(v_auto_prefix, 'PAY');
  END IF;
  
  IF NEW.po_prefix IS NULL THEN
    NEW.po_prefix := COALESCE(v_auto_prefix, 'PO');
  END IF;
  
  IF NEW.booking_prefix IS NULL THEN
    NEW.booking_prefix := COALESCE(v_auto_prefix, 'BKG');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Backfill existing records: auto-generate prefixes from business_name
UPDATE business_profile
SET 
  po_prefix = COALESCE(
    po_prefix, 
    auto_generate_prefix(business_name),
    'PO'
  ),
  booking_prefix = COALESCE(
    booking_prefix,
    auto_generate_prefix(business_name),
    'BKG'
  )
WHERE po_prefix IS NULL OR booking_prefix IS NULL;

COMMIT;

