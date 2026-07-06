---
name: design-handoff-implement
description: Implement a Claude Design handoff zip in the real app. Use when the user attaches a design zip ("dflow RFQ design update.zip", "poppim.zip") and says "read the README in this zip in full" or "recreate these screens in our app". Used for dflow (Angular/AG-Grid) and the React apps (poppim-web, popcrm-web, popdam, hiclaw).
---

# design-handoff-implement

Albert generates visual designs with Claude Design and hands the exported zip to
Claude Code to implement in the existing stack. Past attempts failed by
implementing a lookalike from screenshots, skipping the spec, or breaking the
grid — all of which triggered "this looks 99% like the old site" rework loops.

## Trigger phrases

- "@<path>.zip Read README.md in this zip in full"
- "this is the visual frontend design that claude design created… recreate these screens"
- "implement this design IN OUR EXISTING STACK"

## Procedure

1. **Unzip and read everything**: README, SPEC/IMPLEMENTATION_PROMPT, screenshots,
   and the HTML prototype **source** — the prototype is the truth, not the
   screenshots.
2. **Read the real app screens** the design replaces before planning.
3. **Plan and STOP for approval.** Phased: design tokens → app shell → shared
   components → screens, lowest-risk first, one PR-sized commit per step.
4. **Implement within the existing stack.** Never scaffold a new app; don't
   touch the data layer, routing, or auth unless the spec says so.
   - React apps (poppim-web, popcrm-web, popdam, hiclaw): React + Vite +
     Tailwind + shadcn/ui, OKLCH design tokens only — no ad-hoc colors.
   - dflow (Angular + AG-Grid Enterprise): hard constraints — Theming API
     `themeQuartz.withParams` only, NO `--ag-*` CSS variables, no
     `sizeColumnsToFit()` with flex columns, don't touch fill-handle/undo/
     `getMasterFiledName()`; RFQ detail sub-grid columns are backend-driven and
     Saved Views silently override colDefs (`applyColumnState` on
     `firstDataRendered`).
5. **Verify per phase**: build + lint + existing tests; then serve and
   screenshot each changed screen and compare against the prototype BEFORE
   reporting done. "No visual change on the live site" has happened repeatedly —
   after deploy, verify the deployed URL too (see `deploy-and-verify` /
   `dflow-ship`).
6. Ship via the repo's normal path (main for u2giants apps; sandbox-albert PR
   for dflow).
