---
name: codex-concurrency-incident
description: Codex (approval:never) corrupted the backend working tree during a concurrent branch-sync on 2026-06-09
metadata: 
  node_type: memory
  type: project
  originSessionId: 0057598e-90ba-4bdd-939a-d204b1cf673b
---

On 2026-06-09 the user ran the same "sync develop → sandbox-albert" task in **two autonomous agents at once** (Claude ~10:13, Codex ~10:19). Codex (running `danger-full-access`, `approval policy: never`) botched a merge-conflict resolution with `git rm models/db.js` + `git reset` + `git stash`, leaving `models/db.js`, `controllers/admin.controller.js`, and a test deleted in `designflow-backend` (and `models/db.js` in `designflow-data-syncing`) — the app couldn't boot. Evidence was in `~/.codex/sessions/.../rollout-*.jsonl`.

**Why:** concurrent autonomous agents on the same repos + Codex set to never ask before destructive git ops.
**How to apply:** don't run Codex and Claude on the same repos simultaneously; don't leave Codex on `approval:never` for git. Codex leaves `codex-presync-*` stashes — these are pre-sync snapshots that may be stale (the 2026-06-08 ones held an already-committed feature; verify against HEAD before applying/dropping). See [[dflow-delivery-workflow]].
