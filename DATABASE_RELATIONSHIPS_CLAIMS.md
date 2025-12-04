# 🗄️ DATABASE RELATIONSHIPS - CLAIM MODULE

## Table Structure & Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    USERS TABLE                              │
│  ├── id (UUID)                                              │
│  └── business_owner_id references                           │
└─────────────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  VENDORS     │ │ DELIVERIES   │ │    CLAIMS    │
│              │ │              │ │              │
│ id (PK)      │ │ id (PK)      │ │ id (PK)      │
│ name         │ │ vendor_id →  │ │ claim_id →   │
│ commission % │ │ status       │ │ vendor_id →  │
│              │ │ total_amount │ │ status       │
└──────────────┘ │              │ │ net_amount   │
        ↑        │ DELIVERY     │ │              │
        │        │  ITEMS ──────┼─│ CLAIM ITEMS  │
        │        │  (items for) │ │  (link to)   │
        └────────┴──────────────┘ │ delivery_id  │
                        ↓         │  claimed_amt │
                  ┌─────────────┐ └──────────────┘
                  │  PRODUCTS   │         ↓
                  │             │    ┌──────────────┐
                  │ id (PK)     │    │  PAYMENTS    │
                  │ name        │    │              │
                  │ price       │    │ id (PK)      │
                  └─────────────┘    │ vendor_id →  │
                                     │ amount       │
                                     │ claim_ids[]  │
                                     │ (array link) │
                                     └──────────────┘
```

---

## Key Tables & Fields

### 1. `vendor_deliveries` Table
```sql
CREATE TABLE vendor_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id),
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    vendor_name TEXT NOT NULL,
    
    delivery_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'delivered',  -- delivered, pending, claimed, rejected
    payment_status TEXT,  -- pending, partial, settled
    
    total_amount NUMERIC(12,2),
    invoice_number TEXT UNIQUE,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookup
CREATE INDEX idx_vendor_deliveries_vendor ON vendor_deliveries(vendor_id);
CREATE INDEX idx_vendor_deliveries_status ON vendor_deliveries(status);
CREATE INDEX idx_vendor_deliveries_date ON vendor_deliveries(delivery_date);
```

**Purpose:** Store all deliveries sent to vendors

---

### 2. `vendor_delivery_items` Table
```sql
CREATE TABLE vendor_delivery_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    product_name TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    retail_price NUMERIC(12,2),
    
    rejected_qty NUMERIC(12,3) DEFAULT 0,
    rejection_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_vendor_delivery_items_delivery ON vendor_delivery_items(delivery_id);
CREATE INDEX idx_vendor_delivery_items_product ON vendor_delivery_items(product_id);
```

**Purpose:** Store individual items within each delivery

---

### 3. `consignment_claims` Table
```sql
CREATE TABLE consignment_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id),
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    
    claim_number TEXT UNIQUE NOT NULL,  -- CLM-2512-0001
    claim_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',  -- draft, submitted, approved, rejected, settled
    
    -- Financial
    gross_amount NUMERIC(12,2) NOT NULL,  -- Sum of sold items
    commission_rate NUMERIC(5,2) NOT NULL,  -- Vendor's commission %
    commission_amount NUMERIC(12,2) NOT NULL,  -- Calculated commission
    net_amount NUMERIC(12,2) NOT NULL,  -- What to pay (gross - commission)
    paid_amount NUMERIC(12,2) DEFAULT 0,  -- Already paid
    balance_amount NUMERIC(12,2),  -- Still due
    
    notes TEXT,
    
    -- Approval
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    
    -- Payment
    paid_by UUID REFERENCES users(id),
    paid_at TIMESTAMPTZ,
    payment_reference TEXT,
    
    -- Timestamps
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_consignment_claims_vendor ON consignment_claims(vendor_id);
CREATE INDEX idx_consignment_claims_status ON consignment_claims(status);
CREATE INDEX idx_consignment_claims_claim_number ON consignment_claims(claim_number);
```

**Purpose:** Store claims (tuntutan) with financial tracking

---

### 4. `consignment_claim_items` Table
```sql
CREATE TABLE consignment_claim_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_id UUID NOT NULL REFERENCES consignment_claims(id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES vendor_deliveries(id),
    delivery_item_id UUID NOT NULL REFERENCES vendor_delivery_items(id),
    
    product_id UUID NOT NULL REFERENCES products(id),
    product_name TEXT NOT NULL,
    
    -- Quantities
    delivered_qty NUMERIC(12,3) NOT NULL,
    sold_qty NUMERIC(12,3) NOT NULL,
    unsold_qty NUMERIC(12,3),
    expired_qty NUMERIC(12,3),
    damaged_qty NUMERIC(12,3),
    
    -- Pricing
    unit_price NUMERIC(12,2) NOT NULL,
    claimed_amount NUMERIC(12,2) NOT NULL,  -- sold_qty × unit_price
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_consignment_claim_items_claim ON consignment_claim_items(claim_id);
CREATE INDEX idx_consignment_claim_items_delivery ON consignment_claim_items(delivery_id);
```

**Purpose:** Links claims to deliveries (THE CRITICAL LINK!)

---

### 5. `consignment_payments` Table
```sql
CREATE TABLE consignment_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id),
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    
    payment_date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    payment_method TEXT NOT NULL,
    payment_reference TEXT,
    
    claim_ids UUID[] NOT NULL,  -- Array of claim IDs this payment covers
    notes TEXT,
    
    recorded_by UUID NOT NULL REFERENCES users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_consignment_payments_vendor ON consignment_payments(vendor_id);
CREATE INDEX idx_consignment_payments_date ON consignment_payments(payment_date);
```

**Purpose:** Record payments made to vendors

---

## The CRITICAL LINK

### `consignment_claim_items.delivery_id` ← THIS IS THE KEY!

```
vendor_deliveries (Delivery record)
        ↓ (referenced by)
consignment_claim_items (Links delivery to claim)
        ↓ (belongs to)
consignment_claims (Claim record)
        ↓ (paid by)
consignment_payments (Payment record)
```

This single field `delivery_id` in `consignment_claim_items` is what connects:
- **Delivery** to **Claim**
- **Claim** to **Payment**

---

## Query to Find Claimed Deliveries

```sql
-- Get all delivery IDs that have been claimed (not in draft)
SELECT DISTINCT ci.delivery_id
FROM consignment_claim_items ci
JOIN consignment_claims c ON ci.claim_id = c.id
WHERE c.vendor_id = $1
  AND c.business_owner_id = $2
  AND c.status IN ('submitted', 'approved', 'settled', 'rejected');
```

**What this does:**
- Finds all deliveries that have at least one claim
- Excludes draft claims (those can still be edited)
- Returns delivery IDs that are "locked" (cannot claim again)

**Used by:** `getClaimedDeliveryIds(vendorId)` method in repository

---

## Query to Get Claim Details with Delivery Info

```sql
-- Get claim with linked delivery information
SELECT 
    c.id,
    c.claim_number,
    c.status,
    c.net_amount,
    c.balance_amount,
    d.id as delivery_id,
    d.invoice_number,
    d.delivery_date,
    v.name as vendor_name
FROM consignment_claims c
JOIN consignment_claim_items cci ON c.id = cci.claim_id
JOIN vendor_deliveries d ON cci.delivery_id = d.id
JOIN vendors v ON c.vendor_id = v.id
WHERE c.vendor_id = $1
  AND c.status NOT IN ('draft', 'rejected')
ORDER BY c.created_at DESC;
```

**What this returns:**
- Claim information
- Linked delivery details
- Vendor information
- All in one query

**Used by:** Payment page to show which delivery each claim came from

---

## Data Flow Diagram

```
┌─────────────────────────────────────────┐
│  USER CREATES DELIVERY                  │
└─────────────────────────────────────────┘
            ↓
    INSERT INTO vendor_deliveries
    INSERT INTO vendor_delivery_items
            ↓
┌─────────────────────────────────────────┐
│  vendor_deliveries record created       │
│  Status: 'delivered'                    │
│  No claims yet                          │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  USER CREATES CLAIM FROM DELIVERY       │
└─────────────────────────────────────────┘
            ↓
    1. Query: Get claimed delivery IDs
            ↓
    IF delivery_id in claimed_ids:
        THROW EXCEPTION (already claimed)
    ELSE:
        INSERT INTO consignment_claims
        INSERT INTO consignment_claim_items
            (with delivery_id = delivery.id)
            ↓
┌─────────────────────────────────────────┐
│  consignment_claim_items.delivery_id    │
│  = vendor_deliveries.id  ← LINK!        │
│                                          │
│  Now delivery is marked as "CLAIMED"    │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  NEXT TIME: USER TRIES TO CLAIM SAME    │
│  DELIVERY                               │
└─────────────────────────────────────────┘
            ↓
    Query: Get claimed delivery IDs
    Result: [delivery.id] ← FOUND!
            ↓
    IF delivery_id in claimed_ids:
        PREVENT SELECTION ✅ (UI disables checkbox)
        THROW EXCEPTION (if user somehow forces it)
            ↓
┌─────────────────────────────────────────┐
│  DUPLICATE CLAIM PREVENTED!             │
└─────────────────────────────────────────┘
```

---

## Key SQL Functions

### Function: `generate_claim_number()`
```sql
CREATE FUNCTION generate_claim_number() RETURNS TEXT AS $$
DECLARE
    v_year_month TEXT;
    v_counter INT;
BEGIN
    v_year_month := TO_CHAR(NOW(), 'YYMM');
    v_counter := NEXTVAL('consignment_claim_counter');
    RETURN 'CLM-' || v_year_month || '-' || LPAD(v_counter::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;
```

**Generates:** CLM-2512-0001, CLM-2512-0002, etc.

---

## RLS (Row Level Security)

All tables have RLS enabled:

```sql
-- Example for consignment_claims
ALTER TABLE consignment_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User can only see their own claims" ON consignment_claims
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY "User can only create claims for their business" ON consignment_claims
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());
```

**Result:** Each user only sees their own vendor data

---

## Performance Indexes

```sql
-- All delivery lookups
CREATE INDEX idx_vendor_deliveries_vendor ON vendor_deliveries(vendor_id);

-- Status filtering
CREATE INDEX idx_vendor_deliveries_status ON vendor_deliveries(status);

-- Date range queries
CREATE INDEX idx_vendor_deliveries_date ON vendor_deliveries(delivery_date);

-- Claim lookups
CREATE INDEX idx_consignment_claims_vendor ON consignment_claims(vendor_id);

-- Fast status checks
CREATE INDEX idx_consignment_claims_status ON consignment_claims(status);

-- Link finding (critical for duplicate prevention!)
CREATE INDEX idx_consignment_claim_items_delivery ON consignment_claim_items(delivery_id);
```

**Most Important:** `idx_consignment_claim_items_delivery` for finding claimed deliveries quickly

---

## Summary

| Table | Purpose | Key Field |
|-------|---------|-----------|
| `vendor_deliveries` | Deliveries to vendors | `id`, `vendor_id`, `status` |
| `vendor_delivery_items` | Items in each delivery | `delivery_id`, `product_id` |
| `consignment_claims` | Claims/tuntutan | `id`, `claim_number`, `vendor_id`, `status` |
| `consignment_claim_items` | **LINK claims to deliveries** | **`delivery_id` ← KEY!**, `claim_id` |
| `consignment_payments` | Payments to vendors | `vendor_id`, `claim_ids[]` |

**The Magic Link:** `consignment_claim_items.delivery_id` connects everything!

---

**Document:** Database Reference for Claim Module  
**Status:** Ready for reference  
**Last Updated:** December 5, 2025

