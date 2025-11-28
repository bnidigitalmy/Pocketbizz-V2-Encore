# PocketBizz V2 - Deployment Guide

## Cara Deploy ke Encore Cloud

Untuk Encore.ts, deployment dilakukan melalui **Git push** atau **Encore Cloud Dashboard**.

### Method 1: Git Push (Recommended - Automatic)

1. **Connect GitHub repo ke Encore Cloud**
   - Buka: https://app.encore.cloud
   - Navigate ke: App → Integrations → GitHub
   - Connect repository anda

2. **Set Secrets untuk Environment**
   ```bash
   # Set untuk dev environment
   encore secret set --type dev SUPABASE_URL
   encore secret set --type dev SUPABASE_ANON_KEY
   encore secret set --type dev SUPABASE_SERVICE_KEY
   ```

3. **Push ke GitHub**
   ```bash
   git add .
   git commit -m "Deploy to Encore Cloud"
   git push origin main
   ```
   
   Encore akan automatically deploy setiap kali push ke branch yang connected.

### Method 2: Encore Cloud Dashboard (Manual)

1. **Buka Encore Cloud Dashboard**
   - https://app.encore.cloud
   - Login ke account anda

2. **Navigate ke App**
   - Pilih app: `pocketbizz-v2-gaki`
   - Klik pada environment yang nak deploy (dev/preview/prod)

3. **Set Secrets**
   - Settings → Secrets
   - Add secrets untuk environment:
     - `SUPABASE_URL`
     - `SUPABASE_ANON_KEY`
     - `SUPABASE_SERVICE_KEY`

4. **Deploy via Dashboard**
   - Klik "Deploy" button
   - Atau upload code manually (zip file)

### Method 3: Encore CLI (Jika Support)

Check jika CLI version support deploy:
```bash
encore --help
```

Kalau ada `deploy` command:
```bash
encore deploy --env=dev
```

**Note**: Untuk Encore.ts, biasanya deployment melalui Git push adalah cara yang paling mudah dan automatic.

## Setup Secrets

### Local Environment
```bash
encore secret set --type local SUPABASE_URL
encore secret set --type local SUPABASE_ANON_KEY
encore secret set --type local SUPABASE_SERVICE_KEY
```

### Dev Environment
```bash
encore secret set --type dev SUPABASE_URL
encore secret set --type dev SUPABASE_ANON_KEY
encore secret set --type dev SUPABASE_SERVICE_KEY
```

### Preview Environment
```bash
encore secret set --type preview SUPABASE_URL
encore secret set --type preview SUPABASE_ANON_KEY
encore secret set --type preview SUPABASE_SERVICE_KEY
```

## Check Deployment Status

1. **Via Dashboard**
   - https://app.encore.cloud
   - Navigate ke app → Environments → [environment]
   - Check deployment logs dan status

2. **Via CLI**
   ```bash
   encore env list
   ```

## Get API URL

Lepas deploy, dapatkan API URL:

1. Buka Encore Cloud Dashboard
2. Navigate ke: App → Environments → [environment]
3. Copy **API Base URL**
   - Example: `https://pocketbizz-v2-gaki-dev.encr.app`

4. **Update Android App**
   - Set `BASE_URL` dalam app config ke URL yang dapat
   - Example: `https://pocketbizz-v2-gaki-dev.encr.app`

## Troubleshooting

### "unknown command deploy"
- Encore CLI version mungkin tak support `deploy` command
- Guna **Git push** atau **Dashboard** method instead

### "Secrets not found"
- Set secrets untuk target environment
- Check di Dashboard: Settings → Secrets

### "App not linked"
```bash
encore app link pocketbizz-v2-gaki
```

### Deployment failed
- Check logs di Encore Cloud Dashboard
- Verify semua secrets dah set
- Check code compilation errors

## Quick Start

1. **Set secrets untuk dev:**
   ```bash
   encore secret set --type dev SUPABASE_URL <your-url>
   encore secret set --type dev SUPABASE_ANON_KEY <your-key>
   encore secret set --type dev SUPABASE_SERVICE_KEY <your-key>
   ```

2. **Connect GitHub repo** (di Encore Cloud Dashboard)

3. **Push code:**
   ```bash
   git push origin main
   ```

4. **Check deployment** di Encore Cloud Dashboard

Done! 🎉

