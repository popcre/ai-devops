---
issue: 1678
status: OPEN
owner: mimo/edge-dev-reviewer-no-review-plan
---

# HANDOFF — edge-dev reviewer repair plan (no AI-reviewer gate)

Machine: edge-dev · Agent: MiMo · Written: 2026-10-15 9:48 PM EDT
GitHub signature: `Posted by MiMo chat unknown on edge-dev`
Plan: [`plan_edge-dev-reviewer-repair-no-review.md`](../plan_edge-dev-reviewer-repair-no-review.md)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):** Albert, 2026-10-15 — “knowing that the
  reviewers don't work, make sure implementing it doesn't need reviewers.”
  Implementation of this plan lands with tests + merge queue + live smoke only.
  No AI reviewer is a gate. Do not weaken fleet-wide protected classes.
- **Still his:** nothing pending for this handoff.
- **Not Albert's call:** which door to fix first, OpenCode profile fields,
  whether GLM REVISE is lifecycle vs pool.

## 1. What this application is

`popcre/ai-devops` on **edge-dev** (Windows). Sibling programme:
[`plan_reviewer-recurrence-repair.md`](../plan_reviewer-recurrence-repair.md)
for edge-dev3. This handoff carries the **no-review bootstrap repair plan** for
this machine’s open reviewer failures.

## 2. What we set out to do this session

Write a standalone implementation plan so a fresh session can repair edge-dev
reviewers without depending on a working reviewer fleet.

## 3. Current state

| Outcome | State | Artifact |
|---|---|---|
| Implementation plan | **Written** | `plan_edge-dev-reviewer-repair-no-review.md` |
| Plan publication PR | Open until merged | branch `mimo/plan-edge-dev-reviewer-no-review` |
| Repair implementation | **Not started** | plan STATUS all ⬜ |
| Open local incidents | **OPEN** | `20261014T203826Z-edge-dev-stepfun-2686842`, `20261014T201712Z-edge-dev-glm-2563781` |

## 4. Everything we tried that did NOT work

- N/A this session (planning only). Historical dead ends are in the plan §7.

## 5. Root causes and key findings

See plan §§6–8. Short form: protected wrapper paths cannot be a dependency of
their own repair; most fix targets already classify as `code` (doors, lifecycle,
OpenCode profiles, tests).

## 6. Exact next steps

1. Fresh session: read plan STATUS, start at step 0 (class contract), then step 1
   (inventory).
2. Land steps 2–5 as separate `code` PRs (StepFun spawn, GLM REVISE, durable
   publish, Git Bash).
3. Step 6–7: live smoke, resolve the two incidents on the same issue, code-only
   install, update STATUS.
4. Do not edit `bin/ai-*` entrypoints under this plan; escalate per plan §8.

**Verify success:** both incidents disposed with evidence; named tests green;
smoke shows a starting StepFun shell and a durable report.

## 7. Constraints and gotchas in force

- No AI reviewer gate; effective class must stay `prose`/`code`.
- Worktree-based; never pull the canonical checkout; branch + PR + merge queue.
- Times EST. Secrets: 1Password `vibe_coding` only. Stage only owned files.
- Reuse #1678 / #1467 / #1701 / #1370; no proof-only tickets.

## 8. Access and environment

- edge-dev (Windows), Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- Canonical `C:\repos\ai-devops` landing-only.
- Planning worktree used: `C:\repos\ai-devops-wt-reviewer-no-review`.
