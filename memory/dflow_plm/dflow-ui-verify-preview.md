---
name: dflow-ui-verify-preview
description: How to actually see a dflow UI change render (start:preview + GUI creds) and the dev-server AG-Grid renderer gotcha
metadata: 
  node_type: memory
  type: reference
  originSessionId: b57441dd-c8bf-4a8d-b4e1-adcd2aa896e9
  modified: 2026-07-22T02:11:06.418Z
---

To visually verify a dflow frontend change (Albert's rule 14 — don't ship UI on
confidence), serve the LOCAL build against the sandbox backend and drive it:

1. `preview_start` the `designflow-frontend` `start:preview` script (ng serve
   `--configuration preview --port 4200`); it proxies `/api/*` to the sandbox so
   the browser only ever talks to `localhost:4200`.
2. Log in with the **"designflow PLM frontend gui access credentials"** item in
   1Password vault `vibe_coding` (user `umeka@popcre.com`; the item note says it's
   for UI verification). Albert must OK the login — entering a password into a
   field is otherwise off-limits.
3. **Angular reactive forms ignore a value set directly** (`form_input` /
   `.value=`). Use the native setter + dispatch `input`+`blur` events, or the
   real `type` action, or the SIGN IN click leaves the form empty (`hasToken`
   stays false). Assert the URL left `/login`.
4. **Big gotcha:** the Angular dev server (component-HMR, the `@ng/component`
   requests) renders **AG Grid Angular cell renderers as EMPTY cells** — the
   Sample grid's photo/status/name renderers all show blank. This is a
   dev-server-only artifact, NOT a prod bug (the `ng build` prod image renders
   them fine). To test a grid cell's behavior, open the target dialog directly
   via `window.ng.getComponent(host).onOpenDetail(row)` instead of clicking the
   (blank) cell. Measure layout with `getComputedStyle`/`getBoundingClientRect`;
   the Browser pane doesn't composite CSS animations while hidden, so a stuck
   `translateX(100%)` transform is a compositing artifact, not a positioning bug.

CSS lesson from the sample-tracking detail flyout: a MatDialog opened as a
right flyout scrolls only if the `.mat-mdc-dialog-content` gets `overflow-y:auto`
+ `min-height:0` AND no component-scoped rule on the same element (e.g.
`.detail-dialog.flyout`) sets `overflow:visible`, which silently wins and clips
the content. See [[dflow-fixes-register]].
