# PocketBizz V2 - Git Repository Setup Script
# This script helps initialize git and setup remote for GitHub

Write-Host "🔧 PocketBizz V2 - Git Repository Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if git is installed
Write-Host "📋 Step 1: Checking Git..." -ForegroundColor Cyan
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Git not found. Please install Git from https://git-scm.com/" -ForegroundColor Red
    exit 1
}

$gitVersion = git --version
Write-Host "✅ Git found: $gitVersion" -ForegroundColor Green
Write-Host ""

# Step 2: Check if already a git repo
Write-Host "📋 Step 2: Checking Git repository..." -ForegroundColor Cyan
if (Test-Path .git) {
    Write-Host "✅ Git repository already initialized" -ForegroundColor Green
} else {
    Write-Host "⚠️  Not a git repository. Initializing..." -ForegroundColor Yellow
    git init
    Write-Host "✅ Git repository initialized" -ForegroundColor Green
}
Write-Host ""

# Step 3: Check current branch
Write-Host "📋 Step 3: Checking current branch..." -ForegroundColor Cyan
try {
    $currentBranch = git branch --show-current 2>&1
    if ($LASTEXITCODE -eq 0 -and $currentBranch) {
        Write-Host "✅ Current branch: $currentBranch" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No commits yet. Creating initial commit..." -ForegroundColor Yellow
        git checkout -b main 2>&1 | Out-Null
        Write-Host "✅ Created 'main' branch" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  No commits yet" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Check remote
Write-Host "📋 Step 4: Checking remote repository..." -ForegroundColor Cyan
$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Remote already set: $remote" -ForegroundColor Green
} else {
    Write-Host "⚠️  No remote repository configured" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To add GitHub remote:" -ForegroundColor White
    Write-Host "  1. Create repository on GitHub (if not exists)" -ForegroundColor Gray
    Write-Host "  2. Run: git remote add origin <your-github-repo-url>" -ForegroundColor Cyan
    Write-Host "     Example: git remote add origin https://github.com/username/pocketbizz-flutter.git" -ForegroundColor Gray
    Write-Host ""
    
    $addRemote = Read-Host "Do you want to add remote now? (y/n)"
    if ($addRemote -eq "y" -or $addRemote -eq "Y") {
        $repoUrl = Read-Host "Enter GitHub repository URL"
        if ($repoUrl) {
            git remote add origin $repoUrl
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Remote added successfully" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to add remote" -ForegroundColor Red
            }
        }
    }
}
Write-Host ""

# Step 5: Check uncommitted changes
Write-Host "📋 Step 5: Checking for uncommitted changes..." -ForegroundColor Cyan
$status = git status --porcelain 2>&1
if ($status) {
    Write-Host "⚠️  You have uncommitted changes:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
    $commit = Read-Host "Do you want to commit these changes? (y/n)"
    if ($commit -eq "y" -or $commit -eq "Y") {
        $commitMsg = Read-Host "Enter commit message (or press Enter for default)"
        if (-not $commitMsg) {
            $commitMsg = "Initial commit - PocketBizz V2 Encore backend"
        }
        git add .
        git commit -m $commitMsg
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Changes committed" -ForegroundColor Green
        } else {
            Write-Host "❌ Commit failed" -ForegroundColor Red
        }
    }
} else {
    Write-Host "✅ No uncommitted changes" -ForegroundColor Green
}
Write-Host ""

# Step 6: Summary and next steps
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 Next Steps" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Git repository is ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To push to GitHub:" -ForegroundColor White
    Write-Host "  git push -u origin main" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After pushing, connect repo in Encore Cloud Dashboard:" -ForegroundColor White
    Write-Host "  https://app.encore.cloud → App → Integrations → GitHub" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Remote not configured yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Create repository on GitHub" -ForegroundColor White
    Write-Host "2. Add remote: git remote add origin <repo-url>" -ForegroundColor White
    Write-Host "3. Push: git push -u origin main" -ForegroundColor White
    Write-Host "4. Connect in Encore Cloud Dashboard" -ForegroundColor White
}

Write-Host ""

