-- ============================================================================
-- RECIPES & PRODUCTION BATCHES MIGRATION (FIXED)
-- Links stock items to finished products with automatic cost calculations
-- ============================================================================

-- ============================================================================
-- UPDATE PRODUCTS TABLE - Add Recipe/Cost Fields (IF NOT EXISTS)
-- ============================================================================
DO $$ 
BEGIN
    -- Add columns one by one with IF NOT EXISTS checks
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='units_per_batch') THEN
        ALTER TABLE products ADD COLUMN units_per_batch INTEGER NOT NULL DEFAULT 1;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='labour_cost') THEN
        ALTER TABLE products ADD COLUMN labour_cost NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='other_costs') THEN
        ALTER TABLE products ADD COLUMN other_costs NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='packaging_cost') THEN
        ALTER TABLE products ADD COLUMN packaging_cost NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='materials_cost') THEN
        ALTER TABLE products ADD COLUMN materials_cost NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='total_cost_per_batch') THEN
        ALTER TABLE products ADD COLUMN total_cost_per_batch NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='cost_per_unit') THEN
        ALTER TABLE products ADD COLUMN cost_per_unit NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='suggested_margin') THEN
        ALTER TABLE products ADD COLUMN suggested_margin NUMERIC(5,2) NOT NULL DEFAULT 30.00;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='suggested_price') THEN
        ALTER TABLE products ADD COLUMN suggested_price NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='selling_price') THEN
        ALTER TABLE products ADD COLUMN selling_price NUMERIC(10,2) NOT NULL DEFAULT 0;
    END IF;
END $$;

-- Add comments for clarity
COMMENT ON COLUMN products.units_per_batch IS 'How many units one recipe batch produces';
COMMENT ON COLUMN products.labour_cost IS 'Labour cost per batch';
COMMENT ON COLUMN products.other_costs IS 'Gas, electricity, etc per batch';
COMMENT ON COLUMN products.packaging_cost IS 'Packaging cost per unit (e.g., RM0.238 per piece)';
COMMENT ON COLUMN products.materials_cost IS 'Auto-calculated from recipe items';
COMMENT ON COLUMN products.total_cost_per_batch IS 'materials + labour + other + (packaging * units)';
COMMENT ON COLUMN products.cost_per_unit IS 'totalCostPerBatch / unitsPerBatch';
COMMENT ON COLUMN products.suggested_margin IS 'Suggested profit margin percentage';
COMMENT ON COLUMN products.suggested_price IS 'Auto-calculated: costPerUnit * (1 + suggestedMargin/100)';
COMMENT ON COLUMN products.selling_price IS 'User-set final selling price';

-- ============================================================================
-- RECIPE ITEMS TABLE - Links Products to Stock Items
-- ============================================================================
CREATE TABLE IF NOT EXISTS recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items (id) ON DELETE CASCADE,
    
    -- Quantity & Unit
    quantity_needed NUMERIC(10,2) NOT NULL, -- How much needed for 1 batch
    usage_unit TEXT NOT NULL, -- Unit used in recipe (can differ from stock unit!)
    
    -- Cost Tracking
    cost_per_recipe NUMERIC(10,2) NOT NULL DEFAULT 0, -- Calculated cost for this ingredient in recipe
    
    -- Metadata
    position INTEGER DEFAULT 0, -- Order in recipe
    notes TEXT, -- Optional ingredient notes
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT recipe_items_quantity_positive CHECK (quantity_needed > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recipe_items_product ON recipe_items (product_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_stock_item ON recipe_items (stock_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_owner ON recipe_items (business_owner_id);

-- ============================================================================
-- PRODUCTION BATCHES TABLE - Track Finished Goods Production
-- ============================================================================
CREATE TABLE IF NOT EXISTS production_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    -- Batch Information
    batch_number TEXT, -- Optional custom batch number (e.g., "BATCH-001")
    product_name TEXT NOT NULL, -- Snapshot of product name
    quantity INTEGER NOT NULL, -- Total units produced in this batch
    remaining_qty NUMERIC(10,2) NOT NULL DEFAULT 0, -- Remaining units (for FIFO tracking)
    
    -- Dates
    batch_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE, -- Optional expiry date
    
    -- Costs
    total_cost NUMERIC(10,2) NOT NULL, -- Total cost of this batch
    cost_per_unit NUMERIC(10,2) NOT NULL, -- Cost per unit in this batch
    
    -- Metadata
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT TRUE, -- Set to false for draft batches
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT production_batches_quantity_positive CHECK (quantity > 0),
    CONSTRAINT production_batches_remaining_valid CHECK (remaining_qty >= 0 AND remaining_qty <= quantity)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_production_batches_product ON production_batches (product_id, batch_date DESC);
CREATE INDEX IF NOT EXISTS idx_production_batches_owner ON production_batches (business_owner_id, batch_date DESC);
CREATE INDEX IF NOT EXISTS idx_production_batches_remaining ON production_batches (product_id, remaining_qty) 
    WHERE remaining_qty > 0;

-- ============================================================================
-- TRIGGERS: Auto-update timestamps
-- ============================================================================
CREATE OR REPLACE FUNCTION update_recipe_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_recipe_items_updated_at ON recipe_items;
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

DROP TRIGGER IF EXISTS trigger_production_batches_updated_at ON production_batches;
CREATE TRIGGER trigger_production_batches_updated_at
    BEFORE UPDATE ON production_batches
    FOR EACH ROW
    EXECUTE FUNCTION update_production_batches_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;

-- Recipe Items Policies
DROP POLICY IF EXISTS "Users can view their own recipe items" ON recipe_items;
CREATE POLICY "Users can view their own recipe items"
    ON recipe_items FOR SELECT
    USING (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own recipe items" ON recipe_items;
CREATE POLICY "Users can insert their own recipe items"
    ON recipe_items FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own recipe items" ON recipe_items;
CREATE POLICY "Users can update their own recipe items"
    ON recipe_items FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own recipe items" ON recipe_items;
CREATE POLICY "Users can delete their own recipe items"
    ON recipe_items FOR DELETE
    USING (business_owner_id = auth.uid());

-- Production Batches Policies
DROP POLICY IF EXISTS "Users can view their own production batches" ON production_batches;
CREATE POLICY "Users can view their own production batches"
    ON production_batches FOR SELECT
    USING (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own production batches" ON production_batches;
CREATE POLICY "Users can insert their own production batches"
    ON production_batches FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own production batches" ON production_batches;
CREATE POLICY "Users can update their own production batches"
    ON production_batches FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own production batches" ON production_batches;
CREATE POLICY "Users can delete their own production batches"
    ON production_batches FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- HELPER FUNCTION: Calculate Recipe Cost
-- Automatically calculates total materials cost for a product's recipe
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_recipe_cost(p_product_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_total_cost NUMERIC := 0;
BEGIN
    -- Sum up all recipe item costs for this product
    SELECT COALESCE(SUM(cost_per_recipe), 0)
    INTO v_total_cost
    FROM recipe_items
    WHERE product_id = p_product_id;
    
    RETURN v_total_cost;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION: Update Product Costs
-- Recalculates all cost fields for a product based on recipe and settings
-- ============================================================================
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
    -- Get product settings
    SELECT 
        labour_cost,
        other_costs,
        packaging_cost,
        units_per_batch,
        suggested_margin
    INTO 
        v_labour_cost,
        v_other_costs,
        v_packaging_cost,
        v_units_per_batch,
        v_suggested_margin
    FROM products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
    
    -- Calculate materials cost from recipe
    v_materials_cost := calculate_recipe_cost(p_product_id);
    
    -- Calculate total cost per batch
    -- Formula: materials + labour + other + (packaging * units)
    v_total_cost_per_batch := v_materials_cost + v_labour_cost + v_other_costs + (v_packaging_cost * v_units_per_batch);
    
    -- Calculate cost per unit
    IF v_units_per_batch > 0 THEN
        v_cost_per_unit := v_total_cost_per_batch / v_units_per_batch;
    ELSE
        v_cost_per_unit := 0;
    END IF;
    
    -- Calculate suggested price
    -- Formula: cost_per_unit * (1 + margin/100)
    v_suggested_price := v_cost_per_unit * (1 + v_suggested_margin / 100);
    
    -- Update product
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

-- ============================================================================
-- HELPER FUNCTION: Record Production Batch
-- Creates production batch and deducts stock automatically
-- ============================================================================
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
    -- Get product info
    SELECT business_owner_id, name, cost_per_unit
    INTO v_business_owner_id, v_product_name, v_cost_per_unit
    FROM products
    WHERE id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;
    
    -- Calculate total cost
    v_total_cost := v_cost_per_unit * p_quantity;
    
    -- Create production batch
    INSERT INTO production_batches (
        business_owner_id,
        product_id,
        batch_number,
        product_name,
        quantity,
        remaining_qty,
        batch_date,
        expiry_date,
        total_cost,
        cost_per_unit,
        notes,
        created_at
    ) VALUES (
        v_business_owner_id,
        p_product_id,
        p_batch_number,
        v_product_name,
        p_quantity,
        p_quantity, -- Initially, all units remain
        p_batch_date,
        p_expiry_date,
        v_total_cost,
        v_cost_per_unit,
        p_notes,
        NOW()
    ) RETURNING id INTO v_batch_id;
    
    -- Deduct stock items based on recipe
    FOR v_recipe_item IN
        SELECT ri.stock_item_id, ri.quantity_needed
        FROM recipe_items ri
        WHERE ri.product_id = p_product_id
    LOOP
        -- Calculate quantity to deduct (recipe quantity * production quantity)
        v_quantity_to_deduct := v_recipe_item.quantity_needed * p_quantity;
        
        -- Record stock movement (deduction)
        PERFORM record_stock_movement(
            p_stock_item_id := v_recipe_item.stock_item_id,
            p_movement_type := 'production_use',
            p_quantity_change := -v_quantity_to_deduct,
            p_reason := format('Used in production: %s (Batch: %s)', v_product_name, v_batch_id),
            p_reference_id := v_batch_id,
            p_reference_type := 'production_batch',
            p_created_by := auth.uid()
        );
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE recipe_items IS 'Links products to stock items with quantities needed per batch';
COMMENT ON TABLE production_batches IS 'Records production of finished goods with FIFO tracking';
COMMENT ON FUNCTION calculate_recipe_cost IS 'Calculates total materials cost for a product recipe';
COMMENT ON FUNCTION update_product_costs IS 'Recalculates all cost fields for a product';
COMMENT ON FUNCTION record_production_batch IS 'Creates batch and auto-deducts stock in one transaction';

