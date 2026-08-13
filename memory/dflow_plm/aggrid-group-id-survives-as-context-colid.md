---
name: aggrid-group-id-survives-as-context-colid
description: "On dflow Standardized, a saved layout's column-GROUP id survives only as colDef.context.col_id — getColumnDefs() gives an auto-numbered groupId and customizeGrid clears field"
metadata: 
  node_type: memory
  type: project
  originSessionId: 523862e6-fe06-4f9a-a052-cdeefa6d6a7f
  modified: 2026-07-27T22:03:59.271Z
---

Standardized stores its saved column arrangement as **group** ids (`1_5`, `1_24`) in `GridLayout`,
and the **leaf** order separately in `GridChildrenLayoutOrder` (baked into `getSTDHeader`'s
colDefs). That is by design, not legacy data — a live census on 2026-07-27 found zero leaf ids in
`GridLayout` for any product type. `applyColumnState` silently ignores ids it doesn't recognise, so
the saved order never applied at all. Fixed by
`src/app/helpers/ag-grid/legacy-group-column-state.ts`, which expands group ids to leaves before
the existing married-safe repair.

**Why this is worth remembering:** matching that group id against the live grid failed twice, each
time costing a full build-and-deploy cycle, because both obvious identifiers are gone by restore
time:
- `gridApi.getColumnDefs()` returns groups as `{groupId: "0", headerName: "Glitter", children: […]}`
  — `groupId` is an **auto-generated counter**, not the DB id.
- `customizeGrid()` sets **`col.field = undefined`** on every group (an AG Grid group def must not
  carry `field`), and `moveLayoutMetadataToContext()` moves the DB `col_id` into **`context`**.

**How to apply:** to identify a Standardized column group from persisted state, read
**`colDef.context.col_id`**. Both wrong attempts produced a green build, a green test suite and a
page that looked fine — the only thing that caught them was the `console.warn` added for
unresolvable ids, which is a concrete argument for the no-silent-failures rule
([[error-handling-standard]]). Full evidence in `plan_standardized-saved-views.md` § 5a and
AGENTS.md § 11. Related: [[aggrid-version-drift-local-install]].
