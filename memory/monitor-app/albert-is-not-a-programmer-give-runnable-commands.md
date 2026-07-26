---
name: albert-is-not-a-programmer-give-runnable-commands
description: "The user is an operator, not a programmer — hand-off steps must be exact copy-pasteable commands with host, path, and expected output, never \"deploy X\" or \"enable Y\"."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 02913776-8d59-48dc-ac7f-cfb46f678c1f
---

The user is **not a programmer**. Every instruction handed to him must be a literal,
copy-pasteable command with the real host, the real path, and the expected output —
never a verb-plus-noun like "deploy nas-mcp", "enable the tool in tools-config.json",
"recreate the container", or "run the migration". He has told me to stop this
repeatedly; on 2026-07-16 he said "for the 1000th time".

**Why:** these phrases feel actionable to me because I can already see the file, the
host, and the command behind them. He cannot. A step like "deploy nas-mcp, then
enable it" is not a small omission — it is the whole task, unstated. It reads as
being handed a ticket rather than an answer, and it silently transfers the work of
reconstructing my reasoning back onto him. It is the single most repeated complaint
in this project.

**How to apply:**
- Write the exact command: `ssh albert@192.168.3.100`, then `cd /volume1/...`, then
  the literal line to run. Include `sudo` where it is needed.
- Say what correct output looks like, so he can tell success from failure himself.
  "You should see `74:      - /etc/group:...`" beats "verify the mount landed."
- Name the machine and the file. "Edit line 73 of
  `/volume1/docker/synology-monitor-agent/compose.yaml` on edgesynology1" —
  not "update the compose file".
- If a step is a UI action, name the clicks: DSM → Container Manager → Project → …
- If I cannot give a runnable command (no access, unknown value), say exactly which
  value is missing and ask for it. Never paper over it with a verb.
- Order the steps and number them. One command per line.
- This applies to *anything* handed over: deploys, verification, rollback, secrets.

Related: [[verify-mcp-availability-via-claude-mcp-list]] — the other standing failure
mode here is telling him something is impossible without checking first.
