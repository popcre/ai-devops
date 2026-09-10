---
issue: 373
status: OPEN
owner: edge-dev / claude (was worktree edge-dev-win-runner-status-e5faf9)
---

# Blacksmith Windows CI lane — live-proven, one failure needs independent review

## 0. Decision needed from Albert (the one blocking item)

**Does Albert want independent review requested for a fix to `bin/ai-gemini`'s
`secure_private()` function and `tests/test-ai-gemini.sh`'s matching ACL
check?** That is the only way to clear the last failing Blacksmith section.
This repo's `AGENTS.md` requires independent review before anyone touches
reviewer wrappers, evidence tools, or safety tests — `secure_private()` sets
the Windows ACL that protects failure evidence, so it qualifies. Tracked in
[popcre/ai-devops#373](https://github.com/popcre/ai-devops/issues/373).

If Albert says yes: get a second reviewer (Codex, Grok, or another qualified
reviewer per this repo's reviewer roster) to look at issue #373's two
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

## 3. Bug found, NOT fixed: ACL check fails on Blacksmith (issue #373)

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

Root of the mismatch is likely `bin/ai-gemini` line 71, `secure_private()`:
it grants the ACL via the raw SID (`icacls ... /grant:r "*${sid}:(F)"`), not
the display name the test greps for, and never checks `icacls`'s own exit
code (`>/dev/null 2>&1`, no `||` fallback). Two live hypotheses, not yet
distinguished:
1. Blacksmith's runner account SID doesn't resolve to a display name the way
   GitHub-hosted's does — `icacls` prints the raw SID, the grant succeeded,
   and this is a false-negative test on Blacksmith specifically.
2. `icacls` is silently failing on Blacksmith due to a different privilege
   model there — the ACL is never actually applied, a real (if narrow)
   security gap on that runner class.

**Why I didn't fix or even instrument this myself:** `bin/ai-gemini`'s
`secure_private()` and `tests/test-ai-gemini.sh`'s matching check are
reviewer-safety / evidence-protection code. This repo's `AGENTS.md` requires
independent review for changes here, even a minor diagnostic addition — see
decision needed in section 0.

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

1. Ask Albert (or check whether he already answered) the question in section 0.
2. If yes: get independent review on issue #373's two hypotheses, apply
   whichever fix it recommends to `bin/ai-gemini` and/or
   `tests/test-ai-gemini.sh`, then re-dispatch
   `windows-offline-blacksmith.yml` against `main` to confirm all 4 sections
   pass.
3. Close issue #373 and delete this handoff file once that's proven.
4. Optionally (not blocking): dispatch a genuinely slow PR run to prove
   `windows-queue-watchdog.yml` posts its comment in production.
