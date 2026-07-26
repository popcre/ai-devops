---
name: trigger-pat-cli-whoami-false-negative
description: "`npx trigger.dev whoami` rejects the post-2026-07-26 Trigger PATs even though the management REST API and the trigger MCP accept them — verify these tokens with the API, never the CLI"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c2b905f-9e65-49f5-b5bf-9d73bab09ead
  modified: 2026-07-26T18:05:39.039Z
---

The Trigger.dev PATs rotated on **2026-07-26** (item `Trigger.dev Personal Access
Token (management)`, id `ylzcsfbhmjyzjy65mnu6uxw67e`) fail `npx trigger.dev@latest
whoami` with *"Invalid or Missing Access Token"* — reproduced on CLI **4.5.7 and
4.4.1**, and with the env var named either `TRIGGER_ACCESS_TOKEN` or
`TRIGGER_PERSONAL_ACCESS_TOKEN`. The same tokens are **fully valid**:
`GET https://api.trigger.dev/api/v2/whoami` → 200 (hello@popcre.com), the project
envvars endpoint → 200, and the `trigger` MCP `list_orgs` → org POP/`pop-13dc`.

**Why it matters:** the pre-rotation token DID work with the CLI, so a session that
health-checks a rotation with `trigger.dev whoami` sees a clean-looking failure and
concludes the rotation broke — then re-rotates or hunts a nonexistent paste error.
That happened during Phase 2d and cost real time.

**How to apply:** verify Trigger PATs with the management REST API or the MCP, not
the CLI subcommand. The item now holds two tokens — `credential` (owner level) and
field id `qeqqkatqor6dphspzwyandzwhe` (admin level); `config/mcp.env.example`
references the admin one for least privilege. After any rotation, delete
`~/.config/ai-devops/mcp-secrets.dpapi.json` (the 15-min DPAPI cache) or the old
value keeps resolving.

See [[op-account-migration-2026-07]].
