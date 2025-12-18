# 🚀 APPLY ALL REMAINING MIGRATIONS

**Status:** Grace Transitions Cron Job ✅ Complete  
**Next:** Apply 2 remaining critical migrations

---

## 📋 MIGRATIONS TO APPLY

1. **Admin Access Control** - `add_admin_users_table.sql` (30 min)
2. **Claim Race Condition** - `fix_claim_number_race_condition.sql` (5 min)

**Total Time:** ~35 minutes

---

## 🔒 MIGRATION #1: ADMIN ACCESS CONTROL

### File: `db/migrations/add_admin_users_table.sql`

### Step 1: Apply Migration
1. **Buka Supabase Dashboard**
   - Go to: https://app.supabase.com
   - Select project anda
   - Go to **SQL Editor**

2. **Run Migration**
   - Copy **SEMUA** content dari `db/migrations/add_admin_users_table.sql`
   - Paste ke SQL Editor
   - Click **Run** atau tekan `Ctrl+Enter`
   - Wait for ✅ Success

3. **Verify Migration**
   ```sql
   -- Check table exists
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_name = 'admin_users';
   
   -- Check function exists
   SELECT routine_name 
   FROM information_schema.routines 
   WHERE routine_name = 'is_admin';
   
   -- Should return 2 rows (one with UUID param, one without)
   ```

### Step 2: Add Initial Admin Users

**Get your user UUID first:**
```sql
-- Find your user ID
SELECT id, email FROM auth.users WHERE email = 'admin@pocketbizz.my';
-- Or
SELECT id, email FROM auth.users WHERE email = 'corey@pocketbizz.my';
```

**Then add to admin_users:**
```sql
-- Replace 'user-id-here' with actual UUID from above
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  'user-id-here'::uuid,  -- Replace with actual user UUID
  'user-id-here'::uuid,  -- Self-granted (or use another admin's ID)
  TRUE,
  'Initial admin user - migrated from hardcoded list'
);
```

**Repeat for each admin email:**
- `admin@pocketbizz.my`
- `corey@pocketbizz.my`
- (Add any other admin emails)

### Step 3: Verify Admin Access
1. **Test in App:**
   - Login dengan admin email
   - Should see admin menu in drawer
   - Should be able to access admin pages

2. **Test Non-Admin:**
   - Login dengan non-admin email
   - Should NOT see admin menu
   - Should NOT be able to access admin pages

3. **Clear Cache (if needed):**
   - Admin status cached for 5 minutes
   - Wait 5 minutes atau restart app

---

## 🔧 MIGRATION #2: CLAIM RACE CONDITION FIX

### File: `db/migrations/fix_claim_number_race_condition.sql`

### Step 1: Apply Migration
1. **Buka Supabase Dashboard**
   - Go to: https://app.supabase.com
   - Select project anda
   - Go to **SQL Editor**

2. **Run Migration**
   - Copy **SEMUA** content dari `db/migrations/fix_claim_number_race_condition.sql`
   - Paste ke SQL Editor
   - Click **Run** atau tekan `Ctrl+Enter`
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

### Step 2: Test Claim Creation
1. **Test Single Claim:**
   - Create a claim normally
   - Verify claim number generated correctly
   - Format should be: `CLM-YYMM-0001`

2. **Test Concurrent Claims (if possible):**
   - Try creating multiple claims quickly
   - Verify no duplicate key errors
   - Verify all claim numbers are unique

---

## ✅ FINAL VERIFICATION CHECKLIST

After applying both migrations:

### Admin Access:
- [ ] `admin_users` table exists
- [ ] `is_admin()` function exists (both versions)
- [ ] Admin users added to `admin_users` table
- [ ] Admin access works in app
- [ ] Non-admin users cannot access admin pages
- [ ] No more "function is_admin() does not exist" errors

### Claim Race Condition:
- [ ] `generate_claim_number()` function updated
- [ ] Function uses `pg_advisory_xact_lock`
- [ ] Trigger `trigger_set_claim_number` exists
- [ ] Claim creation works without errors
- [ ] Multiple claims can be created concurrently
- [ ] No duplicate key errors

### Grace Transitions:
- [ ] Cron job created and active
- [ ] Edge Function tested successfully
- [ ] Cron job runs every hour
- [ ] Transitions work correctly

---

## 📊 SUMMARY: ALL 3 CRITICAL FIXES

| Fix | Code Status | Migration Status |
|-----|-------------|------------------|
| ✅ Grace Transitions | Done | ✅ Cron job created |
| ⏳ Admin Access Control | Done | ⏳ Apply migration |
| ⏳ Claim Race Condition | Ready | ⏳ Apply migration |

---

## 🎯 QUICK REFERENCE

### Admin Migration SQL:
```sql
-- File: db/migrations/add_admin_users_table.sql
-- Copy entire file and run in SQL Editor
```

### Claim Migration SQL:
```sql
-- File: db/migrations/fix_claim_number_race_condition.sql
-- Copy entire file and run in SQL Editor
```

---

## ⚠️ IMPORTANT NOTES

1. **Order doesn't matter** - Boleh apply dalam mana-mana order
2. **Safe to run** - Both migrations use `IF NOT EXISTS` / `DROP IF EXISTS`
3. **No data loss** - Only adds tables/functions, doesn't modify existing data
4. **Backward compatible** - Code has fallbacks if migrations not applied yet

---

## 🚀 READY TO APPLY?

1. ✅ Apply Admin Migration (30 min)
2. ✅ Add admin users
3. ✅ Apply Claim Migration (5 min)
4. ✅ Test both fixes
5. ✅ Verify all 3 critical fixes complete

---

**Status:** Ready to apply migrations ✅
