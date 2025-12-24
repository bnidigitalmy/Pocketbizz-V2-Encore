# 📱 Cara Test PocketBizz di Phone

## 🚀 Option 1: Test PWA di Phone Browser (Paling Cepat - TAK PERLU DEPLOY)

### Step 1: Run Flutter Web di Local Network

```bash
# Run Flutter web dengan network access
flutter run -d chrome --web-port=8080 --web-hostname=0.0.0.0
```

**ATAU** kalau nak specify IP address:

```bash
# Dapat IP address dulu
# Windows:
ipconfig
# Mac/Linux:
ifconfig

# Run dengan IP address (contoh: 192.168.1.100)
flutter run -d chrome --web-port=8080 --web-hostname=192.168.1.100
```

### Step 2: Access dari Phone

1. **Pastikan phone dan computer dalam same WiFi network**
2. **Buka browser di phone** (Chrome/Safari)
3. **Masuk URL:** `http://192.168.1.100:8080` (ganti dengan IP address computer kamu)

### Step 3: Test Document Scanner

- ✅ Camera access akan work di phone browser
- ✅ Document cropping akan work
- ✅ OCR akan work (via Edge Function)
- ✅ PDF generation akan work

**Pros:**
- ✅ Tak perlu build atau deploy
- ✅ Hot reload masih boleh guna
- ✅ Cepat untuk test

**Cons:**
- ⚠️ Kena dalam same network
- ⚠️ Computer kena on dan run Flutter

---

## 📦 Option 2: Build APK untuk Android (Native App)

### Step 1: Build Debug APK

```bash
# Build debug APK (lebih cepat, untuk testing)
flutter build apk --debug

# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Step 2: Transfer ke Phone

**Cara 1: USB Cable**
```bash
# Connect phone via USB
# Enable USB debugging di phone
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**Cara 2: Share via Cloud/Email**
1. Upload APK ke Google Drive/Dropbox
2. Download dari phone
3. Install APK (enable "Install from unknown sources" di phone settings)

### Step 3: Build Release APK (Optional - untuk production testing)

```bash
# Build release APK (optimized, lebih besar size)
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Pros:**
- ✅ Test sebagai native app
- ✅ Boleh test offline
- ✅ Performance lebih baik

**Cons:**
- ⚠️ Kena build setiap kali nak update
- ⚠️ Tak ada hot reload

---

## 🍎 Option 3: Build untuk iOS (Native App)

### Requirements:
- Mac computer dengan Xcode
- Apple Developer Account (free account pun boleh untuk testing)

### Step 1: Build IPA

```bash
# Build untuk iOS device
flutter build ipa --debug

# Output: build/ios/ipa/*.ipa
```

### Step 2: Install via Xcode

1. Open Xcode
2. **Window** → **Devices and Simulators**
3. Connect iPhone via USB
4. Drag & drop IPA file ke device

**ATAU** guna TestFlight (untuk distribution):
1. Upload ke App Store Connect
2. Add testers
3. Install via TestFlight app

**Pros:**
- ✅ Native iOS experience
- ✅ Boleh test semua iOS features

**Cons:**
- ⚠️ Kena Mac + Xcode
- ⚠️ Setup lebih complex

---

## 🌐 Option 4: Deploy ke Web Hosting (PWA - Recommended untuk Production)

### Quick Deploy ke Firebase Hosting

```bash
# 1. Build web
flutter build web --release

# 2. Deploy ke Firebase
firebase deploy --only hosting

# 3. Access dari phone: https://your-app.web.app
```

### Quick Deploy ke Vercel

```bash
# 1. Build web
flutter build web --release

# 2. Deploy ke Vercel
vercel --prod

# 3. Access dari phone: https://your-app.vercel.app
```

**Pros:**
- ✅ Public URL - boleh test dari mana-mana
- ✅ PWA support - boleh install ke home screen
- ✅ Auto-update - setiap deploy, user dapat update

**Cons:**
- ⚠️ Kena deploy setiap kali nak update
- ⚠️ Kena setup hosting account

---

## 🎯 Recommended Workflow untuk Development

### Untuk Quick Testing:
```bash
# Option 1: PWA di local network (paling cepat)
flutter run -d chrome --web-port=8080 --web-hostname=0.0.0.0
```

### Untuk Production Testing:
```bash
# Option 4: Deploy ke Firebase/Vercel
flutter build web --release
firebase deploy --only hosting
```

---

## 📋 Checklist Test Document Scanner di Phone

- [ ] Camera access works
- [ ] Image capture works
- [ ] Document cropping UI works (drag corners)
- [ ] Auto edge detection works
- [ ] OCR processing works
- [ ] PDF generation works
- [ ] File upload ke Supabase works
- [ ] Expense creation dengan document URLs works

---

## 🐛 Troubleshooting

### Issue: Phone tak boleh connect ke local server
**Fix:**
1. Check firewall - allow port 8080
2. Pastikan phone dan computer dalam same WiFi
3. Try guna IP address instead of localhost

### Issue: Camera tak work di phone browser
**Fix:**
1. Pastikan guna HTTPS (atau localhost)
2. Check browser permissions - allow camera access
3. Try different browser (Chrome recommended)

### Issue: APK install failed
**Fix:**
1. Enable "Install from unknown sources" di phone
2. Check Android version compatibility
3. Try uninstall existing app first

---

## 💡 Tips

1. **Untuk development:** Guna Option 1 (local network) - paling cepat
2. **Untuk testing dengan team:** Guna Option 4 (deploy) - boleh share URL
3. **Untuk production:** Guna Option 4 (deploy) + Option 2/3 (native apps)




