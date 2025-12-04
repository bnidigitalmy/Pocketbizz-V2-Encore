# 🔄 CLAIMS MODULE - MIGRATION GUIDE

## ✅ UI UPDATES - COMPLETED

### **1. Main App Routes** ✅
- Updated `lib/main.dart` to use new simplified page
- Route `/claims/create` now uses `CreateClaimSimplifiedPage`
- Old page kept at `/claims/create-old` for reference

### **2. Navigation Updates Needed**
Check these files and update if they navigate to create claim:
- `lib/features/claims/presentation/claims_page.dart` - Main claims list page
- Any other pages that navigate to create claim

---

## 🗄️ DATABASE MIGRATIONS

### **Migration 1: Fix Claim Number Race Condition** ⚠️ REQUIRED

**File:** `db/migrations/fix_claim_number_race_condition.sql`

**Purpose:** Fix duplicate key errors when multiple users create claims simultaneously

**What it does:**
- Updates `generate_claim_number()` function to use PostgreSQL advisory locks
- Prevents race conditions when generating claim numbers
- Allows parallel inserts for different months

**How to Apply:**
1. Open Supabase SQL Editor
2. Copy contents of `fix_claim_number_race_condition.sql`
3. Run the SQL script
4. Verify function updated:
   ```sql
   SELECT proname FROM pg_proc WHERE proname = 'generate_claim_number';
   ```

**Status:** ⚠️ **NOT APPLIED YET** - Need to run in Supabase

---

## 📋 MIGRATION CHECKLIST

### **Database Migrations:**
- [ ] Run `fix_claim_number_race_condition.sql` in Supabase SQL Editor
- [ ] Verify `generate_claim_number()` function exists
- [ ] Verify trigger `trigger_set_claim_number` exists
- [ ] Test creating multiple claims simultaneously (should not error)

### **Code Updates:**
- [x] Update `main.dart` routes
- [ ] Update `claims_page.dart` navigation (if needed)
- [ ] Test new simplified flow
- [ ] Remove old page (optional, after testing)

---

## 🧪 TESTING CHECKLIST

### **Before Migration:**
- [ ] Backup database (Supabase auto-backups)
- [ ] Test current claim creation (should work but may have race condition errors)

### **After Migration:**
- [ ] Test creating single claim
- [ ] Test creating multiple claims quickly (simulate race condition)
- [ ] Verify claim numbers are unique
- [ ] Test new simplified UI flow
- [ ] Test validation messages
- [ ] Test error handling

---

## 🚨 IMPORTANT NOTES

### **Race Condition Fix:**
- **CRITICAL:** This migration fixes the duplicate key error you were experiencing
- **SAFE:** Uses advisory locks - won't block other operations
- **PERFORMANCE:** Minimal impact - only locks during claim number generation

### **UI Changes:**
- New simplified page is now the default
- Old page still available at `/claims/create-old` for reference
- Can switch back if needed by changing route

---

## 📝 STEP-BY-STEP MIGRATION

### **Step 1: Apply Database Migration**
```sql
-- Run in Supabase SQL Editor
-- File: db/migrations/fix_claim_number_race_condition.sql
```

### **Step 2: Verify Migration**
```sql
-- Check function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'generate_claim_number';

-- Check trigger exists
SELECT tgname, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'trigger_set_claim_number';
```

### **Step 3: Test**
1. Create a test claim
2. Verify claim number generated correctly
3. Try creating multiple claims quickly
4. Verify no duplicate key errors

### **Step 4: Update Navigation (if needed)**
Check `claims_page.dart` for any direct navigation to create page and update if needed.

---

## 🔍 VERIFICATION QUERIES

### **Check Claim Numbers:**
```sql
SELECT claim_number, created_at 
FROM consignment_claims 
ORDER BY created_at DESC 
LIMIT 10;
```

### **Check for Duplicates:**
```sql
SELECT claim_number, COUNT(*) 
FROM consignment_claims 
GROUP BY claim_number 
HAVING COUNT(*) > 1;
```

### **Check Function:**
```sql
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'generate_claim_number';
```

---

## ✅ SUCCESS CRITERIA

After migration, you should be able to:
- ✅ Create claims without duplicate key errors
- ✅ Create multiple claims simultaneously without conflicts
- ✅ Use new simplified UI flow
- ✅ See clear validation messages
- ✅ Preview claim summary before creating

---

**Status:** Ready for migration! 🚀

