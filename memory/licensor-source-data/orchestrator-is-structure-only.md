---
name: orchestrator-is-structure-only
description: The shared-db orchestrator governs STRUCTURE only. Deleting, inserting, or fixing rows is the working session's own job - never queue it.
metadata:
  type: feedback
---

The shared-db orchestrator/issue queue is ONLY for structural changes: schema,
tables, columns, views, functions/RPCs, triggers, RLS, indexes, migrations,
cross-app contracts.

Ordinary DATA work is NOT its job and must never be queued, handed over, or
asked about: deleting junk rows, cleaning up failed capture runs, backfills,
fixing values, loading an app's own scraped rows. The session doing the work
owns those rows and just does the work.

Only carve-out: bulk loading OUTSIDE-SOURCED content into curated Master Data
(`core.licensor`, `core.property`, `core.character`, `core.customer`,
`core.factory` and their `*_ext` tables).

**Why:** Albert corrected this repeatedly over 2026-08-17..19 and it wasted his
time every single time. Asking "should I queue this with the orchestrator?" for
a row deletion is itself the mistake.

**How to apply:** Before mentioning the orchestrator at all, ask: does this
change the SHAPE of the database? If no, do the work yourself (after proving
which database you are pointed at) and report the result. Never offer to queue
data work. See [[paramount-and-sesame-not-in-database]].
