-- Add prefix columns to business_profile table
-- Auto-generate from business_name (first 3 letters), user can override
-- Default values: DEL (Invoice), CLM (Claim), PAY (Payment)
-- ============================================================================

BEGIN;

-- Add prefix columns
ALTER TABLE business_profile
  ADD COLUMN IF NOT EXISTS invoice_prefix TEXT,
  ADD COLUMN IF NOT EXISTS claim_prefix TEXT,
  ADD COLUMN IF NOT EXISTS payment_prefix TEXT;

-- Add constraint to ensure prefixes are uppercase and max 10 chars
ALTER TABLE business_profile
  DROP CONSTRAINT IF EXISTS invoice_prefix_format,
  DROP CONSTRAINT IF EXISTS claim_prefix_format,
  DROP CONSTRAINT IF EXISTS payment_prefix_format;

ALTER TABLE business_profile
  ADD CONSTRAINT invoice_prefix_format CHECK (
    invoice_prefix IS NULL OR 
    (LENGTH(invoice_prefix) >= 2 AND LENGTH(invoice_prefix) <= 10 AND invoice_prefix = UPPER(invoice_prefix) AND invoice_prefix ~ '^[A-Z0-9]+$')
  ),
  ADD CONSTRAINT claim_prefix_format CHECK (
    claim_prefix IS NULL OR 
    (LENGTH(claim_prefix) >= 2 AND LENGTH(claim_prefix) <= 10 AND claim_prefix = UPPER(claim_prefix) AND claim_prefix ~ '^[A-Z0-9]+$')
  ),
  ADD CONSTRAINT payment_prefix_format CHECK (
    payment_prefix IS NULL OR 
    (LENGTH(payment_prefix) >= 2 AND LENGTH(payment_prefix) <= 10 AND payment_prefix = UPPER(payment_prefix) AND payment_prefix ~ '^[A-Z0-9]+$')
  );

-- Function to auto-generate prefix from business_name
CREATE OR REPLACE FUNCTION auto_generate_prefix(business_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_cleaned TEXT;
  v_prefix TEXT;
BEGIN
  -- Remove non-alphanumeric characters and get first 3 letters
  v_cleaned := REGEXP_REPLACE(business_name, '[^A-Za-z0-9]', '', 'g');
  
  IF LENGTH(v_cleaned) >= 3 THEN
    v_prefix := UPPER(SUBSTRING(v_cleaned FROM 1 FOR 3));
  ELSIF LENGTH(v_cleaned) >= 2 THEN
    v_prefix := UPPER(v_cleaned);
  ELSE
    -- Too short, return NULL to use default
    RETURN NULL;
  END IF;
  
  RETURN v_prefix;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-set prefixes on INSERT/UPDATE
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
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists (for idempotency)
DROP TRIGGER IF EXISTS trigger_auto_set_prefixes ON business_profile;

-- Create trigger
CREATE TRIGGER trigger_auto_set_prefixes
  BEFORE INSERT OR UPDATE OF business_name ON business_profile
  FOR EACH ROW
  EXECUTE FUNCTION auto_set_prefixes();

-- Backfill existing records: auto-generate prefixes from business_name
UPDATE business_profile
SET 
  invoice_prefix = COALESCE(
    invoice_prefix, 
    auto_generate_prefix(business_name),
    'DEL'
  ),
  claim_prefix = COALESCE(
    claim_prefix,
    auto_generate_prefix(business_name),
    'CLM'
  ),
  payment_prefix = COALESCE(
    payment_prefix,
    auto_generate_prefix(business_name),
    'PAY'
  )
WHERE invoice_prefix IS NULL OR claim_prefix IS NULL OR payment_prefix IS NULL;

COMMIT;

