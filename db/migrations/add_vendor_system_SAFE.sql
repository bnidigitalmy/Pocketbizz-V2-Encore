-- ============================================================================
-- VENDOR/SUPPLIER SYSTEM - SAFE INSTALLATION
-- This version handles existing tables gracefully
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: DROP EXISTING TABLES (if any)
-- ============================================================================
DROP TABLE IF EXISTS vendor_payments CASCADE;
DROP TABLE IF EXISTS vendor_claim_items CASCADE;
DROP TABLE IF EXISTS vendor_claims CASCADE;
DROP TABLE IF EXISTS vendor_products CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS generate_claim_number();
DROP FUNCTION IF EXISTS generate_payment_number();
DROP FUNCTION IF EXISTS create_vendor_claim(UUID, UUID, JSONB, TEXT, TEXT);
DROP FUNCTION IF EXISTS update_claim_status(UUID, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS record_vendor_payment(UUID, UUID, NUMERIC, TEXT, UUID[], TEXT, TEXT);

-- ============================================================================
-- STEP 2: CREATE VENDORS TABLE
-- ============================================================================
CREATE TABLE vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    
    -- Vendor Information
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    
    -- Commission Settings
    default_commission_rate NUMERIC(5,2) DEFAULT 0.00,
    
    -- Bank Details (for payment)
    bank_name TEXT,
    bank_account_number TEXT,
    bank_account_holder TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Notes
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendors_commission_valid CHECK (default_commission_rate >= 0 AND default_commission_rate <= 100)
);

CREATE INDEX idx_vendors_business_owner ON vendors (business_owner_id);
CREATE INDEX idx_vendors_active ON vendors (business_owner_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_vendors_email ON vendors (email);

ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendors_select_policy ON vendors FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY vendors_insert_policy ON vendors FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY vendors_update_policy ON vendors FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY vendors_delete_policy ON vendors FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 3: CREATE VENDOR_PRODUCTS TABLE
-- ============================================================================
CREATE TABLE vendor_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    commission_rate NUMERIC(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_products_unique UNIQUE (vendor_id, product_id),
    CONSTRAINT vendor_products_commission_valid CHECK (commission_rate IS NULL OR (commission_rate >= 0 AND commission_rate <= 100))
);

CREATE INDEX idx_vendor_products_vendor ON vendor_products (vendor_id);
CREATE INDEX idx_vendor_products_product ON vendor_products (product_id);
CREATE INDEX idx_vendor_products_business_owner ON vendor_products (business_owner_id);

ALTER TABLE vendor_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_products_select_policy ON vendor_products FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY vendor_products_insert_policy ON vendor_products FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY vendor_products_update_policy ON vendor_products FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY vendor_products_delete_policy ON vendor_products FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 4: CREATE VENDOR_CLAIMS TABLE
-- ============================================================================
CREATE TABLE vendor_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    claim_number TEXT UNIQUE NOT NULL,
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    status TEXT NOT NULL DEFAULT 'pending',
    
    total_sales_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_commission NUMERIC(12,2) NOT NULL DEFAULT 0,
    
    proof_url TEXT,
    vendor_notes TEXT,
    admin_notes TEXT,
    
    reviewed_by UUID REFERENCES users (id),
    reviewed_at TIMESTAMPTZ,
    
    paid_by UUID REFERENCES users (id),
    paid_at TIMESTAMPTZ,
    payment_reference TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_claims_status_valid CHECK (status IN ('pending', 'approved', 'rejected', 'paid')),
    CONSTRAINT vendor_claims_amounts_positive CHECK (total_sales_amount >= 0 AND total_commission >= 0)
);

CREATE INDEX idx_vendor_claims_vendor ON vendor_claims (vendor_id);
CREATE INDEX idx_vendor_claims_business_owner ON vendor_claims (business_owner_id);
CREATE INDEX idx_vendor_claims_status ON vendor_claims (status);
CREATE INDEX idx_vendor_claims_date ON vendor_claims (claim_date DESC);

ALTER TABLE vendor_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_claims_select_policy ON vendor_claims FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY vendor_claims_insert_policy ON vendor_claims FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY vendor_claims_update_policy ON vendor_claims FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY vendor_claims_delete_policy ON vendor_claims FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 5: CREATE VENDOR_CLAIM_ITEMS TABLE
-- ============================================================================
CREATE TABLE vendor_claim_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES vendor_claims (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    quantity NUMERIC(12,2) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    
    commission_rate NUMERIC(5,2) NOT NULL,
    commission_amount NUMERIC(12,2) NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_claim_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT vendor_claim_items_amounts_positive CHECK (unit_price >= 0 AND total_amount >= 0 AND commission_amount >= 0)
);

CREATE INDEX idx_vendor_claim_items_claim ON vendor_claim_items (claim_id);
CREATE INDEX idx_vendor_claim_items_product ON vendor_claim_items (product_id);
CREATE INDEX idx_vendor_claim_items_business_owner ON vendor_claim_items (business_owner_id);

ALTER TABLE vendor_claim_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_claim_items_select_policy ON vendor_claim_items FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY vendor_claim_items_insert_policy ON vendor_claim_items FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY vendor_claim_items_update_policy ON vendor_claim_items FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY vendor_claim_items_delete_policy ON vendor_claim_items FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 6: CREATE VENDOR_PAYMENTS TABLE
-- ============================================================================
CREATE TABLE vendor_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    payment_number TEXT UNIQUE NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    amount NUMERIC(12,2) NOT NULL,
    
    payment_method TEXT NOT NULL,
    payment_reference TEXT,
    
    claim_ids UUID[],
    
    notes TEXT,
    
    created_by UUID REFERENCES users (id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_payments_amount_positive CHECK (amount > 0)
);

CREATE INDEX idx_vendor_payments_vendor ON vendor_payments (vendor_id);
CREATE INDEX idx_vendor_payments_business_owner ON vendor_payments (business_owner_id);
CREATE INDEX idx_vendor_payments_date ON vendor_payments (payment_date DESC);

ALTER TABLE vendor_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_payments_select_policy ON vendor_payments FOR SELECT USING (business_owner_id = auth.uid());
CREATE POLICY vendor_payments_insert_policy ON vendor_payments FOR INSERT WITH CHECK (business_owner_id = auth.uid());
CREATE POLICY vendor_payments_update_policy ON vendor_payments FOR UPDATE USING (business_owner_id = auth.uid());
CREATE POLICY vendor_payments_delete_policy ON vendor_payments FOR DELETE USING (business_owner_id = auth.uid());

-- ============================================================================
-- STEP 7: CREATE FUNCTIONS
-- ============================================================================

-- Generate unique claim number
CREATE OR REPLACE FUNCTION generate_claim_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
    counter INTEGER := 1;
    date_part TEXT;
BEGIN
    date_part := TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    LOOP
        new_number := 'CLAIM-' || date_part || '-' || LPAD(counter::TEXT, 4, '0');
        
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM vendor_claims WHERE claim_number = new_number
        );
        
        counter := counter + 1;
    END LOOP;
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Generate unique payment number
CREATE OR REPLACE FUNCTION generate_payment_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
    counter INTEGER := 1;
    date_part TEXT;
BEGIN
    date_part := TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    LOOP
        new_number := 'PAY-' || date_part || '-' || LPAD(counter::TEXT, 4, '0');
        
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM vendor_payments WHERE payment_number = new_number
        );
        
        counter := counter + 1;
    END LOOP;
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Create vendor claim with items
CREATE OR REPLACE FUNCTION create_vendor_claim(
    p_business_owner_id UUID,
    p_vendor_id UUID,
    p_claim_items JSONB,
    p_vendor_notes TEXT DEFAULT NULL,
    p_proof_url TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_claim_id UUID;
    v_claim_number TEXT;
    v_item JSONB;
    v_commission_rate NUMERIC;
    v_total_amount NUMERIC;
    v_commission_amount NUMERIC;
    v_total_sales NUMERIC := 0;
    v_total_commission NUMERIC := 0;
BEGIN
    v_claim_number := generate_claim_number();
    
    INSERT INTO vendor_claims (
        business_owner_id, vendor_id, claim_number,
        vendor_notes, proof_url
    ) VALUES (
        p_business_owner_id, p_vendor_id, v_claim_number,
        p_vendor_notes, p_proof_url
    ) RETURNING id INTO v_claim_id;
    
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_claim_items)
    LOOP
        SELECT COALESCE(vp.commission_rate, v.default_commission_rate, 0)
        INTO v_commission_rate
        FROM vendors v
        LEFT JOIN vendor_products vp ON vp.vendor_id = v.id 
            AND vp.product_id = (v_item->>'product_id')::UUID
        WHERE v.id = p_vendor_id;
        
        v_total_amount := (v_item->>'quantity')::NUMERIC * (v_item->>'unit_price')::NUMERIC;
        v_commission_amount := v_total_amount * (v_commission_rate / 100);
        
        INSERT INTO vendor_claim_items (
            business_owner_id, claim_id, product_id,
            quantity, unit_price, total_amount,
            commission_rate, commission_amount
        ) VALUES (
            p_business_owner_id, v_claim_id, (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::NUMERIC, (v_item->>'unit_price')::NUMERIC, v_total_amount,
            v_commission_rate, v_commission_amount
        );
        
        v_total_sales := v_total_sales + v_total_amount;
        v_total_commission := v_total_commission + v_commission_amount;
    END LOOP;
    
    UPDATE vendor_claims
    SET 
        total_sales_amount = v_total_sales,
        total_commission = v_total_commission,
        updated_at = NOW()
    WHERE id = v_claim_id;
    
    RETURN v_claim_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update claim status
CREATE OR REPLACE FUNCTION update_claim_status(
    p_claim_id UUID,
    p_status TEXT,
    p_admin_notes TEXT DEFAULT NULL,
    p_reviewed_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE vendor_claims
    SET 
        status = p_status,
        admin_notes = p_admin_notes,
        reviewed_by = COALESCE(p_reviewed_by, auth.uid()),
        reviewed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_claim_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record vendor payment
CREATE OR REPLACE FUNCTION record_vendor_payment(
    p_business_owner_id UUID,
    p_vendor_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_claim_ids UUID[],
    p_payment_reference TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
    v_payment_number TEXT;
    v_claim_id UUID;
BEGIN
    v_payment_number := generate_payment_number();
    
    INSERT INTO vendor_payments (
        business_owner_id, vendor_id, payment_number,
        amount, payment_method, payment_reference,
        claim_ids, notes, created_by
    ) VALUES (
        p_business_owner_id, p_vendor_id, v_payment_number,
        p_amount, p_payment_method, p_payment_reference,
        p_claim_ids, p_notes, auth.uid()
    ) RETURNING id INTO v_payment_id;
    
    FOREACH v_claim_id IN ARRAY p_claim_ids
    LOOP
        UPDATE vendor_claims
        SET 
            status = 'paid',
            paid_by = auth.uid(),
            paid_at = NOW(),
            payment_reference = v_payment_number,
            updated_at = NOW()
        WHERE id = v_claim_id;
    END LOOP;
    
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 8: ADD COMMENTS
-- ============================================================================
COMMENT ON TABLE vendors IS 'Vendors/suppliers who sell products on consignment';
COMMENT ON TABLE vendor_products IS 'Products assigned to specific vendors';
COMMENT ON TABLE vendor_claims IS 'Sales claims submitted by vendors';
COMMENT ON TABLE vendor_claim_items IS 'Individual products in a vendor claim';
COMMENT ON TABLE vendor_payments IS 'Payments made to vendors';

COMMIT;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ VENDOR SYSTEM INSTALLED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created 5 tables';
    RAISE NOTICE '✅ Created 5 functions';
    RAISE NOTICE '✅ Created RLS policies';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Ready to use!';
    RAISE NOTICE '';
END $$;

