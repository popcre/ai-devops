---
issue: none # deferred follow-ups carry their own trackers: popcre/shared-db#5468 (ZCode identity gap); the test-helper bash fallback landed 2026-11-03 as PR #2329
status: OPEN
owner: mimo/wrapup-20261103-deferred-followups
---

# Deferred follow-ups and session learnings — 2026-11-03 wrap-up

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **When to pick up the deferred follow-up below.** Recommendation (owner
  delegated the pick to a Muse review, 2026-11-03): the ZCode identity gap
  only when a ZCode session next needs certified shared-db closeout. Blocks:
  nothing. A wrong guess costs only idle risk (§9); nothing is waiting.
  The test-helper bash fallback is **done** — see §6.2.

**Already settled — do NOT re-ask (2026-11-03):**

- "Fix the two test defects, defer the ZCode identity gap" — decided by the
  owner after a Muse review ("do not fix all three now"), then the owner said
  "spin up subagents to do each" for the two test fixes. Both fixes are merged.
- The ai-housekeeping probe fix is complete, installed and live-verified — do
  not redo it (see §3).

Nothing else in this workstream needs the owner. If this handoff is picked up,
put the one open item above to Albert in a single message before starting work.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery toolkit for a multi-model
AI coding workflow (plan → review → implement → test → review). It is not an
app or service: `bin/` CLI tools, lifecycle scripts, config, skills, templates,
docs and tests, used by Albert and AI coding sessions on Windows and Ubuntu
machines. https://github.com/popcre/ai-devops

## 2. What we set out to do this session, and why

Albert's instructions, in order:

1. Fix the one open follow-up from the previous session: `ai-housekeeping`'s
   GitHub probe reported "UNKNOWN" for every worktree/branch on edge-dev.
2. Investigate the other three recorded follow-ups more deeply (a flaky
   Windows CI test, a Windows-local test error, and the ZCode owner-label gap
   in the shared-db closeout checker).
3. Ask Muse whether to fix all three; then implement the ones Muse endorsed,
   each in its own sub-agent.

All four work items are done. This handoff carries only what was deliberately
NOT done (§6) and what the next session would otherwise re-derive (§4, §5).

## 3. Current state — what is true right now

Landed on `main` and queue-verified (all three via merge queue; do not redo):

| Work | PR | Landing commit |
|---|---|---|
| ai-housekeeping probe fix (300s bound + bash routing + honest timeout message) | https://github.com/popcre/ai-devops/pull/2320 | https://github.com/popcre/ai-devops/commit/eabb3f6a43ae1bab7e604091601a403c0a11c4fc |
| Windows test bash-resolution helper (cygpath shadowing) | https://github.com/popcre/ai-devops/pull/2321 | https://github.com/popcre/ai-devops/commit/35ca3e3f05c627037216a69f7f706feeeb08b112 |
| Flaky admission fixture budget fix | https://github.com/popcre/ai-devops/pull/2322 | https://github.com/popcre/ai-devops/commit/a273fcc32c0474b098facc52f739441f1abf9794 |

- The probe fix is **installed** on edge-dev through the protected Windows
  installer and live-verified through the installed launcher (`GitHub:
  available` with real issue-backed rows instead of false UNKNOWNs). The two
  test-only fixes need no installation; tests run from checkouts and CI.
- Deep findings for the three follow-ups are written up as a comment on
  https://github.com/popcre/ai-devops/pull/2309#issuecomment-6606243051
- Deferred and NOT started: the two items in §6.
- Nothing is committed-but-unpushed; no PR is open; no worktree or branch of
  this session remains.

## 4. Everything we tried that did NOT work

1. **The "timeout cannot exec the extensionless transport" diagnosis was
   wrong** (it came from the previous session's notes). Evidence against it:
   coreutils `timeout` execs an extensionless shebang script fine, and
   `timeout 30 bin/ai-gh auth status` ran and returned 124 at the bound (an
   exec failure returns 126/127 immediately); `timeout 30 bash bin/ai-gh auth
   status` also returned 124. So routing through bash alone would NOT have
   fixed the reported symptom. The real cause is in §5. Lesson: reproduce the
   exact failure before trusting a diagnosis, even one written down.
2. **Installing by declaring the installation task while the candidate was
   already at the target.** `ai-task-gates check --before deploy` then computed
   a zero change set and fell into its "same-source installation" branch, which
   demands to run from the installed checkout with target == installed HEAD.
   Correct sequence (also documented in
   https://github.com/popcre/ai-devops/blob/main/docs/deployment.md field
   notes): declare `ai-task-gates start --class installation` while the
   candidate is checked out at the **installed checkout's HEAD**, then advance
   the candidate to the target, then `check --before deploy --target-head <sha>
   --installed-checkout <path> --installed-launcher <path>`, then run
   `bin/install-ai-devops-windows.ps1 -RepoPath <installed checkout>
   -ExpectedHead <sha>`.
3. **Backgrounding `ai-pr-wait` via `Start-Process`** produced a dead process
   with empty logs. The reliable form is the bounded foreground call
   `bin/ai-pr-wait <n> --fit-tool-call`, rerun on exit 2 / `STILL-WAITING`.
4. **Reviewing a branch with two-dot `git diff origin/main`** after a sibling
   PR had merged showed the sibling's files as deletions (the branch simply
   lacked them). Review PR content with three-dot `git diff origin/main...HEAD`
   or against the merge base.

## 5. Root causes and key findings

1. **Probe starvation, not exec failure** (why every ref read UNKNOWN):
   `ai-housekeeping`
   (https://github.com/popcre/ai-devops/blob/main/bin/ai-housekeeping#L251-L290)
   bounded every governed GitHub call at 30s
   (`timeout 30 "$GH" ...`), but `bin/ai-gh` queues and spaces every call
   machine-wide (FIFO admission tickets plus lock; 3s spacing, 30s when quota
   is low). On a busy machine a caller waits longer than 30s, the probe died,
   `GH_OK` stayed 0, and the report claimed "GitHub unavailable — install and
   authenticate gh", which is false. Same admission-wait class as
   https://github.com/popcre/ai-devops/pull/2305 (600s bound in
   `bin/ai-shared-db-closeout-check`). Fix: 300s bound, tunable via
   `AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS`; a timeout now reports "GitHub probe
   timed out" instead of the install hint.
2. **Fixture environment, not timing** (the flaky admission test): setting
   `AI_DEVOPS_TEST_MODE=0` to get the production lock default also disabled
   the `AI_TASK_GATES_MODE=none` shortcut (honored only when
   `AI_DEVOPS_TEST_MODE=1`, see
   https://github.com/popcre/ai-devops/blob/main/tools/lib/task-gates.sh#L148),
   so
   the real `ai-task-gates check --before pr-wait` — measured 23.7s on
   Windows — ran inside the fixture's 8-second `wait_for` budget. Fix:
   `AI_DEVOPS_TEST_MODE=1` + explicit `AI_GH_NO_WAIT_LOCK_SECONDS=300`.
3. **Which bash a test spawns** (the cygpath test error): the bare `bash` on
   PATH may be the WindowsApps WSL stub, and `Git\bin\bash.exe` bootstraps
   `/mingw64/bin:/usr/bin` ahead of the inherited PATH, so a test's PATH-first
   fake `cygpath` is silently shadowed by Git's real one. The raw MSYS
   `Git\usr\bin\bash.exe` preserves PATH order. Fix landed as
   https://github.com/popcre/ai-devops/blob/main/tests/bash_resolution.py
   (override: `AI_TEST_BASH`).
4. **ZCode owner labels are outside the closeout checker's identity model**.
   (`popcre/shared-db` is the shared Supabase database repository; its
   claim/stage closeout is certified by this repo's `ai-shared-db-closeout-check`
   tool.) That tool's grammar admits only Codex/Claude/MiMo
   shapes and MiMo's single-`s` `ses_` token; ZCode's double-`s` `sess_<uuid>`
   can never match. Consequences: a ZCode session running the checker fails
   closed ("session identity is missing"), and any other session **silently
   skips** a ZCode-owned claim (`owner_session` → None → never counted, never
   UNKNOWN) — a fail-open skip. Historical `ZCode chat unknown` signatures are
   permanently unattributable.

## 6. Exact next steps (the deferred work)

1. **ZCode identity gap** — only when a ZCode session next needs certified
   shared-db closeout. Widen the grammar in
   https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check
   (session token regexes near lines 46–54, `normalize_session` ~57–64,
   `resolve_session` ~112–125 reads only `CODEX_THREAD_ID` /
   `CLAUDE_CODE_SESSION_ID` / `MIMO_SESSION_ID`, `owner_session` ~134–143):
   add `ZCode` to the owner alternations, add a `sess_` (double-s) token,
   accept `--session-id sess_<uuid>`, and cover `OWNER_AT_CHAT` /
   `OWNER_ADOPTION` shapes. Tests must pin fail-open vs fail-closed behavior
   explicitly — a careless widening can turn today's silent skip into
   blockage for everyone. On the shared-db side the only requirement is that
   writers stop emitting the unattributable `ZCode chat unknown` form (issue:
   https://github.com/popcre/shared-db/issues/5468). You'll know it worked
   when: a fixture with a `ZCode chat sess_<uuid>` claim is counted by a
   second session's check (not skipped) and a ZCode session's own run
   resolves instead of erroring "session identity is missing".
2. **Test-helper bash fallback** — **LANDED 2026-11-03** as
   https://github.com/popcre/ai-devops/pull/2329 (commit 16b60de4). The
   handoff's premise was broken: `tests/reviewer_maintenance_cases.py` could
   not run at all, because Stage F (#2131) deleted `bin/ai-reviewer-issue`
   and `tests/test-ai-reviewer-issue.sh` while missing this `.py` file —
   `setUpClass` copied the deleted CLI and all 138 tests errored at setup.
   The PR therefore restores the suite rather than only swapping a fallback:
   `resolve_bash` from `tests/bash_resolution.py` (plus its MSYS coreutils
   directory on PATH), a synthetic recorder fixture in the existing
   `bin/event-fixture` style, and a skip on the glm subtest whose
   `cmd_delete` moved into the `ai-second-opinion` Python path. Verified on
   edge-dev under both shapes: 134 passed, 5 skipped. Deferred from that PR
   (Muse, 2026-11-03): the dead `Maintenance` class + `main()` in
   `tools/reviewer_maintenance.py` (reachable only through the deleted CLI)
   wants a separate cleanup; the glm delete contract is covered only by a
   smoke test in `tests/test_ai_second_opinion.py`.

## 7. Constraints and gotchas in force

- Work on a branch + PR; never push to `main`; code goes through the merge
  queue; prose-only changes merge around it after `bin/ai-doc-safety` passes.
  Full contract: https://github.com/popcre/ai-devops/blob/main/AGENTS.md
- Every GitHub call goes through `bin/ai-gh`; every wait is bounded
  (`bin/ai-pr-wait <n> --fit-tool-call`); no open-ended polling loops.
- Declare the task class first: `ai-task-gates start --class <class>`, and run
  `bin/ai-task-gates check --before <action>` before pr-wait/ship/deploy. A
  refusal is reported, never worked around.
- Sign every GitHub post with `Posted by MiMo chat <id> on <machine>`.
- The canonical checkout is landing-only; write-capable work uses its own
  worktree cut from `origin/main`. Never `git pull` an installed checkout.
- Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>`
  before any commit.
- Windows tests run through Git Bash; keep LF endings and PowerShell 5.1-safe
  argument passing. Platform notes:
  https://github.com/popcre/ai-devops/blob/main/docs/development.md
  (`### Windows CI platform differences`).

## 8. Access and environment

- Machine worked on: edge-dev (Windows, Git Bash + PowerShell). The two Git
  Bash entry points matter for tests (see §5.3).
- Managed command launchers live in the user's `~/.local/bin` and route into
  the installed checkout; the protected installer
  (`bin/install-ai-devops-windows.ps1`) is the only supported update route on
  Windows and needs `ProgramFiles` set in stripped-down shells.
- GitHub access: `gh` through `bin/ai-gh` (governed transport, machine-wide
  throttle). Secrets live in the 1Password `vibe_coding` vault — names only,
  never values. Muse second opinions run via `ai-muse` (session name used:
  `followups-triage-20261103`).

## 9. Open questions and risks

- **The ZCode fail-open skip is live** until §6.1 is done: a shared-db
  closeout check can report clean while a ZCode-owned claim is invisible.
  This is the only safety-flavored gap carried forward (documented as a known
  limitation on https://github.com/popcre/shared-db/issues/5468).
- This handoff has `issue: none`, so `ai-housekeeping` will report it
  `UNPROVABLE` — that is expected and honest; the two deferred items have
  their own anchors (§ contract block).
- Decisions dated 2026-11-03 so a later session cannot unknowingly contradict
  them: the probe's 300s bound is intentional (do not "optimize" it back
  down; throttle admission is the design constraint); the fixture must keep
  test mode ON with an explicit 300s lock default (restoring
  `AI_DEVOPS_TEST_MODE=0` re-creates the flake).

## Part (b) — sub-agent blocks (this session was a coordinator)

Five sub-agents were dispatched; all finished and all their worktrees were
removed and local branches deleted after their PRs merged (nothing is live).

1. **Investigate flaky admission test** (read-only). Asked: root-cause
   `test_pr_waiter_keeps_ticket_past_old_short_default`. Did: reproduced the
   failure and traced the fixture env semantics; found the 23.7s real gate
   inside the 8s budget. Findings: §5.2. No PR. Deliberately did not fix
   (investigation-only scope at that point).
2. **Investigate cygpath test failure** (read-only). Asked: root-cause
   `test_cygpath_adaptation_and_python3_fallback`. Did: reproduced the exact
   FileNotFoundError and proved the PATH-bootstrap shadowing. Findings: §5.3.
   No PR. Did not fix (investigation-only scope).
3. **Investigate ZCode label gap** (read-only). Asked: map the closeout
   checker's identity model and the gap's consequence. Did: mapped the grammar
   and both failure modes (fail-closed for ZCode sessions, fail-open skip for
   others). Findings: §5.4. No PR. Did not fix (deferred by owner decision).
4. **Fix flaky admission fixture** (implementation). Asked: implement the fix
   per the second-opinion direction, up to an open PR, never merge. Did:
   committed `66fd1590`, opened https://github.com/popcre/ai-devops/pull/2322
   with a 35-run stability loop as evidence. Coordinator reviewed (three-dot
   diff — see §4.4), gated and merged it. Deliberately did not raise the
   `wait_for` ceiling (second-opinion guidance) and did not touch other tests.
5. **Fix Windows bash-resolution test** (implementation). Asked: shared
   helper, not a one-test pin; prove both invocation shapes. Did: added
   `tests/bash_resolution.py` (`AI_TEST_BASH` override), opened
   https://github.com/popcre/ai-devops/pull/2321; green under PowerShell and
   Git Bash. Coordinator reviewed, gated and merged it. Deliberately did not
   refactor other bash-spawning tests beyond the failing file; it flagged
   `tests/reviewer_maintenance_cases.py` (now §6.2) instead of widening scope.
