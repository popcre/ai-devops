---
name: minio-recursion-fix
description: "MinIO recursive storage loop bug - root cause, fix, and how to verify it won't recur"
metadata: 
  node_type: memory
  type: project
  originSessionId: 350cc1b5-aa14-4818-a802-a8e3ca45c6fa
---

HICLAW_RUNTIME=k8s (confirmed via docker inspect hiclaw-manager) causes start-manager-agent.sh k8s startup block to pull MinIO `hiclaw/hiclaw-storage/manager/` into the workspace on every container start. Controller's ManagerReconciler pushes workspace back to MinIO wholesale, including any `hiclaw/hiclaw-storage/` local copy that the pull created — each cycle adds one more recursion level.

**Why:** The workspace is both the pull destination AND the push source. Any subdirectory that appears in workspace due to a pull gets pushed back, creating a geometric loop.

**Fix applied 2026-05-20:** Added --exclude flags to the k8s mc mirror pull in start-manager-agent.sh (lines 186-193): excludes `hiclaw/*`, `hiclaw-fs`, `*.clobbered.*`, `.npm/*`, `.codex/*`, `.cache/*`. Also cleaned 9GB workspace/hiclaw/ local copy and 617 stale clobbered files.

**How to apply:** After any container restart, run the recursion check:
```bash
sudo find /var/lib/docker/volumes/hiclaw-data/_data/minio/hiclaw-storage -maxdepth 8 -type d -name "hiclaw-storage" -print
```
Should print only the root path. Extra lines = recursion returned, stop containers immediately.
