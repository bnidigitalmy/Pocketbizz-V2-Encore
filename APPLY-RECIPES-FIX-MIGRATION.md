# 🔧 APPLY RECIPES STRUCTURE FIX - MIGRATION GUIDE

## 🎯 **WHAT THIS FIXES:**

This migration restructures the recipes system to match the old repo's correct pattern:

**BEFORE (WRONG):**
```
Products → Recipe Items → Stock Items
```

**AFTER (CORRECT):**
```
Products → Recipes → Recipe Items → Stock Items
           ↓
      (name, yield, cost, version)
```

---

## ✅ **CHANGES INCLUDED:**

1. ✅ Creates **`recipes`** table (master recipe info)
2. ✅ Recreates **`recipe_items`** to link to recipes (not products)
3. ✅ Creates **`production_ingredient_usage`** (audit trail!)
4. ✅ Adds **`recipe_id`** to production_batches
5. ✅ Adds **`supplier_id`** to stock_items
6. ✅ Creates auto-calculation functions
7. ✅ Backups old data to `recipe_items_backup`

---

## 📝 **STEP-BY-STEP INSTRUCTIONS:**

### **STEP 1: BACKUP YOUR DATA** ⚠️
Before applying migration, manually export critical data:

1. Go to Supabase Dashboard
2. Select your project
3. Go to **Table Editor**
4. Export these tables:
   - `products`
   - `recipe_items`
   - `production_batches`

---

### **STEP 2: APPLY MIGRATION** 🚀

#### **Option A: Using SQL Editor (Recommended)**

1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Click **"New Query"**
4. **COPY** all contents from:
   ```
   db/migrations/FIX_RECIPES_STRUCTURE.sql
   ```
5. **PASTE** into SQL Editor
6. Click **"Run"** button
7. Wait for success message

#### **Option B: Using Supabase CLI**

```bash
# If you have Supabase CLI installed
supabase db reset

# Then apply specific migration
supabase db push
```

---

### **STEP 3: VERIFY MIGRATION** ✅

Run this query to check:

```sql
-- Check if new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
AND table_name IN ('recipes', 'recipe_items', 'production_ingredient_usage', 'recipe_items_backup')
ORDER BY table_name;

-- Should return 4 rows:
-- production_ingredient_usage
-- recipe_items
-- recipe_items_backup
-- recipes
```

**Expected Output:**
```
table_name
---------------------------
production_ingredient_usage
recipe_items
recipe_items_backup
recipes
```

---

### **STEP 4: TEST DATABASE FUNCTIONS** 🧪

```sql
-- Test: Create a test recipe
INSERT INTO recipes (business_owner_id, product_id, name, yield_quantity, yield_unit)
SELECT 
    id as business_owner_id,
    (SELECT id FROM products WHERE business_owner_id = users.id LIMIT 1) as product_id,
    'Test Recipe',
    24,
    'pieces'
FROM users 
WHERE email = 'admin@pocketbizz.my'
LIMIT 1
RETURNING *;

-- If this works, migration is successful! ✅
```

---

### **STEP 5: RESTART FLUTTER APP** 🔄

After migration:

```bash
# Kill existing Flutter process
# Then restart:
flutter run -d chrome
```

---

## ⚠️ **IMPORTANT NOTES:**

### **Data Loss Warning:**
- ❌ **Old `recipe_items` will be DROPPED!**
- ✅ But backed up to `recipe_items_backup`
- ❌ You'll need to **recreate recipes** in the new structure

### **Why Data Can't Be Auto-Migrated:**
Old structure had:
```sql
recipe_items (product_id → stock_item_id)
```

New structure needs:
```sql
recipes (product_id, name, yield_quantity, yield_unit)
   ↓
recipe_items (recipe_id → stock_item_id)
```

**Missing information:**
- ❌ No recipe name
- ❌ No yield quantity/unit
- ❌ No way to group items into "recipes"

**Solution:** Start fresh with proper recipe structure! 🆕

---

## 🚀 **AFTER MIGRATION:**

### **New Workflow:**

1. **Create Recipe:**
   ```dart
   recipesRepo.createRecipe(
     productId: productId,
     name: "Chocolate Cake Recipe V1",
     yieldQuantity: 24,
     yieldUnit: "pieces",
   );
   ```

2. **Add Ingredients:**
   ```dart
   recipesRepo.addRecipeItem(
     recipeId: recipeId,
     stockItemId: flourId,
     quantityNeeded: 2.5,
     usageUnit: "kg",
   );
   ```

3. **Record Production:**
   ```sql
   SELECT record_production_batch(
     business_owner_id,
     product_id,
     recipe_id,  -- ✅ Now includes recipe version!
     quantity,
     batch_date
   );
   ```

---

## 🎯 **BENEFITS OF NEW STRUCTURE:**

1. ✅ **Recipe Versioning** - Can test/duplicate recipes
2. ✅ **Yield Tracking** - Know "1 batch = 24 pieces"
3. ✅ **Cost Per Unit** - Auto-calculated from yield
4. ✅ **Production Audit** - Track what was ACTUALLY used
5. ✅ **Supplier Tracking** - Know where ingredients come from
6. ✅ **Variance Analysis** - Compare expected vs actual usage

---

## 🆘 **TROUBLESHOOTING:**

### **Error: "relation recipe_items_backup already exists"**
```sql
-- Drop and retry:
DROP TABLE IF EXISTS recipe_items_backup CASCADE;
-- Then run migration again
```

### **Error: "function calculate_recipe_cost already exists"**
```sql
-- Drop functions first:
DROP FUNCTION IF EXISTS calculate_recipe_cost CASCADE;
DROP FUNCTION IF EXISTS record_production_batch CASCADE;
-- Then run migration again
```

### **Error: "column recipe_id does not exist"**
- This means migration didn't complete
- Check SQL Editor for error messages
- Fix errors and re-run

---

## ✅ **MIGRATION CHECKLIST:**

- [ ] Backed up critical data
- [ ] Applied migration script
- [ ] Verified new tables exist
- [ ] Tested database functions
- [ ] Restarted Flutter app
- [ ] Ready to create recipes! 🎉

---

**TIME REQUIRED:** 5-10 minutes

**RISK LEVEL:** Medium (data will be reset for recipes)

**RECOMMENDATION:** Do this during non-peak hours!

---

## 📞 **NEED HELP?**

If migration fails:
1. Check Supabase logs for errors
2. Verify all prerequisite tables exist (users, products, stock_items, production_batches)
3. Ensure RLS policies aren't blocking operations
4. Contact support with error messages

---

**READY TO APPLY? BRO NAK APPLY SEKARANG? 🚀**

