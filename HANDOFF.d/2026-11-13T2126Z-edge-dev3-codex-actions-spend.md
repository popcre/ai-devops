---
issue: 2510
status: OPEN
owner: codex/actions-spend-plan
---

# DesignFlow Actions spending

## 0. Owner decisions
None needed for the scoped work. Budget settings and broader mirror cadence are outside scope.

## 1. Application
Six DesignFlow applications receive a copy of the common database description. GitHub runs app checks and reports release readiness. Uma owns DesignFlow promotion.

## 2. Goal
Lower GitHub spend during copy bursts without weakening readiness, database guards or the currency of the app copies.

## 3. State
The implementation plan covers baseline, docs upkeep, notifications and remaining paid checks. Workflows are untouched. Start with the [plan](../plan_designflow-actions-spend.md) and [GitHub copy on the planning branch](https://github.com/popcre/ai-devops/blob/codex/actions-spend-plan/plan_designflow-actions-spend.md).

## 4. Dead ends
A shorter paid notification job still starts a paid runner. Blanket skipping would affect unrelated checks. Path filtering alone cannot authenticate a mirror.

## 5. Findings
[Billing](https://github.com/organizations/popcre/settings/billing) showed $69.95 by November 13. The [notifier run](https://github.com/popcre/designflow-frontend/actions/runs/43504009082) paid to discover it could skip. The [documentation plan](https://github.com/popcre/designflow-backend/blob/develop/plan_docs-lookup-cleanup-and-upkeep.md) calls for weekly upkeep, while the [November 11 change](https://github.com/popcre/designflow-backend/commit/55f54c812) added every matching push.

## 6. Next steps
Execute plan step 1 first. Steps 2a and 3 can follow independently. Keep 2b scheduled proof open while investigating remaining savings. Know the docs work succeeded when six apps preserve weekly and manual upkeep without mirror-only executions. Record proof on [#2510](https://github.com/popcre/ai-devops/issues/2510).

## 7. Constraints
Keep existing release guards and check contexts. Use canonical notifier and normal protected promotion. Preserve GitHub fallback for required work. Keep sensitive evidence private.

## 8. Access
Existing GitHub organization read and repo access worked. Refer to the plan for repository and branch authority and existing App provisions.

## 9. Risks and uncertainty
The current sender can push ordinary changes, and the existing hosted chooser itself costs a job. Keep notification delivery unless an existing safe signal or cheaper trusted route is proved. Compare jobs and net spend against matched activity before closing.
