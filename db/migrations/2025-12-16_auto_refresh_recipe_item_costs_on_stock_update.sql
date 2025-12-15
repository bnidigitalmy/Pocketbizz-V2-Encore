-- ============================================================================
-- AUTO-REFRESH RECIPE ITEM COSTS WHEN STOCK ITEM COST CHANGES
-- Fixes the real-world limitation:
-- - Recipe totals can become outdated when stock_items.purchase_price/package_size/unit changes.
--
-- Strategy:
-- - On stock_items update (purchase_price/package_size/unit), recompute:
--   - recipe_items.cost_per_unit (based on latest stock cost per stock unit)
--   - recipe_items.total_cost (based on converted quantity -> stock unit * cost_per_unit)
-- - Existing recipe trigger (recipe_items_cost_update) will then auto-update recipes rollups.
-- Requires:
-- - convert_unit(quantity, from_unit, to_unit) to exist.
-- ============================================================================

-- Recompute all recipe_items costs for one stock item
CREATE OR REPLACE FUNCTION refresh_recipe_item_costs_for_stock_item(p_stock_item_id UUID)
RETURNS VOID AS $$
DECLARE
    v_stock_unit TEXT;
    v_cost_per_unit NUMERIC;
BEGIN
    SELECT
        unit,
        COALESCE(purchase_price / NULLIF(package_size, 0), 0)
    INTO v_stock_unit, v_cost_per_unit
    FROM stock_items
    WHERE id = p_stock_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock item not found: %', p_stock_item_id;
    END IF;

    -- Update all recipe items referencing this stock item.
    -- Note: total_cost is computed using converted quantity into stock unit.
    UPDATE recipe_items ri
    SET
        cost_per_unit = v_cost_per_unit,
        total_cost = convert_unit(ri.quantity_needed, ri.usage_unit, v_stock_unit) * v_cost_per_unit,
        updated_at = NOW()
    WHERE ri.stock_item_id = p_stock_item_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION refresh_recipe_item_costs_for_stock_item IS
    'Recomputes recipe_items.cost_per_unit/total_cost for a stock item using latest stock_items pricing & convert_unit';

-- Trigger: when stock item pricing or unit changes, refresh related recipe items
CREATE OR REPLACE FUNCTION trigger_refresh_recipe_items_on_stock_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Only run when fields that affect costing change
    IF (NEW.purchase_price IS DISTINCT FROM OLD.purchase_price)
       OR (NEW.package_size IS DISTINCT FROM OLD.package_size)
       OR (NEW.unit IS DISTINCT FROM OLD.unit) THEN
        PERFORM refresh_recipe_item_costs_for_stock_item(NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS stock_items_refresh_recipe_costs ON stock_items;
CREATE TRIGGER stock_items_refresh_recipe_costs
    AFTER UPDATE OF purchase_price, package_size, unit ON stock_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_refresh_recipe_items_on_stock_update();


