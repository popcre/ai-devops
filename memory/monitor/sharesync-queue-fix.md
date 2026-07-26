---
name: sharesync-queue-fix
description: Only known working fix for a stuck ShareSync queue jam. Restarting the package or NAS does NOT work.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 118a8af4-fdfa-4e10-a2e2-0cd981dc2f73
---

Restarting SynologyDriveShareSync (or even the full NAS) does **not** clear a stuck sync file. The queue jam persists.

**Why:** The stuck file's entry remains in the ShareSync queue database. A restart replays the same stuck state.

## Only fix that works
1. Move the stuck file out of its current folder to its **parent folder**
2. Rename the file (to anything)
3. Wait for ShareSync to sync that change through
4. Move the file back to the correct location
5. Rename it back to the original name (except fix any illegal characters — those must stay fixed)

**How to apply:** When diagnosing a ShareSync queue jam alert (`/Decor/Generic` or similar), do not suggest restarting the package. Guide the user through the move/rename/wait/move-back procedure on the source NAS (edgesynology1).

## Current active jam (as of 2026-06-03)
edgesynology2, `/Decor/Generic` folder, ~196 queued events, firing critical alert every 5 minutes since June 1. Source of the stuck file is on edgesynology1 in the `Decor/Generic` path.
