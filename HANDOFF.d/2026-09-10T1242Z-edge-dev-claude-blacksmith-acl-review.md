---
issue: 373
status: OPEN
owner: edge-dev / claude (was worktree edge-dev-win-runner-status-e5faf9)
---

# Blacksmith Windows CI lane — live-proven, one failure needs independent review

## 0. Decision from Albert: APPROVED (2026-09-10) — get the review

**Albert confirmed: yes, request independent review** for a fix to
`bin/ai-gemini`'s `secure_private()` function and `tests/test-ai-gemini.sh`'s
matching ACL check. This is the only way to clear the last failing Blacksmith
section. This repo's `AGENTS.md` requires independent review before anyone
touches reviewer wrappers, evidence tools, or safety tests —
`secure_private()` sets the Windows ACL that protects failure evidence, so it
qualifies. Tracked in
[popcre/ai-devops#373](https://github.com/popcre/ai-devops/issues/373).

**Next session: do not re-ask this question — go straight to lining up the
review** per the steps below.

Get a second reviewer (Codex, Grok, or another qualified reviewer per this
repo's reviewer roster) to look at issue #373's two
hypotheses and pick a fix. If Albert says no or "later": leave issue #373
open and the Blacksmith lane running with 3 of 4 sections green; this is not
blocking normal use of the lane, since Blacksmith stays opt-in/manual anyway.

## 1. What shipped and is proven live (not just YAML that parses)

- **PR #367** (merged earlier this workstream): added
  `.github/workflows/windows-offline-blacksmith.yml` (manual
  `workflow_dispatch` only — never wired to any automatic trigger, per
  Albert's 2026-09-10 decision that Blacksmith is a paid opt-in choice, never
  an automatic fallback) and `.github/workflows/windows-queue-watchdog.yml`
  (comments on a slow-starting PR telling Albert to ask Claude to route it to
  Blacksmith — Albert has no runner-queue visibility of his own, so this is
  his only signal).
- **Proved live**, not just validated as well-formed YAML: dispatched two real
  runs of `windows-offline-blacksmith.yml` against `origin/main` and watched
  them to completion via the GitHub API (job-level `queued` → `in_progress` →
  `completed` transitions observed directly):
  - Run 1: https://github.com/popcre/ai-devops/actions/runs/34449903830
    (before the TEMP fix below) — sections 1 and 3 failed, 2 and 4 passed.
  - Run 2: https://github.com/popcre/ai-devops/actions/runs/34453239757
    (after the TEMP fix) — sections 1, 2, 4 passed; section 3 still failed.
  - Confirmed both failures are Blacksmith-specific, not generic flakiness, by
    checking that the same test suite passed cleanly on a recent GitHub-hosted
    run of the same code (run `34448860758`, for PR #367 itself).
- **`windows-queue-watchdog.yml` has never been exercised against a real slow
  PR run in production.** It has not been proven to actually post a comment
  under real conditions — only read for correctness. If Albert wants that
  proven live too, that is a separate, not-yet-done task (not blocking, since
  the workflow is passive and low-risk).

## 2. Bug found and fixed: TEMP path length (PR #372, merged)

Section 1 (`tests/test-ai-kimi.sh`, specifically the "named review resumes in
its original directory" check) failed on Blacksmith run 1 because Blacksmith's
default `runneradmin` TEMP directory
(`C:\Users\runneradmin\AppData\Local\Temp`) is deeper than GitHub-hosted's
default (`D:\a\_temp`), and these suites nest their own `mktemp` trees below
it — long enough to cross Windows' 260-character path limit and fail
silently. Same root cause as a documented prior incident (repo memory:
`long-tmpdir-fake-flakes.md`).

Fix: added a step to `.github/workflows/windows-offline-blacksmith.yml` that
pins `TEMP`/`TMP` to `C:\t` via `GITHUB_ENV` before the test step runs.
Committed `4e7634c8` on branch `claude/blacksmith-short-tempdir-fix`, opened
as PR #372, merged via merge queue (`mergedAt: 2026-09-10T08:04:20Z`, merge
commit `6c3042db29b6a98320bdc503d7d976fbfcea9367`). **Verified fixed** in run
2 above — section 1 now passes.

## 3. Bug found, NOT YET fixed: ACL check fails on Blacksmith (issue #373)

`tests/test-ai-gemini.sh` line ~178, check `"preserved failure evidence uses
a private Windows ACL"`:
```
CURRENT_ACCOUNT="$(powershell.exe ... '[Security.Principal.WindowsIdentity]::GetCurrent().Name' | tr -d '\r\n')"
check '...' "icacls \"...\" | grep -Fqi \"$CURRENT_ACCOUNT:(F)\""
```
fails identically on both qualification runs (job `102783038923` in run 1,
job `102793580972` in run 2), unaffected by the TEMP fix. No diagnostic
output is printed in this check's failure path, and there's no way to get a
shell into the ephemeral Blacksmith machine after the fact to inspect
further without a code change.

`bin/ai-gemini` line 71, `secure_private()` grants the ACL via the raw SID
(`icacls ... /grant:r "*${sid}:(F)"`), while the test's own check reads
`icacls`'s output text for the resolved display **name**.

**Independent review obtained (Codex, plan-review, 2026-09-10) — verdict
REJECT / hypothesis 1 confirmed.** Full report:
`.ai/reviews/codex-plan-review-20260910T162556-5686-2968.md` (local review
evidence, Git-ignored by design — not committed; also posted as a comment on
[issue #373](https://github.com/popcre/ai-devops/issues/373#issuecomment-5622033494)).
Findings:
- **This is a false-negative test, not a real security gap.** `icacls`'s exit
  status is the *last* command in `secure_private()`, so it does propagate as
  the function's return value — my original write-up in this file was wrong
  to say the exit code is silently discarded. The artifact-link check earlier
  in the same test already proves `secure_private()` returned success, so the
  ACL grant call *is* succeeding on Blacksmith. The test's `grep` for a
  resolved display name is just too narrow for how that runner's identity
  resolves.
- **Two additional real gaps Codex found while reviewing:** (a) the test
  doesn't actually prove privacy — it only checks the current user has Full
  Control, never that no *other* identity also has permissive access, and
  `icacls .../grant:r` only replaces that SID's own explicit grants, so
  pre-existing grants to other identities can survive; (b) if production code
  changes, the wrapper's version constant and the test's matching assertion
  both need bumping (`bin/ai-gemini` line ~15, `tests/test-ai-gemini.sh` line
  ~84).
- **Recommended fix, in order:** (1) one throwaway Blacksmith dispatch with a
  temporary diagnostic branch of the test — print current SID/name, `icacls`
  status/output, and ACE identities normalized to SIDs (never artifact
  contents) — to confirm before touching anything permanent; (2) change the
  test to match by SID instead of display name; (3) add a check that rejects
  unexpected Allow ACEs and confirms inheritance is disabled; (4) add
  regression tests for a failing `icacls`, a pre-seeded permissive ACE,
  disabled inheritance, and SID-only output.

**Still not fixed — this plan-review is not the required final review.**
`AGENTS.md` requires a **read-only exact-head final review before merge** for
any actual diff to this reviewer-safety path; the plan-review above only
validated the approach before code was written. The next session should
write the fix per the recommendation above, then run
`bin/ai-review codex final-check` (or `claude final-check`) against that real
diff before merging.

The Blacksmith lane already runs `-ExcludeReviewerSafety`, so this does not
touch the reviewer-safety CI path itself; it's the general offline suite's
Gemini-provider evidence self-check, and it fails only on Blacksmith.

## 4. Docs touched this session

- `tests/verification/repo-throughput/issue-210-blacksmith-baseline-20260910.md`
  — its old "Next step" section described the abandoned automatic-orchestrator
  design; struck through and replaced with what actually shipped, pointing
  here and to issue #373. No further action needed on that file.

## 5. Repo state

- Branch `claude/blacksmith-short-tempdir-fix` — merged (PR #372,
  `6c3042db29b6a98320bdc503d7d976fbfcea9367`); safe to delete, both locally
  and on origin.
- Branch `blacksmith-migration-9a7f974` (from the earlier, closed PR #355) —
  left alone; an earlier session's explicit decision, not this session's to
  reverse.
- Issue #210 ("Split Windows verification into bounded parallel sections") is
  already **CLOSED** — it's the issue named in this workstream's PR titles,
  but the residual work here (the ACL review) is tracked under the new issue
  #373 instead, since reopening #210 for unrelated follow-up would be wrong.
- Worktree `C:\repos\ai-devops\.claude\worktrees\edge-dev-win-runner-status-e5faf9`
  — evaluate via the `cleanup-worktree` skill once this handoff's docs/HANDOFF
  commit is pushed and confirmed on `main`.

## 6. Exact next action for the next session

The section-0 decision is resolved and the plan-review is done (section 3
above). Remaining:

1. Implement the fix per section 3's recommendation: SID-based diagnostic
   dispatch first, then the SID-match + unexpected-ACE-rejection fix, then
   the regression tests.
2. Get the required **exact-head final review** (`bin/ai-review codex
   final-check` or `claude final-check`) on the real diff before merging —
   the plan-review already done does not substitute for this.
3. Re-dispatch `windows-offline-blacksmith.yml` against `main` to confirm all
   4 sections pass.
4. Close issue #373 and delete this handoff file once that's proven.
5. Optionally (not blocking): dispatch a genuinely slow PR run to prove
   `windows-queue-watchdog.yml` posts its comment in production.
