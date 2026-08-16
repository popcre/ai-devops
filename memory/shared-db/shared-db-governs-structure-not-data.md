---
name: shared-db-governs-structure-not-data
description: "Owner ruling 2026-08-13 — shared-db and its orchestrator govern STRUCTURE only; app sessions own their own row writes, except bulk outside-sourced loads into curated Master Data"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf136834-2926-4717-97ba-49995ce80799
  modified: 2026-08-13T15:36:10.150Z
---

**The `u2giants/shared-db` repo and its orchestrator govern the STRUCTURE of the shared Supabase database, not the DATA inside it.**

> "shared-db orchestrator is for creating, changing, or deleting the STRUCTURE or schema or design of the database, not for creating, changing, or deleting the data inside the database. That should be done by the sessions working on the actual application." — Albert Hazan, 2026-08-13

**Gated (issue → orchestrator → branch → preview → PR):** schemas, tables, columns, types/enums, views, functions/RPCs, triggers, RLS policies, grants, indexes, constraints, extensions, realtime publications, storage policies, migrations, structural seeds that ship as a migration, cross-app data contracts.

**NOT gated — the application session owns it, no issue and no dispatch:** feature and bug-fix row writes, a scraper/importer/sync job writing its own ingest or staging tables, backfills and cleanups of data the app itself produced, preview test/fixture data, and operational rows (job runs, queues, cache, audit, logs).

**The one carve-out:** bulk or ad-hoc loading of OUTSIDE-SOURCED content (spreadsheet, CSV, export, pasted rows, API pull) into curated Master Data — `core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory`, `*_ext` — stays orchestrator work under `AGENTS.md` §6.4, matched-row abstention included. Trigger is provenance and target, not volume or verb.

**Why:** the old wording listed "seeds" and "data fixes" beside tables and columns and said any `INSERT` left read-only territory, so sessions queued ordinary app row writes behind the single-orchestrator gate. Never the intent. §6.4 survives because it was bought with an incident — this database records no per-field curation, so an ad-hoc dump can silently supersede hand-curated rulings.

**Unchanged:** §4.2 still requires proving the connection target immediately before every `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE`, preview and production alike. Read-only inspection stays open (§0.0-A). The single-orchestrator rule still governs structure work.

**How to apply:** controlling text is `shared-db` `AGENTS.md` §0.0-B, which wins over every skill and template. The test in one line: **shape or contents?**

Related: [[shared-db-apply-mechanics]], [[popdam-two-permission-systems]].
