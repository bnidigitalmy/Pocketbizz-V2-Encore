# Firebase Hosting Setup Script
# Usage: .\scripts\setup-firebase.ps1

Write-Host "🔥 Firebase Hosting Setup for Flutter Web" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Firebase CLI
Write-Host "📋 Step 1: Checking Firebase CLI..." -ForegroundColor Cyan
try {
    $firebaseVersion = firebase --version 2>&1
    Write-Host "   ✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Firebase CLI not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "   📥 Install Firebase CLI:" -ForegroundColor Yellow
    Write-Host "      npm install -g firebase-tools" -ForegroundColor White
    Write-Host "      Or: https://firebase.google.com/docs/cli#install_the_firebase_cli" -ForegroundColor White
    exit 1
}

# Step 2: Check if logged in
Write-Host ""
Write-Host "📋 Step 2: Checking authentication..." -ForegroundColor Cyan
try {
    $whoami = firebase login:list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Logged in to Firebase" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Not logged in. Running 'firebase login'..." -ForegroundColor Yellow
        firebase login
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   ❌ Login failed" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "   ⚠️  Cannot verify login. Run 'firebase login' manually if needed." -ForegroundColor Yellow
}

# Step 3: Check firebase.json
Write-Host ""
Write-Host "📋 Step 3: Checking firebase.json..." -ForegroundColor Cyan
if (Test-Path "firebase.json") {
    Write-Host "   ✅ firebase.json exists" -ForegroundColor Green
} else {
    Write-Host "   ❌ firebase.json not found" -ForegroundColor Red
    Write-Host "      This should have been created. Check if file exists." -ForegroundColor Yellow
    exit 1
}

# Step 4: Check .firebaserc
Write-Host ""
Write-Host "📋 Step 4: Checking .firebaserc..." -ForegroundColor Cyan
if (Test-Path ".firebaserc") {
    $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
    $projectId = $firebaserc.projects.default
    
    if ($projectId -eq "your-firebase-project-id") {
        Write-Host "   ⚠️  Project ID not set" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   📝 Set your Firebase project ID:" -ForegroundColor Cyan
        Write-Host "      1. Create project at: https://console.firebase.google.com" -ForegroundColor White
        Write-Host "      2. Get project ID from Firebase console" -ForegroundColor White
        Write-Host "      3. Update .firebaserc with your project ID" -ForegroundColor White
        Write-Host "      4. Or run: firebase use --add" -ForegroundColor White
    } else {
        Write-Host "   ✅ Project ID: $projectId" -ForegroundColor Green
    }
} else {
    Write-Host "   ⚠️  .firebaserc not found" -ForegroundColor Yellow
    Write-Host "      Run: firebase init hosting" -ForegroundColor White
}

# Step 5: Initialize Firebase (if needed)
Write-Host ""
Write-Host "📋 Step 5: Firebase Hosting Setup..." -ForegroundColor Cyan
Write-Host "   💡 If not initialized, run:" -ForegroundColor Yellow
Write-Host "      firebase init hosting" -ForegroundColor White
Write-Host ""
Write-Host "   When prompted:" -ForegroundColor Cyan
Write-Host "      - Use existing project (or create new)" -ForegroundColor White
Write-Host "      - Public directory: build/web" -ForegroundColor White
Write-Host "      - Single-page app: Yes" -ForegroundColor White
Write-Host "      - Automatic builds: No (we use GitHub Actions)" -ForegroundColor White

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📋 NEXT STEPS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Create Firebase project (if not exists):" -ForegroundColor Yellow
Write-Host "   https://console.firebase.google.com" -ForegroundColor White
Write-Host ""
Write-Host "2. Update .firebaserc with your project ID" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Setup GitHub Secrets:" -ForegroundColor Yellow
Write-Host "   - FIREBASE_SERVICE_ACCOUNT (JSON key)" -ForegroundColor White
Write-Host "   - FIREBASE_PROJECT_ID (your project ID)" -ForegroundColor White
Write-Host ""
Write-Host "4. Get Service Account key:" -ForegroundColor Yellow
Write-Host "   Firebase Console → Project Settings → Service Accounts" -ForegroundColor White
Write-Host "   Generate new private key → Copy JSON content" -ForegroundColor White
Write-Host ""
Write-Host "5. Test build locally:" -ForegroundColor Yellow
Write-Host "   flutter build web --release" -ForegroundColor White
Write-Host ""
Write-Host "6. Test deploy locally (optional):" -ForegroundColor Yellow
Write-Host "   firebase deploy --only hosting" -ForegroundColor White
Write-Host ""
Write-Host "7. Push to GitHub to trigger auto-deploy!" -ForegroundColor Green
Write-Host ""

