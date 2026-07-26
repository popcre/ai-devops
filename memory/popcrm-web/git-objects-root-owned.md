---
name: git-objects-root-owned
description: "popcrm-web commits fail with \"insufficient permission for adding an object\" — fix with sudo chown"
metadata: 
  node_type: memory
  type: project
  originSessionId: b6c8d8bb-6b21-43f1-a55c-7eaab98c33b1
---

In `/worksp/popcrm-web`, some `.git/objects/*` subdirectories periodically end up
owned by `root` (likely a root process touching the repo), so `git commit`/`git add`
as user `ai` fails with `insufficient permission for adding an object to repository
database .git/objects`.

**Why:** mixed ownership inside `.git`; git can't write loose objects into root-owned dirs.

**How to apply:** `sudo chown -R ai:ai /worksp/popcrm-web/.git` (passwordless sudo is
available in this env), then re-run the commit. Verify with
`find /worksp/popcrm-web/.git -not -user ai | wc -l` → 0.

Also note: `git add -A` here picks up untracked `.playwright-mcp/`, `*.png` screenshots,
and `design_handoff_popcrm_elevation/` — stage explicit source paths instead. Related: [[work-on-main-no-branches]].
