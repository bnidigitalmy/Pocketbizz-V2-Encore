# 🚀 APPLY MIGRATIONS - STEP BY STEP GUIDE

## 📋 **WHAT WE'RE APPLYING:**

1. ✅ **Stock Management** (if not done yet)
2. ✅ **Recipes & Production** (new!)

---

## 🎯 **STEP-BY-STEP:**

### **Step 1: Open Supabase Dashboard**
1. Go to: https://gxllowlurizrkvpdircw.supabase.co
2. Login with your credentials
3. Select your project

### **Step 2: Open SQL Editor**
1. Click **SQL Editor** in left sidebar
2. Click **New Query** button (top right)

---

## 📦 **MIGRATION 1: STOCK MANAGEMENT**

### **Copy This File:**
```
db/migrations/add_stock_management.sql
```

### **What It Creates:**
- ✅ `stock_items` table
- ✅ `stock_movements` table
- ✅ `stock_movement_type` enum
- ✅ `record_stock_movement()` function
- ✅ `low_stock_items` view
- ✅ RLS policies

### **Apply:**
1. Copy ENTIRE contents of `add_stock_management.sql`
2. Paste into SQL Editor
3. Click **Run** (or Ctrl+Enter)
4. Wait for ✅ Success

### **Verify:**
```sql
-- Check tables created
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('stock_items', 'stock_movements');

-- Should return 2 rows
```

---

## 🏭 **MIGRATION 2: RECIPES & PRODUCTION**

### **Copy This File:**
```
db/migrations/add_recipes_and_production.sql
```

### **What It Creates:**
- ✅ Updates `products` table (10 new columns)
- ✅ `recipe_items` table
- ✅ `production_batches` table
- ✅ `calculate_recipe_cost()` function
- ✅ `update_product_costs()` function
- ✅ `record_production_batch()` function (with auto-deduct!)
- ✅ RLS policies

### **Apply:**
1. Click **New Query** again
2. Copy ENTIRE contents of `add_recipes_and_production.sql`
3. Paste into SQL Editor
4. Click **Run** (or Ctrl+Enter)
5. Wait for ✅ Success

### **Verify:**
```sql
-- Check new tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('recipe_items', 'production_batches');

-- Should return 2 rows

-- Check new product columns
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'products' 
  AND column_name IN ('units_per_batch', 'labour_cost', 'materials_cost');

-- Should return 3 rows

-- Check functions created
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN (
  'calculate_recipe_cost',
  'update_product_costs',
  'record_production_batch'
);

-- Should return 3 rows
```

---

## ✅ **VERIFICATION TESTS**

### **Test 1: Stock Movement Function**
```sql
-- Create test stock item
INSERT INTO stock_items (
  business_owner_id, 
  name, 
  unit, 
  package_size, 
  purchase_price, 
  low_stock_threshold
)
VALUES (
  auth.uid(), 
  'TEST Item', 
  'kg', 
  1, 
  10.00, 
  5
)
RETURNING id;

-- Copy the returned ID and test movement
SELECT record_stock_movement(
  p_stock_item_id := 'PASTE_ID_HERE',
  p_movement_type := 'purchase',
  p_quantity_change := 10.0,
  p_reason := 'Initial test stock'
);

-- Check it worked
SELECT * FROM stock_items WHERE name = 'TEST Item';
-- Should show current_quantity = 10

SELECT * FROM stock_movements 
ORDER BY created_at DESC 
LIMIT 1;
-- Should show the movement record

-- Clean up test
DELETE FROM stock_items WHERE name = 'TEST Item';
```

### **Test 2: Recipe & Production Functions**
```sql
-- Will test after UI is ready!
-- For now, just verify functions exist
```

---

## 🚨 **TROUBLESHOOTING**

### **Error: "relation already exists"**
**Solution:** Tables already created, skip that migration
```sql
-- Check what's already there
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';
```

### **Error: "permission denied"**
**Solution:** Make sure you're logged in to Supabase dashboard

### **Error: "function already exists"**
**Solution:** Drop and recreate
```sql
DROP FUNCTION IF EXISTS record_stock_movement CASCADE;
DROP FUNCTION IF EXISTS calculate_recipe_cost CASCADE;
DROP FUNCTION IF EXISTS update_product_costs CASCADE;
DROP FUNCTION IF EXISTS record_production_batch CASCADE;
```
Then rerun migration.

---

## 📊 **EXPECTED RESULT**

After both migrations:

### **New Tables (5):**
1. ✅ `stock_items`
2. ✅ `stock_movements`
3. ✅ `recipe_items`
4. ✅ `production_batches`
5. ✅ `low_stock_items` (view)

### **New Functions (4):**
1. ✅ `record_stock_movement()`
2. ✅ `calculate_recipe_cost()`
3. ✅ `update_product_costs()`
4. ✅ `record_production_batch()`

### **Updated Tables (1):**
1. ✅ `products` (+10 new columns)

---

## ⏭️ **AFTER MIGRATIONS APPLIED:**

1. ✅ Run verification queries
2. ✅ Test stock movement function
3. ✅ Tell me "migrations done!"
4. 🚀 I'll build the UI pages!

---

## 💡 **QUICK TIPS:**

- ⚡ Each migration takes ~5-10 seconds
- 📝 Copy the ENTIRE file content
- ✅ Look for "Success" message
- 🔄 If error, read the error message
- 🆘 If stuck, send me the error!

---

**READY BRO? COPY-PASTE-RUN! 🎯**

Once done, balik sini and type **"migrations done!"** 
Then aku build UI terus! 🎨

