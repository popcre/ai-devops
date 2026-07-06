---
name: dflow-session-start
description: DesignFlow PLM session opener. Use at the start of any dflow session, or when the user says "pull develop into sandbox-albert" or any branch-sync variant. Syncs all six designflow repos and loads the standing dflow rules Albert used to paste manually every session.
---

# dflow-session-start

Branch-sync ritual plus standing rules for DesignFlow PLM work. Albert pasted
this preamble at the start of nearly every dflow session on three machines.

## Trigger phrases

- "pull the latest changes from develop on github.com into sandbox-albert…"
- "pull develop branch on github.com into sandbox-albert on github.com"
- "update the local repos to the latest from github.com"
- Any session opening in a dflow working copy

## Repos and branches

Six sibling repos (GitHub org `popcre`): designflow-frontend, designflow-backend,
designflow-bff, designflow-item-master, designflow-tracking, designflow-data-syncing.

| Working copy | User branch | Live URL |
|---|---|---|
| `…\dflow` / `dflow plm` | `sandbox-albert` | https://alsand.designflow.app |
| `…\dflow-alsand2` / `dflow alsand2` | `albert-2sandbox` | https://alsand2.designflow.app |

## Sync procedure (per repo, all six)

1. Check `git status` first — another AI session may have uncommitted work.
   Never discard or clobber it silently; report and reconcile.
2. On GitHub: merge `origin/develop` → the user branch (`gh` CLI is authenticated).
3. Locally: pull the updated remote user branch into the local user branch.
4. Report conflicts in plain English and resolve them; never leave a repo mid-merge.

## Standing rules (in force for the whole session)

- Work ONLY on the user branch. Pull from `develop`. **Never touch `main`.**
  Never merge PRs — the human developer (Uma, `devopswithkube`) reviews them.
- All AG-Grid coding per `search_docs` in the AG-Grid MCP server (Angular 35.1.0
  is the latest version it exposes; the app runs AG-Grid Enterprise v35/v36).
  Theming API only (`themeQuartz.withParams`) — no legacy `--ag-*` CSS variables,
  no `sizeColumnsToFit()` on grids with flex columns. Saved Views silently
  override colDefs — use `applyColumnState` on `firstDataRendered`.
- Add unit tests for every function/feature you create.
- Commit author: `Albert Hazan <u2giants@users.noreply.github.com>` (other
  emails fail GitHub's email-privacy check).
- Read `AGENTS.md` (router) and `HANDOFF.md` if present; do not bulk-load every
  .md file.
- dflow uses GCP Cloud SQL today (Supabase migration is planned, architecture
  stays Angular→BFF→Express→Sequelize). It is NOT on Supabase — don't assume.
- Pushing the user branch auto-deploys via Google Cloud Build (GCP project
  `lithe-breaker-323913`, region `us-east4`).
