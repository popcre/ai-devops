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

## Brief content — the other model gets nothing but this

StepFun starts with **zero knowledge of this session**: no chat history, no
memory, no prior turns, and no files unless you point at them. Anything you
leave out of the brief, it does not know. A thin brief produces a confident
answer to a question you did not ask.

Standard: **a stranger who walked in this morning could make the right call
from the brief alone.** If a fact shaped your own thinking, it belongs in the
brief. Never write "as discussed", "the usual setup", or "you know the
context".

Every brief carries all of this, every time:

- **Background** — what the work is, why it is happening, what led to this
  question, and every prior decision, owner ruling, constraint, or incident
  that bears on the answer.
- **The material** — the plan, design, diff, diagnosis, config, or error being
  judged. Name exact paths, functions, commits, and error text; never "the
  relevant file". Attach long artifacts or point at repository paths StepFun
  can read. Put in full anything it cannot read for itself.
- **The question** — the one thing to judge or decide, stated sharply.
- **Constraints** — scope limits, what must not change, and the compatibility
  or safety rules that govern the answer.
- **Required output** — the verdict or artifact, the evidence to return, and
  anything to flag as uncertain or unassessable from what was supplied.

Never put a secret, token, connection string, credential, or `.env` value in a
brief. Point at facts, not credentials.

StepFun's account allows about 10 requests a minute; keep calls few. Exit code
3 means StepFun was unavailable; use another second-opinion tool instead of
retrying in a loop. The implementer edits files but cannot run commands, so run
the tests yourself after applying its diff.
