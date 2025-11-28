# Deployment Scripts

Scripts untuk automate deployment PocketBizz V2 ke Encore Cloud.

## Prerequisites

1. **Encore CLI installed**
   ```bash
   # Check if installed
   encore version
   
   # If not, install from:
   # https://encore.dev/docs/install
   ```

2. **Logged in to Encore**
   ```bash
   encore auth login
   ```

3. **Secrets ready**
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_KEY`

## Usage

### Windows (PowerShell)

```powershell
# Deploy to dev environment
.\scripts\deploy.ps1 dev

# Deploy to preview environment
.\scripts\deploy.ps1 preview

# Deploy to production
.\scripts\deploy.ps1 prod
```

### Linux / Mac (Bash)

```bash
# Make script executable (first time only)
chmod +x scripts/deploy.sh

# Deploy to dev environment
./scripts/deploy.sh dev

# Deploy to preview environment
./scripts/deploy.sh preview

# Deploy to production
./scripts/deploy.sh prod
```

### NPM Scripts (Simpler)

```bash
# Deploy to dev
npm run deploy:dev

# Deploy to preview
npm run deploy:preview

# Deploy to production
npm run deploy:prod
```

## What the Scripts Do

1. ✅ Check Encore CLI installation
2. ✅ Verify authentication
3. ✅ Link app to Encore Cloud
4. ✅ Prompt for secrets (if not already set)
5. ✅ Deploy to specified environment
6. ✅ Show deployment status and next steps

## Manual Steps (If Scripts Fail)

### 1. Set Secrets

```bash
# For dev environment
encore secret set --type dev SUPABASE_URL
encore secret set --type dev SUPABASE_ANON_KEY
encore secret set --type dev SUPABASE_SERVICE_KEY

# For preview environment
encore secret set --type preview SUPABASE_URL
encore secret set --type preview SUPABASE_ANON_KEY
encore secret set --type preview SUPABASE_SERVICE_KEY
```

### 2. Link App

```bash
encore app link pocketbizz-v2-gaki
```

### 3. Deploy

```bash
encore deploy --env=dev
```

## After Deployment

1. **Get API URL**
   - Visit: https://app.encore.cloud
   - Navigate to your app → Environments → [environment]
   - Copy the API Base URL

2. **Update Android App**
   - Set `BASE_URL` in your Android app config to the Encore Cloud URL
   - Example: `https://pocketbizz-v2-gaki-dev.encr.app`

3. **Test Endpoints**
   - Use Encore Cloud Dashboard API Explorer
   - Or test with Postman/curl

## Troubleshooting

### "App is not linked"
```bash
encore app link pocketbizz-v2-gaki
```

### "Secrets not found"
Set secrets for the target environment:
```bash
encore secret set --type dev SUPABASE_URL <your-url>
```

### "Deployment failed"
- Check Encore Cloud Dashboard for error logs
- Verify all secrets are set correctly
- Ensure app is linked: `encore app link pocketbizz-v2-gaki`

## Environment Types

- **dev**: Development environment (for testing)
- **preview**: Preview environment (for staging/PR previews)
- **prod**: Production environment (live)

