---
name: ask-codex
description: "Codex (GPT-5.x) second opinion, debate, review, or scoped implementation through `ai-codex`; debates by default. Use for \"ask Codex\", \"run this by codex\", \"what does codex think\", \"get a second opinion\", \"see if codex agrees\", \"push back and see if it changes its mind\", \"Codex review\", or a small delegated change. Long autonomous build/run/prove work goes to codex-handoff."
---

# Ask Codex

Codex (the OpenAI Codex CLI, GPT-5.x) gives second opinions, debates, reviews
and small delegated changes. Review is advice only (owner ruling 2026-10-29,
#2104): nothing waits on Codex. Codex is a genuinely independent engine with a
clean context, so it is the best check on Claude's reasoning, but only if the
debate below is run honestly.

`ai-codex` is a thin entry to `bin/ai-second-opinion codex`, the same session,
private-copy and verdict machinery as `ai-glm`, `ai-muse` and
`ai-antigravity`. Every call runs on a private copy of the repository (HEAD
plus uncommitted changes, no git remote); your checkout is never touched.
Read-only calls run Codex's `read-only` sandbox; `implement` runs
`workspace-write` inside the private writable copy. Named sessions continue the
same Codex thread (`codex exec resume`). Codex is not a CI reviewer.

```bash
ai-codex doctor [--live]                         # codex CLI present; --live makes one tiny call
ai-codex ask "Is this retry loop bounded?"       # one-shot read-only question about the current repo
ai-codex new <name> --prompt-file "$brief"       # start a named read-only session
ai-codex ask <name> --prompt-file "$next"        # continue that same thread
ai-codex review --repo . --base origin/main      # review the diff; ends with a VERDICT line
ai-codex implement <name> --prompt-file "$task"  # edits in a private writable copy; prints the diff
ai-codex diff <name> | git apply                 # take the implementation into your checkout
ai-codex list | show <name> | transcript <name> | abort <name> | delete <name>
```

Reasoning effort: the standing rule is `low` by default, `medium` allowed,
never `high` or `none`. Set `AI_CODEX_EFFORT=medium` for judgement work such as
a debate; `AI_CODEX_MODEL` overrides the model. Sign-in is the Codex CLI's own;
there is no key to store.

## Debate is the default

Every opinion, review, or second opinion is a **debate**, not a lookup, unless
the user asks only for a one-line fact or for `implement`. Two models agreeing
because the second anchored on the first is worth nothing; the value is real
independence, then real argument.

1. **Commit to your own position first.** Before Codex sees anything, write
   your claim, reasoning, confidence, and what would change your mind to
   `<scratchpad>/claude-position.md`. With no real position, say so plainly:
   "I have no independent read; Codex's answer stands unopposed."
2. **Send the brief plus your position**, labelled as one input to weigh and
   *not* the expected answer. Tell Codex to reason from the material first
   and say plainly if you are wrong. State that this is read-only.
   `ai-codex new <name> --prompt-file "$brief"`
3. **Report two separate things:** what Codex said, faithfully (keep the
   parts that hurt your position), then whether you agree, point by point. If
   it changed your mind, say so and stop.
4. **Rebut only real disagreement**, in the same session so it argues with its
   own reasoning: `ai-codex ask <name> --prompt-file "$rebuttal"`. Name the claim you reject, give the evidence it
   lacked, and ask whether that changes its verdict; tell it not to split the
   difference to be agreeable. Use `templates/delegation/debate-turn.md` for
   the turn. **Cap at two rounds.**
5. **Close with one verdict:** *Agreed* (note when it merely confirmed),
   *Codex conceded*, *Claude conceded* (and what moved you), or *Still split*
   with the crux and what would settle it. Then recommend what to do.

Never read Codex's answer before writing your position, fold because it
sounds confident, soften its disagreement, run a debate with write access, or
report "we agree" when you are still split.

## Brief content — the other model gets nothing but this

Codex starts with **zero knowledge of this session**: no chat history, no memory,
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
  relevant file". Attach long artifacts or point at repository paths Codex can
  read. Put in full anything it cannot read for itself.
- **The question** — the one thing to judge or decide, stated sharply.
- **Constraints** — scope limits, what must not change, and the compatibility
  or safety rules that govern the answer.
- **Required output** — the verdict or artifact, the evidence to return, and
  anything to flag as uncertain or unassessable from what was supplied.

Never put a secret, token, connection string, credential, or `.env` value in a
brief. Point at facts, not credentials.

Exit code 3 means Codex was unavailable (not signed in, usage limit, timeout,
or no answer); use another second-opinion tool rather than retrying in a loop.
The implementer can run commands only inside its sandboxed private copy: apply
its diff, then run the tests yourself.
