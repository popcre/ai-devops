---
name: work-on-main-no-branches
description: "In popcrm-web, always commit directly to main — never create feature branches"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64fcf6ec-26c9-45a6-b628-e7c08fc552a2
---

In the `popcrm-web` repo, work directly on `main`. Do not create feature branches, and do not open PRs unless explicitly asked.

**Why:** The user stated "Commit to main and delete any other branches and never use branches again" (2026-06-11), after I had built the frontend redesign on a `frontend-redesign` branch. They want a single-branch workflow here.

**How to apply:** When committing in this repo, stay on `main` and commit/push there. Skip the default "branch first if on main" habit for this project. Still only commit/push when the user asks.
