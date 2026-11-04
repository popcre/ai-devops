---
issue: none # deferred work carries its own anchor: popcre/shared-db#5468 (ZCode identity gap); this file closes out the 2026-11-03 deferred-followups session and carries only its leftovers
status: OPEN
owner: mimo/wrapup-20261103-deferred-followups-closeout
---

# Deferred follow-ups landed; leftovers and a dark Windows CI lane — 2026-11-03/04 wrap-up

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None new — nothing in this workstream needs the owner.

**Already settled — do NOT re-ask:**

- **When the ZCode closeout identity gap gets picked up.** Owner (2026-11-03,
  in chat): take it "only if a ZCode session needs certified closeout".
  No such session has appeared. It stays parked; the fail-open blind spot it
  describes is documented as a known limitation on
  https://github.com/popcre/shared-db/issues/5468.
- **Which deferred item to land first.** Owner (2026-11-03, in chat): "ask
  Muse what you should do and keep in mind we don't want to add complexity to
  our ai-devops tooling". Muse chose the test-helper bash fallback (landed,
  see §3); the ZCode gap stays deferred. Do not re-open the choice.
- **Merging while advisory checks fail is allowed.** Owner ruling 2026-10-30
  (lean required checks): only checks that stop production-data damage or
  secret leaks may block a merge; everything else is advisory. This is why
  the two PRs in §3 merged with the failures described in §5.3. The Windows
  lane being dark (§5.3) is therefore a **repair task for the next session**,
  not a merge-approval question.

Nothing else in this workstream needs the owner. If this handoff is picked up
together with
https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-03T1727Z-edge-dev-mimo-deferred-followups-and-learnings.md
(the predecessor, still OPEN and kept — see §9), put the combined
business-question list (currently empty) to the owner in one message before
starting work.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery toolkit for a multi-model
AI coding workflow (plan → review → implement → test → review). It is not an
app or service: `bin/` CLI tools, lifecycle scripts, config, skills, templates,
docs and tests, used by Albert and AI coding sessions on Windows and Ubuntu
machines. https://github.com/popcre/ai-devops

- Canonical operating contract:
  https://github.com/popcre/ai-devops/blob/main/AGENTS.md
- Recovery procedure:
  https://github.com/popcre/ai-devops/blob/main/docs/restore-from-zero.md

## 2. What we set out to do this session, and why

Albert's instruction (2026-11-03/04): resume the deferred follow-ups recorded
in the predecessor handoff
(https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-03T1727Z-edge-dev-mimo-deferred-followups-and-learnings.md
§6). Put that file's section-0 question to Albert, then land **one** deferred
follow-up of his choice in a fresh worktree cut from `origin/main`, with
`ai-task-gates start --class code`, verification against that handoff's §6
gates, and a signed PR through the merge queue. Success = the chosen item's
verification gate passes and its PR merges through the queue.

Albert could not evaluate the two options technically and delegated the pick
to a Muse review, with the constraint "we don't want to add complexity to our
ai-devops tooling". Muse picked the test-helper bash fallback. The session
then landed it (and, at wrap-up, recorded the outcome and leftovers).

## 3. Current state — what is true right now

Landed on `main` and verified (do not redo):

| Work | PR | Landing commit |
|---|---|---|
| Test suite restored + MSYS bash resolver | https://github.com/popcre/ai-devops/pull/2329 | https://github.com/popcre/ai-devops/commit/16b60de470c125e1f70cf736abb6e1a32228ed5e |
| Predecessor handoff marked landed | https://github.com/popcre/ai-devops/pull/2333 | https://github.com/popcre/ai-devops/commit/228401b3dda53af30addbbf3b57d9269ed221718 |

- The chosen item's gate (predecessor §6.2) passes on edge-dev (Windows):
  `tests/reviewer_maintenance_cases.py` imports `resolve_bash` and its suites
  pass under **both** a plain PowerShell `python -m pytest` and
  `bash -lc python -m pytest` — `134 passed, 5 skipped, 5 subtests passed`
  in each shape. (4 of the skips are pre-existing platform skips; 1 is the
  glm subtest skip described in §5.4.)
- Scope of the change is exactly one file:
  https://github.com/popcre/ai-devops/blob/main/tests/reviewer_maintenance_cases.py
- Predecessor handoff updated in place (PR #2333) to mark its §6.2 landed and
  record the premise correction; its §6.1 (ZCode) remains deferred.
- No production tool was touched. Nothing is committed-but-unpushed. No PR is
  open. This session's worktrees were removed and its local branches deleted
  after merge. Zero shared-db claims were ever held this session (see §9 for
  the unproduced closeout receipt).

Not started (all deliberate, see §6): the ZCode identity gap, the dead
`Maintenance` cleanup, the glm delete-contract coverage, and the CI repair in
§5.3.

## 4. Everything we tried that did NOT work

1. **Trusting the predecessor's §6.2 premise** ("the file just needs the bash
   fallback swapped"). Baseline run on a fresh worktree: `1 error in 0.86s`,
   `FileNotFoundError: ... 'bin\ai-reviewer-issue'` in `setUpClass`. All 138
   tests errored at setup before any bash fallback was exercised. Lesson (same
   as predecessor §4.1): reproduce the exact failure before trusting a
   written diagnosis, even one in a handoff.
2. **Muse's first two verdicts** ("land neither" / "the helper does not exist,
   so Item A is new code"). Both were wrong because `ai-muse` reviews a
   private copy of the **local HEAD**, and the local checkout was 8 commits
   behind `origin/main` — `tests/bash_resolution.py` had been merged there
   (PR #2321). Pushed back with `git show origin/main:tests/bash_resolution.py`
   evidence; Muse corrected and approved the right scope. Lesson: when Muse's
   premise contradicts a handoff or `git show origin/main:...`, push back with
   evidence before acting.
3. **Bare `resolve_bash()` without the MSYS coreutils directory on PATH.**
   After the first edit, 12 tests failed with exit 127 (command not found):
   the raw MSYS bash (`Git\usr\bin\bash.exe`) preserves PATH order but does
   not add `/usr/bin`, so `readlink`, `env`, `dirname` vanished. The helper
   returns `msys_bin` for exactly this; it must be appended to PATH **after**
   any test shadow directory. With that wired in, all 12 passed.
4. **Assuming `bin/ai-glm` still had a bash `cmd_delete()`** (the test scrapes
   that function out of wrapper sources). `git show` of Stage F
   (https://github.com/popcre/ai-devops/commit/dd6916295e29f0bf01c9cd25cefb5976f500894c)
   shows `bin/ai-glm` rewritten to a 6-line dispatcher into
   `bin/ai-second-opinion`; the delete path is Python now
   (https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion,
   `cmd in (...) → "delete"` branch). `IndexError` on the source split. Fixed
   with an explicit `skipTest` (§5.4) rather than by resurrecting the old
   shape.
5. **`ai-shared-db-closeout-check --session-id ...` as the zero-claims
   proof.** Four attempts (PowerShell twice, Git Bash twice, one bounded with
   `timeout 300`) produced **no output at all** — the harness killed two
   attempts (`ChildProcess.kill`), the other two returned an empty file. No
   JSON receipt exists. The tool's own `--help` works. See §9 for the risk
   and §6 step 5 for the rerun.
6. **Running `bash tests/test-workflow-policy.sh` locally** to reproduce the
   CI failure in §5.3. Harness kill, then a 5-minute tool timeout, both with
   no captured output. Not reproduced locally; the CI evidence in §5.3 stands
   on its own (two PRs, same three failures).
7. **First `ai-gh pr create`** died with harness `ChildProcess.kill` and left
   no PR. Re-running with output redirected to a file succeeded
   (PR #2329 appeared). Same workaround later for `ai-gh pr checks` output.
8. **`Path.write_text` on Windows emits CRLF** (verified: `b'#!/usr/bin/env
   bash\r\n...'`). Both real Git bash entry points run CRLF fixture scripts
   fine (verified), but the new fixture is written with `newline="\n"` to
   match the repo's LF rule anyway.

## 5. Root causes and key findings

1. **Stage F left an orphaned test suite and dead code.**
   https://github.com/popcre/ai-devops/commit/dd6916295e29f0bf01c9cd25cefb5976f500894c
   ("Stage F: second opinions on the simple path; delete the old review
   engine", PR #2131) deleted `bin/ai-reviewer-issue` and its runner
   `tests/test-ai-reviewer-issue.sh`, but missed
   `tests/reviewer_maintenance_cases.py` — so `setUpClass`'s
   `shutil.copyfile(ROOT / "bin/ai-reviewer-issue", ...)` has been a
   guaranteed `FileNotFoundError` ever since, and all 138 tests (live
   `tools/reviewer_events.py` coverage included) have been dead. It also kept
   the `Maintenance` class + `main()` in
   https://github.com/popcre/ai-devops/blob/main/tools/reviewer_maintenance.py
   reachable only through that deleted CLI.
2. **Two live seam contracts the fixture stub now stands in for** (the tests
   assert these shapes, so a future real recorder must keep them):
   `tools/reviewer_maintenance.py:207` reads `VERSION="..."` out of
   `<toolkit>/bin/ai-reviewer-issue`, and `:512` runs
   `[AI_REVIEWER_BASH or bash, <toolkit>/bin/ai-reviewer-issue, "record",
   --lifecycle-state X --summary Y --details-file Z]`, requires exit 0, and
   parses `^ai-reviewer-issue: recorded ([A-Za-z0-9._-]+)$` from stdout; the
   four `test_record_candidate_*` tests then assert the `issue.json` the
   recorder wrote (`repository.root/head`, `join.run_id` (null when the event
   had none), `join.event_sha256`, `evidence.*` counters). The synthetic
   fixture (same style as the file's existing `bin/event-fixture` stub)
   implements exactly that.
3. **The Windows CI lane is dark on every recent pull request — pre-existing,
   unowned, and safety-adjacent.** Evidence from the two most recent code
   PRs, identical on both:
   - https://github.com/popcre/ai-devops/pull/2328 (merged):
     `fast-classifier / validate` FAIL
     (https://github.com/popcre/ai-devops/actions/runs/41726719518/job/126233315203),
     `windows-offline` FAIL
     (https://github.com/popcre/ai-devops/actions/runs/41726719518/job/126234171909),
     `verification-report` FAIL
     (https://github.com/popcre/ai-devops/actions/runs/41726719518/job/126234277749).
   - https://github.com/popcre/ai-devops/pull/2329 (this session):
     same three FAIL
     (https://github.com/popcre/ai-devops/actions/runs/41732872463/job/126254455764,
     https://github.com/popcre/ai-devops/actions/runs/41732872463/job/126255235883,
     https://github.com/popcre/ai-devops/actions/runs/41732872463/job/126255344106).
   Decoded from those logs:
   - `fast-classifier / validate` runs `bash tests/test-workflow-policy.sh`
     and fails one assertion: **"FAIL manifest exactly matches Bash
     discovery"** — `config/ci-suite-manifest.json` disagrees with the
     discovered `tests/test-*.sh` set (every other assertion passes, incl.
     "manifest exactly matches PowerShell discovery").
   - `windows-offline` ("Aggregate the Windows offline lane") fails
     fail-closed with `event=pull_request selection=success run_long=true
     sections=skipped complete=skipped` → "windows-offline: the twelve
     Windows sections reported skipped; failing closed." The section matrix
     jobs (`windows-offline-section (...)`) show `skipping` — **no Windows
     test section actually runs on pull requests**, yet these checks are
     `required=false` (advisory per the 2026-10-30 ruling), so merges land
     anyway.
   These failures are **not** caused by this session's change (identical on
   the previous merged PR) and could not be reproduced locally (§4.6).
4. **`bin/ai-glm` has no `cmd_delete()` any more** — Stage F rewrote it as a
   thin dispatcher into `bin/ai-second-opinion` (Python). The delete-metadata
   contract ("delete preserves metadata and provider when snapshot cleanup
   refuses") has no equivalent test on that Python path; `tests/test_ai_second_opinion.py`
   only smoke-tests `delete` exit code 0.
5. **`ai-muse` reviews a private copy of the local HEAD, not `origin/main`.**
   A stale checkout yields stale verdicts (§4.2). Same class of trap as
   predecessor §4.4 (two-dot diffs).
6. **On this machine the bare `bash` on PATH is the WindowsApps WSL stub** —
   reproduced live: running it prints "Windows Subsystem for Linux has no
   installed distributions" in UTF-16 and exits 1. `resolve_bash()`
   (https://github.com/popcre/ai-devops/blob/main/tests/bash_resolution.py)
   returns `Git\usr\bin\bash.exe` plus the `msys_bin` directory; both are
   needed (§4.3).

## 6. Exact next steps

1. **Repair the dark Windows CI lane (most urgent — everything else merges
   without Windows coverage today).** Reconcile
   `config/ci-suite-manifest.json`
   (https://github.com/popcre/ai-devops/blob/main/config/ci-suite-manifest.json)
   with Bash `tests/test-*.sh` discovery until the failing assertion in
   `tests/test-workflow-policy.sh`
   (https://github.com/popcre/ai-devops/blob/main/tests/test-workflow-policy.sh)
   passes, then find why `windows-offline-section` jobs report `skipping`
   while `RUN_LONG=true` (see the aggregate's env block in §5.3) and make the
   twelve sections schedule again. Declare `ai-task-gates start --class code`.
   You'll know it worked when: `bash tests/test-workflow-policy.sh` passes in
   full, and a fresh code PR shows the `windows-offline-section` jobs running
   (not `skipping`) with the `windows-offline` aggregate green.
2. **ZCode closeout identity gap** — only when a ZCode session next needs
   certified shared-db closeout (owner's condition, §0). Full scope, grammar
   locations and the fail-open-vs-fail-closed test requirement are in the
   predecessor handoff §6.1:
   https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-03T1727Z-edge-dev-mimo-deferred-followups-and-learnings.md#L150-L180
   (tracker: https://github.com/popcre/shared-db/issues/5468). You'll know it
   worked when: a fixture with a `ZCode chat sess_<uuid>` claim is counted by
   a second session's check (not skipped), and a ZCode session's own run
   resolves instead of erroring "session identity is missing".
3. **Dead `Maintenance` class + `main()` cleanup** in
   https://github.com/popcre/ai-devops/blob/main/tools/reviewer_maintenance.py
   (`Maintenance` around line 201, `main()` around line 662) — reachable only
   through the deleted `bin/ai-reviewer-issue`. The module's helpers
   (`physical`, `Blocked`, `digest`, `publish`, `snapshot`, `locked`) are live
   and imported by `reviewer_events.py`, `reviewer_credit_watch.py`,
   `glm_credit.py`, `bin/ai-deepseek-agent` — do not remove those. You'll
   know it worked when: nothing instantiates `Maintenance` any more, the dead
   tests in
   https://github.com/popcre/ai-devops/blob/main/tests/reviewer_maintenance_cases.py
   that only exercise it are gone or redirected, and the suite still passes
   in both invocation shapes (§3).
4. **glm delete-contract coverage on the `ai-second-opinion` path** — pin
   "delete preserves metadata and provider when snapshot cleanup refuses" for
   the Python delete path, mirroring the bash-wrapper test that now skips glm
   (see the `skipTest` in
   https://github.com/popcre/ai-devops/blob/main/tests/reviewer_maintenance_cases.py).
   You'll know it worked when: a test fails if the Python delete removes
   metadata when the sandbox cleanup refuses.
5. **Produce the shared-db zero-claims receipt this session could not** (§4.5,
   §9): run the installed `ai-shared-db-closeout-check` with session id
   `ses_ffe5e5c98c1f7ffeyBcNjIpiPg` on edge-dev and save its JSON receipt.
   You'll know it worked when: the receipt exists and reports zero owned open
   claims and zero owned preview/merge/production stages. (Expect zero — this
   session never touched shared-db.)

## 7. Constraints and gotchas in force

- Work on a branch + PR; never push to `main`; code goes through the merge
  queue; prose-only changes merge around it after `bin/ai-doc-safety` passes
  on the exact head (`gh pr merge --squash --admin`). Full contract:
  https://github.com/popcre/ai-devops/blob/main/AGENTS.md
- Every GitHub call goes through `bin/ai-gh` (machine-wide lock, spacing,
  quota back-off); every wait is bounded (`bin/ai-pr-wait <n>
  --fit-tool-call`, rerun on exit 2 / `STILL-WAITING`); no open polling loops.
- Declare the task class first (`ai-task-gates start --class <class>`), and
  run `bin/ai-task-gates check --before <action>` before pr-wait/ship. A
  refusal is reported `Blocked —`, never worked around.
- Sign every GitHub post: `Posted by MiMo chat <id> on <machine>` (`<id>` =
  `$MIMO_SESSION_ID`, or the session UUID from the memory path when that env
  var is empty; `unknown` only if neither exists).
- The canonical checkout is landing-only; write-capable work uses its own
  worktree cut from `origin/main`. Never `git pull` an installed checkout.
- Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>`
  before any commit (`git var GIT_COMMITTER_IDENT`).
- Windows tests run through Git Bash; keep LF endings; PowerShell 5.1-safe
  argument passing. Platform notes:
  https://github.com/popcre/ai-devops/blob/main/docs/development.md
- Reviewer tooling runs on **both** Ubuntu and Windows — state which OS a
  problem happened on and which OSes the change runs on (platform brief
  printed by `ai-task-gates start`).
- Harness quirk on this machine: long or chatty shell commands can die with
  `ChildProcess.kill`. Workaround: redirect output to a file under the temp
  directory and read it back; bound long tools with `timeout`.
- `HANDOFF.d/` discipline (https://github.com/popcre/ai-devops/blob/main/AGENTS.md):
  three-line contract block at the top of every file; never edit another
  session's file; never rewrite the root `HANDOFF.md`.

## 8. Access and environment

- Machine: edge-dev (Windows; Git Bash + PowerShell 7). Python 3.13.15,
  pytest 9.1.1 on PATH.
- Git for Windows in its standard install location (Git root below `git.exe`'s
  parent); the raw MSYS bash that preserves PATH order is `usr/bin/bash.exe`
  under that root (the `bin/bash.exe` wrapper bootstraps
  `/mingw64/bin:/usr/bin` ahead of the inherited PATH).
- GitHub: `gh` through `bin/ai-gh` only. Both PRs this session merged fine
  while `ai-gh` reported "quota unknown; retaining spacing and refusal
  back-off" — the transport still worked.
- Secrets live in the 1Password `vibe_coding` vault — names only, never
  values. None appeared this session.
- Muse second opinions via `ai-muse` (session name used:
  `deferred-followup-choice`). Remember: it reads local HEAD (§5.5).
- Task classes declared this session: `code` (PR #2329), `prose` (PR #2333
  and this handoff).

## 9. Open questions and risks

- **The Windows test lane is dark on every pull request** (§5.3) and merges
  land anyway under the lean-required-checks ruling. Until step 1 in §6 is
  done, Windows test evidence for any change is unproven. This is the
  strongest safety-adjacent item in this file.
- **The ZCode fail-open skip is live** (a shared-db closeout check can report
  clean while a ZCode-owned claim is invisible) until §6 step 2 runs.
  Documented as a known limitation on
  https://github.com/popcre/shared-db/issues/5468.
- **No `ai-shared-db-closeout-check` receipt exists for this session**
  (§4.5): the zero-claims state is true by session history (no shared-db
  commands, no claims ever issued) but unproven by tool receipt. §6 step 5
  closes this.
- **The glm delete-metadata contract is only smoke-tested** on the new
  `ai-second-opinion` path (§5.4) — a regression there would pass CI today.
- This file has `issue: none`, so `ai-housekeeping` will report it
  `UNPROVABLE` — expected and honest; its items carry
  https://github.com/popcre/shared-db/issues/5468 and §6's steps as anchors.
- The predecessor handoff
  (https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-03T1727Z-edge-dev-mimo-deferred-followups-and-learnings.md)
  is **kept OPEN on purpose** and must not be deleted under the successor
  rule: it still holds decisions and dead ends (its §4, §5, §9) that exist
  nowhere else, and its §6.1 is the authoritative ZCode scope. Do not edit
  it further; carry its obligations forward here or in a plan.
- Decisions dated so a later session cannot unknowingly contradict them:
  2026-11-03 — Muse's scope guard-rails for this workstream were "one test
  file only, no CI runner/manifest wiring, flag the dead `Maintenance` class
  for a separate cleanup". The CI-runner omission is why the suite still has
  no `test-*.sh` runner and is therefore not exercised by CI; adding one is
  step 3's territory (or a small rider on step 1) and was deliberately not
  done here.

## Part (b) — sub-agent blocks

N/A — this session dispatched no sub-agents (no worker agents were spawned).
Two `ai-muse` consult rounds (`deferred-followup-choice`) were second-opinion
decision support only, not delegated implementation; their verdict trail is
recorded in §4.2 and §0. If a later session resumes this workstream with
sub-agents, append per-sub-agent blocks here or in a new file of its own.
