# PocketBizz V2 - Quick Setup Script
# This script helps you set up secrets and provides next steps for GitHub integration

Write-Host "🚀 PocketBizz V2 - Quick Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Encore CLI
Write-Host "📋 Step 1: Checking Encore CLI..." -ForegroundColor Cyan
if (-not (Get-Command encore -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Encore CLI not found!" -ForegroundColor Red
    Write-Host "   Install from: https://encore.dev/docs/install" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Encore CLI found" -ForegroundColor Green
Write-Host ""

# Step 2: Check Authentication
Write-Host "📋 Step 2: Checking authentication..." -ForegroundColor Cyan
try {
    $whoami = encore auth whoami 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Authenticated" -ForegroundColor Green
    } else {
        Write-Host "❌ Not authenticated" -ForegroundColor Red
        Write-Host ""
        Write-Host "   Run: encore auth login" -ForegroundColor Yellow
        $login = Read-Host "   Do you want to login now? (y/n)"
        if ($login -eq "y" -or $login -eq "Y") {
            encore auth login
        } else {
            Write-Host "   Please login manually and run this script again." -ForegroundColor Yellow
            exit 1
        }
    }
} catch {
    Write-Host "❌ Authentication check failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Check App Link
Write-Host "📋 Step 3: Checking app link..." -ForegroundColor Cyan
$appId = "pocketbizz-v2-gaki"
try {
    encore app link $appId 2>&1 | Out-Null
    Write-Host "✅ App linked: $appId" -ForegroundColor Green
} catch {
    Write-Host "⚠️  App may not be linked" -ForegroundColor Yellow
    Write-Host "   This is OK if app doesn't exist yet in Encore Cloud" -ForegroundColor Gray
}
Write-Host ""

# Step 4: Set Secrets
Write-Host "📋 Step 4: Setting secrets for dev environment..." -ForegroundColor Cyan
Write-Host ""
$setSecrets = Read-Host "Do you want to set secrets now? (y/n)"
if ($setSecrets -eq "y" -or $setSecrets -eq "Y") {
    Write-Host ""
    Write-Host "Running secrets setup script..." -ForegroundColor Yellow
    & "$PSScriptRoot\set-secrets.ps1" -Environment "dev"
} else {
    Write-Host "⏭️  Skipping secrets setup" -ForegroundColor Gray
    Write-Host "   You can run: .\scripts\set-secrets.ps1 dev" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: GitHub Integration Instructions
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 Step 5: GitHub Integration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "To enable automatic deployment via Git push:" -ForegroundColor White
Write-Host ""
Write-Host "1. Open Encore Cloud Dashboard:" -ForegroundColor Yellow
Write-Host "   https://app.encore.cloud" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Navigate to:" -ForegroundColor Yellow
Write-Host "   App → Integrations → GitHub" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Connect your GitHub repository" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Select branch and environment" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. Push code to trigger deployment:" -ForegroundColor Yellow
Write-Host "   git push origin main" -ForegroundColor Cyan
Write-Host ""
Write-Host "📖 Full guide: scripts/setup-github-integration.md" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Setup Checklist" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "☐ Encore CLI installed" -ForegroundColor White
Write-Host "☐ Logged in to Encore" -ForegroundColor White
Write-Host "☐ Secrets set for dev environment" -ForegroundColor White
Write-Host "☐ GitHub repo connected (via dashboard)" -ForegroundColor White
Write-Host "☐ Code pushed to GitHub" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Once all checked, your app will auto-deploy on push!" -ForegroundColor Green
Write-Host ""

