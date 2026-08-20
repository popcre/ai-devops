---
name: division-code-two-encodings
description: "division_code columns hold BOTH ColdLion codes (CW001) and DesignFlow ids (1); 78% of items sit in \"dead\" division 2, which blocks the erp_items_current backfill"
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

**The trap:** 15,185 of 19,463 DesignFlow item headers (78%) sit in division `2`, the one
everyone calls dead — none active, but that is where item history lives. Division `2` has no
ColdLion code under the rule above, so `public.erp_items_current.division_code` **must not be
backfilled** until the owner rules on it. As of 2026-08-17 Albert has not answered.

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
