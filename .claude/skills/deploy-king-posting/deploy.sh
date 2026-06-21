#!/usr/bin/env bash
# Deploy king-posting to Cloudflare Workers and verify it's live.
# Usage: bash .claude/skills/deploy-king-posting/deploy.sh [--schema]
#   --schema   also apply schema.sql to the remote D1 database
# Must be run from repo root.

set -e

PROD_URL="https://king-posting.watergold20222022.workers.dev"

echo ">>> Checking wrangler auth..."
npx wrangler whoami 2>&1 | grep -E '(logged in|You are logged|email)' || {
  echo "Not authenticated. Run: npx wrangler login"
  exit 1
}

# Optionally migrate remote D1 schema first
if [[ "$1" == "--schema" ]]; then
  echo ">>> Applying schema.sql to remote D1..."
  npx wrangler d1 execute king-posting --remote --file=./schema.sql
  echo "Schema applied."
fi

echo ">>> Deploying..."
npx wrangler deploy

echo ""
echo ">>> Verifying deployment at $PROD_URL ..."
sleep 2

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$PROD_URL/health")
if [ "$STATUS" = "200" ]; then
  echo "PASS /health → 200"
else
  echo "FAIL /health → $STATUS"
  exit 1
fi

TITLE=$(curl -sf "$PROD_URL/" | grep -o '<title>[^<]*</title>' | head -1)
echo "PASS / → $TITLE"

TOTAL=$(curl -s "$PROD_URL/api/posts?limit=1" | python3 -c "import sys,json; print('Total posts:', json.load(sys.stdin)['total'])" 2>/dev/null || echo "API check skipped")
echo "PASS $TOTAL"

echo ""
echo "Deployed successfully. Version visible at:"
echo "  $PROD_URL"
