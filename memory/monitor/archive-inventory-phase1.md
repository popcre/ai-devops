---
name: archive-inventory-phase1
description: Synology Archive Inventory — Phase 1 (read-only) shipped 2026-06-07; Phase 2 (move) is next.
metadata: 
  node_type: memory
  type: project
  originSessionId: fea6f8ea-e2c9-45c2-8a5c-1863520d4f30
---

The Synology Archive feature (file inventory → archive move) is specced in
`docs/synology-archive.md` (design) + `docs/synology-archive-implementation.md`
(build guide), now committed to the repo.

**Phase 1 (read-only inventory) shipped 2026-06-07** — pushed to `main`, all CI
image builds green. nas-api `internal/jobs/` (WalkDir scanner, mtime-year +
date-protection via statx, best-effort sqlite Drive/ShareSync overlay, atomic
store, scheduler, startup recovery) behind six `/jobs/inventory/*` REST endpoints;
5 MCP tools (`job-client.ts`, native dispatch, not `/exec`); web `/archive-inventory`
page + `/api/archive/*`. Backend has Go tests (incl. canonical-op-string + race).

**Gotcha — `NAS_API_NAME` ≠ agent `NAS_NAME`.** The inventory job system reads a
dedicated `NAS_API_NAME` env (the logical `edgesynology1/2` name the web/MCP sign
canonical op strings with). The agent's existing `NAS_NAME` is a heartbeat display
name ("Synology NAS 1"); reusing it would break every tier-2 approval signature.
Don't merge the two.

**Deploy needs a one-time `docker compose up -d` per NAS** to materialize the
`/app/data/jobs` mount + `NAS_API_NAME` (Watchtower ships images, not compose
changes). Until then `/jobs/inventory/*` returns 503 by design.

**Overlay query is best-effort/heuristic** — the live Synology Drive/ShareSync
SQLite schema was unverified in-session; `overlay.go` copies DBs read-only and
guesses a (path,time) column pair, degrading to a note rather than failing the job.
Confirm/tune the query during live verification.

**Phase 2 (archive move) ALSO shipped 2026-06-07** — pushed to main, CI green
(nas-api gate now runs the move tests). Staged `archive_move` state machine
(plan→preflight→snapshot→execute→verify→rollback + `clean_empty_dirs`) in
`internal/jobs/move.go`/`dirs.go`/`manifest.go`/`btrfs.go`; rename-only within the
Btrfs subvolume with per-file identity verify-and-rollback; JSONL manifest;
8 `/jobs/archive-move/*` endpoints (execute/rollback tier 3); 7 MCP tools;
`/archive-move` web page (plan→review-gate→type-share-name execute→verify→rollback).

**Phase 2 gotchas:** moves write via the **`:rw` `/btrfs/volume1/<share>`** mount,
NOT the `:ro` `/volume1/<share>` (no compose change needed — the rw mount already
exists). Btrfs subvolume/snapshot calls are behind an injectable `fsOps` interface
(`btrfs.go`) so move logic is unit-tested on temp trees; **the real btrfs snapshot
path is unverified in-session and must be validated live** on a small real share
(e.g. Coldlion) per the design's end-to-end test. ctime is intentionally NOT
preserved by rename (no syscall can) — the verifier tolerates ctime change, checks
inode/size/mtime/btime. See [[ai-rebuild-plan]] for the "code from the doc" pattern.
