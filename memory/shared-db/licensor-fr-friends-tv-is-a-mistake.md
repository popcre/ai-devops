---
name: licensor-fr-friends-tv-is-a-mistake
description: "Owner ruling 2026-08-02 — licensor FR \"FRIENDS TV\" should never have existed; FRIDA KAHLO was a property under a now-defunct FRIDA KAHLO licensor"
metadata: 
  node_type: memory
  type: project
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-03T00:59:09.016Z
---

Albert's ruling, 2026-08-02, on two licensor-spine defects found in `core.licensor` /
`core.property` on the shared Supabase DB:

- **`FR` = "FRIENDS TV" was never a real licensor.** It was created by mistake. Do not
  treat it as authoritative and do not map anything new under it.
- **FRIDA KAHLO (`FK`) was a property under a FRIDA KAHLO licensor**, which is now
  **defunct**. Its current mapping in `core.property` (`FK` → licensor `FR` FRIENDS TV)
  is therefore wrong on both halves.

**Later the same day Albert REVISED the disposal rule.** He first said "do not create
discontinued licensors — only prospective ones may be non-ColdLion", then reversed it:
**defunct licensors are KEPT in the system**, specifically the FRIDA KAHLO licensor that
the ColdLion API transmits. The reversal is the operative instruction.

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
