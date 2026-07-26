---
name: ai-stage-improvements-2026-05-31
description: Three agent/pipeline improvements shipped 2026-05-31 to close gaps identified via SSH-vs-monitor comparison
metadata: 
  node_type: memory
  type: project
  originSessionId: d55a3937-ec07-4fe0-b642-b69b7dcd321c
---

Three improvements shipped 2026-05-31 to close the accuracy gaps between the automated monitor scan and a root SSH session.

**Why:** A monitor scan from 2026-05-29 reported six RAID5 arrays resyncing simultaneously and 257 inflight I/Os on md5. An SSH session later showed only one active resync and low inflight counts. Root causes: (1) inflight I/O was never emitted to the DB, (2) Drive client logs weren't being collected despite the mount existing, (3) Stage 2 had no way to read raw log files or /proc//sys on-demand.

**What changed:**

1. `apps/agent/internal/collector/diskstats.go` — emits `disk_inflight_ios` metric (instantaneous gauge, type=count) alongside the existing DiskIOStat payload. Goes to the `metrics` table; no schema migration needed.

2. `apps/agent/internal/logwatcher/watcher.go` — `inferDriveLogFiles` now tries `/host/shares` as the first base (the actual container mount point from docker-compose.agent.yml) before the legacy `WATCH_PATHS`. Drive client logs at `/host/shares/@synologydrive/log/*.log` are now collected.

3. `apps/web/src/lib/server/ai/stage2-reasoning.ts`:
   - Added `run_command` tool to Stage 2's tool catalog — free-form tier-1 shell (cat, tail, /proc, /sys). Validated through same tier check as predefined tools.
   - `buildWholeSystemSnapshot` now probes `nas-api /health` with a 3s timeout to set real `nasReachable` instead of hardcoded true.
   - System prompt updated to tell the model about `run_command`.

4. `apps/web/src/lib/server/ai/stage3-explainer.ts` — fixed bug: was reading from legacy `issue_evidence` table (empty in new pipeline); now reads `issue_evidence_items` filtered to `in_scope=true`, limit 30.

5. `PLAN.md §3` — replaced with detailed spec for all three stages (§3.1/§3.2/§3.3).

**How to apply:** Agent changes take effect after next Docker image build + deploy. Web changes deploy automatically on main push.
