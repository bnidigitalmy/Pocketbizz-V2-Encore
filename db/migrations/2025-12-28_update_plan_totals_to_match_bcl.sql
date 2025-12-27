-- ============================================================================
-- Align subscription_plans totals with BCL.my form amounts (whole-ringgit)
-- ============================================================================
-- Normal pricing: RM39/bulan
-- - 6 bulan (-8%)  = 215 (from 215.28 floored/rounded by business decision)
-- - 12 bulan (-15%) = 397 (from 397.80 floored)
--
-- This ensures webhook strict amount validation matches the payment.amount stored.
-- ============================================================================

BEGIN;

UPDATE public.subscription_plans
SET total_price = 215.00,
    discount_percentage = 8.00,
    price_per_month = 39.00,
    updated_at = NOW()
WHERE duration_months = 6;

UPDATE public.subscription_plans
SET total_price = 397.00,
    discount_percentage = 15.00,
    price_per_month = 39.00,
    updated_at = NOW()
WHERE duration_months = 12;

COMMIT;


