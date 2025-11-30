-- ============================================================================
-- VENDOR COMMISSION TYPES
-- Support for percentage-based and price-range-based commission
-- ============================================================================

BEGIN;

-- Add commission_type to vendors table
ALTER TABLE vendors 
ADD COLUMN IF NOT EXISTS commission_type TEXT DEFAULT 'percentage' 
CHECK (commission_type IN ('percentage', 'price_range'));

-- Create vendor_commission_price_ranges table
CREATE TABLE IF NOT EXISTS vendor_commission_price_ranges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    
    -- Price Range
    min_price NUMERIC(12,2) NOT NULL,
    max_price NUMERIC(12,2), -- NULL means unlimited (last range)
    commission_amount NUMERIC(12,2) NOT NULL, -- Fixed commission for this range
    
    -- Order/Position
    position INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_commission_ranges_price_valid CHECK (min_price >= 0 AND (max_price IS NULL OR max_price > min_price)),
    CONSTRAINT vendor_commission_ranges_amount_positive CHECK (commission_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_vendor_commission_ranges_vendor ON vendor_commission_price_ranges (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_commission_ranges_owner ON vendor_commission_price_ranges (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_vendor_commission_ranges_position ON vendor_commission_price_ranges (vendor_id, position);

-- Enable RLS
ALTER TABLE vendor_commission_price_ranges ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY vendor_commission_ranges_select_policy ON vendor_commission_price_ranges
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY vendor_commission_ranges_insert_policy ON vendor_commission_price_ranges
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_commission_ranges_update_policy ON vendor_commission_price_ranges
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY vendor_commission_ranges_delete_policy ON vendor_commission_price_ranges
    FOR DELETE USING (business_owner_id = auth.uid());

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_vendor_commission_ranges_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vendor_commission_ranges_updated_at
    BEFORE UPDATE ON vendor_commission_price_ranges
    FOR EACH ROW
    EXECUTE FUNCTION update_vendor_commission_ranges_updated_at();

COMMIT;

