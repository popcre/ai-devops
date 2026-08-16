---
name: shared-db-apply-mechanics
description: "How shared-db migrations actually get applied to prod, and two traps"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c2fb38ad-dde0-459e-9563-443c4d2c38e1
  modified: 2026-08-13T20:21:32.241Z
---

Applying `u2giants/shared-db` migrations to the shared backend
(`qsllyeztdwjgirsysgai`):

- The **Supabase MCP is read-only** in this environment — `apply_migration`
  fails with "Cannot apply migration in read-only mode." Use `execute_sql` only
  for read-only validation. DDL goes through GitHub, not MCP.
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
- **Preview project (`rjyboqwcdzcocqgmsyel`): its LEDGER still lies, but preview
  itself IS usable.** Corrected 2026-08-13. The ledger is applied out of order and
  carries `preview_ledger_marker` rows, so a dry-run can say "up to date" while an
  apply fails with "repair the migration history table," and a high max applied
  version does NOT mean everything below it is applied. **The old line "preview
  could not be used to de-risk" (2026-07-22) is SUPERSEDED** — through August
  preview carried real rehearsals and the full PopDAM OrderList import (3,212
  orders / 24,010 lines, idempotent, all 10 balance checks pass). Apply there by
  the bounded path, then verify **by catalog object, never by the ledger**.
- **Preview and production have diverged in BOTH directions — neither predicts the
  other** (`AGENTS.md` §12.1 item 11, verified 2026-08-11). Preview holds all 23
  `plm.pmt_*` tables and production holds none; `20260810140000` is on production
  and not on preview. A green preview rehearsal never means production will match:
  post-apply verification against production objects is mandatory.

Related: [[shared-db-change]]. popdam3 is main-only and its GitHub ruleset
**blocks creating new branches** ("creations being restricted") — feature work
must land on main (which deploys), so DB-dependent frontend must wait for the
prod apply.
