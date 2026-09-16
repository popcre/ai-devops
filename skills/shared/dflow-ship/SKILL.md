---
name: dflow-ship
description: Shared Claude and Codex DesignFlow PLM ship step — test, commit, push, PR to develop, verify the sandbox Cloud Build deploy. Use for a pure ship request ("push and commit", "commit and push", "update the PR for my branch sandbox-albert with develop", "is everything pushed and committed?") WHEN WORKING IN A DFLOW REPO (the six popcre designflow-* repos on branch sandbox-albert / albert-2sandbox). For the hetz/Coolify apps (poppim-web, popcrm-web, popdam3, monitor, hiclaw) use `deploy-and-verify` instead. This is NOT the session closer — it does not update docs, sweep secrets, or write a handoff; for "wrap up"/"close out"/"end of session" use `wrap-up`, which detects the repository and delegates its ship step here.
---

# dflow-ship

Commit → push → PR → deploy-verify for DesignFlow PLM. Albert typed a variant of
this at the end of nearly every dflow session.

## ⚠️ Routing guard — read first

This skill is **only the ship step**. It does NOT update the `.md` docs.
If the user's message contains **"wrap up"**, **"wrap it up"**, **"close out"**,
or **"end of session"** (e.g. "dflow wrap up"), STOP — this is the wrong skill.
Run the **`wrap-up`** skill instead: it updates the docs FIRST, sweeps secrets,
verifies handoff-safe state, and then calls this skill for the ship step. Only
proceed here for a pure ship request ("push and commit", "is everything pushed?").

## Trigger phrases

**Only when the working copy is a dflow repo** (`popcre/designflow-*`, branch
`sandbox-albert` / `albert-2sandbox`). If it's a hetz/Coolify app repo
(poppim-web, popcrm-web, popdam3, monitor, hiclaw), use `deploy-and-verify`
instead — same phrases, different pipeline. When in doubt, check `git remote -v`.

- "push and commit" / "commit and push to github.com"
- "Create a new PR for this for my branch sandbox-albert with develop branch, or update it if one exists"
- "is everything pushed and committed?"

## Procedure

1. **Test first.** Run unit tests for every repo you touched. For the Angular
   **frontend** also run the AOT/sandbox build (the Node backend repos have no
   AOT build). Fix failures before shipping — never ship red.
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
   verify the exact user flow in Playwright or a controlled browser and capture
   the changed screen. Assert meaningful page content, not only a route change
   or visible wrapper. For routed detail pages, verify a stable heading or body
   section renders, no blank page appears, and the browser has no relevant
   console errors, page errors, failed API responses, or error-toast text.
   Compare the result against the requirement before declaring success.
7. **Report** in plain English: commit SHAs, PR URLs, deploy status, and what
   was visually verified. Never report "done" on evidence you didn't collect.

## Follow-ups (mandatory at session end)

- **Run the installed client documentation skill** (`session-docs-update` on
  Claude; `codex-docs-update` on Codex) — do not merely offer it. The skill
  itself decides what needs updating and says so if nothing durable changed, so
  running it is always safe. Skipping docs is the #1 recurring wrap-up failure.
- If the session touched the shared backend, run the installed shared-database
  skill (`shared-db-change` on Claude; `codex-shared-db-change` on Codex).
