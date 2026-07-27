---
name: plan-standardized-saved-views
description: "Open plan file for the Standardized saved-view defects — read its STATUS table first, do not re-plan"
metadata: 
  node_type: memory
  type: project
  originSessionId: 267f38b1-7f9c-4b33-814e-8841b9852791
  modified: 2026-07-27T02:27:29.187Z
---

`designflow-frontend/plan_standardized-saved-views.md` (branch `sandbox-albert`, written
2026-07-26) is the canonical plan for two Standardized-page defects: the dead "Add New"
saved-view button (template has no `@if (newViewInput)` block and the component has no
`onSaveNewView()`), and legacy saved layouts persisting group-level column ids so they never
apply. It also carries the always-true `onSaveLayout` Default guard and two sandbox data
cleanups.

**Read its STATUS table first — do not re-derive or re-plan that work.** As of 2026-07-26
nothing in it has been executed; a fresh session starts at Step 1. It is linked from
`AGENTS.md` §2a and from `HANDOFF.md`.

**Why:** the plan already records the live evidence, the rejected approaches, and two traps
that cost a session real time (see [[aggrid-saved-layout-gotchas]]). Re-planning throws that
away.

**How to apply:** open the plan, check STATUS, start at the first non-done step, and update
the STATUS table before ending the session.

Related: [[dflow-delivery-workflow]], [[aggrid-saved-layout-gotchas]], [[error-handling-standard]]
