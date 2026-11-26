---
issue: none  # follow-ups left after closed issues 2889 and 2892; scope freeze at wrap-up barred opening a new issue
status: OPEN
owner: claude/handoff-windows-abort
---

# Second-opinion tool: install and remaining proof after two Windows fixes

Written 2026-11-25, 11:35 PM EST, on edge-dev, by Claude Sonnet 5.5.

## 0. Business decisions only the owner can make

None. Nothing in this workstream needs the owner.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is the public toolkit that sets up the AI coding tools on POP Creations development computers. The file
[bin/ai-second-opinion](https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion) lets one AI ask another AI engine (codex, opencode, antigravity, harness) for a second opinion. It runs on Ubuntu (hetz, edge-dev3) and Windows (4837, 916, edge-dev).

## 2. What we set out to do, and why

1. Make reviewer input and files UTF-8 on Windows (issue [2889](https://github.com/popcre/ai-devops/issues/2889)).
2. Stop the Windows `abort` command recording a session as aborted while its engine was still running (issue [2892](https://github.com/popcre/ai-devops/issues/2892)).

## 3. Current state

- Fix 1: merged, [PR 2891](https://github.com/popcre/ai-devops/pull/2891), commit [e0e547f0](https://github.com/popcre/ai-devops/commit/e0e547f0). Issue closed.
- Fix 2: merged, [PR 2893](https://github.com/popcre/ai-devops/pull/2893), commit [07f76f9e](https://github.com/popcre/ai-devops/commit/07f76f9e8366d1c11e88c3e9eaea927541072d33). Issue closed. Verified on `origin/main`.
- `bash tests/test-ai-review-simple.sh` passed for both on edge-dev, hetz and edge-dev3 before merge. The three new Windows abort tests in [tests/test_ai_second_opinion.py](https://github.com/popcre/ai-devops/blob/main/tests/test_ai_second_opinion.py) fail without the fix and pass with it.
- Not done: this session installed neither fix on any computer and did not check which version any computer currently has installed. 4837 and 916 were not tested. No live engine call was made after either fix; [AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md) says a second-opinion tool repair is complete only when tests pass and one live call of the repaired tool succeeds, and asks for install on both operating systems.
- A suggested follow-up task ("Check Ubuntu abort stops non-Codex engines") was offered in the app and had not been started. The offer expires after a week, so step 3 below is the durable record.

## 4. What did not work

- `ssh hetz` as the default user was refused. Working form: `ssh -i ~/.ssh/916-alien -o IdentitiesOnly=yes -o BatchMode=yes ai@hetz`; for edge-dev3, `ssh -o BatchMode=yes ahazan@edge-dev3`.
- Editing Python files through shell heredocs broke quoting; writing an edit script to a file and running it worked.
- `bin/ai-pr-wait 2893 --timeout-minutes 30`, started in the background from the worktree, exited 3 with "cannot determine the repository; pass --repo". Adding `--repo popcre/ai-devops` worked. The cause was not investigated.

## 5. Root causes and findings

- Windows `abort` only checked for survivors where `os.killpg` exists, and `taskkill /T` on an already ended parent misses its orphaned children. The fix is `stop_windows_trees` in `bin/ai-second-opinion`.
- On Windows, `os.kill(pid, 0)` sends CTRL_C_EVENT; never use it as a liveness probe.
- Only the codex engine records `child_pid`; other engines record only the tool's own `pid`.
- Remaining limit: on Windows a grandchild whose intermediate parent already ended cannot be traced (Windows Job Objects would solve it).
- By code reading only, not reproduced: on Ubuntu, non-codex engines appear to run in their own process session, so `abort` may report aborted while the engine survives.
- A killed tool leaves its `.lock` directory behind (behaviour that predates these fixes).

## 6. Next steps

1. Check which commit each reviewer computer has installed. Where it predates 07f76f9e, install by the protected route in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) (Ubuntu `update.sh` from a candidate worktree; Windows `bin/install-ai-devops-windows.ps1`, authorized with `ai-task-gates authorize-install`). Never `git pull` in an installed checkout. Worked when the installed receipt on hetz, edge-dev3, 4837, 916 and edge-dev names 07f76f9e or newer.
2. On 4837 and 916 run `bash tests/test-ai-review-simple.sh` (Git Bash), then one live `ai-second-opinion` call per operating system. Worked when the suite exits 0 and the live call returns an answer.
3. On hetz or edge-dev3, try to reproduce the Ubuntu `abort` gap with a non-codex engine. If confirmed, open an issue, fix it, add a test, keep `stop_windows_trees` working, and merge. Worked when the engine process is gone, or the session stays `running`, in every case. If not reproduced, record why.
4. Delete this file once steps 1 to 3 are proven.

## 7. Constraints and gotchas

- Branch and PR only; merge through the queue with `bin/ai-gh pr merge <n> --auto`.
- Design for and prove both operating systems.
- Do not overlap a local full test series with a GitHub job on the same Windows computer.
- The repository is public.

## 8. Access and environment

`gh` through `bin/ai-gh` was signed in on edge-dev. SSH forms are in section 4. No secret was used or exposed; secrets live in the 1Password vault `vibe_coding`.

## 9. Open questions and risks

- 2026-11-25: whether any computer already has these commits installed is unknown.
- 2026-11-25: the Ubuntu abort gap is a hypothesis.

## Self-audit

1 and 2 (newcomer can continue): yes, sections 1 to 8. 3 (every relevant detail): yes, sections 3 to 6 and 9. 4 (owner decisions): yes, section 0; no sentence elsewhere needs an owner ruling.
