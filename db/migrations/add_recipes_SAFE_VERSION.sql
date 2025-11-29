-- ============================================================================
-- ULTRA-SAFE RECIPES & PRODUCTION MIGRATION
-- This version checks EVERYTHING before creating
-- ============================================================================

-- Step 1: Verify prerequisites
DO $$
BEGIN
    -- Check products table exists
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products') THEN
        RAISE EXCEPTION 'products table does not exist! Create it first.';
    END IF;
    
    -- Check stock_items table exists
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'stock_items') THEN
        RAISE EXCEPTION 'stock_items table does not exist! Run stock management migration first.';
    END IF;
    
    -- Check users table exists
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users') THEN
        RAISE EXCEPTION 'users table does not exist!';
    END IF;
    
    RAISE NOTICE 'All prerequisite tables exist ✓';
END $$;

-- ============================================================================
-- UPDATE PRODUCTS TABLE
-- ============================================================================
DO $$ 
BEGIN
    -- Add columns one by one
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
    
    -- Set NOT NULL after adding columns
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
    
    RAISE NOTICE 'Products table updated ✓';
END $$;

-- ============================================================================
-- RECIPE ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL,
    product_id UUID NOT NULL,
    stock_item_id UUID NOT NULL,
    quantity_needed NUMERIC(10,2) NOT NULL CHECK (quantity_needed > 0),
    usage_unit TEXT NOT NULL,
    cost_per_recipe NUMERIC(10,2) NOT NULL DEFAULT 0,
    position INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign keys SEPARATELY (safer)
DO $$
BEGIN
    -- FK to users
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'recipe_items_business_owner_id_fkey' 
        AND table_name = 'recipe_items'
    ) THEN
        ALTER TABLE recipe_items 
        ADD CONSTRAINT recipe_items_business_owner_id_fkey 
        FOREIGN KEY (business_owner_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
    
    -- FK to products
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'recipe_items_product_id_fkey' 
        AND table_name = 'recipe_items'
    ) THEN
        ALTER TABLE recipe_items 
        ADD CONSTRAINT recipe_items_product_id_fkey 
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
    END IF;
    
    -- FK to stock_items
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'recipe_items_stock_item_id_fkey' 
        AND table_name = 'recipe_items'
    ) THEN
        ALTER TABLE recipe_items 
        ADD CONSTRAINT recipe_items_stock_item_id_fkey 
        FOREIGN KEY (stock_item_id) REFERENCES stock_items(id) ON DELETE CASCADE;
    END IF;
    
    RAISE NOTICE 'Recipe items foreign keys added ✓';
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recipe_items_product ON recipe_items (product_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_stock_item ON recipe_items (stock_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_owner ON recipe_items (business_owner_id);

-- ============================================================================
-- PRODUCTION BATCHES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS production_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL,
    product_id UUID NOT NULL,
    batch_number TEXT,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    remaining_qty NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (remaining_qty >= 0),
    batch_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    total_cost NUMERIC(10,2) NOT NULL,
    cost_per_unit NUMERIC(10,2) NOT NULL,
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT production_batches_remaining_valid CHECK (remaining_qty <= quantity)
);

-- Add foreign keys SEPARATELY
DO $$
BEGIN
    -- FK to users
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'production_batches_business_owner_id_fkey' 
        AND table_name = 'production_batches'
    ) THEN
        ALTER TABLE production_batches 
        ADD CONSTRAINT production_batches_business_owner_id_fkey 
        FOREIGN KEY (business_owner_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
    
    -- FK to products
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'production_batches_product_id_fkey' 
        AND table_name = 'production_batches'
    ) THEN
        ALTER TABLE production_batches 
        ADD CONSTRAINT production_batches_product_id_fkey 
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
    END IF;
    
    RAISE NOTICE 'Production batches foreign keys added ✓';
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_production_batches_product ON production_batches (product_id, batch_date DESC);
CREATE INDEX IF NOT EXISTS idx_production_batches_owner ON production_batches (business_owner_id, batch_date DESC);
CREATE INDEX IF NOT EXISTS idx_production_batches_remaining ON production_batches (product_id, remaining_qty) 
    WHERE remaining_qty > 0;

-- ============================================================================
-- TRIGGERS
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
-- RLS POLICIES
-- ============================================================================
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;

-- Recipe Items
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
    USING (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own recipe items" ON recipe_items;
CREATE POLICY "Users can delete their own recipe items"
    ON recipe_items FOR DELETE
    USING (business_owner_id = auth.uid());

-- Production Batches
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
    USING (business_owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own production batches" ON production_batches;
CREATE POLICY "Users can delete their own production batches"
    ON production_batches FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- FUNCTIONS
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

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '✓✓✓ RECIPES & PRODUCTION MIGRATION COMPLETE! ✓✓✓';
END $$;

