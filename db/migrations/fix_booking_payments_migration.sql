-- FIX BOOKING PAYMENTS MIGRATION
-- Run this if you get error: column "total_paid" of relation "booking_payments" does not exist
-- This script will clean up and re-run the migration properly

BEGIN;

-- Step 1: Drop trigger if exists (might be in wrong state)
DROP TRIGGER IF EXISTS trigger_update_booking_total_paid ON booking_payments;

-- Step 2: Ensure total_paid column exists in bookings table (not booking_payments!)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS total_paid NUMERIC(12,2) DEFAULT 0;

-- Step 3: Recreate the function (ensures it references correct table)
CREATE OR REPLACE FUNCTION update_booking_total_paid()
RETURNS TRIGGER AS $$
BEGIN
    -- Update total_paid in bookings table (NOT booking_payments!)
    UPDATE bookings
    SET total_paid = (
        SELECT COALESCE(SUM(payment_amount), 0)
        FROM booking_payments
        WHERE booking_id = COALESCE(NEW.booking_id, OLD.booking_id)
    )
    WHERE id = COALESCE(NEW.booking_id, OLD.booking_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 4: Recreate trigger
CREATE TRIGGER trigger_update_booking_total_paid
    AFTER INSERT OR UPDATE OR DELETE ON booking_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_total_paid();

-- Step 5: Update existing bookings with current total_paid (if any payments exist)
UPDATE bookings
SET total_paid = (
    SELECT COALESCE(SUM(payment_amount), 0)
    FROM booking_payments
    WHERE booking_payments.booking_id = bookings.id
)
WHERE EXISTS (
    SELECT 1 FROM booking_payments WHERE booking_payments.booking_id = bookings.id
);

COMMIT;

