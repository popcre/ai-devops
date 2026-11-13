---
name: gemini-code-delegation
description: "FROZEN 2026-10-13 (popcre/ai-devops#1714), best-effort; callable by name. Gemini 3.8 Flash via ai-gemini for an independent review in a disposable copy. Use for ask Gemini, use Gemini, Gemini review, run this by Gemini, or Gemini 3.8 Flash."
---

# Gemini code review

> **FROZEN 2026-10-13** (popcre/ai-devops#1714): best-effort, not maintained.
> The wrapper stays installed and callable by name. The registry marks `gemini`
> absent, so `ai-review gemini` refuses formal dispatch. Do not treat the
> rotation notes below as current membership.

Gemini 3.8 Flash is a governed reviewer again as of 2026-09-06, and may also be
used for an ad-hoc advisory review. It was held out after two live
attempts produced no parseable verdict and a bare `PASS` with an empty report;
it returned only after a recorded live safety qualification and a live review
that produced a well-formed verdict above a substantive report. It is drawable
only while `ai-review-preflight usable gemini` exits zero — the hash-bound
qualification re-quarantines it on any wrapper, runtime, or model drift. Never
add a provider to the registry to make an allocation succeed.

Never call `agy` directly or bypass a quarantine. Check both gates before
assigning work:

```bash
ai-review-preflight usable gemini
```

```bash
AI_GEMINI_CALLER=codex ai-gemini doctor
```

On Windows PowerShell, set the caller as `$env:AI_GEMINI_CALLER='codex'` (or
`claude`) before the command. The bash `VAR=val cmd` prefix is not PowerShell
syntax and leaves the caller unset.

Proceed only when `doctor` reports `PASS` for exact model
`gemini-3.8-flash-high`. If it reports `QUARANTINED`, stop and choose another
governed reviewer until one governed requalification succeeds. An empty answer,
wrong model or conversation, changed protected file, committed or uncommitted
source drift, interruption, or missing durable report is always a failed review.
Gemini is review-only.

## Clean worktree only

The `ai-gemini` packet builder rejects a dirty working tree with
`snapshot-digest-mismatch`. Run every Gemini review from a clean worktree that
matches upstream — never from a canonical checkout that has uncommitted drift
or is behind `origin/main`. Confirm `git status` is clean and the branch is
current before building the packet.

## Check the allowance before a long review

Antigravity meters Gemini on a weekly and a 5-hour bucket. A review that starts
with an empty 5-hour bucket fails partway through and wastes the whole packet,
so check the headroom first. This costs zero tokens and starts no conversation.

```bash
ai-gemini-usage
```

To gate automatically, use the floor and read the exit code: `0` means every
Gemini bucket is above the floor, `3` means one is below it, and `1` means the
allowance could not be read — treat `1` as "unknown", never as headroom.

```bash
ai-gemini-usage --min-percent 15
```

When the 5-hour bucket is low, the output gives the exact UTC refresh time and a
countdown. Wait for that reset or pick another governed reviewer; never retry
into an exhausted bucket.

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
