---
name: supabase-mcp-canonical-setup-script
description: "MCP config is owned by ai-devops bin/setup-machine.ps1; the Dropbox setup-claude-mcps.ps1 is LEGACY — don't edit it."
metadata: 
  node_type: memory
  type: project
  originSessionId: e320f643-2527-46d4-aa44-ca6e6a233c33
  modified: 2026-07-29T22:56:07.876Z
---

MCP server configuration has already moved into the hub. The canonical writer is
**`C:\repos\ai-devops\bin\setup-machine.ps1`**:

- One `$McpServers` ordered hashtable defines every server **once**, and both Claude Desktop
  and Claude Code merge it. Its own comment says separate hand-maintained lists were "the root
  cause of every gap this script has had." **Add new global servers there and nowhere else.**
- Secrets are never written to disk. Servers launch via `~/.config/ai-devops/mcp-launch.cmd` →
  `bin/mcp-secret-launch.ps1`, which does ONE mutex-serialized `op run` refresh into a 15-minute
  DPAPI-encrypted cache (the fix for [[mcp-1password-launcher-storm]]). References live in
  `mcp.env` as name-based `op://` refs.

**`C:\Dropbox\vibe coding\set up synology and VPS MCP servers in claude windows\setup-claude-mcps.ps1`
is LEGACY and superseded.** `setup-machine.ps1` refers to it as "the legacy Dropbox script."
Don't edit it, and don't tell Albert to run it — it hard-coded PATs in plaintext, and running it
would overwrite the launcher-based entries with token-bearing ones. It should be deleted.

**Mistake made 2026-07-29 (don't repeat):** when asked to remove a plaintext Supabase PAT, I
edited the Dropbox script instead of checking the hub first — so the work landed in a dead file
while the live config path was already token-free. Locate the canonical script in `ai-devops`
before touching any MCP or machine-setup config, however plausible a Dropbox path looks in the
machine atlas.

**How to apply:** global MCP change → `bin/setup-machine.ps1`. Per-app project MCP → that repo's
`.mcp.json` via the launcher ([[supabase-mcp-one-project-per-server]]). Never the Dropbox script.
