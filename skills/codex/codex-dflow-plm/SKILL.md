---
name: codex-dflow-plm
description: DesignFlow PLM Codex workflow for session start, implementation, and session end. Use for dflow/designflow work, sandbox-albert or albert-2sandbox branch sync, AG-Grid coding rules, Uma PR handoff, or when the user references uma_designflow_prompt.docx.
---

# Codex DesignFlow PLM

DesignFlow is the PLM application in the `popcre` GitHub org. This skill covers
the repeated beginning-of-session and end-of-session prompt.

## Repos

The six DesignFlow repos are:

- `designflow-bff`
- `designflow-frontend`
- `designflow-backend`
- `designflow-item-master`
- `designflow-tracking`
- `designflow-data-syncing`

Default Windows parent path: `C:\repos\dflow`.

## Branch Rules

- Work only on Albert's branch: `sandbox-albert`.
- Visual-only branch: `albert-2sandbox`.
- Pull from `develop`.
- Never work on or merge to `main`.
- Never self-merge PRs; Uma (`devopswithkube`) reviews and merges.

## Session Start

1. Verify `gh` is authenticated.
2. Clone missing repos or open existing working copies.
3. In every repo: check status, fetch, merge `origin/develop` into the user
   branch on GitHub when appropriate, then pull the updated user branch locally.
4. Read `AGENTS.md` and `HANDOFF.md` if present.
5. Load only task-relevant docs.

## Coding Rules

- For AG-Grid work, use the AG-Grid MCP `search_docs`; Angular 35.1.0 is the
  latest version exposed there for docs lookup.
- Add unit tests for functions/code created.
- Keep changes on the user branch.
- Do not paste or document database passwords. Any read-only database access
  belongs in 1Password or approved local secret storage, never in prompts,
  docs, commits, or chat output.

## Ship For Uma

When ready:

1. Run relevant unit tests/builds.
2. Commit and push touched repos.
3. Create or update PRs from the user branch to `develop`.
4. Verify sandbox deploy when the repo's deploy path supports it.
5. Report PR URLs, commit SHAs, tests, and anything Uma needs to know.
