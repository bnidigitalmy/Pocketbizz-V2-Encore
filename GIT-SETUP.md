# Git Repository Setup Guide

## Quick Setup untuk Encore Cloud Deployment

### Step 1: Initialize Git (Jika Belum)

```powershell
git init
```

### Step 2: Create Initial Commit

```powershell
# Add all files
git add .

# Create initial commit
git commit -m "Initial commit - PocketBizz V2 Encore backend"
```

### Step 3: Create GitHub Repository

1. Buka: https://github.com/new
2. Repository name: `pocketbizz-flutter` (atau nama lain)
3. Set sebagai **Private** atau **Public**
4. **JANGAN** initialize dengan README, .gitignore, atau license
5. Click **"Create repository"**

### Step 4: Add Remote and Push

```powershell
# Add GitHub remote (ganti dengan URL repo anda)
git remote add origin https://github.com/USERNAME/pocketbizz-flutter.git

# Create main branch (jika belum)
git branch -M main

# Push to GitHub
git push -u origin main
```

**Note**: Ganti `USERNAME` dengan GitHub username anda, dan `pocketbizz-flutter` dengan nama repo anda.

### Step 5: Connect to Encore Cloud

1. Buka: https://app.encore.cloud
2. Navigate ke: App → Integrations → GitHub
3. Click **"Connect GitHub"**
4. Authorize Encore
5. Select repository: `pocketbizz-flutter`
6. Select branch: `main`
7. Select environment: `dev`
8. Enable **"Auto-deploy on push"**
9. Click **"Save"**

### Step 6: Set Secrets for Dev Environment

```powershell
# Run secrets setup script
.\scripts\set-secrets.ps1 dev

# Or set manually
encore secret set --type dev SUPABASE_URL
encore secret set --type dev SUPABASE_ANON_KEY
encore secret set --type dev SUPABASE_SERVICE_KEY
```

### Step 7: Test Deployment

```powershell
# Make a small change
echo "# Test" >> README.md

# Commit and push
git add .
git commit -m "Test deployment"
git push origin main
```

Check deployment status di Encore Cloud Dashboard!

---

## Troubleshooting

### "fatal: not a git repository"
```powershell
git init
```

### "remote origin already exists"
```powershell
# Check current remote
git remote -v

# Update remote URL
git remote set-url origin <new-url>

# Or remove and add again
git remote remove origin
git remote add origin <new-url>
```

### "failed to push some refs"
```powershell
# If GitHub repo has files, pull first
git pull origin main --allow-unrelated-histories

# Then push
git push -u origin main
```

### "authentication failed"
- Use GitHub Personal Access Token instead of password
- Or setup SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

## Quick Commands Reference

```powershell
# Check status
git status

# Add files
git add .

# Commit
git commit -m "Your message"

# Push
git push origin main

# Check remote
git remote -v

# View commits
git log --oneline
```

---

## After Setup

✅ Git repository initialized  
✅ Code pushed to GitHub  
✅ GitHub connected to Encore Cloud  
✅ Secrets set for dev environment  
✅ Auto-deploy enabled  

**Every `git push` will now automatically deploy to Encore Cloud!** 🚀

