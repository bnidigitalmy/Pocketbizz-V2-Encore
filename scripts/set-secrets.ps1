# PocketBizz V2 - Set Secrets Script
# Usage: .\scripts\set-secrets.ps1 [dev|preview|prod]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "preview", "prod", "local")]
    [string]$Environment = "dev"
)

Write-Host "🔐 PocketBizz V2 - Set Secrets for $Environment Environment" -ForegroundColor Cyan
Write-Host ""

# Check if encore CLI is installed
if (-not (Get-Command encore -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Encore CLI not found. Please install from https://encore.dev/docs/install" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Encore CLI found" -ForegroundColor Green
Write-Host ""

# Check authentication
Write-Host "📋 Checking authentication..." -ForegroundColor Cyan
try {
    $whoami = encore auth whoami 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Authenticated" -ForegroundColor Green
    } else {
        Write-Host "❌ Not authenticated. Please run: encore auth login" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Authentication check failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📝 You will be prompted to enter secret values." -ForegroundColor Yellow
Write-Host "   Use the same values as your local environment." -ForegroundColor Yellow
Write-Host "   Press Enter to skip a secret (if already set)." -ForegroundColor Yellow
Write-Host ""

$secrets = @(
    @{Name="SUPABASE_URL"; Description="Supabase Project URL"},
    @{Name="SUPABASE_ANON_KEY"; Description="Supabase Anonymous Key"},
    @{Name="SUPABASE_SERVICE_KEY"; Description="Supabase Service Role Key"}
)

$setCount = 0
$skippedCount = 0

foreach ($secret in $secrets) {
    Write-Host ""
    Write-Host "🔑 $($secret.Name)" -ForegroundColor Cyan
    Write-Host "   $($secret.Description)" -ForegroundColor Gray
    
    $value = Read-Host "   Enter value (or press Enter to skip)"
    
    if ($value) {
        Write-Host "   Setting secret..." -ForegroundColor Yellow
        $result = encore secret set --type $Environment $secret.Name --value $value 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Secret set successfully" -ForegroundColor Green
            $setCount++
        } else {
            Write-Host "   ⚠️  Failed to set secret: $result" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⏭️  Skipped" -ForegroundColor Gray
        $skippedCount++
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "   Environment: $Environment" -ForegroundColor White
Write-Host "   Secrets set: $setCount" -ForegroundColor Green
Write-Host "   Secrets skipped: $skippedCount" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if ($setCount -gt 0) {
    Write-Host "✅ Secrets configuration completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Verify secrets in Encore Cloud Dashboard:" -ForegroundColor White
    Write-Host "      https://app.encore.cloud → App → Settings → Secrets" -ForegroundColor Gray
    Write-Host "   2. Connect GitHub repo for automatic deployment" -ForegroundColor White
    Write-Host "   3. Push code to trigger deployment" -ForegroundColor White
} else {
    Write-Host "ℹ️  No secrets were set. They may already be configured." -ForegroundColor Yellow
}

Write-Host ""

