# 👤 ADD ADMIN USERS - QUICK GUIDE

**Status:** Migration applied ✅  
**Next:** Add admin users to `admin_users` table

---

## 🚀 STEP 1: GET USER UUID

Run ini dalam SQL Editor untuk dapat UUID:

```sql
-- Get user UUID for admin@pocketbizz.my
SELECT id, email FROM auth.users WHERE email = 'admin@pocketbizz.my';

-- Or for corey@pocketbizz.my
SELECT id, email FROM auth.users WHERE email = 'corey@pocketbizz.my';
```

**Copy UUID** dari result (format: `59099145-c65a-4108-bfb3-1ee61b18762f`)

---

## ✅ STEP 2: ADD ADMIN USER

Paste SQL code di bawah dan **replace UUID** dengan UUID yang anda dapat dari Step 1:

```sql
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  '59099145-c65a-4108-bfb3-1ee61b18762f'::uuid,  -- Replace dengan UUID dari Step 1
  '59099145-c65a-4108-bfb3-1ee61b18762f'::uuid,  -- Same UUID (self-granted)
  TRUE,
  'Initial admin user - migrated from hardcoded list'
);
```

**Important:**
- UUID mesti dalam **quotes** (`'...'`)
- Mesti ada `::uuid` cast di hujung
- Format: `'uuid-here'::uuid`

---

## 🔄 STEP 3: ADD MULTIPLE ADMIN USERS

Jika ada multiple admin emails, repeat Step 1 & 2 untuk setiap email:

### Example untuk 2 admins:

```sql
-- Admin 1: admin@pocketbizz.my
-- (Get UUID first, then insert)
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  'uuid-admin-1'::uuid,
  'uuid-admin-1'::uuid,
  TRUE,
  'Admin user: admin@pocketbizz.my'
);

-- Admin 2: corey@pocketbizz.my
-- (Get UUID first, then insert)
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  'uuid-corey'::uuid,
  'uuid-corey'::uuid,
  TRUE,
  'Admin user: corey@pocketbizz.my'
);
```

---

## ✅ STEP 4: VERIFY ADMIN USERS ADDED

```sql
-- Check admin users
SELECT 
  au.id,
  au.user_id,
  u.email,
  au.is_active,
  au.granted_at
FROM admin_users au
JOIN auth.users u ON u.id = au.user_id
WHERE au.is_active = TRUE;
```

**Expected:** Should see your admin users listed

---

## 🧪 STEP 5: TEST IN APP

1. **Restart app** atau **wait 5 minutes** (cache TTL)
2. **Login** dengan admin email
3. **Check:**
   - ✅ Admin menu muncul dalam drawer
   - ✅ Boleh access admin pages
   - ✅ No more "function is_admin() does not exist" errors

---

## ⚠️ COMMON ERRORS

### Error: "invalid input syntax for type uuid"
**Cause:** UUID format salah atau tidak dalam quotes  
**Fix:** Pastikan format: `'uuid-here'::uuid`

### Error: "duplicate key value violates unique constraint"
**Cause:** User sudah ada dalam `admin_users` table  
**Fix:** Check existing admins first:
```sql
SELECT * FROM admin_users WHERE user_id = 'your-uuid'::uuid;
```

### Error: "insert or update on table violates foreign key constraint"
**Cause:** UUID tidak wujud dalam `auth.users` table  
**Fix:** Verify UUID exists:
```sql
SELECT id, email FROM auth.users WHERE id = 'your-uuid'::uuid;
```

---

## 📝 CORRECT SQL FORMAT

**✅ CORRECT:**
```sql
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  '59099145-c65a-4108-bfb3-1ee61b18762f'::uuid,
  '59099145-c65a-4108-bfb3-1ee61b18762f'::uuid,
  TRUE,
  'Initial admin user'
);
```

**❌ WRONG:**
```sql
-- Missing quotes
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  59099145-c65a-4108-bfb3-1ee61b18762f::uuid,  -- ❌ No quotes
  ...
);

-- Wrong cast syntax
INSERT INTO admin_users (user_id, granted_by, is_active, notes)
VALUES (
  'user-id-here'::59099145-c65a-4108-bfb3-1ee61b18762f,  -- ❌ Wrong syntax
  ...
);
```

---

**Status:** Ready to add admin users ✅
