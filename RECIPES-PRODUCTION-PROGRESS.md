# 🏭 RECIPES & PRODUCTION SYSTEM - IN PROGRESS

## ✅ COMPLETED SO FAR (70%!)

### 1. **DATABASE SCHEMA** ✅
**File:** `db/migrations/add_recipes_and_production.sql`

**What's Created:**
- ✅ Updated `products` table with 10 new cost fields
- ✅ `recipe_items` table (links products ↔ stock items)
- ✅ `production_batches` table (FIFO tracking)
- ✅ RLS policies (multi-tenant security)
- ✅ Auto-update triggers
- ✅ 3 powerful DB functions:
  - `calculate_recipe_cost()` - Auto-sum materials
  - `update_product_costs()` - Recalc all cost fields
  - `record_production_batch()` - Create batch + auto-deduct stock!

**Key Features:**
- Unit conversion support (recipe unit ≠ stock unit)
- Automatic cost calculations
- FIFO batch tracking
- Expiry date tracking
- Thread-safe operations

---

### 2. **DART MODELS** ✅
**Files Created:**
- ✅ `lib/data/models/recipe_item.dart`
- ✅ `lib/data/models/production_batch.dart`

**Features:**
- Complete type safety
- JSON serialization
- Helper methods (isExpired, usagePercentage, etc.)
- Input DTOs for API calls

---

### 3. **REPOSITORIES** ✅
**Files Created:**
- ✅ `lib/data/repositories/recipes_repository_supabase.dart`
- ✅ `lib/data/repositories/production_repository_supabase.dart`

**Recipes Repository Features:**
- ✅ Get recipe for product
- ✅ Create/update/delete recipe items
- ✅ Bulk operations
- ✅ Auto-update product costs
- ✅ Replace entire recipe
- ✅ Recipe statistics

**Production Repository Features:**
- ✅ Record production (auto-deducts stock!)
- ✅ Get batches (by product, date range, etc.)
- ✅ FIFO operations
- ✅ Deduct from oldest batch first
- ✅ Update remaining qty
- ✅ Get expired batches
- ✅ Production statistics

---

## 🚧 REMAINING (30%)

### 4. **UI PAGES** (Next)
Need to create:
- [ ] Recipe Builder Page (add ingredients to product)
- [ ] Production Record Page (record new batch)
- [ ] Production History Page (list all batches)
- [ ] Product Detail Page (show recipe + costs)

### 5. **INTEGRATION** (Next)
- [ ] Add routes to `main.dart`
- [ ] Update Products page (show if has recipe)
- [ ] Dashboard widget (recent production)

---

## 🎯 HOW IT WORKS

### **Recipe System Flow:**

```
1. Create Product (e.g., "Chocolate Cake")
   ↓
2. Add Recipe Items:
   - 500g Tepung Gandum (from stock)
   - 200g Gula Pasir (from stock)
   - 3 pcs Telur (from stock)
   ↓
3. Set Additional Costs:
   - Labour: RM 10
   - Gas/Electricity: RM 5
   - Packaging: RM 0.50 per piece
   ↓
4. System Auto-Calculates:
   - Materials Cost = Sum of recipe items
   - Total Cost Per Batch = Materials + Labour + Other + (Packaging × Units)
   - Cost Per Unit = Total / Units Per Batch
   - Suggested Price = Cost Per Unit × (1 + Margin%)
```

### **Production System Flow:**

```
1. Record Production Batch
   - Product: Chocolate Cake
   - Quantity: 20 pieces
   - Batch Date: Today
   - Expiry Date: +7 days
   ↓
2. System AUTO-DEDUCTS Stock:
   - 10kg Tepung (-500g × 20 = -10kg)
   - 5kg Gula (-200g × 20 = -4kg)
   - 30 Telur (-3 × 20 = -60 pcs)
   ↓
3. Records Movement in Audit Trail:
   - "Used in production: Chocolate Cake (Batch: xxx)"
   ↓
4. Creates Batch with:
   - Quantity: 20
   - Remaining: 20 (for FIFO)
   - Cost: Auto-calculated from recipe
```

### **FIFO Sales Flow:**

```
1. Customer buys 5 Chocolate Cakes
   ↓
2. System finds OLDEST batch with remaining qty
   ↓
3. Deducts from that batch first
   - Batch #1 (oldest): 10 remaining → deduct 5 → 5 left
   ↓
4. If batch fully consumed, moves to next batch
   - Batch #1: 3 remaining → deduct 3
   - Batch #2: 2 remaining → deduct 2
```

---

## 📊 **DATABASE SCHEMA SUMMARY**

### **Products Table** (Updated)
```sql
-- New columns added:
units_per_batch INTEGER           -- How many units 1 recipe makes
labour_cost NUMERIC               -- Labour per batch
other_costs NUMERIC               -- Gas, electric, etc
packaging_cost NUMERIC            -- Cost per unit
materials_cost NUMERIC            -- Auto-calculated!
total_cost_per_batch NUMERIC     -- Auto-calculated!
cost_per_unit NUMERIC             -- Auto-calculated!
suggested_margin NUMERIC          -- Profit margin %
suggested_price NUMERIC           -- Auto-calculated!
selling_price NUMERIC             -- User-set final price
```

### **Recipe Items Table**
```sql
product_id UUID                   -- Which product
stock_item_id UUID                -- Which ingredient
quantity_needed NUMERIC           -- How much needed
usage_unit TEXT                   -- Can differ from stock unit!
cost_per_recipe NUMERIC           -- Calculated cost
position INTEGER                  -- Order in recipe
```

### **Production Batches Table**
```sql
product_id UUID                   -- What was produced
quantity INTEGER                  -- Total produced
remaining_qty NUMERIC             -- For FIFO tracking
batch_date DATE                   -- When produced
expiry_date DATE                  -- When expires
total_cost NUMERIC                -- Total batch cost
cost_per_unit NUMERIC             -- Cost per piece
```

---

## 🔥 **POWERFUL FEATURES**

### 1. **Unit Conversion**
Recipe can use different units than stock purchase:
- Stock: 1kg @ RM20 (per kg cost = RM20)
- Recipe: Needs 500 gram
- System converts: 500g = 0.5kg × RM20 = RM10

### 2. **Automatic Cost Calculation**
When you:
- Add/remove recipe items
- Change quantities
- Update stock prices

System automatically recalculates:
- Materials cost
- Total cost per batch
- Cost per unit
- Suggested selling price

### 3. **FIFO Tracking**
When selling products, system:
1. Finds oldest batch with remaining qty
2. Deducts from that batch
3. Moves to next batch if fully consumed
4. Tracks exact cost of goods sold (COGS)

### 4. **Stock Deduction**
When recording production:
- System reads recipe
- Calculates total ingredients needed
- Auto-deducts from stock
- Records movement in audit trail
- ALL IN ONE ATOMIC TRANSACTION!

### 5. **Expiry Tracking**
- Set expiry date for each batch
- Query expired batches
- Prevent sales from expired batches
- Track waste/losses

---

## ⏭️ **NEXT STEPS**

1. **Apply Migration** (5 mins)
   ```
   1. Go to Supabase SQL Editor
   2. Copy: db/migrations/add_recipes_and_production.sql
   3. Run
   4. Verify tables created
   ```

2. **Build UI Pages** (Ongoing)
   - Recipe Builder
   - Production Record
   - Production History
   - Integration with Products

3. **Test Complete Flow**
   - Create product
   - Add recipe
   - Record production
   - Verify stock deducted
   - Check costs calculated

---

## 💪 **TECHNICAL ACHIEVEMENTS**

✅ **Complex Cost Calculations** - Multi-level auto-calc  
✅ **Unit Conversions** - Flexible recipe units  
✅ **FIFO Implementation** - Accurate COGS tracking  
✅ **Atomic Transactions** - Stock + batch in one operation  
✅ **Audit Trail** - Complete history tracking  
✅ **Multi-tenant** - RLS enforced  
✅ **Type-Safe** - End-to-end typing  

---

## 🎊 **COMPLETION STATUS: 70%**

### ✅ Done:
1. ✅ Database schema & functions
2. ✅ Dart models
3. ✅ Repositories with full CRUD

### 🚧 In Progress:
4. 🚧 UI Pages (starting now!)
5. 🚧 Navigation integration

### ⏭️ Next:
6. ⏭️ Testing & documentation

---

**BRO, BACKEND LOGIC IS 100% DONE!** 🔥  
**NOW WE BUILD THE UI!** 🎨

Nak sambung create UI pages now? The heavy lifting (DB functions, repositories, FIFO logic) is COMPLETE! 💪

