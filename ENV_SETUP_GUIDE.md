# 🔐 ENVIRONMENT VARIABLES SETUP GUIDE

**Purpose:** Secure configuration management untuk production

---

## 🚀 QUICK SETUP

### Step 1: Install Package
```bash
flutter pub get
```

### Step 2: Create `.env` File

Create `.env` file in project root dengan content:

```env
# Supabase Configuration
SUPABASE_URL=https://gxllowlurizrkvpdircw.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs

# Google OAuth (Optional)
GOOGLE_OAUTH_CLIENT_ID=214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com
```

**Important:**
- ✅ `.env` file is in `.gitignore` (won't be committed)
- ✅ Never commit `.env` to git
- ✅ Use different values for dev/prod environments

### Step 3: Test
```bash
flutter run
```

App should load dengan environment variables.

---

## 🔒 SECURITY NOTES

### What Changed:
- ✅ Supabase credentials moved to `.env`
- ✅ All service files updated to use env vars
- ✅ Fallback to hardcoded values (for development only)
- ⚠️ **Warning shown if using hardcoded values**

### For Production:
1. **Create `.env` file** with production credentials
2. **Never commit** `.env` to git
3. **Use different** credentials for dev/prod
4. **Rotate keys** if exposed

---

## 📋 FILES UPDATED

- ✅ `pubspec.yaml` - Added `flutter_dotenv` package
- ✅ `lib/main.dart` - Uses environment variables
- ✅ `lib/core/config/env_config.dart` - New config class
- ✅ `lib/core/services/image_upload_service.dart` - Uses env vars
- ✅ `lib/core/services/document_storage_service.dart` - Uses env vars
- ✅ `lib/core/services/receipt_storage_service.dart` - Uses env vars
- ✅ `lib/core/services/announcement_media_service.dart` - Uses env vars
- ✅ `lib/core/config/app_config.dart` - Uses env vars
- ✅ `.gitignore` - Ensures `.env*` files ignored

---

## ⚠️ CRITICAL: Remove Test File

**File:** `lib/main_simple.dart` contains **real admin password**!

**Action Required:**
```bash
# Option 1: Delete the file
rm lib/main_simple.dart

# Option 2: Add to .gitignore (if keeping for local testing)
echo "lib/main_simple.dart" >> .gitignore
```

**Recommendation:** Delete it - contains real password!

---

## ✅ VERIFICATION

### Check Environment Variables Load:
```dart
// In app, check if env vars loaded
print('Supabase URL: ${dotenv.env['SUPABASE_URL']}');
```

### Check No Hardcoded Credentials:
```bash
# Should not find hardcoded URL (except in .env)
grep -r "gxllowlurizrkvpdircw" lib/ --exclude-dir=build
```

---

**Status:** Code updated ✅ - Create `.env` file to complete setup
