---
name: paramount-and-sesame-not-in-database
description: CORRECTED 2026-08-19 - Paramount IS in the database (plm.pmt_*, loaded). Sesame has a landing migration but no rows.
metadata:
  type: project
---

**Correction (verified by live query 2026-08-19):** an earlier version of this note
said Paramount had no tables. That was WRONG.

- **Paramount IS in the shared Supabase database**: `plm.pmt_*` (24 tables:
  property, franchise, character, collection/style guide, brand, asset,
  authorized title, the link tables, capture bookkeeping, and the lossless
  `pmt_asset_metadata_value`). Loaded 2026-08-13; the complete capture's counts
  match the repo CSVs exactly (67 properties, 62 characters, 538 collections,
  22 franchises, 33,862 assets).
- **Sesame** has a landing migration (`20260819212002_sesame_workshop_netx_source_landing.sql`)
  but no data loaded as of 2026-08-19.
- Also present: NBCU (`plm.nbcu_*`), Disney DCP Vault (`plm.dcp_*`), Disney OPA
  (`plm.opa_*`), Warner STARLABS (`plm.wb_*`), WildBrain (`plm.wildbrain_*`),
  Peanuts (`plm.peanuts_*`), Sega.

**How to check for real, instead of guessing:** psql against the pooler with the
password from `op read 'op://vibe_coding/Supabase DB Password - shared POP database/password'`,
host `aws-1-us-east-1.pooler.supabase.com:6543`, user `postgres.qsllyeztdwjgirsysgai`.
psql IS installed on this Windows machine (18.6) despite older shared-db docs
saying it is not. A grep of the repo proves a table exists; only a query proves
it has rows.

Related: [[peanuts-portal-is-tenovos]], [[orchestrator-is-structure-only]]
