# Manual Firebase Deploy Script
# Usage: .\scripts\deploy-firebase.ps1

Write-Host "🔥 Deploying to Firebase Hosting" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Firebase CLI
Write-Host "📋 Step 1: Checking Firebase CLI..." -ForegroundColor Cyan
try {
    $firebaseVersion = firebase --version 2>&1
    Write-Host "   ✅ Firebase CLI found" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Firebase CLI not found" -ForegroundColor Red
    Write-Host "      Install: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check Flutter
Write-Host ""
Write-Host "📋 Step 2: Checking Flutter..." -ForegroundColor Cyan
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "   ✅ Flutter found" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Flutter not found" -ForegroundColor Red
    exit 1
}

# Step 3: Build Flutter web
Write-Host ""
Write-Host "📋 Step 3: Building Flutter web..." -ForegroundColor Cyan
Write-Host "   This may take a few minutes..." -ForegroundColor Gray

flutter clean
flutter pub get
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Build failed" -ForegroundColor Red
    exit 1
}

# Verify build
if (-not (Test-Path "build/web/index.html")) {
    Write-Host "   ❌ Build output not found" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Build completed" -ForegroundColor Green
$buildSize = (Get-ChildItem "build/web" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "      Size: $([math]::Round($buildSize, 2)) MB" -ForegroundColor Gray

# Step 4: Check Firebase config
Write-Host ""
Write-Host "📋 Step 4: Checking Firebase configuration..." -ForegroundColor Cyan
if (-not (Test-Path "firebase.json")) {
    Write-Host "   ❌ firebase.json not found" -ForegroundColor Red
    Write-Host "      Run setup script first: .\scripts\setup-firebase.ps1" -ForegroundColor Yellow
    exit 1
}

if (Test-Path ".firebaserc") {
    $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
    $projectId = $firebaserc.projects.default
    
    if ($projectId -eq "your-firebase-project-id") {
        Write-Host "   ⚠️  Project ID not set in .firebaserc" -ForegroundColor Yellow
        Write-Host "      Update .firebaserc with your Firebase project ID" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "   ✅ Project ID: $projectId" -ForegroundColor Green
    }
} else {
    Write-Host "   ⚠️  .firebaserc not found" -ForegroundColor Yellow
    Write-Host "      Run: firebase use --add" -ForegroundColor Yellow
}

# Step 5: Deploy
Write-Host ""
Write-Host "📋 Step 5: Deploying to Firebase Hosting..." -ForegroundColor Cyan
Write-Host "   This will deploy to production!" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "   Continue? (y/n)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "   ⏭️  Deployment cancelled" -ForegroundColor Gray
    exit 0
}

firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your app is now live on Firebase Hosting!" -ForegroundColor Cyan
    Write-Host "   Check Firebase Console for the URL" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    Write-Host "   Check error messages above" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

