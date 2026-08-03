---
name: licensor-fr-friends-tv-is-a-mistake
description: "Owner ruling 2026-08-02 — licensor FR \"FRIENDS TV\" should never have existed; FRIDA KAHLO was a property under a now-defunct FRIDA KAHLO licensor"
metadata: 
  node_type: memory
  type: project
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-03T18:49:08.651Z
---

Albert's ruling, 2026-08-02, on two licensor-spine defects found in `core.licensor` /
`core.property` on the shared Supabase DB:

- **`FR` = "FRIENDS TV" was never a real licensor.** It was created by mistake. Do not
  treat it as authoritative and do not map anything new under it.
- **FRIDA KAHLO (`FK`) was a property under a FRIDA KAHLO licensor**, which is now
  **defunct**. Its current mapping in `core.property` (`FK` → licensor `FR` FRIENDS TV)
  is therefore wrong on both halves.

**FINAL position (2026-08-03), after two intermediate reversals — this is operative:**
- **FRIDA KAHLO STAYS as a licensor.** Not as a "defunct" exception — it is legitimate:
  we genuinely make product under a Frida Kahlo licence, and ColdLion transmits it in
  its licensor list (slot 05, both divisions, modified 2026-07-31). It was simply never
  imported into `core.licensor`.
- **FRIENDS TV must NOT exist as a licensor, not even temporarily.** FRIENDS has always
  been a *property* under WARNER BROS, so any genuine FRIENDS item has a correct home
  already. Remove `FR`, don't park it.
- **`X-NASA` goes too.** It is a hand-made substitute holding zero properties while
  ColdLion transmits a real `NA` NASA licensor. General principle: **use the licensor
  table as it comes in from ColdLion** — hand-made `X-` rows are for PROSPECTIVE
  licensors only, never as substitutes for ones ColdLion already sends.

**Why:** the `FR` code collision (property `FR` vs licensor `FR`) let a bad parent land in
production. Corroborated independently on 2026-08-02: ColdLion's item feed carries 7
products for property `FK`, unanimously naming a Frida Kahlo licensor — so the ruling is
backed by data, not only by assertion. Note `core.licensor` DOES have a `status` column
(enum `app.entity_status`: active/inactive/archived/deleted/potential) — an earlier claim
that it had no active/inactive concept was wrong. See [[merch-group-taxonomy]] and
[[no-inference-verify-everything]].

**How to apply:** treat `FR` as retire-on-sight, not as a valid parent. Keep defunct
licensors with a non-active `status` rather than deleting them. Any fix is a shared-db
branch+PR (preview first), never a direct UPDATE — and curated `status` only survives if
the importer stops force-resetting it, see [[plm-master-data-sync-broken]].
