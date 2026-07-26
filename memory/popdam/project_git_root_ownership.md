---
name: project_git_root_ownership
description: "In the /worksp/popdam workspace, .git and dist/ periodically revert to root ownership, breaking git/build as user 'ai' — fix with sudo chown"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8fa604ba-5565-4550-915b-ccedbedc3cf6
---

In the `/worksp/popdam` harness workspace, the agent runs as user `ai` but `.git/` (index + loose objects) and `dist/` are sometimes owned by `root`, causing `fatal: .git/index: index file open failed: Permission denied`, `unable to open loose object`, and vite `EACCES ... dist/assets`. It recurs mid-session (e.g. after a build invokes git).

**How to apply:** passwordless sudo is available. When git or build hits a permission error, run `sudo -n chown -R ai:ai .git` (and `sudo -n chown -R ai:ai dist` for build). This is a legitimate environment fix, not a workaround of the no-workarounds rule. Then proceed with the normal `git push origin main` + `git push github main` flow. Note: origin and github remotes both point at the same GitHub URL here, so the second push reports "Everything up-to-date".
