---
name: ask-muse
description: Start or continue a persistent protected Muse Spark 1.3 Contributor review, debate, or implementation. Use when the user says "review with Muse", "ask Muse", "debate Muse", "Muse review", "have Muse implement/build/fix X", or requests a Muse Spark second opinion.
---

# Ask Muse

Use `ai-muse` only. Do not call OpenCode, the Meta API, or 1Password directly.
Review is advice only (owner ruling 2026-10-29, #2104).

`ai-muse` is a thin entry to `bin/ai-second-opinion muse`, the same OpenCode
path the advisory CI reviewer uses. Every call runs on a private copy of the
repository (HEAD plus uncommitted changes, no git remote); your checkout is
never touched. Named sessions keep their conversation.

```bash
ai-muse doctor [--live]
ai-muse new <stable-name> --prompt-file <brief-file>
ai-muse ask <stable-name> --prompt-file <follow-up-file>
ai-muse review --repo . --base origin/main [--prompt-file <brief>]
ai-muse implement <name> --prompt-file <brief>    # private writable copy; prints the diff
ai-muse diff <name> | git apply
ai-muse transcript <stable-name>
ai-muse list | show <name> | abort <name> | delete <name>
ai-muse store-key [--if-missing]                  # installer use: key from 1Password to the private store
```

## Debate is the default

Every opinion, review, or second opinion is a **debate**, not a lookup, unless
the user asks only for a one-line fact or for `implement`. Two models agreeing
because the second anchored on the first is worth nothing; the value is real
independence, then real argument.

1. **Commit to your own position first.** Before Muse sees anything, write
   your claim, reasoning, confidence, and what would change your mind to
   `<scratchpad>/claude-position.md`. With no real position, say so plainly:
   "I have no independent read; Muse's answer stands unopposed."
2. **Send the brief plus your position**, labelled as one input to weigh and
   *not* the expected answer. Tell Muse to reason from the material first
   and say plainly if you are wrong. State that this is read-only.
   `ai-muse new <name> --prompt-file <brief-file>`
3. **Report two separate things:** what Muse said, faithfully (keep the
   parts that hurt your position), then whether you agree, point by point. If
   it changed your mind, say so and stop.
4. **Rebut only real disagreement**, in the same session so it argues with its
   own reasoning: `ai-muse ask <name> --prompt-file <rebuttal-file>`. Name the claim you reject, give the evidence it
   lacked, and ask whether that changes its verdict; tell it not to split the
   difference to be agreeable. Use `templates/delegation/debate-turn.md` for
   the turn. **Cap at two rounds.**
5. **Close with one verdict:** *Agreed* (note when it merely confirmed),
   *Muse conceded*, *Claude conceded* (and what moved you), or *Still split*
   with the crux and what would settle it. Then recommend what to do.

Never read Muse's answer before writing your position, fold because it
sounds confident, soften its disagreement, run a debate with write access, or
report "we agree" when you are still split.

## Brief content — the other model gets nothing but this

Muse starts with **zero knowledge of this session**: no chat history, no memory,
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
  relevant file". Attach long artifacts or point at repository paths Muse can
  read. Put in full anything it cannot read for itself.
- **The question** — the one thing to judge or decide, stated sharply.
- **Constraints** — scope limits, what must not change, and the compatibility
  or safety rules that govern the answer.
- **Required output** — the verdict or artifact, the evidence to return, and
  anything to flag as uncertain or unassessable from what was supplied.

Never put a secret, token, connection string, credential, or `.env` value in a
brief. Point at facts, not credentials.

Report Muse's view, say whether you agree, and push back with evidence when
you do not. Exit code 3 means Muse was unavailable; use another second-opinion
tool instead of retrying in a loop. The implementer edits files but cannot run
commands, so run the tests yourself after applying its diff.
