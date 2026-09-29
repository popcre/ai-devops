---
name: stepfun
description: Use StepFun Step 5 (step-5-preview) through ai-stepfun. Formal reviews with a VERDICT line and second opinions (both may run code and edit files in a disposable remote-less copy), and implementation runs that write and execute code in an isolated remote-less clone. Windows runs through OpenCode; Ubuntu runs through StepCode. Use for "ask StepFun", "StepFun review", "Step 5", "have StepFun implement this", or a StepFun second opinion.
---

# stepfun

StepFun Step 5 runs through `ai-stepfun`. On Ubuntu/Linux where StepCode is
installed it uses the StepCode CLI (`step`) under bubblewrap. On Windows (and
any host without StepCode) it uses the pinned OpenCode harness — the same
binary GLM, Muse, and DeepSeek use. Owner instruction 2026-09-25: let it write,
implement, and execute code. Owner instruction 2026-09-28 (#974): reviewers are
not read-only.

## Platform

Windows and Ubuntu/Linux. On Windows, run `bin\setup-opencode-stepfun.ps1` once
to install OpenCode and the `ai-stepfun` command. On Ubuntu, install StepCode
and bubblewrap, or the OpenCode path works there too.

## Sandbox

Every turn runs against a disposable, remote-less copy or clone. StepCode turns
additionally run under bubblewrap: the model sees only its own folder, with an
empty home, /tmp and /run and a cleared environment. OpenCode turns run against
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

`stepfun` is registered in `config/reviewer-registry.json` and listed as
outside the shared-db allocator: the allocator has no platform awareness, so it
never assigns StepFun. Use it when a session wants a reviewer, or when Albert
asks for StepFun.

## Failures

- Exit 92 with `AI_REVIEWER_OUT_OF_CREDIT provider=stepfun`: the StepFun
  account needs credit at https://platform.stepfun.ai. Tell Albert in the same
  reply, then use another reviewer.
- HTTP 429 `rate_limited`: the account tier allows about 10 requests a minute.
  Reviews retry automatically; do not run several StepFun jobs at once.
- Missing key store: run `ai-stepfun store-key` (reads 1Password item
  `stepfun step5 ai api key` once; reviews never call 1Password).
- Health: `ai-stepfun doctor --live`.
