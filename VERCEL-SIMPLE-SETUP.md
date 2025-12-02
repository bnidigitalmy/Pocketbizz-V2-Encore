# 🚀 Vercel Simple Setup (Tanpa Kompleks)

## ✅ Masih Boleh Guna Vercel!

Kita dah remove setup yang complex, tapi masih boleh guna Vercel dengan cara **simple**:

---

## 🎯 Cara Simple: Pre-built Files

### Step 1: Build Flutter Web

```bash
flutter build web --release
```

### Step 2: Commit Build Files (Temporary)

```bash
# Uncomment build/ di .gitignore (temporary)
# Edit .gitignore, ganti:
# build/  →  # build/

# Commit build files
git add build/web
git commit -m "Add Flutter web build for Vercel"
git push origin main
```

### Step 3: Setup Vercel di Dashboard

1. **Buka:** https://vercel.com/dashboard
2. **Add New Project** → **Import Git Repository**
3. **Pilih GitHub repo:** `Pocketbizz-V2-Encore`
4. **Configure:**
   - **Framework Preset:** Other
   - **Root Directory:** `.` (current)
   - **Build Command:** *(kosongkan - skip build)*
   - **Output Directory:** `build/web` ✅
   - **Install Command:** *(kosongkan - skip install)*
5. **Deploy!**

### Step 4: Auto-Deploy

Setelah setup, setiap kali push `build/web` ke GitHub:
- ✅ Vercel akan auto-deploy
- ✅ No build needed (sudah pre-built)
- ✅ Simple dan reliable!

---

## 🔄 Workflow Simple

```bash
# 1. Update code
# 2. Build web
flutter build web --release

# 3. Commit build (temporary uncomment build/ di .gitignore)
git add build/web
git commit -m "Update web build"
git push origin main

# 4. Vercel auto-deploy! 🎉
```

---

## 💡 Alternative: Manual Deploy (No Git)

Kalau tak nak commit build files:

```bash
# 1. Build
flutter build web --release

# 2. Deploy manual via CLI
vercel --prod

# 3. Done! URL akan diberikan
```

**Pros:** No need commit build files
**Cons:** Manual step setiap kali

---

## 📋 Checklist Setup Vercel Simple

- [ ] Build Flutter: `flutter build web --release`
- [ ] Uncomment `build/` di .gitignore (temporary)
- [ ] Commit build files
- [ ] Push to GitHub
- [ ] Setup Vercel di dashboard (import GitHub repo)
- [ ] Configure: Output Directory = `build/web`
- [ ] Deploy!

---

## 🎯 Perbezaan

**Before (Complex):**
- ❌ GitHub Actions workflow
- ❌ Auto build di Vercel (tapi Vercel tak ada Flutter)
- ❌ Complex setup dengan secrets
- ❌ Banyak troubleshooting

**Now (Simple):**
- ✅ Build lokal dulu
- ✅ Commit build files
- ✅ Vercel just serve files
- ✅ Simple dan reliable!

---

## 🚀 Quick Start

Kalau nak setup Vercel sekarang:

1. **Build:**
   ```bash
   flutter build web --release
   ```

2. **Uncomment build/ di .gitignore:**
   ```gitignore
   # build/  # Temporarily uncommented for Vercel
   ```

3. **Commit & Push:**
   ```bash
   git add build/web .gitignore
   git commit -m "Add web build for Vercel deployment"
   git push origin main
   ```

4. **Setup Vercel:**
   - Dashboard → Import GitHub repo
   - Output Directory: `build/web`
   - Deploy!

**Done!** 🎉

---

## 📝 Note

- Build files akan besar (~10-20MB)
- Tapi simple dan reliable
- Kalau nak, boleh guna hosting lain juga (Firebase, Netlify, etc.)

---

**Masih boleh guna Vercel, cuma dengan cara yang lebih simple!** ✅


