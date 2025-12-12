#!/bin/bash

# Test script untuk BCL webhook (bash version)
# Usage: ./scripts/test-bcl-webhook.sh

set -e

WEBHOOK_URL="${WEBHOOK_URL:-https://gxllowlurizrkvpdircw.supabase.co/functions/v1/supabase-functions-deploy-bcl-webhook}"
BCL_SECRET="${BCL_API_SECRET_KEY:-${TEST_BCL_SECRET:-}}"

if [ -z "$BCL_SECRET" ]; then
  echo "❌ ERROR: BCL_API_SECRET_KEY is required!"
  echo ""
  echo "Set it via environment variable:"
  echo "  export BCL_API_SECRET_KEY='your-secret-key'"
  echo "  ./scripts/test-bcl-webhook.sh"
  exit 1
fi

echo "🚀 Starting BCL Webhook Tests"
echo "📍 Webhook URL: $WEBHOOK_URL"
echo "🔑 BCL Secret: ✅ Set"
echo ""

# Note: This bash script requires a helper to generate HMAC signatures
# For full testing, use the TypeScript version: deno run scripts/test-bcl-webhook.ts

echo "📝 To run full tests with signature verification, use:"
echo "   deno run --allow-net --allow-env scripts/test-bcl-webhook.ts"
echo ""
echo "Or with Node.js:"
echo "   npx tsx scripts/test-bcl-webhook.ts"

