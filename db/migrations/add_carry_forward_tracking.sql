-- CARRY FORWARD (C/F) ITEMS TRACKING SYSTEM
-- System untuk track items yang belum terjual dari previous claims
-- dan boleh digunakan untuk next claim
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: CREATE CARRY_FORWARD_ITEMS TABLE
-- Track items yang di-C/F dari previous claims untuk next claim
-- ============================================================================

CREATE TABLE IF NOT EXISTS carry_forward_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    -- Source claim info (dari mana C/F ini datang)
    source_claim_id UUID REFERENCES consignment_claims (id) ON DELETE SET NULL,
    source_claim_item_id UUID REFERENCES consignment_claim_items (id) ON DELETE SET NULL,
    source_delivery_id UUID REFERENCES vendor_deliveries (id),
    source_delivery_item_id UUID REFERENCES vendor_delivery_items (id),
    
    -- Product info
    product_id UUID REFERENCES products (id),
    product_name TEXT NOT NULL,  -- Denormalized untuk performance
    
    -- Quantity info
    quantity_available NUMERIC(12,3) NOT NULL,  -- Quantity yang masih available untuk next claim
    unit_price NUMERIC(12,2) NOT NULL,  -- Price dari original delivery
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'used', 'expired', 'cancelled')),
    -- available: Masih boleh digunakan untuk next claim
    -- used: Sudah digunakan dalam claim baru
    -- expired: Item sudah expired (tidak boleh digunakan lagi)
    -- cancelled: User cancel C/F item ini
    
    -- Metadata
    original_claim_number TEXT,  -- Untuk reference
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- When C/F was created
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_at TIMESTAMPTZ,  -- When this C/F was used in a new claim
    used_in_claim_id UUID REFERENCES consignment_claims (id),  -- Which claim used this C/F
    
    CONSTRAINT carry_forward_quantity_positive CHECK (quantity_available > 0)
);

CREATE INDEX idx_cf_items_owner ON carry_forward_items (business_owner_id);
CREATE INDEX idx_cf_items_vendor ON carry_forward_items (vendor_id);
CREATE INDEX idx_cf_items_status ON carry_forward_items (status);
CREATE INDEX idx_cf_items_available ON carry_forward_items (business_owner_id, vendor_id, status) 
    WHERE status = 'available';
CREATE INDEX idx_cf_items_source_claim ON carry_forward_items (source_claim_id);
CREATE INDEX idx_cf_items_used_claim ON carry_forward_items (used_in_claim_id);

-- Enable RLS
ALTER TABLE carry_forward_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY carry_forward_items_select_policy ON carry_forward_items 
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_insert_policy ON carry_forward_items 
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_update_policy ON carry_forward_items 
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY carry_forward_items_delete_policy ON carry_forward_items 
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 2: CREATE FUNCTION TO AUTO-CREATE C/F ITEMS WHEN CLAIM IS CREATED
-- When a claim item has quantity_unsold > 0 and carry_forward = TRUE,
-- automatically create a C/F item record
-- ============================================================================

CREATE OR REPLACE FUNCTION create_carry_forward_items()
RETURNS TRIGGER AS $$
DECLARE
    claim_record RECORD;
    claim_item_record RECORD;
    delivery_item_record RECORD;
BEGIN
    -- Get claim info
    SELECT business_owner_id, vendor_id, claim_number
    INTO claim_record
    FROM consignment_claims
    WHERE id = NEW.claim_id;
    
    -- Get delivery item info for product details
    SELECT product_id, product_name, unit_price
    INTO delivery_item_record
    FROM vendor_delivery_items
    WHERE id = NEW.delivery_item_id;
    
    -- If this claim item has unsold quantity and is marked for carry forward
    IF NEW.quantity_unsold > 0 AND NEW.carry_forward = TRUE THEN
        INSERT INTO carry_forward_items (
            business_owner_id,
            vendor_id,
            source_claim_id,
            source_claim_item_id,
            source_delivery_id,
            source_delivery_item_id,
            product_id,
            product_name,
            quantity_available,
            unit_price,
            original_claim_number,
            status
        ) VALUES (
            claim_record.business_owner_id,
            claim_record.vendor_id,
            NEW.claim_id,
            NEW.id,
            NEW.delivery_id,
            NEW.delivery_item_id,
            delivery_item_record.product_id,
            COALESCE(delivery_item_record.product_name, 'Unknown Product'),
            NEW.quantity_unsold,
            NEW.unit_price,
            claim_record.claim_number,
            'available'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-create C/F items when claim items are inserted
DROP TRIGGER IF EXISTS trigger_create_carry_forward_items ON consignment_claim_items;
CREATE TRIGGER trigger_create_carry_forward_items
    AFTER INSERT ON consignment_claim_items
    FOR EACH ROW
    WHEN (NEW.quantity_unsold > 0 AND NEW.carry_forward = TRUE)
    EXECUTE FUNCTION create_carry_forward_items();

-- ============================================================================
-- STEP 3: CREATE FUNCTION TO MARK C/F ITEMS AS USED WHEN USED IN NEW CLAIM
-- When a C/F item is used in a new claim, mark it as 'used'
-- ============================================================================

CREATE OR REPLACE FUNCTION mark_carry_forward_as_used()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new claim item references a C/F item (via source_claim_item_id),
    -- mark the C/F item as used
    IF NEW.carry_forward = TRUE AND NEW.quantity_unsold > 0 THEN
        -- This is a new C/F item, not using old one
        -- But we should check if there are available C/F items for this product
        -- and mark them as used if they match
        UPDATE carry_forward_items
        SET 
            status = 'used',
            used_at = NOW(),
            used_in_claim_id = NEW.claim_id,
            quantity_available = 0,
            updated_at = NOW()
        WHERE 
            business_owner_id = (SELECT business_owner_id FROM consignment_claims WHERE id = NEW.claim_id)
            AND vendor_id = (SELECT vendor_id FROM consignment_claims WHERE id = NEW.claim_id)
            AND source_delivery_item_id = NEW.delivery_item_id
            AND status = 'available'
            AND quantity_available > 0
            AND id IN (
                SELECT id FROM carry_forward_items
                WHERE source_delivery_item_id = NEW.delivery_item_id
                AND status = 'available'
                ORDER BY created_at ASC
                LIMIT 1
            );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger will be called when claim items are created
-- We'll handle the logic in application layer for better control

-- ============================================================================
-- STEP 4: CREATE VIEW FOR AVAILABLE C/F ITEMS (EASIER QUERYING)
-- ============================================================================

CREATE OR REPLACE VIEW available_carry_forward_items AS
SELECT 
    cf.id,
    cf.business_owner_id,
    cf.vendor_id,
    cf.source_claim_id,
    cf.source_claim_item_id,
    cf.source_delivery_id,
    cf.source_delivery_item_id,
    cf.product_id,
    cf.product_name,
    cf.quantity_available,
    cf.unit_price,
    cf.original_claim_number,
    cf.created_at,
    v.name as vendor_name,
    p.name as product_name_full,
    p.unit as product_unit
FROM carry_forward_items cf
LEFT JOIN vendors v ON v.id = cf.vendor_id
LEFT JOIN products p ON p.id = cf.product_id
WHERE cf.status = 'available'
    AND cf.quantity_available > 0;

-- Grant access to view
GRANT SELECT ON available_carry_forward_items TO authenticated;

COMMIT;


