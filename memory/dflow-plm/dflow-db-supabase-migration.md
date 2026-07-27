---
name: dflow-db-supabase-migration
description: "dflow's database moved OFF GCP Cloud SQL TO supabase.com — the sandbox is already fully on Supabase (verified 2026-07-27)"
metadata: 
  node_type: memory
  type: project
  originSessionId: dd2f4ab8-0a3d-4487-9421-175480787aab
  modified: 2026-07-21T20:10:47.808Z
---

As of 2026-07-21 Albert confirmed **GCP Cloud SQL is being retired** as dflow's
database; the target is **supabase.com**. New tables / storage for dflow (e.g. the
HTS RAG ruling store `hts_rag_rulings`) should be authored for Supabase, via the
canonical [[shared-db-canonical-repo]] workflow (branch → PR → preview → main),
NOT Cloud SQL.

This updates the older standing note (dflow-session-start skill still says "dflow
uses GCP Cloud SQL today, Supabase migration is planned") — the migration is now
the active direction. App architecture stays Angular → BFF → Express → Sequelize;
only the DB backend changes. Verify live config before asserting which DB a given
environment points at during the transition.

**Update 2026-07-27 — the migration is DONE for the sandbox, not just planned.**
Verified from `popcre-albert-core-sandbox` (Cloud Run) env: `DB_PROVIDER=supabase`,
`DB_EXPECTED_PORT=6543`, `DB_NETWORK_PATH=public-pooler`, `SCHEMA=dflow`, targeting
`qsllyeztdwjgirsysgai`. Do NOT tell anyone dflow "runs on Cloud SQL today" — that claim (still
present in the `dflow-session-start` skill text) is now wrong for the sandbox and cost this
session a wrong diagnosis written into a plan doc before it was caught. Crucially, that Supabase
project is **production**: see [[dflow-sandbox-is-production-supabase]].
