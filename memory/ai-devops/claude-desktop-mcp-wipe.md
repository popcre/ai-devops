---
name: claude-desktop-mcp-wipe
description: The Claude desktop app silently deletes the whole mcpServers block from claude_desktop_config.json; Settings -> Developer then shows 0 servers.
metadata:
  type: project
---

The Claude desktop app rewrites
`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
and drops the entire `mcpServers` key. Every other key in the file survives.
Settings -> Developer (NOT Settings -> Connectors) is the screen that reads this
file; after a wipe it shows 0 servers.

**Why:** Observed 2026-08-20. The file held all 11 ai-devops servers on 2026-08-18;
at 07:32 on 2026-08-20 the app logged three "Config file written" lines and the
block was gone. No org blocklist (empty) and no dxt allowlist (disabled) were
involved. From that point the app injected only 13 built-in / account connectors
into sessions — none of the 11 local ones. This is a SEPARATE fault from
[[claude-mcp-config-file]]; do not conflate them. That one was about Claude Code
reading `~/.claude.json`; this one is the desktop chat surface.

**How to apply:** Block restored by hand on 2026-08-20 (backup:
`claude_desktop_config.json.pre-restore-20260820.bak`) as a deliberate test of
whether the app wipes it again. CHECK THAT FIRST in any follow-up session:
`cat <path> | python -c "import sys,json;print(len(json.load(sys.stdin).get('mcpServers',{})))"`
— 11 means it survived and the wipe was one-off; 0 means the app is actively
deleting it and restoring the file is a band-aid, so the servers must be reached
another way. Restoring it repeatedly without answering that question is the
wrong move.
