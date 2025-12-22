-- ============================================================================
-- ADD VENDOR NUMBER (NV) FIELD
-- Add vendor_number field to vendors table for invoice display
-- ============================================================================

BEGIN;

-- Add vendor_number column to vendors table
ALTER TABLE vendors 
ADD COLUMN IF NOT EXISTS vendor_number TEXT;

-- Add index for vendor_number (optional, for faster lookups)
CREATE INDEX IF NOT EXISTS idx_vendors_vendor_number ON vendors (vendor_number) 
WHERE vendor_number IS NOT NULL;

-- Add comment
COMMENT ON COLUMN vendors.vendor_number IS 'Nombor Vendor (NV) - displayed in delivery invoices';

COMMIT;
