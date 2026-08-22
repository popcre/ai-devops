# Repo Onboarding (future / manual)

How to bring an existing application repo into the AI DevOps workflow. This is a
**manual, opt-in** process — the toolkit never modifies your application repos
automatically.

> Not automated yet. This document describes the intended steps; a helper script
> may be added later.

## Prerequisites

- The toolkit is installed (`ai-devops doctor` is green).
- You are logged in to `gh`, `claude`, and `codex`.

## Steps to onboard a repo

1. **Clone / locate** the app repo under `/worksp/<repo>`.

2. **Add the workflow docs.** Copy the relevant templates from
   `templates/repo-docs/` into the app repo (e.g. into its `docs/`):
   - `docs-ai-agent-roles.md`
   - `docs-ai-branching.md`
   - `docs-ai-completion-report.md`
   - `docs-ai-visual-testing.md`

3. **Append the agent add-ons.** Merge the contents of:
   - `templates/repo-docs/CLAUDE.addon.md` → the repo's `CLAUDE.md`
   - `templates/repo-docs/AGENTS.addon.md` → the repo's `AGENTS.md`

4. **Add `.ai/` to the repo's `.gitignore`** if you don't want run/review
   artifacts committed:
   ```
   .ai/runs/
   .ai/tmp/
   .ai/reviews/
   ```

5. **Sanity check** from inside the repo:
   ```bash
   ai-workspace-status
   ```

6. **Try a dry run** of the task scaffold (does not edit code):
   ```bash
   ai-run-task start "Describe a small first task"
   ```

## What onboarding does NOT do

- It does not change application code.
- It does not commit anything on your behalf.
- It does not push, merge, or open PRs.

## Later

A future `ai-onboard-repo` helper may automate steps 2–4. For now, do them by
hand and review the diff before committing.
