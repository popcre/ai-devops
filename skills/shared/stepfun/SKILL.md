---
name: stepfun
description: "StepFun Step 5 (step-5-preview) via ai-stepfun: reviews with a VERDICT line, second opinions, and isolated implementation runs. Use for \"ask StepFun\", \"StepFun review\", \"Step 5\", \"have StepFun implement this\", or a StepFun second opinion."
---

# stepfun

StepFun Step 5 runs through `ai-stepfun`, a thin entry to
`bin/ai-second-opinion stepfun`: the same pinned OpenCode path and provider
definition the advisory CI reviewer uses, on Linux and Windows. Review is
advice only (owner ruling 2026-10-29, #2104).

Every call runs on a private copy of the repository (HEAD plus uncommitted
changes, no git remote); your checkout is never touched.

```bash
ai-stepfun doctor [--live]
ai-stepfun review --repo . --base origin/main --prompt-file brief.md
ai-stepfun ask "Is this retry loop bounded?"
ai-stepfun implement <name> --prompt-file task.md   # private writable copy; prints the diff
ai-stepfun diff <name> | git apply
ai-stepfun list | show <name> | transcript <name> | delete <name>
ai-stepfun store-key [--if-missing]                 # installer use: key from 1Password
```

StepFun's account allows about 10 requests a minute; keep calls few. Exit code
3 means StepFun was unavailable; use another second-opinion tool instead of
retrying in a loop. The implementer edits files but cannot run commands, so run
the tests yourself after applying its diff.
