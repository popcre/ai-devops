---
issue: 2898
status: OPEN
owner: claude/handoff-close-nested-pr-wait
---

# Close-nested: queued-wait fix and second-opinion fixes, install and proof remaining

Written November 26, 2026, 8:27 AM EST (13:27 UTC) on edge-dev by Claude Sonnet 5.5, chat "Diagnose why PRs wait before entering merge queue".

## 0. Business decisions only the owner can make

None. Nothing in this workstream needs the owner.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is the public toolkit that sets up the AI coding tools on POP Creations development computers: Ubuntu (hetz, edge-dev3) and Windows (4837 also called al8960ofc, 916, edge-dev). [bin/ai-pr-wait](https://github.com/popcre/ai-devops/blob/main/bin/ai-pr-wait) waits for a pull request to merge. [bin/ai-second-opinion](https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion) asks another AI engine for an opinion.

## 2. What we set out to do, and why

This session found why some pull requests sat 9 to 60 minutes before entering the merge queue ([diagnosis](https://github.com/popcre/ai-devops/issues/2869#issuecomment-7180725497)): sessions waited on pull requests nothing had queued. Albert approved the fix ("Yes, build it"). Side sessions fixed Windows faults in the second-opinion tool. Albert then invoked `/close-nested` here.

## Tree closed

| Session | Final state | Branch disposition |
|---|---|---|
| "Diagnose why PRs wait before entering merge queue" (`local_350573a9-efce-434e-a7d9-7f723e1d5f25`) | closing with this file | `claude/pr-wait-not-queued` merged, temporary worktrees removed. The shared parent worktree is kept |
| "Fix Muse answer crash on Windows" (`local_08a762c2-f2d8-4881-9036-638bdd3139ac`) | wrapped up, idle | branch landed and deleted; worktree `wizardly-bell-d16a62` kept, clean, detached at 108f225e |
| "Fix remaining Windows reviewer text and test faults" (`local_c41a2bad-8302-4623-a9eb-881e6406a1e6`) | wrapped up, idle | branches landed and deleted; worktree `serene-neumann-96a10f` kept, clean, detached at ce73d312 |

The two side sessions had already closed themselves, so no second wrap-up message was sent; their handoffs and final report were read and their pull requests checked on GitHub. The session that started this one (`local_4d2b1471-c63c-44fb-b2b0-6d1095d2ad8c`) and its other side session (`local_96665937-b2eb-4409-996f-a9ac5b1d09db`) are outside this tree and were not closed. [Issue 2869](https://github.com/popcre/ai-devops/issues/2869) is theirs and stays open. No shared-database work, claims or locks.

## Landed

Each verified `MERGED` on GitHub on November 26.

- [PR 2890](https://github.com/popcre/ai-devops/pull/2890), merge ecee4949: `ai-pr-wait` exits 4 on an unqueued pull request; instructions say queue first.
- [PR 2888](https://github.com/popcre/ai-devops/pull/2888), 496c9864: printed answers are UTF-8.
- [PR 2891](https://github.com/popcre/ai-devops/pull/2891), e0e547f0: input and files are UTF-8 on Windows ([issue 2889](https://github.com/popcre/ai-devops/issues/2889), closed).
- [PR 2893](https://github.com/popcre/ai-devops/pull/2893), 07f76f9e: Windows stop command verifies the engine ended ([issue 2892](https://github.com/popcre/ai-devops/issues/2892), closed).
- [PR 2894](https://github.com/popcre/ai-devops/pull/2894), f716ed40: Ubuntu stop command (a session outside this tree).
- Handoffs: [PR 2895](https://github.com/popcre/ai-devops/pull/2895), [PR 2899](https://github.com/popcre/ai-devops/pull/2899).

## 3. Current state

- Installed by this session on November 25 (EST) and verified then, at ecee4949: edge-dev, 4837, 916 (checkout on drive D), hetz. ecee4949 contains 496c9864 but **not** e0e547f0, 07f76f9e or f716ed40. Not re-read since.
- **edge-dev3, read November 26 about 8:23 AM EST:** its checkout was moved to f3414704 at 7:48 AM EST by someone outside this tree. f3414704 contains ecee4949 and f716ed40, and `/usr/local/bin/ai-pr-wait` points into the checkout, so the new commands are live. The install is **not** proven complete: the newest install stage report is for c01a7797 (November 25), the `install-stages` folder is empty, `ai-adopt-globals --check` reports DRIFT (3 changed lines) for all five agent instruction files, a search of the installed Claude instructions found no queue-first text, and `sudo -n true` answers "interactive authentication is required". A process search showed no installer running.
- PR 2890 proof: tests on Windows (edge-dev) and Ubuntu (edge-dev3); remaining failures also occur on unchanged code and are listed in the PR. Live: the installed command returned exit 4 on an open unqueued pull request (November 25, 10:58 PM EST). Results: [comment](https://github.com/popcre/ai-devops/issues/2869#issuecomment-7182191084). Suites not run on 4837, 916, hetz for that change.
- Second-opinion fixes: the side sessions report the suite passing on edge-dev, hetz and edge-dev3 for PRs 2891 and 2893; 4837 and 916 untested; no live engine call after the fixes.
- [Issue 2896](https://github.com/popcre/ai-devops/issues/2896) is open (`review-finding`, `fixer-deferred`).

## 4. What did not work

- edge-dev3 `update.sh` needs sudo, which requires interactive authentication. No AI enters a password; the install was left unfinished.
- `ai-task-gates check --before push` is an unknown action; use `ship`.
- `ssh hetz` as the default user is refused: user `ai`, key `916-alien`, identities-only, batch mode. Checkout `/worksp/ai-devops`.
- The first version of PR 2890 failed two Ubuntu tests (a removed router sentence; `not_queued` counted as success). Both fixed before merge.
- `tests/test-ai-pr-poll-guard-hook.sh` has one Windows failure (`reset-hard -C overrides cd`) that also occurs on unchanged code.
- `ai-pr-wait` started in the background from a worktree once exited 3, "cannot determine the repository"; `--repo popcre/ai-devops` worked. Cause not investigated.
- Git Bash ignores `TZ`; compute EST as UTC minus 5.

## 5. Root causes and findings

- Queue first with `bin/ai-gh pr merge <n> --auto`, then wait. `--allow-unqueued` is for deliberate waits.
- A checkout can be advanced while the protected install is incomplete; judge an Ubuntu install by its stage report and the globals check, not by `git log`.
- Second-opinion findings are in section 5 of the [Windows handoff](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0435Z-edge-dev-claude-windows-reviewer-install-followups.md). Its Ubuntu stop step is superseded by PR 2894: do not start it or task `task_5cc43dda`.

## 6. Open tasks (exact next steps)

### Task 1: install current main on the five computers

- Goal: every computer runs both repairs. [Issue 2898](https://github.com/popcre/ai-devops/issues/2898).
- Next action: re-read each installed receipt; where older than f716ed40, install by the protected route in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) (candidate worktree, declared installation task; Ubuntu `update.sh --installed-checkout <path> --expected-head <sha>`, Windows `bin/install-ai-devops-windows.ps1 -RepoPath <path> -ExpectedHead <sha> -AdoptGlobals`). Never `git pull` in an installed checkout. On edge-dev3 first check no other session is installing.
- Done when: all five receipts name f716ed40 or newer and the agent instructions check is clean on each.
- Resume branch: fresh from main. Blockers: **edge-dev3 is blocked** until a session has administrator authority there. Do the other four first.

### Task 2: prove the second-opinion tool (after: Task 1 on the computers it uses)

- Goal: the repair is complete. [Issue 2898](https://github.com/popcre/ai-devops/issues/2898).
- Next action: on 4837 and 916 run `bash tests/test-ai-review-simple.sh` in Git Bash; one live `ai-second-opinion` call on Windows and one on Ubuntu. Do not overlap a local run with a GitHub job on that computer.
- Done when: the suite exits 0 on both and both calls print an answer. Then, with Task 1 complete, close issue 2898 and delete this file and the two child handoffs.
- Resume branch: fresh from main.

### Task 3: settle the review finding on the Ubuntu stop test (independent)

- Goal: the new stop test is isolated and not racy. [Issue 2896](https://github.com/popcre/ai-devops/issues/2896).
- Next action: check for an automatic fix; otherwise verify both claims against [tests/test_ai_second_opinion.py](https://github.com/popcre/ai-devops/blob/main/tests/test_ai_second_opinion.py) and fix what is real without weakening the test.
- Done when: issue 2896 is closed with a merged fix or an evidenced reason, and the suite passes on Ubuntu and Windows.
- Resume branch: fresh from main.

## 7. Constraints and gotchas

- Branch and PR only; queue with `bin/ai-gh pr merge <n> --auto`. GitHub calls go through `bin/ai-gh` (they can take minutes).
- Design for and prove both operating systems. The repository is public.

## 8. Access and environment

`bin/ai-gh` is signed in on edge-dev. SSH from edge-dev to edge-dev3 works with the default key. No secret appeared in this session; secrets live in the 1Password vault `vibe_coding`.

## 9. Open questions and risks

- 2026-11-26: who advanced the edge-dev3 checkout, and why no stage report exists for it, is unknown.
- 2026-11-26: receipts on the other four computers may have changed since last read.
- 2026-11-25: whether finding 2896 is real is unverified.

## Child handoffs

- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0451Z-edge-dev-claude-close-nested-reviewer-install.md
- https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-26T0435Z-edge-dev-claude-windows-reviewer-install-followups.md

This file's task list replaces the two lists above where they differ.

## Self-audit

1. A newcomer can continue without asking: yes (sections 1 to 8). 2. As effectively as this session: yes (Landed, sections 3 to 6). 3. All relevant detail recorded: yes (sections 2 to 7 and 9). 4. Owner decisions: none; section 0 says so and no other part asks for a ruling. The edge-dev3 item is a blocker, not an owner question.

Posted by Claude chat "Diagnose why PRs wait before entering merge queue" (9945380b) on edge-dev
