---
name: handoff-writer
description: Write a fresh-developer-grade handoff document or next-session prompt. Use when the user says "put that plan in handoff.md", "write a fix_*.md", "give me a detailed prompt for the new chat", or "comprehensive enough that a brand new fresh developer would pick up where you left off and not skip a beat".
---

# handoff-writer

Albert works across many short sessions and machines; the handoff doc IS the
memory. His quality bar, stated verbatim many times: *"comprehensive enough that
a brand new fresh developer with no knowledge of this project and no context
into what we did and what's left to do would be able to pick up where you left
off and not skip a beat."*

## Trigger phrases

- "put that plan in handoff.md" / "write a comprehensive handoff.md"
- "write a fix_<topic>.md" (oracle convention: fix_enhancement.md, fix_remove_fallbacks.md, …)
- "give me a very detailed prompt to give another ai session"
- "make a plan so detailed a brand new ai session with no context can execute it flawlessly"
- "this session's context window is getting full"

## Required contents

1. **Problem statement** — what we're solving, in plain English, with the
   business context.
2. **System background** — stack, repos, branches, URLs, where things run.
   Assume zero prior knowledge.
3. **Everything tried and why each attempt failed** — this is the part Albert
   explicitly asks for; it prevents the next session from repeating dead ends.
4. **Root causes found** with `file:line` references.
5. **Exact next steps**, ordered, each with a verification gate ("you'll know it
   worked when …").
6. **Constraints** — standing rules in force (branch policy, no band-aids,
   AG-Grid rules, etc.).
7. **Access** — which CLIs/MCPs are authenticated, where secrets live
   (1Password `vibe_coding` — never the values themselves).
8. **Open questions / risks.**

## Rules

- Write it as a repo file (HANDOFF.md or fix_<topic>.md), commit and push it —
  a handoff that only exists in chat is lost.
- No placeholders the reader must fill in; no unexplained jargon.
- For infra decisions (e.g. "scratch VPS can be deleted"), record the decision
  and its date — a past session contradicted its own earlier advice.
- HANDOFF.md is deleted only when the work it describes is truly complete.
