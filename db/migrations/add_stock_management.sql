-- ============================================================================
-- STOCK MANAGEMENT SYSTEM MIGRATION
-- Adds comprehensive stock/inventory tracking with unit conversions
-- ============================================================================

-- Stock Movement Types Enum
CREATE TYPE stock_movement_type AS ENUM (
    'purchase',         -- Initial stock purchase
    'replenish',        -- Stock replenishment (adding more)
    'adjust',           -- Manual quantity adjustment
    'production_use',   -- Used in production/recipe
    'waste',            -- Damaged/expired/wasted
    'return',           -- Returned to supplier
    'transfer',         -- Transfer between locations (future)
    'correction'        -- Inventory correction/audit
);

-- ============================================================================
-- STOCK ITEMS TABLE (Raw Materials / Ingredients Warehouse)
-- ============================================================================
CREATE TABLE IF NOT EXISTS stock_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    
    -- Product Information
    name TEXT NOT NULL,
    unit TEXT NOT NULL, -- Base unit: kg, gram, liter, ml, pcs, dozen
    
    -- Purchase Information
    package_size NUMERIC(10,2) NOT NULL DEFAULT 1, -- Size of package purchased (e.g., 500 for 500gram)
    purchase_price NUMERIC(10,2) NOT NULL, -- Total price for the PACKAGE
    
    -- Current Stock Level
    current_quantity NUMERIC(10,2) NOT NULL DEFAULT 0, -- Current stock in warehouse
    low_stock_threshold NUMERIC(10,2) NOT NULL DEFAULT 5, -- Alert when below this
    
    -- Metadata
    notes TEXT,
    version INTEGER NOT NULL DEFAULT 0, -- Optimistic locking for concurrent updates
    is_archived BOOLEAN NOT NULL DEFAULT FALSE, -- Soft delete
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_stock_items_owner ON stock_items (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_stock_items_active ON stock_items (business_owner_id, is_archived);
CREATE INDEX IF NOT EXISTS idx_stock_items_low_stock ON stock_items (business_owner_id, current_quantity, low_stock_threshold) 
    WHERE is_archived = FALSE;

-- ============================================================================
-- STOCK MOVEMENTS TABLE (Complete Audit Trail)
-- ============================================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- Movement Details
    movement_type stock_movement_type NOT NULL,
    quantity_before NUMERIC(10,2) NOT NULL, -- Quantity before change
    quantity_change NUMERIC(10,2) NOT NULL, -- Positive = increase, Negative = decrease
    quantity_after NUMERIC(10,2) NOT NULL, -- Quantity after change
    
    -- Context & Traceability
    reason TEXT, -- Optional explanation
    reference_id UUID, -- Link to related entity (purchase_order, production_batch, etc.)
    reference_type TEXT, -- Type of reference (e.g., "purchase_order", "production_batch")
    created_by UUID REFERENCES users (id), -- Who made the change
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_stock_movements_stock_item ON stock_movements (stock_item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_owner ON stock_movements (business_owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements (movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock_movements (reference_type, reference_id);

-- ============================================================================
-- TRIGGERS: Auto-update timestamps
-- ============================================================================
CREATE OR REPLACE FUNCTION update_stock_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_stock_items_updated_at
    BEFORE UPDATE ON stock_items
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_items_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) - Multi-tenant isolation
-- ============================================================================
ALTER TABLE stock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Stock Items Policies
CREATE POLICY "Users can view their own stock items"
    ON stock_items FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own stock items"
    ON stock_items FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can update their own stock items"
    ON stock_items FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can delete their own stock items"
    ON stock_items FOR DELETE
    USING (business_owner_id = auth.uid());

-- Stock Movements Policies
CREATE POLICY "Users can view their own stock movements"
    ON stock_movements FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own stock movements"
    ON stock_movements FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

-- ============================================================================
-- HELPER FUNCTION: Record Stock Movement
-- This function ensures consistency when updating stock quantities
-- ============================================================================
CREATE OR REPLACE FUNCTION record_stock_movement(
    p_stock_item_id UUID,
    p_movement_type stock_movement_type,
    p_quantity_change NUMERIC,
    p_reason TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_quantity_before NUMERIC;
    v_quantity_after NUMERIC;
    v_movement_id UUID;
    v_current_version INTEGER;
BEGIN
    -- Get current stock info with row lock (prevent concurrent modifications)
    SELECT business_owner_id, current_quantity, version
    INTO v_business_owner_id, v_quantity_before, v_current_version
    FROM stock_items
    WHERE id = p_stock_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item not found: %', p_stock_item_id;
    END IF;

    -- Calculate new quantity
    v_quantity_after := v_quantity_before + p_quantity_change;

    -- Prevent negative stock (optional - uncomment if needed)
    -- IF v_quantity_after < 0 THEN
    --     RAISE EXCEPTION 'Insufficient stock. Current: %, Requested: %', v_quantity_before, -p_quantity_change;
    -- END IF;

    -- Update stock item quantity & version (optimistic locking)
    UPDATE stock_items
    SET 
        current_quantity = v_quantity_after,
        version = version + 1,
        updated_at = NOW()
    WHERE id = p_stock_item_id
      AND version = v_current_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item was modified by another transaction. Please retry.';
    END IF;

    -- Record the movement in audit trail
    INSERT INTO stock_movements (
        business_owner_id,
        stock_item_id,
        movement_type,
        quantity_before,
        quantity_change,
        quantity_after,
        reason,
        reference_id,
        reference_type,
        created_by,
        created_at
    ) VALUES (
        v_business_owner_id,
        p_stock_item_id,
        p_movement_type,
        v_quantity_before,
        p_quantity_change,
        v_quantity_after,
        p_reason,
        p_reference_id,
        p_reference_type,
        COALESCE(p_created_by, auth.uid()),
        NOW()
    ) RETURNING id INTO v_movement_id;

    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER VIEW: Low Stock Alerts
-- ============================================================================
CREATE OR REPLACE VIEW low_stock_items AS
SELECT 
    si.id,
    si.business_owner_id,
    si.name,
    si.unit,
    si.current_quantity,
    si.low_stock_threshold,
    si.package_size,
    si.purchase_price,
    ROUND((si.current_quantity / si.low_stock_threshold) * 100, 2) AS stock_level_percentage
FROM stock_items si
WHERE si.is_archived = FALSE
  AND si.current_quantity <= si.low_stock_threshold
ORDER BY (si.current_quantity / si.low_stock_threshold) ASC;

-- Grant access to view
GRANT SELECT ON low_stock_items TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE stock_items IS 'Raw materials/ingredients warehouse inventory with unit tracking';
COMMENT ON TABLE stock_movements IS 'Complete audit trail of all stock quantity changes';
COMMENT ON COLUMN stock_items.package_size IS 'Size of package purchased (e.g., 500 for 500gram, 1.4 for 1.4kg)';
COMMENT ON COLUMN stock_items.purchase_price IS 'Total price for the PACKAGE, not per unit';
COMMENT ON COLUMN stock_items.version IS 'Optimistic locking: increments on every update to prevent concurrent modification';
COMMENT ON FUNCTION record_stock_movement IS 'Thread-safe function to update stock and record movement in one transaction';

