---
name: shared-db-change
description: >-
  Discipline for structural changes to the shared database, including schema,
  migrations, security rules, and cross-app contracts. It also explains that
  ordinary application data belongs to the application session and that
  read-only inspection is allowed from every application repository.
---

# shared-db-change

Concrete project identifiers are protected configuration. Resolve them with
`ai-private-config value supabase_shared_prod_ref` and
`ai-private-config value supabase_shared_preview_ref`; never copy a value into
this public skill. Prove the live link immediately before every write.

`u2giants/shared-db` is the canonical repo for the shared supabase.com backend
(project `<protected-shared-prod-ref>`) used by CRM / DAM / PM-PIM / PLM. Albert had to
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
> **Need to reach the orchestrator? Resolve it, never remember it** (shared-db
> `AGENTS.md` §11c, issue #1605):
>
> ```bash
> node scripts/check-orchestrator-marker.mjs --resolve
> ```
>
> It answers from the **current open marker only** and prints the address that
> marker DECLARES. Exit 0 = one valid marker, and the printed `route_id` is where
> to try. Exit 3 = **no active orchestrator** — open your issue and let it queue;
> do not dispatch and do not appoint yourself. Exit 1 = unsafe, ambiguous or
> unroutable — an orchestrator may be live and unreachable, so stop. Exit 2 =
> GitHub unreadable — assume one exists.
>
> ⚠️ **Exit 0 does not prove anyone is there.** Nothing checks that the session
> exists, is running, or can receive a message — only that a marker declares that
> address. **Confirm you got a reply.** Silence is not delivery, and if nobody
> answers, re-resolve rather than assuming it landed.
>
> ⚠️ **Never take a routing target from conversation history, a `HANDOFF.d/` file,
> a closed marker, or a remembered id.** That is exactly how an authorized
> structural request was once delegated to an orchestrator that had already
> closed, and nothing reported it. Re-resolve before every delegation; a handover
> changes the target.
>
> **Working IN the shared-db repo, or running more than one workstream?** Load the
> **`shared-db-orchestrator`** skill as well. This skill covers how to author a
> correct change; that one covers how a session is run — one orchestrator, all work
> in isolated sub-agent worktrees, never background task chips (four of them once
> wrote competing `CREATE OR REPLACE` migrations on the same function),
> up to five isolated authors with atomic GitHub-backed reservations, and the two-part orchestrator
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

## Successor issues must be routed from scratch

Never inherit the route of a predecessor issue. Classify the successor's own
requested work: structural work routes to `shared-db-orchestrator` and names
exact database objects; ordinary application data or offline analysis routes to
the owning application session; outside-sourced curated Master Data uses its
existing governed exception; planning and repository maintenance do not consume
a migration-author lane. If the issue is misrouted, stop before implementation,
preserve private artifacts in their approved private repository, and hand off to
the correct route. A predecessor's repository is context, not routing proof.

## Hard rules (these govern STRUCTURAL CHANGES)

1. ~~**DDL via MCP `apply_migration` only** — never `execute_sql` for DDL.~~
   **SUPERSEDED — see the box above.** Never `execute_sql` for DDL still holds; "via MCP
   only" does not. Prove which project you are pointed at before any MCP call.
2. ~~After applying, run `list_migrations` and capture the recorded timestamp;
   create the local migration file with the **identical** timestamp.~~
   **SUPERSEDED 2026-08-09 — it is the same apply-through-MCP-first drift as rule 1.**
   The file comes FIRST: write a new `YYYYMMDDHHMMSS_*.sql` under
   `supabase/migrations/`, using the version assigned by
   `manage-migration-author-lanes.mjs --claim` before the file exists, then apply it to
   **preview** only through the exclusive preview lane. Never pick a version from a
   local directory listing. **Never reuse a timestamp:** Supabase's ledger keys on the
   version alone, so a duplicate makes one migration **silently skip** with no
   error (`AGENTS.md` §4 rule 5; this has happened twice). Never edit a migration
   that may already be applied — fix forward.
3. **Author the change in shared-db**, not only in the app repo. App repos get
   generated types and adapters; durable backend truth lives in shared-db.
4. **Branch policy exception:** shared-db is the ONE repo that uses branches +
   PR (all app repos are main-only). Claude merges the shared-db PR itself once
   checks pass — Albert cannot.
5. **Correct project refs** (never mix):
   - shared backend **PRODUCTION**: `<protected-shared-prod-ref>`
   - shared backend **PREVIEW**: `<protected-shared-preview-ref>` (Supabase branch
     `shared-db-schema-rehearsal` — it is a *branch*, so it does **not** appear in
     `supabase projects list`; that absence proves nothing). *(Added 2026-08-09:
     this list previously omitted preview entirely.)*
   - popdam prod: `<protected-popdam-ref>`
   - SynoMon: `<protected-retired-synomon-ref>` (migrated to Virginia: `<protected-synomon-ref>`)
   - oracle: `<protected-oracle-ref>`

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
