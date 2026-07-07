---
name: handoff-writer
description: Write a fresh-developer-grade handoff document or next-session prompt. Use when the user says "put that plan in handoff.md", "write a fix_*.md", "give me a detailed prompt for the new chat", "wrap up", or "comprehensive enough that a brand new fresh developer would pick up where you left off and not skip a beat". Handoffs must pass a mandatory self-audit before being shown.
---

# handoff-writer

Albert works across many short sessions with clean context windows; the handoff
IS the memory. Skimpy handoffs are his #1 recurring pain — they force him to
stay in long sessions and to repeat the pushback *"is this comprehensive enough
for a brand new fresh developer who would pick up where you left off and not
skip a beat?"* This skill exists so he NEVER has to ask that again: you answer
it yourself, before showing him anything.

## Trigger phrases

- "put that plan in handoff.md" / "write a comprehensive handoff.md"
- "write a fix_<topic>.md"
- "give me a very detailed prompt to give another ai session"
- "this session's context window is getting full"
- any "wrap up" / end-of-session handoff

## The standard (follow it exactly)

Write the handoff per [handoff-standard.md](../../../templates/system/handoff-standard.md)
— the canonical standard. Non-negotiables:

- **Write for a stranger who walked in off the street this morning**: zero
  knowledge of the app, the session, this chat, or what failed. Default to too
  much; too-long costs minutes, too-short costs Albert a whole session.
- Use the 9-section structure (what the app is → goal → current state →
  **what we tried that failed** → root causes → exact next steps → constraints
  → access → open questions). Never drop a section silently.
- The "what we tried that did NOT work" section is mandatory and most-skipped —
  include every dead end and why it failed.

## Mandatory self-audit gate

Before presenting the handoff, grade it against the five questions in the
standard (could a street newcomer continue with no questions? as effectively as
you can now? did you include the failures? are next steps concrete + verifiable?
is every term explained?). If any answer is "no," expand and re-grade. Only then
show it — and state that the self-audit passed.

## Mechanics

- Write to a repo file (HANDOFF.md or fix_<topic>.md), commit and push.
- HANDOFF.md is deleted only when its work is truly complete.
- Record infra/design decisions with dates so a later session can't contradict them.
