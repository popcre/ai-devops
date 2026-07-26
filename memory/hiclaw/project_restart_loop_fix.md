---
name: project-restart-loop-fix
description: Gateway 5-minute restart loop root cause and fix (resolved 2026-05-21)
metadata: 
  node_type: memory
  type: project
  originSessionId: 350cc1b5-aa14-4818-a802-a8e3ca45c6fa
---

The OpenClaw gateway was restarting every 5 minutes (in-process SIGUSR1) triggered by `manager-config-keeper.sh`.

**Root cause**: The gateway uses its **initial startup config as the reload diff baseline**, stored in `config-health.json`. The startup script writes `commands.restart: true` before starting the gateway; this becomes the permanent baseline. Any subsequent write that changes the `commands` field — including `null→{}`, `{}→null`, or removing the restart key — shows up in the diff and triggers a full in-process restart.

The controller writes `commands: null` every ~5 minutes. The keeper was writing `commands: {}`, causing a `commands` diff against the startup baseline.

**Fix**: `manager-config-keeper.sh` now writes `commands: {restart: true}` permanently. This matches the startup baseline exactly — zero diff — so keeper's schema fixes (allow→enabled, whatsapp entries) are applied as hot reloads.

**Do not change**: Writing any other value (`{}`, `null`, `false`) causes restarts every cycle.

**Confirmed**: Gateway stable for 10+ minutes with hot reloads only after fix. Commit: 64791ba.

**Why:** [[project-minio-recursion-fix]]
