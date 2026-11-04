# Plan: close out popcre/ai-devops#2284 (obsolete review finding)

## VERDICT (read first): OBSOLETE — close as not planned, no code change

Evidence (checked 2026-11-04 on main f2b4f5bd):
- F1 (test argv off-by-one) was a reviewer false positive: `python -c PROG a b c` sets `sys.argv = ['-c','a','b','c']` (program text is not in argv), so `sys.argv[1:3]` / `sys.argv[3]` at tests/test-github-request-qualification.py:1001-1005 are correct. `python3 -I tests/test-github-request-qualification.py` on main: "Ran 62 tests ... OK".
- F2 (missing Windows functions) is fixed: tools/github-requests/windows_event.py:120 `active_completion_io` and :157 `active_harness_exec` exist (landed in PR #2289, commit 6932559d).
- F3 (wake harness unreachable under admitted profiles) is a coverage note on GitHub-request measurement/qualification machinery. Its parent programme #658 and #660 were closed NOT_PLANNED on 2026-11-04 under the skinny rework. Adding reachability or tests for dormant measurement code goes against owner rulings 2026-10-29/30 (docs/owner-rulings.md: fewest moving parts, reviews advisory, only data-safety/secret-leak checks block).
- Source PR #2283 merged 2026-11-01; fixer deferred it (label `fixer-deferred`).

## STATUS
| Step | State |
|---|---|
| 1 Recheck evidence on current main | ⬜ open |
| 2 Close #2284 as not planned with signed comment | ⬜ open |
Start at step 1.

## 1. Ultimate goal
Clear the review-finding queue of stale items so the automatic fixer and Albert see only real work. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Application
popcre/ai-devops: Albert's AI tooling toolkit (scripts, skills, CI). tools/github-requests/ is GitHub-API-usage measurement code; bin/ai-blocker-watch is the issue blocker watcher.

## 3. Trigger
Automated advisory review (StepFun, run 41336928715) on PR #2283 filed #2284 with F1-F3; review-fixer run 41337540562 deferred it because the PR was already closed.

## 4. Scope
In: verify, then close #2284. NOT in: any code change; removing the measurement code (separate skinny-cleanup decision, not this issue); reopening #658/#660.

## 5-6. Current state / findings
See VERDICT. No work in progress, nothing committed.

## 7. Rejected approaches
- Fix F1: rejected, the finding is wrong.
- Implement F2: already done in #2289.
- Make wake harness reachable / add tests (F3): rejected, parent programme not planned; adds moving parts for unused machinery.

## 8. Decisions
Locked: no code change; close as not planned. Open: none.

## 9. Steps
1. In a clean checkout of origin/main run `grep -n "^def active_" tools/github-requests/windows_event.py` (expect both functions) and `python3 -I tests/test-github-request-qualification.py` (expect OK). Confirm `gh issue view 658 -R popcre/ai-devops --json stateReason` = NOT_PLANNED. Gate: all three hold; if any fails, stop and re-plan F1/F2 only.
2. `gh issue close 2284 -R popcre/ai-devops --reason "not planned" --comment "<evidence summary above>\n\n$AI_GH_SIGNATURE"`. Gate: `gh issue view 2284 --json state,stateReason` shows CLOSED/NOT_PLANNED.

## 10. Tests
None new. Existing tests/test-github-request-qualification.sh must stay green (already is).

## 11. Constraints
Sign GitHub posts with `$AI_GH_SIGNATURE`; use the popcre-appropriate identity; reviews advisory only; quote times in EST.

## 12. Access
`gh` authenticated for popcre/ai-devops. No secrets needed.

## 13. Done / risks
Done: #2284 closed not planned with signed evidence comment. Risk: none material; reopen if measurement programme is revived. No HANDOFF.d entry: plan is close-out only and lives in scratch per caller's read-only instruction.

## Self-audit
1. Fresh session can execute: yes — sections VERDICT, 9, 12 give exact commands and gates.
2. Carries all reasoning incl. rejected options: yes — VERDICT, 7.
3. Goal clear for judgment calls: yes — section 1 and step 1 stop rule.
Gap noted: no HANDOFF.d backlink (caller forbade repo writes).
