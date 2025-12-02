# 🔥 Firebase Hosting Setup untuk Flutter Web App

## Overview

Guide lengkap untuk setup Firebase Hosting untuk Flutter web app PocketBizz dengan automatic deployment via GitHub Actions.

---

## ✅ Kelebihan Firebase Hosting untuk Flutter

- ✅ Native Flutter support
- ✅ Auto-build di CI/CD (tidak perlu commit build files)
- ✅ Free tier generous (10GB storage, 360MB/day)
- ✅ Global CDN dengan SSL otomatis
- ✅ Easy setup dan reliable

---

## 📋 Prerequisites

- Firebase account (Google account)
- GitHub repository
- Flutter installed locally (untuk testing)

---

## 🚀 Setup Steps

### Step 1: Install Firebase CLI

```bash
# Install via npm
npm install -g firebase-tools

# Verify installation
firebase --version
```

**Atau** download dari: https://firebase.google.com/docs/cli#install_the_firebase_cli

---

### Step 2: Login to Firebase

```bash
firebase login
```

Follow prompts untuk login dengan Google account.

---

### Step 3: Create Firebase Project

1. **Buka:** https://console.firebase.google.com
2. **Click "Add project"** atau pilih existing project
3. **Enter project name:** `pocketbizz-web` (atau nama lain)
4. **Enable Google Analytics** (optional)
5. **Create project**

**Copy Project ID** - akan digunakan nanti!

---

### Step 4: Initialize Firebase Hosting

```bash
# Run setup script
.\scripts\setup-firebase.ps1

# Atau manual:
firebase init hosting
```

**When prompted:**
- **Select project:** Pilih project yang baru dibuat
- **Public directory:** `build/web`
- **Single-page app:** `Yes` (untuk Flutter routing)
- **Automatic builds:** `No` (kita pakai GitHub Actions)
- **Overwrite index.html:** `No` (Flutter sudah generate)

---

### Step 5: Update .firebaserc

Edit `.firebaserc` dan ganti project ID:

```json
{
  "projects": {
    "default": "your-actual-project-id"
  }
}
```

**Atau** run:
```bash
firebase use --add
# Pilih project dari list
```

---

### Step 6: Get Firebase Service Account Key

1. **Buka:** Firebase Console → Project Settings → **Service Accounts**
2. **Click "Generate new private key"**
3. **Download JSON file**
4. **Copy entire JSON content**

**⚠️ Keep this secret!** Jangan commit ke Git.

---

### Step 7: Setup GitHub Secrets

1. **Buka:** GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. **Add secrets:**

   **a. FIREBASE_SERVICE_ACCOUNT**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Paste entire JSON content dari service account key

   **b. FIREBASE_PROJECT_ID**
   - Name: `FIREBASE_PROJECT_ID`
   - Value: Your Firebase project ID (contoh: `pocketbizz-web-12345`)

---

### Step 8: Test Build Locally

```bash
# Build Flutter web
flutter build web --release

# Verify output
ls build/web/index.html
```

---

### Step 9: Test Deploy (Optional)

```bash
# Deploy to Firebase (manual test)
firebase deploy --only hosting

# Atau use script
.\scripts\deploy-firebase.ps1
```

**Check URL** yang diberikan - app should be live!

---

### Step 10: Push to GitHub

```bash
git add .
git commit -m "Setup Firebase Hosting"
git push origin main
```

**GitHub Actions akan:**
1. ✅ Build Flutter web automatically
2. ✅ Deploy to Firebase Hosting
3. ✅ App live! 🎉

---

## 🔄 Workflow Normal

Setelah setup, setiap push ke `main`:

```bash
# 1. Code changes
git add .
git commit -m "Update feature"
git push origin main

# 2. GitHub Actions auto:
#    - Build Flutter web
#    - Deploy to Firebase
#    - App updated! 🚀
```

**No manual steps needed!**

---

## 📁 Files Created

- `firebase.json` - Hosting configuration
- `.firebaserc` - Project configuration
- `.github/workflows/firebase-deploy.yml` - CI/CD workflow
- `scripts/setup-firebase.ps1` - Setup helper
- `scripts/deploy-firebase.ps1` - Manual deploy script

---

## 🛠️ Manual Deploy (Alternative)

Kalau tidak pakai GitHub Actions:

```bash
# Build
flutter build web --release

# Deploy
firebase deploy --only hosting

# Atau use script
.\scripts\deploy-firebase.ps1
```

---

## 🔍 Troubleshooting

### "Firebase CLI not found"
```bash
npm install -g firebase-tools
```

### "Not logged in"
```bash
firebase login
```

### "Project not found"
- Check `.firebaserc` project ID
- Run: `firebase use --add`

### "Build failed in GitHub Actions"
- Check Flutter version compatibility
- Verify `pubspec.yaml` dependencies
- Check GitHub Actions logs

### "Deployment failed"
- Verify `FIREBASE_SERVICE_ACCOUNT` secret is correct JSON
- Check `FIREBASE_PROJECT_ID` matches your project
- Verify service account has Hosting permissions

---

## 📋 Checklist

- [ ] Firebase CLI installed
- [ ] Logged in to Firebase
- [ ] Firebase project created
- [ ] `.firebaserc` updated with project ID
- [ ] Service account key generated
- [ ] GitHub Secrets configured:
  - [ ] `FIREBASE_SERVICE_ACCOUNT`
  - [ ] `FIREBASE_PROJECT_ID`
- [ ] Test build locally: `flutter build web --release`
- [ ] Test deploy (optional): `firebase deploy --only hosting`
- [ ] Push to GitHub → Auto-deploy! 🎉

---

## 🎯 Quick Start

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Run setup script
.\scripts\setup-firebase.ps1

# 4. Create Firebase project (via console)
# 5. Update .firebaserc with project ID
# 6. Setup GitHub Secrets
# 7. Push to GitHub → Done! 🚀
```

---

## 📚 Resources

- Firebase Hosting Docs: https://firebase.google.com/docs/hosting
- Flutter Web: https://docs.flutter.dev/platform-integration/web
- GitHub Actions: https://docs.github.com/en/actions

---

**Selamat! Firebase Hosting setup complete!** 🎉

