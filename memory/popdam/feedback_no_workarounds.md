---
name: feedback-no-workarounds
description: "User wants tools/connections fixed properly, not worked around with best-effort substitutes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1624e8a0-ee84-4176-893a-8001e4fc575c
---

When a needed capability isn't available (an MCP tool isn't connected, a credential is missing, live log/infra access is absent), do not silently fall back to a lesser substitute (e.g. static code review instead of live log queries) and report it as if the job were fully done. Diagnose the actual root cause of why the tool/connection isn't working, fix it properly if it's within reach (e.g. a config gap), and if it requires something only the user can provide (a credential, a decision, access you don't have), stop and ask for exactly that — state precisely what's missing and why.

**Why:** Triggered 2026-07-08 when asked to check "all the logs for all errors" — several MCP servers (`supabase` in particular) were not connected. Initial response did a code-only review and reported it as complete without clearly flagging the gap upfront as a blocker to push on. Corrected instruction: "why not? connect them. no workarounds or best-effort. do it right and ask me for the tools you need to do it right if you don't have that."

**How to apply:** Before reporting a task done, check whether a missing tool/connection silently narrowed the scope of what was actually checked/done. If so, either fix the root cause (e.g. this session found `supabase` MCP failed because `.mcp.json`'s `supabase` server entry had no `env` block wiring `SUPABASE_ACCESS_TOKEN`, unlike `devops-mcp`/`synology-monitor` which use the `${VAR}` placeholder pattern already resolved via 1Password — fixed by adding the matching `env` block) or explicitly ask the user for the missing piece rather than quietly downgrading to best-effort and moving on. See [project_popdam_shared_env](project_popdam_shared_env.md) for the specific PopDAM MCP-token mechanism this applies to.

This is a general working preference, not specific to any one tool — applies whenever a task's real scope depends on access/tools not currently available.
