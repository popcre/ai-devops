---
name: licensor-fr-friends-tv-is-a-mistake
description: "Owner ruling 2026-08-02 — licensor FR \"FRIENDS TV\" should never have existed; FRIDA KAHLO was a property under a now-defunct FRIDA KAHLO licensor"
metadata: 
  node_type: memory
  type: project
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-02T13:50:16.761Z
---

Albert's ruling, 2026-08-02, on two licensor-spine defects found in `core.licensor` /
`core.property` on the shared Supabase DB:

- **`FR` = "FRIENDS TV" was never a real licensor.** It was created by mistake. Do not
  treat it as authoritative and do not map anything new under it.
- **FRIDA KAHLO (`FK`) was a property under a FRIDA KAHLO licensor**, which is now
  **defunct**. Its current mapping in `core.property` (`FK` → licensor `FR` FRIENDS TV)
  is therefore wrong on both halves.

**Why:** the `FR` code collision (property `FR` vs licensor `FR`) let a bad parent land in
production, and the defunct-licensor case is not representable today — `core.licensor` has
no active/inactive flag, mirroring ColdLion's own lack of one. See
[[merch-group-taxonomy]].

**How to apply:** treat `FR` as retire-on-sight, not as a valid parent. Any fix is a
shared-db branch+PR (preview first), never a direct UPDATE. Note it cannot be fixed
durably upstream while the DesignFlow PLM master-data sync is broken — see
[[plm-master-data-sync-broken]].
