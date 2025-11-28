# GitHub Integration Setup Guide

## Step-by-Step: Connect GitHub to Encore Cloud

### Prerequisites
- ✅ Encore Cloud account (logged in)
- ✅ GitHub account
- ✅ Repository pushed to GitHub

### Steps

1. **Open Encore Cloud Dashboard**
   - Go to: https://app.encore.cloud
   - Login if needed

2. **Navigate to Your App**
   - Click on app: `pocketbizz-v2-gaki`
   - Or create new app if not exists

3. **Go to Integrations**
   - In the left sidebar, click **"Integrations"**
   - Or navigate to: App → Settings → Integrations

4. **Connect GitHub**
   - Click **"GitHub"** or **"Connect GitHub"** button
   - You'll be redirected to GitHub for authorization
   - Authorize Encore to access your repositories

5. **Select Repository**
   - Choose repository: `pocketbizz-flutter` (or your repo name)
   - Select branch: `main` (or `master`)
   - Choose environment: `dev` (for development)

6. **Configure Auto-Deploy**
   - Enable automatic deployment on push
   - Set deployment environment (dev/preview/prod)
   - Save configuration

### After Setup

Once connected, every `git push` to the connected branch will:
- ✅ Automatically trigger deployment
- ✅ Build your Encore.ts app
- ✅ Deploy to selected environment
- ✅ Show deployment status in dashboard

### Manual Deployment (Alternative)

If you prefer manual deployment:
1. Go to Encore Cloud Dashboard
2. Navigate to: App → Environments → [environment]
3. Click **"Deploy"** button
4. Upload code or connect via Git

### Troubleshooting

**"Repository not found"**
- Ensure GitHub account is connected
- Check repository permissions
- Verify repository name is correct

**"Deployment failed"**
- Check deployment logs in dashboard
- Verify secrets are set correctly
- Check code compilation errors

**"Branch not found"**
- Ensure branch exists in repository
- Check branch name spelling
- Push code to branch first

## Quick Reference

- **Dashboard**: https://app.encore.cloud
- **App ID**: `pocketbizz-v2-gaki`
- **Repository**: Your GitHub repo name
- **Branch**: `main` or `master`

