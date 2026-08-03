---
name: google-sheets-import-is-temporary
description: Owner ruling 2026-08-03 — Google Sheets Master Data import is transitional and must never overwrite curated data
metadata: 
  node_type: memory
  type: project
  originSessionId: 1ee30836-e24c-4e11-a6e0-d680a2fb6e2a
  modified: 2026-08-03T19:33:01.335Z
---

Albert ruled on **2026-08-03**, verbatim: *"importing Master Data info from Google
Sheets is a temporary thing until all the employees are ready to do all work in our
Master Data and then Google Sheets version gets deprecated and never touched again.
so any improvements we've made should no longer be overwritten by the imports from
Google Sheets. those imports should only be data that gets us up to date until we're
ready to cut-over (hopefully soon)."**

**Why:** the import is a catch-up mechanism during a migration off spreadsheets, not
a permanent integration. Curated-in-our-system outranks imported-from-Sheets for any
field a human deliberately set.

**How to apply:** an import may fill gaps and bring in what we do not yet have; it may
never revert a deliberate change. This is currently VIOLATED in production —
`plm.import_master_data()` unconditionally overwrites `core.property.licensor_id`
from feed nesting and force-sets `status = 'active'`, with no audit. It is harmless
only because the feed has been dead since 2026-07-08; reviving it before this is
fixed would silently revert every curated ruling.

Pairs with the related end-state ruling: the `dflow.*` tables are eventually retired
and `core.*` becomes the source of truth for all four applications, fed from ColdLion
as the ultimate upstream — design for that end state.

Related: [[licensor-fr-friends-tv-is-a-mistake]], [[parent-child-must-be-hand-curated]],
[[plm-master-data-sync-broken]]
