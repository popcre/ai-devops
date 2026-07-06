---
name: dflow-ship
description: DesignFlow PLM end-of-session ship ritual. Use when the user says "push and commit", "commit and push", "update the PR for my branch sandbox-albert with develop", or asks "is everything pushed and committed?". Tests, commits, pushes, creates/updates the PR to develop, and verifies the sandbox deploy.
---

# dflow-ship

Commit → push → PR → deploy-verify for DesignFlow PLM. Albert typed a variant of
this at the end of nearly every dflow session.

## Trigger phrases

- "push and commit" / "commit and push to github.com"
- "Create a new PR for this for my branch sandbox-albert with develop branch, or update it if one exists"
- "is everything pushed and committed?"

## Procedure

1. **Test first.** Run unit tests and the AOT build for every repo you touched.
   Fix failures before shipping — never ship red.
2. **Commit** on the user branch (`sandbox-albert` or `albert-2sandbox`) in each
   affected repo. Author: `Albert Hazan <u2giants@users.noreply.github.com>`.
3. **Push** to origin.
4. **PR:** for each affected repo, `gh pr create` (or `gh pr edit` if one exists)
   from the user branch → `develop`. **Never target `main`. Never merge** — Uma
   (`devopswithkube`) reviews and merges.
5. **Watch the deploy.** Pushing the user branch triggers Cloud Build. Poll it
   in the background (don't make the user ask "did it finish?").
6. **Verify live.** When the build lands, confirm the sandbox site
   (alsand / alsand2 .designflow.app) serves the new commit. For UI changes,
   log in (sandbox email+password are in 1Password, vault `vibe_coding`) and
   screenshot the changed screen; compare against the requirement before
   declaring success.
7. **Report** in plain English: commit SHAs, PR URLs, deploy status, and what
   was visually verified. Never report "done" on evidence you didn't collect.

## Follow-ups

- Offer `session-docs-update` if the session changed durable knowledge.
- If the session touched the shared backend, run `shared-db-change` rules.
