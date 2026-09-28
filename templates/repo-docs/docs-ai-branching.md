# AI Branching & Workspace Safety

Rules for how AI agents (and humans) use branches in an onboarded repo.

## Core rules

- **Never commit directly to `main` / `master`.** Always use a feature branch.
- **One task, one branch.** Name it descriptively, e.g.
  `feat/checkout-tax`, `fix/login-redirect`, `chore/upgrade-deps`.
- **Start clean.** Run `ai-workspace-status` before starting. If the tree is
  dirty or you are on `main`, stop and fix that first.
- **Keep changes small.** Smaller diffs review faster and roll back cleaner.

## Before you start a task

```bash
ai-workspace-status          # confirm branch + clean tree + PR state
git switch -c feat/my-task   # create a feature branch off the base
```

## Before you open a PR

```bash
ai-workspace-status          # confirm branch is ahead of origin, tree is clean
ai-codex-review diff-review  # optional second opinion on the diff
```

## Safety warnings you may see from `ai-workspace-status`

- **On main/master** — you must branch before editing.
- **DIRTY working tree** — commit/stash/discard before switching context.

## What agents must never do without an assigned AI reviewer's APPROVE

- Merge to `main`/`master`.
- Force-push (`git push --force`).
- Delete branches.
- Rewrite published history.

An *assigned AI reviewer* is a rotation reviewer run through `ai-review` (or the
shared-db allocator) whose engine differs from the implementing session's; the
implementing session never approves its own change.
