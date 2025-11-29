-- =====================================================
-- CATEGORIES MODULE
-- =====================================================
-- This migration creates a categories table for better
-- organization of products

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT, -- Emoji or icon name
    color TEXT, -- Hex color code
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_owner_id, name)
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_categories_owner ON categories (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories (business_owner_id, is_active);

-- Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY categories_select_own ON categories
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY categories_insert_own ON categories
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY categories_update_own ON categories
    FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY categories_delete_own ON categories
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- Insert default categories for existing users
INSERT INTO categories (business_owner_id, name, icon, color)
SELECT DISTINCT business_owner_id, 'General', '📦', '#6B7280'
FROM products
WHERE business_owner_id NOT IN (SELECT business_owner_id FROM categories)
ON CONFLICT DO NOTHING;

-- Add some common default categories
-- (These will be added when user first creates a product)
COMMENT ON TABLE categories IS 'Product categories for better organization and filtering';

