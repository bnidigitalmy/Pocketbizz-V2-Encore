# 🏪 Consignment System Design - Tuntutan & Bayaran

## 📋 Overview

Sistem consignment lengkap untuk mengurus **Tuntutan** (Claims) dan **Bayaran** (Payments) antara Consignor (User PocketBizz) dan Consignee (Vendor/Kedai).

---

## 🔄 Business Flow

### Flow 1: Tuntutan (Claims)

```
1. User hantar produk ke Vendor (Delivery)
   ↓
2. Vendor jual produk kepada customer
   ↓
3. Vendor update sales status:
   - Sold quantity
   - Unsold quantity
   - Expired quantity
   - Rosak/Damaged quantity
   ↓
4. User buat TUNTUTAN berdasarkan:
   - Delivery batch(es)
   - Produk yang SOLD sahaja
   - Tolak commission rate
   ↓
5. System generate Claim Invoice
   - Total amount
   - Commission deduction
   - Net amount to claim
```

### Flow 2: Bayaran (Payments)

```
1. User approve Tuntutan
   ↓
2. Vendor buat BAYARAN dengan kaedah:
   a) Bill to Bill (Settle semua outstanding)
   b) Per Claim (Bayar claim semasa sahaja)
   c) Carry Forward (Tunda item ke claim seterusnya)
   d) Partial Payment (Bayar separa)
   ↓
3. System record payment:
   - Payment method
   - Amount paid
   - Items settled
   - Balance carried forward (if any)
   ↓
4. Update claim status & delivery status
```

---

## 🗄️ Database Schema

### 1. `consignment_deliveries` (Enhanced)

```sql
CREATE TABLE IF NOT EXISTS consignment_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    delivery_date DATE NOT NULL,
    delivery_number TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'delivered' CHECK (status IN ('delivered', 'claimed', 'settled', 'cancelled')),
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partial', 'settled')),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    settled_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_deliveries_vendor ON consignment_deliveries (vendor_id);
CREATE INDEX idx_deliveries_owner ON consignment_deliveries (business_owner_id);
CREATE INDEX idx_deliveries_date ON consignment_deliveries (delivery_date);
```

### 2. `consignment_delivery_items`

```sql
CREATE TABLE IF NOT EXISTS consignment_delivery_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES consignment_deliveries (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    quantity_delivered NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    
    -- Sales tracking (updated by vendor)
    quantity_sold NUMERIC(12,3) NOT NULL DEFAULT 0,
    quantity_unsold NUMERIC(12,3) NOT NULL DEFAULT 0,
    quantity_expired NUMERIC(12,3) NOT NULL DEFAULT 0,
    quantity_damaged NUMERIC(12,3) NOT NULL DEFAULT 0,
    
    -- Validation
    CONSTRAINT valid_quantities CHECK (
        quantity_delivered = quantity_sold + quantity_unsold + quantity_expired + quantity_damaged
    ),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_delivery_items_delivery ON consignment_delivery_items (delivery_id);
CREATE INDEX idx_delivery_items_product ON consignment_delivery_items (product_id);
```

### 3. `consignment_claims` (NEW)

```sql
CREATE TABLE IF NOT EXISTS consignment_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
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
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claims_vendor ON consignment_claims (vendor_id);
CREATE INDEX idx_claims_owner ON consignment_claims (business_owner_id);
CREATE INDEX idx_claims_status ON consignment_claims (status);
CREATE INDEX idx_claims_date ON consignment_claims (claim_date);
```

### 4. `consignment_claim_items` (NEW)

```sql
CREATE TABLE IF NOT EXISTS consignment_claim_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_id UUID NOT NULL REFERENCES consignment_claims (id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES consignment_deliveries (id),
    delivery_item_id UUID NOT NULL REFERENCES consignment_delivery_items (id),
    
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
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claim_items_claim ON consignment_claim_items (claim_id);
CREATE INDEX idx_claim_items_delivery ON consignment_claim_items (delivery_id);
```

### 5. `consignment_payments` (NEW)

```sql
CREATE TABLE IF NOT EXISTS consignment_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
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
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_vendor ON consignment_payments (vendor_id);
CREATE INDEX idx_payments_owner ON consignment_payments (business_owner_id);
CREATE INDEX idx_payments_date ON consignment_payments (payment_date);
```

### 6. `consignment_payment_allocations` (NEW)

```sql
CREATE TABLE IF NOT EXISTS consignment_payment_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES consignment_payments (id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES consignment_claims (id),
    claim_item_id UUID REFERENCES consignment_claim_items (id),
    
    -- Allocation amounts
    allocated_amount NUMERIC(12,2) NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_allocations_payment ON consignment_payment_allocations (payment_id);
CREATE INDEX idx_allocations_claim ON consignment_payment_allocations (claim_id);
```

---

## 🎯 Payment Methods Explained

### 1. **Bill to Bill** (Settle Semua Outstanding)

**Description:** Vendor bayar semua outstanding claims sekaligus.

**Flow:**
```
1. User select multiple claims
2. System calculate total outstanding
3. Vendor bayar total amount
4. All selected claims marked as "settled"
5. All delivery items marked as "paid"
```

**Use Case:** Vendor nak settle semua hutang sekali gus.

---

### 2. **Per Claim** (Bayar Claim Semasa Sahaja)

**Description:** Vendor bayar untuk satu claim tertentu sahaja.

**Flow:**
```
1. User select ONE claim
2. System show claim net amount
3. Vendor bayar exact amount
4. Only this claim marked as "settled"
5. Other claims remain outstanding
```

**Use Case:** Vendor bayar mengikut claim yang baru approve.

---

### 3. **Carry Forward** (Tunda Item)

**Description:** Vendor tunda bayaran untuk item tertentu ke claim seterusnya.

**Flow:**
```
1. User create new claim
2. Select items to include
3. Mark some items as "carry forward"
4. System:
   - Include carried items in new claim
   - Keep old claim with balance
   - Link items between claims
```

**Use Case:** 
- Item belum ready untuk claim
- Vendor minta tunda bayaran untuk item tertentu
- Item perlu adjustment

---

### 4. **Partial Payment** (Bayar Separa)

**Description:** Vendor bayar separa amount untuk claim.

**Flow:**
```
1. User select claim
2. Vendor bayar less than net amount
3. System:
   - Record partial payment
   - Update claim balance
   - Mark claim as "partial"
   - Keep items as "partially paid"
```

**Use Case:** Vendor bayar separa kerana cash flow issues.

---

## 🔌 API Endpoints Design

### Claims Service

```typescript
// Create claim from deliveries
POST /claims/create
Body: {
  vendorId: string;
  deliveryIds: string[];  // Multiple deliveries
  claimDate: string;
  notes?: string;
}

// Submit claim for approval
POST /claims/:id/submit

// Approve claim
POST /claims/:id/approve

// Reject claim
POST /claims/:id/reject
Body: {
  reason: string;
}

// List claims
GET /claims?vendorId=&status=&fromDate=&toDate=

// Get claim details
GET /claims/:id

// Update delivery item quantities (sold/unsold/expired/damaged)
PUT /claims/:id/items/:itemId/quantities
Body: {
  quantitySold: number;
  quantityUnsold: number;
  quantityExpired: number;
  quantityDamaged: number;
}
```

### Payments Service

```typescript
// Create payment
POST /payments/create
Body: {
  vendorId: string;
  paymentMethod: 'bill_to_bill' | 'per_claim' | 'partial' | 'carry_forward';
  paymentDate: string;
  totalAmount: number;
  claimIds?: string[];  // For bill_to_bill
  claimId?: string;     // For per_claim
  claimItemIds?: string[];  // For carry_forward
  paymentReference?: string;
  notes?: string;
}

// Allocate payment to claims
POST /payments/:id/allocate
Body: {
  allocations: [{
    claimId: string;
    claimItemId?: string;
    amount: number;
  }]
}

// List payments
GET /payments?vendorId=&fromDate=&toDate=

// Get payment details
GET /payments/:id

// Get outstanding balance for vendor
GET /payments/outstanding/:vendorId
```

---

## 📱 UI/UX Flow

### Screen 1: Claims List Page

**Features:**
- List semua claims dengan status
- Filter by vendor, status, date range
- Summary cards:
  - Total Outstanding
  - Pending Claims
  - Overdue Claims
- Actions:
  - Create New Claim
  - View Details
  - Export

**Status Badges:**
- Draft (Gray)
- Submitted (Blue)
- Approved (Green)
- Rejected (Red)
- Settled (Dark Green)

---

### Screen 2: Create Claim Page

**Step 1: Select Deliveries**
- List deliveries untuk vendor
- Checkbox untuk select multiple
- Show delivery details (date, items, amount)
- Filter by date range

**Step 2: Review Items**
- List semua items dari selected deliveries
- Show quantities:
  - Delivered
  - Sold (editable)
  - Unsold (editable)
  - Expired (editable)
  - Damaged (editable)
- Auto-calculate:
  - Gross amount (sold * price)
  - Commission
  - Net amount

**Step 3: Confirm & Submit**
- Summary of claim
- Total amounts
- Submit button

---

### Screen 3: Claim Details Page

**Sections:**
1. **Header:**
   - Claim number
   - Vendor name
   - Status badge
   - Dates

2. **Amounts Summary:**
   - Gross Amount
   - Commission (-)
   - Net Amount
   - Paid Amount
   - Balance

3. **Items Table:**
   - Product name
   - Quantities (delivered, sold, unsold, expired, damaged)
   - Unit price
   - Gross amount
   - Commission
   - Net amount
   - Status (paid/outstanding)

4. **Actions:**
   - Edit Quantities
   - Approve/Reject
   - Generate Invoice
   - Record Payment

---

### Screen 4: Payment Page

**Step 1: Select Payment Method**
- Radio buttons:
  - Bill to Bill
  - Per Claim
  - Partial Payment
  - Carry Forward

**Step 2: Select Claims/Items**
- **Bill to Bill:** Select multiple claims
- **Per Claim:** Select one claim
- **Partial:** Select claim + enter amount
- **Carry Forward:** Select items to carry

**Step 3: Enter Payment Details**
- Payment date
- Amount (auto-calculated or manual)
- Payment reference
- Notes

**Step 4: Confirm & Record**
- Summary
- Allocation breakdown
- Confirm button

---

### Screen 5: Payment History

**Features:**
- List semua payments
- Filter by vendor, method, date
- Payment details:
  - Payment number
  - Date
  - Method
  - Amount
  - Allocated to claims
- View allocation details

---

## 💡 Key Features

### 1. **Auto-Calculation**

```typescript
// Calculate claim amounts
function calculateClaimAmounts(items: ClaimItem[], commissionRate: number) {
  let grossAmount = 0;
  
  items.forEach(item => {
    const itemGross = item.quantitySold * item.unitPrice;
    grossAmount += itemGross;
    
    item.grossAmount = itemGross;
    item.commissionAmount = itemGross * (commissionRate / 100);
    item.netAmount = itemGross - item.commissionAmount;
  });
  
  const totalCommission = grossAmount * (commissionRate / 100);
  const netAmount = grossAmount - totalCommission;
  
  return {
    grossAmount,
    commissionAmount: totalCommission,
    netAmount
  };
}
```

### 2. **Payment Allocation**

```typescript
// Allocate payment to claims
function allocatePayment(
  payment: Payment,
  claims: Claim[],
  method: PaymentMethod
) {
  switch (method) {
    case 'bill_to_bill':
      // Allocate to all selected claims proportionally
      return allocateToMultipleClaims(payment, claims);
      
    case 'per_claim':
      // Allocate to single claim
      return allocateToSingleClaim(payment, claims[0]);
      
    case 'partial':
      // Allocate partial amount
      return allocatePartial(payment, claims[0]);
      
    case 'carry_forward':
      // Mark items as carry forward
      return markCarryForward(claims, payment.claimItemIds);
  }
}
```

### 3. **Validation Rules**

- ✅ Quantities must balance: `delivered = sold + unsold + expired + damaged`
- ✅ Commission rate must be set for vendor
- ✅ Payment amount cannot exceed outstanding balance
- ✅ Claim must be approved before payment
- ✅ Delivery items must be claimed before payment

---

## 📊 Reports & Analytics

### 1. **Outstanding Claims Report**
- List semua claims yang belum settle
- Group by vendor
- Show overdue claims

### 2. **Payment Summary**
- Total payments by period
- Payment methods breakdown
- Vendor payment history

### 3. **Commission Report**
- Total commission by vendor
- Commission by product
- Commission trends

---

## 🚀 Implementation Priority

### Phase 1: Core Claims (P1)
- ✅ Database schema
- ✅ Create claim from deliveries
- ✅ Update quantities
- ✅ Calculate amounts
- ✅ Claim approval workflow

### Phase 2: Basic Payments (P1)
- ✅ Record payment
- ✅ Per claim payment
- ✅ Payment allocation
- ✅ Update claim status

### Phase 3: Advanced Payments (P2)
- ✅ Bill to bill
- ✅ Partial payment
- ✅ Carry forward
- ✅ Payment history

### Phase 4: Reports & Analytics (P2)
- ✅ Outstanding reports
- ✅ Payment summaries
- ✅ Commission reports

---

## 📝 Notes

1. **Commission Rate:** Stored in `vendors` table, can be per-vendor or per-product
2. **Validation:** Always validate quantities balance before claim submission
3. **Audit Trail:** Track all changes to claims and payments
4. **Notifications:** Notify vendor when claim submitted/approved
5. **Export:** Generate PDF invoices and payment receipts

---

**Selamat membina sistem consignment yang lengkap!** 🎉



