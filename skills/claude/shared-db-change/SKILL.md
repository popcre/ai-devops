---
name: shared-db-change
description: Discipline for any STRUCTURAL change to the shared supabase.com backend — schema, tables, columns, views, functions/RPCs, triggers, RLS, indexes, migrations, cross-app data contracts. It does NOT gate DATA: an application session owns the rows it writes, updates, or deletes in the normal course of its work, with no issue and no dispatch (owner ruling 2026-08-13, shared-db `AGENTS.md` §0.0-B); the ONE exception is bulk/ad-hoc loading of outside-sourced content into curated Master Data (`core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory`, `*_ext`). Use before making db/schema/migration/RLS/API-contract changes in ANY app repo (popdam3, popcrm-web, poppim-web, monitor, dflow), or when the user says "make db changes the proper way", "mirror it to shared-db", or "re-author it properly in shared-db". Also states Rule 0 — read-only inspection of the shared schema (tables, columns, keys, indexes, views, functions/RPCs, triggers, RLS, migration history, generated types) is ALLOWED from every application repo with no issue and no dispatch — so load it too when the ask is "does the shared database fit our data", "compare our data shape to the schema", "review the schema", or "what columns exist".
---

# shared-db-change

`u2giants/shared-db` is the canonical repo for the shared supabase.com backend
(project `<removed-protected-project-ref>`) used by CRM / DAM / PM-PIM / PLM. Albert had to
say "pull the repo again and re-read the .md files to see the proper way to make
db changes" in at least three separate sessions — this skill is that protocol.

> **Working IN the shared-db repo and you were not started as the orchestrator?
> STOP.** `AGENTS.md` runs one orchestrator session; every other session opens a
> GitHub issue and stops —
> `gh issue create --repo u2giants/shared-db --label db-work --title "HANDOVER: …" --body-file <file>`.
> This skill tells you how to author a correct change once you have been
> dispatched; it is not permission to start one. **This STOP is about changing
> STRUCTURE.** It is not about looking — read-only inspection of the schema is
> always allowed from anywhere (Rule 0 below). And it is not about your own
> application's data — see Rule 0.5.
>
> **Working IN the shared-db repo, or running more than one workstream?** Load the
> **`shared-db-orchestrator`** skill as well. This skill covers how to author a
> correct change; that one covers how a session is run — one orchestrator, all work
> in isolated sub-agent worktrees, never background task chips (four of them once
> wrote competing `CREATE OR REPLACE` migrations on the same function),
> single-writer ownership of `supabase/migrations/`, and the two-part orchestrator
> handoff. To end or hand over that session, use **`shared-db-handover`**.

> ## ⚠️ Two corrections, 2026-08-07. Read before rule 1.
>
> **`AGENTS.md` in `u2giants/shared-db` WINS over this file wherever they disagree.** It is
> the live rulebook; this skill is a portable summary and it has already drifted once.
>
> **1. Rule 1 below is STALE and following it literally is dangerous.** It says to apply
> DDL through the Supabase MCP. `AGENTS.md` standing fact 6 says the MCP **may be bound to
> PRODUCTION and takes no project parameter — there is no way to aim it at preview.**
> Following rule 1 can therefore apply DDL straight to production. **Preview work goes
> through the Supabase CLI or psql**, and you must check `cat supabase/.temp/project-ref`
> immediately before every push. Call `get_project_url` FIRST and confirm what you are
> pointed at before any MCP call at all.
>
> **2. Requesting the work has changed.** `COORDINATOR_INTAKE.md` was retired on
> 2026-08-07 and is now a 37-line pointer. If you need database work done and have not
> started it, **open a GitHub issue**:
> `gh issue create --repo u2giants/shared-db --label db-work --title "…" --body-file <file>`.
> A required check fails any PR that writes work back into the old file.

## Rule 0 — read-only inspection is ALLOWED, from every repo, always

**None of the gates below apply to reading.** This skill governs *changes*. Any AI
session, in any application repository, may inspect the shared database in full
without a GitHub issue, an orchestrator dispatch, or a handoff:

- schemas; tables and columns; keys and relationships; indexes and constraints
- views; functions and RPCs; triggers; row-security (RLS) policies
- migration history; generated types; metadata; safe sample data when a review
  genuinely needs it

It may compare all of that against application code, scraper output, source-data
shapes, expected business rules and proposed features, and report the gaps. That
is normal engineering work. Deciding whether the shared database fits an app's
data **requires** seeing the whole schema, so refusing to look is a failure, not
caution.

Three conditions on a read-only review:

1. **Read only.** No `ALTER`/`CREATE`/`DROP`, no `apply_migration`, no migration
   file, no branch — in preview or production. The moment you mutate the schema,
   it stops being a review and the rules below apply. (Writing your own app's rows
   is not gated at all, but it is also not a "review" — see Rule 0.5.)
2. **Know what you are pointed at** before every call — `get_project_url` for the
   MCP, `cat supabase/.temp/project-ref` for the CLI — and quote it in your report.
   Use the approved read-only AI identity wherever one is required.
3. **Licensed data stays put.** A review may read private licensor source data
   inside its approved private repository; licensed rows never go into a public
   repo, a GitHub issue, logs, prompts sent to outside services, commit messages
   or pull requests.

Everything below — the issue, the orchestrator, the branch/PR/preview process —
starts the moment the answer is "and now change the SHAPE of it".

## Rule 0.5 — DATA is not gated. Rows belong to the application session.

> **Owner ruling, Albert Hazan, 2026-08-13** — "shared-db orchestrator is for creating,
> changing, or deleting the STRUCTURE or schema or design of the database, not for
> creating, changing, or deleting the data inside the database. That should be done by
> the sessions working on the actual application."

Recorded as `AGENTS.md` §0.0-B in `u2giants/shared-db`, which is the controlling text.
This skill governs the **shape** of the shared database, not its **contents**.

**No issue, no dispatch, no handover, no branch, no migration** for:

- a feature or bug fix writing, updating, or deleting its own application rows
- a scraper, importer, or sync job writing into the ingest/staging tables it owns
- backfilling, correcting, or cleaning up application data the app itself produced
- test, demo, or fixture data in preview
- operational data: job runs, queue rows, cache entries, audit and log rows

Older wording here listed "a seed or data fix" next to tables and columns, so sessions
reasonably read any `INSERT` as orchestrator work. It never was.

**The one carve-out — curated Master Data.** Bulk or ad-hoc loading of **outside-sourced**
content (spreadsheet, CSV, export, pasted rows, screenshot, chat message, API pull) into
`core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory` or
their `*_ext` tables is still orchestrator work under `AGENTS.md` §6.4 and its 2026-08-03
correction, matched-row abstention included. That gate was bought with an incident. The
trigger is **provenance and target**, not volume or verb.

**Still binding on every data write you do own:** `AGENTS.md` §4.2 — prove which database
you are pointed at immediately before every `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE`, preview
and production alike, and quote the proof in your report.

**The test:** *shape or contents?* Shape → everything below. Contents → your own session,
unless the target is curated Master Data.

## Hard rules (these govern STRUCTURAL CHANGES)

1. ~~**DDL via MCP `apply_migration` only** — never `execute_sql` for DDL.~~
   **SUPERSEDED — see the box above.** Never `execute_sql` for DDL still holds; "via MCP
   only" does not. Prove which project you are pointed at before any MCP call.
2. ~~After applying, run `list_migrations` and capture the recorded timestamp;
   create the local migration file with the **identical** timestamp.~~
   **SUPERSEDED 2026-08-09 — it is the same apply-through-MCP-first drift as rule 1.**
   The file comes FIRST: write a new `YYYYMMDDHHMMSS_*.sql` under
   `supabase/migrations/`, choosing a version **above the current maximum**
   (`ls supabase/migrations | cut -c1-14 | sort | tail -1`), then apply it to
   **preview** with the CLI. Pick the version by hand —
   `check-dispatch-collision.mjs --allocate-version` was withdrawn on 2026-08-07
   and now exits `2`. **Never reuse a timestamp:** Supabase's ledger keys on the
   version alone, so a duplicate makes one migration **silently skip** with no
   error (`AGENTS.md` §4 rule 5; this has happened twice). Never edit a migration
   that may already be applied — fix forward.
3. **Author the change in shared-db**, not only in the app repo. App repos get
   generated types and adapters; durable backend truth lives in shared-db.
4. **Branch policy exception:** shared-db is the ONE repo that uses branches +
   PR (all app repos are main-only). Claude merges the shared-db PR itself once
   checks pass — Albert cannot.
5. **Correct project refs** (never mix):
   - shared backend **PRODUCTION**: `<removed-protected-project-ref>`
   - shared backend **PREVIEW**: `<removed-protected-project-ref>` (Supabase branch
     `shared-db-schema-rehearsal` — it is a *branch*, so it does **not** appear in
     `supabase projects list`; that absence proves nothing). *(Added 2026-08-09:
     this list previously omitted preview entirely.)*
   - popdam prod: `<removed-protected-project-ref>`
   - SynoMon: `<removed-protected-project-ref>` (migrated to Virginia: `<removed-protected-project-ref>`)
   - oracle: `<removed-protected-project-ref>`

   **Prove the target before every write** (`AGENTS.md` §4.2, an owner ruling):
   immediately before any statement that writes, changes or removes data, schema
   or privileges — in preview as well as production — check the live connection
   target (`get_project_url` for MCP, `cat supabase/.temp/project-ref` for the
   CLI) and quote what you saw in your report.
6. Data-model semantics that keep getting violated:
   - The only companies in these apps are **customers** (active or potential).
     `core.customer`, not `core.company`. "Factory" is renamed **Vendor**.
   - Departments exist only as part of a company, never standalone.
7. Regenerate database types in affected app repos after schema changes.
8. Verify: check CI `supabase db push`, run app builds, note RLS/role checks.
9. Document per the shared-db section of the `session-docs-update` skill
   (what/why/apps affected/where implemented/verified/risks; app migration
   handoffs under `docs/app-migration-notes/<app>-YYYYMMDD.md`).
10. Never leave shared-db with untracked migrations or docs — finish the
    branch/PR/merge or write your own `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`
    file saying exactly what remains (never rewrite the shared root `HANDOFF.md`).
