---
name: project_supabase_virginia_cutover
description: Live PopDAM Supabase project is now Virginia (qsllyeztdwjgirsysgai); the default Supabase MCP points at the decommissioned Ohio .old project — query the wrong one and you get 16h-stale data
metadata: 
  node_type: memory
  type: project
  originSessionId: 18f5033f-df76-4d6c-a271-171812318866
---

As of 2026-06-20 (~21:31 UTC, commit a35414d "chore: cut over Supabase backend to Virginia"), PopDAM moved Supabase projects:
- **LIVE: `qsllyeztdwjgirsysgai`** — name "popdam", region us-east-1 (Virginia), created 2026-06-20. This is prod now.
- **OLD/decommissioned: `ryltkzzernhwnojzouyb`** — name "popdam-prod.old", region us-east-2 (Ohio). Frozen since ~2026-06-20 17:38 EDT.

**TRAP:** the default `mcp__supabase__*` tools (and `get_project_url`) are still bound to the OLD Ohio project `ryltkzzernhwnojzouyb`. Querying them returns real-looking but 16h-stale data (e.g. agent_registrations frozen at the cutover moment), which can be mistaken for a "heartbeat persistence regression." For LIVE data use `mcp__claude_ai_Supabase__execute_sql` with `project_id: "qsllyeztdwjgirsysgai"`.

**How agents migrated:** bridge/windows agents still have `SUPABASE_URL=https://ryltkzzernhwnojzouyb.supabase.co` baked in their container env, but `apps/{bridge,windows}-agent/src/config.ts` added `migrateSupabaseUrl()` which rewrites the legacy Ohio URL → Virginia (`qsllyeztdwjgirsysgai`) at runtime. So an agent only points at Virginia once it's running the post-cutover build (bridge ≥1.16.3). On the live Virginia DB both agents heartbeat normally every ~30s. Related: [[project_bridge_self_updater]], [[project_cicd]].

Many sibling projects exist in the same org (theoracle, synomon, poppim, popcrm, oracle.old, popdam-prod.old) — match by `name`/`region`, don't assume.
