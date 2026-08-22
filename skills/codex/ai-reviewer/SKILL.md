---
name: ai-reviewer
description: >-
  Run a read-only Codex second-opinion review (plan, diff, security, visual, or
  final-check) on the current git repo and save the result under .ai/reviews/.
  Use when the user wants Codex to independently review work without changing any
  files.
---

# AI Reviewer (Codex)

Read-only second-opinion reviews from Codex, wrapping the toolkit's
`ai-codex-review` command. Reviews **never** edit, commit, push, merge, or
delete anything.

> Status: fail-closed reviewer lifecycle.

## When to use

- The user wants an independent Codex review of a plan, a diff, security, visual
  impact, or overall readiness.
- The user explicitly wants a **read-only** pass (no code changes).

## Modes

Run from inside the target git repo:

```bash
ai-codex-review plan-review       # review the current plan
ai-codex-review diff-review       # review the current git diff
ai-codex-review security-review   # security-only review of the diff
ai-codex-review visual-review     # UI/visual-testing considerations
ai-codex-review final-check       # go/no-go readiness check
```

Each run:

- requires `.ai/reviews/` to be Git-ignored and physically contained,
- creates a disposable complete snapshot, including untracked and binary files,
- seals and verifies an exact evidence packet and whole-source digest,
- saves output under a collision-proof run identity,
- prints the saved file path,
- uses `CODEX_CMD` from `/etc/ai-devops/models.env`
  (default includes `--sandbox read-only` and medium reasoning), and
- returns nonzero unless Codex succeeds, the snapshot remains unchanged, an
  exact verdict is present, the source is still current, and lifecycle/
  scoreboard accounting completes.

## Guardrails

- Must be inside a git repo.
- Read-only is enforced by the Codex sandbox and verified again by hashing the
  private snapshot after the provider returns.
- The complete review-visible source is in scope. Never start this command in a
  repository whose untracked files contain credentials or other material that
  must not be sent to the configured model.

## Relationship to the pipeline

This skill covers the Opus/Codex review gates (Stages 02, 04, 06, plus visual and
final checks) of the `ai-development-pipeline` skill, but as an independent Codex
opinion rather than the primary Opus review.
