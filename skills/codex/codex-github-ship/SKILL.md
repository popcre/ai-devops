---
name: codex-github-ship
description: Sync, commit, push, PR, and verify GitHub/deploy state from Codex. Use when the user says "push and commit", "commit and push", "sync this repo with github.com", "pull the latest repo from github.com", "is everything pushed and committed?", or asks why the live site still has an old commit.
---

# Codex GitHub Ship

This captures the repeated "push and commit" and "sync with github.com" ritual.
Always adapt to the repo's `AGENTS.md` branch rules before touching git.

## Start

1. Read `AGENTS.md` and any `HANDOFF.md`.
2. State the target repo and branch before merge, commit, or push.
3. Check for user/concurrent-session work with `git status --short --branch`.
   Do not overwrite unrelated changes.

## Sync Rules

- **Default u2giants apps:** main-only. Pull/rebase from `origin/main`, resolve
  conflicts deliberately, then commit and push to `main`.
- **dflow/popcre repos:** work only on `sandbox-albert` or `albert-2sandbox`.
  First update the sandbox branch from `develop` on GitHub, then pull that
  sandbox branch locally. Create or update a PR to `develop`; never self-merge.
- **shared-db:** use branch and PR unless the repo says otherwise.

## Ship

1. Run checks for touched code before commit: lint/typecheck/tests/build, plus
   visual verification for UI changes.
2. Commit focused changes with Albert's configured author.
3. Push and verify the pushed commit exists on the remote branch.
4. For PR repos, create or update the PR and include the verification summary.
5. For deployed apps, watch CI/deploy and verify the live commit by the repo's
   documented mechanism. For hetz/Coolify apps, use the known live HTML
   `build-sha` check instead of trusting `version.json`.

## Report

Report branch, commit SHA, push/PR URL, checks, deploy/live SHA, and any
remaining risk. If the live app still shows an old commit, keep investigating
the CI/image/deploy chain; do not stop at "push succeeded."
