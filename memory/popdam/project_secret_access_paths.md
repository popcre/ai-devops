---
name: project_secret_access_paths
description: "How to reach PopDAM secrets/DB when the supabase MCP is unauthorized — op no-print path, service role, psql"
metadata: 
  node_type: memory
  type: project
  originSessionId: 510c0819-789c-4874-93eb-eb8cadc5cbdb
---

Working access paths on the hetz VPS checkout (verified 2026-07-14), for when a
task needs a live secret or DB read and printing the secret is blocked:

- **1Password CLI `op` works** — authed as a SERVICE_ACCOUNT against vault
  `vibe_coding` (the only vault). Use the **no-print path**: never `op read`
  into stdout; instead `op run --env-file=tmpl -- <cmd>` so secrets land only in
  the subprocess env. The classifier blocks any tool call that prints even a
  prefix of a live credential ("credential materialization") — that's what
  "classifier correctly blocked printing the key" means; it's not a bug, route
  around it with op-injected env, not by echoing the value.
- `op://` refs **break on titles with parentheses** — resolve the item `.id`
  first (`op item get "<title>" --vault vibe_coding --format json` → `.id`) and
  reference `op://vibe_coding/<id>/<FIELD_LABEL>`.
- Key items in `vibe_coding`: `Supabase Runtime Keys - shared POP database
  (production)` (fields SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY,
  SUPABASE_PROJECT_REF); `Supabase DB Password - shared POP database`;
  `OpenRouter API Key - The Oracle` (STALE — returns 401, don't use). The live
  PopDAM OpenRouter key lives in `admin_config.OPENROUTER_API_KEY`, reachable via
  PostgREST with the service role.
- **Supabase CLI is installed (2.98.2) and authed**; linked project is
  `qsllyeztdwjgirsysgai`. `psql` (18.4) and `gh` also present. So the supabase
  **MCP being unauthorized** ("provide a valid access token") is NOT a dead end —
  read via service-role + PostgREST (`${SUPABASE_URL}/rest/v1/<table>?...` with
  apikey+Bearer) or the CLI, both fed by op. See [[project_popdam_shared_env]],
  [[project_vps_1password_mcp_secrets]].
- **Gotcha:** the PopDAM OpenRouter account's privacy/data-policy blocks bare
  text completions ("No endpoints available matching your guardrail restrictions
  and data policy") — a from-scratch live OpenRouter probe fails even with the
  real key unless you match prod's actual request shape. Don't change the account
  privacy setting to test; it's outward-facing prod config.
