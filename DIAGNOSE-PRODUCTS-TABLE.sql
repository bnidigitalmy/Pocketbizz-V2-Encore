-- ============================================================================
-- DIAGNOSTIC QUERIES - Run these ONE BY ONE in Supabase SQL Editor
-- ============================================================================

-- QUERY 1: Check if products table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = 'products'
);
-- Expected: true

-- QUERY 2: Check ALL columns in products table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'products'
ORDER BY ordinal_position;
-- Copy ALL output and send to me!

-- QUERY 3: Check primary key of products table
SELECT
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'products'
    AND tc.constraint_type = 'PRIMARY KEY';
-- What's the primary key column name?

-- QUERY 4: Check stock_items table structure
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'stock_items'
ORDER BY ordinal_position;
-- Does stock_items exist?

-- QUERY 5: Test if we can reference products
-- (Don't worry if this fails, we just testing)
DO $$
BEGIN
    -- Try to create a test foreign key
    EXECUTE 'CREATE TABLE test_fk_check (
        id UUID PRIMARY KEY,
        product_id UUID REFERENCES products(id)
    )';
    
    -- Clean up
    DROP TABLE test_fk_check;
    
    RAISE NOTICE 'FK to products.id WORKS!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: %', SQLERRM;
END $$;

