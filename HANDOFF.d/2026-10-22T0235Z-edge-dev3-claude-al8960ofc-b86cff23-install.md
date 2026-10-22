# Handoff — finish the b86cff23 toolkit install on al8960ofc

## 1. Goal
Install ai-devops release `b86cff23368fe4a2aa2026a8e0ddeea81b38279c` on Windows host al8960ofc (ssh alias `4837`) through the protected installer with `-AdoptGlobals`. Done when `bash bin/ai-adopt-globals --check` in the installed checkout prints CLEAN for Claude, Codex, ZCode and MiMo and the managed `ai-task-gates` launcher says `source-sha=b86cff23…`.

## 2. Current state (2026-10-21 10:35 PM EDT)
- al8960ofc is installed and receipted at `81b4b1bd` (#1881 Phases 1–5). All four globals were proven CLEAN at about 3:00 PM EDT.
- **Blocked by the reviewer observation-week freeze**: [plan_reviewer-observation-week.md §11](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-observation-week.md) forbids any installer run on a review host while the window file is live (#1948). Do not run the install until that freeze has ended.
- Prepared on the host (left in place for resume): the review worktree `rcv-rev-b86cff23` at b86cff23 and the installation candidate `rcv-cand-b86cff23`. The installation task was declared at 81b4b1bd, then the candidate was advanced to b86cff23. Both are under the host's `ai-devops-worktrees` folder.
- The Linux and Windows release live check (`ai-release-live-check fleet --target-head b86cff23…`) passed at about 3:10 PM EDT. Both commit statuses are posted.
- The Muse exact-head final-check with `--tests` was killed by a desktop-app crash. It was relaunched as the Windows scheduled task `rcv-b86` (log `~/rcv-b86.log` on the host). Its outcome is unverified: at 10:30 PM EDT SSH connected, but the Git Bash login shell returned no output.
- An abandoned earlier attempt by another session left `inst-cand-b86cff23` and `inst-review-b86cff23`, which hold a Codex REJECT for missing cross-platform tests. It is not ours; leave it alone.

## 3. Supported recovery path (proven for 81b4b1bd)
A checkout advanced past its receipt is not a legacy migration. Declare `ai-task-gates start --class installation` in a candidate checked out at the **receipt SHA** (the `source-sha` in `~/.local/bin/ai-task-gates`), then advance the candidate to the target. `authorize-install` then reports "installed checkout advanced … within the reviewed release range". The gate also requires:
1. the APPROVE report's lifecycle record to carry passing `--tests` evidence (an APPROVE without `--tests` is refused);
2. a passing `ai-release-live-check fleet` from an Ubuntu review host whenever shared review code changed.
See [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) ("authorize-install start_head" gotcha).

## 4. Next steps (only after the freeze ends)
1. Get the Git Bash shell on 4837 answering again: SSH in and run a trivial `bash -l` command.
2. Read `~/rcv-b86.log`. If it shows EXIT 0 and APPROVE, use that report in `rcv-rev-b86cff23/.ai/reviews/`. Otherwise rerun `ai-review muse final-check --implementer claude --assert-head b86cff23… --tests "bash tests/test-ai-codex-review.sh && bash tests/test-codex-reviewer-home-cleanup.sh && bash tests/test-windows-job-run.sh && bash tests/test-ai-review-snapshot-bounded-history.sh"` from the review worktree.
3. If main has moved and the target is re-pinned, redeclare in a fresh candidate at the receipt SHA and rerun the live check.
4. From the candidate: `ai-task-gates authorize-install --target-head <T> --installed-checkout /c/repos/ai-devops --installed-launcher /c/Users/ahazan2/.local/bin/ai-task-gates --review-report <R> --reviewer-approval <R>`.
5. `powershell -NoProfile -ExecutionPolicy Bypass -File <candidate>\bin\install-ai-devops-windows.ps1 -RepoPath C:\repos\ai-devops -ExpectedHead <T> -AdoptGlobals`.
6. Verify with `bash bin/ai-adopt-globals --check` (four CLEAN lines) and the launcher's `source-sha`. Then remove the `rcv-*-b86cff23` worktrees and the `rcv-b86` scheduled task.

## 5. Tried and failed
- Same-SHA candidate: refused with "Empty release needs an installed receipt or explicit reviewed legacy migration."
- `--legacy-migration`: refused with "Legacy migration requires a launcher without a receipt." (correct: the launcher has a receipt)
- Muse APPROVE without `--tests`: refused for missing local-tests evidence.

## 6. Risks
Other sessions fast-forward the installed checkout. Re-read its HEAD and the launcher receipt immediately before declaring.

## 7. Owner / issue
Part of #1881 rollout ([ruleset trim plan](https://github.com/popcre/ai-devops/blob/main/plan_ruleset-trim-and-enforce.md)). Posted by Claude chat 23395d21-e160-4fd1-b1bd-8b6d3139c898 on edge-dev3.

## 8. Verification evidence
81b4b1bd: the installer exited 0 and adopt-globals printed four CLEAN lines at about 3:00 PM EDT 2026-10-21.

## 9. Self-audit
A stranger can resume: the target, the blocker, the host state, the exact commands, the failure modes and the done check are all stated above.
