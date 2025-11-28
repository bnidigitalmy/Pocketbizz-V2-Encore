# PocketBizz V2 - Encore Cloud Deployment Script
# Usage: .\scripts\deploy.ps1 [dev|preview|prod]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "preview", "prod")]
    [string]$Environment = "dev"
)

Write-Host "🚀 PocketBizz V2 - Encore Cloud Deployment" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Step 1: Check if encore CLI is installed
Write-Host "📋 Step 1: Checking Encore CLI..." -ForegroundColor Cyan
try {
    $encoreVersion = encore version 2>&1
    Write-Host "✅ Encore CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Encore CLI not found. Please install from https://encore.dev/docs/install" -ForegroundColor Red
    exit 1
}

# Step 2: Check if user is logged in
Write-Host ""
Write-Host "📋 Step 2: Checking authentication..." -ForegroundColor Cyan
try {
    $whoami = encore auth whoami 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Authenticated: $whoami" -ForegroundColor Green
    } else {
        Write-Host "❌ Not authenticated. Running 'encore auth login'..." -ForegroundColor Yellow
        encore auth login
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Login failed. Please login manually." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "❌ Authentication check failed" -ForegroundColor Red
    exit 1
}

# Step 3: Check if app is linked
Write-Host ""
Write-Host "📋 Step 3: Checking app link..." -ForegroundColor Cyan
$appId = "pocketbizz-v2-gaki"
try {
    encore app link $appId 2>&1 | Out-Null
    Write-Host "✅ App linked: $appId" -ForegroundColor Green
} catch {
    Write-Host "⚠️  App link check failed (may already be linked)" -ForegroundColor Yellow
}

# Step 4: Set secrets for the environment
Write-Host ""
Write-Host "📋 Step 4: Setting secrets for $Environment environment..." -ForegroundColor Cyan
Write-Host "⚠️  You will be prompted to enter secrets. Use the same values as your local environment." -ForegroundColor Yellow
Write-Host ""

$secrets = @("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_KEY")

foreach ($secret in $secrets) {
    Write-Host "Setting $secret..." -ForegroundColor Yellow
    $response = Read-Host "Enter value for $secret (or press Enter to skip)"
    if ($response) {
        encore secret set --type $Environment $secret --value $response
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $secret set successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Failed to set $secret (may already exist)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⏭️  Skipped $secret" -ForegroundColor Gray
    }
}

# Step 5: Deploy to cloud
Write-Host ""
Write-Host "📋 Step 5: Deploying to Encore Cloud ($Environment)..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
Write-Host ""

try {
    encore deploy --env=$Environment
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Deployment successful!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Your API is now available at:" -ForegroundColor Cyan
        Write-Host "   Check Encore Cloud Dashboard: https://app.encore.cloud" -ForegroundColor White
        Write-Host ""
        Write-Host "📝 Next steps:" -ForegroundColor Cyan
        Write-Host "   1. Get your API URL from Encore Cloud Dashboard" -ForegroundColor White
        Write-Host "   2. Update your Android app's BASE_URL" -ForegroundColor White
        Write-Host "   3. Test endpoints using the dashboard or Postman" -ForegroundColor White
    } else {
        Write-Host "❌ Deployment failed. Check the error messages above." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Deployment error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Done!" -ForegroundColor Green

