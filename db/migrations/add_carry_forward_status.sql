-- CARRY FORWARD STATUS FIELD
-- Allows users to mark unsold items as either Loss or Carry Forward
-- ============================================================================

BEGIN;

-- Add carry_forward_status field to track user's explicit choice
-- Values: 'none' (default), 'carry_forward', 'loss'
ALTER TABLE consignment_claim_items
ADD COLUMN IF NOT EXISTS carry_forward_status TEXT DEFAULT 'none'
CHECK (carry_forward_status IN ('none', 'carry_forward', 'loss'));

-- Create index for fast lookup
CREATE INDEX IF NOT EXISTS idx_claim_items_cf_status 
ON consignment_claim_items(claim_id, carry_forward_status);

-- Update trigger to use carry_forward_status instead of carry_forward boolean
DROP TRIGGER IF EXISTS trigger_create_carry_forward_items ON consignment_claim_items;

CREATE TRIGGER trigger_create_carry_forward_items
    AFTER INSERT ON consignment_claim_items
    FOR EACH ROW
    WHEN (NEW.quantity_unsold > 0 
          AND NEW.carry_forward_status = 'carry_forward')
EXECUTE FUNCTION create_carry_forward_items();

COMMIT;
