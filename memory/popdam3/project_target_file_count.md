---
name: Target file count
description: Expected number of .ai/.psd files that should be in the DAM when fully indexed
type: project
---

Target asset count is **120,678** .ai/.psd files (give or take a few hundred).

- `Decor/Generic Decor`: ~7,400 files
- `Decor/Character Licensed`: ~113,278 files
- Both under `/volume1/mac/Decor/` on the Synology NAS (container path: `/mnt/nas/mac/Decor`)
- `/volume1/styleguides` is intentionally excluded

**Why:** Verified via SSH on 2026-03-13 with `find` count directly on the NAS.

**How to apply:** If the asset count in the DB is significantly below ~120,678, something is wrong with the scan — diagnose and fix it. Don't accept a partial count as "done."
