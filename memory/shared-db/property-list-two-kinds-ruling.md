---
name: property-list-two-kinds-ruling
description: Owner ruling 2026-08-19 — exactly two kinds of property list (portal scrapes = licensed for; ColdLion = actually used); core.property Universe A is deleted
metadata:
  type: project
---

Albert ruled on 2026-08-19 (issue #865, recorded permanently as `AGENTS.md` §6.15
in shared-db PR #1237) that licensed properties live in exactly TWO kinds of list:

- **portal scrape lists** (Disney OPA, Warner STARLABS, NBCU, Paramount, Peanuts,
  Sesame, WildBrain, Sega) = what we are **licensed for**
- **the ColdLion API list** = which ones we **actually use**

Neither is derivable from the other. There is no third kind.

"Universe A" is deleted: `core.property` (256 rows, no source-ID columns),
`core.character` and `core.property_character` (both empty), and `core.licensor`
(26 rows) if it proves unused. Work tracked on shared-db issue #1238.

"Universe B" survives: `core.properties_and_characters` (10,122 rows carrying
`source_licensed_property_id` / `source_character_id`) and
`core.property_character_associations` (9,622 rows), keyed to `core."licenseList"`.

**Why:** Universe A is hand-made and carries none of the licensors' own primary keys,
so it can never be matched row-for-row against a portal capture. Universe B's portal
membership is proven (112/112 sampled Disney OPA IDs, 6/6 Warner). `licenseList` 13
(`CC`) is the one synthetic exception (`COKE-CHAR-00n` IDs).

**How to apply:** any licensor reconciliation targets Universe B, never Universe A
(that re-scopes issue #640). Do not propose a third list or a merge of the two kinds.
The ruling settles the destination only — it does NOT authorize dropping anything
without the blast-radius pass, migration, preview rehearsal and production evidence
chain. Related: [[merch-group-taxonomy]], [[shared-db-apply-mechanics]].
