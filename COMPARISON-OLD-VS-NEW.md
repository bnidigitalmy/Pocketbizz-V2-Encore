# 🔍 COMPARISON: OLD REPO VS CURRENT IMPLEMENTATION

## 📊 **PRODUCTS MODULE**

### **OLD REPO (React + Express):**
```sql
products (
    id, business_owner_id, sku, name, description,
    category TEXT,  -- ❗ Just TEXT
    unit, 
    cost_price, sale_price,
    -- ❌ NO image_url
    is_active, created_at, updated_at
)
```

### **CURRENT (Flutter + Supabase):**
```sql
products (
    id, business_owner_id, sku, name, description,
    category_id UUID,  -- ✅ Proper foreign key!
    unit, 
    cost_price, sale_price,
    image_url TEXT,  -- ✅ Product images!
    is_active, created_at, updated_at
)

categories (  -- ✅ New table!
    id, business_owner_id, name, color, icon
)
```

**STATUS:** ✅ **CURRENT IS BETTER!** (Categories + Images)

---

## 📦 **STOCK MANAGEMENT**

### **OLD REPO:**
```sql
ingredients (  -- ❗ Called "ingredients"
    id, business_owner_id,
    name, unit, cost_per_unit,
    supplier_id,  -- ✅ Links to suppliers
    -- ❌ NO current_quantity
    -- ❌ NO reorder_level
    -- ❌ NO stock tracking!
    created_at, updated_at
)
```

### **CURRENT:**
```sql
stock_items (  -- ❗ Called "stock_items"
    id, business_owner_id,
    item_name, unit, cost_per_unit,
    -- ❌ NO supplier_id yet
    current_quantity,  -- ✅ Track quantity!
    reorder_level,     -- ✅ Low stock alerts!
    created_at, updated_at
)

stock_movements (  -- ✅ Complete audit trail!
    id, stock_item_id, business_owner_id,
    type (IN/OUT/ADJUSTMENT),
    quantity, reason, reference_type, reference_id,
    created_at
)
```

**STATUS:** 🟡 **MIXED!**
- ✅ BETTER: Current quantity tracking, movements audit
- ❌ MISSING: Supplier link

---

## 🍳 **RECIPES MODULE**

### **OLD REPO (CORRECT!):**
```sql
-- 1. RECIPES TABLE (Master recipe info)
recipes (
    id, business_owner_id,
    product_id,  -- Links to ONE product
    name TEXT,   -- Recipe name (e.g., "Chocolate Cake Recipe V1")
    yield_quantity NUMERIC,  -- How many units this recipe produces
    yield_unit TEXT,         -- What unit (e.g., "pieces", "kg")
    total_cost NUMERIC,      -- Total cost for this recipe
    created_at, updated_at
)

-- 2. RECIPE ITEMS (Ingredients list)
recipe_items (
    id, recipe_id,  -- ❗ Links to RECIPES table!
    ingredient_id,   -- Links to ingredients
    quantity, unit,
    position, created_at, updated_at
)
```

**BUSINESS LOGIC (OLD REPO):**
- ✅ One product can have MULTIPLE recipes (versions)
- ✅ Recipe has `yield_quantity` (e.g., "1 batch = 24 pieces")
- ✅ Recipe can be duplicated/versioned

### **CURRENT (WRONG!):**
```sql
-- ❌ NO RECIPES TABLE!

recipe_items (
    id, product_id,  -- ❗ Links DIRECTLY to products!
    stock_item_id,   -- Links to stock
    quantity_needed, usage_unit,
    cost_per_recipe,
    position, notes,
    created_at, updated_at
)
```

**BUSINESS LOGIC (CURRENT):**
- ❌ One product = ONE recipe only
- ❌ No `yield_quantity` concept
- ❌ Can't version recipes
- ❌ Can't name recipes

**STATUS:** ❌ **OLD REPO IS CORRECT!**

---

## 🏭 **PRODUCTION MODULE**

### **OLD REPO (COMPLETE!):**
```sql
-- 1. PRODUCTION BATCHES
finished_product_batches (
    id, business_owner_id,
    product_id,
    recipe_id,  -- ✅ Links to which recipe was used!
    quantity, available_quantity,
    cost_per_unit, total_cost,
    production_date, expiry_date,
    notes, created_at, updated_at
)

-- 2. INGREDIENT USAGE TRACKING (AUDIT!)
production_ingredient_usage (
    id, business_owner_id,
    production_batch_id,
    ingredient_id,
    quantity NUMERIC,  -- ✅ What was ACTUALLY used
    unit TEXT,
    cost NUMERIC,      -- ✅ Cost at time of production
    created_at
)
```

**BUSINESS LOGIC (OLD REPO):**
- ✅ Tracks which recipe was used for production
- ✅ Records actual ingredient usage (audit trail)
- ✅ Cost snapshot at production time
- ✅ FIFO with `available_quantity`

### **CURRENT (SIMPLIFIED!):**
```sql
production_batches (
    id, business_owner_id, product_id,
    batch_number, product_name,
    quantity, remaining_qty,
    batch_date, expiry_date, notes,
    created_at, updated_at
)

-- ❌ NO production_ingredient_usage table!
-- ✅ Auto-deduction via DB function
```

**BUSINESS LOGIC (CURRENT):**
- ❌ No `recipe_id` (doesn't know which recipe version)
- ❌ No audit trail of what was used
- ❌ No cost snapshot
- ✅ Auto-deduction works (but no history)

**STATUS:** ❌ **OLD REPO IS BETTER!** (More complete audit)

---

## 💰 **COST CALCULATION**

### **OLD REPO (DETAILED!):**
```sql
products (
    -- ❌ NO cost breakdown fields
    cost_price, sale_price
)
```

### **CURRENT (ENHANCED!):**
```sql
products (
    units_per_batch INTEGER,      -- ✅ Batch size
    labour_cost NUMERIC,           -- ✅ Labour
    other_costs NUMERIC,           -- ✅ Utilities
    packaging_cost NUMERIC,        -- ✅ Packaging
    materials_cost NUMERIC,        -- ✅ Auto-calc from recipe
    total_cost_per_batch NUMERIC, -- ✅ Total
    cost_per_unit NUMERIC,        -- ✅ Per unit
    suggested_margin NUMERIC,     -- ✅ Profit %
    suggested_price NUMERIC,      -- ✅ Suggested price
    selling_price NUMERIC         -- ✅ Final price
)
```

**STATUS:** ✅ **CURRENT IS MUCH BETTER!** (Detailed costing)

---

## 🎯 **SUMMARY**

### **✅ WHAT'S BETTER IN CURRENT:**
1. ✅ Product images + categories module
2. ✅ Stock quantity tracking + movements audit
3. ✅ Detailed cost breakdown (labour, packaging, etc.)
4. ✅ Low stock alerts
5. ✅ Better costing formulas

### **❌ WHAT'S MISSING FROM OLD REPO:**
1. ❌ **RECIPES TABLE** - Should be separate from recipe_items
2. ❌ **Recipe versioning** - Can't have multiple recipes per product
3. ❌ **Yield quantity/unit** - No concept of "1 batch = 24 pieces"
4. ❌ **Production ingredient usage tracking** - No audit trail
5. ❌ **Supplier link in stock** - Can't track where ingredients came from

---

## 🚀 **RECOMMENDED FIXES**

### **PRIORITY 1: FIX RECIPES STRUCTURE** 🔥 **HIGH IMPACT!**

**Current (WRONG):**
```
Products → Recipe Items → Stock Items
```

**Should be (CORRECT):**
```
Products → Recipes → Recipe Items → Stock Items
         ↓
    (name, yield, cost)
```

**Why:**
- ✅ Can have multiple recipe versions
- ✅ Can calculate "per piece" cost
- ✅ Can duplicate/test recipes
- ✅ Better for scaling up/down

---

### **PRIORITY 2: ADD PRODUCTION USAGE TRACKING** 📊 **AUDIT TRAIL!**

**Add table:**
```sql
production_ingredient_usage (
    production_batch_id,
    stock_item_id,
    quantity_used,    -- Actual usage
    cost_at_time,     -- Price when used
    created_at
)
```

**Why:**
- ✅ Know EXACTLY what was used
- ✅ Historical cost tracking
- ✅ Variance analysis (recipe vs actual)
- ✅ Better for inventory accuracy

---

### **PRIORITY 3: ADD SUPPLIER LINK** 🏪

**Update stock_items:**
```sql
ALTER TABLE stock_items 
ADD COLUMN supplier_id UUID REFERENCES vendors(id);
```

**Why:**
- ✅ Track where ingredients come from
- ✅ Compare supplier prices
- ✅ Purchase order generation

---

## 💡 **MY RECOMMENDATION**

**NAK AKU FIX SEKARANG KE? 🔧**

**OPTION A: FIX SEKARANG** (2-3 hours)
- Restructure recipes (add recipes table)
- Add production usage tracking
- Migrate existing recipe_items
- Update UI accordingly

**OPTION B: SAMBUNG VENDOR DULU** (recommended!)
- Keep current structure (works for now)
- Build vendor system first (more business value)
- Fix recipes later when scaling

**PILIH MANA BRO?** 💬

Old repo is MORE CORRECT for recipes/production.
Current version is BETTER for products/costing.

Need to merge the best of both! 🎯

