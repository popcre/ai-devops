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

**How to apply:** The bug is upstream in `u2giants/ai-devops` —
`bin/setup-secrets.sh` (~line 302-388) and `bin/setup-machine.ps1` (~line 666-689,
whose comment wrongly claims "Claude Code reads its OWN ~/.claude/settings.json")
both merge the server set into settings.json. Until those are fixed, every
machine re-setup silently un-registers every MCP server. Related:
[[mcp-1password-launcher-storm]].
