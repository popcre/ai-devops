---
name: ""
metadata: 
  node_type: memory
  originSessionId: b1ddb6e1-d01b-49a0-8387-254e70fb70fb
---

When Albert says **"dflow wrap up"** (or "wrap up", "wrap it up", "close out",
"end of session"), invoke the **`wrap-up`** skill — NOT `dflow-ship`.

**Why:** `wrap-up` is the full end-of-session closer and its Step 1 is updating
the `.md` docs (via `session-docs-update`), followed by secrets sweep,
handoff-safe check, and only then the ship step (which for dflow delegates to
`dflow-ship`). `dflow-ship` on its own is ONLY the ship step (commit/push/PR/
deploy) and historically just "offered" the docs update — so routing "dflow wrap
up" to `dflow-ship` silently skipped updating the .md files. This mis-route
happened repeatedly across sessions and machines and frustrated Albert.

**How to apply:** Any message containing "wrap up" → run `wrap-up`, even with a
project prefix like "dflow". `dflow-ship` now carries a routing guard that hands
back to `wrap-up`, and its docs follow-up is now mandatory (not "offer"), but the
first-choice route is still `wrap-up`. Related: [[dflow-delivery-workflow]].
