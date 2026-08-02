---
name: plm-master-data-sync-broken
description: The DesignFlow PLM master-data sync has been dead since 2026-07-08 (HTTP 502) and silently stopped logging failures; its endpoint also filters out is_active=false properties
metadata: 
  node_type: memory
  type: project
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-02T13:50:25.379Z
---

Two independent defects keep licensor/property data from reaching Supabase `core`:

1. **The sync is dead and silent.** `ingest.sync_run` last records a `designflow_plm` /
   `plm_master_data_api` run at **2026-07-08 03:30**. It is supposed to run daily
   (`plm-sync.timer` on host `hetz`). `getLicensorsWithProperties` returns **HTTP 502
   after ~31s**. 15 runs are recorded and **zero** have a non-success status — it stopped
   writing rows entirely rather than recording a failure. Classic silent failure.
2. **The endpoint filters MG06 on `is_active: true`.** Properties flagged inactive in
   DesignFlow are structurally invisible to the sync even when it is healthy and even when
   they are correctly parented. Confirmed 2026-08-02: `EX` THE EXORCIST, `LB` THE LOST
   BOYS, `CHR` CHEERS and `SGT` SUPERGIRL THEATRICAL 2026 all carry a correct `parent_id`
   in DesignFlow but `is_active = false`, and none of the four is in
   `plm.property_import` (468 rows).

**Why it matters:** every "why is this property missing / unmapped" question traces back to
one of these two. Fixing a mapping in DesignFlow does **not** propagate today.

**How to apply:** before diagnosing any licensor/property gap, check
`max(started_at)` in `ingest.sync_run` for `designflow_plm` and the `is_active` flag on the
DesignFlow row. Related: [[merch-group-taxonomy]],
[[licensor-fr-friends-tv-is-a-mistake]].
