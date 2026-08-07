---
name: shared-db-change
description: Discipline for any change to the shared supabase.com backend. Use before making db/schema/migration/RLS/API-contract changes in ANY app repo (popdam3, popcrm-web, poppim-web, monitor, dflow), or when the user says "make db changes the proper way", "mirror it to shared-db", or "re-author it properly in shared-db".
---

# shared-db-change

`u2giants/shared-db` is the canonical repo for the shared supabase.com backend
(project `<removed-protected-project-ref>`) used by CRM / DAM / PM-PIM / PLM. Albert had to
say "pull the repo again and re-read the .md files to see the proper way to make
db changes" in at least three separate sessions — this skill is that protocol.

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

## Hard rules

1. ~~**DDL via MCP `apply_migration` only** — never `execute_sql` for DDL.~~
   **SUPERSEDED — see the box above.** Never `execute_sql` for DDL still holds; "via MCP
   only" does not. Prove which project you are pointed at before any MCP call.
2. After applying, run `list_migrations` and capture the recorded timestamp;
   create the local migration file with the **identical** timestamp under
   `supabase/migrations/`. Never edit a migration that may already be applied.
3. **Author the change in shared-db**, not only in the app repo. App repos get
   generated types and adapters; durable backend truth lives in shared-db.
4. **Branch policy exception:** shared-db is the ONE repo that uses branches +
   PR (all app repos are main-only). Claude merges the shared-db PR itself once
   checks pass — Albert cannot.
5. **Correct project refs** (never mix):
   - popdam prod: `<removed-protected-project-ref>`
   - SynoMon: `<removed-protected-project-ref>` (migrated to Virginia: `<removed-protected-project-ref>`)
   - shared backend: `<removed-protected-project-ref>`
   - oracle: `<removed-protected-project-ref>`
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
