---
name: shared-db-read-only-is-open
description: Owner ruling 2026-08-10 — read-only inspection of the shared Supabase DB is allowed from EVERY app repo with no issue/dispatch; only changes are gated
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e946e2de-58fa-4ae7-83d3-b4541101efb5
  modified: 2026-08-11T01:21:33.418Z
---

**Read-only inspection of the shared Supabase database is allowed from every application repository**, with no GitHub issue, no orchestrator dispatch and no handover. That covers schemas, tables and columns, keys and relationships, indexes, constraints, views, functions/RPCs, triggers, RLS policies, migration history, generated types, metadata and safe sample data — plus comparing all of it against app code, scraper output, source-data shapes, business rules and proposed features.

Only **structural** changes are gated: every schema/view/RPC/trigger/RLS/index/constraint/structural-seed/migration/data-contract change is still authored in `u2giants/shared-db` first via branch → preview → PR.

**DATA is not gated either** (second owner ruling, 2026-08-13 — see [[shared-db-governs-structure-not-data]]). The rows an application writes, updates or deletes in the normal course of its work belong to that application's session, with no issue and no dispatch. The one exception is bulk/ad-hoc loading of outside-sourced content into curated Master Data (`core.licensor`, `core.property`, `core.character`, `core.customer`, `core.factory`, `*_ext`), which stays gated under `AGENTS.md` §6.4.

**Why:** the database serves many applications and each must be able to judge whether it fits its data — impossible without seeing the whole schema. Several skills said "do not perform database work", which sessions read as a blanket blocking harmless reads. Albert ruled 2026-08-10 that the blanket is wrong.

**How to apply:** the split is written in `shared-db` `AGENTS.md` §0.0-A (the live rulebook, wins over skills), `shared-db-change` Rule 0, `codex-shared-db-change` Rule 0, and the global templates in `ai-devops`. Never use "database work" as an undifferentiated term — say "change" when you mean change. Unchanged: production/shared-cloud read-only safety, the approved read-only AI identity, §0.1-A's Cloud SQL conditions and "never report row contents", and licensed-data protection (licensed rows stay in their approved private repo — never a public repo, issue, log, outside-service prompt, commit message or PR).

Related: [[shared-db-apply-mechanics]], [[popdam-two-permission-systems]].
