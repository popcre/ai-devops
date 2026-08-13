---
name: dflow-fixes-register
description: "dflow's canonical bug register (fixes.md) — where it lives, current status, and the regression-by-activation caution"
metadata: 
  node_type: memory
  type: project
  originSessionId: b57441dd-c8bf-4a8d-b4e1-adcd2aa896e9
  modified: 2026-07-20T23:52:56.844Z
---

The whole-codebase audit register is **`fixes.md`**, tracked canonically in
`designflow-frontend/fixes.md` (a floating convenience copy also sits at the
workspace root `C:\repos\dflow plm\fixes.md`; keep both in sync). The workspace
root is NOT a git repo — only the six `designflow-*` subdirs are.

Re-verified against live `sandbox-albert` code on 2026-07-20 (one agent per repo,
treating commit messages and prior doc claims as unproven): **39 findings closed,
106 open, 14 new.** Original audit 2026-07-07, reconciled with the retired
`bugs.md` on 2026-07-15.

Things prior docs got WRONG (verify, don't trust):
- The JWT `algorithms` (plural) auth-bypass **B1/I6/T7 is FIXED in all three
  services.** Root `HANDOFF.md` and old `fixes.md` still called it the top open
  security item — stale.
- The `result(null, err)` fake-HTTP-200 pattern is eliminated in item-master and
  data-syncing (zero occurrences each) and swept in backend/tracking.
- Tests no longer run at container cold start anywhere; jest/nodemon are devDeps.
- The `DB_NAME` Cloud Build deploy blocker is fixed (env-specific secret substitutions).

**Regression-by-activation is now a live theme:** three fixes created new bugs —
B31 (`saveTechLink` now throws into a bare async Express handler → hung request),
D34 (integer `.toUpperCase()` crash the D1/D21 sync repair made reachable), F39
(upload throw swallowed by legacy uploaders). Every fix must now state what latent
code it makes reachable. See [[dflow-vendor-identity-model]] for the Group A security work.
