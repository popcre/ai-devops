---
issue: 2869
status: OPEN
owner: claude/close-nested-continuity-pilot
---

# Close-nested: GitHub continuity pilot tree closed; install, proof and one review finding remain

## 0. Business decisions only the owner can make

None.

## 1. What this application is

`popcre/ai-devops` is Albert's shared AI toolkit: the scripts, skills and instructions installed on every AI machine.

## 2. What we set out to do, and why

The goal was to run the GitHub continuity and throughput pilot from `plan_github-continuity-pilot.md` (issue [#2869](https://github.com/popcre/ai-devops/issues/2869)) and land fixes for what it found.

## Tree closed

| Session | Final state | Branch |
|---|---|---|
| GitHub continuity pilot execution (this coordinator) | closed | `claude/github-continuity-pilot-2eab4a`, landed |
| Bound GitHub waits in status, memory sync, collision | closed | landed, PR 2886 |
| Diagnose why PRs wait before entering merge queue | closed | landed, PRs 2890 and 2902 |
| Fix Muse answer crash on Windows (child of the above) | closed | landed |
| Fix remaining Windows reviewer text and test faults (grandchild) | closed | landed |

## Landed

The following are merged and verified on GitHub: [#2882](https://github.com/popcre/ai-devops/pull/2882) (pilot findings), [#2886](https://github.com/popcre/ai-devops/pull/2886) (bounded slow-GitHub waits), [#2888](https://github.com/popcre/ai-devops/pull/2888), [#2890](https://github.com/popcre/ai-devops/pull/2890) (stop waiting on an unqueued PR), [#2891](https://github.com/popcre/ai-devops/pull/2891), [#2893](https://github.com/popcre/ai-devops/pull/2893), [#2894](https://github.com/popcre/ai-devops/pull/2894), [#2895](https://github.com/popcre/ai-devops/pull/2895), [#2899](https://github.com/popcre/ai-devops/pull/2899), [#2902](https://github.com/popcre/ai-devops/pull/2902).

## 3. Current state

All code is merged. Installs are verified on edge-dev, 4837, 916 and hetz at `ecee4949`. The checkout on edge-dev3 holds the fix, but its install is not proven. Issue #2869 stays open only for the live listener proof.

## 4. What did not work

Waiting on PR 2882 before enqueueing it cost 60 minutes; PR 2890 fixes this.

## 5. Root causes and findings

The verdicts are in `docs/verification/github-pilot.md`.

## 6. Open tasks (exact next steps)

Tasks 1–3 are those of the [pr-wait close-nested handoff](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T1327Z-edge-dev-claude-close-nested-pr-wait.md), section 6. Follow that file's subsections verbatim.

### Task 1: install current main on the five computers

- **Goal:** every computer runs current main, `f716ed40` or newer.
- **Issue:** [#2898](https://github.com/popcre/ai-devops/issues/2898).
- **Blocker:** edge-dev3 needs administrator authority. Report it `Blocked —` if no session holds that authority.
- **Done when:** every install receipt is current and the agent-instructions check is clean.

### Task 2: prove the second-opinion tool (after: Task 1)

Run the suite on 4837 and 916, then make one live call on Windows and one on Ubuntu. Issue: [#2898](https://github.com/popcre/ai-devops/issues/2898).

### Task 3: settle the Ubuntu stop-test review finding (independent)

Issue: [#2896](https://github.com/popcre/ai-devops/issues/2896). Done when it is closed with a merged fix or an evidenced reason, and the suite passes on both operating systems.

### Not a task: shared-notification live proof

The listener live proof stays open on #2869. Do not start it unless verified status reads reach 20% of a peak hour (see the findings doc). First attribute the unaccounted REST core spend.

## 7. Constraints and gotchas

- Every GitHub call goes through `bin/ai-gh`.
- Enqueue with `ai-gh pr merge <n> --auto` before starting `bin/ai-pr-wait`.

## 8. Access and environment

These are the standard ai-devops machines; see `AGENTS.md`.

## 9. Open questions and risks

Five older Windows test failures are covered by Task 2's suite run.

## Child handoffs

- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T1327Z-edge-dev-claude-close-nested-pr-wait.md
- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0451Z-edge-dev-claude-close-nested-reviewer-install.md
- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0435Z-edge-dev-claude-windows-reviewer-install-followups.md

## Self-audit

- Every task names a goal, next action, done-when and issue.
- Every listed PR was verified merged.
- No secrets, private repository names or local paths outside the repo appear in this file.
