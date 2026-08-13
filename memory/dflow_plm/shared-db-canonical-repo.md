---
name: shared-db-canonical-repo
description: "Canonical shared Supabase DB repo — location, distinct main-branch PR workflow, and when DB changes belong there vs the app"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1f4e224d-eceb-40de-a51d-280cd51d19e6
---

`u2giants/shared-db` is the single source of truth for the shared Supabase database, cloned locally at `C:\repos\shared-db`. Its contents are mirrored (read-only) into the `shared-db/` folder of every consumer repo on each push to `main` — never hand-edit those mirror copies.

**Workflow differs from the DesignFlow app repos.** App repos (frontend/backend/bff) use `sandbox-albert → develop`, never `main`. shared-db has **no `develop`**: work on a feature branch, open a PR to **`main`**, and the AI is expected to merge it (docs-only PRs merge promptly after `scripts/check-sql.sh`). Merging `main` auto-syncs to all apps. Self-merging your own PR is blocked by the auto-mode guard — needs explicit user say-so ("you merge").

**Where a DB change goes** (per workspace `SUPABASE-MIGRATION.md`): shared/cross-app schema, views, RPCs, RLS, `supabase/migrations/*.sql` → shared-db (new `YYYYMMDDHHMMSS_*.sql`, additive, preview ref `xjcyeuvzkhtzsheknaiu` before prod `qsllyeztdwjgirsysgai`). Service-specific additive columns on **app-owned** tables (e.g. PLM `GridViewState`, `GridLayout*`) stay in the backend as an idempotent `ADD COLUMN IF NOT EXISTS` startup migration in `models/db.js` + model + `tests/unit/db.migration.test.js` — these tables are NOT in shared-db's `core`/`plm` migration lineage, so record them as a note in `docs/app-migration-notes/`, not a SQL migration. The `forbid-shared-db-bypass.yml` CI (now in every app repo) fails PRs that add `supabase/migrations/*.sql` or reference DB secrets/`supabase db push` in scripts/workflows/package.json. See [[dflow-delivery-workflow]].
