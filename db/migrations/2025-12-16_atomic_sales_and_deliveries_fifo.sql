-- Atomic sales & vendor deliveries creation with FIFO deduction from production_batches
-- Uses movement_type='sale' and differentiates sources via reference_type ('sale' | 'delivery').
--
-- Requires tables:
-- - sales, sale_items
-- - vendor_deliveries, vendor_delivery_items
-- - production_batches
-- - production_batch_stock_movements
--
-- Notes:
-- - SECURITY DEFINER is used so function can run atomically; we still enforce ownership via auth.uid().

BEGIN;

-- ============================================================================
-- Helper: deduct from finished goods batches (FIFO by batch_date) + log movements
-- ============================================================================
CREATE OR REPLACE FUNCTION deduct_from_production_batches_fifo(
  p_business_owner_id UUID,
  p_product_id UUID,
  p_quantity_to_deduct NUMERIC,
  p_reference_id UUID,
  p_reference_type TEXT,
  p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_remaining NUMERIC := p_quantity_to_deduct;
  v_batch RECORD;
  v_deducted NUMERIC;
  v_new_remaining NUMERIC;
  v_total_available NUMERIC;
BEGIN
  IF p_quantity_to_deduct <= 0 THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(remaining_qty), 0)
  INTO v_total_available
  FROM production_batches
  WHERE business_owner_id = p_business_owner_id
    AND product_id = p_product_id
    AND remaining_qty > 0;

  IF v_total_available < p_quantity_to_deduct THEN
    RAISE EXCEPTION 'Insufficient finished stock. Available: %, Required: %', v_total_available, p_quantity_to_deduct;
  END IF;

  FOR v_batch IN
    SELECT id, remaining_qty
    FROM production_batches
    WHERE business_owner_id = p_business_owner_id
      AND product_id = p_product_id
      AND remaining_qty > 0
    ORDER BY batch_date ASC, created_at ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    v_deducted := LEAST(v_remaining, v_batch.remaining_qty);
    v_new_remaining := v_batch.remaining_qty - v_deducted;

    UPDATE production_batches
    SET remaining_qty = v_new_remaining,
        updated_at = NOW()
    WHERE id = v_batch.id;

    INSERT INTO production_batch_stock_movements (
      business_owner_id,
      batch_id,
      product_id,
      movement_type,
      quantity,
      remaining_after_movement,
      reference_id,
      reference_type,
      notes
    ) VALUES (
      p_business_owner_id,
      v_batch.id,
      p_product_id,
      'sale',
      v_deducted,
      v_new_remaining,
      p_reference_id,
      p_reference_type,
      p_notes
    );

    v_remaining := v_remaining - v_deducted;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION deduct_from_production_batches_fifo IS
  'Deduct finished goods from production_batches FIFO (oldest first) and record movements. movement_type fixed to sale; use reference_type to differentiate.';

-- ============================================================================
-- Atomic Sale Creation + FIFO deduction
-- ============================================================================
DROP FUNCTION IF EXISTS create_sale_and_deduct_fifo CASCADE;

CREATE OR REPLACE FUNCTION create_sale_and_deduct_fifo(
  p_items JSONB,
  p_customer_name TEXT DEFAULT NULL,
  p_channel TEXT DEFAULT 'walk-in',
  p_discount_amount NUMERIC DEFAULT 0,
  p_notes TEXT DEFAULT NULL,
  p_delivery_address TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sale_id UUID;
  v_item JSONB;
  v_product_id UUID;
  v_product_name TEXT;
  v_qty NUMERIC;
  v_unit_price NUMERIC;
  v_subtotal NUMERIC;
  v_total NUMERIC := 0;
  v_final NUMERIC := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'p_items must be a non-empty JSON array';
  END IF;

  -- Pre-calc totals & validate items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
    v_product_name := COALESCE(v_item->>'product_name', 'Unknown');

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for product %', v_product_id;
    END IF;
    IF v_unit_price < 0 THEN
      RAISE EXCEPTION 'Invalid unit_price for product %', v_product_id;
    END IF;

    -- Ensure product belongs to current user
    IF NOT EXISTS (
      SELECT 1 FROM products
      WHERE id = v_product_id
        AND business_owner_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Product not found/unauthorized: %', v_product_id;
    END IF;

    v_subtotal := v_qty * v_unit_price;
    v_total := v_total + v_subtotal;
  END LOOP;

  v_final := v_total - COALESCE(p_discount_amount, 0);
  IF v_final < 0 THEN
    v_final := 0;
  END IF;

  -- Insert sale
  INSERT INTO sales (
    business_owner_id,
    customer_name,
    channel,
    total_amount,
    discount_amount,
    final_amount,
    notes,
    delivery_address,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_customer_name,
    COALESCE(p_channel, 'walk-in'),
    v_total,
    COALESCE(p_discount_amount, 0),
    v_final,
    p_notes,
    p_delivery_address,
    NOW(),
    NOW()
  ) RETURNING id INTO v_sale_id;

  -- Insert sale items + deduct FIFO per item (atomic)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
    v_product_name := COALESCE(v_item->>'product_name', 'Unknown');
    v_subtotal := v_qty * v_unit_price;

    INSERT INTO sale_items (
      sale_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      subtotal,
      created_at,
      updated_at
    ) VALUES (
      v_sale_id,
      v_product_id,
      v_product_name,
      v_qty,
      v_unit_price,
      v_subtotal,
      NOW(),
      NOW()
    );

    PERFORM deduct_from_production_batches_fifo(
      p_business_owner_id := v_user_id,
      p_product_id := v_product_id,
      p_quantity_to_deduct := v_qty,
      p_reference_id := v_sale_id,
      p_reference_type := 'sale',
      p_notes := COALESCE(p_notes, 'Sale') || ' #' || substr(v_sale_id::TEXT, 1, 8)
    );
  END LOOP;

  RETURN v_sale_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION create_sale_and_deduct_fifo IS
  'Creates a sale + sale_items and deducts finished goods FIFO atomically.';

-- ============================================================================
-- Atomic Vendor Delivery Creation + FIFO deduction (accepted qty only)
-- ============================================================================
DROP FUNCTION IF EXISTS create_vendor_delivery_and_deduct_fifo CASCADE;

CREATE OR REPLACE FUNCTION create_vendor_delivery_and_deduct_fifo(
  p_vendor_id UUID,
  p_delivery_date DATE,
  p_items JSONB,
  p_status TEXT DEFAULT 'delivered',
  p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_delivery_id UUID;
  v_vendor_name TEXT;
  v_item JSONB;
  v_product_id UUID;
  v_product_name TEXT;
  v_qty NUMERIC;
  v_rejected NUMERIC;
  v_accepted NUMERIC;
  v_unit_price NUMERIC;
  v_total_price NUMERIC;
  v_total_amount NUMERIC := 0;
  v_retail_price NUMERIC;
  v_rejection_reason TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'p_items must be a non-empty JSON array';
  END IF;

  -- Vendor ownership check + name
  SELECT name INTO v_vendor_name
  FROM vendors
  WHERE id = p_vendor_id
    AND business_owner_id = v_user_id;

  IF v_vendor_name IS NULL THEN
    RAISE EXCEPTION 'Vendor not found/unauthorized: %', p_vendor_id;
  END IF;

  -- Pre-calc total amount (accepted qty only) + validate
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
    v_rejected := COALESCE((v_item->>'rejected_qty')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
    v_product_name := COALESCE(v_item->>'product_name', 'Unknown');

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for product %', v_product_id;
    END IF;
    IF v_rejected < 0 OR v_rejected > v_qty THEN
      RAISE EXCEPTION 'Invalid rejected_qty for product %', v_product_id;
    END IF;
    IF v_unit_price < 0 THEN
      RAISE EXCEPTION 'Invalid unit_price for product %', v_product_id;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM products
      WHERE id = v_product_id
        AND business_owner_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'Product not found/unauthorized: %', v_product_id;
    END IF;

    v_accepted := v_qty - v_rejected;
    v_total_amount := v_total_amount + (v_accepted * v_unit_price);
  END LOOP;

  INSERT INTO vendor_deliveries (
    business_owner_id,
    vendor_id,
    vendor_name,
    delivery_date,
    status,
    total_amount,
    notes,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_vendor_id,
    v_vendor_name,
    p_delivery_date,
    COALESCE(p_status, 'delivered'),
    v_total_amount,
    p_notes,
    NOW(),
    NOW()
  ) RETURNING id INTO v_delivery_id;

  -- Insert items + deduct FIFO for accepted qty (atomic)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := COALESCE(v_item->>'product_name', 'Unknown');
    v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
    v_rejected := COALESCE((v_item->>'rejected_qty')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
    v_retail_price := NULLIF((v_item->>'retail_price')::NUMERIC, 0);
    v_rejection_reason := NULLIF(v_item->>'rejection_reason', '');

    v_accepted := v_qty - v_rejected;
    v_total_price := v_accepted * v_unit_price;

    INSERT INTO vendor_delivery_items (
      delivery_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      total_price,
      retail_price,
      rejected_qty,
      rejection_reason,
      created_at,
      updated_at
    ) VALUES (
      v_delivery_id,
      v_product_id,
      v_product_name,
      v_qty,
      v_unit_price,
      v_total_price,
      v_retail_price,
      v_rejected,
      v_rejection_reason,
      NOW(),
      NOW()
    );

    IF v_accepted > 0 THEN
      PERFORM deduct_from_production_batches_fifo(
        p_business_owner_id := v_user_id,
        p_product_id := v_product_id,
        p_quantity_to_deduct := v_accepted,
        p_reference_id := v_delivery_id,
        p_reference_type := 'delivery',
        p_notes := COALESCE(p_notes, 'Delivery') || ' #' || substr(v_delivery_id::TEXT, 1, 8)
      );
    END IF;
  END LOOP;

  RETURN v_delivery_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION create_vendor_delivery_and_deduct_fifo IS
  'Creates vendor delivery + items and deducts finished goods FIFO atomically (accepted qty only).';

COMMIT;


