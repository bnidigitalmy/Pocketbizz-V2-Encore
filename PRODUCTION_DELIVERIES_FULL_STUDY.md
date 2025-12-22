# 📚 FULL STUDY - PRODUCTION & DELIVERIES MODULES

**Date:** January 16, 2025  
**Project:** PocketBizz Flutter App  
**Study Level:** Comprehensive (Complete Implementation Details)

---

## 🎯 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Module 1: Production Module](#module-1-production-module)
3. [Module 2: Deliveries Module](#module-2-deliveries-module)
4. [Integration Flow](#integration-flow)
5. [Database Schema](#database-schema)
6. [Key Calculations](#key-calculations)
7. [User Flows](#user-flows)
8. [Technical Implementation](#technical-implementation)
9. [Testing Strategy](#testing-strategy)
10. [Future Enhancements](#future-enhancements)

---

## 📖 OVERVIEW

### **Business Context:**

**Production Module:**
- Convert raw materials (stock items) into finished products
- Track production batches with FIFO (First In First Out)
- Auto-calculate costs from recipes
- Auto-deduct stock when recording production
- **Use Case:** Bakery produces cakes from flour, sugar, eggs → Creates production batch → Batch available for sales/deliveries

**Deliveries Module:**
- Send finished products to vendors (consignment system)
- Track delivery status and payment status
- Auto-deduct from production batches using FIFO
- Generate invoices and track rejections
- **Use Case:** Owner sends cakes to vendor → Vendor sells → Owner creates claim → Owner gets paid (minus commission)

### **Complete Business Flow:**

```
Raw Materials (Stock Items)
    ↓
Recipe (Links Product → Stock Items)
    ↓
Production Batch (Converts Materials → Finished Product)
    ↓
Production Batches (FIFO Tracking)
    ↓
┌─────────────┬─────────────┐
│   Sales     │  Deliveries  │
│  (Direct)   │  (Vendors)   │
└─────────────┴─────────────┘
    ↓              ↓
FIFO Deduction (Oldest Batch First)
    ↓              ↓
Stock Movements (Audit Trail)
    ↓              ↓
Claims (for Deliveries)
    ↓
Payments
```

### **Key Concepts:**

1. **Production Batch:** One production run of a product
2. **FIFO Tracking:** Oldest batches consumed first
3. **Recipe-Based Production:** Uses recipe items to calculate materials needed
4. **Auto Stock Deduction:** Stock automatically deducted when recording production
5. **Delivery:** Shipment of products to vendor
6. **Accepted Quantity:** Quantity minus rejected quantity
7. **Consignment Flow:** Owner → Delivery → Vendor → Sales → Claim → Payment

---

## 🏭 MODULE 1: PRODUCTION MODULE

### **1.1 PURPOSE**

Convert raw materials (stock items) into finished products (production batches) with automatic cost calculation and stock deduction.

### **1.2 KEY FEATURES**

#### ✅ **Implemented Features:**

1. **Production Planning**
   - Preview materials needed before production
   - Check stock sufficiency
   - Calculate total production cost
   - Single product planning
   - Bulk production planning (multiple products)

2. **Record Production**
   - Create production batch
   - Auto-deduct stock from recipe items
   - Track batch date and expiry date
   - Optional batch number
   - Notes for production

3. **Production History**
   - View all production batches
   - Filter by product, date range
   - Track remaining quantity (FIFO)
   - Expiry date tracking
   - Cost tracking per batch

4. **FIFO Management**
   - Oldest batches consumed first
   - Track remaining quantity per batch
   - Auto-deduct when selling/delivering
   - Batch movement tracking

5. **Cost Calculation**
   - Materials cost (from recipe)
   - Labour cost (per batch)
   - Other costs (gas, electricity)
   - Packaging cost (per unit)
   - Total cost per batch
   - Cost per unit

6. **Stock Integration**
   - Auto-deduct stock when recording production
   - Track ingredient usage
   - Stock movement audit trail
   - Unit conversion support

### **1.3 DATABASE SCHEMA**

#### **Recipes Table: `recipes`**
```sql
CREATE TABLE recipes (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    product_id UUID NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
```

**Purpose:** Links products to recipe items. One product can have multiple recipe versions, but only one active.

#### **Recipe Items Table: `recipe_items`**
```sql
CREATE TABLE recipe_items (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    recipe_id UUID NOT NULL, -- Links to recipes table
    product_id UUID NOT NULL, -- Denormalized for performance
    stock_item_id UUID NOT NULL,
    
    -- Quantity & Unit
    quantity_needed NUMERIC(10,2) NOT NULL,
    usage_unit TEXT NOT NULL, -- Can differ from stock unit!
    
    -- Cost Tracking
    cost_per_recipe NUMERIC(10,2) NOT NULL DEFAULT 0,
    
    -- Metadata
    position INTEGER DEFAULT 0,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
```

**Purpose:** Defines ingredients needed for a product. Links recipe → stock items with quantities.

#### **Main Table: `production_batches`**
```sql
CREATE TABLE production_batches (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    product_id UUID NOT NULL,
    
    -- Batch Information
    batch_number TEXT,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    remaining_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
    
    -- Dates
    batch_date DATE NOT NULL,
    expiry_date DATE,
    
    -- Costs
    total_cost NUMERIC(10,2) NOT NULL,
    cost_per_unit NUMERIC(10,2) NOT NULL,
    
    -- Metadata
    notes TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
```

**Key Fields:**
- `quantity`: Total units produced
- `remaining_qty`: Units still available (for FIFO)
- `batch_date`: When production happened
- `expiry_date`: When batch expires (optional)
- `total_cost`: Total cost of batch
- `cost_per_unit`: Cost per unit (for COGS calculation)

#### **Audit Table: `production_ingredient_usage`**
```sql
CREATE TABLE production_ingredient_usage (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    production_batch_id UUID NOT NULL,
    stock_item_id UUID NOT NULL,
    recipe_item_id UUID,
    
    -- Usage Details
    quantity_used NUMERIC(10,2) NOT NULL,
    unit TEXT NOT NULL,
    cost_per_unit NUMERIC(10,2),
    total_cost NUMERIC(10,2),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL
);
```

**Purpose:** Track exactly what ingredients were used in each production batch (audit trail).

#### **Movement Tracking: `production_batch_stock_movements`**
```sql
CREATE TABLE production_batch_stock_movements (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    batch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    
    -- Movement Details
    movement_type TEXT NOT NULL, -- 'sale', 'production', 'adjustment', 'expired', 'damaged'
    quantity NUMERIC(10,2) NOT NULL,
    remaining_after_movement NUMERIC(10,2) NOT NULL,
    
    -- Reference
    reference_id UUID,
    reference_type TEXT, -- 'sale', 'delivery', 'production_batch'
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL
);
```

**Purpose:** Track all movements (sales, deliveries) from production batches.

### **1.4 DATABASE FUNCTIONS**

#### **`record_production_batch()`**
**Purpose:** Create production batch and auto-deduct stock atomically.

**Parameters:**
- `p_product_id`: Product to produce
- `p_quantity`: Number of units to produce
- `p_batch_date`: Production date
- `p_expiry_date`: Expiry date (optional)
- `p_notes`: Notes (optional)
- `p_batch_number`: Custom batch number (optional)

**What It Does:**
1. Validates product exists
2. Gets active recipe for product
3. Checks stock sufficiency for all ingredients
4. Creates production batch record
5. Deducts stock from each recipe item
6. Records ingredient usage (audit trail)
7. Returns batch ID

**Key Logic:**
- Two-pass validation: Check first, then deduct
- Unit conversion support (recipe unit ≠ stock unit)
- Auto-calculates cost from product's `cost_per_unit`
- Thread-safe operations
- Uses active recipe (is_active = true)
- Records ingredient usage for audit trail

### **1.5 DATA MODELS**

#### **`ProductionBatch`**
```dart
class ProductionBatch {
  final String id;
  final String businessOwnerId;
  final String productId;
  final String? batchNumber;
  final String productName;
  final int quantity;
  final double remainingQty; // For FIFO
  final DateTime batchDate;
  final DateTime? expiryDate;
  final double totalCost;
  final double costPerUnit;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Helper Methods:**
- `isFullyUsed`: Check if batch fully consumed
- `isPartiallyUsed`: Check if batch partially consumed
- `isExpired`: Check if batch expired
- `usagePercentage`: Get percentage used
- `canBeEdited`: Check if can edit/delete (24 hours or admin)
- `hasBeenUsed`: Check if batch used in sales

#### **`ProductionBatchInput`**
```dart
class ProductionBatchInput {
  final String productId;
  final int quantity;
  final DateTime batchDate;
  final DateTime? expiryDate;
  final String? notes;
  final String? batchNumber;
}
```

#### **`ProductionPlan`**
```dart
class ProductionPlan {
  final ProductInfo product;
  final int quantity; // Number of batches
  final int totalUnits; // Total units produced
  final List<MaterialPreview> materialsNeeded;
  final bool allStockSufficient;
  final double totalProductionCost;
}
```

**Purpose:** Preview production plan before recording.

#### **`MaterialPreview`**
```dart
class MaterialPreview {
  final String stockItemId;
  final String stockItemName;
  final double quantityNeeded;
  final String usageUnit;
  final double currentStock;
  final String stockUnit;
  final bool isSufficient;
  final double shortage;
  final double convertedQuantity;
  final double packageSize;
  final int packagesNeeded;
}
```

**Purpose:** Show material requirements and stock status.

### **1.6 REPOSITORY METHODS**

#### **ProductionRepository**

**CRUD Operations:**
- `getAllBatches()`: Get all batches with pagination
- `getBatchById()`: Get single batch
- `getRecentBatches()`: Get last N batches
- `getBatchesByDateRange()`: Filter by date range
- `recordProductionBatch()`: Create batch (uses DB function)
- `updateBatch()`: Update batch details
- `updateBatchNotes()`: Update notes only
- `deleteBatchWithStockReversal()`: Delete and reverse stock

**FIFO Operations:**
- `getOldestBatchesForProduct()`: Get batches for FIFO (oldest first)
- `deductFromBatch()`: Deduct quantity from specific batch
- `deductFIFO()`: Deduct using FIFO (multiple batches)
- `consumeStock()`: Consume stock for delivery

**Statistics:**
- `getProductionStatistics()`: Get production stats
- `getTotalRemainingForProduct()`: Get total available stock
- `getExpiredBatches()`: Get expired batches

**Planning:**
- `previewProductionPlan()`: Preview single product plan
- `previewBulkProductionPlan()`: Preview multiple products plan

**Movement Tracking:**
- `getBatchMovementHistory()`: Get movements for batch
- `getProductMovementHistory()`: Get movements for product

### **1.7 UI PAGES**

#### **1. Production Planning Page** (`production_planning_page.dart`)

**Features:**
- View all production batches (history)
- Scheduled production tasks (from planner)
- Create new production (single or bulk)
- Filter and search batches
- Edit notes
- Delete batches (with stock reversal)

**Key UI Elements:**
- Batch cards with product image
- Expiry status indicators (expired, expiring, fresh)
- Cost display
- Edit/Delete actions (conditional)
- Scheduled production section

**Actions:**
- "Rancang/Bulk" button → Opens planning chooser
- Planning chooser → Single or Bulk planning
- Batch menu → Edit notes, Delete

#### **2. Record Production Page** (`record_production_page.dart`)

**Features:**
- Select product
- Enter quantity
- Set batch date
- Set expiry date (optional)
- Add batch number (optional)
- Add notes (optional)
- Record production

**Key UI Elements:**
- Product dropdown
- Product info card (if pre-selected)
- Quantity input
- Date pickers
- Warning card (stock auto-deduction notice)
- Record button

**Validation:**
- Product must be selected
- Quantity must be positive integer
- Stock must be sufficient (checked by DB function)

#### **3. Production Planning Dialog** (`production_planning_dialog.dart`)

**3-Step Flow:**

**Step 1: Select Product & Quantity**
- Select product
- Enter number of batches
- Set batch date
- Set scheduled time (for planner task)
- Set expiry (days or date)

**Step 2: Preview Materials**
- Shows materials needed
- Stock sufficiency check
- Shortage warnings
- Total production cost
- Can add to shopping list

**Step 3: Confirm & Record**
- Review plan
- Create planner task (optional)
- Record production
- Add to shopping list (if stock insufficient)

**Key Features:**
- Real-time stock checking
- Material preview with shortages
- Shopping list integration
- Planner task creation

#### **4. Bulk Production Planning Dialog** (`bulk_production_planning_dialog.dart`)

**Features:**
- Select multiple products
- Set batch count per product
- Preview aggregated materials
- "Produce Now" plan (respects shared stock)
- Shows blockers (insufficient stock)
- Can produce partial (what's possible now)

**Key Logic:**
- Aggregates materials across all products
- Computes "produce now" plan (partial)
- Respects shared raw materials
- Shows what can be produced now vs. full plan

### **1.8 PRODUCTION FLOW**

```
1. User Plans Production
   ↓
2. Select Product & Quantity
   ↓
3. System Checks Recipe
   ↓
4. System Checks Stock Sufficiency
   ↓
5. Preview Materials Needed
   ↓
6. User Confirms
   ↓
7. System Records Production Batch
   ↓
8. System Auto-Deducts Stock (from recipe items)
   ↓
9. System Records Ingredient Usage (audit trail)
   ↓
10. Batch Available for Sales/Deliveries
```

### **1.9 KEY CALCULATIONS**

#### **Production Cost Calculation:**
```
Materials Cost = Sum of (recipe_item.quantity_needed × stock_item.cost_per_unit)
Labour Cost = product.labour_cost (per batch)
Other Costs = product.other_costs (per batch)
Packaging Cost = product.packaging_cost × units_per_batch

Total Cost Per Batch = Materials + Labour + Other + Packaging
Cost Per Unit = Total Cost Per Batch / units_per_batch
```

#### **FIFO Deduction:**
```
1. Get batches ordered by batch_date ASC (oldest first)
2. For each batch:
   - If remaining_qty >= quantity_to_deduct:
     - Deduct all from this batch
     - Update remaining_qty
     - Done
   - Else:
     - Deduct remaining_qty from this batch
     - Move to next batch
     - Continue until all deducted
```

### **1.10 INTEGRATION WITH OTHER MODULES**

**With Recipes:**
- Uses active recipe to get ingredients
- Calculates materials needed from recipe items
- Auto-updates product costs when recipe changes

**With Stock:**
- Auto-deducts stock when recording production
- Uses `record_stock_movement()` function
- Tracks ingredient usage in audit trail

**With Sales:**
- Sales deduct from production batches (FIFO)
- Uses `deduct_from_production_batches_fifo()` function
- Tracks COGS from batch cost_per_unit

**With Deliveries:**
- Deliveries deduct from production batches (FIFO)
- Only accepted quantity deducted (quantity - rejected_qty)
- Uses same FIFO function as sales

**With Planner:**
- Can create planner tasks for scheduled production
- Shows upcoming scheduled production in planning page
- Links production planning with task management

**With Shopping List:**
- Can add insufficient materials to shopping list
- Auto-suggests packages needed
- Integrates with purchase orders

---

## 🚚 MODULE 2: DELIVERIES MODULE

### **2.1 PURPOSE**

Manage deliveries of finished products to vendors in a consignment system. Track delivery status, rejections, and payment status.

### **2.2 KEY FEATURES**

#### ✅ **Implemented Features:**

1. **Create Delivery**
   - Select vendor
   - Add items with quantity & price
   - Auto-calculate total (accepted qty only)
   - Auto-generate invoice number
   - Track rejection quantity per item
   - Add notes

2. **Track Delivery Status**
   - `delivered`: Default status
   - `pending`: Pending delivery
   - `claimed`: Vendor claimed (for payment)
   - `rejected`: Delivery rejected

3. **Rejection Management**
   - Track rejected quantity per item
   - Record rejection reason
   - Calculate accepted quantity automatically
   - Edit rejection after creation

4. **Payment Status Tracking**
   - `pending`: Not paid yet
   - `partial`: Partially paid
   - `settled`: Fully paid

5. **FIFO Stock Deduction**
   - Auto-deduct from production batches (FIFO)
   - Only accepted quantity deducted
   - Rejected quantity NOT deducted
   - Atomic operation (delivery + deduction)

6. **Document Generation**
   - Auto-generate invoice number (format: DEL-YYMM-0001)
   - PDF invoice generation
   - WhatsApp sharing
   - Print support

7. **Vendor Integration**
   - Load last delivery for vendor (quick duplicate)
   - Vendor commission calculation
   - Price calculation (with commission)

8. **Filters & Search**
   - Filter by vendor
   - Filter by status
   - Filter by date range
   - Pagination support

### **2.3 DATABASE SCHEMA**

#### **Main Table: `vendor_deliveries`**
```sql
CREATE TABLE vendor_deliveries (
    id UUID PRIMARY KEY,
    business_owner_id UUID NOT NULL,
    
    -- Vendor Information
    vendor_id UUID NOT NULL,
    vendor_name TEXT NOT NULL, -- Denormalized
    
    -- Delivery Information
    delivery_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'delivered',
    payment_status TEXT, -- 'pending', 'partial', 'settled'
    
    -- Financial
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    invoice_number TEXT UNIQUE, -- Auto-generated
    
    -- Notes
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
```

**Status Values:**
- `delivered`: Default, delivery sent
- `pending`: Pending delivery
- `claimed`: Vendor claimed (ready for payment)
- `rejected`: Delivery rejected

**Payment Status Values:**
- `pending`: Not paid
- `partial`: Partially paid
- `settled`: Fully paid

#### **Items Table: `vendor_delivery_items`**
```sql
CREATE TABLE vendor_delivery_items (
    id UUID PRIMARY KEY,
    delivery_id UUID NOT NULL,
    
    -- Product Information
    product_id UUID NOT NULL,
    product_name TEXT NOT NULL, -- Denormalized
    
    -- Quantity and Pricing
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    retail_price NUMERIC(12,2), -- Original retail price
    
    -- Rejection Tracking
    rejected_qty NUMERIC(12,3) DEFAULT 0,
    rejection_reason TEXT,
    
    -- Consignment Quantities (for claims)
    quantity_sold NUMERIC(12,3),
    quantity_unsold NUMERIC(12,3),
    quantity_expired NUMERIC(12,3),
    quantity_damaged NUMERIC(12,3),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
```

**Key Fields:**
- `quantity`: Total quantity delivered
- `rejected_qty`: Quantity rejected
- `accepted_qty`: Calculated as `quantity - rejected_qty`
- `quantity_sold/unsold/expired/damaged`: For claims tracking

### **2.4 DATABASE FUNCTIONS**

#### **`create_vendor_delivery_and_deduct_fifo()`**
**Purpose:** Create delivery and deduct stock atomically.

**Parameters:**
- `p_vendor_id`: Vendor to deliver to
- `p_delivery_date`: Delivery date
- `p_items`: JSONB array of items
- `p_status`: Delivery status (default: 'delivered')
- `p_notes`: Notes (optional)

**Item Structure:**
```json
{
  "product_id": "uuid",
  "product_name": "string",
  "quantity": 10.0,
  "rejected_qty": 0.0,
  "unit_price": 5.00,
  "retail_price": 6.00,
  "rejection_reason": null
}
```

**What It Does:**
1. Validates vendor exists and belongs to user
2. Validates all items (product exists, quantities valid)
3. Calculates total amount (accepted qty only)
4. Creates delivery record
5. Creates delivery items
6. Deducts stock from production batches (FIFO) for accepted qty only
7. Returns delivery ID

**Key Logic:**
- Only accepted quantity deducted: `quantity - rejected_qty`
- Uses FIFO (oldest batches first)
- Atomic operation (all or nothing)
- Auto-generates invoice number

#### **`generate_delivery_invoice_number()`**
**Purpose:** Auto-generate invoice number.

**Format:** `DEL-YYMM-0001`

**Logic:**
- Prefix: `DEL`
- Year: Last 2 digits
- Month: 2 digits
- Sequence: 4 digits (increments per month)

**Example:** `DEL-2501-0001` (January 2025, first delivery)

### **2.5 DATA MODELS**

#### **`Delivery`**
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
}
```

#### **`DeliveryItem`**
```dart
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
  
  // Consignment quantities (for claims)
  final double? quantitySold;
  final double? quantityUnsold;
  final double? quantityExpired;
  final double? quantityDamaged;
  
  final DateTime createdAt;
}
```

**Calculated Properties:**
- `acceptedQty`: `quantity - rejectedQty`
- `acceptedTotalPrice`: `acceptedQty × unitPrice`

### **2.6 REPOSITORY METHODS**

#### **DeliveriesRepositorySupabase**

**CRUD Operations:**
- `getAllDeliveries()`: Get all deliveries with pagination
- `getDeliveryById()`: Get single delivery
- `getLastDeliveryForVendor()`: Get last delivery (for duplicate)
- `createDelivery()`: Create delivery (uses DB function)
- `updateDeliveryStatus()`: Update status
- `updateDeliveryPaymentStatus()`: Update payment status
- `updateDeliveryItemRejection()`: Update rejection
- `updateDeliveryItemQuantities()`: Update consignment quantities
- `batchUpdateDeliveryItemQuantities()`: Batch update quantities

**Vendor Integration:**
- `getVendorCommission()`: Get vendor commission info

### **2.7 UI PAGES**

#### **1. Deliveries Page** (`deliveries_page.dart`)

**Features:**
- List all deliveries
- Filter by vendor, status, date range
- Pagination (load more)
- Create new delivery
- Edit delivery status
- Edit rejection
- Update payment status
- View invoice
- Share via WhatsApp
- Export CSV (planned)
- Duplicate yesterday's delivery

**Key UI Elements:**
- Delivery cards (expandable)
- Status badges (color-coded)
- Payment status indicators
- Item list with rejections
- Action buttons (Edit Rejection, WhatsApp, Invoice)
- Filters panel

**Actions:**
- "Tambah Penghantaran" button → Opens delivery form
- Status dropdown → Update status
- "Edit Tolakan" → Edit rejection dialog
- "WhatsApp" → Share delivery info
- "Invois" → View invoice dialog

#### **2. Delivery Form Dialog** (`delivery_form_dialog.dart`)

**Features:**
- Select vendor
- Add/remove items
- Set quantity and price per item
- Set rejection quantity and reason
- Auto-calculate total (accepted qty)
- Load last delivery for vendor (duplicate)
- Check stock availability
- Create delivery

**Key UI Elements:**
- Vendor dropdown
- Item list with add/remove
- Quantity and price inputs
- Rejection inputs (quantity + reason)
- Stock availability display
- Total amount display
- Create button

**Validation:**
- Vendor must be selected
- At least one item required
- Quantity must be positive
- Rejected qty cannot exceed quantity
- Stock must be sufficient (for accepted qty)

#### **3. Edit Rejection Dialog** (`edit_rejection_dialog.dart`)

**Features:**
- Edit rejected quantity per item
- Edit rejection reason
- Update delivery item rejection

**Key UI Elements:**
- Item list
- Rejection quantity input
- Rejection reason input
- Save button

#### **4. Payment Status Dialog** (`payment_status_dialog.dart`)

**Features:**
- Update payment status
- Options: pending, partial, settled

**Key UI Elements:**
- Payment status dropdown
- Save button

#### **5. Invoice Dialog** (`invoice_dialog.dart`)

**Features:**
- Display delivery invoice
- Show delivery details
- Show items list
- Show totals
- Print support (planned)

**Key UI Elements:**
- Invoice header
- Business info
- Vendor info
- Items table
- Totals section
- Print button (planned)

### **2.8 DELIVERY FLOW**

```
1. User Creates Delivery
   ↓
2. Select Vendor
   ↓
3. Add Items (Product, Quantity, Price)
   ↓
4. Set Rejection (if any)
   ↓
5. System Calculates Total (Accepted Qty Only)
   ↓
6. System Creates Delivery Record
   ↓
7. System Creates Delivery Items
   ↓
8. System Auto-Deducts Stock (FIFO, Accepted Qty Only)
   ↓
9. System Generates Invoice Number
   ↓
10. Delivery Ready for Claims
```

### **2.9 KEY CALCULATIONS**

#### **Delivery Total Calculation:**
```
For each item:
  accepted_qty = quantity - rejected_qty
  item_total = accepted_qty × unit_price

delivery_total = Sum of all item_totals
```

#### **Stock Deduction:**
```
For each item:
  accepted_qty = quantity - rejected_qty
  IF accepted_qty > 0:
    Deduct from production_batches (FIFO)
    Only accepted_qty deducted
    Rejected qty NOT deducted
```

#### **Vendor Price Calculation:**
```
If vendor has commission:
  vendor_price = retail_price × (1 - commission_rate / 100)
Else:
  vendor_price = retail_price (or custom price)
```

### **2.10 INTEGRATION WITH OTHER MODULES**

**With Vendors:**
- Links to vendor record
- Uses vendor commission for pricing
- Tracks vendor name (denormalized)

**With Products:**
- Links to product record
- Uses product retail price
- Tracks product name (denormalized)

**With Production:**
- Deducts from production batches (FIFO)
- Only accepted quantity deducted
- Uses `deduct_from_production_batches_fifo()` function

**With Claims:**
- Delivery items used in claims
- Tracks sold/unsold/expired/damaged quantities
- Payment status linked to claims

**With Sales:**
- Uses same FIFO function as sales
- Same stock deduction logic
- Tracks reference_type as 'delivery'

---

## 🔄 INTEGRATION FLOW

### **Complete Production → Delivery Flow:**

```
1. User Plans Production
   ↓
2. System Checks Recipe & Stock
   ↓
3. User Records Production Batch
   ↓
4. System Auto-Deducts Raw Materials
   ↓
5. Production Batch Created (with remaining_qty)
   ↓
6. User Creates Delivery to Vendor
   ↓
7. System Deducts from Production Batches (FIFO)
   ↓
8. Delivery Created with Items
   ↓
9. Vendor Sells Products
   ↓
10. User Creates Claim (based on delivery)
   ↓
11. User Records Payment
```

### **FIFO Flow (Production → Sales/Delivery):**

```
Production Batches (ordered by batch_date ASC):
  Batch 1: 100 units (remaining: 100)
  Batch 2: 50 units (remaining: 50)
  Batch 3: 75 units (remaining: 75)

Sale/Delivery: 80 units
  ↓
Deduct from Batch 1: 80 units
  Batch 1: remaining = 20
  Batch 2: remaining = 50 (unchanged)
  Batch 3: remaining = 75 (unchanged)

Next Sale/Delivery: 60 units
  ↓
Deduct from Batch 1: 20 units (fully consumed)
  Deduct from Batch 2: 40 units
  Batch 1: remaining = 0
  Batch 2: remaining = 10
  Batch 3: remaining = 75 (unchanged)
```

---

## 🗄️ DATABASE SCHEMA DETAILS

### **Production Tables:**

1. **`production_batches`**
   - Tracks finished goods production
   - FIFO tracking via `remaining_qty`
   - Cost tracking per batch

2. **`production_ingredient_usage`**
   - Audit trail of ingredients used
   - Links batch → stock items
   - Tracks quantity and cost

3. **`production_batch_stock_movements`**
   - Tracks all movements from batches
   - Links to sales, deliveries
   - Movement types: sale, production, adjustment, expired, damaged

### **Delivery Tables:**

1. **`vendor_deliveries`**
   - Main delivery record
   - Status and payment tracking
   - Auto-generated invoice number

2. **`vendor_delivery_items`**
   - Items in delivery
   - Rejection tracking
   - Consignment quantities (for claims)

### **Relationships:**

```
products
  ↓ (1:N)
recipes (is_active = true)
  ↓ (1:N)
recipe_items
  ↓ (N:1)
stock_items

products
  ↓ (1:N)
production_batches
  ↓ (1:N)
production_batch_stock_movements
  ↓ (reference)
sales / vendor_deliveries

production_batches
  ↓ (1:N)
production_ingredient_usage
  ↓ (N:1)
stock_items

vendor_deliveries
  ↓ (1:N)
vendor_delivery_items
  ↓ (N:1)
products
  ↓ (FIFO deduction from)
production_batches
```

---

## 🧮 KEY CALCULATIONS

### **Production Cost:**
```
Materials Cost = Sum(recipe_item.quantity × stock_item.cost_per_unit)
Total Cost Per Batch = Materials + Labour + Other + (Packaging × Units)
Cost Per Unit = Total Cost Per Batch / Units Per Batch
```

### **Delivery Total:**
```
For each item:
  accepted_qty = quantity - rejected_qty
  item_total = accepted_qty × unit_price

delivery_total = Sum(item_totals)
```

### **FIFO Deduction:**
```
1. Get batches: ORDER BY batch_date ASC, created_at ASC
2. For each batch:
   - If remaining_qty >= quantity_to_deduct:
     - Deduct all from this batch
     - Update remaining_qty
     - Done
   - Else:
     - Deduct remaining_qty from this batch
     - Update remaining_qty = 0
     - Continue with next batch
```

### **Stock Availability:**
```
Total Available = Sum(remaining_qty) 
  FROM production_batches 
  WHERE product_id = X 
    AND remaining_qty > 0
```

---

## 👤 USER FLOWS

### **Flow 1: Record Production**

```
1. Go to Production Planning Page
   ↓
2. Click "Rancang/Bulk" button
   ↓
3. Select "Rancang Produksi (1 Produk)"
   ↓
4. Select Product
   ↓
5. Enter Number of Batches
   ↓
6. Set Batch Date & Expiry
   ↓
7. Click "Preview Bahan"
   ↓
8. Review Materials Needed
   ↓
9. If stock insufficient:
   - Add to Shopping List
   - Or proceed with partial
   ↓
10. Click "Rekod Produksi"
   ↓
11. System records batch & deducts stock
   ↓
✅ Production recorded
```

### **Flow 2: Create Delivery**

```
1. Go to Deliveries Page
   ↓
2. Click "Tambah Penghantaran"
   ↓
3. Select Vendor
   ↓
4. Add Items:
   - Select Product
   - Enter Quantity
   - Set Unit Price
   - Set Rejection (if any)
   ↓
5. System calculates total (accepted qty)
   ↓
6. Click "Simpan Penghantaran"
   ↓
7. System creates delivery & deducts stock (FIFO)
   ↓
8. Invoice dialog shows
   ↓
✅ Delivery created
```

### **Flow 3: Edit Rejection**

```
1. Go to Deliveries Page
   ↓
2. Find Delivery
   ↓
3. Expand delivery card
   ↓
4. Click "Edit Tolakan"
   ↓
5. Update rejected quantity
   ↓
6. Update rejection reason
   ↓
7. Click "Simpan"
   ↓
✅ Rejection updated
```

### **Flow 4: Update Payment Status**

```
1. Go to Deliveries Page
   ↓
2. Find Delivery
   ↓
3. Update Status to "Dituntut"
   ↓
4. Payment Status Dialog opens
   ↓
5. Select Payment Status
   ↓
6. Click "Simpan"
   ↓
✅ Payment status updated
```

---

## 🔧 TECHNICAL IMPLEMENTATION

### **File Structure:**

```
lib/
├── data/
│   ├── models/
│   │   ├── production_batch.dart
│   │   ├── production_preview.dart
│   │   ├── production_ingredient_usage.dart
│   │   └── delivery.dart
│   └── repositories/
│       ├── production_repository_supabase.dart
│       └── deliveries_repository_supabase.dart
├── features/
│   ├── production/
│   │   └── presentation/
│   │       ├── production_planning_page.dart
│   │       ├── record_production_page.dart
│   │       └── widgets/
│   │           ├── production_planning_dialog.dart
│   │           └── bulk_production_planning_dialog.dart
│   └── deliveries/
│       └── presentation/
│           ├── deliveries_page.dart
│           ├── delivery_form_dialog.dart
│           ├── edit_rejection_dialog.dart
│           ├── payment_status_dialog.dart
│           └── invoice_dialog.dart
└── db/
    └── migrations/
        ├── add_recipes_and_production.sql
        ├── create_record_production_batch_function.sql
        ├── add_vendor_deliveries.sql
        └── 2025-12-16_atomic_sales_and_deliveries_fifo.sql
```

### **Key Functions:**

1. **`record_production_batch()`** (DB Function)
   - Creates batch
   - Deducts stock
   - Records usage

2. **`deduct_from_production_batches_fifo()`** (DB Function)
   - Deducts from batches (FIFO)
   - Logs movements
   - Used by sales and deliveries

3. **`create_vendor_delivery_and_deduct_fifo()`** (DB Function)
   - Creates delivery
   - Creates items
   - Deducts stock (FIFO, accepted qty only)

### **Error Handling:**

- Stock insufficiency: Clear error message
- Invalid quantities: Validation errors
- Missing recipe: Error with guidance
- Database errors: User-friendly messages

---

## 🧪 TESTING STRATEGY

### **Production Module Testing:**

1. **Record Production:**
   - Test with sufficient stock
   - Test with insufficient stock
   - Test with multiple ingredients
   - Test unit conversion
   - Test cost calculation

2. **FIFO Deduction:**
   - Test oldest batch consumed first
   - Test multiple batches consumed
   - Test partial batch consumption
   - Test stock availability check

3. **Production Planning:**
   - Test single product planning
   - Test bulk planning
   - Test stock sufficiency check
   - Test shopping list integration

### **Deliveries Module Testing:**

1. **Create Delivery:**
   - Test with sufficient stock
   - Test with insufficient stock
   - Test with rejections
   - Test FIFO deduction (accepted qty only)
   - Test invoice number generation

2. **Rejection Management:**
   - Test edit rejection
   - Test rejection reason
   - Test accepted qty calculation

3. **Status Updates:**
   - Test status changes
   - Test payment status updates
   - Test status validation

---

## 🚀 FUTURE ENHANCEMENTS

### **Production Module:**
- [ ] Production scheduling calendar
- [ ] Batch expiry alerts
- [ ] Production reports
- [ ] Cost variance analysis
- [ ] Multi-location production
- [ ] Production templates
- [ ] Batch quality tracking
- [ ] Waste tracking

### **Deliveries Module:**
- [ ] Delivery tracking (GPS)
- [ ] Delivery confirmation (vendor app)
- [ ] Automated delivery reminders
- [ ] Delivery performance analytics
- [ ] Multi-currency support
- [ ] Delivery routes optimization
- [ ] Driver assignment
- [ ] Real-time delivery status

---

## 📋 QUICK REFERENCE

### **Production Module - Key Points:**

1. **Recipe Required:** Product must have active recipe before production
2. **Stock Check:** System validates stock sufficiency before recording
3. **Auto Deduction:** Stock automatically deducted when recording production
4. **FIFO Tracking:** Oldest batches consumed first (by batch_date)
5. **Cost Calculation:** Uses product's cost_per_unit (from recipe)
6. **Audit Trail:** All ingredient usage recorded in `production_ingredient_usage`

### **Deliveries Module - Key Points:**

1. **Accepted Qty Only:** Only `quantity - rejected_qty` deducted from stock
2. **FIFO Deduction:** Uses same FIFO logic as sales
3. **Invoice Auto-Generated:** Format `DEL-YYMM-0001`
4. **Status Flow:** delivered → pending → claimed → rejected
5. **Payment Tracking:** Separate from delivery status
6. **Rejection Tracking:** Can reject partial quantity with reason

### **Common Patterns:**

1. **FIFO Always:** Both sales and deliveries use FIFO (oldest first)
2. **Atomic Operations:** DB functions ensure all-or-nothing
3. **Stock Validation:** Always check before deduct
4. **Audit Trail:** All movements tracked in `production_batch_stock_movements`
5. **Cost Tracking:** Cost per unit stored in batch for COGS calculation

---

## 📊 SUMMARY

### **Production Module:**
- ✅ Complete production planning
- ✅ Recipe-based production
- ✅ Auto stock deduction
- ✅ FIFO tracking
- ✅ Cost calculation
- ✅ Audit trail

### **Deliveries Module:**
- ✅ Complete delivery management
- ✅ Rejection tracking
- ✅ Payment status tracking
- ✅ FIFO stock deduction
- ✅ Invoice generation
- ✅ Vendor integration

### **Integration:**
- ✅ Production → Deliveries (FIFO)
- ✅ Production → Sales (FIFO)
- ✅ Deliveries → Claims
- ✅ Stock movement tracking

---

**Status:** Production Ready ✅

---

**Document Version:** 1.0  
**Last Updated:** January 16, 2025  
**Maintained By:** Development Team
