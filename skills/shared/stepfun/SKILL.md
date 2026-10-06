---
name: stepfun
description: Use StepFun Step 5 (step-5-preview) through ai-stepfun. Formal reviews with a VERDICT line and second opinions (both may run code and edit files in a disposable remote-less copy), and implementation runs that write and execute code in an isolated remote-less clone. Allocator rotation reviewer (shared-db#3657). Linux runs StepCode or OpenCode under bubblewrap; Windows runs review/ask through the OpenCode folder + test shell, and implement is refused there. Use for "ask StepFun", "StepFun review", "Step 5", "have StepFun implement this", or a StepFun second opinion.
---

# stepfun

StepFun Step 5 runs through `ai-stepfun`. On Ubuntu/Linux where StepCode is
installed it uses the StepCode CLI (`step`); otherwise the pinned OpenCode
harness (the same binary GLM, Muse, and DeepSeek use). Both run under
bubblewrap. Owner instruction 2026-09-25: let it write,
implement, and execute code. Owner instruction 2026-09-28 (#974): reviewers are
not read-only.

## Platform

Linux (owner instruction 2026-09-25): bubblewrap plus StepCode or the OpenCode
harness (#1086). Windows (owner instruction 2026-09-30): `review` and `ask` run
through the pinned OpenCode engine in a disposable folder with a gated test
shell; `implement` is refused there.
The Windows shell permits in-folder `ls`/`cat`, `head -n N` for 1–200 lines,
and `grep -n -F` for up to 200 literal matches. Windows file tools remain
disabled; the runner binaries are hash-pinned.

## Sandbox

Every turn runs against a disposable, remote-less copy or clone. StepCode turns
additionally run under bubblewrap: the model sees only its own folder, with an
empty home, /tmp and /run and a cleared environment; OpenCode turns on Linux get the
same sandbox. Windows turns are not mount-isolated: see the owner-accepted
Windows residual in `docs/reviewer-rotation-rules.md` rule 12. OpenCode turns run against
the same disposable copy with a per-run profile and the key exported only into
the child environment.

## Commands

```bash
# Formal review: read, shell, edit and write tools in a disposable
# remote-less copy (edits discarded, never part of the PR), ends in
# "VERDICT: APPROVE|REVISE|REJECT <head sha>"
ai-stepfun review --repo . --base origin/main --prompt-file brief.md

# Second opinion, same disposable writable copy
ai-stepfun ask --repo . "Is this retry loop bounded?"

# Implementation: StepFun may read, edit, write, and run commands, in a NEW
# remote-less clone on branch stepfun/impl-<id>. A run that commits or adds a
# remote is refused.
ai-stepfun implement --repo . --prompt-file task.md
```

- Reviews and `ask` are not read-only (owner instruction, #974): StepFun may
  run builds and tests and edit files, but only in a disposable, remote-less
  copy that is thrown away. The caller's checkout is checked unchanged and the
  answer is rejected if it moved. Keeping changes is `implement`'s job.
- After `implement`, inspect the diff in the printed `CLONE` folder, run the tests
  yourself, and only then carry the change into your own branch. StepFun's
  output is work to verify, not a finished change.
- Delete the clone folder when you are done with it.

## Membership

`stepfun` is registered in `config/reviewer-registry.json` and is an active
shared-db allocator reviewer (shared-db#3657). The allocator draws it only on a
machine where `ai-review-preflight usable stepfun` passes. Also use it when
Albert asks for StepFun.

## Failures

- Exit 92 with `AI_REVIEWER_OUT_OF_CREDIT provider=stepfun`: the StepFun
  account needs credit at https://platform.stepfun.ai. Tell Albert in the same
  reply, then use another reviewer.
- HTTP 429 `rate_limited`: the account tier allows about 10 requests a minute.
  Reviews retry automatically; do not run several StepFun jobs at once.
- Missing key store: run `ai-stepfun store-key` (reads 1Password item
  `stepfun step5 ai api key` once; reviews never call 1Password).
- Health: `ai-stepfun doctor --live`.
