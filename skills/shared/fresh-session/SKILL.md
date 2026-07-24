---
name: fresh-session
description: >-
  "Fresh session?" — decide whether the work should cut over to a NEW AI session
  with a clean context window between phases/steps of a plan, and if so, verify
  the handoff is airtight for a fresh agent. Use when the user asks "fresh
  session?", "should this be a new session?", "new context window?", "is the
  context window getting full?", "hand this phase over to a new agent", or is
  between phases of a multi-phase plan and wondering whether to continue here or
  cut over. Owns the go/no-go decision and whole-plan (all remaining phases)
  comprehensiveness scope; delegates the actual handoff document to
  handoff-writer instead of duplicating it.
---

# fresh-session

Albert works across many short sessions with clean context windows. The moment
between phases of a plan is where a session either cuts over cleanly or drags a
bloated context forward and starts making mistakes. This skill owns that decision
and the *forward-looking* comprehensiveness check. It does **not** re-implement
handoff writing — for that it hands off to `handoff-writer`.

## What this skill adds over `handoff-writer`

`handoff-writer` writes/judges a fresh-developer-grade handoff for the work *in
flight*. This skill wraps three things around it that it does not do:

1. **The go/no-go decision** — should this even be a new session?
2. **Whole-plan scope** — grade against **every remaining phase to plan-end**,
   not just the next one.
3. **The reciprocal spec check** — confirm the outgoing phase spec tells the
   implementing agent to re-read all downstream phases when it finishes.

## Step 1 — Decide: fresh session, or keep going?

Answer plainly and recommend one. Favor a fresh session when any hold:

- The context window is genuinely large / degrading, or the session is long.
- A phase just completed and the next phase is largely independent work.
- The remaining work is well-specified in a plan `.md` (so a clean agent can
  execute it without this session's in-head context).

Favor continuing here when the next step is small, tightly coupled to what just
happened, or depends on live in-context state that isn't worth writing down. If
you recommend continuing, say so and stop — no handoff needed.

## Step 2 — Scope the comprehensiveness check to the WHOLE plan

If cutting over, the handoff + the plan `.md` together must let a clean agent
execute the handed phase **and** everything after it. Read the plan `.md` end to
end and confirm, for **every remaining phase through the last one** (not just the
next step):

- Nothing this session did changes a downstream phase's assumptions without that
  being written down (schema, file layout, interfaces, decisions, renamed things).
- Nothing this session *discovered* invalidates a later phase's approach without
  it being flagged.
- Every later phase still has the context, identifiers, and decisions it needs.

Anything that fails → fix it in the handoff and/or the plan `.md` before cutover.

## Step 3 — Verify the reciprocal end-of-phase instruction

The outgoing phase spec MUST instruct the implementing agent to, **at the end of
its phase, re-read all downstream phases (to plan-end) and report any drift** —
anything it did or learned that affects a later phase. If that instruction is
missing from the spec, add it. (Authoring of this rule lives in the plan step;
here you verify it survived into the spec being handed over.)

## Step 4 — Delegate the document to the handoff standard

Do NOT re-implement the handoff structure, checklist, or self-audit gate here —
delegate to the canonical standard and pass it the widened scope from Steps 2–3
(whole-plan, plus the reciprocal-instruction requirement):

- **In Claude:** invoke the `handoff-writer` skill.
- **In Codex (or if `handoff-writer` isn't installed):** apply the canonical
  cross-tool standard at `templates/system/handoff-standard.md` in the
  `ai-devops` repo — the same 9 sections + self-audit gate `handoff-writer`
  wraps.

Either way, the answer to "is it comprehensive?" must be a truthful **Yes**
before cutover.

## Output

State the decision (fresh session / continue) with the one-line reason. If fresh:
confirm the whole-plan scope passed, the reciprocal instruction is present, and
`handoff-writer`'s self-audit passed — then give Albert the exact next-session
starting prompt.
