---
name: nas-migration-plan
description: "Two-pass NAS rebuild plan: wipe edge2 first, copy from edge1, then wipe edge1 and copy back. File date preservation is a hard requirement."
metadata: 
  node_type: memory
  type: project
  originSessionId: 118a8af4-fdfa-4e10-a2e2-0cd981dc2f73
---

## Goal
Clean DSM reinstall on both units to escape persistent Drive/ShareSync corruption. All file dates (mtime + Windows xattrs) must be preserved.

## Plan
1. Wipe edgesynology2, install clean DSM + packages
2. Copy files from edgesynology1 → edgesynology2 using rsync
3. Switch users to edgesynology2 (temporary)
4. Wipe edgesynology1, install clean DSM + packages
5. Copy files from edgesynology2 → edgesynology1
6. Switch users back to edgesynology1

## rsync command (preserves all timestamps + Windows created-date xattrs)
```bash
rsync -aXHv --numeric-ids -e ssh \
  admin@edgesynology1:/volume1/ \
  /volume1/
```
- `-a` preserves mtime, permissions, ownership
- `-X` preserves Samba xattrs (Windows "Date Created")
- `-H` preserves hard links
- `--numeric-ids` avoids UID/GID remapping on fresh DSM

## Do NOT copy the Synology Drive database
Exclude `@synologydrive` — it's the source of corruption. Let Drive re-index from the clean filesystem. mtime on every file will be correct.

## Volume layout
The two units are NOT layout-compatible (different disk count, no NVMe on edge2). Btrfs send/receive is not an option. rsync only.

**Why:** edgesynology1 has 6 HDDs + 2 NVMe; edgesynology2 has 5 HDDs, no NVMe, different md array count.

## Pre-wipe checks for edge2
- md0 and md1 are currently degraded=1 (system RAID1, one disk missing). Identify which physical disk before wiping.
- 25 Btrfs corruption_errs on the volume device (cachedev_0 is the device mapper name, not SSD cache).

## Data integrity concern
edgesynology2's data may be incomplete/incorrect due to years of Drive/ShareSync queue jams. edgesynology1 is the authoritative source. All work is done on edge1 and synced to edge2.
