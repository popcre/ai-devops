---
name: ask-glm
description: "GLM-5.3 second opinion; never reviews GLM-orchestrated (ZCode) work. Analysis, review, debate, second opinion, or scoped implementation through `ai-glm`. Use for \"ask GLM\", \"run this by GLM\", \"get GLM's opinion\", GLM-5.3, or delegating repository work to GLM."
---

# Ask GLM

GLM-5.3 gives second opinions, debates and small delegated changes. Review is
advice only (owner ruling 2026-10-29, #2104): nothing waits on GLM. The
2026-09-17 independence ruling still binds: GLM never reviews GLM-orchestrated
(ZCode) work.

`ai-glm` is a thin entry to `bin/ai-second-opinion glm`, the same OpenCode path
and provider definition the advisory CI reviewer uses. Every call runs on a
private copy of the repository (HEAD plus uncommitted changes, no git remote);
your checkout is never touched.

```bash
ai-glm doctor [--live]                         # key and OpenCode present; --live makes one tiny call
ai-glm ask "Is this retry loop bounded?"       # one-shot question about the current repo
ai-glm new <name> --prompt-file "$brief"       # start a named read-only session
ai-glm ask <name> --prompt-file "$next"        # continue that same session
ai-glm review --repo . --base origin/main      # review the diff; ends with a VERDICT line
ai-glm implement <name> --prompt-file "$task"  # edits in a private writable copy; prints the diff
ai-glm diff <name> | git apply                 # take the implementation into your checkout
ai-glm list | show <name> | transcript <name> | abort <name> | delete <name>
```

## Brief content — the other model gets nothing but this

GLM starts with **zero knowledge of this session**: no chat history, no memory,
no prior turns, and no files unless you point at them. Anything you leave out
of the brief, it does not know. A thin brief produces a confident answer to a
question you did not ask.

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
  relevant file". Attach long artifacts or point at repository paths GLM can
  read. Put in full anything it cannot read for itself.
- **The question** — the one thing to judge or decide, stated sharply.
- **Constraints** — scope limits, what must not change, and the compatibility
  or safety rules that govern the answer.
- **Required output** — the verdict or artifact, the evidence to return, and
  anything to flag as uncertain or unassessable from what was supplied.

Never put a secret, token, connection string, credential, or `.env` value in a
brief. Point at facts, not credentials.

Write briefs with the shared debate template
`templates/delegation/debate-turn.md` when you disagree and want GLM to argue
back. Report GLM's view in your own words, say whether you agree, and push back
with evidence when you do not.

Exit code 3 means GLM was unavailable (no key, out of credit, timeout or an
empty answer); try another second-opinion tool rather than retrying in a loop.
The implementer can edit files but cannot run commands: run the tests yourself
after applying its diff.
