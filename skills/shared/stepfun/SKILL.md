---
name: stepfun
description: Use StepFun Step 5 (step-5-preview) through ai-stepfun on Ubuntu/Linux only. Formal reviews with a VERDICT line and second opinions (both may run code and edit files in a disposable remote-less copy), and implementation runs that write and execute code in an isolated remote-less clone. Use for "ask StepFun", "StepFun review", "Step 5", "have StepFun implement this", or a StepFun second opinion. Not available on Windows.
---

# stepfun

StepFun Step 5 runs through the StepCode CLI (`step`), wrapped by
`ai-stepfun`. Owner instruction 2026-09-25: add it as a reviewer on Ubuntu only,
and let it write, implement, and execute code.

## Platform

Ubuntu/Linux only. StepCode is not yet available on Windows, so `ai-stepfun`
exits 2 with `unsupported-platform` there and `ai-review-preflight status
stepfun` reports `unsupported-platform`. On Windows, pick another reviewer; do
not try to install or emulate StepCode.

## Sandbox

Every StepFun turn runs under bubblewrap: the model sees only its own folder,
with an empty home, /tmp and /run and a cleared environment (no SSH keys or
agent, git or gh logins, 1Password token, or Docker socket). If
`bwrap` is missing, `ai-stepfun` refuses to run; install it with
`sudo apt-get install bubblewrap`.

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

`stepfun` is in the shared-db rotation on Ubuntu/Linux. The allocator checks
local preflight before a draw, so Windows excludes it as unsupported. Drawing
other reviewers, including StepFun, before Grok is owner policy (shared-db issue
#3592) that takes effect only when shared-db PR #3593 lands.

## Failures

- Exit 92 with `AI_REVIEWER_OUT_OF_CREDIT provider=stepfun`: the StepFun
  account needs credit at https://platform.stepfun.ai. Tell Albert in the same
  reply, then use another reviewer.
- HTTP 429 `rate_limited`: the account tier allows about 10 requests a minute.
  Reviews retry automatically; do not run several StepFun jobs at once.
- Missing key store: run `ai-stepfun store-key` (reads 1Password item
  `stepfun step5 ai api key` once; reviews never call 1Password).
- Health: `ai-stepfun doctor --live`.
