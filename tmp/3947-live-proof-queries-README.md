# 3947 live proof queries — how to run

Ready-to-run READ-ONLY proof SQL for shared-db issue #3947 (Scraped Properties
display dedupe, migration `20261007190954` — forward replacement for
HARD_BLOCKED `20261007020907`).

File: `3947-live-proof-queries.sql`

## What it proves

| Pattern | Pass means |
|---|---|
| Warner | Zero displayed `natural_key_fallback` rows whose label has a `source_id` twin in the same namespace. Landing fallback rows still exist. |
| Sesame | Exactly one display row per `value_key` on the latest complete capture; when both generations exist the survivor is `field_generation = 'current'`. Landing keeps both generations. |
| Lucasfilm / Disney | Zero displayed Lucasfilm rows whose exact `source_id` has a Disney `dcp_property` twin. Every Lucasfilm identity with no twin is still displayed. Every shared id keeps its Disney survivor, resolution history, and member associations. Landing tables and the decision ledger are non-empty. |

Function-body checks also assert the three hide predicates are present in
`api.db_data_admin_scraped_source_inventory` and that security posture is
unchanged (security definer, stable, `search_path=app, public`, execute for
`authenticated` only).

## How to run (psql pooler, READ-ONLY)

1. Get the database password from 1Password vault `vibe_coding`, item
   `246sf23gymd64yudpmhswcnyle`, **only** through `1password_op_run` (never
   paste it into a command line or chat).
2. Connect. Pooler hosts DIFFER between production and preview — using the
   wrong one fails like a bad password:

   - **Production** `qsllyeztdwjgirsysgai` → `aws-1-us-east-1.pooler.supabase.com:6543`,
     user `postgres.qsllyeztdwjgirsysgai`
   - **Preview** `mvpkijzfmfcxhnzqogzs` → `aws-0-us-east-1.pooler.supabase.com:6543`,
     user `postgres.mvpkijzfmfcxhnzqogzs`. Password is field `DB_PASSWORD` on
     1Password item `qbvfk7umc3n75ejekd65zwd4ty` (title has parentheses — read
     by item id, not title).

3. In psql, run `set role postgres;` then:

   ```
   \i C:/repos/ai-devops/tmp/3947-live-proof-queries.sql
   ```

4. Gate: **zero rows with `result = FAIL`**. `INFO` and `SKIP` are allowed.
   Do not start until check `01_migration_applied` is PASS.

Everything in the file is SELECT, session-local SET, or TEMP tables. It writes
nothing to any permanent table.

## Expected baseline (production evidence 2026-10-06)

Informational only — live counts may drift with new captures:

- Warner landing: 227 `source_id` + 133 `natural_key_fallback`, 132 dual-form labels.
- Sesame latest capture: 28 `value_key`s, 21 dual-generation.
- Lucasfilm: 70 landing rows, 30 shared with Disney, 40 unique.
- Shared ids: all 30 with resolution history, 24 with approved members.

## Optional gold-standard section

Checks `41`–`44` page the live inventory function as an authenticated
licensing-manager (JWT claims impersonation) and assert the three patterns on
the actual returned JSON. Prints `SKIP` if no qualifying profile exists. The
static checks `10`–`40` are sufficient on their own.

## Preview dry-run (2026-10-07)

Ran read-only against preview `mvpkijzfmfcxhnzqogzs` (migration already
applied). **Zero FAIL rows.** Actual counts:

- Warner: displayed=393, landing 392 `source_id` + 133 `natural_key_fallback`,
  132 dual-form labels. Pattern PASS (0 fallback twins displayed).
- Sesame: 0 keys on preview's latest complete capture — pattern checks pass
  vacuously there. Production has the 28/21 baseline.
- Lucasfilm: 70 landing, 30 shared, 40 unique displayed — matches the
  production baseline exactly. Disney dcpvault total 237.
- Decision ledger is **empty on preview**, so checks `34`/`36`/`40` correctly
  return `SKIP`. Production has the populated ledger (30 shared ids with
  resolution, 24 with members) and must show PASS there.
- Gold-standard inventory call: 2458 property rows paged; all three patterns
  PASS (`bad=0` each).

Note: the script is pooler-safe — fixture TEMP tables run inside one
transaction with `ON COMMIT DROP`, and leftover names from a leaked pooled
session are dropped first.

## Application-owned live artifact (not built yet)

Obligation: `u2giants/popdam3` workflow artifact
`shared-db-live-proof-3947-<application_sha>`. The existing app workflow
allow-list and service-role producer **cannot** run this proof, because the
inventory function is `authenticated`-only and behind
`app.require_licensing_manager_access()`. A least-privileged read-only
producer would need:

- A dedicated Postgres role (or JWT-authenticated identity) with **no write
  grants** — SELECT on `plm.wb_property`, `plm.sesame_brand`,
  `plm.lucasfilm_dcp_property`, `plm.dcp_property`,
  `plm.dcp_opa_property_resolution(_member)`, `plm.sesame_capture`, and
  EXECUTE on `api.db_data_admin_scraped_source_inventory` only.
- A provisioned `app.profile` holding exactly the `licensing` role plus
  `plm` (or `admin`) app access, so the existing gate passes without widening
  it.
- Network reach to the pooler and a secret delivered through 1Password
  `op://` references in the workflow environment — never inline.
- Output: the check rows above, committed as the named artifact bound to the
  application SHA that consumed the proof.

Do not weaken the licensing gate or grant `service_role` execute to make the
artifact easier to produce.
