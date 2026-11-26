---
issue: 2898
status: OPEN
owner: claude/handoff-close-nested-reviewer-install
---

# Close-nested: second-opinion tool fixes, install and proof remaining

Written 2026-11-26 04:51 UTC (November 25, 2026, 11:51 PM EST) on edge-dev by Claude Sonnet 5.5, chat "Fix Muse answer crash on Windows".

## 0. Business decisions only the owner can make

None. Nothing in this workstream needs the owner.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is the public toolkit that sets up the AI coding tools on POP Creations development computers. Its second-opinion tool, [bin/ai-second-opinion](https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion), lets one AI ask another AI engine (Codex, OpenCode, Antigravity, harness) for an opinion; wrappers such as `ai-muse` and `ai-glm` call it. It runs on Ubuntu (hetz, edge-dev3) and Windows (4837 also called al8960ofc, 916, edge-dev).

## 2. What we set out to do, and why

An `ai-muse new` run on Windows finished its turn and then crashed printing the answer (Windows console encoding, found during work on [issue 2869](https://github.com/popcre/ai-devops/issues/2869)). This session fixed that; a nested session fixed the related input and file encoding, the Windows tests, and the Windows stop command. Albert then invoked `/close-nested`.

## Tree closed

| Session | Final state | Branch disposition |
|---|---|---|
| "Fix Muse answer crash on Windows" (`local_08a762c2-f2d8-4881-9036-638bdd3139ac`) | closing with this file | `claude/wizardly-bell-d16a62` landed, deleted. Its worktree is kept because this session runs in it |
| "Fix remaining Windows reviewer text and test faults" (`local_c41a2bad-8302-4623-a9eb-881e6406a1e6`) | wrapped up, idle | all three task branches landed and deleted; worktree `serene-neumann-96a10f` kept, clean, detached at ce73d312 |

No grandchild sessions. The session that started this one (`local_350573a9-efce-434e-a7d9-7f723e1d5f25`) and its other relatives are outside this tree and were not closed. Issue 2869 belongs to them and stays open. No shared-database work, no claims or locks.

## Landed

All verified merged on GitHub.

- [PR 2888](https://github.com/popcre/ai-devops/pull/2888), commit 496c9864: printed answers are UTF-8.
- [PR 2891](https://github.com/popcre/ai-devops/pull/2891), commit e0e547f0: input and written files are UTF-8; Windows Codex tests fixed ([issue 2889](https://github.com/popcre/ai-devops/issues/2889), closed).
- [PR 2893](https://github.com/popcre/ai-devops/pull/2893), commit 07f76f9e: Windows stop command verifies the engine ended ([issue 2892](https://github.com/popcre/ai-devops/issues/2892), closed).
- [PR 2895](https://github.com/popcre/ai-devops/pull/2895): the nested session's handoff.
- [PR 2894](https://github.com/popcre/ai-devops/pull/2894), commit f716ed40: Ubuntu stop command, from a session on edge-dev3 outside this tree. Listed because it finishes a step the child handoff left open.

## 3. Current state

- The code above is on `main`. **Nothing was installed by either session in this tree**, and which commit each computer has installed was not checked.
- Tests: PR 2888's new tests passed on edge-dev, and its Linux CI jobs passed. The nested session reports `tests/test-ai-review-simple.sh` passing on edge-dev, hetz and edge-dev3 for PRs 2891 and 2893. 4837 and 916 are untested.
- No live engine call was made after any of these fixes in this tree.
- [Issue 2896](https://github.com/popcre/ai-devops/issues/2896) is an open AI review finding on PR 2894, labelled `review-finding` and `fixer-deferred`.

## 4. What did not work

- Before PR 2891, five Codex tests failed on Windows (WinError 193). Fixed there.
- `ai-pr-wait` started in the background from a worktree once exited 3, "cannot determine the repository"; adding `--repo popcre/ai-devops` worked. Cause not investigated.
- `ssh hetz` as the default user was refused. Use user `ai` with SSH key `916-alien` (identities-only, batch mode).
- `gh run view --log` refuses while a run is in progress; per-job logs need `gh api --allow-escape-sequences`.

## 5. Root causes and findings

- Redirected output and piped input on Windows default to cp1252; the tool now sets UTF-8 itself.
- Windows stop: `taskkill /T` on an ended parent misses orphaned children; see `stop_windows_trees` in the tool. Never use `os.kill(pid, 0)` as a liveness probe on Windows.
- Further limits are in section 5 of the [child handoff](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0435Z-edge-dev-claude-windows-reviewer-install-followups.md). Its Ubuntu stop step and the proposed task `task_5cc43dda` are superseded by PR 2894: do not start them.

## 6. Open tasks (exact next steps)

### Task 1: install the fixes on the reviewer computers

- Goal: every reviewer computer runs the fixed tool. [Issue 2898](https://github.com/popcre/ai-devops/issues/2898).
- State: merged, not installed by this tree; installed versions unchecked.
- Next action: read each installed receipt on hetz, edge-dev3, 4837, 916 and edge-dev; where older than f716ed40, install by the protected route in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) (candidate worktree, `ai-task-gates authorize-install`, Ubuntu `update.sh`, Windows `bin/install-ai-devops-windows.ps1`). Never `git pull` in an installed checkout. On 916 the live checkout is on drive D.
- Done when: all five receipts name f716ed40 or newer.
- Branch: fresh from main. Blockers: none known.

### Task 2: prove it on Windows and with live calls (after: Task 1)

- Goal: the repair is complete under [AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md). [Issue 2898](https://github.com/popcre/ai-devops/issues/2898).
- Next action: on 4837 and 916 run `bash tests/test-ai-review-simple.sh` in Git Bash; then one live `ai-second-opinion` call on Windows and one on Ubuntu. Do not overlap a local test run with a GitHub job on the same Windows computer.
- Done when: the suite exits 0 on both and both live calls print an answer. Then close issue 2898 and delete this file and the child handoff.
- Branch: fresh from main.

### Task 3: resolve the review finding on the Ubuntu stop fix

- Goal: the new stop test is isolated and not racy. [Issue 2896](https://github.com/popcre/ai-devops/issues/2896).
- State: open, deferred by the automatic fixer. Its two claims are unverified (the PR's tests did pass).
- Next action: check whether an automatic fix has appeared; otherwise verify both claims against [tests/test_ai_second_opinion.py](https://github.com/popcre/ai-devops/blob/main/tests/test_ai_second_opinion.py) and fix what is real, without weakening the test.
- Done when: issue 2896 is closed with a merged fix or an evidenced reason, and the suite passes on Ubuntu and Windows.
- Branch: fresh from main. Independent of Tasks 1 and 2; if its fix lands first, install that newer commit.

## 7. Constraints and gotchas

- Branch and PR only; merge through the queue with `bin/ai-gh pr merge <n> --auto`. GitHub calls go through `bin/ai-gh`.
- Design for and prove both operating systems. The repository is public.

## 8. Access and environment

GitHub access through `bin/ai-gh` is signed in on edge-dev. SSH note in section 4; edge-dev3 accepts the default key. No secret appeared in this work; secrets live in the 1Password vault `vibe_coding`.

## 9. Open questions and risks

- 2026-11-25: installed versions on all five computers are unknown.
- 2026-11-25: whether finding 2896 is real is unverified.

## Child handoffs

- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0435Z-edge-dev-claude-windows-reviewer-install-followups.md

## Self-audit

1. A newcomer can continue without asking: yes (sections 1 to 8). 2. As effectively as this session: yes (Landed, sections 3 to 6). 3. All relevant detail recorded: yes (sections 2 to 7 and 9). 4. Owner decisions: none exist; section 0 says so and no other part asks for a ruling.

Posted by Claude chat "Fix Muse answer crash on Windows" (31a11f92) on edge-dev
