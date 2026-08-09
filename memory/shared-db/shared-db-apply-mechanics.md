---
name: shared-db-apply-mechanics
description: "How shared-db migrations actually get applied to prod, and two traps"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c2fb38ad-dde0-459e-9563-443c4d2c38e1
  modified: 2026-08-06T17:58:56.647Z
---

Applying `u2giants/shared-db` migrations to the shared backend
(`qsllyeztdwjgirsysgai`):

- The **Supabase MCP is read-only** in this environment — `apply_migration`
  fails with "Cannot apply migration in read-only mode." Use `execute_sql` only
  for read-only validation. DDL goes through GitHub, not MCP.
- **The Supabase MCP is connected to PRODUCTION `qsllyeztdwjgirsysgai`, not
  preview** (confirmed 2026-08-06). This misleads: querying a preview-only
  object such as `plm.taxonomy_parallel_observation` returns
  `42P01 relation does not exist`, which reads as a broken schema but actually
  means *wrong database*. Phase 6 objects exist ONLY on preview. There is no MCP
  route to preview — use the workflow lanes or the Management API.
- **The workflow is only safe when the backlog is empty.** It runs a plain
  `supabase db push`, which promotes EVERY pending file, not just yours. When
  others are pending (deliberately-held ColdLion work, etc.), use the bounded
  temp-worktree path in AGENTS §5.1 instead: worktree off `origin/main`, delete
  every migration you are not promoting, then `db push`. Confirmed 2026-07-26.
- Apply path = the **`shared-supabase-migrations` GitHub workflow**
  (`gh workflow run shared-supabase-migrations.yml -f target=<preview|production>
  -f mode=<dry-run|apply>`). PRs only run static `scripts/check-sql.sh`;
  migrations are NOT auto-applied on merge — you must dispatch the workflow.
- The workflow runs plain `supabase db push` (no `--include-all`). When prod
  history has an **out-of-order** pending file (a timestamp earlier than the last
  applied), db push refuses: "Found local migration files to be inserted before
  the last migration… Rerun with --include-all." Then apply batch-applies ALL
  pending migrations from every session — a coordination decision, not unilateral.
- **Preview project (`rjyboqwcdzcocqgmsyel`) ledger is unreliable** (has
  `preview_ledger_marker` rows): dry-run says "up to date" while apply fails with
  "repair the migration history table." Preview could not be used to de-risk
  as of 2026-07-22. Verify logic read-only against prod data instead.

Related: [[shared-db-change]]. popdam3 is main-only and its GitHub ruleset
**blocks creating new branches** ("creations being restricted") — feature work
must land on main (which deploys), so DB-dependent frontend must wait for the
prod apply.
