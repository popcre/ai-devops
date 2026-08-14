---
name: owner-rulings-survive-syncs
description: "Standing structural rule — owner/curated changes in the shared DB must never be overwritten by ANY sync or refresh (DesignFlow, ColdLion, scrapes)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a1cdd34-1039-45ab-bf83-183e410350b9
  modified: 2026-08-14T14:21:22.084Z
---

Albert's standing rule, reaffirmed 2026-08-14 (he has stated it many times before):
the shared database must be **structured** so that changes made on our side are
persistent and are NOT overwritten by any refresh or sync — not a DesignFlow
re-seed, not a ColdLion API pull, not a portal scrape load.

**Why:** he has repeated this "1000 times" and sessions keep proposing per-case
workarounds (e.g. "add a marker before the next edge re-seed" for the COCO
licensor ruling). A per-case guard is a band-aid; the requirement is a general
structural property of the schema. Losing a curated ruling to a routine sync
silently corrupts master data.

**How to apply:** every writer into curated Master Data (`core.licensor`,
`core.property`, `core.character`, `core.customer`, `core.factory`) must be
column-scoped and additive, and must respect a persistent provenance/lock marker
that records which values were set by an owner ruling or manual curation. Design
that marker into the schema once, generally, rather than adding a one-off guard
before each sync. Never propose "remember to add a marker before re-running X"
as the fix. Related: [[merch-group-taxonomy]], [[shared-db-apply-mechanics]].
