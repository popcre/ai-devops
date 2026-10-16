---
issue: 1678
status: OPEN
owner: mimo/edge-dev-reviewer-no-review-plan
---

# HANDOFF — edge-dev reviewer repair plan (no AI-reviewer gate) (2026-10-15, edge-dev/mimo)

Machine: edge-dev · Agent: MiMo · Written: 2026-10-15 10:45 PM EDT
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

Plan (read its STATUS first):
https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md

Sibling (do not rewrite):
https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already settled — do NOT re-ask (2026-10-15, Albert, verbatim):** “knowing
  that the reviewers don't work, make sure implementing it doesn't need
  reviewers.” Implementation of this plan lands with tests + merge queue +
  live smoke only. No AI reviewer is a merge or install gate. Do not weaken
  fleet-wide protected classes to achieve that.
- **BLOCKING:** none. The repair can start without Albert.
- **RECOVERABLE:** none.
- **NOT PART OF THIS WORK, AND NOBODY IS ON IT:** none found.
- **Still his:** nothing.

Technical approvals never go here. If a step hits a protected-class stop, it
is `Blocked —` in the plan STATUS and issue #1678 — not a question for Albert.

## 1. What this application is

`popcre/ai-devops` is Albert’s public AI workflow toolkit (reviewer wrappers,
doors, tests, docs, installers) on GitHub
https://github.com/popcre/ai-devops. This handoff is for **edge-dev** (Windows).
Sibling programme for edge-dev3 (Linux) is
https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md
under issue #1783 — share common-layer work; do not fork it.

## 2. What we set out to do this session, and why

Albert asked why reviewers keep failing on this computer, then asked for a plan
to fix it with the constraint that implementing it must not need reviewers.
This session wrote and published that plan. **Implementation has not started.**

## 3. Current state — what is true right now

| Outcome | State | Evidence |
|---|---|---|
| Implementation plan | **On `main`** | https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md (PR https://github.com/popcre/ai-devops/pull/1788, squash `1078ea63`) |
| Plan STATUS publication checklist | **Closed** | PR https://github.com/popcre/ai-devops/pull/1792, merge `00ee365b` |
| AGENTS.md + docs/task-router links | **Live on `main`** | same PRs |
| Repair implementation | **Not started** | plan STATUS rows 0–7 all open |
| Local incidents on edge-dev | **OPEN** | `20261014T203826Z-edge-dev-stepfun-2686842`, `20261014T201712Z-edge-dev-glm-2563781` |
| Issue #1678 | **OPEN** | plan publication comment recorded; repair checklist still open |

Nothing is half-edited. Both publication PRs are MERGED. No deploy/install was
performed (this was a docs-only session).

## 4. Everything we tried that did NOT work

- Planning session only — no implementation attempts. Historical dead ends are
  in plan §7 (including “get an AI review to land the fixes”, admin-merge, and
  weakening `config/task-gates.json`).
- `ai-pr-wait` on a prose PR: refused because `prose` forbids the `pr-wait`
  action. Used auto-merge + merge queue instead. Do not retry `ai-pr-wait` for
  a prose-only change.

## 5. Root causes and key findings

See plan §§6–8:
https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md

Short form: `reviewer-safety` is a protected class that requires an independent
AI review — circular when the fleet is the defect. Measured class map shows
doors, lifecycle, OpenCode profiles, config and tests are `code` (no review).
Fixes must stay on those paths.

## 6. Exact next steps

1. Read the plan STATUS table (link above). Start at **step 0** (no-review class
   contract), then **step 1** (edge-dev inventory).
   Gate: `bin/ai-task-gates explain` on the PR change set shows effective class
   `prose` or `code` only.
2. Land steps 2–5 as separate `code` PRs: StepFun Windows shell spawn, GLM
   REVISE re-review waste, durable report publish, Git Bash/ProgramFiles.
   Gate: each PR’s named tests green; never edit `bin/ai-*` entrypoints.
3. Steps 6–7: live smoke on edge-dev, resolve both local incidents with exact
   evidence on issue #1678, code-only install, update plan STATUS.
   Gate: incidents resolved/partially-resolved with evidence; smoke shows a
   starting StepFun shell and a durable report path.
4. If any fix is only possible inside a protected wrapper file, stop and record
   `Blocked —` with the path class — do not edit it under this plan (plan §8).

## 7. Constraints and gotchas in force

- Owner rule: no AI reviewer as a gate; change sets stay `prose`/`code`.
- Branch + PR + merge queue; never push `main`; never `--admin`.
- Work in a fresh worktree from `origin/main`; canonical checkout is landing-only.
- Reuse issues #1678 / #1467 / #1701 / #1370; no proof-only tickets.
- Times EST/EDT. Secrets: 1Password `vibe_coding` only. Stage only owned files.
- `git var GIT_COMMITTER_IDENT` must show Albert’s identity before commit.

## 8. Access and environment

- Host edge-dev (Windows). Git Bash is the supported shell for these tools.
- GitHub as `u2giants` via `bin/ai-gh`. Repo `popcre/ai-devops`.
- Private incident store via `ai-reviewer-issue` on the installed toolkit
  (do not copy raw incident bodies into the public repo).
- No new secrets required to implement the plan.

## 9. Open questions and risks

- Exact OpenCode field causing StepFun `ChildProcess.spawn` NotFound (plan open
  judgment).
- Whether GLM REVISE waste is lifecycle vs pool-only (escalate per plan §8 if
  only `bin/ai-review-pool` can fix it).
- Risk: a root cause that lives only in a protected `bin/ai-*` entrypoint — then
  stop as `Blocked —` rather than break the no-review contract.
- Risk: overlap with edge-dev3 plan on shared lifecycle files — serialize those
  edits.

## Mandatory self-audit — completed before closeout

1. **Stranger continues with no questions? Yes.** §§2–3 name goal and exact
   state; §6 is ordered with gates; plan URL is the build spec.
2. **As effectively as this session? Yes.** §§4–5 carry failed approaches and
   the class-map finding; §7 carries the owner rule and delivery constraints.
3. **Failed attempts included? Yes.** §4 (prose `pr-wait` refusal) plus plan §7.
4. **Next steps concrete and verifiable? Yes.** §6 each step has a gate.
5. **Terms explained? Yes.** §§1,5 define toolkit/plan/incident IDs; plan has
   the full glossary.
6. **File references are GitHub URLs? Yes.** All repo artifacts in §§1–3,5 use
   https://github.com/popcre/ai-devops/blob/main/... or pull URLs.
7. **Section-0 sweep done? Yes.** Only Albert item is the already-settled
   no-review rule; nothing else needs him; technical stops stay `Blocked —`.

Synthesis: (1) Yes — §§0–9 + plan link. (2) Yes — failed attempts, class map,
owner rule, next gates. (3) Yes — background, state, constraints, risks, next
actions. (4) Yes — §0 has the only business decision (settled 2026-10-15) and
nothing else; walking §§1–9 finds no other owner judgement.
