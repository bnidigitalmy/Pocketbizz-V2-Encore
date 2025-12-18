# 🔧 TROUBLESHOOT: is_admin() Function Error

**Error:** `ERROR: 42883: function is_admin() does not exist`

---

## 📋 KENAPA ERROR INI MUNCUL?

Error ini muncul kerana:
1. **Migration belum dijalankan** - Function `is_admin()` belum wujud dalam database
2. **Normal behavior** - Code sepatutnya handle ini dengan fallback

---

## ✅ SOLUTION 1: JALANKAN MIGRATION (RECOMMENDED)

### Step 1: Buka Supabase Dashboard
- Go to: https://app.supabase.com
- Select project anda
- Go to **SQL Editor**

### Step 2: Run Migration
- Copy **SEMUA** content dari `db/migrations/add_admin_users_table.sql`
- Paste ke SQL Editor
- Click **Run** atau tekan `Ctrl+Enter`
- Tunggu ✅ Success message

### Step 3: Verify Function Created
```sql
-- Check function exists
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_name = 'is_admin';

-- Should return 2 rows (one with UUID param, one without)
```

---

## ✅ SOLUTION 2: CODE FALLBACK (TEMPORARY)

Jika migration belum boleh dijalankan sekarang, **code sudah handle ini automatically**:

1. **Code akan try RPC function first** → Fail (function belum wujud)
2. **Code akan try direct query** → Fail (table belum wujud)  
3. **Code akan fallback ke email whitelist** → ✅ **WORKING**

Jadi app akan terus berfungsi walaupun function belum wujud!

---

## 🔍 VERIFY CODE FALLBACK WORKING

Check logs dalam app:
```
Admin check: RPC function not available (migration not applied), trying direct query...
Admin check: Direct query failed (migration not applied), using email whitelist fallback
```

Jika nampak messages ni, bermakna fallback sedang digunakan dan app masih berfungsi.

---

## ⚠️ IMPORTANT NOTES

### Error Location:
- **Jika error dalam Supabase Dashboard SQL Editor:** Normal - function belum wujud
- **Jika error dalam App:** Code sepatutnya handle dengan fallback
- **Jika error dalam Logs:** Boleh ignore - fallback akan digunakan

### After Migration Applied:
- Error akan hilang
- Code akan use database-based check (more secure)
- Email whitelist fallback masih ada untuk backward compatibility

---

## 🧪 TEST AFTER MIGRATION

1. **Test Function Directly:**
   ```sql
   -- Test with UUID parameter
   SELECT is_admin('your-user-uuid-here');
   
   -- Test without parameter (uses current user)
   SELECT is_admin();
   ```

2. **Test in App:**
   - Login dengan admin email
   - Check admin menu muncul
   - Access admin pages

3. **Verify No More Errors:**
   - Check app logs - should NOT see "function is_admin() does not exist"
   - Should see successful admin check

---

## 📝 MIGRATION FILE UPDATED

Migration file sudah updated untuk support kedua-dua:
- `is_admin(UUID)` - dengan parameter
- `is_admin()` - tanpa parameter (uses `auth.uid()`)

Ini memastikan function boleh dipanggil dalam kedua-dua cara.

---

## 🎯 NEXT STEPS

1. ✅ **Jalankan migration** bila ready
2. ✅ **Add admin users** ke `admin_users` table
3. ✅ **Test admin access** works
4. ✅ **Verify no more errors** dalam logs

---

**Status:** Error ni normal sebelum migration. Code akan fallback automatically. ✅
