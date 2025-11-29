-- ============================================================================
-- FIX RECIPES STRUCTURE - FINAL WORKING VERSION
-- ============================================================================

BEGIN;

-- STEP 1: Drop existing objects (clean slate)
-- ============================================================================
DROP TABLE IF EXISTS production_ingredient_usage CASCADE;
DROP TABLE IF EXISTS recipe_items CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;
DROP TABLE IF EXISTS recipe_items_backup CASCADE;

DROP FUNCTION IF EXISTS calculate_recipe_cost(UUID) CASCADE;
DROP FUNCTION IF EXISTS record_production_batch CASCADE;
DROP FUNCTION IF EXISTS trigger_update_recipe_cost() CASCADE;

-- STEP 2: Backup OLD recipe_items
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recipe_items') THEN
        EXECUTE 'CREATE TABLE recipe_items_backup AS SELECT * FROM recipe_items';
        RAISE NOTICE '✅ Backed up old recipe_items';
    ELSE
        RAISE NOTICE '⚠️  No existing recipe_items to backup';
    END IF;
END $$;

-- STEP 3: CREATE RECIPES TABLE
-- ============================================================================
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    -- Recipe Details
    name TEXT NOT NULL,
    description TEXT,
    
    -- Yield Information
    yield_quantity NUMERIC(12,3) NOT NULL,
    yield_unit TEXT NOT NULL,
    
    -- Cost Tracking
    materials_cost NUMERIC(12,2) DEFAULT 0,
    total_cost NUMERIC(12,2) DEFAULT 0,
    cost_per_unit NUMERIC(12,4) DEFAULT 0,
    
    -- Version Control
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recipes_business_owner ON recipes (business_owner_id);
CREATE INDEX idx_recipes_product ON recipes (product_id);
CREATE INDEX idx_recipes_active ON recipes (product_id, is_active) WHERE is_active = TRUE;

ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipes_select_policy ON recipes FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY recipes_insert_policy ON recipes FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY recipes_update_policy ON recipes FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY recipes_delete_policy ON recipes FOR DELETE USING (business_owner_id = auth.uid());

-- STEP 4: CREATE RECIPE_ITEMS TABLE
-- ============================================================================
CREATE TABLE recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- Quantity & Unit
    quantity_needed NUMERIC(12,4) NOT NULL,
    usage_unit TEXT NOT NULL,
    
    -- Cost Tracking
    cost_per_unit NUMERIC(12,4) DEFAULT 0,
    total_cost NUMERIC(12,2) DEFAULT 0,
    
    -- Metadata
    position INTEGER DEFAULT 0,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT recipe_items_quantity_positive CHECK (quantity_needed > 0)
);

CREATE INDEX idx_recipe_items_recipe ON recipe_items (recipe_id);
CREATE INDEX idx_recipe_items_stock_item ON recipe_items (stock_item_id);
CREATE INDEX idx_recipe_items_owner ON recipe_items (business_owner_id);

ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_items_select_policy ON recipe_items FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY recipe_items_insert_policy ON recipe_items FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY recipe_items_update_policy ON recipe_items FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY recipe_items_delete_policy ON recipe_items FOR DELETE USING (business_owner_id = auth.uid());

-- STEP 5: CREATE PRODUCTION_INGREDIENT_USAGE TABLE
-- ============================================================================
CREATE TABLE production_ingredient_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    production_batch_id UUID NOT NULL REFERENCES production_batches (id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- What was used
    quantity_used NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    
    -- Cost snapshot
    cost_per_unit NUMERIC(12,4) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL,
    
    -- Link to recipe item
    recipe_item_id UUID REFERENCES recipe_items (id) ON DELETE SET NULL,
    
    -- Variance tracking
    variance_quantity NUMERIC(12,4) DEFAULT 0,
    variance_percentage NUMERIC(5,2) DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT production_usage_quantity_positive CHECK (quantity_used > 0)
);

CREATE INDEX idx_production_usage_batch ON production_ingredient_usage (production_batch_id);
CREATE INDEX idx_production_usage_stock_item ON production_ingredient_usage (stock_item_id);
CREATE INDEX idx_production_usage_owner ON production_ingredient_usage (business_owner_id);

ALTER TABLE production_ingredient_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY production_usage_select_policy ON production_ingredient_usage FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY production_usage_insert_policy ON production_ingredient_usage FOR INSERT WITH CHECK (business_owner_id = auth.uid());

-- STEP 6: UPDATE EXISTING TABLES
-- ============================================================================
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS recipe_id UUID REFERENCES recipes (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_production_batches_recipe ON production_batches (recipe_id);

ALTER TABLE stock_items ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES vendors (id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_stock_items_supplier ON stock_items (supplier_id);

-- STEP 7: CREATE FUNCTION - CALCULATE RECIPE COST
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
    
    -- Get product costs (if columns exist)
    BEGIN
        SELECT 
            COALESCE(labour_cost, 0),
            COALESCE(other_costs, 0)
        INTO labour, other
        FROM products
        WHERE id = product_uuid;
    EXCEPTION WHEN undefined_column THEN
        labour := 0;
        other := 0;
    END;
    
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

-- STEP 8: CREATE FUNCTION - RECORD PRODUCTION BATCH
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
    v_quantity_to_deduct NUMERIC;
    v_cost_snapshot NUMERIC;
    v_expected_quantity NUMERIC;
    v_recipe_yield NUMERIC;
BEGIN
    -- Get recipe yield
    SELECT yield_quantity INTO v_recipe_yield
    FROM recipes
    WHERE id = p_recipe_id;
    
    IF v_recipe_yield IS NULL THEN
        RAISE EXCEPTION 'Recipe not found: %', p_recipe_id;
    END IF;
    
    -- Create production batch
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
    
    -- For each recipe item, deduct stock & record usage
    FOR v_recipe_item IN
        SELECT *
        FROM recipe_items
        WHERE recipe_id = p_recipe_id
        ORDER BY position
    LOOP
        -- Calculate how much to deduct
        v_expected_quantity := (v_recipe_item.quantity_needed / v_recipe_yield) * p_quantity;
        
        -- Get current cost
        SELECT cost_per_unit INTO v_cost_snapshot
        FROM stock_items
        WHERE id = v_recipe_item.stock_item_id;
        
        -- Record usage (AUDIT TRAIL!)
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
        
        -- Deduct from stock
        UPDATE stock_items
        SET 
            current_quantity = GREATEST(0, current_quantity - v_expected_quantity),
            updated_at = NOW()
        WHERE id = v_recipe_item.stock_item_id;
        
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

-- STEP 9: CREATE TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_update_recipe_cost()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM calculate_recipe_cost(OLD.recipe_id);
    ELSE
        PERFORM calculate_recipe_cost(NEW.recipe_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recipe_items_cost_update
    AFTER INSERT OR UPDATE OR DELETE ON recipe_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_recipe_cost();

-- FINAL SUMMARY
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RECIPES STRUCTURE FIX - COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created: recipes table';
    RAISE NOTICE '✅ Created: recipe_items table';
    RAISE NOTICE '✅ Created: production_ingredient_usage table';
    RAISE NOTICE '✅ Updated: production_batches (recipe_id)';
    RAISE NOTICE '✅ Updated: stock_items (supplier_id)';
    RAISE NOTICE '✅ Created: Functions & triggers';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT: Restart your Flutter app!';
    RAISE NOTICE '';
END $$;

COMMIT;

