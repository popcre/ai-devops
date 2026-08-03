---
name: parent-child-must-be-hand-curated
description: "Owner ruling 2026-08-02 — the property→licensor parent link is hand-curated in a Supabase table, never inferred from product data"
metadata: 
  node_type: memory
  type: project
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-03T15:20:03.884Z
---

**The licensor→property parent relationship must be HAND-CURATED in a table in
Supabase.** It moves out of DesignFlow (whose `dflow.*` tables are to be retired)
and into the shared database, but it stays a curated table — it is NOT to be
derived from product data.

**Why:** Albert's ruling, 2026-08-02, after an investigation showed the link can be
reconstructed by co-occurrence — every ColdLion item row carries both a licensor
code (`merchGroup05`) and a property code (`merchGroup06`), reproducing 211 of 225
DesignFlow links (93.8%). His position: inferring a parent from many examples is
not a sound way to structure the relationship, however well it scores. The
investigation itself proves the risk — 4 of 14 disagreements were caused by staff
test records ("awdawd", "TESTTTT", "Alex54"), and COCO would have been mis-filed
under Coca-Cola by a plain majority vote because of a code collision.

**How to apply:** treat item co-occurrence as an AUDIT tool — good for catching a
wrong parent, never the mechanism that sets one. A parent change is a curated
decision recorded in the table. Note ColdLion itself has no parent field at all,
so the curated table is the only place this relationship will exist once
DesignFlow is retired. Related: [[merch-group-taxonomy]],
[[licensor-fr-friends-tv-is-a-mistake]], [[no-inference-verify-everything]].
