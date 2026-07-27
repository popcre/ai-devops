---
name: aggrid-saved-layout-gotchas
description: AG Grid v36 saved-layout traps in dflow — applyColumnState silently ignores unknown colIds; married groups discard the whole order
metadata: 
  node_type: memory
  type: reference
  originSessionId: 267f38b1-7f9c-4b33-814e-8841b9852791
  modified: 2026-07-27T02:27:42.900Z
---

Four traps behind dflow's "saved column layout doesn't come back" bugs (all verified live on
the sandbox 2026-07-26, full detail in `designflow-frontend/AGENTS.md` §11):

1. **`applyColumnState()` silently ignores unknown `colId`s** — no error, no warning, no return
   signal. A saved layout referencing ids the grid doesn't have just quietly does nothing.
2. **Splitting a `marryChildren` group discards the ENTIRE saved order**, not just the offending
   columns (AG Grid warning #39). Repair helper:
   `src/app/helpers/ag-grid/married-safe-column-state.ts` — every `applyColumnState` that
   restores *persisted* state must go through it.
3. **Standardized saves via `stdService` → `/api/core/std/saveGridLayout`.** The `itemService`
   route `/api/core/saveGridLayout` returns **503** for that grid — a wrong-path symptom, NOT a
   down backend. Auth is a bare `Authorization: <token>`, no `Bearer` prefix.
4. **Testing trap:** never assert married-group contiguity against rendered `.ag-header-cell`
   elements — leaves with `columnGroupShow: 'open'` aren't in the DOM while collapsed, so the
   assertion passes vacuously. Assert against `gridApi.getColumnState()`.

Also: `licensing_tracking` and `prod_tracking` have fields *named* `gridColumnApi` that are
assigned `params.api` — misleadingly named but **working**. Don't "fix" them. The genuinely
broken ones (standardized, manage_users, customer-aggrid, item-size-aggrid, item-depth-aggrid)
were fixed in PR #149.

**Why:** these failures are invisible — the grid renders fine and the user just silently loses
their arrangement, which is exactly what [[error-handling-standard]] forbids.

**How to apply:** before touching any saved-view / column-state code, read AGENTS.md §11, and
prove any new regression test fails without the fix.

Related: [[plan-standardized-saved-views]], [[aggrid-v36-legacy-theming]], [[error-handling-standard]]
