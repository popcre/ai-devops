---
name: nas-mcp-is-named-synology-monitor
description: "The NAS MCP server is registered as \"synology-monitor\", and worktree sessions don't load it because .mcp.json is untracked"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9731c810-5856-419a-8d5b-bb12127f33c5
---

The repo's NAS MCP (`apps/nas-mcp`, live at `https://nas-mcp.designflow.app/mcp`) is
registered under the server name **`synology-monitor`** — not "nas-mcp". Searching for
"nas" tools finds nothing. It is a different server from `devops-mcp`
(`mcp.designflow.app`), which is VPS/host-scoped and has no Synology operations.

Config lives in `/worksp/monitor/app/.mcp.json`, which is **untracked** (was only in
`.git/info/exclude`; added to `.gitignore` on 2026-07-16). Consequences:

- **Git worktrees under `.claude/worktrees/` have no `.mcp.json`**, so the server never
  loads in a worktree session even though `claude mcp list` reports it Connected —
  that command reads the main project dir. Same reason `pnpm-lock.yaml` is missing there.
- The token in `.mcp.json` is **stale/rotated** (returns `{"error":"Unauthorized"}`).
  The live one is in `~/.claude.json` → `mcpServers.synology-monitor.headers.Authorization`,
  and in Coolify as `MCP_BEARER_TOKEN`. See the `nas-monitor-secrets` item in the
  `vibe_coding` 1Password vault.

When the tools aren't loaded, call the endpoint directly over HTTP with the live token
(`tools/list`, or `tools/call` with `run_command` / `invoke_tool`) — it is stateless, so
no initialize handshake is needed. See [[verify-mcp-availability-via-claude-mcp-list]].
