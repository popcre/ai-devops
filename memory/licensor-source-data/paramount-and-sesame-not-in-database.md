---
name: paramount-and-sesame-not-in-database
description: Paramount and Sesame Workshop captures exist only as files; unlike the other licensors they have no plm.* tables in the shared database.
metadata: 
  node_type: memory
  type: project
  originSessionId: e1eb03a2-ae1a-4810-a92f-74435fd2317b
  modified: 2026-08-19T22:06:57.219Z
---

As of 2026-08-19, six licensors have `plm.*` tables in the shared Supabase database:
NBCU (`plm.nbcu_*`), Disney DCP Vault (`plm.dcp_*`), Disney OPA (`plm.opa_*`),
Warner STARLABS (`plm.wb_*`), Strawberry Shortcake / WildBrain (`plm.wildbrain_*`)
and Peanuts (`plm.peanuts_*`).

**Paramount and Sesame Workshop have no tables at all.** Their captures live only as
CSV/JSON files under `paramount/` and `sesame/` in `u2giants/licensor-source-data`.
Neither has a loader or a `load-receipts/` directory. Designing their initial schema
is unstarted work, not a retrofit.

Do not assume a licensor is queryable in the database just because its capture files
exist in the repo, and do not promise a database answer for Paramount or Sesame
without checking first. The authoritative check is a grep for `plm.<licensor>_` across
the repo excluding `node_modules`.

Related: [[nbcu-style-guide-downloads]], [[peanuts-portal-is-tenovos]]
