---
name: aggrid-version-drift-local-install
description: Local node_modules can drift from the lockfile — always yarn install before trusting local tsc/jest in designflow-frontend
metadata: 
  node_type: memory
  type: feedback
  originSessionId: da60309d-a52f-4d12-abd0-fe4a5405be5f
---

In `designflow-frontend`, local `node_modules` had **AG Grid 35.2.1** installed while `package.json`/`yarn.lock` pin **36.0.0**. Local `tsc`/`jest` passed against 35.2.1 (looser types) but the Cloud Build (fresh `yarn install` → 36.0.0, stricter) failed — e.g. AG Grid 36 added `FullWidthNotesDataSource`, so a notes `dataSource` with optional `getNote/setNote` was no longer assignable to `notesDataSource`.

**Why:** Local checks ran against a different dependency version than CI, so green-locally / red-in-CI. Burned two Cloud Build cycles (~6 min each) before catching it.

**How to apply:** Before trusting any local `tsc`/`jest`/build result in this repo, run `yarn install --immutable` to match the lockfile — especially after a dependency bump (the repo's 35→36 AG Grid upgrade left stale local modules). The Docker build runs `yarn test`; a clean local install is the only way to reproduce CI faithfully. See [[aggrid-v36-legacy-theming]] and [[dflow-delivery-workflow]].
