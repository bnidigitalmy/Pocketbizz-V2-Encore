# Quick Git Setup and Push
Write-Host "Initializing Git repository..." -ForegroundColor Cyan

# Initialize git
git init

# Configure git (optional but recommended)
# git config user.name "Your Name"
# git config user.email "your@email.com"

# Add remote
git remote add origin https://github.com/bnidigitalmy/Pocketbizz-V2-Encore.git 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Remote may already exist, updating..." -ForegroundColor Yellow
    git remote set-url origin https://github.com/bnidigitalmy/Pocketbizz-V2-Encore.git
}

# Add files
Write-Host "Adding files..." -ForegroundColor Cyan
git add .

# Commit
Write-Host "Creating commit..." -ForegroundColor Cyan
git commit -m "Initial commit - PocketBizz V2 Encore backend with all services"

# Set branch to main
Write-Host "Setting branch to main..." -ForegroundColor Cyan
git branch -M main

# Push
Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
Write-Host "This may take a few minutes for first push..." -ForegroundColor Yellow
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Success! Code pushed to GitHub." -ForegroundColor Green
    Write-Host "Check: https://github.com/bnidigitalmy/Pocketbizz-V2-Encore" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Push failed. You may need to authenticate." -ForegroundColor Red
    Write-Host "Try running manually in terminal with authentication." -ForegroundColor Yellow
}

