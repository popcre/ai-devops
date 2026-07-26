---
name: git-objects-root-owned
description: "Recurring git failure in /worksp/directus — sudo/root git runs leave .git objects+refs root-owned; commits fail with \"invalid object\" until chowned back to ai."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3e4ef769-b9b9-4773-a58f-e7a497115a75
---

In `/worksp/directus`, commits/pushes intermittently fail with errors like `error: invalid object 100644 <sha> for '<path>'` / `unable to open loose object <sha>: Permission denied`. Cause: a prior git operation ran as **root** (via sudo, or another tool/agent like codex), writing files under `.git/objects/` and `.git/refs/` owned by `root` with restrictive perms. The `ai` user then can't read a blob the index references, so git can't build the commit tree — even when the unreadable object belongs to an unrelated already-staged file.

**Fix (run automatically, don't ask):**
```
sudo chown -R ai:ai /worksp/directus/.git
```
Then retry the commit/push. Verify with `git fsck --connectivity-only` (dangling objects in output are harmless/normal). Confirmed safe — only changes ownership of git's internal store, never file content or history.

**Why:** First hit 2026-06-16 committing saved-views files; ~127 objects + 19 dirs + the `main`/`origin/main` refs were root-owned. chown fixed it; commit `0133b64` then succeeded.

**How to apply:** When a git command in this repo fails with "invalid object" or "Permission denied" on a loose object, just run the chown above and retry — no need to diagnose from scratch or check with the user. **Prevent:** avoid `sudo git ...` in this repo so the object store stays `ai`-owned. Related: [[platform-decision-directus]].
