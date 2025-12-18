# 🔧 APPLY CLAIM NUMBER RACE CONDITION FIX

**Purpose:** Fix duplicate key errors when multiple users create claims simultaneously

---

## 📋 WHAT THIS FIXES

**Problem:**
- Race condition dalam claim number generation
- Multiple users boleh dapat same claim number jika create serentak
- Error: "duplicate key value violates unique constraint"

**Solution:**
- Uses PostgreSQL advisory locks untuk prevent concurrent access
- Lock key based on year+month (allows parallel inserts for different months)
- Thread-safe claim number generation

---

## 🚀 STEP 1: APPLY DATABASE MIGRATION

### File: `db/migrations/fix_claim_number_race_condition.sql`

1. **Open Supabase Dashboard**
   - Go to: https://app.supabase.com
   - Select your project
   - Go to **SQL Editor**

2. **Run Migration**
   - Copy entire contents of `fix_claim_number_race_condition.sql`
   - Paste into SQL Editor
   - Click **Run** or press `Ctrl+Enter`
   - Wait for ✅ Success

3. **Verify Migration**
   ```sql
   -- Check function exists and updated
   SELECT proname, prosrc 
   FROM pg_proc 
   WHERE proname = 'generate_claim_number';
   
   -- Should show function with pg_advisory_xact_lock
   
   -- Check trigger exists
   SELECT tgname, tgrelid::regclass 
   FROM pg_trigger 
   WHERE tgname = 'trigger_set_claim_number';
   
   -- Should return 1 row
   ```

---

## ✅ STEP 2: TEST THE FIX

1. **Test Single Claim Creation**
   - Create a claim normally
   - Verify claim number generated correctly
   - Format should be: `CLM-YYMM-0001`

2. **Test Concurrent Claims** (if possible)
   - Try creating multiple claims quickly
   - Verify no duplicate key errors
   - Verify all claim numbers are unique

---

## 🔍 HOW IT WORKS

**Before:**
```sql
-- No locking - race condition possible
SELECT MAX(...) + 1 FROM consignment_claims
-- Two transactions can get same MAX value
```

**After:**
```sql
-- Advisory lock prevents concurrent access
PERFORM pg_advisory_xact_lock(lock_key);
SELECT MAX(...) + 1 FROM consignment_claims
-- Lock released automatically at end of transaction
```

**Lock Key:**
- Based on year+month (e.g., 202501)
- Allows parallel inserts for different months
- Prevents conflicts within same month

---

## ⚠️ IMPORTANT NOTES

- **Safe to run:** Uses `DROP FUNCTION IF EXISTS` - won't break existing code
- **No data loss:** Only updates function logic, doesn't affect existing data
- **Performance:** Minimal impact - only locks during claim number generation
- **Backward compatible:** Function signature same, only internal logic changed

---

## 📝 CODE CHANGES

**No code changes needed** - this is a database-only fix. The function is called automatically by trigger.

---

**Status:** Ready to apply migration ✅
