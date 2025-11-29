# 🚀 APPLY THESE MIGRATIONS NOW!

## Step 1: Product Images Support

```sql
-- Copy & paste this in Supabase Dashboard > SQL Editor

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'image_url'
    ) THEN
        ALTER TABLE products ADD COLUMN image_url TEXT;
    END IF;
END $$;

COMMENT ON COLUMN products.image_url IS 'URL to product image in Supabase Storage';
```

**Click RUN!** ✅

---

## Step 2: Categories Module

```sql
-- Copy & paste this in Supabase Dashboard > SQL Editor

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_owner_id, name)
);

-- Create indexes
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

-- Insert default categories
INSERT INTO categories (business_owner_id, name, icon, color)
SELECT DISTINCT business_owner_id, 'General', '📦', '#6B7280'
FROM products
WHERE business_owner_id NOT IN (SELECT business_owner_id FROM categories)
ON CONFLICT DO NOTHING;
```

**Click RUN!** ✅

---

## Step 3: Create Storage Bucket

1. Go to **Supabase Dashboard**
2. Click **Storage** (left sidebar)
3. Click **New Bucket**
4. Name: `product-images`
5. **✅ Public bucket** (check this!)
6. Click **Create Bucket**

---

## ✅ DONE!

Migrations applied! Now hot reload the app! 🔥

