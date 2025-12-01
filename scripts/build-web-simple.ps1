# Simple Flutter Web Build Script
# Usage: .\scripts\build-web-simple.ps1

Write-Host "🚀 Building Flutter Web (Simple)" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Flutter
Write-Host "📋 Checking Flutter..." -ForegroundColor Cyan
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "   ✅ Flutter: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Flutter not found" -ForegroundColor Red
    Write-Host "      Install Flutter: https://flutter.dev" -ForegroundColor Yellow
    exit 1
}

# Step 2: Clean
Write-Host ""
Write-Host "📋 Cleaning previous build..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ⚠️  Clean failed (might be OK)" -ForegroundColor Yellow
}

# Step 3: Get dependencies
Write-Host ""
Write-Host "📋 Getting dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Failed to get dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Dependencies installed" -ForegroundColor Green

# Step 4: Build web
Write-Host ""
Write-Host "📋 Building Flutter web (this may take a while)..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Build failed" -ForegroundColor Red
    exit 1
}

# Step 5: Verify build
Write-Host ""
Write-Host "📋 Verifying build output..." -ForegroundColor Cyan
if (Test-Path "build/web/index.html") {
    $buildSize = (Get-ChildItem "build/web" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "   ✅ Build complete!" -ForegroundColor Green
    Write-Host "      Output: build/web" -ForegroundColor Gray
    Write-Host "      Size: $([math]::Round($buildSize, 2)) MB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📋 Next steps:" -ForegroundColor Cyan
    Write-Host "   • Test locally: cd build/web && python -m http.server 8000" -ForegroundColor White
    Write-Host "   • Or upload build/web to your hosting" -ForegroundColor White
} else {
    Write-Host "   ❌ Build output not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Done!" -ForegroundColor Green

