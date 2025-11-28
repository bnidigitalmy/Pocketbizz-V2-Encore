# PocketBizz V2 - Push to GitHub Script
# This script helps commit and push code to GitHub

Write-Host "📤 PocketBizz V2 - Push to GitHub" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Check if git is initialized
if (-not (Test-Path .git)) {
    Write-Host "❌ Git not initialized. Run: git init" -ForegroundColor Red
    exit 1
}

# Check remote
$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Remote configured: $remote" -ForegroundColor Green
} else {
    Write-Host "⚠️  No remote configured" -ForegroundColor Yellow
    Write-Host "   Run: git remote add origin <your-repo-url>" -ForegroundColor Gray
    exit 1
}
Write-Host ""

# Check for changes
Write-Host "📋 Checking for changes..." -ForegroundColor Cyan
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️  Uncommitted changes found:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
    
    $commit = Read-Host "Do you want to commit and push? (y/n)"
    if ($commit -eq "y" -or $commit -eq "Y") {
        # Add all files
        Write-Host ""
        Write-Host "📦 Adding files..." -ForegroundColor Cyan
        git add .
        
        # Commit
        $commitMsg = Read-Host "Enter commit message (or press Enter for default)"
        if (-not $commitMsg) {
            $commitMsg = "Initial commit - PocketBizz V2 Encore backend"
        }
        
        Write-Host ""
        Write-Host "💾 Committing..." -ForegroundColor Cyan
        git commit -m $commitMsg
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Committed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Commit failed" -ForegroundColor Red
            exit 1
        }
        
        # Push
        Write-Host ""
        Write-Host "📤 Pushing to GitHub..." -ForegroundColor Cyan
        Write-Host "   This may take a few minutes..." -ForegroundColor Yellow
        
        # Check if main branch exists
        $currentBranch = git branch --show-current 2>&1
        if (-not $currentBranch) {
            git checkout -b main 2>&1 | Out-Null
            $currentBranch = "main"
        }
        
        git push -u origin $currentBranch
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ Successfully pushed to GitHub!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📝 Next steps:" -ForegroundColor Cyan
            Write-Host "   1. Connect repo in Encore Cloud Dashboard:" -ForegroundColor White
            Write-Host "      https://app.encore.cloud → App → Integrations → GitHub" -ForegroundColor Gray
            Write-Host "   2. Set secrets for dev environment:" -ForegroundColor White
            Write-Host "      .\scripts\set-secrets.ps1 dev" -ForegroundColor Gray
            Write-Host "   3. Future pushes will auto-deploy!" -ForegroundColor White
        } else {
            Write-Host "❌ Push failed. Check error messages above." -ForegroundColor Red
            Write-Host ""
            Write-Host "Common issues:" -ForegroundColor Yellow
            Write-Host "  - Authentication: Setup GitHub Personal Access Token" -ForegroundColor Gray
            Write-Host "  - Remote exists: git remote set-url origin <url>" -ForegroundColor Gray
            exit 1
        }
    } else {
        Write-Host "⏭️  Skipped" -ForegroundColor Gray
    }
} else {
    Write-Host "✅ No uncommitted changes" -ForegroundColor Green
    Write-Host ""
    Write-Host "To push existing commits:" -ForegroundColor Yellow
    Write-Host "  git push -u origin main" -ForegroundColor Cyan
}

Write-Host ""

