-- =====================================================
-- PRODUCT IMAGES SUPPORT
-- =====================================================
-- This migration adds image support for products
-- and sets up the Supabase Storage bucket

-- Add image_url column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'image_url'
    ) THEN
        ALTER TABLE products ADD COLUMN image_url TEXT;
    END IF;
END $$;

-- Create storage bucket for product images (via Supabase Dashboard or API)
-- Bucket name: product-images
-- Public: true
-- Allowed MIME types: image/jpeg, image/png, image/webp
-- Max file size: 2MB

-- Note: Storage buckets must be created via Supabase Dashboard
-- Dashboard > Storage > New Bucket > "product-images" (make it public)

COMMENT ON COLUMN products.image_url IS 'URL to product image in Supabase Storage';

