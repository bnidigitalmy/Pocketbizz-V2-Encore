# 🌐 Firebase Custom Domain Setup - app.pocketbizz.my

## Overview

Guide untuk setup custom domain `app.pocketbizz.my` dari Shinjiru untuk Firebase Hosting.

---

## 📋 Prerequisites

- ✅ Firebase Hosting sudah setup
- ✅ Domain `pocketbizz.my` managed di Shinjiru
- ✅ Access ke Shinjiru DNS management

---

## 🚀 Setup Steps

### Step 1: Add Custom Domain di Firebase

1. **Buka Firebase Console:**
   ```
   https://console.firebase.google.com/project/pocketbizz-web-flutter/hosting
   ```

2. **Click "Add custom domain"** (atau "Connect domain")

3. **Enter domain:**
   - Type: `app.pocketbizz.my`
   - Click "Continue"

4. **Firebase akan show DNS records yang perlu di-set:**
   - A record atau AAAA records
   - TXT record untuk verification

5. **Copy semua DNS records** yang Firebase berikan

---

### Step 2: Configure DNS di Shinjiru

1. **Login ke Shinjiru:**
   - Buka: https://www.shinjiru.com (atau panel Shinjiru kamu)
   - Login ke account

2. **Navigate ke DNS Management:**
   - Go to Domain Management
   - Select domain: `pocketbizz.my`
   - Click "DNS Management" atau "DNS Settings"

3. **Add DNS Records:**

   **A. A Record (IPv4):**
   - **Type:** A
   - **Name/Host:** `app` (atau `app.pocketbizz.my` - depends on Shinjiru format)
   - **Value/TTL:** IP addresses dari Firebase (biasanya 2 IPs)
   - **TTL:** 3600 (atau default)

   **B. AAAA Record (IPv6) - Optional:**
   - **Type:** AAAA
   - **Name/Host:** `app`
   - **Value:** IPv6 addresses dari Firebase (jika ada)

   **C. TXT Record (Verification):**
   - **Type:** TXT
   - **Name/Host:** `app` (atau `_firebase` - depends on Firebase instruction)
   - **Value:** TXT value dari Firebase
   - **TTL:** 3600

4. **Save DNS records**

---

### Step 3: Verify Domain di Firebase

1. **Kembali ke Firebase Console**
2. **Click "Verify"** atau wait untuk auto-verification
3. **Firebase akan check DNS records**
4. **Verification biasanya take 5-30 minutes**

**Note:** DNS propagation boleh take up to 48 hours, tapi biasanya 5-30 minutes.

---

### Step 4: SSL Certificate (Automatic)

1. **Firebase akan automatically request SSL certificate** setelah domain verified
2. **SSL setup biasanya take 10-60 minutes**
3. **Status akan show "Provisioning" → "Active"**

---

### Step 5: Finalize Setup

1. **Wait untuk SSL certificate active**
2. **Firebase akan show "Domain connected"**
3. **Test domain:**
   ```
   https://app.pocketbizz.my
   ```

---

## 🔍 DNS Records Format (Example)

Firebase biasanya akan kasih records seperti ini:

### A Records:
```
Type: A
Name: app
Value: 151.101.1.195
Value: 151.101.65.195
TTL: 3600
```

### TXT Record (Verification):
```
Type: TXT
Name: app (atau _firebase)
Value: firebase=xxxxxxxxxxxxx
TTL: 3600
```

**⚠️ Important:** Copy exact values dari Firebase Console!

---

## 📝 Shinjiru DNS Management Guide

### Format di Shinjiru biasanya:

**Option A: Subdomain format**
- **Host:** `app`
- **Type:** A
- **Points to:** `151.101.1.195`

**Option B: Full domain format**
- **Host:** `app.pocketbizz.my`
- **Type:** A
- **Points to:** `151.101.1.195`

**Check Shinjiru documentation** untuk exact format mereka.

---

## 🔄 After DNS Setup

### Check DNS Propagation:

```bash
# Check A record
nslookup app.pocketbizz.my

# Check TXT record
nslookup -type=TXT app.pocketbizz.my
```

**Or use online tools:**
- https://dnschecker.org
- https://mxtoolbox.com

---

## ✅ Verification Checklist

- [ ] DNS A records added di Shinjiru
- [ ] DNS TXT record added di Shinjiru
- [ ] DNS records propagated (check dengan nslookup)
- [ ] Domain verified di Firebase
- [ ] SSL certificate provisioned
- [ ] Domain status: "Connected" di Firebase
- [ ] Test: `https://app.pocketbizz.my` works

---

## 🐛 Troubleshooting

### "Domain verification failed"

**Problem:** DNS records tidak betul atau belum propagated

**Fix:**
1. Double-check DNS records di Shinjiru
2. Verify values match Firebase exactly
3. Wait 10-30 minutes untuk DNS propagation
4. Check dengan `nslookup` atau DNS checker tools
5. Try verify again di Firebase

### "SSL certificate provisioning failed"

**Problem:** DNS tidak fully propagated atau domain tidak accessible

**Fix:**
1. Ensure domain verified first
2. Wait untuk DNS fully propagated
3. Check domain accessible: `http://app.pocketbizz.my` (before SSL)
4. Retry SSL provisioning di Firebase

### "Domain not resolving"

**Problem:** DNS records tidak betul atau TTL too high

**Fix:**
1. Verify A records correct
2. Check TTL (lower to 300-600 untuk faster propagation)
3. Clear DNS cache: `ipconfig /flushdns` (Windows)
4. Wait untuk propagation

---

## 📚 Resources

- Firebase Custom Domain: https://firebase.google.com/docs/hosting/custom-domain
- Shinjiru Support: Check Shinjiru documentation untuk DNS management
- DNS Checker: https://dnschecker.org

---

## 🎯 Quick Summary

1. **Firebase Console** → Add custom domain `app.pocketbizz.my`
2. **Copy DNS records** dari Firebase
3. **Shinjiru DNS** → Add A records dan TXT record
4. **Wait** untuk DNS propagation (5-30 min)
5. **Verify** di Firebase
6. **Wait** untuk SSL (10-60 min)
7. **Done!** `https://app.pocketbizz.my` live! 🎉

---

**Selamat! Custom domain setup complete!** 🚀

