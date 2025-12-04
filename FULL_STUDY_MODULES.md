# 📚 FULL STUDY - VENDOR, DELIVERY & CLAIM MODULES

**Date:** December 5, 2025  
**Project:** PocketBizz Flutter App  
**Study Level:** Comprehensive (Complete Implementation Details)

---

## 🎯 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Module 1: Vendor Module](#module-1-vendor-module)
3. [Module 2: Delivery Module](#module-2-delivery-module)
4. [Module 3: Claim Module](#module-3-claim-module)
5. [Integration Flow](#integration-flow)
6. [Database Schema](#database-schema)
7. [API Endpoints](#api-endpoints)
8. [Implementation Guide](#implementation-guide)
9. [Testing Strategy](#testing-strategy)
10. [Future Enhancements](#future-enhancements)

---

## 📖 OVERVIEW

This PocketBizz app uses a **Consignment System** where:

```
┌─────────────────────────────────────────────┐
│                 CONSIGNMENT FLOW             │
├─────────────────────────────────────────────┤
│                                             │
│  Business Owner (Consignor)                 │
│      ↓                                      │
│  [1] Add Vendor (Kedai)                     │
│      ↓                                      │
│  [2] Send Products (Delivery)               │
│      ↓                                      │
│  Vendor (Consignee) sells products          │
│      ↓                                      │
│  [3] Owner creates Claim based on sales     │
│      ↓                                      │
│  [4] Owner pays vendor based on claim       │
│      ↓                                      │
│  Commission calculated & tracked           │
│                                             │
└─────────────────────────────────────────────┘
```

**Key Concepts:**
- **Vendor (Consignee):** Kedai/reseller yang jual produk kami dengan commission
- **Delivery:** Penghantaran produk dari owner ke vendor
- **Claim:** Tuntutan bayaran based on sold products
- **Commission:** Peratusan yang vendor dapat untuk setiap penjualan

---

## MODULE 1: VENDOR MODULE

### 1.1 PURPOSE

Manage vendors/resellers yang menjual produk dengan sistem commission (dropship/consignment)

### 1.2 KEY FEATURES

#### ✅ Implemented Features:
1. **Add/Edit/Delete Vendors**
   - Basic information (name, email, phone, address)
   - Commission settings (percentage or price-range based)
   - Bank details for payment tracking
   - Status management (active/inactive)

2. **Product Assignment**
   - Assign specific products to vendors
   - Override commission rate per product (optional)
   - Track which products each vendor sells

3. **Financial Tracking**
   - Total sales amount
   - Total commission earned
   - Amount paid
   - Outstanding balance
   - Payment history

4. **Notifications**
   - Pending claims count
   - Overdue payment tracking
   - Status updates

### 1.3 DATABASE SCHEMA

#### Main Table: `vendors`
```sql
CREATE TABLE vendors (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    
    -- Vendor Information
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    
    -- Commission Settings
    commission_type TEXT ('percentage' | 'price_range'),
    default_commission_rate NUMERIC(5,2),
    
    -- Bank Details
    bank_name TEXT,
    bank_account_number TEXT,
    bank_account_holder TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_vendors_business_owner ON vendors(business_owner_id);
CREATE INDEX idx_vendors_active ON vendors(business_owner_id, is_active);
```

#### Related Table: `vendor_products`
```sql
CREATE TABLE vendor_products (
    id UUID PRIMARY KEY,
    vendor_id UUID → vendors(id),
    product_id UUID → products(id),
    business_owner_id UUID → users(id),
    
    -- Optional override
    commission_rate NUMERIC(5,2), -- NULL means use vendor default
    
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_vendor_products_vendor ON vendor_products(vendor_id);
CREATE INDEX idx_vendor_products_product ON vendor_products(product_id);
```

#### Related Table: `vendor_commission_price_ranges`
```sql
CREATE TABLE vendor_commission_price_ranges (
    id UUID PRIMARY KEY,
    vendor_id UUID → vendors(id),
    
    -- Price Range
    min_price NUMERIC(12,2),
    max_price NUMERIC(12,2), -- NULL = unlimited
    commission_amount NUMERIC(12,2),
    
    position INTEGER,
    created_at TIMESTAMPTZ
);
```

### 1.4 DATA MODELS

#### Vendor Model
```dart
class Vendor {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  
  final String commissionType; // 'percentage' or 'price_range'
  final double defaultCommissionRate;
  
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Methods
  factory Vendor.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### 1.5 REPOSITORY LAYER

#### VendorsRepositorySupabase
Location: `lib/data/repositories/vendors_repository_supabase.dart`

**Key Methods:**

```dart
// CRUD Operations
Future<List<Vendor>> getAllVendors({bool activeOnly = true});
Future<Vendor?> getVendorById(String vendorId);
Future<Vendor> createVendor(Vendor vendor);
Future<Vendor> updateVendor(Vendor vendor);
Future<void> deleteVendor(String vendorId);
Future<void> toggleVendorStatus(String vendorId, bool isActive);

// Product Assignment
Future<void> assignProductToVendor(String vendorId, String productId, {double? commissionRate});
Future<void> removeProductFromVendor(String vendorId, String productId);
Future<List<Product>> getVendorProducts(String vendorId);

// Claims Management
Future<List<VendorClaim>> getAllClaims({String? vendorId, String? status});
Future<VendorClaim?> getClaimById(String claimId);
Future<VendorClaim> createClaim(VendorClaim claim);
Future<VendorClaim> approveClaim(String claimId);
Future<VendorClaim> rejectClaim(String claimId);

// Financial Data
Future<VendorPayment> recordPayment({...});
Future<List<VendorPayment>> getVendorPayments(String vendorId);
Future<VendorSummary> getVendorSummary(String vendorId);
Future<int> getPendingClaimsCount();
```

### 1.6 UI PAGES

#### VendorsPage
- List all vendors
- Search & filter (by name, status)
- Add new vendor button
- Active/inactive toggle
- Quick access to vendor details

#### AddVendorPage
- Form for creating new vendor
- Fields: name, email, phone, address, commission rate, bank details
- Validation & error handling
- Success feedback

#### VendorDetailPage
- Vendor summary dashboard
- Cards showing:
  - Total sales amount
  - Total commission
  - Amount paid
  - Outstanding balance
- Contact information
- Quick actions (View Claims, Assign Products)

#### AssignProductsPage
- List all products
- Toggle switch for each product
- Show current assignment status
- Real-time updates

#### VendorClaimsPage
- List claims for selected vendor
- Filter by status (all, pending, approved, paid)
- Approve/Reject buttons
- View claim details

### 1.7 USER WORKFLOW

```
1. Go to Vendors page from drawer menu
                ↓
2. Click "+ Add Vendor" button
                ↓
3. Fill in vendor details:
   - Name
   - Email/Phone
   - Address
   - Commission rate
   - Bank details
                ↓
4. Click "Save Vendor"
                ↓
5. Go to Vendor Details
                ↓
6. Click "Assign Products"
                ↓
7. Toggle products ON/OFF
                ↓
✅ Vendor created and configured
```

### 1.8 KEY CALCULATIONS

#### Commission Calculation (Percentage-based)
```
Commission Amount = Sales Amount × (Commission Rate / 100)
Net Amount = Sales Amount - Commission Amount
```

Example:
- Sales: RM 1000
- Commission Rate: 15%
- Commission: RM 150
- Net: RM 850

#### For Price-Range Based Commission
```
If Price falls between min_price and max_price:
  Commission Amount = Fixed Amount per range
```

---

## MODULE 2: DELIVERY MODULE

### 2.1 PURPOSE

Track and manage deliveries of products sent to vendors (Consignment System)

### 2.2 KEY FEATURES

#### ✅ Implemented Features:
1. **Create Delivery**
   - Select vendor
   - Add items with quantity & price
   - Auto-calculate total
   - Generate invoice number (auto)
   - Add notes

2. **Track Delivery Status**
   - delivered (default)
   - pending
   - claimed
   - rejected

3. **Rejection Management**
   - Track rejected quantity per item
   - Record rejection reason
   - Calculate accepted quantity automatically

4. **Payment Status Tracking**
   - pending
   - partial
   - settled

5. **Document Generation**
   - Auto-generate invoice number (format: DEL-YYMM-0001)
   - PDF invoice generation
   - WhatsApp sharing
   - Print support

6. **Inventory Integration**
   - Update stock when delivery created
   - Reduce available stock for vendor

### 2.3 DATABASE SCHEMA

#### Main Table: `vendor_deliveries`
```sql
CREATE TABLE vendor_deliveries (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    vendor_id UUID → vendors(id),
    vendor_name TEXT, -- Denormalized
    
    -- Delivery Information
    delivery_date DATE,
    status TEXT CHECK (status IN ('delivered','pending','claimed','rejected')),
    payment_status TEXT CHECK (payment_status IN ('pending','partial','settled')),
    
    -- Financial
    total_amount NUMERIC(12,2),
    
    -- Documents
    invoice_number TEXT UNIQUE,
    
    -- Notes
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_vendor_deliveries_vendor ON vendor_deliveries(vendor_id);
CREATE INDEX idx_vendor_deliveries_date ON vendor_deliveries(delivery_date);
CREATE INDEX idx_vendor_deliveries_status ON vendor_deliveries(status);
```

#### Items Table: `vendor_delivery_items`
```sql
CREATE TABLE vendor_delivery_items (
    id UUID PRIMARY KEY,
    delivery_id UUID → vendor_deliveries(id),
    product_id UUID → products(id),
    
    -- Product Info (denormalized)
    product_name TEXT,
    
    -- Quantity & Pricing
    quantity NUMERIC(12,3),
    unit_price NUMERIC(12,2),
    total_price NUMERIC(12,2),
    retail_price NUMERIC(12,2), -- Original price before commission
    
    -- Rejection Tracking
    rejected_qty NUMERIC(12,3) DEFAULT 0,
    rejection_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_vendor_delivery_items_delivery ON vendor_delivery_items(delivery_id);
CREATE INDEX idx_vendor_delivery_items_product ON vendor_delivery_items(product_id);
```

#### Invoice Number Generation Function
```sql
CREATE SEQUENCE vendor_delivery_invoice_counter;

CREATE OR REPLACE FUNCTION generate_delivery_invoice_number()
RETURNS TEXT AS $$
DECLARE
    v_year_month TEXT;
    v_counter INT;
BEGIN
    v_year_month := TO_CHAR(NOW(), 'YYMM');
    v_counter := NEXTVAL('vendor_delivery_invoice_counter');
    RETURN 'DEL-' || v_year_month || '-' || LPAD(v_counter::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;
```

### 2.4 DATA MODELS

#### Delivery Model
```dart
class Delivery {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String vendorName;
  final DateTime deliveryDate;
  final String status; // delivered, pending, claimed, rejected
  final String? paymentStatus; // pending, partial, settled
  final double totalAmount;
  final String? invoiceNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DeliveryItem> items;

  // Methods
  factory Delivery.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class DeliveryItem {
  final String id;
  final String deliveryId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? retailPrice;
  final double rejectedQty;
  final String? rejectionReason;

  // Methods
  double get acceptedQty => quantity - rejectedQty;
  
  factory DeliveryItem.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### 2.5 REPOSITORY LAYER

#### DeliveriesRepositorySupabase
Location: `lib/data/repositories/deliveries_repository_supabase.dart`

**Key Methods:**

```dart
// CRUD Operations
Future<Map<String, dynamic>> getDeliveries({
  int limit = 20,
  int offset = 0,
  String? vendorId,
  String? status,
  DateTime? fromDate,
  DateTime? toDate,
});

Future<Delivery?> getDeliveryById(String deliveryId);

Future<Delivery> createDelivery({
  required String vendorId,
  required DateTime deliveryDate,
  required String status,
  required List<Map<String, dynamic>> items,
  String? notes,
});

Future<Delivery> updateDelivery(Delivery delivery);

Future<void> deleteDelivery(String deliveryId);

// Status Updates
Future<void> updateDeliveryStatus(String deliveryId, String status);

Future<void> updatePaymentStatus(String deliveryId, String paymentStatus);

// Item Management
Future<void> updateRejection({
  required String itemId,
  required double rejectedQty,
  String? rejectionReason,
});

// Export & Import
Future<String> exportDeliveriesToCSV({String? vendorId});

Future<List<Delivery>> importDeliveries(String csvContent);

// Duplication
Future<Delivery> duplicateYesterdayDeliveries();
```

### 2.6 UI PAGES

#### DeliveriesPage
- List all deliveries with pagination
- Filter by vendor, status, date range
- Add new delivery button
- Edit rejection status
- Update payment status
- View invoice
- Share via WhatsApp
- Export to CSV
- Duplicate yesterday's deliveries

#### DeliveryFormDialog
- Create new delivery
- Select vendor
- Add multiple items
- Auto-calculate total
- Validation before submit

#### EditRejectionDialog
- Update rejected quantity
- Add rejection reason
- Auto-recalculate totals

#### PaymentStatusDialog
- Update payment status
- Record payment details

#### InvoiceDialog
- View generated invoice
- Print invoice
- Share via WhatsApp
- Download PDF

### 2.7 USER WORKFLOW

```
1. Go to Deliveries from drawer menu
                ↓
2. Click "+ Add Delivery" button
                ↓
3. Select Vendor from dropdown
                ↓
4. Set Delivery Date
                ↓
5. Add Items:
   - Select Product
   - Enter Quantity
   - Enter Unit Price
   - Auto-calculates total
                ↓
6. Add Notes (optional)
                ↓
7. Click "Create Delivery"
   - Auto-generates invoice number
   - Saves to database
                ↓
8. View Delivery Details
   - See invoice number
   - View items
   - Track status
                ↓
9. Update Status (if needed)
   - Mark as rejected
   - Update rejection reason
   - Update payment status
                ↓
✅ Delivery recorded and tracked
```

### 2.8 SPECIAL FEATURES

#### Rejection Tracking
```
Accepted Quantity = Total Quantity - Rejected Quantity
Amount Claimed = Accepted Quantity × Unit Price

Example:
Total: 100 units
Rejected: 20 units
Reason: "Expired"
Accepted: 80 units
```

#### Invoice Number Generation
```
Format: DEL-YYMM-0001
Example: DEL-2512-0001 (December 2025, Sequential 0001)

Auto-increments:
DEL-2512-0001
DEL-2512-0002
DEL-2512-0003
...

Resets each month
```

#### CSV Export
```
Format: CSV with columns
- Invoice Number
- Vendor Name
- Delivery Date
- Item Name
- Quantity
- Unit Price
- Total Price
- Status
- Payment Status
```

---

## MODULE 3: CLAIM MODULE

### 3.1 PURPOSE

Create and manage claims for vendor payments based on delivered products

### 3.2 KEY FEATURES

#### ✅ Implemented Features:
1. **Create Claim**
   - Step-by-step wizard flow
   - Select vendor
   - Select multiple deliveries
   - Automatic quantity calculations
   - Auto-apply commission
   - Generate claim summary

2. **Claim Status Tracking**
   - draft → pending → approved → paid
   - Reject with reason
   - Track submission date
   - Track approval date
   - Track payment date

3. **Financial Calculations**
   - Gross Amount (based on sold items)
   - Commission Amount (vendor commission)
   - Net Amount (amount to pay vendor)
   - Balance Amount (unpaid portion)

4. **Commission Types Support**
   - Percentage-based (e.g., 15%)
   - Price-range based (fixed amount per range)

5. **Payment Tracking**
   - Payment history per vendor
   - Multiple payments per claim allowed
   - Partial payment support
   - Payment method tracking

6. **Notifications**
   - Pending claims count
   - Overdue payment tracking
   - Auto-reminders

### 3.3 DATABASE SCHEMA

#### Claims Table: `consignment_claims`
```sql
CREATE TABLE consignment_claims (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    vendor_id UUID → vendors(id),
    
    -- Claim Info
    claim_number TEXT UNIQUE,
    claim_date DATE,
    status TEXT CHECK (status IN ('draft','submitted','approved','rejected','settled')),
    
    -- Financial Data
    gross_amount NUMERIC(12,2), -- Sum of sold items
    commission_rate NUMERIC(5,2), -- Vendor commission rate at time of claim
    commission_amount NUMERIC(12,2), -- Total commission
    net_amount NUMERIC(12,2), -- Amount to pay (gross - commission)
    paid_amount NUMERIC(12,2) DEFAULT 0, -- Amount already paid
    balance_amount NUMERIC(12,2), -- Unpaid (net - paid)
    
    -- Notes
    notes TEXT,
    
    -- Review Info
    reviewed_by UUID → users(id),
    reviewed_at TIMESTAMPTZ,
    
    -- Payment Info
    paid_by UUID → users(id),
    paid_at TIMESTAMPTZ,
    payment_reference TEXT,
    
    -- Timestamps
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_consignment_claims_vendor ON consignment_claims(vendor_id);
CREATE INDEX idx_consignment_claims_status ON consignment_claims(status);
CREATE INDEX idx_consignment_claims_claim_number ON consignment_claims(claim_number);
```

#### Claim Items Table: `consignment_claim_items`
```sql
CREATE TABLE consignment_claim_items (
    id UUID PRIMARY KEY,
    claim_id UUID → consignment_claims(id),
    delivery_id UUID → vendor_deliveries(id),
    delivery_item_id UUID → vendor_delivery_items(id),
    
    -- Product Info
    product_id UUID → products(id),
    product_name TEXT,
    
    -- Quantities (from delivery update)
    delivered_qty NUMERIC(12,3),
    sold_qty NUMERIC(12,3), -- Quantity sold
    unsold_qty NUMERIC(12,3),
    expired_qty NUMERIC(12,3),
    damaged_qty NUMERIC(12,3),
    
    -- Pricing
    unit_price NUMERIC(12,2),
    claimed_amount NUMERIC(12,2), -- sold_qty × unit_price
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_consignment_claim_items_claim ON consignment_claim_items(claim_id);
CREATE INDEX idx_consignment_claim_items_delivery ON consignment_claim_items(delivery_id);
```

#### Payments Table: `consignment_payments`
```sql
CREATE TABLE consignment_payments (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    vendor_id UUID → vendors(id),
    
    -- Payment Info
    payment_date DATE,
    amount NUMERIC(12,2),
    payment_method TEXT, -- bill_to_bill, cash, transfer, etc.
    payment_reference TEXT,
    
    -- Allocation
    claim_ids UUID[], -- Array of claim IDs this payment covers
    
    -- Notes
    notes TEXT,
    
    -- Recording Info
    recorded_by UUID → users(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_consignment_payments_vendor ON consignment_payments(vendor_id);
CREATE INDEX idx_consignment_payments_date ON consignment_payments(payment_date);
```

#### Claim Number Generation Function
```sql
CREATE OR REPLACE FUNCTION generate_claim_number()
RETURNS TEXT AS $$
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

### 3.4 DATA MODELS

#### ConsignmentClaim Model
```dart
class ConsignmentClaim {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  
  final String claimNumber;
  final DateTime claimDate;
  final String status; // draft, submitted, approved, rejected, settled
  
  final double grossAmount; // Total from sold items
  final double commissionRate; // Vendor's commission %
  final double commissionAmount; // Calculated commission
  final double netAmount; // What vendor gets paid (gross - commission)
  final double paidAmount; // Already paid
  final double balanceAmount; // Still due (net - paid)
  
  final String? notes;
  
  final String? reviewedBy;
  final DateTime? reviewedAt;
  
  final String? paidBy;
  final DateTime? paidAt;
  final String? paymentReference;
  
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? settledAt;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final List<ConsignmentClaimItem>? items;

  // Methods
  factory ConsignmentClaim.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class ConsignmentClaimItem {
  final String id;
  final String claimId;
  final String deliveryId;
  final String deliveryItemId;
  
  final String productId;
  final String productName;
  
  final double deliveredQty;
  final double soldQty;
  final double unsoldQty;
  final double expiredQty;
  final double damagedQty;
  
  final double unitPrice;
  final double claimedAmount; // soldQty × unitPrice

  // Methods
  factory ConsignmentClaimItem.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### 3.5 REPOSITORY LAYER

#### ConsignmentClaimsRepositorySupabase
Location: `lib/data/repositories/consignment_claims_repository_supabase.dart`

**Key Methods:**

```dart
// CRUD Operations
Future<List<ConsignmentClaim>> getAllClaims({
  String? vendorId,
  String? status,
  int limit = 20,
  int offset = 0,
});

Future<ConsignmentClaim?> getClaimById(String claimId);

Future<ConsignmentClaim> createClaim({
  required String vendorId,
  required List<String> deliveryIds,
  required DateTime claimDate,
  String? notes,
});

// Validation
Future<ClaimValidationResult> validateClaimRequest({
  required String vendorId,
  required List<String> deliveryIds,
});

// Summary
Future<ClaimSummary> getClaimSummary({
  required String vendorId,
  required List<String> deliveryIds,
});

// Status Updates
Future<ConsignmentClaim> submitClaim(String claimId);

Future<ConsignmentClaim> approveClaim(String claimId);

Future<ConsignmentClaim> rejectClaim(String claimId, String reason);

// Payment Recording
Future<ConsignmentPayment> recordPayment({
  required String vendorId,
  required double amount,
  required String paymentMethod,
  required List<String> claimIds,
  String? paymentReference,
  String? notes,
});

// Payment Tracking
Future<List<ConsignmentPayment>> getVendorPayments(String vendorId);

Future<int> getPendingClaimsCount();

Future<int> getOverdueClaimsCount();
```

### 3.6 UI PAGES

#### ClaimsPage (Main List)
- List all claims
- Filter by vendor, status
- Sort by date, amount, status
- Pending claims badge
- Click to view details
- Quick actions (approve, reject)

#### CreateClaimSimplifiedPage (Step-by-step Wizard)

**Step 1: Vendor Selection**
- Dropdown with all vendors
- Show vendor commission rate
- Auto-filter deliveries for selected vendor

**Step 2: Delivery Selection**
- Checkbox list of available deliveries
- Show date, amount, status
- Multiple selections allowed

**Step 3: Quantity Review**
- Show items from selected deliveries
- Display: Delivered quantity, Sold, Unsold, Expired, Damaged
- Auto-calculate totals

**Step 4: Summary & Confirmation**
- Show summary card:
  - Gross Amount (what sold)
  - Commission Rate (%)
  - Commission Amount (calculated)
  - Net Amount (what to pay)
- Add notes
- Confirm and create

#### ClaimDetailPage
- Full claim view
- Summary cards
- Item breakdown
- Status timeline
- Payment history
- Action buttons (approve, reject, pay)

### 3.7 USER WORKFLOW

```
1. Go to Claims from drawer menu
                ↓
2. View list of claims
   - Filter by vendor/status
   - See pending count
                ↓
3. Click "Create Claim" or "+ New Claim"
                ↓
STEP 1: Select Vendor
   - Pick vendor from dropdown
   - See their commission rate
                ↓
STEP 2: Select Deliveries
   - Check deliveries to include
   - Multiple selections OK
                ↓
STEP 3: Review Quantities
   - Auto-shows sold items from deliveries
   - Can adjust if needed
                ↓
STEP 4: Confirm Summary
   - Shows:
     * Gross: RM 1000
     * Commission: 15% = RM 150
     * Net (to pay): RM 850
   - Click "Create Claim"
                ↓
✅ Claim Created
   - Status: draft → submitted → approved
                ↓
Admin Reviews & Approves
   - Go to claim detail
   - Click "Approve"
   - Status: approved
                ↓
Record Payment
   - Amount: RM 850
   - Payment method: Bank transfer
   - Reference: TXN123456
   - Click "Record Payment"
                ↓
✅ Claim Status: settled
   - Commission tracked
   - Payment recorded
   - Vendor balance updated
```

### 3.8 KEY CALCULATIONS

#### Gross Amount
```
Gross = Sum of (Sold Quantity × Unit Price) for all items
```

#### Commission Calculation (Percentage-based)
```
Commission Amount = Gross Amount × (Commission Rate / 100)
Net Amount = Gross Amount - Commission Amount
Balance Amount = Net Amount - Paid Amount
```

#### Commission Calculation (Price-range based)
```
For each item:
  If Unit Price falls in range 1: Commission = Fixed Amount 1
  If Unit Price falls in range 2: Commission = Fixed Amount 2
  
Total Commission = Sum of all commissions
Net Amount = Gross Amount - Total Commission
```

#### Example Calculation
```
Delivery Items:
- Product A: 10 units @ RM 50 = RM 500 (8 sold, 2 unsold)
- Product B: 5 units @ RM 100 = RM 500 (5 sold, 0 unsold)

Gross Amount = (8 × RM 50) + (5 × RM 100) = RM 400 + RM 500 = RM 900
Commission Rate = 15%
Commission Amount = RM 900 × 15% = RM 135
Net Amount = RM 900 - RM 135 = RM 765

Vendor gets paid: RM 765
Commission to track: RM 135
```

### 3.9 VALIDATION RULES

```dart
class ClaimValidationRules {
  // Vendor must be selected
  if (vendorId.isEmpty) {
    errors.add('Sila pilih vendor');
  }
  
  // At least one delivery must be selected
  if (deliveryIds.isEmpty) {
    errors.add('Sila pilih sekurang-kurangnya satu penghantaran');
  }
  
  // All deliveries must be for same vendor
  if (deliveriesFromMultipleVendors) {
    errors.add('Semua penghantaran mesti daripada vendor yang sama');
  }
  
  // Delivery must not already be claimed
  if (deliveryAlreadyClaimed) {
    errors.add('Penghantaran ini sudah dituntut');
  }
  
  // Delivery must have sold items
  if (noSoldItems) {
    warnings.add('Tiada item terjual dalam penghantaran ini');
  }
  
  // Quantities must balance
  if (!quantitiesBalance) {
    errors.add('Jumlah item tidak seimbang');
  }
}
```

---

## INTEGRATION FLOW

### Complete Consignment Workflow

```
┌─────────────────────────────────────────────────────────┐
│ DAY 1: SETUP                                            │
├─────────────────────────────────────────────────────────┤
│ Owner opens app                                         │
│    ↓                                                    │
│ Drawer → Vendors                                        │
│    ↓                                                    │
│ + Add Vendor (Ahmad Bakery)                            │
│    - Name: Ahmad Bakery                                │
│    - Commission: 15%                                   │
│    - Bank: Maybank 1234567890                          │
│    ↓                                                    │
│ Save Vendor ✅                                          │
│    ↓                                                    │
│ Click vendor → Assign Products                         │
│    - Toggle products vendor can sell                   │
│    ↓                                                    │
│ Save assignments ✅                                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ DAY 2-10: DELIVERY & SALES                              │
├─────────────────────────────────────────────────────────┤
│ Owner decides to send products to vendor               │
│    ↓                                                    │
│ Drawer → Deliveries                                    │
│    ↓                                                    │
│ + Add Delivery                                         │
│    - Vendor: Ahmad Bakery                              │
│    - Date: 2025-12-05                                  │
│    - Items:                                            │
│      * Roti: 50 × RM 10 = RM 500                       │
│      * Kek: 20 × RM 25 = RM 500                        │
│    - Total: RM 1000                                    │
│    ↓                                                    │
│ Create → Invoice #DEL-2512-0001 generated ✅           │
│    ↓                                                    │
│ Share via WhatsApp to vendor                           │
│    ↓                                                    │
│ Vendor receives and signs for delivery                 │
│    ↓                                                    │
│ Vendor sells products over 1-2 weeks                   │
│    - Roti: 40 units sold, 10 unsold                    │
│    - Kek: 18 units sold, 2 expired                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ DAY 14: CLAIM CREATION                                  │
├─────────────────────────────────────────────────────────┤
│ Owner collects sales report from vendor               │
│    ↓                                                    │
│ Drawer → Claims                                        │
│    ↓                                                    │
│ + Create Claim (Step-by-step)                          │
│    ↓                                                    │
│ STEP 1: Select Vendor → Ahmad Bakery                   │
│    ↓                                                    │
│ STEP 2: Select Deliveries → DEL-2512-0001             │
│    ↓                                                    │
│ STEP 3: Review Quantities                              │
│    - Roti: 40 sold, 10 unsold = RM 400 claimed         │
│    - Kek: 18 sold, 2 expired = RM 450 claimed          │
│    - Gross: RM 850                                     │
│    ↓                                                    │
│ STEP 4: Review Summary                                 │
│    - Gross: RM 850                                     │
│    - Commission (15%): RM 127.50                       │
│    - Net (to pay): RM 722.50                           │
│    ↓                                                    │
│ Create Claim → CLM-2512-0001 ✅                        │
│    Status: draft → submitted                           │
│    ↓                                                    │
│ Show success message                                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ DAY 14-15: CLAIM APPROVAL                               │
├─────────────────────────────────────────────────────────┤
│ Owner reviews claim in detail page                      │
│    ↓                                                    │
│ Verify sales numbers with vendor                       │
│    ↓                                                    │
│ Click "Approve Claim"                                  │
│    Status: submitted → approved ✅                     │
│    ↓                                                    │
│ Notification: "Claim approved, ready to pay"          │
│    ↓                                                    │
│ Owner initiates payment to vendor                      │
│    - Amount: RM 722.50                                 │
│    - Method: Bank transfer                             │
│    - Reference: TXN20251205001                         │
│    ↓                                                    │
│ Record Payment in system                               │
│    - Amount: RM 722.50                                 │
│    - Reference: TXN20251205001                         │
│    ↓                                                    │
│ System updates:                                        │
│    - Claim status: approved → settled                  │
│    - Balance: RM 0                                     │
│    - Vendor paid_amount += RM 722.50 ✅               │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ TRACKING & REPORTING                                    │
├─────────────────────────────────────────────────────────┤
│ Owner can now see:                                      │
│    - Vendor Dashboard:                                 │
│      * Total Sales: RM 1000                            │
│      * Commission: RM 150                              │
│      * Paid: RM 722.50                                 │
│      * Balance: RM 0 (settled)                         │
│    ↓                                                    │
│    - Payment History:                                  │
│      * Date: 2025-12-15                                │
│      * Amount: RM 722.50                               │
│      * Reference: TXN20251205001                       │
│    ↓                                                    │
│    - Vendor Commission Report:                         │
│      * Commission earned: RM 150                       │
│      * Percentage: 15% of RM 1000                      │
│      * System tracks commission ✅                     │
└─────────────────────────────────────────────────────────┘
```

---

## DATABASE SCHEMA

### Tables Relationship Diagram

```
users
├── vendors (business_owner_id)
│   ├── vendor_products
│   │   └── products
│   ├── vendor_commission_price_ranges
│   └── vendor_deliveries (vendor_id)
│       ├── vendor_delivery_items
│       │   └── products
│       └── consignment_claims (delivery IDs)
│           ├── consignment_claim_items
│           │   ├── vendor_delivery_items
│           │   └── products
│           └── consignment_payments (claim IDs)
│
└── consignment_payments
    └── vendors
```

### RLS (Row Level Security) Policies

All tables have RLS enabled:
```sql
-- Pattern for all tables:
CREATE POLICY table_select_policy ON table_name
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY table_insert_policy ON table_name
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY table_update_policy ON table_name
    FOR UPDATE
    USING (business_owner_id = auth.uid());

CREATE POLICY table_delete_policy ON table_name
    FOR DELETE
    USING (business_owner_id = auth.uid());
```

---

## API ENDPOINTS

### Vendor API

```
GET    /vendors                          - List all vendors
GET    /vendors/:id                      - Get vendor details
POST   /vendors                          - Create vendor
PUT    /vendors/:id                      - Update vendor
DELETE /vendors/:id                      - Delete vendor

GET    /vendors/:id/products             - Get vendor's products
POST   /vendors/:id/products             - Assign product
DELETE /vendors/:id/products/:productId  - Remove product

GET    /vendors/:id/claims               - Get vendor's claims
GET    /vendors/:id/payments             - Get vendor's payments
GET    /vendors/:id/summary              - Get vendor summary
```

### Delivery API

```
GET    /deliveries                       - List deliveries (with pagination)
GET    /deliveries/:id                   - Get delivery details
POST   /deliveries                       - Create delivery
PUT    /deliveries/:id                   - Update delivery
DELETE /deliveries/:id                   - Delete delivery

PUT    /deliveries/:id/status            - Update delivery status
PUT    /deliveries/:id/payment-status    - Update payment status
PUT    /deliveries/:id/items/:itemId/rejection - Update rejection

GET    /deliveries/export/csv            - Export to CSV
POST   /deliveries/import/csv            - Import from CSV
POST   /deliveries/duplicate/yesterday   - Duplicate yesterday
```

### Claim API

```
GET    /claims                           - List claims
GET    /claims/:id                       - Get claim details
POST   /claims/create                    - Create claim
POST   /claims/:id/submit                - Submit claim
POST   /claims/:id/approve               - Approve claim
POST   /claims/:id/reject                - Reject claim

POST   /claims/:id/payments              - Record payment
GET    /claims/:id/payments              - Get payment history

GET    /claims/validate                  - Validate claim request
GET    /claims/summary                   - Get claim summary
GET    /claims/pending-count             - Get pending claims count
GET    /claims/overdue-count             - Get overdue claims count
```

---

## IMPLEMENTATION GUIDE

### Step 1: Database Setup

```bash
# 1. Apply migrations
supabase db push db/migrations/add_vendor_system.sql
supabase db push db/migrations/add_vendor_deliveries.sql
supabase db push db/migrations/add_consignment_claims.sql
supabase db push db/migrations/add_vendor_commission_types.sql

# 2. Verify tables created
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
```

### Step 2: Data Models

```dart
// Already created in lib/data/models/:
- vendor.dart
- delivery.dart
- claim.dart
- vendor_payment.dart
- vendor_claim.dart
- consignment_claim.dart
```

### Step 3: Repository Layer

```dart
// Already created in lib/data/repositories/:
- vendors_repository_supabase.dart
- deliveries_repository_supabase.dart
- consignment_claims_repository_supabase.dart
```

### Step 4: UI Implementation

```dart
// Vendor Module
lib/features/vendors/presentation/
├── vendors_page.dart
├── add_vendor_page.dart
├── vendor_detail_page.dart
├── vendor_claims_page.dart
└── assign_products_page.dart

// Delivery Module
lib/features/deliveries/presentation/
├── deliveries_page.dart
├── delivery_form_dialog.dart
├── edit_rejection_dialog.dart
├── payment_status_dialog.dart
└── invoice_dialog.dart

// Claim Module
lib/features/claims/presentation/
├── claims_page.dart
├── create_claim_simplified_page.dart
├── claim_detail_page.dart
└── widgets/
    ├── claim_summary_card.dart
    ├── delivery_selection_card.dart
    └── quantity_editor.dart
```

### Step 5: Route Registration

```dart
// In lib/main.dart or router configuration:
routes: {
  '/vendors': (context) => const VendorsPage(),
  '/vendors/:id': (context) => VendorDetailPage(
    vendorId: routeParams['id'],
  ),
  '/deliveries': (context) => const DeliveriesPage(),
  '/claims': (context) => const ClaimsPage(),
  '/claims/create': (context) => const CreateClaimSimplifiedPage(),
}
```

### Step 6: Navigation Integration

```dart
// In drawer or main menu:
ListTile(
  title: const Text('Vendors'),
  leading: const Icon(Icons.store),
  onTap: () => Navigator.of(context).pushNamed('/vendors'),
),
ListTile(
  title: const Text('Deliveries'),
  leading: const Icon(Icons.local_shipping),
  onTap: () => Navigator.of(context).pushNamed('/deliveries'),
),
ListTile(
  title: const Text('Claims'),
  leading: const Icon(Icons.assignment),
  onTap: () => Navigator.of(context).pushNamed('/claims'),
),
```

---

## TESTING STRATEGY

### Unit Tests

```dart
// Test models
test/data/models/
├── vendor_test.dart
├── delivery_test.dart
└── claim_test.dart

// Test repositories
test/data/repositories/
├── vendors_repository_test.dart
├── deliveries_repository_test.dart
└── consignment_claims_repository_test.dart
```

### Widget Tests

```dart
test/features/
├── vendors_page_test.dart
├── deliveries_page_test.dart
└── claims_page_test.dart
```

### Integration Tests

```dart
test/integration/
├── vendor_workflow_test.dart
├── delivery_workflow_test.dart
└── complete_consignment_workflow_test.dart
```

### Manual Test Scenarios

#### Vendor Module

```
✓ Create vendor with all fields
✓ Update vendor information
✓ Assign products to vendor
✓ View vendor summary
✓ Filter vendors by status
✓ Delete vendor (with cascade)
```

#### Delivery Module

```
✓ Create delivery with items
✓ Auto-generate invoice number
✓ Update delivery status
✓ Record rejection
✓ Update payment status
✓ Export to CSV
✓ Generate PDF invoice
✓ Share via WhatsApp
```

#### Claim Module

```
✓ Create claim via wizard
✓ Step-by-step validation
✓ Auto-calculate commission
✓ Submit claim
✓ Approve claim
✓ Reject claim with reason
✓ Record payment
✓ Track claim status
✓ View payment history
```

#### Complete Integration

```
✓ Full consignment cycle:
  1. Create vendor
  2. Assign products
  3. Create delivery
  4. Update quantities
  5. Create claim
  6. Approve claim
  7. Record payment
  8. Verify vendor summary updated
```

---

## FUTURE ENHANCEMENTS

### Phase 2 Features

1. **Vendor Portal**
   - Separate mobile app for vendors
   - View assigned products
   - Update sold quantities
   - Submit claims from vendor side
   - Track payment status

2. **Auto Claims**
   - Automatically create claims from POS sales
   - Link to actual sales transactions
   - Real-time quantity updates

3. **Reports**
   - Vendor performance reports
   - Commission trends
   - Sales by vendor
   - Payment statistics

4. **Notifications**
   - Push notifications for claim status
   - Email notifications
   - WhatsApp auto-messages

5. **PDF Export**
   - Claim details PDF
   - Payment summary PDF
   - Vendor statement PDF
   - Multi-page PDFs

6. **Advanced Commission**
   - Tiered commission (based on volume)
   - Seasonal commission adjustments
   - Penalty/bonus system
   - Commission cap settings

7. **Integration**
   - Sync with accounting software
   - Bank transfer automation
   - Inventory sync
   - POS integration

### Phase 3 Features

1. **Analytics Dashboard**
   - Vendor analytics
   - Commission analytics
   - Sales trends
   - Performance KPIs

2. **Compliance**
   - Audit logs
   - Commission history
   - Payment proof tracking
   - Tax reporting

3. **Multi-vendor Management**
   - Vendor territories
   - Vendor hierarchies
   - Bulk operations
   - Vendor groups

---

## TROUBLESHOOTING

### Common Issues

#### Issue: Invoice number not generating

```
Solution:
1. Check if sequence exists: SELECT * FROM vendor_delivery_invoice_counter;
2. If not, create sequence manually
3. Verify function: SELECT generate_delivery_invoice_number();
```

#### Issue: Claim number duplicates

```
Solution:
1. Check for race conditions in createClaim()
2. Add retry logic with exponential backoff
3. Use database-level uniqueness constraint
```

#### Issue: Commission calculation wrong

```
Solution:
1. Verify commission_type in vendor record
2. Check commission_rate value
3. Verify delivery items quantities
4. Test calculation: gross × (rate / 100)
```

#### Issue: Rejected quantity exceeds delivery quantity

```
Solution:
1. Add validation in updateRejection()
2. Check constraint: rejected_qty <= quantity
3. Show error message before saving
```

---

## QUICK REFERENCE

### Key Files

```
lib/
├── data/
│   ├── models/
│   │   ├── vendor.dart
│   │   ├── delivery.dart
│   │   ├── claim.dart
│   │   └── ...
│   └── repositories/
│       ├── vendors_repository_supabase.dart
│       ├── deliveries_repository_supabase.dart
│       └── consignment_claims_repository_supabase.dart
│
└── features/
    ├── vendors/
    │   └── presentation/
    ├── deliveries/
    │   └── presentation/
    └── claims/
        └── presentation/

db/migrations/
├── add_vendor_system.sql
├── add_vendor_deliveries.sql
├── add_consignment_claims.sql
└── add_vendor_commission_types.sql
```

### Important Constants

```dart
// Commission Types
const COMMISSION_TYPE_PERCENTAGE = 'percentage';
const COMMISSION_TYPE_PRICE_RANGE = 'price_range';

// Delivery Status
const DELIVERY_STATUS_DELIVERED = 'delivered';
const DELIVERY_STATUS_PENDING = 'pending';
const DELIVERY_STATUS_CLAIMED = 'claimed';
const DELIVERY_STATUS_REJECTED = 'rejected';

// Claim Status
const CLAIM_STATUS_DRAFT = 'draft';
const CLAIM_STATUS_SUBMITTED = 'submitted';
const CLAIM_STATUS_APPROVED = 'approved';
const CLAIM_STATUS_REJECTED = 'rejected';
const CLAIM_STATUS_SETTLED = 'settled';

// Payment Status
const PAYMENT_STATUS_PENDING = 'pending';
const PAYMENT_STATUS_PARTIAL = 'partial';
const PAYMENT_STATUS_SETTLED = 'settled';
```

### Important Functions

```dart
// Vendor Summary Calculation
double calculateCommission(double salesAmount, double commissionRate) {
  return salesAmount * (commissionRate / 100);
}

// Accepted Quantity Calculation
double calculateAcceptedQuantity(double delivered, double rejected) {
  return delivered - rejected;
}

// Claimed Amount Calculation
double calculateClaimedAmount(double acceptedQty, double unitPrice) {
  return acceptedQty * unitPrice;
}
```

---

## GLOSSARY

| Term | Definition |
|------|-----------|
| **Consignor** | Owner/User - person who owns the products |
| **Consignee** | Vendor - person who sells products on behalf of owner |
| **Commission** | Percentage or fixed amount vendor earns for selling products |
| **Gross Amount** | Total value of products sold |
| **Net Amount** | Amount owner pays vendor (gross - commission) |
| **Claim** | Request for payment based on sold products |
| **Delivery** | Shipment of products sent to vendor |
| **Invoice** | Document generated for delivery (DEL-YYMM-XXXX) |
| **Claim Number** | Auto-generated identifier (CLM-YYMM-XXXX) |
| **Payment Status** | Status of payment (pending, partial, settled) |
| **Rejection** | Items not suitable for sale (expired, damaged, etc.) |

---

## SUMMARY

This comprehensive study covers:

✅ **Vendor Module** - Manage vendors, commission, bank details  
✅ **Delivery Module** - Track shipments, quantities, invoices  
✅ **Claim Module** - Create claims, calculate commission, record payments  

All modules are **fully integrated** with:
- Complete database schema
- Data models
- Repository layer
- UI implementation
- Validation & error handling
- PDF generation
- WhatsApp sharing
- CSV export/import

The system follows a **consignment business model** where:
1. Owner sends products to vendor
2. Vendor sells products with commission
3. Owner creates claim based on sales
4. Owner pays vendor (commission already deducted)
5. System tracks commission and payments

**Status:** Production Ready ✅

---

**Document Version:** 1.0  
**Last Updated:** December 5, 2025  
**Maintained By:** Development Team

