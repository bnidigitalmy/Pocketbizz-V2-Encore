# Manual webhook test script untuk verify function berfungsi
# Usage: .\scripts\test-webhook-manual.ps1

$webhookUrl = "https://gxllowlurizrkvpdircw.supabase.co/functions/v1/supabase-functions-deploy-bcl-webhook"
$bclSecret = $env:BCL_API_SECRET_KEY

if (-not $bclSecret) {
    Write-Host "❌ ERROR: BCL_API_SECRET_KEY is required!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Set it via:"
    Write-Host "  `$env:BCL_API_SECRET_KEY = 'your-secret-key'"
    exit 1
}

Write-Host "🧪 Testing webhook manually..." -ForegroundColor Cyan
Write-Host "📍 URL: $webhookUrl" -ForegroundColor Cyan
Write-Host ""

# Test payload (tanpa signature dulu untuk test basic function)
$testPayload = @{
    order_number = "PBZ-TEST-MANUAL-001"
    transaction_id = "TXN-TEST-001"
    amount = "39.00"
    currency = "MYR"
    status = "success"
    status_description = "Test payment"
} | ConvertTo-Json

Write-Host "📤 Sending test request (without signature - should fail with 401)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $testPayload -ContentType "application/json"
    Write-Host "✅ Response:" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Host "📥 Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    Write-Host "📥 Response:" -ForegroundColor Yellow
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $responseBody = $reader.ReadToEnd()
    Write-Host $responseBody
}

Write-Host ""
Write-Host "💡 Note: Function should return 401 (Invalid signature) - this confirms function is working!" -ForegroundColor Cyan
Write-Host "💡 If you get connection error, check webhook URL and function deployment." -ForegroundColor Cyan

