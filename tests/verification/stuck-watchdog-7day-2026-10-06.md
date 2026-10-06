# Stuck-work watchdog seven day check — 2026-10-06

Owner: popcre/ai-devops#1011. Window: 2026-09-29 through 2026-10-06. Result: **FAIL; live proof remains open**.

## Live run evidence

- edge-dev3 has 51 `stuck-watchdog-*.log` files, from 2026-09-29 11:41:57 UTC through 2026-09-30 05:14:14 UTC. Median gap between those files is 20 minutes; one gap exceeds 30 minutes (maximum 72.17 minutes). Its `stuck-report.json` was last generated at the final run.
- The current configuration assigns the watchdog to hetz. At 2026-10-06 14:07 UTC, hetz had zero `stuck-watchdog-*.log` files. Its BlockerWatch tick log contained 866 `stuck watchdog: no app token on this machine` failures. `ai-gh-app-auth status` returned 3: app private key absent. The scheduled tick exists, but the watchdog does not execute successfully.
- The daily notice label has issues for September 29 (#1056) and September 30 (#1155), with no later notice found as of this check.

## Step 6 measures

- Median from first red required check to green or recorded owner decision: **unavailable**. The watchdog did not run for the full window and the retained final report is a point-in-time snapshot, not a per-PR transition history. No value is imputed.
- PRs red over two hours with neither green nor a recorded owner decision: **unavailable** for the same reason. The final edge-dev3 report still listed nine stuck PRs; it cannot establish the full-week count.
- Seven day cadence: **failed**. Recorded cadence ended after approximately 17.5 hours, followed by a six day gap.

## Fixer outcome sample

The `fixer-attempted` label in ai-devops included 45 issues in the retrieved list. Checked live comments on #1052, #1054, #1094, and #1153: each has a fixer result comment. #1052 reported its branch fix but an unresolved merge conflict; #1054 reported checks still running; #1094 reported the required check already green; #1153 reported checks green and branch mergeable. These comments do not prove the PRs were delivered. The shared-db `fixer-attempted` list was empty.

## Required follow-through

Restore the pop-ai-watchers app credential on hetz through the installation and assigned-review gates; prove a successful live watchdog tick there. Then gather a fresh continuous seven day window and calculate the two Step 6 measures from timestamped PR/check and owner-decision evidence. Keep #1011 open. The previously named shared-db plan path is absent from current `origin/main`, so no STATUS rows were changed there.
