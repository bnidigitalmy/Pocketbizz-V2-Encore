#!/bin/bash
# PocketBizz V2 - Encore Cloud Deployment Script
# Usage: ./scripts/deploy.sh [dev|preview|prod]

set -e

ENVIRONMENT=${1:-dev}

if [[ ! "$ENVIRONMENT" =~ ^(dev|preview|prod)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [dev|preview|prod]"
    exit 1
fi

echo "🚀 PocketBizz V2 - Encore Cloud Deployment"
echo "Environment: $ENVIRONMENT"
echo ""

# Step 1: Check if encore CLI is installed
echo "📋 Step 1: Checking Encore CLI..."
if ! command -v encore &> /dev/null; then
    echo "❌ Encore CLI not found. Please install from https://encore.dev/docs/install"
    exit 1
fi
echo "✅ Encore CLI found"

# Step 2: Check if user is logged in
echo ""
echo "📋 Step 2: Checking authentication..."
if encore auth whoami &> /dev/null; then
    echo "✅ Authenticated: $(encore auth whoami)"
else
    echo "❌ Not authenticated. Running 'encore auth login'..."
    encore auth login
    if [ $? -ne 0 ]; then
        echo "❌ Login failed. Please login manually."
        exit 1
    fi
fi

# Step 3: Check if app is linked
echo ""
echo "📋 Step 3: Checking app link..."
APP_ID="pocketbizz-v2-gaki"
encore app link "$APP_ID" &> /dev/null || echo "⚠️  App link check (may already be linked)"

# Step 4: Set secrets for the environment
echo ""
echo "📋 Step 4: Setting secrets for $ENVIRONMENT environment..."
echo "⚠️  You will be prompted to enter secrets. Use the same values as your local environment."
echo ""

SECRETS=("SUPABASE_URL" "SUPABASE_ANON_KEY" "SUPABASE_SERVICE_KEY")

for secret in "${SECRETS[@]}"; do
    echo "Setting $secret..."
    read -p "Enter value for $secret (or press Enter to skip): " value
    if [ -n "$value" ]; then
        encore secret set --type "$ENVIRONMENT" "$secret" --value "$value"
        if [ $? -eq 0 ]; then
            echo "✅ $secret set successfully"
        else
            echo "⚠️  Failed to set $secret (may already exist)"
        fi
    else
        echo "⏭️  Skipped $secret"
    fi
done

# Step 5: Deploy to cloud
echo ""
echo "📋 Step 5: Deploying to Encore Cloud ($ENVIRONMENT)..."
echo "This may take a few minutes..."
echo ""

if encore deploy --env="$ENVIRONMENT"; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Your API is now available at:"
    echo "   Check Encore Cloud Dashboard: https://app.encore.cloud"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Get your API URL from Encore Cloud Dashboard"
    echo "   2. Update your Android app's BASE_URL"
    echo "   3. Test endpoints using the dashboard or Postman"
else
    echo "❌ Deployment failed. Check the error messages above."
    exit 1
fi

echo ""
echo "🎉 Done!"

