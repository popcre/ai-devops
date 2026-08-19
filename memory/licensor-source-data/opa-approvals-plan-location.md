---
name: opa-approvals-plan-location
description: Where the Disney OPA approvals-into-dflow plan lives and that it must not be re-planned
metadata: 
  node_type: memory
  type: project
  originSessionId: 98170b3d-88a8-42c5-990f-1b423a317d39
  modified: 2026-08-19T19:46:04.533Z
---

The plan to feed Disney OPA approval decisions, rejections, resubmit requests
and reviewer comments into DesignFlow PLM lives at `plan_disney-opa-approvals.md`
in `popcre/designflow-tracking` (branch `sandbox-albert`), with its handoff at
`HANDOFF.d/2026-08-19T0140Z-edge-dev-claude-opa-submission-approvals.md`.
`u2giants/licensor-source-data` keeps a pointer at
`disney-opa/plan_opa-submission-approvals-to-dflow.md` and owns the capture half.

**Read its STATUS table first — do not re-derive or re-plan it.** As of
2026-08-19 nothing is built; a fresh session starts at Step 1, a stop-gate that
proves Disney's SKU values match dflow's `itemHeader.item_num_id`.

**Why:** the scoping that produced it (2026-08-18) cost a full session of
read-only portal work, and its rejected-approaches list exists so nobody repeats
those dead ends.

**How to apply:** open the plan before answering any question about Disney
approvals in dflow. Scope is Home and Toys, North America only (Albert,
2026-08-19). Portal procedure lives in the `disney-source-data-scrape` skill,
not in the plan. Related: [[peanuts-portal-is-tenovos]].
