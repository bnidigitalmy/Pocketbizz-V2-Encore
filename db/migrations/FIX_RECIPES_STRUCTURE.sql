-- ============================================================================
-- FIX RECIPES STRUCTURE - MATCH OLD REPO (CORRECT PATTERN)
-- ============================================================================
-- This migration restructures recipes to match the old repo's correct pattern:
-- Products → Recipes (master) → Recipe Items (ingredients) → Stock Items
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE NEW RECIPES TABLE (Master Recipe Info)
-- ============================================================================
CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    -- Recipe Details
    name TEXT NOT NULL,                    -- e.g., "Chocolate Cake Recipe V1"
    description TEXT,                      -- Optional notes about this recipe
    
    -- Yield Information (CRITICAL!)
    yield_quantity NUMERIC(12,3) NOT NULL, -- How many units this recipe produces
    yield_unit TEXT NOT NULL,              -- What unit (e.g., "pieces", "kg", "boxes")
    
    -- Cost Tracking (Auto-calculated)
    materials_cost NUMERIC(12,2) DEFAULT 0,  -- Sum of all recipe items
    total_cost NUMERIC(12,2) DEFAULT 0,       -- Materials + labour + other costs
    cost_per_unit NUMERIC(12,4) DEFAULT 0,    -- total_cost / yield_quantity
    
    -- Version Control
    version INTEGER DEFAULT 1,               -- Recipe version number
    is_active BOOLEAN DEFAULT TRUE,          -- Current active recipe?
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_recipes_business_owner ON recipes (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_recipes_product ON recipes (product_id);
CREATE INDEX IF NOT EXISTS idx_recipes_active ON recipes (product_id, is_active) WHERE is_active = TRUE;

-- RLS Policies
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipes_select_policy" ON recipes
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipes_insert_policy" ON recipes
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "recipes_update_policy" ON recipes
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipes_delete_policy" ON recipes
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 2: BACKUP EXISTING RECIPE_ITEMS (Just in case!)
-- ============================================================================
CREATE TABLE IF NOT EXISTS recipe_items_backup AS 
SELECT * FROM recipe_items;

-- ============================================================================
-- STEP 3: DROP OLD RECIPE_ITEMS & RECREATE WITH CORRECT STRUCTURE
-- ============================================================================
DROP TABLE IF EXISTS recipe_items CASCADE;

CREATE TABLE recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,  -- ✅ Now links to RECIPES!
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- Quantity & Unit
    quantity_needed NUMERIC(12,4) NOT NULL, -- How much needed for THIS recipe
    usage_unit TEXT NOT NULL,                -- Unit used in recipe
    
    -- Cost Tracking (Snapshot at time of creation)
    cost_per_unit NUMERIC(12,4) DEFAULT 0,   -- Cost per unit of stock item
    total_cost NUMERIC(12,2) DEFAULT 0,       -- quantity_needed * cost_per_unit
    
    -- Metadata
    position INTEGER DEFAULT 0,               -- Order in recipe
    notes TEXT,                               -- Optional ingredient notes
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT recipe_items_quantity_positive CHECK (quantity_needed > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items (recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_stock_item ON recipe_items (stock_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_owner ON recipe_items (business_owner_id);

-- RLS Policies
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipe_items_select_policy" ON recipe_items
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_items_insert_policy" ON recipe_items
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "recipe_items_update_policy" ON recipe_items
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_items_delete_policy" ON recipe_items
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 4: ADD PRODUCTION INGREDIENT USAGE TRACKING (AUDIT TRAIL!)
-- ============================================================================
CREATE TABLE IF NOT EXISTS production_ingredient_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    production_batch_id UUID NOT NULL REFERENCES production_batches (id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- What was ACTUALLY used in production
    quantity_used NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    
    -- Cost snapshot at time of production
    cost_per_unit NUMERIC(12,4) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL,
    
    -- Link to recipe item (what was expected)
    recipe_item_id UUID REFERENCES recipe_items (id) ON DELETE SET NULL,
    
    -- Variance tracking
    variance_quantity NUMERIC(12,4) DEFAULT 0,  -- Actual vs expected
    variance_percentage NUMERIC(5,2) DEFAULT 0, -- Percentage difference
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT production_usage_quantity_positive CHECK (quantity_used > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_production_usage_batch ON production_ingredient_usage (production_batch_id);
CREATE INDEX IF NOT EXISTS idx_production_usage_stock_item ON production_ingredient_usage (stock_item_id);
CREATE INDEX IF NOT EXISTS idx_production_usage_owner ON production_ingredient_usage (business_owner_id);

-- RLS Policies
ALTER TABLE production_ingredient_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "production_usage_select_policy" ON production_ingredient_usage
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "production_usage_insert_policy" ON production_ingredient_usage
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 5: UPDATE PRODUCTION_BATCHES - ADD RECIPE_ID LINK
-- ============================================================================
ALTER TABLE production_batches 
ADD COLUMN IF NOT EXISTS recipe_id UUID REFERENCES recipes (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_production_batches_recipe ON production_batches (recipe_id);

COMMENT ON COLUMN production_batches.recipe_id IS 'Which recipe version was used for this production batch';

-- ============================================================================
-- STEP 6: ADD SUPPLIER LINK TO STOCK_ITEMS
-- ============================================================================
ALTER TABLE stock_items 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES vendors (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_stock_items_supplier ON stock_items (supplier_id);

COMMENT ON COLUMN stock_items.supplier_id IS 'Which supplier/vendor provides this stock item';

-- ============================================================================
-- STEP 7: CREATE FUNCTION - AUTO CALCULATE RECIPE COSTS
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_recipe_cost(recipe_uuid UUID)
RETURNS NUMERIC AS $$
DECLARE
    total_materials_cost NUMERIC := 0;
    recipe_yield NUMERIC;
    labour NUMERIC := 0;
    other NUMERIC := 0;
    product_uuid UUID;
BEGIN
    -- Sum up all recipe item costs
    SELECT COALESCE(SUM(total_cost), 0) INTO total_materials_cost
    FROM recipe_items
    WHERE recipe_id = recipe_uuid;
    
    -- Get recipe details
    SELECT yield_quantity, product_id INTO recipe_yield, product_uuid
    FROM recipes
    WHERE id = recipe_uuid;
    
    -- Get product costs (labour, other costs)
    SELECT 
        COALESCE(labour_cost, 0),
        COALESCE(other_costs, 0)
    INTO labour, other
    FROM products
    WHERE id = product_uuid;
    
    -- Update recipe costs
    UPDATE recipes
    SET 
        materials_cost = total_materials_cost,
        total_cost = total_materials_cost + labour + other,
        cost_per_unit = CASE 
            WHEN recipe_yield > 0 THEN (total_materials_cost + labour + other) / recipe_yield
            ELSE 0
        END,
        updated_at = NOW()
    WHERE id = recipe_uuid;
    
    RETURN total_materials_cost + labour + other;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 8: CREATE FUNCTION - RECORD PRODUCTION WITH AUDIT TRAIL
-- ============================================================================
CREATE OR REPLACE FUNCTION record_production_batch(
    p_business_owner_id UUID,
    p_product_id UUID,
    p_recipe_id UUID,
    p_quantity INTEGER,
    p_batch_date DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_recipe_item RECORD;
    v_stock_item RECORD;
    v_quantity_to_deduct NUMERIC;
    v_cost_snapshot NUMERIC;
    v_expected_quantity NUMERIC;
BEGIN
    -- 1. Create production batch
    INSERT INTO production_batches (
        business_owner_id, product_id, recipe_id,
        batch_number, product_name, quantity, remaining_qty,
        batch_date, expiry_date, notes
    )
    SELECT 
        p_business_owner_id, p_product_id, p_recipe_id,
        'BATCH-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS'),
        p.name,
        p_quantity, p_quantity,
        p_batch_date, p_expiry_date, p_notes
    FROM products p
    WHERE p.id = p_product_id
    RETURNING id INTO v_batch_id;
    
    -- 2. For each recipe item, deduct stock & record usage
    FOR v_recipe_item IN
        SELECT ri.*, r.yield_quantity
        FROM recipe_items ri
        JOIN recipes r ON r.id = ri.recipe_id
        WHERE ri.recipe_id = p_recipe_id
        ORDER BY ri.position
    LOOP
        -- Calculate how much to deduct for this batch quantity
        v_expected_quantity := (v_recipe_item.quantity_needed / v_recipe_item.yield_quantity) * p_quantity;
        
        -- Get current cost of stock item
        SELECT cost_per_unit INTO v_cost_snapshot
        FROM stock_items
        WHERE id = v_recipe_item.stock_item_id;
        
        -- Record ingredient usage (AUDIT TRAIL!)
        INSERT INTO production_ingredient_usage (
            business_owner_id, production_batch_id, stock_item_id,
            recipe_item_id,
            quantity_used, unit, cost_per_unit, total_cost
        ) VALUES (
            p_business_owner_id, v_batch_id, v_recipe_item.stock_item_id,
            v_recipe_item.id,
            v_expected_quantity, v_recipe_item.usage_unit,
            v_cost_snapshot, v_expected_quantity * v_cost_snapshot
        );
        
        -- Deduct from stock (FIFO style - same as before)
        v_quantity_to_deduct := v_expected_quantity;
        
        WHILE v_quantity_to_deduct > 0 LOOP
            UPDATE stock_items
            SET 
                current_quantity = GREATEST(0, current_quantity - v_quantity_to_deduct),
                updated_at = NOW()
            WHERE id = v_recipe_item.stock_item_id
            AND current_quantity > 0;
            
            EXIT WHEN v_quantity_to_deduct <= 0;
            v_quantity_to_deduct := 0;
        END LOOP;
        
        -- Record stock movement
        INSERT INTO stock_movements (
            stock_item_id, business_owner_id,
            type, quantity, reason,
            reference_type, reference_id
        ) VALUES (
            v_recipe_item.stock_item_id, p_business_owner_id,
            'OUT', v_expected_quantity, 'Production batch recorded',
            'production_batch', v_batch_id
        );
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 9: CREATE TRIGGER - AUTO UPDATE RECIPE COSTS ON ITEM CHANGE
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_update_recipe_cost()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate recipe cost when items are added/updated/deleted
    IF TG_OP = 'DELETE' THEN
        PERFORM calculate_recipe_cost(OLD.recipe_id);
    ELSE
        PERFORM calculate_recipe_cost(NEW.recipe_id);
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS recipe_items_cost_update ON recipe_items;
CREATE TRIGGER recipe_items_cost_update
    AFTER INSERT OR UPDATE OR DELETE ON recipe_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_recipe_cost();

-- ============================================================================
-- MIGRATION COMPLETE! 🎉
-- ============================================================================

-- Add helpful comments
COMMENT ON TABLE recipes IS 'Master recipe table - one product can have multiple recipe versions';
COMMENT ON TABLE recipe_items IS 'Recipe ingredients list - links recipes to stock items';
COMMENT ON TABLE production_ingredient_usage IS 'Audit trail of what was actually used in production';

-- Summary
DO $$
BEGIN
    RAISE NOTICE '✅ RECIPES STRUCTURE FIXED!';
    RAISE NOTICE '✅ Now matches old repo pattern: Products → Recipes → Recipe Items → Stock';
    RAISE NOTICE '✅ Added production_ingredient_usage for audit trail';
    RAISE NOTICE '✅ Added supplier_id to stock_items';
    RAISE NOTICE '✅ Auto cost calculation functions created';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Old recipe_items data backed up to recipe_items_backup';
    RAISE NOTICE '📝 Next: Update Flutter models & UI to use new structure';
END $$;

