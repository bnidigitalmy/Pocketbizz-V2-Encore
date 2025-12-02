# Simple Vercel Setup Script
# Usage: .\scripts\setup-vercel-simple.ps1

Write-Host "🚀 Setting up Vercel (Simple Method)" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build Flutter Web
Write-Host "📋 Step 1: Building Flutter web..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Build completed" -ForegroundColor Green

# Step 2: Update .gitignore
Write-Host ""
Write-Host "📋 Step 2: Updating .gitignore..." -ForegroundColor Cyan
$gitignorePath = ".gitignore"
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    
    if ($gitignoreContent -match '^build/') {
        Write-Host "   ⚠️  build/ is in .gitignore" -ForegroundColor Yellow
        Write-Host "   📝 Commenting out build/ for Vercel..." -ForegroundColor Gray
        
        $gitignoreContent = $gitignoreContent -replace '^build/', '# build/  # Temporarily uncommented for Vercel deployment'
        Set-Content -Path $gitignorePath -Value $gitignoreContent
        Write-Host "   ✅ Updated .gitignore" -ForegroundColor Green
    } else {
        Write-Host "   ✅ build/ already commented or not in .gitignore" -ForegroundColor Green
    }
}

# Step 3: Commit build files
Write-Host ""
Write-Host "📋 Step 3: Committing build files..." -ForegroundColor Cyan
Write-Host "   ⚠️  This will commit build files to Git (they are large)" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "   Continue? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    git add build/web .gitignore
    git commit -m "Add Flutter web build for Vercel deployment"
    Write-Host "   ✅ Committed build files" -ForegroundColor Green
    Write-Host ""
    Write-Host "   📤 Push to GitHub:" -ForegroundColor Cyan
    Write-Host "      git push origin main" -ForegroundColor White
} else {
    Write-Host "   ⏭️  Skipped commit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   💡 You can commit manually later:" -ForegroundColor Cyan
    Write-Host "      git add build/web" -ForegroundColor White
    Write-Host "      git commit -m 'Add web build'" -ForegroundColor White
}

# Step 4: Instructions
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📋 NEXT STEPS: Setup Vercel" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Push to GitHub (if not done):" -ForegroundColor Yellow
Write-Host "   git push origin main" -ForegroundColor White
Write-Host ""
Write-Host "2. Setup Vercel:" -ForegroundColor Yellow
Write-Host "   a. Buka: https://vercel.com/dashboard" -ForegroundColor White
Write-Host "   b. Click 'Add New Project'" -ForegroundColor White
Write-Host "   c. Import GitHub repository" -ForegroundColor White
Write-Host "   d. Configure:" -ForegroundColor White
Write-Host "      - Framework Preset: Other" -ForegroundColor Gray
Write-Host "      - Root Directory: . (current)" -ForegroundColor Gray
Write-Host "      - Build Command: (kosongkan)" -ForegroundColor Gray
Write-Host "      - Output Directory: build/web" -ForegroundColor Gray
Write-Host "      - Install Command: (kosongkan)" -ForegroundColor Gray
Write-Host "   e. Deploy!" -ForegroundColor White
Write-Host ""
Write-Host "3. After setup, Vercel will auto-deploy on every push!" -ForegroundColor Green
Write-Host ""


