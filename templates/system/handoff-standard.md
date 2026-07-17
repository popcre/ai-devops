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

After drafting, grade your OWN handoff against these questions. **Write an
answer to every question and cite the handoff section(s) that prove the answer.**
Do not merely acknowledge that the questions were asked. If an answer exposes
any missing or weak detail, add it to `HANDOFF.md`, reread the affected sections,
and answer all questions again. Do NOT present the handoff to Albert until every
answer is an evidence-backed "yes" and every identified gap has been closed:

1. Could a developer who walked in off the street — with zero knowledge of this
   app, this session, and this chat — pick up and continue **without asking me a
   single question**?
2. Could they continue **as effectively as I can right now**, with everything I
   currently know?
3. Did I include what we tried that FAILED, and why — not just the final plan?
4. Is every next step concrete enough to execute without guessing, each with a
   way to verify it worked?
5. Did I explain every term, identifier, path, and URL a newcomer wouldn't know?

Then ask and answer these three final synthesis questions exactly:

1. **Is `HANDOFF.md` comprehensive enough that a brand-new developer with no
   knowledge of this project and no context about what we did or what remains
   could pick up where I left off and not skip a beat?**
2. **Is it detailed enough that they could continue as well as I could right
   now, with all my knowledge from this session and all relevant background
   about what we are trying to accomplish?**
3. **Is every single relevant detail—background, goals, intended outcome,
   current state, failed attempts, decisions, constraints, risks, exact next
   actions, and verification evidence—present for the implementing agent to
   execute flawlessly?**

For each answer, name the supporting sections and any gap found. A found gap
must be fixed before re-running the entire audit. Preserve the final answers in
the closing report or at the end of `HANDOFF.md` so the audit is inspectable.

State in your closing message that the self-audit passed. Albert should never
again have to ask "is this comprehensive enough for a fresh developer?" — you
must have already answered it yourself.

## Comprehensiveness checklist (objective — every item must be YES)

This is what "comprehensive" means. It is a fixed bar, not a feeling. "It could
always be more detailed" is NOT an item on this list — do not treat it as one.

- [ ] All 9 sections present (or "N/A" + reason).
- [ ] A street-newcomer could continue WITHOUT asking a single question.
- [ ] They could continue as effectively as you can right now — every non-obvious
      thing learned this session is written down.
- [ ] The failed attempts / dead ends are included, with why they failed.
- [ ] Every next step is concrete and has a "you'll know it worked when ___" gate.
- [ ] Every term, identifier, path, URL, and commit SHA a newcomer wouldn't know
      is defined or referenced.
- [ ] Commit / push / deploy status is explicit for each piece of work.
- [ ] Secrets are referenced by location only (vault/item), never by value.
- [ ] In a multi-workstream handoff, YOUR workstream's section clears every bar
      above (you need not re-audit other sessions' sections, but do not claim the
      whole file passes if yours is thin).

## Answering "is it comprehensive enough?" (do NOT reflex-answer "No")

The recurring failure this standard exists to end: when asked whether the handoff
is comprehensive / thorough / detailed enough, the answer comes back "No, I'll fix
it" EVERY time — regardless of whether the handoff is actually deficient. That
reflex is the bug. When asked:

1. Re-read the actual handoff file first. Never answer from memory — it may already
   be complete.
2. Grade it once against the comprehensiveness checklist above — the fixed bar, not a vibe.
3. If every item passes, answer "Yes." Say it plainly and show the evidence (map
   each audit dimension to the section that satisfies it). Then stop — do not invent
   work or append "but I could add more."
4. Answer "No" ONLY if you can name a SPECIFIC missing checklist item — a real gap a
   newcomer would trip on. Name it, fix exactly that, re-grade, then answer "Yes."
5. Never answer "No, I'll improve it" as a reflex or a hedge. "More detail is always
   possible" is not a deficiency. Padding a passing handoff wastes the user's time
   and trains them to keep asking. A truthful "Yes" is the goal — reach it by making
   the handoff good, then saying so.

The bar for "Yes": a stranger could continue as effectively as you can right now.
If that is true, the answer is Yes — say it.

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
