<!--
  AGENTS.addon.md — paste/append this block into an application repo's AGENTS.md
  (or Codex agent instructions) when onboarding it to the AI DevOps workflow.
  It tells Codex-family agents how to behave in this repo.
-->

## AI DevOps workflow (Codex / GPT-5.6 agents)

This repo is onboarded to the AI DevOps staged workflow. When you act as the
**planning**, **implementation**, or **testing** agent (GPT-5.6 / Codex, medium reasoning):

- Work only from an **approved plan**. If there is no approved plan, ask for one.
- Make the **smallest safe change**. Do not refactor unrelated code.
- Always **add or update tests** for behavior you change.
- Never commit secrets. Never weaken auth or permission checks.
- Never force-push, never delete branches, never merge to `main`/`master`
  without explicit human approval.
- Run on a **feature branch**, never directly on `main`/`master`.
- When done, summarize files changed, tests added, and any plan deviations.

Review stages (plan / diff / security / final) are handled by Opus and are
**read-only** — do not perform edits during a review stage.

Useful commands (from the toolkit):

- `ai-workspace-status` — check branch/dirty/PR safety before you start.
- `ai-codex-review diff-review` — second-opinion review of the current diff.
