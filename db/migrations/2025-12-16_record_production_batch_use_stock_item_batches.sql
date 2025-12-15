-- Upgrade record_production_batch to deduct raw materials using stock_item_batches FIFO (expiry-first)
-- Fallback: if no batches exist for a stock item, use legacy stock_items.current_quantity + record_stock_movement.
--
-- Depends on:
-- - convert_unit(quantity, from_unit, to_unit)
-- - record_stock_movement(...)
-- - deduct_from_stock_item_batches(...)

BEGIN;

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
    v_quantity_to_deduct_converted NUMERIC;
    v_recipe_id UUID;
    v_stock_cost_per_unit NUMERIC;
    v_recipe_item_id UUID;
    v_units_per_batch INTEGER;
    v_batches_needed NUMERIC;

    v_has_batches_table BOOLEAN := (to_regclass('public.stock_item_batches') IS NOT NULL);
    v_batches_count INTEGER;
    v_available_from_batches NUMERIC;
    v_rm_total_cost NUMERIC;
    v_rm_total_qty NUMERIC;
BEGIN
    -- Get product info including units_per_batch
    SELECT business_owner_id, name, cost_per_unit, COALESCE(units_per_batch, 1)
    INTO v_business_owner_id, v_product_name, v_cost_per_unit, v_units_per_batch
    FROM products
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;

    -- Get active recipe for this product
    SELECT id INTO v_recipe_id
    FROM recipes
    WHERE product_id = p_product_id
      AND is_active = true
    LIMIT 1;

    IF v_recipe_id IS NULL THEN
        RAISE EXCEPTION 'No active recipe found for product: %', p_product_id;
    END IF;

    -- Calculate number of batches needed
    -- p_quantity is total units, so divide by units_per_batch to get batches
    v_batches_needed := p_quantity::NUMERIC / NULLIF(v_units_per_batch, 0);
    IF v_batches_needed IS NULL OR v_batches_needed <= 0 THEN
        v_batches_needed := 1;
    END IF;

    -- Calculate total cost
    v_total_cost := COALESCE(v_cost_per_unit, 0) * p_quantity;

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
        COALESCE(p_batch_number, 'BATCH-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS')),
        v_product_name,
        p_quantity,
        p_quantity,
        p_batch_date,
        p_expiry_date,
        v_total_cost,
        v_cost_per_unit,
        p_notes,
        NOW()
    ) RETURNING id INTO v_batch_id;

    -- FIRST PASS: Check if all ingredients have sufficient stock
    FOR v_recipe_item IN
        SELECT
            ri.stock_item_id,
            ri.quantity_needed,
            ri.usage_unit,
            si.unit as stock_unit,
            si.current_quantity,
            si.name as stock_item_name
        FROM recipe_items ri
        JOIN stock_items si ON si.id = ri.stock_item_id
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        v_quantity_to_deduct := v_recipe_item.quantity_needed * v_batches_needed;
        v_quantity_to_deduct_converted := convert_unit(
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            v_recipe_item.stock_unit
        );

        IF v_has_batches_table THEN
            SELECT COUNT(*), COALESCE(SUM(remaining_qty), 0)
            INTO v_batches_count, v_available_from_batches
            FROM stock_item_batches
            WHERE stock_item_id = v_recipe_item.stock_item_id
              AND remaining_qty > 0;

            IF v_batches_count > 0 THEN
                IF v_available_from_batches < v_quantity_to_deduct_converted THEN
                    RAISE EXCEPTION 'Stok batch tidak mencukupi untuk %: Available: %, Required: %',
                        v_recipe_item.stock_item_name,
                        v_available_from_batches,
                        v_quantity_to_deduct_converted;
                END IF;
                CONTINUE;
            END IF;
        END IF;

        -- Legacy fallback
        IF v_recipe_item.current_quantity < v_quantity_to_deduct_converted THEN
            RAISE EXCEPTION 'Stok tidak mencukupi untuk %: Available: %, Required: %',
                v_recipe_item.stock_item_name,
                v_recipe_item.current_quantity,
                v_quantity_to_deduct_converted;
        END IF;
    END LOOP;

    -- SECOND PASS: Deduct + record usage
    FOR v_recipe_item IN
        SELECT
            ri.stock_item_id,
            ri.quantity_needed,
            ri.usage_unit,
            si.unit as stock_unit,
            si.current_quantity,
            si.name as stock_item_name
        FROM recipe_items ri
        JOIN stock_items si ON si.id = ri.stock_item_id
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        v_quantity_to_deduct := v_recipe_item.quantity_needed * v_batches_needed;
        v_quantity_to_deduct_converted := convert_unit(
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            v_recipe_item.stock_unit
        );

        v_rm_total_cost := NULL;
        v_rm_total_qty := NULL;

        IF v_has_batches_table THEN
            SELECT COUNT(*) INTO v_batches_count
            FROM stock_item_batches
            WHERE stock_item_id = v_recipe_item.stock_item_id
              AND remaining_qty > 0;

            IF v_batches_count > 0 THEN
                -- Deduct from batches (expiry-first FIFO) and aggregate actual cost
                SELECT
                    COALESCE(SUM(x.total_cost), 0),
                    COALESCE(SUM(x.quantity_deducted), 0)
                INTO v_rm_total_cost, v_rm_total_qty
                FROM deduct_from_stock_item_batches(
                    p_stock_item_id := v_recipe_item.stock_item_id,
                    p_quantity_to_deduct := v_quantity_to_deduct_converted,
                    p_reason := format('Production: %s (Batch: %s)', v_product_name, v_batch_id),
                    p_reference_id := v_batch_id,
                    p_reference_type := 'production_batch'
                ) AS x;
            END IF;
        END IF;

        IF v_rm_total_qty IS NULL OR v_rm_total_qty <= 0 THEN
            -- Legacy fallback: deduct from aggregate stock via record_stock_movement
            PERFORM record_stock_movement(
                p_stock_item_id := v_recipe_item.stock_item_id,
                p_movement_type := 'production_use',
                p_quantity_change := -v_quantity_to_deduct_converted,
                p_reason := format('Production: %s (Batch: %s)', v_product_name, v_batch_id),
                p_reference_id := v_batch_id,
                p_reference_type := 'production_batch',
                p_created_by := auth.uid()
            );

            SELECT COALESCE(purchase_price / NULLIF(package_size, 0), 0)
            INTO v_stock_cost_per_unit
            FROM stock_items
            WHERE id = v_recipe_item.stock_item_id;

            v_rm_total_cost := v_quantity_to_deduct_converted * COALESCE(v_stock_cost_per_unit, 0);
        ELSE
            -- Use weighted average cost per STOCK unit based on actual batch deductions
            v_stock_cost_per_unit := v_rm_total_cost / NULLIF(v_rm_total_qty, 0);
        END IF;

        -- Get recipe item ID
        SELECT id INTO v_recipe_item_id
        FROM recipe_items
        WHERE recipe_id = v_recipe_id
          AND stock_item_id = v_recipe_item.stock_item_id
        LIMIT 1;

        -- Record ingredient usage audit (quantity_used in usage_unit; total_cost in stock_unit * cost)
        INSERT INTO production_ingredient_usage (
            business_owner_id,
            production_batch_id,
            stock_item_id,
            recipe_item_id,
            quantity_used,
            unit,
            cost_per_unit,
            total_cost
        ) VALUES (
            v_business_owner_id,
            v_batch_id,
            v_recipe_item.stock_item_id,
            v_recipe_item_id,
            v_quantity_to_deduct,
            v_recipe_item.usage_unit,
            COALESCE(v_stock_cost_per_unit, 0),
            COALESCE(v_rm_total_cost, 0)
        );
    END LOOP;

    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_production_batch IS
  'Creates production batch and deducts raw materials; uses stock_item_batches FIFO (expiry-first) when available, otherwise falls back to aggregate stock.';

COMMIT;


