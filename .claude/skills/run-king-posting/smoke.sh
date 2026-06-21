#!/usr/bin/env bash
# Smoke test for king-posting. Starts wrangler dev, runs the full API flow, exits.
# Usage: bash .claude/skills/run-king-posting/smoke.sh
# Must be run from repo root.

set -e

PORT=8787
BASE="http://127.0.0.1:$PORT"
AGENT="smoke-$(date +%s)"
PASS="smokepass123"

echo ">>> Starting wrangler dev on port $PORT..."
npx wrangler dev --port $PORT --local > /tmp/wrangler-dev.log 2>&1 &
WR_PID=$!
trap "kill $WR_PID 2>/dev/null; exit" EXIT INT TERM

# Wait for ready
for i in $(seq 1 20); do
  if curl -sf "$BASE/health" >/dev/null 2>&1; then break; fi
  sleep 0.5
done
curl -sf "$BASE/health" >/dev/null || { echo "FAIL: server never started"; cat /tmp/wrangler-dev.log; exit 1; }
echo ">>> Server ready"

# Health
echo ">>> /health"
curl -sf "$BASE/health" | grep -q '"ok"' && echo "PASS" || echo "FAIL"

# Home page
echo ">>> / (HTML)"
curl -sf "$BASE/" | grep -q 'King Posting' && echo "PASS" || echo "FAIL"

# Posts page
echo ">>> /posts (HTML)"
curl -sf "$BASE/posts" | grep -q '帖子流' && echo "PASS" || echo "FAIL"

# Register
echo ">>> POST /api/auth/register"
REG=$(curl -sf -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$AGENT\",\"password\":\"$PASS\"}")
echo "$REG" | grep -q '"name"' && echo "PASS" || { echo "FAIL: $REG"; exit 1; }

# Login
echo ">>> POST /api/auth/login"
LOGIN=$(curl -sf -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$AGENT\",\"password\":\"$PASS\"}")
TOKEN=$(echo "$LOGIN" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[ -n "$TOKEN" ] && echo "PASS" || { echo "FAIL: $LOGIN"; exit 1; }

# Create post
echo ">>> POST /api/posts"
POST=$(curl -sf -X POST "$BASE/api/posts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"content":"Hello from smoke test!"}')
POST_ID=$(echo "$POST" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$POST_ID" ] && echo "PASS (id=$POST_ID)" || { echo "FAIL: $POST"; exit 1; }

# Reply
echo ">>> POST /api/posts (reply)"
REPLY=$(curl -sf -X POST "$BASE/api/posts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"content\":\"Reply!\",\"parent_id\":$POST_ID}")
echo "$REPLY" | grep -q '"parent_id"' && echo "PASS" || { echo "FAIL: $REPLY"; exit 1; }

# List posts
echo ">>> GET /api/posts"
LIST=$(curl -sf "$BASE/api/posts")
echo "$LIST" | grep -q '"posts"' && echo "PASS" || { echo "FAIL: $LIST"; exit 1; }

# Get single post with replies
echo ">>> GET /api/posts/$POST_ID"
SINGLE=$(curl -sf "$BASE/api/posts/$POST_ID")
echo "$SINGLE" | grep -q '"replies"' && echo "PASS" || { echo "FAIL: $SINGLE"; exit 1; }

# Delete post (also cascade-deletes reply)
echo ">>> DELETE /api/posts/$POST_ID"
DEL=$(curl -sf -X DELETE "$BASE/api/posts/$POST_ID" \
  -H "Authorization: Bearer $TOKEN")
echo "$DEL" | grep -q '"message"' && echo "PASS" || { echo "FAIL: $DEL"; exit 1; }

# Verify deleted
echo ">>> GET /api/posts/$POST_ID (expect 404)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/posts/$POST_ID")
[ "$STATUS" = "404" ] && echo "PASS" || echo "FAIL: expected 404 got $STATUS"

# Validation: duplicate name
echo ">>> Register duplicate (expect 409)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$AGENT\",\"password\":\"$PASS\"}")
[ "$STATUS" = "409" ] && echo "PASS" || echo "FAIL: expected 409 got $STATUS"

# Validation: short password
echo ">>> Register short password (expect 400)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"x","password":"abc"}')
[ "$STATUS" = "400" ] && echo "PASS" || echo "FAIL: expected 400 got $STATUS"

echo ""
echo "All smoke tests done."
