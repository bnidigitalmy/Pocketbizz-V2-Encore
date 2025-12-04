-- CONSIGNMENT CLAIMS & PAYMENTS SYSTEM
-- Complete system for managing claims and payments in consignment business
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: CLEAN UP ANY OLD CONSIGNMENT TABLES (LEGACY STRUCTURE)
-- This ensures we don't clash with older Encore-based consignment schema
-- where consignment_claims did NOT have vendor_id.
-- ============================================================================

DROP TABLE IF EXISTS consignment_payment_allocations CASCADE;
DROP TABLE IF EXISTS consignment_payments CASCADE;
DROP TABLE IF EXISTS consignment_claim_items CASCADE;
DROP TABLE IF EXISTS consignment_claims CASCADE;

-- ============================================================================
-- STEP 1: ENHANCE EXISTING VENDOR_DELIVERY_ITEMS TABLE
-- Add quantity tracking for sold/unsold/expired/damaged
-- ============================================================================

-- Add new columns to track sales quantities
ALTER TABLE vendor_delivery_items
    ADD COLUMN IF NOT EXISTS quantity_sold NUMERIC(12,3) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS quantity_unsold NUMERIC(12,3) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS quantity_expired NUMERIC(12,3) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS quantity_damaged NUMERIC(12,3) DEFAULT 0;

-- Add constraint to ensure quantities balance
ALTER TABLE vendor_delivery_items
    DROP CONSTRAINT IF EXISTS valid_quantities;

ALTER TABLE vendor_delivery_items
    ADD CONSTRAINT valid_quantities CHECK (
        quantity >= (COALESCE(quantity_sold, 0) + COALESCE(quantity_unsold, 0) + 
                     COALESCE(quantity_expired, 0) + COALESCE(quantity_damaged, 0))
    );

-- ============================================================================
-- STEP 2: CREATE CONSIGNMENT_CLAIMS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS consignment_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    -- Claim Information
    claim_number TEXT UNIQUE NOT NULL,
    claim_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'settled')),
    
    -- Amounts
    gross_amount NUMERIC(12,2) NOT NULL DEFAULT 0,  -- Total before commission
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 0,  -- Percentage
    commission_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    net_amount NUMERIC(12,2) NOT NULL DEFAULT 0,    -- Amount to claim (after commission)
    
    -- Payment tracking
    paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    balance_amount NUMERIC(12,2) NOT NULL DEFAULT 0,  -- net_amount - paid_amount
    
    -- Metadata
    notes TEXT,
    due_date DATE,
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT claims_amounts_positive CHECK (
        gross_amount >= 0 AND commission_amount >= 0 AND net_amount >= 0 AND
        paid_amount >= 0 AND balance_amount >= 0
    )
);

CREATE INDEX idx_claims_vendor ON consignment_claims (vendor_id);
CREATE INDEX idx_claims_owner ON consignment_claims (business_owner_id);
CREATE INDEX idx_claims_status ON consignment_claims (status);
CREATE INDEX idx_claims_date ON consignment_claims (claim_date DESC);
CREATE INDEX idx_claims_number ON consignment_claims (claim_number);

-- Enable RLS
ALTER TABLE consignment_claims ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY consignment_claims_select_policy ON consignment_claims 
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY consignment_claims_insert_policy ON consignment_claims 
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY consignment_claims_update_policy ON consignment_claims 
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY consignment_claims_delete_policy ON consignment_claims 
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 3: CREATE CONSIGNMENT_CLAIM_ITEMS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS consignment_claim_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_id UUID NOT NULL REFERENCES consignment_claims (id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries (id),
    delivery_item_id UUID NOT NULL REFERENCES vendor_delivery_items (id),
    
    -- Quantities (from delivery items)
    quantity_delivered NUMERIC(12,3) NOT NULL,
    quantity_sold NUMERIC(12,3) NOT NULL,
    quantity_unsold NUMERIC(12,3) NOT NULL,
    quantity_expired NUMERIC(12,3) NOT NULL,
    quantity_damaged NUMERIC(12,3) NOT NULL,
    
    -- Pricing
    unit_price NUMERIC(12,2) NOT NULL,
    gross_amount NUMERIC(12,2) NOT NULL,  -- quantity_sold * unit_price
    commission_rate NUMERIC(5,2) NOT NULL,
    commission_amount NUMERIC(12,2) NOT NULL,
    net_amount NUMERIC(12,2) NOT NULL,   -- gross_amount - commission_amount
    
    -- Payment tracking
    paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    balance_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    carry_forward BOOLEAN NOT NULL DEFAULT FALSE,  -- If item carried to next claim
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT claim_items_amounts_positive CHECK (
        gross_amount >= 0 AND commission_amount >= 0 AND net_amount >= 0 AND
        paid_amount >= 0 AND balance_amount >= 0
    )
);

CREATE INDEX idx_claim_items_claim ON consignment_claim_items (claim_id);
CREATE INDEX idx_claim_items_delivery ON consignment_claim_items (delivery_id);
CREATE INDEX idx_claim_items_delivery_item ON consignment_claim_items (delivery_item_id);

-- Enable RLS
ALTER TABLE consignment_claim_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies (inherit from parent claim)
CREATE POLICY consignment_claim_items_select_policy ON consignment_claim_items 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM consignment_claims 
            WHERE consignment_claims.id = consignment_claim_items.claim_id 
            AND consignment_claims.business_owner_id = auth.uid()
        )
    );

CREATE POLICY consignment_claim_items_insert_policy ON consignment_claim_items 
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM consignment_claims 
            WHERE consignment_claims.id = consignment_claim_items.claim_id 
            AND consignment_claims.business_owner_id = auth.uid()
        )
    );

CREATE POLICY consignment_claim_items_update_policy ON consignment_claim_items 
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM consignment_claims 
            WHERE consignment_claims.id = consignment_claim_items.claim_id 
            AND consignment_claims.business_owner_id = auth.uid()
        )
    );

CREATE POLICY consignment_claim_items_delete_policy ON consignment_claim_items 
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM consignment_claims 
            WHERE consignment_claims.id = consignment_claim_items.claim_id 
            AND consignment_claims.business_owner_id = auth.uid()
        )
    );

-- ============================================================================
-- STEP 4: CREATE CONSIGNMENT_PAYMENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS consignment_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    -- Payment Information
    payment_number TEXT UNIQUE NOT NULL,
    payment_date DATE NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN (
        'bill_to_bill',      -- Settle semua outstanding
        'per_claim',         -- Bayar claim semasa sahaja
        'partial',           -- Bayar separa
        'carry_forward'      -- Tunda ke claim seterusnya
    )),
    
    -- Amounts
    total_amount NUMERIC(12,2) NOT NULL,
    payment_reference TEXT,  -- Bank reference, cheque number, etc.
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT payments_amount_positive CHECK (total_amount > 0)
);

CREATE INDEX idx_payments_vendor ON consignment_payments (vendor_id);
CREATE INDEX idx_payments_owner ON consignment_payments (business_owner_id);
CREATE INDEX idx_payments_date ON consignment_payments (payment_date DESC);
CREATE INDEX idx_payments_method ON consignment_payments (payment_method);
CREATE INDEX idx_payments_number ON consignment_payments (payment_number);

-- Enable RLS
ALTER TABLE consignment_payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY consignment_payments_select_policy ON consignment_payments 
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY consignment_payments_insert_policy ON consignment_payments 
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY consignment_payments_update_policy ON consignment_payments 
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY consignment_payments_delete_policy ON consignment_payments 
    FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 5: CREATE CONSIGNMENT_PAYMENT_ALLOCATIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS consignment_payment_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES consignment_payments (id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES consignment_claims (id),
    claim_item_id UUID REFERENCES consignment_claim_items (id),
    
    -- Allocation amounts
    allocated_amount NUMERIC(12,2) NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT allocations_amount_positive CHECK (allocated_amount > 0)
);

CREATE INDEX idx_allocations_payment ON consignment_payment_allocations (payment_id);
CREATE INDEX idx_allocations_claim ON consignment_payment_allocations (claim_id);
CREATE INDEX idx_allocations_claim_item ON consignment_payment_allocations (claim_item_id);

-- Enable RLS
ALTER TABLE consignment_payment_allocations ENABLE ROW LEVEL SECURITY;

-- RLS Policies (inherit from parent payment)
CREATE POLICY consignment_payment_allocations_select_policy ON consignment_payment_allocations 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM consignment_payments 
            WHERE consignment_payments.id = consignment_payment_allocations.payment_id 
            AND consignment_payments.business_owner_id = auth.uid()
        )
    );

CREATE POLICY consignment_payment_allocations_insert_policy ON consignment_payment_allocations 
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM consignment_payments 
            WHERE consignment_payments.id = consignment_payment_allocations.payment_id 
            AND consignment_payments.business_owner_id = auth.uid()
        )
    );

-- ============================================================================
-- STEP 6: CREATE FUNCTION TO GENERATE CLAIM NUMBER
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_claim_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'CLM';
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_claim_number TEXT;
BEGIN
    -- Get next sequence number for this month
    SELECT COALESCE(MAX(CAST(SUBSTRING(claim_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM consignment_claims
    WHERE claim_number LIKE v_prefix || v_year || v_month || '%';
    
    -- Format: CLM-YYMM-0001
    v_claim_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
    
    RETURN v_claim_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: CREATE FUNCTION TO GENERATE PAYMENT NUMBER
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_payment_number()
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := 'PAY';
    v_year TEXT := TO_CHAR(NOW(), 'YY');
    v_month TEXT := TO_CHAR(NOW(), 'MM');
    v_seq_num INTEGER;
    v_payment_number TEXT;
BEGIN
    -- Get next sequence number for this month
    SELECT COALESCE(MAX(CAST(SUBSTRING(payment_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM consignment_payments
    WHERE payment_number LIKE v_prefix || v_year || v_month || '%';
    
    -- Format: PAY-YYMM-0001
    v_payment_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
    
    RETURN v_payment_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 8: CREATE TRIGGERS FOR AUTO-GENERATED NUMBERS
-- ============================================================================

CREATE OR REPLACE FUNCTION set_claim_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.claim_number IS NULL OR NEW.claim_number = '' THEN
        NEW.claim_number := generate_claim_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_claim_number
    BEFORE INSERT ON consignment_claims
    FOR EACH ROW
    EXECUTE FUNCTION set_claim_number();

CREATE OR REPLACE FUNCTION set_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
        NEW.payment_number := generate_payment_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_payment_number
    BEFORE INSERT ON consignment_payments
    FOR EACH ROW
    EXECUTE FUNCTION set_payment_number();

-- ============================================================================
-- STEP 9: CREATE TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_consignment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_claims_updated_at
    BEFORE UPDATE ON consignment_claims
    FOR EACH ROW
    EXECUTE FUNCTION update_consignment_updated_at();

CREATE TRIGGER trigger_update_claim_items_updated_at
    BEFORE UPDATE ON consignment_claim_items
    FOR EACH ROW
    EXECUTE FUNCTION update_consignment_updated_at();

CREATE TRIGGER trigger_update_payments_updated_at
    BEFORE UPDATE ON consignment_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_consignment_updated_at();

-- ============================================================================
-- STEP 10: CREATE FUNCTION TO UPDATE CLAIM BALANCE AFTER PAYMENT
-- ============================================================================

CREATE OR REPLACE FUNCTION update_claim_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_claim_id UUID;
    v_total_paid NUMERIC(12,2);
    v_net_amount NUMERIC(12,2);
BEGIN
    -- Get claim_id from allocation
    v_claim_id := NEW.claim_id;
    
    -- Calculate total paid for this claim
    SELECT COALESCE(SUM(allocated_amount), 0)
    INTO v_total_paid
    FROM consignment_payment_allocations
    WHERE claim_id = v_claim_id;
    
    -- Get net amount for this claim
    SELECT net_amount
    INTO v_net_amount
    FROM consignment_claims
    WHERE id = v_claim_id;
    
    -- Update claim paid_amount and balance_amount
    UPDATE consignment_claims
    SET 
        paid_amount = v_total_paid,
        balance_amount = v_net_amount - v_total_paid,
        status = CASE 
            WHEN (v_net_amount - v_total_paid) <= 0 THEN 'settled'
            WHEN v_total_paid > 0 THEN 'approved'  -- Keep approved if partially paid
            ELSE status
        END,
        settled_at = CASE 
            WHEN (v_net_amount - v_total_paid) <= 0 THEN NOW()
            ELSE settled_at
        END
    WHERE id = v_claim_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_claim_balance
    AFTER INSERT OR UPDATE OR DELETE ON consignment_payment_allocations
    FOR EACH ROW
    EXECUTE FUNCTION update_claim_balance();

COMMIT;

-- ============================================================================
-- NOTES:
-- 1. Claim status: draft, submitted, approved, rejected, settled
-- 2. Payment methods: bill_to_bill, per_claim, partial, carry_forward
-- 3. Claim number auto-generated (format: CLM-YYMM-0001)
-- 4. Payment number auto-generated (format: PAY-YYMM-0001)
-- 5. Quantities must balance: delivered = sold + unsold + expired + damaged
-- 6. Claim balance auto-updated when payment allocations change
-- ============================================================================

