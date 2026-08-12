---
name: shared-db-production-apply-lane
description: "dflow schema changes only reach the live DB via shared-db's production lane, and atomic batches (B9) forbid applying one migration alone"
metadata: 
  node_type: memory
  type: project
  originSessionId: 67ac4451-4bf8-4ae6-97b1-b2a0c0fa2789
  modified: 2026-08-12T17:40:04.883Z
---

Merging a migration into `u2giants/shared-db` main does NOT put it in the live database
(`qsllyeztdwjgirsysgai`). A separate `Shared Supabase Migrations` workflow dispatch applies it:
target=production, mode=apply, exact `origin/main` SHA, typed `APPLY <sha>` confirmation, a
`review_reference`, and Albert approving the `production` environment gate. The Supabase MCP is
read-only and cannot apply anything.

`scripts/production_migration_guard.py` marks batches B1, B3, B7, B9 ATOMIC — a single-version
allowlist inside one of them is refused, because resting mid-batch leaves known security holes.
So "just apply this one file" is often not an option; the whole batch ships.

**Why:** on 2026-08-12 dflow sandbox login was fully down (SYS-030 `column "office_location" does
not exist`, and a bare 401 on Azure SSO) because the backend shipped code reading two columns
whose migration `20260810160000` sat merged-but-unapplied inside atomic batch B9.

**How to apply:** when app code reads a new dflow column, confirm the migration is in the live
ledger before shipping, not just merged. File a `db-work` issue on shared-db naming the full
batch. See [[dflow-db-supabase-migration]] and [[shared-db-canonical-repo]].
