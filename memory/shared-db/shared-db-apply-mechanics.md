---
name: shared-db-apply-mechanics
description: "How shared-db migrations actually get applied to prod, and two traps"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c2fb38ad-dde0-459e-9563-443c4d2c38e1
  modified: 2026-07-23T01:27:40.687Z
---

Applying `u2giants/shared-db` migrations to the shared backend
(`qsllyeztdwjgirsysgai`):

- The **Supabase MCP is read-only** in this environment — `apply_migration`
  fails with "Cannot apply migration in read-only mode." Use `execute_sql` only
  for read-only validation. DDL goes through GitHub, not MCP.
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
