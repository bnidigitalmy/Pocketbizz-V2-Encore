# 🔒 FIX SECURITY ISSUES - QUICK GUIDE

**Priority:** 🔴 **CRITICAL** - Fix immediately before production

---

## 🚨 ISSUES FOUND

### 1. Hardcoded Supabase Credentials
- **Files:** `main.dart`, `image_upload_service.dart`, `document_storage_service.dart`, `receipt_storage_service.dart`, `announcement_media_service.dart`
- **Risk:** Credentials exposed in code

### 2. Hardcoded Password in Test File
- **File:** `lib/main_simple.dart`
- **Risk:** Real admin password exposed

### 3. Hardcoded Google OAuth Client ID
- **File:** `lib/core/config/app_config.dart`
- **Risk:** Medium (acceptable but should use env vars)

---

## ✅ FIXES APPLIED

### 1. Added `flutter_dotenv` Package ✅
- Added to `pubspec.yaml`
- Added `.env` to assets

### 2. Created Environment Config ✅
- Created `lib/core/config/env_config.dart`
- Created `.env.example` template

### 3. Updated Code to Use Environment Variables ✅
- Updated `main.dart` to load env vars
- Updated all service files to use env vars
- Updated `app_config.dart` to use env vars

### 4. Updated `.gitignore` ✅
- Ensured `.env*` files are ignored (except `.env.example`)

---

## 🚀 NEXT STEPS (MANUAL)

### Step 1: Install Package
```bash
flutter pub get
```

### Step 2: Create `.env` File
Copy `.env.example` to `.env` and fill in values:

```env
# Supabase Configuration
SUPABASE_URL=https://gxllowlurizrkvpdircw.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs

# Google OAuth (Optional)
GOOGLE_OAUTH_CLIENT_ID=214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com
```

**Important:** 
- ✅ `.env` file is already in `.gitignore`
- ✅ Never commit `.env` to git
- ✅ Use different values for dev/prod

### Step 3: Remove Test File (CRITICAL)
**Option A: Delete the file**
```bash
# Delete test file with password
rm lib/main_simple.dart
```

**Option B: Add to .gitignore (if keeping for local testing)**
Add to `.gitignore`:
```
lib/main_simple.dart
```

**Recommendation:** Delete it - it contains real password!

### Step 4: Test
1. Create `.env` file with your credentials
2. Run `flutter pub get`
3. Test app - should work with env vars
4. Verify no hardcoded credentials in code

---

## ✅ VERIFICATION

### Check No Hardcoded Credentials:
```bash
# Search for hardcoded Supabase URL
grep -r "gxllowlurizrkvpdircw" lib/ --exclude-dir=build

# Search for hardcoded anon key
grep -r "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" lib/ --exclude-dir=build

# Should only find in .env file (which is gitignored)
```

### Check Test File Removed:
```bash
# Should not exist or be gitignored
ls lib/main_simple.dart
```

---

## 🎯 PRODUCTION DEPLOYMENT

### For Firebase Hosting (Web):
1. Set environment variables in Firebase Console
2. Or use build-time environment variables
3. Never commit `.env` to repository

### For Mobile Apps:
1. Use different approach (not `.env` file)
2. Use build configuration files
3. Or use secure storage for secrets

**Note:** For Flutter web, `.env` file works. For mobile, consider using:
- `flutter_config` package
- Build-time environment variables
- Secure storage

---

## 📋 CHECKLIST

- [ ] Install `flutter_dotenv` package (`flutter pub get`)
- [ ] Create `.env` file from `.env.example`
- [ ] Fill in actual Supabase credentials
- [ ] Delete or gitignore `lib/main_simple.dart`
- [ ] Test app with environment variables
- [ ] Verify no hardcoded credentials remain
- [ ] Commit changes (without `.env` file)

---

**Status:** Code updated ✅ - Manual steps required to complete
