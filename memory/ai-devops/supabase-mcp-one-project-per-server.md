---
name: supabase-mcp-one-project-per-server
description: "Supabase MCP takes exactly one --project-ref; extra projects get a project-scoped .mcp.json in their own repo, routed through the ai-devops launcher."
metadata: 
  node_type: memory
  type: project
  originSessionId: e320f643-2527-46d4-aa44-ca6e6a233c33
  modified: 2026-07-29T22:55:43.093Z
---

`@supabase/mcp-server-supabase` accepts exactly **one** `--project-ref`. There is no
multi-project mode. The Supabase PAT is account-wide (one shared token for ALL POP apps —
never create a per-app Supabase token), so the limit is the server, not the credential.

A second project therefore needs a second server entry. Do **not** add it to the global
`$McpServers` set in `bin/setup-machine.ps1` — a global entry loads ~20 tools into every
unrelated session (dflow, shared-db). Put a project-scoped `.mcp.json` in that app's repo.

Set up 2026-07-29 — `C:\repos\oracle\.mcp.json` defines `supabase-oracle` →
`eqccjfbyrywsqkxxpjvg` ("theoracle", same org as popdam), read-only. It routes through
`${USERPROFILE}\.config\ai-devops\mcp-launch.cmd` exactly like the global `supabase` entry,
so the PAT is injected from 1Password at launch. Because it's committed, it reaches every
machine by `git pull` — no per-machine step beyond having ai-devops installed.

**Do NOT use `${SUPABASE_ACCESS_TOKEN}` in a Windows `.mcp.json`.** `mcp.env` describes that
placeholder pattern, but it only works where a login shell pre-resolves the env (Ubuntu). On
Windows it would need a permanent OS env var holding the PAT, and the ONLY OS env var allowed
is the 1Password service-account token — everything else resolves from 1Password. Use the
launcher instead. See [[supabase-mcp-canonical-setup-script]].

Rejected alternative: the **session pooler** as a general AI access path. It's a plain
Postgres connection, so it strictly loses functionality (logs, advisors, edge functions, type
generation, branches are all management-API only) while *removing* the `--read-only` guardrail
and requiring the DB password. Against the shared DB that's a direct-DDL path, which
[[shared-db-change]] forbids. If a pooler is ever needed, use a dedicated read-only Postgres
role so the database enforces it.

**How to apply:** one project per MCP entry; extra projects go project-scoped in their own
repo via the launcher; never hand a session a raw pooler/psql connection to the shared DB.
