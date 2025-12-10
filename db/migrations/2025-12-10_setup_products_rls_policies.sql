-- Enable Row Level Security on products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view their own products" ON products;
DROP POLICY IF EXISTS "Users can insert their own products" ON products;
DROP POLICY IF EXISTS "Users can update their own products" ON products;
DROP POLICY IF EXISTS "Users can delete their own products" ON products;

-- Policy: Users can view their own products only
CREATE POLICY "Users can view their own products"
ON products
FOR SELECT
USING (business_owner_id = auth.uid());

-- Policy: Users can insert products with their own business_owner_id
CREATE POLICY "Users can insert their own products"
ON products
FOR INSERT
WITH CHECK (business_owner_id = auth.uid());

-- Policy: Users can update their own products only
CREATE POLICY "Users can update their own products"
ON products
FOR UPDATE
USING (business_owner_id = auth.uid())
WITH CHECK (business_owner_id = auth.uid());

-- Policy: Users can delete their own products only
CREATE POLICY "Users can delete their own products"
ON products
FOR DELETE
USING (business_owner_id = auth.uid());

