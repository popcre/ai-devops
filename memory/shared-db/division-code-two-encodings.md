---
name: division-code-two-encodings
description: "division_code columns hold BOTH ColdLion codes (CW001) and DesignFlow ids (1); DesignFlow id 2 is internal-only and means CW001, confirmed live against ColdLion"
metadata: 
  node_type: memory
  type: project
  originSessionId: b03656ee-100d-46a8-80d1-915037d1b332
  modified: 2026-08-17T21:48:35.727Z
---

Divisions are stored in two encodings under the same column names: ColdLion
`CW001`/`SP001`/`EH001` and DesignFlow ids `1`/`8`/`9` (same three divisions).
Shared PLM item tables store the **ColdLion spelling**; never `1`/`8`/`9`, never the
deprecated id `2` or unused `7`. Company is always `EDGEHOME`. Proven live on item
`BRT10DYWP01` (2026-08-14) — do not re-verify.

**The trap:** 15,185 of 19,463 DesignFlow item headers (78%) carry `div_code_fk = 2`.
That id is **DesignFlow-internal — ColdLion has no division `2` and never did** (their four
codes are `CW001`, `EH001`, `SP001`, retired `EP001`). Tell: those rows have their ColdLion
text column empty while ids 1/8/9 carry theirs. Asked live 2026-08-17, **19 of 19 division-2
items came back `CW001`** from ColdLion, so **id `2` → `CW001`** and the
`erp_items_current` backfill is unblocked. Never *store* `2`; translate it on the way in.
Do not re-raise this as an owner decision — it was one for a few hours and is settled.

**Separate and still open:** ColdLion calls those items active; the DesignFlow mirror marks
all 15,185 inactive. Not a division problem.

`EP001` is a **real retired book/education division**, not a mis-keyed `EH001` — never
"correct" it. Three `core."merchGroup"` rows (`mg_id` 2, 3, 4) carry no division at all, look
like junk, and hold 573 item references between them.

Authority, read before any division change:
`docs/division-code-round2-answers-and-reference-check-20260817.md` in `u2giants/shared-db`
(178 of 363 unclean rows safe to clean, 185 not), plus `AGENTS.md` §6.1b for the short version.
Two fix rules from the original answers are **withdrawn** — read the banner on
`docs/division-code-answers-from-uma-20260813.md` before applying anything from it.

Related: [[merch-group-taxonomy]], [[owner-rulings-survive-syncs]],
[[shared-db-apply-mechanics]]
