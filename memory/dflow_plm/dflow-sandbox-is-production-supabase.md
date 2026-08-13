---
name: dflow-sandbox-is-production-supabase
description: "The dflow \"sandbox\" (alsand.designflow.app) writes to the PRODUCTION Supabase project qsllyeztdwjgirsysgai, separated only by the dflow schema — test data written there is real and an AI session cannot delete it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 523862e6-fe06-4f9a-a052-cdeefa6d6a7f
  modified: 2026-07-27T22:03:47.091Z
---

Verified 2026-07-27 from `popcre-albert-core-sandbox` (Cloud Run, project
`lithe-breaker-323913`, region `us-east4`): `DB_PROVIDER=supabase`,
`DB_EXPECTED_PORT=6543`, `DB_NETWORK_PATH=public-pooler`, `SCHEMA=dflow`. The target is Supabase
project **`qsllyeztdwjgirsysgai`** — the shared backend, which `u2giants/shared-db` labels
**production**. Sandbox is separated from the other apps only by the `dflow` *schema*, not by a
separate database. This corrects the older assumption that dflow runs on Cloud SQL
(see [[dflow-db-supabase-migration]]).

**Why:** anything an AI session writes while testing on `alsand.designflow.app` lands in
production data, and it cannot clean up after itself. Proven this session: a throwaway saved view
`AI-VERIFY-TMP` needed Albert to delete it by hand in the Supabase dashboard, because
(a) the app has no delete-layout endpoint, (b) the Supabase MCP connects as
`supabase_read_only_user` so both `execute_sql` and `apply_migration` fail with "cannot execute
DELETE in a read-only transaction", and (c) shared-db's
`.github/workflows/shared-supabase-migrations.yml` is dry-run only against production and refuses
an apply outright, so merging a shared-db PR would apply nothing.

**How to apply:** before writing ANY test record on the dflow sandbox, assume it is permanent and
that only Albert can remove it. Prefer read-only verification (API GETs, `getColumnState()`,
console assertions). If a write is genuinely required, tell Albert up front that he will have to
delete it, and give him the exact SQL and the dashboard link
`https://supabase.com/dashboard/project/qsllyeztdwjgirsysgai/sql/new`. Never work around the
read-only guard by pulling the app's DB password out of Secret Manager. Related:
[[shared-db-canonical-repo]], [[dflow-schema-dflow-vs-plm]].
