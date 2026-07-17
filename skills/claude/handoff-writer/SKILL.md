---
name: handoff-writer
description: Write a fresh-developer-grade handoff (HANDOFF.md or fix_*.md), OR judge whether an existing handoff is comprehensive enough. Use when the user says "put that plan in handoff.md", "write a fix_*.md", "give me a detailed prompt for the new chat", "wrap up", OR asks whether HANDOFF.md is thorough / detailed / comprehensive enough for a fresh developer to pick up and not skip a beat. This skill is self-contained. The handoff must pass the concrete self-audit BELOW before it is shown, so that the answer to "is it comprehensive enough?" is already a truthful Yes.
---

# handoff-writer

The user works across many short sessions with clean context windows; the handoff
IS the memory carried forward. A thin handoff forces them to babysit long
sessions — the exact thing this skill prevents. It applies to two situations:
**writing** a handoff, and **judging** one the user is challenging.

The recurring failure this skill exists to kill: the user asks *"is HANDOFF.md
comprehensive enough for a fresh developer to pick up and not skip a beat?"* and
the answer comes back *"No, I'll fix it now."* — **every single time**, whether
or not the handoff is actually deficient. That reflex is the bug. The cure is two
parts: (1) make the handoff genuinely complete at write time so "Yes" is
truthful, and (2) when asked, verify against the concrete checklist and answer
**Yes** when it passes — instead of reflexively hedging to "No."

## When to use

- "put that plan in handoff.md" / "write a comprehensive handoff.md"
- "write a fix_<topic>.md"
- "give me a very detailed prompt to give another ai session"
- "this session's context window is getting full" / any "wrap up"
- **The verification question** — any form of "is HANDOFF.md thorough / detailed /
  comprehensive / complete enough?", "does it have every relevant detail and
  nuance?", "could a fresh developer continue as well as you?" → go to
  **§ Answering the verification question**. Do NOT reflexively answer "No."

## Two modes

- **Mode A — WRITE:** produce or update a handoff. Follow the structure + gate below.
- **Mode B — JUDGE:** the user is asking whether an existing handoff is good
  enough. Re-read the actual file, grade it, and answer per § Answering the
  verification question.

## Required structure (use these 9 sections; never drop one silently — write "N/A" + why if truly inapplicable)

Write for a developer who **walked in off the street this morning**: zero
knowledge of the app, the business, this session, this chat, or what failed. Make
them able to continue **as effectively as you can right now, with everything you
know**. If they'd have to ask you one question to proceed, that answer belongs in
the handoff. Default to TOO MUCH — too long costs minutes, too short costs a whole
session; those are not symmetric, so err long.

1. **What this application is** — plain English: what it does, who uses it, why.
   Repos, stack, where it runs (URLs, hosts).
2. **What we set out to do this session, and why** — goal in business terms + the
   technical objective + what triggered it (bug, feature, incident).
3. **Current state — what is true right now** — what works (verified how?);
   what is half-done and its EXACT state (files, `file:line`); what is not started;
   is the code committed / pushed / deployed, on which branch/environment.
4. **Everything we tried that did NOT work** — the most-skipped, most-important
   section. Each dead end: what we tried, why it seemed reasonable, how it failed,
   why. This is what stops the next session repeating your hours of mistakes.
5. **Root causes and key findings** — what you actually learned, with `file:line`
   refs and the non-obvious discoveries that each took you real time to work out.
6. **Exact next steps** — numbered, in order, specific enough to execute without
   judgment calls. Each ends with a verification gate: "you'll know it worked when ___."
7. **Constraints and gotchas in force** — standing rules (branch policy, no
   band-aids, concurrency, file-date preservation, etc.) and traps specific to this work.
8. **Access and environment** — which CLIs/MCPs are authenticated, which
   env/branch/URL, where secrets live (1Password vault name — NEVER the values).
9. **Open questions and risks** — what's uncertain, what could break, decisions
   made and why, each dated so a later session can't unknowingly contradict them.

## Comprehensiveness checklist (objective — every item must be YES)

This is what "comprehensive" means. It is a fixed bar, not a feeling. "It could
always be more detailed" is NOT a checklist item — do not treat it as one.

- [ ] All 9 sections present (or "N/A" + reason).
- [ ] A street-newcomer could continue **without asking a single question**.
- [ ] They could continue **as effectively as you can right now** — every
      non-obvious thing you learned this session is written down.
- [ ] The **failed attempts / dead ends** are included with why they failed.
- [ ] Every next step is concrete + has a "you'll know it worked when ___" gate.
- [ ] Every term, identifier, path, URL, and commit SHA a newcomer wouldn't know
      is defined or referenced.
- [ ] Commit/push/deploy status is explicit for each piece of work.
- [ ] Secrets are referenced by location only (vault/item), never by value.
- [ ] For a multi-workstream handoff: **your** workstream's section clears every
      bar above. (You are not responsible for re-auditing other sessions'
      sections, but do not claim the whole file passes if yours is thin.)

## Mandatory self-audit gate (Mode A — BEFORE showing the handoff)

After drafting, grade the handoff against the checklist above. If ANY item is
"no," expand and re-grade — loop until all pass. The FIRST version you present to
the user MUST already pass; do not show a draft you know is thin and plan to
improve after they push back. In your closing message, state that the self-audit
passed and name what makes it comprehensive (which section covers each dimension).

Write and answer the following three questions, citing the handoff sections that
support each answer:

1. Is `HANDOFF.md` comprehensive enough that a brand-new developer with no
   project knowledge and no session context could pick up where I left off and
   not skip a beat?
2. Is it detailed enough that they could continue as well as I could right now,
   with all my session knowledge and the relevant background and purpose?
3. Is every single relevant detail needed for flawless execution included:
   background, goals, intended outcome, current state, failures, decisions,
   constraints, risks, exact next actions, and verification evidence?

Do not accept a bare "yes." For each answer, name the supporting sections and
any gap discovered. Fix every gap in the handoff, then reread and repeat the
whole audit until all three answers are evidence-backed yeses. Preserve the
final answers in the closing report or at the end of the handoff.

## Answering the verification question (Mode B — the reflex this skill fixes)

When the user asks whether the handoff is comprehensive/detailed/thorough enough:

1. **Re-read the actual handoff file first.** Never answer from memory — it may
   already be complete, or the relevant section may be someone else's.
2. **Grade it once against the checklist above** — the fixed bar, not a vibe.
3. **If every checklist item passes → answer "Yes."** Say so plainly, and show
   the evidence: map each audit dimension to the section that satisfies it. Then
   stop. Do not invent work. Do not append "but I could add more."
4. **Only answer "No" if you can name a SPECIFIC missing checklist item** — a real
   gap a newcomer would trip on (an undocumented dead end, a vague next step, a
   missing `file:line`, an unstated deploy status). Name it, fix exactly that,
   then re-grade and answer "Yes."
5. **Never answer "No, I'll improve it" as a reflex or a hedge.** "More detail is
   always possible" is not a deficiency; padding a passing handoff wastes the
   user's time and trains them to keep asking. A truthful "Yes" is the goal —
   reach it by making the handoff good, not by refusing to ever say it.

The bar for "Yes": a stranger could continue **as effectively as you can right
now**. If that is true, the answer is Yes — say it.

## Anti-patterns (why past handoffs were too thin)

- Assuming the reader knows what the app does or what "the X issue" refers to.
- Listing the final plan but omitting the failed attempts.
- "Continue where we left off" without saying where, in `file:line` terms.
- Vague next steps ("finish the migration") instead of exact, verifiable ones.
- Session jargon with no definition.
- Three sentences called a handoff. Under a screen of text for non-trivial work is
  almost certainly too thin — re-audit.
- Reflexively answering "No, not comprehensive enough" to look diligent when the
  checklist already passes.

## Mechanics

- Write to a repo file (HANDOFF.md, or fix_<topic>.md for a specific fix), commit
  and push — a handoff that lives only in chat is lost.
- In a concurrently-edited checkout, stage only your own hunks; never sweep in
  another session's uncommitted work.
- HANDOFF.md is deleted only when the work it describes is truly complete.
- Record infra/design decisions with dates so a later session can't contradict them.

---

_Canonical cross-tool standard (also used by Codex): `templates/system/handoff-standard.md`
in the `ai-devops` repo. This SKILL.md is self-contained and does not depend on it
being checked out; keep the two in sync when either changes._
