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
- Claude Opus 5 independently reviews the plan, diff, security, and final state
  with only Read, Grep, and Glob in a complete disposable snapshot.
- `ai-review claude ...` and `ai-review codex ...` are the only approval-capable
  front doors. Other model wrappers are advisory or quarantined and cannot
  replace a required approval.
- Any `REJECT`, `BLOCKED`, missing verdict, provider failure, source change, or
  lifecycle-accounting failure stops later stages.

The run manifest under `.ai/runs/` is the durable record. Each stage consumes
the prior named artifact, records its hashes and source digest, and publishes a
new immutable output. Do not edit completed run artifacts.

Normal Git, deployment, authorization, and production rules still apply after
the pipeline completes; the pipeline does not grant permission to push, merge,
or deploy.
