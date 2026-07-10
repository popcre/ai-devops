---
name: codex-shared-db-change
description: Discipline for ANY change to the shared supabase.com backend from an app repo. Use before making db/schema/column/table/view/RPC/trigger/RLS/seed/migration or cross-app data-contract changes in ANY app repo (designflow/dflow, popcrm-web, poppim-web, popdam, directus, monitor), or when the user says "make db changes the proper way", "mirror it to shared-db", "re-author it properly in shared-db", or "all db work goes through shared-db". Codex has no auto-loaded skills, so read this whenever a task touches the database.
---

# codex-shared-db-change

`u2giants/shared-db` is the **canonical** repo for the shared supabase.com backend
(production project `<removed-protected-project-ref>`) used by CRM, DAM, PM/PIM, and PLM
(designflow). Every app reads/writes the same tables, so a schema change made in
one app repo can silently break another. All durable DB truth lives in shared-db.

## The one rule

**Never make a schema/DDL change from an app repo, and never run direct DDL
against the shared database.** That means: do NOT add `ALTER TABLE`/`CREATE
TABLE`/`CREATE INDEX`/`CREATE POLICY`/seed/backfill SQL to app code (e.g. a
Sequelize `models/db.js` startup migration), do NOT `execute_sql`/`psql` a
`ALTER`/`CREATE`/`DROP` against `<removed-protected-project-ref>`, and do NOT rely on an
app-repo-only migration. **Author it in `u2giants/shared-db` first.** App repos
only get updated (models, generated types, adapters, API code) AFTER the shared-db
change is applied.

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
   item for `<removed-protected-project-ref>`):
   ```bash
   supabase link --project-ref <removed-protected-project-ref>   # preview first
   supabase db push --dry-run   # must be clean: only your change
   supabase db push
   # then production:
   supabase link --project-ref <removed-protected-project-ref>
   supabase db push --dry-run && supabase db push
   ```
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

- shared backend (prod): `<removed-protected-project-ref>`  ·  preview branch: `<removed-protected-project-ref>`
- popdam prod: `<removed-protected-project-ref>`  ·  oracle: `<removed-protected-project-ref>`

## Data-model semantics that keep getting violated

- The only companies are **customers** (active or potential): `core.customer`,
  not `core.company`. "Factory" is renamed **Vendor**. Departments exist only as
  part of a company, never standalone.

## Don't leave a mess

Never leave shared-db with untracked migrations or an open PR: finish
branch → PR → merge, or write `HANDOFF.md` stating the exact next action.
Full reference: `u2giants/shared-db/AGENTS.md`.
