---
name: division-code-two-encodings
description: "division_code columns hold BOTH ColdLion codes (CW001) and DesignFlow ids (1); DesignFlow id 2 is an internal MIXED bucket - resolve those items from ColdLion per item, never map"
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
That id is **DesignFlow-internal — ColdLion has no division `2` and never did**. It is a
**mixed legacy bucket**: a 250-item random sample against the full ColdLion catalogue
(2026-08-18) came back 83.5% `CW001`, 8.4% `EH001`, 6.8% `SP001`, 1.2% `EP001`, 0.4% absent.
**Never blanket-map `2`** — it would misfile ~2,500 rows. A 19-item sample said 100% `CW001`
and produced exactly that wrong conclusion; do not repeat it.

**Owner ruling (2026-08-18, "go according to ColdLion"):** resolve each item's division from
ColdLion **by item number**. Ids 1/8/9 translate safely; `2` does not. Never *store* `2`.
Sweep the catalogue with `collectItems()` in `tools/sync-coldlion-items.mjs` (97 pages, ~90s).

**Separate and still open:** ColdLion marks 18,866 of 19,326 items active, the mirror ~1,000 —
probably not the same question (check `itemAvailable`/`itemDiscontinued`). Also: `EP001` is
retired but NOT empty (451 items). Neither is a division problem.

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
