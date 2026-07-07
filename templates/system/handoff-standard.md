# HANDOFF standard — how EVERY session must write a handoff

This is a hard standard, not a suggestion. Albert starts new sessions with clean
context windows and relies on the handoff as the ONLY memory carried forward.
Skimpy handoffs force him to stay in long sessions babysitting — the exact thing
this standard exists to prevent. Applies to Claude AND Codex, every time.

## The mindset (read this first)

Write the handoff for a brand-new developer who **walked in off the street this
morning**. They have:

- NO knowledge of the application or the business it serves
- NO knowledge of what this session was trying to accomplish or why
- NO knowledge of anything discussed in this session
- NO knowledge of what was tried, what failed, or what the dead ends were
- NO access to this chat — when it's gone, it's gone

Your job: make that stranger able to continue **as effectively as you can right
now, with everything you currently know**. If they would have to ask you a
single question to keep going, that question's answer belongs in the handoff.

Default to TOO MUCH. A handoff that is too long costs a few minutes of reading.
A handoff that is too short costs Albert a whole session of rediscovery. These
are not symmetric — always err long.

## Required structure

Use these sections. Never drop one silently — if a section genuinely doesn't
apply, write "N/A" and one line saying why.

```md
# HANDOFF — <topic> (<date>)

## 1. What this application is
Plain-English: what the product does, who uses it, why it exists. Assume zero
prior knowledge. Name the repos, the stack, and where it runs (URLs, hosts).

## 2. What we set out to do this session, and why
The goal in business terms + the technical objective + what triggered it
(bug report, feature request, incident).

## 3. Current state — what is true right now
- What works / is done (verified how?)
- What is half-done and its EXACT current state (files touched, file:line)
- What has not been started
- Is the code committed? pushed? deployed? On which branch/environment?

## 4. Everything we tried that did NOT work
The most-skipped, most-important section. For each dead end: what we tried,
why it seemed reasonable, how it failed, and why. This is what stops the next
session from wasting hours repeating your mistakes.

## 5. Root causes and key findings
What we actually learned about the problem, with file:line references and any
non-obvious discoveries ("the RFQ sub-grid columns come from the backend, not
colDefs" — the kind of thing that took you an hour to figure out).

## 6. Exact next steps
Numbered, in order, specific enough to execute without judgment calls. Each step
ends with a verification gate: "you'll know it worked when ___."

## 7. Constraints and gotchas in force
Standing rules that apply (branch policy, no band-aids, AG-Grid rules, file-date
preservation, etc.) and any traps specific to this work.

## 8. Access and environment
Which CLIs/MCPs are authenticated, which env/branch/URL, where secrets live
(1Password vault name — NEVER the values). Enough that the stranger can act
without asking for logins.

## 9. Open questions and risks
What's uncertain, what could go wrong, decisions made and why (with dates, so a
later session doesn't contradict them).
```

## Mandatory self-audit gate (do this BEFORE showing the handoff)

After drafting, grade your OWN handoff against these questions. If the honest
answer to any is "no," expand the handoff and re-grade. Do NOT present the
handoff to Albert until all are "yes":

1. Could a developer who walked in off the street — with zero knowledge of this
   app, this session, and this chat — pick up and continue **without asking me a
   single question**?
2. Could they continue **as effectively as I can right now**, with everything I
   currently know?
3. Did I include what we tried that FAILED, and why — not just the final plan?
4. Is every next step concrete enough to execute without guessing, each with a
   way to verify it worked?
5. Did I explain every term, identifier, path, and URL a newcomer wouldn't know?

State in your closing message that the self-audit passed. Albert should never
again have to ask "is this comprehensive enough for a fresh developer?" — you
must have already answered it yourself.

## Anti-patterns (these are why past handoffs were too skimpy)

- Assuming the reader knows what the app does, or what "the RFQ issue" refers to.
- Listing the final plan but omitting the failed attempts.
- "Continue where we left off" without saying where that is, in file:line terms.
- Vague next steps ("finish the migration") instead of exact ones.
- Jargon or internal shorthand from this session with no definition.
- Writing three sentences and calling it a handoff. If it's under a screen of
  text for anything non-trivial, it's almost certainly too thin — re-audit.

## Mechanics

- Write it to a repo file (HANDOFF.md, or fix_<topic>.md for a specific fix),
  commit and push — a handoff that lives only in chat is lost.
- HANDOFF.md is deleted only when the work it describes is truly complete.
