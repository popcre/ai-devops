---
name: shared-db-change
description: Discipline for any change to the shared supabase.com backend. Use before making db/schema/migration/RLS/API-contract changes in ANY app repo (popdam3, popcrm-web, poppim-web, monitor, dflow), or when the user says "make db changes the proper way", "mirror it to shared-db", or "re-author it properly in shared-db".
---

# shared-db-change

`u2giants/shared-db` is the canonical repo for the shared supabase.com backend
(project `qsllyeztdwjgirsysgai`) used by CRM / DAM / PM-PIM / PLM. Albert had to
say "pull the repo again and re-read the .md files to see the proper way to make
db changes" in at least three separate sessions — this skill is that protocol.

## Hard rules

1. **DDL via MCP `apply_migration` only** — never `execute_sql` for DDL.
2. After applying, run `list_migrations` and capture the recorded timestamp;
   create the local migration file with the **identical** timestamp under
   `supabase/migrations/`. Never edit a migration that may already be applied.
3. **Author the change in shared-db**, not only in the app repo. App repos get
   generated types and adapters; durable backend truth lives in shared-db.
4. **Branch policy exception:** shared-db is the ONE repo that uses branches +
   PR (all app repos are main-only). Claude merges the shared-db PR itself once
   checks pass — Albert cannot.
5. **Correct project refs** (never mix):
   - popdam prod: `ryltkzzernhwnojzouyb`
   - SynoMon: `qnjimovrsaacneqkggsn` (migrated to Virginia: `aaxtrlfpnoutziwhshlt`)
   - shared backend: `qsllyeztdwjgirsysgai`
   - oracle: `eqccjfbyrywsqkxxpjvg`
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
