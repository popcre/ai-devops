---
name: coldlion-field-decisions-are-owner-authority
description: "Albert personally marked every ColdLion API field ingest/ignore on 2026-08-19; that CSV is authority — read the plan's STATUS table, never re-derive"
metadata: 
  node_type: memory
  type: project
  originSessionId: 542c9c93-9e90-4a76-adc0-55abe2199ec7
  modified: 2026-08-19T19:41:38.549Z
---

On 2026-08-19 Albert reviewed every field of eight ColdLion API feeds and marked each
`ingest` or `ignore` himself. The result is
`docs/coldlion-field-decisions-20260819.csv` in `u2giants/shared-db`. **It is owner
authority, not a suggestion.** The build plan is
`docs/plan_coldlion-landing-phases-2-6.md` (issue #1184, phases 2-6) — read its STATUS
table first and do not re-derive its measurements or re-plan its steps.

Two rulings that are easy to get wrong:

- **No raw JSON archive** (he overruled the recommendation on query-performance grounds).
  So an `ignore` on the two history feeds is **permanent** — reversing one means
  re-pulling 7 years. Master feeds are cheap to re-pull, history is not.
- **"Merch groups belong to the item, not the order"** applies to **line-level**
  `merchGroupNN` only. `subMerchGroup*` and `ppkMerchGroup*` describe component styles
  inside an assortment, deliberately differ from the master item, and are **kept**.

**How to apply:** never widen a ruling past the evidence that produced it, and never
present a low fill percentage as a reason to discard a field without sampling widely —
`lineCancelledQty` measured 0.8%, 11.5% and 24% in three samples of the same feed.

Related: [[merch-group-taxonomy]], [[property-list-two-kinds-ruling]],
[[shared-checkout-commits-can-land-elsewhere]]
