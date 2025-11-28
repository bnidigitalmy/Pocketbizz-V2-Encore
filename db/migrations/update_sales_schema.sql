-- Update sales table to match new repository structure
-- Add missing columns and adjust existing ones

-- Drop old structure if exists and recreate
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;

-- Create sales table with new structure
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    customer_name TEXT,
    channel TEXT NOT NULL DEFAULT 'walk-in',
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12,2),
    final_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create sale_items table (note: singular naming to match code)
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_sales_owner ON sales (business_owner_id);
CREATE INDEX idx_sales_channel ON sales (channel);
CREATE INDEX idx_sales_created ON sales (created_at DESC);

CREATE INDEX idx_sale_items_sale ON sale_items (sale_id);
CREATE INDEX idx_sale_items_product ON sale_items (product_id);

-- Enable RLS
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for sales
CREATE POLICY sales_select_own ON sales
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY sales_insert_own ON sales
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY sales_update_own ON sales
    FOR UPDATE USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY sales_delete_own ON sales
    FOR DELETE USING (business_owner_id = auth.uid());

-- RLS Policies for sale_items (inherit from sales)
CREATE POLICY sale_items_select_own ON sale_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sales
            WHERE sales.id = sale_items.sale_id
            AND sales.business_owner_id = auth.uid()
        )
    );

CREATE POLICY sale_items_insert_own ON sale_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM sales
            WHERE sales.id = sale_items.sale_id
            AND sales.business_owner_id = auth.uid()
        )
    );

