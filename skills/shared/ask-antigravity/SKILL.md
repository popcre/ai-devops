---
name: ask-antigravity
description: "Antigravity + Gemini (gemini-4-neon-medium) second opinion, review, debate, or scoped implementation through `ai-antigravity`. Use for \"ask Antigravity\", \"ask Gemini\", \"run this by Gemini\", \"run this by Antigravity\", \"Antigravity review\", \"Gemini review\", \"Gemini second opinion\", or delegating repository work to Antigravity/Gemini."
---

# Ask Antigravity (Gemini)

Google Antigravity (`agy`) with Gemini (`gemini-4-neon-medium` by default;
override with `AI_ANTIGRAVITY_MODEL`) gives second opinions, debates, reviews,
and small delegated changes. Review is advice only (owner ruling 2026-10-29,
#2104): nothing waits on Antigravity/Gemini.

`ai-antigravity` is a thin entry to `bin/ai-second-opinion antigravity`, the
same `agy` path the advisory GitHub CI reviewer (`ai-review-simple`) uses, on
Linux and Windows. Every call runs on a private copy of the repository (HEAD
plus uncommitted changes, no git remote); your checkout is never touched. Named
sessions keep their conversation via `agy --conversation`.

```bash
ai-antigravity doctor [--live]                         # agy CLI present; --live makes one tiny call
ai-antigravity ask "Is this retry loop bounded?"       # one-shot read-only question about the current repo
ai-antigravity new <name> --prompt-file "$brief"       # start a named read-only session
ai-antigravity ask <name> --prompt-file "$next"        # continue that same session
ai-antigravity review --repo . --base origin/main      # review the diff; ends with a VERDICT line
ai-antigravity implement <name> --prompt-file "$task"  # edits in a private writable copy; prints the diff
ai-antigravity diff <name> | git apply                 # take the implementation into your checkout
ai-antigravity list | show <name> | transcript <name> | abort <name> | delete <name>
```

## Brief content — the other model gets nothing but this

Gemini starts with **zero knowledge of this session**: no chat history, no
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
  relevant file". Attach long artifacts or point at repository paths Gemini can
  read. Put in full anything it cannot read for itself.
- **The question** — the one thing to judge or decide, stated sharply.
- **Constraints** — scope limits, what must not change, and the compatibility
  or safety rules that govern the answer.
- **Required output** — the verdict or artifact, the evidence to return, and
  anything to flag as uncertain or unassessable from what was supplied.

Never put a secret, token, connection string, credential, or `.env` value in a
brief. Point at facts, not credentials.

Write briefs with the shared debate template
`templates/delegation/debate-turn.md` when you disagree and want Gemini to
argue back. Report Gemini's view in your own words, say whether you agree, and
push back with evidence when you do not.

Exit code 3 means Antigravity/Gemini was unavailable (`agy` missing, not signed
in, quota exhausted, timeout, or an empty answer); try another second-opinion
tool rather than retrying in a loop. Always run the tests yourself after
applying an `implement` diff.
