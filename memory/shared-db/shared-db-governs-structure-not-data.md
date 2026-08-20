---
name: shared-db-governs-structure-not-data
description: Owner ruling 2026-08-13 — the shared-db repo and its orchestrator govern STRUCTURE only; an app session owns its own row writes, except bulk loads into curated Master Data
metadata:
  node_type: memory
  type: feedback
---

**The `u2giants/shared-db` repo and its orchestrator govern the STRUCTURE of the shared Supabase database, not the DATA inside it.**

> "shared-db orchestrator is for creating, changing, or deleting the STRUCTURE or schema or design of the database, not for creating, changing, or deleting the data inside the database. That should be done by the sessions working on the actual application." — Albert Hazan, 2026-08-13

**Structure (gated — issue, orchestrator, branch, preview, PR):** schemas, tables, columns, types/enums, views, materialised views, functions/RPCs, triggers, RLS policies, grants, indexes, constraints, extensions, realtime publications, storage policies, migrations, structural seed rows that ship as a migration, cross-app data contracts.

**Data (NOT gated — the application session owns it outright, no issue, no dispatch, no migration):** feature and bug-fix row writes, a scraper/importer/sync job writing its own ingest or staging tables, backfilling or cleaning up data the app itself produced, preview test/demo/fixture data, and operational rows (job runs, queues, cache, audit, logs).

**The one carve-out:** bulk or ad-hoc loading of OUTSIDE-SOURCED content (spreadsheet, CSV, export, pasted rows, screenshot, chat message, API pull) into curated Master Data — `core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory` and their `*_ext` tables — stays orchestrator work under `AGENTS.md` §6.4 and its 2026-08-03 correction, matched-row abstention included. The trigger is **provenance and target**, never volume or verb.

**Why:** the earlier wording listed "seeds" and "data fixes" beside tables and columns, and said any `INSERT`/`UPDATE`/`DELETE` left read-only territory. Sessions correctly read that as "every row write is orchestrator work", which was never the intent and clogged the queue while blocking app work. The §6.4 carve-out survives because it was bought with an incident: this database records no per-field curation, so an ad-hoc dump can silently supersede hand-curated rulings with no way to tell curated from untouched.

**Unchanged:** §4.2 still binds every data write — prove which database you are pointed at immediately before every `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE`, preview and production alike, and quote the proof in your report. Owning your rows is not permission to be unsure where they land. Read-only inspection stays wide open (§0.0-A). The single-orchestrator rule still governs structure work.

**How to apply:** the controlling text is `shared-db` `AGENTS.md` §0.0-B (the live rulebook, wins over every skill and template). Mirrored in that repo's README, `AGENTS.md` §0 / §4.2 / §6.4 / §12.1 rule 15, and in `ai-devops`: `skills/claude/shared-db-orchestrator`, `shared-db-change` Rule 0.5, `shared-db-handover`, `skills/codex/codex-shared-db-change`, and both global templates. The test in one line: **shape or contents?**

Related: [[shared-db-read-only-is-open]], [[shared-db-apply-mechanics]], [[feedback_all_db_work_via_shared_db]].
