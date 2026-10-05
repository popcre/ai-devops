# Coord-deletion residuals — C4a machine-tools verify + C4b t16 reachability probe

Plan: `plan_shared-db-coordination-deletion.md` Phase E residual slice (parent #1061, tracking #1183 child 4). Owner: residual slice only.

## Identity

| Field | Value |
|---|---|
| Machine (probe origin) | `edge-dev` |
| Timestamp (UTC) | `2026-10-05T01:15:44Z` – `2026-10-05T01:16:47Z` |
| Timestamp (EST/EDT) | 2026-10-04 9:15 PM EDT – 9:16 PM EDT |
| Source commit (`origin/main`) | `e59f903721ed5da505f11b920843e4569bb5ec34` |
| Worktree / branch | `C:/repos/ai-devops-wt-c4-adopt` / `mimo/1183-c4-adopt` (no code change expected) |

## C4a — `config/machine-tools.tsv` duplicate-row fix is complete

The duplicate-row defect (`ai-blocker-watch`, `ai-reap-shared-db-worktrees`) is
**already fixed on current `origin/main`** by PR #1168 / commit `45cd6b5e`.
This session re-proved the fix at `e59f9037` and made **no code change**.

Catalog check at `e59f9037` (first column = command name):

- data rows: **36**
- unique command names: **36**
- duplicate groups: **none**

Guard still in place: `bin/install-machine-tools.ps1` lines 73–74 throw
`Machine-tools catalog has an unsafe or duplicate command name.` on any
repeated first-column value, so the launcher half of `bin/ai-adopt-globals`
can complete on every host.

Focused tests (Git Bash on edge-dev, worktree `mimo/1183-c4-adopt`):

| Test | Result |
|---|---|
| `bash tests/test-ai-machine-tools.sh` | **PASS** — `PASS: machine tool catalog, repair, doctor, bootstrap, and skill contracts` |
| `bash tests/test-install-ai-provider-clis.sh` | **PASS** — exit 0 under `set -euo pipefail` (contract suite for the provider installer; no FAIL emitted). One earlier attempt was killed mid-run by a transient Git Bash `fork: retry: Resource temporarily unavailable`; a clean re-run exited 0. |
| `bash tests/test-ai-adopt-globals.sh` | **PASS** — `ALL TESTS PASSED` (10/10) |

**C4a slice: DONE.** No code PR is opened: the fix already sits on `origin/main`.

## C4b — t16 reachability probe (2026-10-04 9:15 PM EDT)

Target: `t16` (atlas alias `albt16`, Windows 11 dev box). Prior unreachable
record: `adopt-t16-20260930T053832Z.md` (2026-09-30, Tailscale offline).

Probe results from `edge-dev`, 2026-10-04 9:15 PM EDT / `2026-10-05T01:15Z`:

1. **No SSH alias.** `grep -i -E 't16|albt16' ~/.ssh/ai-devops.conf` → no
   matches (exit 1). Same as 2026-09-30.
2. **Tailscale: ONLINE (changed).** `tailscale status` now lists `t16` as a
   live Windows peer (address redacted for the public boundary) **without** an
   `offline` marker — unlike the 2026-09-30 record.
3. **Ping: SUCCEEDS (changed).** `ping -n 1` to the Tailscale address →
   1 received / 0 lost, ~15 ms. `ping albt16` → `Ping request could not find
   host albt16.` (hostname alias still absent).
4. **SSH: UNREACHABLE (unchanged).**
   - `ssh u2giants@<tailscale-ip>` → `Connection timed out` (port 22).
   - `ssh -o HostName=<tailscale-ip> t16` → `Connection timed out`.
   - `tailscale ssh t16` → `dial failure ... connectex: A connection attempt
     failed ... 502 Bad Gateway`.
5. **Alternate ports: all closed/timeout.** TCP probes to ports 22, 2222,
   2022, 443, 3389 on the Tailscale address all closed or timed out.

**Conclusion: t16 is NOT remotely adoptable from edge-dev.** It is online on
Tailscale (ICMP reachable) but runs no accepting SSH/remote-access listener —
the same long-standing condition recorded in
`plan_context-engineering-consolidation.md` ("unreachable over SSH ... port 22
closed ... can only be adopted by someone sitting at it"). No `bin/ai-adopt-globals`
run, no installed copy touched on t16.

When t16 is next reachable (or someone sits at it), its own
`adopt-t16-<UTC>.md` proof (real `bash bin/ai-adopt-globals` + body-vs-template
gate) supersedes this probe. Tracking checklist item is left on #1183:
`- [ ] t16 live adopt proof when reachable`. No new issue is opened.

Posted by MiMo chat ses_ffe5ef69ac023ffeXUWiefKcGx on edge-dev
