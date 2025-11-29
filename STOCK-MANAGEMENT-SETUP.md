# 🏭 Stock Management System - Setup Guide

## ✅ What's Been Built

The complete **Stock Management System** has been ported from the old repo with these features:

### 📦 Features Implemented:
1. **Stock Items Management** - Raw materials/ingredients tracking
2. **Unit Conversions** - Auto-convert between kg, gram, liter, ml, tbsp, tsp, pcs, dozen
3. **Stock Movements** - Complete audit trail (purchase, replenish, production use, waste, etc.)
4. **Low Stock Alerts** - Real-time alerts when stock below threshold
5. **Optimistic Locking** - Prevent concurrent modification issues
6. **Cost Calculations** - Auto-calculate cost per unit from package pricing
7. **Thread-Safe Operations** - Database functions ensure consistency

---

## 🗄️ Database Setup

### Step 1: Apply Migration to Supabase

1. Go to your **Supabase Project Dashboard**
2. Click **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy the entire contents of `db/migrations/add_stock_management.sql`
5. Paste into the SQL Editor
6. Click **Run** (or press Ctrl+Enter)

### Step 2: Verify Tables Created

Run this query to verify:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('stock_items', 'stock_movements');
```

You should see both tables listed.

### Step 3: Test Stock Movement Function

```sql
-- Create a test stock item
INSERT INTO stock_items (business_owner_id, name, unit, package_size, purchase_price, low_stock_threshold)
VALUES (auth.uid(), 'Test Item', 'kg', 1, 10.00, 5);

-- Record a stock movement (add 10 kg)
SELECT record_stock_movement(
    p_stock_item_id := (SELECT id FROM stock_items WHERE name = 'Test Item' LIMIT 1),
    p_movement_type := 'purchase',
    p_quantity_change := 10.0,
    p_reason := 'Initial test stock'
);

-- Verify it worked
SELECT * FROM stock_items WHERE name = 'Test Item';
SELECT * FROM stock_movements ORDER BY created_at DESC LIMIT 1;
```

---

## 📱 Flutter App - Already Integrated!

### ✅ Files Created:

**Models:**
- `lib/data/models/stock_item.dart`
- `lib/data/models/stock_movement.dart`

**Utilities:**
- `lib/core/utils/unit_conversion.dart`

**Repository:**
- `lib/data/repositories/stock_repository_supabase.dart`

**UI Pages:**
- `lib/features/stock/presentation/stock_page.dart`
- `lib/features/stock/presentation/add_edit_stock_item_page.dart`
- `lib/features/stock/presentation/stock_detail_page.dart`
- `lib/features/stock/presentation/adjust_stock_page.dart`

**Dashboard Widget:**
- `lib/features/dashboard/presentation/widgets/low_stock_alerts_widget.dart`

### ✅ Navigation Added:
- Route: `/stock`
- Quick Action on Dashboard: "Stock Management"
- Low Stock Alerts Widget on Dashboard

---

## 🚀 How to Use

### 1. Run the App

```bash
cd pocketbizz-flutter
flutter run -d chrome
```

### 2. Access Stock Management

- **From Dashboard**: Click "Stock Management" quick action
- **Or navigate**: `/stock` route

### 3. Add Your First Stock Item

1. Click **"Add Stock Item"** FAB
2. Fill in:
   - Item Name (e.g., "Tepung Gandum")
   - Unit (e.g., "gram")
   - Package Size (e.g., 500)
   - Purchase Price (e.g., 21.90)
   - Low Stock Threshold (e.g., 5)
3. Optionally add initial quantity
4. Click **"Add Item"**

### 4. Adjust Stock

1. Tap on any stock item
2. Click **"Adjust Stock"** FAB
3. Choose **Add** or **Remove**
4. Select movement type
5. Enter quantity and reason
6. Submit

### 5. View Stock History

1. Tap any stock item
2. Go to **"History"** tab
3. See complete audit trail with:
   - Movement type
   - Quantity changes
   - Before/after quantities
   - Timestamps
   - Reasons

---

## 🎯 Key Features Explained

### Unit Conversion System

The app automatically converts between units for cost calculations:

**Weight:**
- kg ↔ gram ↔ g

**Volume:**
- liter ↔ l ↔ ml ↔ tbsp ↔ tsp

**Count:**
- dozen ↔ pcs ↔ pieces

**Example:**
- Package: 500 gram @ RM 21.90
- Cost per gram: RM 0.0438
- If recipe needs 250 gram → cost = RM 10.95

### Stock Movement Types

1. **Purchase** - Initial stock purchase
2. **Replenish** - Adding more stock
3. **Production Use** - Used in recipes/production
4. **Waste** - Damaged/expired items
5. **Return to Supplier** - Items returned
6. **Adjust** - Manual corrections
7. **Correction** - Inventory audit fixes
8. **Transfer** - Between locations (future)

### Thread-Safe Operations

All stock updates use the `record_stock_movement()` database function which:
- Locks the row to prevent concurrent modifications
- Updates stock quantity
- Records movement in audit trail
- All in ONE atomic transaction

### Optimistic Locking

Each stock item has a `version` field that increments on every update. This prevents:
- Lost updates from concurrent modifications
- Data inconsistencies
- Race conditions

---

## 📊 Dashboard Integration

The dashboard now shows:

1. **Low Stock Alerts Widget**
   - Top 5 low stock items
   - Visual stock level indicators
   - Quick access to stock details

2. **Stock Management Quick Action**
   - Easy access from dashboard
   - Modern gradient design

---

## 🔥 What's Next?

This completes **Stock Management System** porting! 

### Ready for next phase:

✅ **Stock Management** - DONE
⏭️ **Production Batches** - Link recipes to stock
⏭️ **Vendor Consignment** - Delivery tracking
⏭️ **Purchase Orders** - Supplier management
⏭️ **Subscription System** - ToyyibPay integration
⏭️ **Admin Panel** - Platform management

---

## 🛠️ Troubleshooting

### If migrations fail:

1. Check if tables already exist:
```sql
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS stock_items CASCADE;
DROP TYPE IF EXISTS stock_movement_type CASCADE;
```

2. Then rerun the migration

### If RLS errors occur:

Check your user is authenticated:
```sql
SELECT auth.uid();
```

Should return your user UUID, not null.

---

## 📞 Need Help?

The Stock Management system is now **production-ready** with:
- Complete UI/UX
- Thread-safe operations
- Audit trail
- Low stock alerts
- Unit conversions

**Nak test sekarang?** Just run the app and add your first stock item! 🚀

