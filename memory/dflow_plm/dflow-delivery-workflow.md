---
name: dflow-delivery-workflow
description: "dflow PLM repo layout, branch model, and delivery flow (commit → push → PR to develop)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0057598e-90ba-4bdd-939a-d204b1cf673b
---

The workspace `C:\repos\dflow plm` is **not** a git repo itself; it contains 6 separate repos under the `popcre` GitHub org: `designflow-backend`, `-bff`, `-data-syncing`, `-frontend`, `-item-master`, `-tracking`. (The project moved from `D:` to `C:` — CLAUDE.md memory paths referencing `D--repos-dflow` are stale; sessions live under `C--repos-dflow-plm`.)

Branch model: work happens on **`sandbox-albert`**. Delivery = commit on sandbox-albert → push `origin/sandbox-albert` → PR `sandbox-albert` → `develop` (never touch `main`). When syncing, `develop` is typically already fully merged into `sandbox-albert`. Pushing often hits non-fast-forward (concurrent activity) — resolve with `git pull --rebase --autostash`. Commit surgically (only your own files; the working trees often carry unrelated pre-existing changes). See [[git-commit-identity]] and [[codex-concurrency-incident]].
