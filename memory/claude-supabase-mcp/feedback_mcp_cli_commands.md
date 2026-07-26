---
name: MCP CLI command format issues on Windows
description: The claude mcp add CLI command misparses flags like -y as its own options on Windows
type: feedback
---

Never use `claude mcp add` CLI to configure MCP servers on this machine — it misparsed `-y` as its own option (error: "unknown option '-y'").

**Why:** The CLI argument parser doesn't correctly handle flags after the `--` separator on Windows in at least two instances (Supabase setup, Playwright setup).

**How to apply:** Always edit `C:/Users/ahazan2/.claude.json` directly to add/modify global MCP servers. For project-level servers, edit the `.mcp.json` file in the project root directly.
