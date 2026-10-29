---
name: ai-development-pipeline
description: >-
  Run a code change through the governed seven-stage plan, review,
  implementation, test, security, and final-review workflow. Use when a task
  needs the complete multi-model pipeline rather than one isolated review.
disable-model-invocation: true
---

# AI Development Pipeline

Use the repository's deterministic orchestrator. It owns artifact identity,
source freshness, resume behavior, and the approval gates; do not reproduce the
seven stages manually.

## Run

From the target Git repository:

```bash
run_dir="$(ai-run-task start "Exact user request")"
ai-run-task run "$run_dir"
ai-run-task status "$run_dir"
```

Use `ai-run-task resume "$run_dir"` only when a failed attempt left the source
digest unchanged. The command verifies every completed output hash before it
skips anything. If it reports external source drift, a changed artifact, or a
failed write stage that changed source, start a new evidence generation instead
of forcing resume.

## Roles and boundaries

- Codex / GPT-5.6 at medium reasoning plans in a read-only sandbox, then owns
  implementation and testing in an explicit workspace-write sandbox.
- A registered pool reviewer (default Muse) independently reviews the plan, diff,
  security, and final state. Claude is out of the reviewer pool and is never the
  reviewer.
- Review is advice only (owner ruling 2026-10-29): a `REJECT` or `REVISE`
  finding is fixed or answered with evidence; it never needs an approval to
  continue. A source change or lifecycle-accounting failure still stops later
  stages.

The run manifest under `.ai/runs/` is the durable record. Each stage consumes
the prior named artifact, records its hashes and source digest, and publishes a
new immutable output. Do not edit completed run artifacts.

Normal Git, deployment, authorization, and production rules still apply after
the pipeline completes; the pipeline does not grant permission to push, merge,
or deploy.
