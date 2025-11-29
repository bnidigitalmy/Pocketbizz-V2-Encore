-- ============================================================================
-- VENDOR/SUPPLIER SYSTEM - COMPLETE IMPLEMENTATION
-- Based on old repo pattern for consignment/dropship businesses
-- ============================================================================

-- ============================================================================
-- VENDORS TABLE - Store vendor/supplier information
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    
    -- Vendor Information
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    
    -- Commission Settings
    default_commission_rate NUMERIC(5,2) DEFAULT 0.00, -- Percentage (e.g., 15.50 = 15.5%)
    
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendors_business_owner ON vendors (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_vendors_active ON vendors (business_owner_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_vendors_email ON vendors (email);

-- RLS Policies
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendors_select_policy ON vendors
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY vendors_insert_policy ON vendors
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendors_update_policy ON vendors
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY vendors_delete_policy ON vendors
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- VENDOR_PRODUCTS TABLE - Link vendors to specific products
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendor_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    -- Override commission rate for specific product (optional)
    commission_rate NUMERIC(5,2), -- If NULL, use vendor's default_commission_rate
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint: one vendor per product
    CONSTRAINT vendor_products_unique UNIQUE (vendor_id, product_id),
    CONSTRAINT vendor_products_commission_valid CHECK (commission_rate IS NULL OR (commission_rate >= 0 AND commission_rate <= 100))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendor_products_vendor ON vendor_products (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_products_product ON vendor_products (product_id);
CREATE INDEX IF NOT EXISTS idx_vendor_products_business_owner ON vendor_products (business_owner_id);

-- RLS Policies
ALTER TABLE vendor_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_products_select_policy ON vendor_products
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_products_insert_policy ON vendor_products
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_products_update_policy ON vendor_products
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_products_delete_policy ON vendor_products
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- VENDOR_CLAIMS TABLE - Track sales claims submitted by vendors
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendor_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    -- Claim Details
    claim_number TEXT UNIQUE NOT NULL, -- Auto-generated: CLAIM-YYYYMMDD-XXXX
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Status
    status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected, paid
    
    -- Amounts
    total_sales_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_commission NUMERIC(12,2) NOT NULL DEFAULT 0,
    
    -- Proof of Sale
    proof_url TEXT, -- Receipt/invoice image URL (Supabase Storage)
    
    -- Notes
    vendor_notes TEXT, -- Vendor's notes when submitting
    admin_notes TEXT,  -- Admin's notes when reviewing
    
    -- Review Info
    reviewed_by UUID REFERENCES users (id),
    reviewed_at TIMESTAMPTZ,
    
    -- Payment Info
    paid_by UUID REFERENCES users (id),
    paid_at TIMESTAMPTZ,
    payment_reference TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_claims_status_valid CHECK (status IN ('pending', 'approved', 'rejected', 'paid')),
    CONSTRAINT vendor_claims_amounts_positive CHECK (total_sales_amount >= 0 AND total_commission >= 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendor_claims_vendor ON vendor_claims (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_claims_business_owner ON vendor_claims (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_vendor_claims_status ON vendor_claims (status);
CREATE INDEX IF NOT EXISTS idx_vendor_claims_date ON vendor_claims (claim_date DESC);

-- RLS Policies
ALTER TABLE vendor_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_claims_select_policy ON vendor_claims
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_claims_insert_policy ON vendor_claims
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_claims_update_policy ON vendor_claims
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_claims_delete_policy ON vendor_claims
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- VENDOR_CLAIM_ITEMS TABLE - Individual products in a claim
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendor_claim_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES vendor_claims (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    
    -- Sale Details
    quantity NUMERIC(12,2) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL, -- quantity * unit_price
    
    -- Commission
    commission_rate NUMERIC(5,2) NOT NULL,
    commission_amount NUMERIC(12,2) NOT NULL, -- total_amount * (commission_rate / 100)
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_claim_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT vendor_claim_items_amounts_positive CHECK (unit_price >= 0 AND total_amount >= 0 AND commission_amount >= 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendor_claim_items_claim ON vendor_claim_items (claim_id);
CREATE INDEX IF NOT EXISTS idx_vendor_claim_items_product ON vendor_claim_items (product_id);
CREATE INDEX IF NOT EXISTS idx_vendor_claim_items_business_owner ON vendor_claim_items (business_owner_id);

-- RLS Policies
ALTER TABLE vendor_claim_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_claim_items_select_policy ON vendor_claim_items
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_claim_items_insert_policy ON vendor_claim_items
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_claim_items_update_policy ON vendor_claim_items
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_claim_items_delete_policy ON vendor_claim_items
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- VENDOR_PAYMENTS TABLE - Track payments made to vendors
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendor_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    
    -- Payment Details
    payment_number TEXT UNIQUE NOT NULL, -- Auto-generated: PAY-YYYYMMDD-XXXX
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Amount
    amount NUMERIC(12,2) NOT NULL,
    
    -- Payment Method
    payment_method TEXT NOT NULL, -- cash, bank_transfer, cheque, etc.
    payment_reference TEXT, -- Bank reference, cheque number, etc.
    
    -- Related Claims (array of claim IDs)
    claim_ids UUID[], -- Which claims are paid with this payment
    
    -- Notes
    notes TEXT,
    
    -- Created by
    created_by UUID REFERENCES users (id),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT vendor_payments_amount_positive CHECK (amount > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendor_payments_vendor ON vendor_payments (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_business_owner ON vendor_payments (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_date ON vendor_payments (payment_date DESC);

-- RLS Policies
ALTER TABLE vendor_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY vendor_payments_select_policy ON vendor_payments
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_payments_insert_policy ON vendor_payments
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY vendor_payments_update_policy ON vendor_payments
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY vendor_payments_delete_policy ON vendor_payments
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- ============================================================================
-- FUNCTION: Generate unique claim number
-- ============================================================================
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

-- ============================================================================
-- FUNCTION: Generate unique payment number
-- ============================================================================
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

-- ============================================================================
-- FUNCTION: Create vendor claim with items
-- ============================================================================
CREATE OR REPLACE FUNCTION create_vendor_claim(
    p_business_owner_id UUID,
    p_vendor_id UUID,
    p_claim_items JSONB, -- Array of {product_id, quantity, unit_price}
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
    -- Generate claim number
    v_claim_number := generate_claim_number();
    
    -- Create claim
    INSERT INTO vendor_claims (
        business_owner_id, vendor_id, claim_number,
        vendor_notes, proof_url
    ) VALUES (
        p_business_owner_id, p_vendor_id, v_claim_number,
        p_vendor_notes, p_proof_url
    ) RETURNING id INTO v_claim_id;
    
    -- Process each item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_claim_items)
    LOOP
        -- Get commission rate (product-specific or vendor default)
        SELECT COALESCE(vp.commission_rate, v.default_commission_rate, 0)
        INTO v_commission_rate
        FROM vendors v
        LEFT JOIN vendor_products vp ON vp.vendor_id = v.id 
            AND vp.product_id = (v_item->>'product_id')::UUID
        WHERE v.id = p_vendor_id;
        
        -- Calculate amounts
        v_total_amount := (v_item->>'quantity')::NUMERIC * (v_item->>'unit_price')::NUMERIC;
        v_commission_amount := v_total_amount * (v_commission_rate / 100);
        
        -- Insert claim item
        INSERT INTO vendor_claim_items (
            business_owner_id, claim_id, product_id,
            quantity, unit_price, total_amount,
            commission_rate, commission_amount
        ) VALUES (
            p_business_owner_id, v_claim_id, (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::NUMERIC, (v_item->>'unit_price')::NUMERIC, v_total_amount,
            v_commission_rate, v_commission_amount
        );
        
        -- Accumulate totals
        v_total_sales := v_total_sales + v_total_amount;
        v_total_commission := v_total_commission + v_commission_amount;
    END LOOP;
    
    -- Update claim totals
    UPDATE vendor_claims
    SET 
        total_sales_amount = v_total_sales,
        total_commission = v_total_commission,
        updated_at = NOW()
    WHERE id = v_claim_id;
    
    RETURN v_claim_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Approve/Reject vendor claim
-- ============================================================================
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

-- ============================================================================
-- FUNCTION: Record vendor payment
-- ============================================================================
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
    -- Generate payment number
    v_payment_number := generate_payment_number();
    
    -- Create payment record
    INSERT INTO vendor_payments (
        business_owner_id, vendor_id, payment_number,
        amount, payment_method, payment_reference,
        claim_ids, notes, created_by
    ) VALUES (
        p_business_owner_id, p_vendor_id, v_payment_number,
        p_amount, p_payment_method, p_payment_reference,
        p_claim_ids, p_notes, auth.uid()
    ) RETURNING id INTO v_payment_id;
    
    -- Update related claims status to 'paid'
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
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE vendors IS 'Vendors/suppliers who sell products on consignment';
COMMENT ON TABLE vendor_products IS 'Products assigned to specific vendors';
COMMENT ON TABLE vendor_claims IS 'Sales claims submitted by vendors';
COMMENT ON TABLE vendor_claim_items IS 'Individual products in a vendor claim';
COMMENT ON TABLE vendor_payments IS 'Payments made to vendors';

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ VENDOR SYSTEM - COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created: vendors table';
    RAISE NOTICE '✅ Created: vendor_products table';
    RAISE NOTICE '✅ Created: vendor_claims table';
    RAISE NOTICE '✅ Created: vendor_claim_items table';
    RAISE NOTICE '✅ Created: vendor_payments table';
    RAISE NOTICE '✅ Created: Helper functions';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT: Build Flutter models & UI';
    RAISE NOTICE '';
END $$;

