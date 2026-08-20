---
name: claude-mcp-config-file
description: Claude Code reads local MCP servers from ~/.claude.json, NOT ~/.claude/settings.json; the ai-devops setup scripts write to the wrong file.
metadata:
  type: project
---

Claude Code ignores an `mcpServers` block in `~/.claude/settings.json`. Local MCP
servers must be registered in `~/.claude.json` (use `claude mcp add -s user`).

**Why:** On 2026-08-20 all 11 local MCP servers (1password, codex-cli,
supabase, synology-monitor, devops-mcp, playwright, chrome-devtools, vercel,
ag-grid, trigger, recall-ai) were present in `~/.claude/settings.json` but
`claude mcp list` showed only the account-synced claude.ai connectors. Re-adding
them with `claude mcp add -s user` made 8 connect immediately. vercel and
recall-ai need browser OAuth; trigger times out on npx cold start.

**Fixed 2026-08-20** in commit 65ce7c0 on u2giants/ai-devops main. **How to apply:** the bug was upstream in `u2giants/ai-devops` —
`bin/setup-secrets.sh` (~line 302-388) and `bin/setup-machine.ps1` (~line 666-689,
whose comment wrongly claims "Claude Code reads its OWN ~/.claude/settings.json")
both merged the server set into settings.json; they now write ~/.claude.json and
strip the stale block out of settings.json. If MCP servers ever vanish again,
check which file they landed in FIRST. Related:
[[mcp-1password-launcher-storm]].

**Git Bash trap:** `claude mcp add ... -- cmd /c npx ...` from Git Bash silently
rewrites the `/c` flag to `C:/` (MSYS path conversion), producing a server that
is registered but can never launch. Prefix with `MSYS_NO_PATHCONV=1` and use
`//c`, then correct the stored value back to `/c` — or add the entry with a
Python/PowerShell JSON edit instead. Bit railway on 2026-08-20.
