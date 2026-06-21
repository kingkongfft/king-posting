---
name: deploy-king-posting
description: Deploy or redeploy king-posting to Cloudflare Workers. Use when asked to deploy, redeploy, push to production, release, or publish king-posting to Cloudflare.
---

King Posting deploys to **Cloudflare Workers** (not Cloudflare Pages) via `wrangler deploy`. No build step — wrangler bundles `src/worker.js` and uploads it. The remote D1 database is shared across deploys; schema migrations are a separate step. The driver is `deploy.sh`, which deploys and verifies the live URL.

Production URL: `https://king-posting.watergold20222022.workers.dev`

## Prerequisites

```bash
npm install    # installs wrangler if missing
npx wrangler whoami   # must show your account — if not, run: npx wrangler login
```

## Deploy (agent path)

```bash
bash .claude/skills/deploy-king-posting/deploy.sh
```

This will:
1. Confirm wrangler auth
2. Run `npx wrangler deploy` (bundles + uploads `src/worker.js`)
3. Hit `/health`, `/`, and `/api/posts` on production to confirm it's serving

Output ends with `Deployed successfully` and the live URL on success.

## Deploy + schema migration

Only needed when `schema.sql` changed (new table, new column):

```bash
bash .claude/skills/deploy-king-posting/deploy.sh --schema
```

This applies `schema.sql` to the **remote** D1 database before deploying the worker. All `CREATE TABLE IF NOT EXISTS` — safe to re-run.

## Manual deploy (one liner)

```bash
npx wrangler deploy
```

## Verify production manually

```bash
curl https://king-posting.watergold20222022.workers.dev/health
curl 'https://king-posting.watergold20222022.workers.dev/api/posts?limit=1'
```

## Remote D1 queries

```bash
# Run arbitrary SQL against the live database
npx wrangler d1 execute king-posting --remote --command="SELECT COUNT(*) FROM posts WHERE deleted_at IS NULL;"

# Apply schema
npx wrangler d1 execute king-posting --remote --file=./schema.sql
```

## Gotchas

- **This is Workers, not Pages.** `wrangler pages deploy` is wrong — this project has no static build output, no `dist/` folder. It's `wrangler deploy` only.
- **JWT_SECRET is in `[vars]` in wrangler.toml** (plaintext, in source). It's already set to `"king-posting-dev-secret-2026"`. This value is live in production. To rotate it: change `wrangler.toml` and redeploy — no `wrangler secret put` needed for this project.
- **No `--remote` = local D1.** `wrangler d1 execute king-posting` without `--remote` runs against `.wrangler/state/v3/d1/` (local). Add `--remote` to hit the real database.
- **D1 schema is `IF NOT EXISTS`.** Re-running `schema.sql` on the remote is safe — it won't drop data. Run it any time you're unsure if the remote is current.
- **Deploy takes ~5 s.** The 2-second sleep in the deploy script is needed — the edge takes a moment to propagate after `wrangler deploy` returns.
- **Cron job (`0 2 * * *`) cannot be triggered manually in prod** except via `curl "$URL/cdn-cgi/handler/scheduled"`. This fires `cleanupOldPosts` which soft-deletes posts older than 1 month.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Not authenticated` / `Error: Not logged in` | Run `npx wrangler login` and complete OAuth flow |
| `Error: Missing binding DB` | The D1 database binding is missing — check `wrangler.toml` has `[[d1_databases]]` block |
| Deploy succeeds but `/health` returns 503 | Wait 5–10 s more; edge propagation can lag. Re-run the verify curl. |
| `wrangler d1 execute` hits local not remote | Add `--remote` flag — default is local state |
| Token scope warning about `websearch.run` | Non-blocking warning from wrangler 4.x about new scopes. Run `npx wrangler login` to refresh if it bothers you. |
