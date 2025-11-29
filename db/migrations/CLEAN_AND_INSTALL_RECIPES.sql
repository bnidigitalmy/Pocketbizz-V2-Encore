-- ============================================================================
-- CLEAN & INSTALL RECIPES & PRODUCTION
-- This drops existing tables and creates fresh ones
-- ============================================================================

-- STEP 1: DROP existing tables (if they exist)
DROP TABLE IF EXISTS production_batches CASCADE;
DROP TABLE IF EXISTS recipe_items CASCADE;

-- Drop functions too
DROP FUNCTION IF EXISTS record_production_batch CASCADE;
DROP FUNCTION IF EXISTS update_product_costs CASCADE;
DROP FUNCTION IF EXISTS calculate_recipe_cost CASCADE;

-- ============================================================================
-- STEP 2: UPDATE PRODUCTS TABLE
-- ============================================================================
DO $$ 
BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS units_per_batch INTEGER DEFAULT 1;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS labour_cost NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS other_costs NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS packaging_cost NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS materials_cost NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS total_cost_per_batch NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS cost_per_unit NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS suggested_margin NUMERIC(5,2) DEFAULT 30.00;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS suggested_price NUMERIC(10,2) DEFAULT 0;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS selling_price NUMERIC(10,2) DEFAULT 0;
    
    ALTER TABLE products ALTER COLUMN units_per_batch SET NOT NULL;
    ALTER TABLE products ALTER COLUMN labour_cost SET NOT NULL;
    ALTER TABLE products ALTER COLUMN other_costs SET NOT NULL;
    ALTER TABLE products ALTER COLUMN packaging_cost SET NOT NULL;
    ALTER TABLE products ALTER COLUMN materials_cost SET NOT NULL;
    ALTER TABLE products ALTER COLUMN total_cost_per_batch SET NOT NULL;
    ALTER TABLE products ALTER COLUMN cost_per_unit SET NOT NULL;
    ALTER TABLE products ALTER COLUMN suggested_margin SET NOT NULL;
    ALTER TABLE products ALTER COLUMN suggested_price SET NOT NULL;
    ALTER TABLE products ALTER COLUMN selling_price SET NOT NULL;
    
    RAISE NOTICE '✓ Products table updated';
END $$;

-- ============================================================================
-- STEP 3: CREATE RECIPE ITEMS TABLE (FRESH!)
-- ============================================================================
CREATE TABLE recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id) ON DELETE CASCADE,
    quantity_needed NUMERIC(10,2) NOT NULL CHECK (quantity_needed > 0),
    usage_unit TEXT NOT NULL,
    cost_per_recipe NUMERIC(10,2) NOT NULL DEFAULT 0,
    position INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recipe_items_product ON recipe_items (product_id);
CREATE INDEX idx_recipe_items_stock_item ON recipe_items (stock_item_id);
CREATE INDEX idx_recipe_items_owner ON recipe_items (business_owner_id);

-- ============================================================================
-- STEP 4: CREATE PRODUCTION BATCHES TABLE (FRESH!)
-- ============================================================================
CREATE TABLE production_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_number TEXT,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    remaining_qty NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (remaining_qty >= 0 AND remaining_qty <= quantity),
    batch_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    total_cost NUMERIC(10,2) NOT NULL,
    cost_per_unit NUMERIC(10,2) NOT NULL,
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_production_batches_product ON production_batches (product_id, batch_date DESC);
CREATE INDEX idx_production_batches_owner ON production_batches (business_owner_id, batch_date DESC);
CREATE INDEX idx_production_batches_remaining ON production_batches (product_id, remaining_qty) 
    WHERE remaining_qty > 0;

-- ============================================================================
-- STEP 5: TRIGGERS
-- ============================================================================
CREATE OR REPLACE FUNCTION update_recipe_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_recipe_items_updated_at
    BEFORE UPDATE ON recipe_items
    FOR EACH ROW
    EXECUTE FUNCTION update_recipe_items_updated_at();

CREATE OR REPLACE FUNCTION update_production_batches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_production_batches_updated_at
    BEFORE UPDATE ON production_batches
    FOR EACH ROW
    EXECUTE FUNCTION update_production_batches_updated_at();

-- ============================================================================
-- STEP 6: RLS POLICIES
-- ============================================================================
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recipe items"
    ON recipe_items FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own recipe items"
    ON recipe_items FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can update their own recipe items"
    ON recipe_items FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can delete their own recipe items"
    ON recipe_items FOR DELETE
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can view their own production batches"
    ON production_batches FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own production batches"
    ON production_batches FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can update their own production batches"
    ON production_batches FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY "Users can delete their own production batches"
    ON production_batches FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 7: FUNCTIONS
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_recipe_cost(p_product_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_total_cost NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(cost_per_recipe), 0)
    INTO v_total_cost
    FROM recipe_items
    WHERE product_id = p_product_id;
    
    RETURN v_total_cost;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_product_costs(p_product_id UUID)
RETURNS VOID AS $$
DECLARE
    v_materials_cost NUMERIC;
    v_labour_cost NUMERIC;
    v_other_costs NUMERIC;
    v_packaging_cost NUMERIC;
    v_units_per_batch INTEGER;
    v_total_cost_per_batch NUMERIC;
    v_cost_per_unit NUMERIC;
    v_suggested_margin NUMERIC;
    v_suggested_price NUMERIC;
BEGIN
    SELECT 
        labour_cost, other_costs, packaging_cost, units_per_batch, suggested_margin
    INTO 
        v_labour_cost, v_other_costs, v_packaging_cost, v_units_per_batch, v_suggested_margin
    FROM products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
    
    v_materials_cost := calculate_recipe_cost(p_product_id);
    v_total_cost_per_batch := v_materials_cost + v_labour_cost + v_other_costs + (v_packaging_cost * v_units_per_batch);
    
    IF v_units_per_batch > 0 THEN
        v_cost_per_unit := v_total_cost_per_batch / v_units_per_batch;
    ELSE
        v_cost_per_unit := 0;
    END IF;
    
    v_suggested_price := v_cost_per_unit * (1 + v_suggested_margin / 100);
    
    UPDATE products
    SET
        materials_cost = v_materials_cost,
        total_cost_per_batch = v_total_cost_per_batch,
        cost_per_unit = v_cost_per_unit,
        suggested_price = v_suggested_price,
        updated_at = NOW()
    WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION record_production_batch(
    p_product_id UUID,
    p_quantity INTEGER,
    p_batch_date DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_batch_number TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_business_owner_id UUID;
    v_product_name TEXT;
    v_cost_per_unit NUMERIC;
    v_total_cost NUMERIC;
    v_batch_id UUID;
    v_recipe_item RECORD;
    v_quantity_to_deduct NUMERIC;
BEGIN
    SELECT business_owner_id, name, cost_per_unit
    INTO v_business_owner_id, v_product_name, v_cost_per_unit
    FROM products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
    
    v_total_cost := v_cost_per_unit * p_quantity;
    
    INSERT INTO production_batches (
        business_owner_id, product_id, batch_number, product_name,
        quantity, remaining_qty, batch_date, expiry_date,
        total_cost, cost_per_unit, notes, created_at
    ) VALUES (
        v_business_owner_id, p_product_id, p_batch_number, v_product_name,
        p_quantity, p_quantity, p_batch_date, p_expiry_date,
        v_total_cost, v_cost_per_unit, p_notes, NOW()
    ) RETURNING id INTO v_batch_id;
    
    FOR v_recipe_item IN
        SELECT stock_item_id, quantity_needed
        FROM recipe_items
        WHERE product_id = p_product_id
    LOOP
        v_quantity_to_deduct := v_recipe_item.quantity_needed * p_quantity;
        
        PERFORM record_stock_movement(
            p_stock_item_id := v_recipe_item.stock_item_id,
            p_movement_type := 'production_use',
            p_quantity_change := -v_quantity_to_deduct,
            p_reason := format('Production: %s (Batch: %s)', v_product_name, v_batch_id),
            p_reference_id := v_batch_id,
            p_reference_type := 'production_batch',
            p_created_by := auth.uid()
        );
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SUCCESS!
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓';
    RAISE NOTICE '✓                                          ✓';
    RAISE NOTICE '✓  RECIPES & PRODUCTION MIGRATION SUCCESS! ✓';
    RAISE NOTICE '✓                                          ✓';
    RAISE NOTICE '✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  ✓ recipe_items';
    RAISE NOTICE '  ✓ production_batches';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions created:';
    RAISE NOTICE '  ✓ calculate_recipe_cost()';
    RAISE NOTICE '  ✓ update_product_costs()';
    RAISE NOTICE '  ✓ record_production_batch()';
    RAISE NOTICE '';
    RAISE NOTICE 'Ready to build UI! 🚀';
END $$;

