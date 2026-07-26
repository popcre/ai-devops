---
name: dbda-read-set-live-on-prod
description: DB Data Admin Step 4-6 read migrations are LIVE on production despite HANDOFF saying preview-only; write gates correctly absent.
metadata: 
  node_type: memory
  type: project
  originSessionId: d822d3d2-a17e-4f3e-99dd-e36a260bcd7d
  modified: 2026-07-23T14:33:37.048Z
---

Live read-only verification 2026-07-23 (prod `qsllyeztdwjgirsysgai`, pooler): the DB Data Admin
read set — `20260722002500` (foundation), `003000`–`003500` (ext tables + channels), `004500`
(merge FK coverage), `005000`/`005100`/`005200` (admin read RPCs + 5 serving views + uuid fix),
`163000` (errata) — is ALL PRESENT in `supabase_migrations.schema_migrations` on production.
Prod head = `20260722221700`. The five serving views + `api.dam_customer_list` exist on prod.

This CONTRADICTS `HANDOFF.md` and `DB_Data_Admin.md` §6/§10, which repeatedly say Steps 4–6 are
"preview-only / production unchanged." They are not — they're live. Likely applied via a bounded
checkout during a later promotion; never documented.

**Correctly absent on prod (must stay off until Step 13):** `170000` (single_record_write gate),
`194000`/`194100` (merge execution), `203000`/`203100` (licensor tree), `210000` (merge-preview
detail). `app.db_data_admin_feature_gate` is ABSENT on prod (present on preview with both
`single_record_write` and `merge_execute` = true). Non-revoked `admin` app_access grants on prod = 0.

**Why:** Prod head is 221700, so these six write-gate migrations are OLDER-than-head PENDING.
A plain `supabase db push` skips them (version ≤ head); **`supabase db push --include-all` WOULD
apply them** — enabling production write/merge. Never run --include-all against prod while these
sit pending. See [[shared-db-apply-mechanics]] and [[merge-fn-loser-first]].

**Live counts (prod, 2026-07-23):** customers 859 (140/12/707); factories 93 (91/2, reconciled by
`20260722140000`, NOT the stale 510); licensors 20; properties 256; orphans 0; `core.factory_source_ref`
= 104 rows all coldlion (NOT the stale 523); designflow_plm customer refs 54 / 50 companies; designflow
factory refs 0.
