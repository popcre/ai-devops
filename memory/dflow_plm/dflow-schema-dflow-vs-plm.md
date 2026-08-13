---
name: dflow-schema-dflow-vs-plm
description: "dflow runtime runs on the `dflow` Postgres schema; the segregation migration moves tables to `plm` and can break the app (\"relation does not exist\")"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8272e53b-4774-4824-b410-9f41ab722e8d
  modified: 2026-07-21T21:15:38.776Z
---

The dflow app + all its Cloud Run services run on ONE Supabase Postgres schema:
**`SCHEMA=dflow`** (verified on core/item/tracking/sync sandbox services). It's the
legacy Cloud SQL copy. The Supabase project is `qsllyeztdwjgirsysgai` (the shared
backend, managed by `u2giants/shared-db`).

Separately, shared-db's **schema-segregation** work
(`shared-db/docs/designflow-master-data-migration/designflow-schema-segregation.md`)
moves tables out of `dflow` into new logical schemas (`core`, `app`, `plm`, …) via
`ALTER TABLE … SET SCHEMA`. **`plm` is a near-identical copy of dflow's PLM tables.**

**The trap (happened 2026-07-21):** the six sample-tracking tables (`sample`,
`sample_event`, `sample_comments`, `sample_attachment`, `sample_box`,
`sample_factory_group`) had been moved to `plm`, but the app still reads `dflow`, so
creating a sample failed with **`relation "dflow.sample" does not exist`**. Fix:
migration `20260721201500_restore_dflow_sample_tracking_tables.sql` in shared-db
recreated them in `dflow` as structural copies of the empty plm tables (identity PKs +
5 intra-cluster FKs; the `sample_comments.user_id → app.users` FK omitted because
`dflow.users` has no PK — user_id is app-enforced). Applied via `supabase db push`.

If any other feature throws `relation "dflow.<table>" does not exist`, it's the same
root cause: the table was segregated to `plm`/`core`/`app` ahead of the app being
switched over. Same fix pattern until the app itself is migrated to a multi-schema
search_path. See [[dflow-fixes-register]].
