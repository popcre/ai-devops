---
name: implementation-plan-writer
description: Write (or judge) an implementation plan that a BRAND-NEW AI session with zero context can execute perfectly. Use when the user says "write an implementation plan", "write the plan for this feature/fix", "plan how we'll build X", "put the plan in PLAN.md / IMPLEMENTATION-PLAN.md", "give another session a plan to implement this", or asks whether an existing plan is detailed/comprehensive enough for a fresh implementing session. The plan is a handoff plus a build spec: it must carry the ultimate goal, all background, every constraint and nuance, and per-step verification. This skill is self-contained and must pass the self-audit gate BELOW before the plan is shown.
---

# implementation-plan-writer

## The failure this skill exists to kill

Plans get written by the session that did the thinking — and that session
silently assumes the implementing session shares its context. It doesn't. A new
session opens the plan with **zero** knowledge of the app, the goal, the earlier
debugging, the rejected approaches, or why step 3 is worded that way. The result
is an implementer that builds the letter of the plan and misses the point, or
stops to ask questions that the planning session already knew the answer to.

**Rule: the implementation plan must stand completely on its own.** If the
implementer would have to ask the planner one question — or read the planning
chat, or guess at intent — that answer belongs in the plan.

An implementation plan is a **handoff + a build spec**. Everything the
`handoff-writer` standard demands about background and dead ends applies here,
plus the forward-looking build detail below.

## Two modes

- **Mode A — WRITE:** produce or update an implementation plan. Follow the
  structure, then the self-audit gate.
- **Mode B — JUDGE:** the user asks whether an existing plan is
  detailed/comprehensive enough for a fresh implementing session. Re-read the
  actual file, grade it against the checklist, and answer per
  **§ Answering the verification question**. Do NOT reflex-answer "No."

## Required structure (13 sections — never drop one silently; write "N/A" + why)

Write for an implementer who **walked in off the street this morning** and has
only this document. Default to TOO MUCH: a long plan costs minutes of reading, a
thin plan costs a whole session of rediscovery and a wrong build.

### Part 1 — Why (the part sessions always omit)

1. **The ultimate goal — what we are actually trying to achieve.**
   Plain business English, first, before any technical wording. What will be
   true for the user/business when this is done that isn't true today? This is
   the section the implementer re-reads when the plan and reality disagree —
   when a step turns out to be wrong, the goal is what they steer by. State
   explicitly: *"If a step conflicts with this goal, the goal wins — stop and
   flag it."*
2. **What this application is** — what it does, who uses it, why it exists.
   Repos, branch, stack, where it runs (URLs, hosts, environments).
3. **What triggered this work** — the bug report, feature request, incident, or
   business need, including the environment/URL it was observed on and how to
   reproduce it if it's a bug.
4. **Scope — in and out.** An explicit "NOT in this plan" list. Unbounded scope
   is how a two-file change becomes a refactor.

### Part 2 — What we already know (so it isn't rediscovered)

5. **Current state of the code** — what already exists and works, what is
   half-done and its EXACT state with `file:line` refs, what is untouched.
   Committed? Pushed? Deployed? On which branch/environment?
6. **Key findings and root cause** — what investigation established, with
   `file:line` evidence. Every non-obvious discovery that cost real time.
7. **Approaches considered and REJECTED, and why** — the most-skipped section.
   Includes anything already tried that failed and how it failed. Without this
   the implementer "improves" the plan by walking straight into a dead end.
8. **Design decisions already made, and their reasoning** — with dates. State
   which decisions are **locked** (do not relitigate) and which are **open** for
   the implementer's judgment. Ambiguity here is how implementers quietly
   redesign the feature.

### Part 3 — How to build it

9. **The plan — numbered, ordered, executable steps.** For EACH step:
   - What to change, in `file:line` / function / component terms — the target
     files named, not "the relevant service".
   - How it should behave when done (the intent, not just the edit), so a step
     that's slightly wrong can still be implemented correctly.
   - Dependencies: what must be done first; what can run in parallel.
   - **Verification gate: "you'll know it worked when ___"** — a command,
     an HTTP check, a test name, or a screenshot of a specific screen.
   - Where a step is genuinely a judgment call, say so and give the criteria.
   Group steps into **phases** when the work is large enough that a session
   would run out of context; mark the natural cut points (see `fresh-session`).
10. **Tests required** — the specific unit tests to add for the new code, and
    the existing suite/command that must stay green. Never "add tests."
11. **Constraints, standing rules, and gotchas in force** — branch policy, DB
    changes go through `shared-db` (never app-repo migrations), no band-aids, no
    silent failures, nothing hard-coded, visual verification for UI work, plus
    every trap specific to THIS work. Name them; do not assume the implementer
    has read the global rules.
12. **Access and environment** — which CLIs/MCPs are authenticated, the target
    branch/env/URL, test logins by 1Password location (vault + item title,
    **never values**), and how to run/serve the thing locally.

### Part 4 — Landing it

13. **Definition of done + risks and open questions** — the checklist that makes
    this complete (code, tests, commit, push, CI green, deployed SHA verified,
    docs/handoff updated), what could break and the rollback, and what remains
    genuinely uncertain with the criteria for deciding it.

## Comprehensiveness checklist (objective — every item must be YES)

This is what "comprehensive" means here. It is a fixed bar, not a feeling. "It
could always be more detailed" is NOT an item on this list.

- [ ] All 13 sections present (or "N/A" + reason).
- [ ] **The ultimate goal is stated in plain business English, up top**, with the
      "if a step conflicts with the goal, the goal wins" instruction.
- [ ] A fresh session could implement it **without asking a single question** and
      without reading the planning chat.
- [ ] Rejected approaches and failed attempts are written down, with why.
- [ ] Every step names concrete files/functions and has a verification gate.
- [ ] Locked vs. open decisions are labeled.
- [ ] Explicit out-of-scope list.
- [ ] Tests are specified by name/behavior, not "add tests."
- [ ] Every term, path, URL, identifier, and SHA a newcomer wouldn't know is
      defined or referenced.
- [ ] Secrets referenced by location only, never by value.
- [ ] Definition of done includes commit/push/CI/deploy verification.

## Mandatory self-audit gate (Mode A — BEFORE showing the plan)

After drafting, grade the plan against the checklist. If ANY item is "no,"
expand and re-grade — loop until all pass. The FIRST version presented MUST
already pass; never show a draft you know is thin intending to fix it after
pushback. Write and answer these three questions, citing the plan sections that
support each answer:

1. Could a brand-new AI session with no project knowledge and no context from
   this conversation execute this plan to perfection, without asking me anything?
2. Does the plan carry every piece of background, nuance, and reasoning I
   currently hold — including what we ruled out and why?
3. Is the ultimate goal stated clearly enough that the implementer could make a
   correct judgment call if a step turns out to be wrong?

Do not accept a bare "yes" — name the supporting sections and any gap found, fix
the gap, then re-run the whole audit. Preserve the final answers at the end of
the plan file. In your closing message, state that the self-audit passed and what
makes the plan comprehensive.

## Answering the verification question (Mode B)

When asked whether the plan is comprehensive/detailed enough:

1. **Re-read the actual plan file first** — never answer from memory.
2. Grade it once against the checklist above.
3. **If every item passes → answer "Yes,"** plainly, with the evidence (map each
   audit dimension to the section that satisfies it). Then stop. Do not invent
   work or append "but I could add more."
4. **Answer "No" only if you can name a SPECIFIC missing checklist item** — a
   real gap the implementer would trip on. Name it, fix exactly that, re-grade,
   answer "Yes."
5. Never answer "No, I'll improve it" as a reflex or a hedge.

## Anti-patterns (the ways plans fail the next session)

- Assuming the implementer knows what "the RFQ issue" or "the new flow" means.
- Leading with the steps and never stating the goal — so the implementer can't
  tell right from wrong when the plan is imperfect.
- "Refactor the service layer" / "wire it up" / "finish the migration" — steps
  with no files and no verification gate.
- Silently omitting the approaches already tried and rejected.
- Leaving locked decisions unlabeled, so the implementer redesigns them.
- No out-of-scope list, so scope grows silently.
- A plan that only lives in chat. It must be a file (see Mechanics).
- Three bullet points called a plan. Under a screen of text for non-trivial work
  is almost certainly too thin — re-audit.

## Mechanics

- Write to a repo file — `IMPLEMENTATION-PLAN.md`, or `plan_<topic>.md` for a
  scoped piece of work — then commit and push. A plan that lives only in chat is
  lost when the session ends.
- If the implementing session will be a different tool (Codex, another Claude
  session), the plan file IS the brief — hand over its path, not a summary.
- In a concurrently-edited checkout, stage only your own hunks.
- For multi-phase work, mark the context cut points and instruct the implementer
  to **re-read the downstream phases before starting each one** (drift check);
  pair with the `fresh-session` skill at each cut.
- When work has already happened, the plan complements — not replaces —
  `HANDOFF.md`; cross-link the two so neither is read alone.
- Delete/complete the plan file only when the work it describes is truly done.
- **Put a STATUS table at the top from day one** — one row per step (done / partial /
  open, dated) plus a line naming where a fresh session starts. On a brand-new plan
  every row is `⬜ open`; that is fine. It exists so the first thing any reader sees
  is what is still true.
- **A plan goes stale the moment someone executes part of it.** Whoever does the work
  owns updating it — the `session-docs-update` / `codex-docs-update` skills carry a
  **mandatory plan-file gate** for exactly this (de-stale the "current state" section,
  keep the reasoning as history, mark passed verification, record what is blocked and
  on whom). Real failure it prevents: on 2026-07-26 four steps of
  `plan_phase3-config-consolidation.md` were executed while its current-state section
  still described the pre-fix world, which would have made the next session redo
  finished work.
- **Make it discoverable, not memorable.** Nobody will remember `plan_<topic>.md`
  three months on. Link it from `AGENTS.md` (the router), `HANDOFF.md`, the topic doc,
  and any skill whose trigger leads there; add a memory entry saying "read its STATUS
  table first — do not re-derive or re-plan".

---

_Canonical cross-tool standard: `templates/system/implementation-plan-standard.md`
in the `ai-devops` repo. Companion standard for past-facing work:
`templates/system/handoff-standard.md` (skill: `handoff-writer`). This SKILL.md is
self-contained; keep it in sync when either standard changes._
