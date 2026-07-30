---
name: audit-every-permission-layer
description: "When asked to fix one permission hole, sweep every layer (EXECUTE grants, table grants, views/matviews) — not just the layer named in the request"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1ecd9b80-bdf8-442d-968c-b37aa7972d6b
  modified: 2026-07-30T14:47:58.082Z
---

When a task names one permission problem, the same trust boundary is almost always
broken at other layers too. Audit all of them before reporting done: function
EXECUTE grants, table/column grants + RLS, and **views/materialized views**
(which have no RLS of their own and bypass the base table's RLS unless created
`security_invoker = true`).

**Why:** on 2026-07-29 the ask was "one SECURITY DEFINER function is anon-callable."
Sweeping the function layer found 88 of 99 exposed — good. But I scoped the *table*
layer out as "a different risk class," and that is where the actual customer-data
leak was: ~27,000 rows readable by anyone with the public anon key, across
`style_groups` plus three RLS-bypassing views. An independent GLM review, not my own
audit, flagged the layer I had skipped.

Second lesson from the same day: **do not detect exposure with catalog/regex
queries alone.** My `pg_policies` regex found 1 of the 4 leaks; probing all 53
anon-privileged relations with a real anon key found all 4. Privilege bits also
mislead — `has_function_privilege('anon', ...)` returned true for `plm` functions
that anon cannot reach at all, because anon lacks schema `USAGE` there. Prove
reachability end-to-end from outside the database.

**How to apply:** finish the named layer, then enumerate the other layers and test
each from outside with the real key before saying it is closed. Report cleared
items too, so the negative result is trustworthy. The standing rules that came out
of this are in `shared-db` `AGENTS.md` §10.2 — read that, don't re-derive it.
