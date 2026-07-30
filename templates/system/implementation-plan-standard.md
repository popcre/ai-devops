# IMPLEMENTATION PLAN standard — how EVERY session must write a plan

Hard standard, not a suggestion. Applies to Claude AND Codex, every time.
Companion to `handoff-standard.md`: the handoff records what happened, the plan
directs what happens next. Skill: `implementation-plan-writer`.

## The mindset (read this first)

The plan will be executed by a **brand-new AI session with a clean context
window**. It has NO knowledge of the app, the goal, this session's debugging,
the approaches already rejected, or why a step is worded the way it is — and no
access to the planning chat.

If the implementer would have to ask the planner a single question, that
question's answer belongs in the plan. Default to TOO MUCH: a long plan costs
minutes of reading; a thin plan costs a whole session and a wrong build.

Above all: **state the ultimate goal first, in plain business English.** When a
step turns out to be wrong — and on real work some step always is — the goal is
the only thing that lets the implementer choose correctly instead of building
the letter of a broken instruction.

## Required structure

```md
# IMPLEMENTATION PLAN — <topic> (<date>)

## 1. The ultimate goal — what we are trying to achieve
Plain business English. What is true when this is done that isn't true today?
End with: "If any step below conflicts with this goal, the goal wins — stop and flag it."

## 2. What this application is
What it does, who uses it, why. Repos, branch, stack, where it runs (URLs, hosts).

## 3. What triggered this work
Bug report / feature request / incident, the environment it was seen on, repro steps.

## 4. Scope — in and out
Explicit "NOT in this plan" list.

## 5. Current state of the code
Exists and works / half-done (file:line) / untouched. Committed? Pushed? Deployed? Branch?

## 6. Key findings and root cause
With file:line evidence and every non-obvious discovery that cost real time.

## 7. Approaches considered and REJECTED, and why
Including what was already tried and how it failed. Most-skipped section.

## 8. Design decisions already made (dated)
Mark each LOCKED (do not relitigate) or OPEN (implementer's judgment).

## 9. The plan — numbered, ordered steps
Per step: target files (file:line/function), intended behavior when done,
dependencies, and a verification gate — "you'll know it worked when ___."
Group into phases for large work; mark the context cut points.

## 10. Tests required
Specific unit tests to add; the existing suite/command that must stay green.

## 11. Constraints, standing rules, and gotchas in force
Branch policy, shared-db for ALL schema changes, no band-aids, no silent
failures, nothing hard-coded, visual verification for UI — plus traps specific
to this work.

## 12. Access and environment
Authenticated CLIs/MCPs, target branch/env/URL, test logins by 1Password
vault + item title (NEVER values), how to run it locally.

## 13. Definition of done + risks and open questions
Code, tests, commit, push, CI green, deployed SHA verified, docs updated.
What could break, the rollback, what's still uncertain and how to decide it.
```

## Comprehensiveness checklist (every item must be YES)

- [ ] All 13 sections present (or "N/A" + reason).
- [ ] Ultimate goal stated in plain business English, up top, with the
      "goal wins over a wrong step" instruction.
- [ ] A fresh session could execute it without asking a single question.
- [ ] Rejected approaches and failed attempts included, with why.
- [ ] Every step names concrete files and has a verification gate.
- [ ] Locked vs. open decisions labeled.
- [ ] Explicit out-of-scope list.
- [ ] Tests specified by name/behavior, not "add tests."
- [ ] Every term, path, URL, identifier, SHA a newcomer wouldn't know is defined.
- [ ] Secrets by location only, never by value.
- [ ] Definition of done includes commit/push/CI/deploy verification.

## Mandatory self-audit gate (BEFORE showing the plan)

Grade the draft against the checklist; loop until every item passes. Then answer,
citing sections:

1. Could a brand-new AI session with no project knowledge and no context from
   this conversation execute this plan to perfection, without asking anything?
2. Does the plan carry every piece of background, nuance and reasoning I hold —
   including what we ruled out and why?
3. Is the ultimate goal clear enough that the implementer could make a correct
   judgment call if a step turns out to be wrong?

Fix every gap found, re-run the whole audit, and preserve the final answers at the
end of the plan file. State in the closing message that the self-audit passed.

## Answering "is the plan detailed enough?" (do NOT reflex-answer "No")

Re-read the file, grade it once against the checklist, and if every item passes
answer **"Yes"** with the evidence, then stop. Answer "No" only when you can name
a specific missing checklist item — fix exactly that, re-grade, answer "Yes."
"More detail is always possible" is not a deficiency.

## Anti-patterns

- Steps with no goal above them, so a wrong step gets built anyway.
- "Refactor the service layer" — no files, no verification gate.
- Omitting the dead ends, so the implementer walks into them.
- Unlabeled decisions, silently redesigned by the implementer.
- No out-of-scope list.
- A plan that only lives in chat.

## Mechanics

- Write it to a repo file (`IMPLEMENTATION-PLAN.md`, or `plan_<topic>.md`),
  commit and push. Hand the implementing session the file path, not a summary.
- For multi-phase work, instruct the implementer to re-read downstream phases
  before starting each one (drift check); pair with the `fresh-session` skill.
- Cross-link with your session's `HANDOFF.d/` file when work has already happened — neither should
  be read alone.
- **STATUS table at the top from day one:** one row per step (done / partial / open,
  dated) plus a line naming where a fresh session starts. On a new plan every row is
  `open`; it exists so the first thing a reader sees is what is still true.
- **Executing part of a plan makes the rest of it lie.** Whoever does the work updates
  the plan in the same session — the `session-docs-update` / `codex-docs-update` skills
  carry a mandatory plan-file gate: de-stale the "current state of the code" section,
  keep the reasoning as history (a session that loses the *why* undoes the fix), mark
  verification that already passed, and record what is open and blocked on whom.
- **Discoverability beats memory.** Nobody recalls `plan_<topic>.md` months later.
  Link it from `AGENTS.md`, your own `HANDOFF.d/` file, the topic doc, and any skill whose trigger
  leads there, and add a memory entry pointing at its STATUS table.
