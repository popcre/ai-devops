---
name: codex-shared-db-change
description: Read before any shared Supabase schema question or structural change. Use for tables, columns, views, RPCs, triggers, RLS, indexes, migrations, cross-app contracts, "make db changes properly", "mirror to shared-db", schema review, or data-shape comparison. Structural work routes through u2giants/shared-db; ordinary application row data does not.
---

# codex-shared-db-change

Resolve environment identifiers from the protected configuration before use:

```bash
SHARED_PROD_REF="$(ai-private-config value supabase_shared_prod_ref)"
SHARED_PREVIEW_REF="$(ai-private-config value supabase_shared_preview_ref)"
```

The angle-bracketed names below are explanatory labels, never literal command
arguments. Prove the live link again immediately before every write.

`u2giants/shared-db` is the **canonical** repo for the shared supabase.com backend
(production project `<protected-shared-prod-ref>`) used by CRM, DAM, PM/PIM, and PLM
(designflow). Every app reads/writes the same tables, so a schema change made in
one app repo can silently break another. All durable DB **structure** lives in shared-db.

> **Structure, not data (owner ruling, Albert Hazan, 2026-08-13; `AGENTS.md` §0.0-B).**
> This skill and the shared-db orchestrator govern the *shape* of the database — schema,
> tables, columns, views, functions/RPCs, triggers, RLS, indexes, migrations, cross-app
> contracts. The rows an application creates, edits, or deletes in the normal course of its
> work belong to the session working on that application: **no issue, no dispatch, no
> migration.** That includes its own ingest/staging tables, backfills and cleanups of data
> the app produced, preview fixtures, and job/queue/audit rows.
>
> **One carve-out:** bulk or ad-hoc loading of outside-sourced content (spreadsheet, CSV,
> export, pasted rows, API pull) into curated Master Data — `core.licensor`,
> `core.property`, `core.character`, `core.customer`, `core.factory` and their `*_ext`
> tables — is still orchestrator work under `AGENTS.md` §6.4, matched-row abstention
> included. The trigger is provenance and target, not volume or verb.
>
> **Unchanged:** §4.2 still requires proving the connection target immediately before every
> data write, preview and production alike.

> ## ⚠️ Read this before anything below. Corrected 2026-08-09 (issue #574).
>
> **`AGENTS.md` in `u2giants/shared-db` is the live rulebook and WINS over this file
> wherever they disagree.** This skill is a portable summary and it had drifted badly.
>
> 1. **The preview project ref in this file was WRONG.** It said
>    `<protected-retired-preview-ref>`, which is not a project in this account. Preview is
>    **`<protected-shared-preview-ref>`** (Supabase branch `shared-db-schema-rehearsal`);
>    production is `<protected-shared-prod-ref>`. Fixed throughout.
> 2. **You almost certainly may not do this work yourself.** `shared-db` runs **one
>    orchestrator session** and every other session **stops and opens a GitHub issue**:
>    `gh issue create --repo u2giants/shared-db --label db-work --title "…" --body-file <file>`.
>    Read the procedure below as *how a dispatched agent authors the change*, never as
>    permission to start one.
> 3. **Prove which database you are on before every write** — `AGENTS.md` §4.2, an owner
>    ruling. Immediately before any statement that writes, changes or removes data,
>    schema or privileges (preview included), read `cat supabase/.temp/project-ref`, and
>    quote the value in your report. A ref read ten minutes ago proves nothing.
> 4. **Never reuse a migration timestamp.** The ledger keys on the version alone, so a
>    duplicate makes one migration **silently skip**. Pick a version above the current
>    maximum, by hand.
> 5. **Never create background task chips for this repo.** Four of them once wrote
>    competing `CREATE OR REPLACE` migrations against the same function.

## Rule 0 — read-only inspection is ALLOWED, from every repo, always

**Everything in this skill governs CHANGES. None of it applies to reading.** Any
session, in any application repository, may inspect the shared database in full
with no GitHub issue, no orchestrator dispatch and no handoff: schemas; tables and
columns; keys and relationships; indexes and constraints; views; functions and
RPCs; triggers; row-security policies; migration history; generated types;
metadata; and safe sample data when a review needs it. It may compare all of that
against app code, scraper output, source-data shapes, expected business rules and
proposed features, and report the gaps.

Judging whether the shared database fits an application's data **requires** seeing
the whole schema. Refusing to look is a failure, not caution. Do not treat
"database work" as a blanket that also blocks reading.

Three conditions:

1. **Read only** — no DDL, no DML, no `apply_migration`, no migration file, no
   branch, in preview or production. Mutate anything and it is no longer a review.
2. **Know the target** before every call (`get_project_url` for MCP,
   `cat supabase/.temp/project-ref` for the CLI) and quote it in your report; use
   the approved read-only AI identity wherever one is required.
3. **Licensed rows stay in their approved private repo** — never into a public
   repo, issue, log, outside-service prompt, commit message or PR.

## The one rule (for changes)

**Never make a schema/DDL change from an app repo, and never run direct DDL
against the shared database.** That means: do NOT add `ALTER TABLE`/`CREATE
TABLE`/`CREATE INDEX`/`CREATE POLICY`/seed/backfill SQL to app code (e.g. a
Sequelize `models/db.js` startup migration), do NOT `execute_sql`/`psql` a
`ALTER`/`CREATE`/`DROP` against `<protected-shared-prod-ref>`, and do NOT rely on an
app-repo-only migration. **Author it in `u2giants/shared-db` first.** App repos
only get updated (models, generated types, adapters, API code) AFTER the shared-db
change is applied.

## Successor issues must be routed from scratch

Never inherit the route of a predecessor issue. Classify the successor's own
requested work: structural work routes to `shared-db-orchestrator` and names
exact database objects; ordinary application data or offline analysis routes to
the owning application session; outside-sourced curated Master Data uses its
existing governed exception; planning and repository maintenance do not consume
a migration-author lane. If the issue is misrouted, stop before implementation,
preserve private artifacts in their approved private repository, and hand off to
the correct route. A predecessor's repository is context, not routing proof.

## Procedure (local Supabase CLI — the working path)

1. **Stop and switch to `u2giants/shared-db`** (local clone, e.g. `C:\repos\shared-db`
   or `/worksp/shared-db`). Read its `AGENTS.md`. Check for in-flight work first:
   `gh pr list`, `git branch -a`, `ls supabase/migrations`, `git status` — if
   another DB change is in flight, serialize (finish/land it or coordinate) before
   starting yours. Two simultaneous schema edits are the #1 cause of breakage.
2. **Branch + PR** (shared-db is the ONE repo that uses branches; app repos are
   main-only). New timestamped file `supabase/migrations/YYYYMMDDHHMMSS_*.sql`.
   Additive/idempotent by default (`IF EXISTS`/`IF NOT EXISTS`); never edit a
   migration already applied anywhere.
3. **Authenticate the CLI** — env-only token is NOT enough, you must `login`:
   ```bash
   supabase login --token "$(op read 'op://vibe_coding/Supabase CLI Personal Access Token/SUPABASE_ACCESS_TOKEN')"
   supabase projects list   # verify
   ```
4. **Preview first**, then production. Link with the matching DB password
   (1Password `Supabase DB Password - shared POP database` for prod; the preview
   item for `<protected-shared-preview-ref>`):
   ```bash
   cat supabase/.temp/project-ref            # PROVE the target (AGENTS.md §4.2)
   supabase link --project-ref "$SHARED_PREVIEW_REF"   # preview ONLY
   supabase db push --dry-run   # must be clean: only your change
   cat supabase/.temp/project-ref            # prove again, immediately before the push
   supabase db push
   ```

   ⚠️ **Corrected 2026-08-09: this block used to continue straight into
   `supabase link --project-ref "$SHARED_PROD_REF" && supabase db push`. Do NOT
   promote to production that way.** Production almost always carries pending
   migrations from other workstreams that other teams have deliberately kept off it,
   so a plain `db push` either refuses or sweeps up work that was never approved.
   Production promotion requires **Albert's explicit approval for that exact change**,
   the `AGENTS.md` §5 merge checklist, and the §5.1 bounded temp-checkout recipe. It is
   the orchestrator's call, not this skill's. Stop and ask.
   If a change was already applied out-of-band, use `supabase migration repair
   --status applied <version>` to record it (metadata only, no SQL re-run). If the
   dry-run reports "Remote migration versions not found in local migrations
   directory", that is DRIFT from other in-flight work — do NOT blindly
   `repair`/`db pull`; verify what it is and serialize.
5. **Merge the shared-db PR yourself** once `scripts/check-sql.sh` passes and the
   preview dry-run/apply is clean (Albert cannot merge). Merging syncs the
   `shared-db/` folder into consumer repos; it does NOT apply to the DB (apply is
   the CLI / `workflow_dispatch` step above).
6. **Then** update the app repo: Sequelize model / generated types / mapping / API
   / tests to match the canonical schema. Commit to the app repo per its own rules.

## Correct project refs (never mix)

- shared backend (prod): `<protected-shared-prod-ref>`  ·  preview branch: `<protected-shared-preview-ref>`
- popdam prod: `<protected-popdam-ref>`  ·  oracle: `<protected-oracle-ref>`

## Data-model semantics that keep getting violated

- The only companies are **customers** (active or potential): `core.customer`,
  not `core.company`. "Factory" is renamed **Vendor**. Departments exist only as
  part of a company, never standalone.

## Don't leave a mess

Never leave shared-db with untracked migrations or an open PR: finish
branch → PR → merge, or write your own
`HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` file stating the exact next action
(never rewrite the shared root `HANDOFF.md`).
Full reference: `u2giants/shared-db/AGENTS.md`.
