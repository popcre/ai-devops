---
name: project-batch-ops-live-in-worker
description: "PopDAM long-running batch/bulk ops are Railway worker handlers, not Supabase edge functions; don't describe a component before opening its file"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a5b073e-5511-4091-aa73-b211df3e4d41
  modified: 2026-07-29T22:41:09.125Z
---

In PopDAM, every long-running batch/bulk operation is a handler in
`apps/worker/src/handlers/` running on the Railway worker. Supabase edge functions
under `supabase/functions/` are request-response only, and
`supabase/functions/bulk-job-runner` is a deployed no-op that returns
`{ ok: true, message: "replaced by railway worker" }`. Edge functions hold just the
registry entry for an op (`_shared/operation-constants.ts`).

**Why:** the repo has a large, prominent `supabase/functions/` tree and CLAUDE.md
talks about edge functions constantly, so "where does this background job run?"
pattern-matches to the wrong answer. On 2026-07-29 I told Albert the
`tag-popsg-files` resume cursor was written by an edge function; it is written by
`apps/worker/src/handlers/popsg-tags.ts`. In the same reply I raised a
base64-padding risk from general knowledge of base64 before opening the writer —
it uses `base64url` (no padding), so the concern was empty.

**How to apply:** for any question about where background/batch work happens, look
in `apps/worker/src/handlers/` first. More generally: do not state how a component
behaves, or flag a risk in it, until the file that implements it is open. Verify,
then describe. Also label verified checks as "confirmed, no action needed" rather
than grouping them under a heading that reads like a to-do list — Albert reads a
trailing list as work he owes.

Recorded in the repo too: AGENTS.md quirk "PopSG file tagging (`tag-popsg-files`)
runs in the Railway worker, not an edge function", plus a header comment in
`apps/worker/src/handlers/popsg-tags.ts`. See [[feedback-no-workarounds]] and
[[project-popsg-search-paths]] (same failure mode: assuming the standard path
instead of checking which one this feature actually uses).
