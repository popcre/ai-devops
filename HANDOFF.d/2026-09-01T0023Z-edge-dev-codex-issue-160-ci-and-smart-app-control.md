---
issue: 160
status: OPEN
owner: codex/issue-160-reviewer-determinism
---

# HANDOFF — issue #160 CI closeout and Windows runner policy (2026-09-01T0023Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Albert explicitly authorized the remaining #160 workflow and permanently
switching Smart App Control Off on EDGE-DEV. Do not ask again.

Already settled:

- Parent #159 owns children #160–#169; required-check cutover #166 stays last.
- Do not reset, clean, weaken tests, raise the 150-second product timeout, or
  accept stale/partial/cancelled evidence.
- Smart App Control must be Off as durable ai-devops Windows runner setup state.
  The source implementation is tracked separately in #200 and must warn that
  Windows cannot turn it back on without reset/reinstall.

## 1. What this application is

`popcre/ai-devops` is the public restore and multi-model workflow toolkit. This
work is in `C:\repos\ai-devops-throughput-160` on EDGE-DEV, branch
`codex/issue-160-reviewer-determinism`. GitHub is source of truth; installation
is deployment. There is no hosted app or application database.

## 2. What we set out to do, and why

Finish deterministic reviewer safety in #160, prove the exact tree locally and
independently, merge PR #193, close #160, audit downstream issue drift, and
start #161 fresh. During CI, Smart App Control blocked both official Windows
runners, so Albert also directed a permanent, documented setup repair.

## 3. Current state — exact live facts

- Preserve base commit `7da4411`. Committed repair `3ca8ad7` exposes truthful
  packet/sandbox progress and passes focused Kimi 207/207 and Grok 199/199.
- Exact-head review of `3ca8ad7` APPROVED in
  `.ai/reviews/codex-final-check-20260831T171038-503062-8456.md`; its Grok suite
  passed 199/199. Any later commit makes that review stale.
- PR #193 is OPEN with auto-merge enabled. Its remote head is `3ca8ad7`. Linux
  and reviewer-safety checks passed. Windows-offline failed after 74 minutes on
  `uncertain_ask_blocks_its_exact_retry`; it did not hit the 75-minute ceiling.
- The CI log proved the owner fixture lived 243 seconds because packet
  preparation plus its deliberate 150-second silent window exceeded the
  fixture's 240-second lease. Production behavior correctly expired that lease.
  Local commit `1b4e5dd8bc5be2fd2c975e9f46e2af8da35e168c` changes only the test owner's
  lease from 240 to 480 seconds and documents why. It does not change the
  challenger bound, silent window, assertions, or production timeouts. Focused
  Grok passes 199/199 on that commit. It is not pushed or independently reviewed.
- One full `tests/test-all.ps1` run on `1b4e5dd` ended Bash 1 / PowerShell 17,
  failures 1; truncated console output hid the Bash suite name. A diagnostic
  full Bash rerun is active in terminal session 49989 and writes
  `.ai/issue-160-bash-rerun.log`. At handoff it was still progressing through
  Grok assertions; do not start another run until it ends and its log is read.
- Smart App Control incident: Code Integrity 3077/3033 events named the signed
  `VerifiedAndReputableDesktop` base policy. An unsigned narrow supplemental
  policy was rejected as `IsAuthorized:false` and removed; no supplemental is
  active. Registry and active policies were backed up under
  `C:\ProgramData\ai-devops\backups\smart-app-control-<timestamp>`, then
  `HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState`
  was set to `0`. `Runner.Listener.exe --version` now succeeds at 2.337.0 and
  both scheduled runner registrations returned online.
- Issue #200 tracks making that state an idempotent, backed-up, verified part of
  canonical Windows setup. Do not mix #200 implementation into the #160 exact
  reviewer branch before #160 lands.
- Local reviewer incident `20260831T035919Z-edge-dev-grok-2159527` was marked
  resolved. Issue #160 and parent #159 remain open.

## 4. What did not work

1. Repeated #193 Windows runs collided with other PRs on the same physical host;
   an earlier run was cancelled at 75 minutes and is not evidence.
2. Smart App Control has no supported arbitrary local app/hash/path whitelist.
   The unsigned supplemental allow policy was rejected by its signed base.
3. The first uncontended #193 Windows run exposed a test-fixture lifetime bug,
   not a production lock bug: its 240-second owner lease expired at 243 seconds.
4. The first full local run after `1b4e5dd` had one Bash failure, but console
   truncation concealed the suite. Blindly rerunning would repeat the original
   throughput failure, so a durable-log diagnostic rerun was started once.

## 5. Root causes and findings

- #160 production repair is sound on focused proof: real preparation work was
  invisible to the old readiness fingerprint, and successor-owned locks needed
  truthful release paths. The new CI failure was solely a deterministic fixture
  lease shorter than the fixture's now-observed 243-second lifetime.
- Smart App Control reputation enforcement blocks unsigned assemblies shipped by
  the official self-hosted runner. Practical alternatives are trusted signing or
  an isolated VM/host. On this machine, with the current unsigned runner, Off is
  the only practical supported route; an arbitrary permanent whitelist is not.
- #160 improved reliability, not total runtime. Current CI duplicates all 61
  Bash suites across Linux/Windows, runs 17 PowerShell suites serially, and adds
  focused reviewer suites. Cross-PR concurrency keys allow one machine to be
  saturated by unrelated PRs.

## 6. Exact next steps

1. Attach to terminal session 49989 or wait for it to exit. Inspect
   `.ai/issue-160-bash-rerun.log` for every `FAIL`, nonzero suite summary, and the
   final Bash summary. Diagnose the exact suite before changing or rerunning it.
2. If the diagnostic Bash rerun passes, combine it with the already green 17/17
   PowerShell result only as diagnostic evidence; run one final exact-tree full
   suite when the machine and GitHub runners are idle. If it fails, repair the
   identified cause without weakening any assertion, then focused-test first.
3. Update issue-160 evidence with exact timestamps/counts. Verify identity,
   commit only owned evidence/handoff changes if appropriate, and push
   `1b4e5dd` plus follow-up commits to PR #193.
4. Run a fresh read-only exact-head final review with the focused reviewer test.
   Head changes invalidate it. Enter/retain merge queue and use `bin/ai-pr-wait
   193`; require exact PR and merge-group checks green, then confirm merge on
   `origin/main`.
5. Close #160 only when issue, plan, evidence, PR, and main agree. Retire all
   three #160 handoffs in that completion commit.
6. Audit live #161, #162, #163, #164, #167, #169, #168 and #166-last. Reviewer
   design for #161: add an always-required hosted-Ubuntu fast classifier (<3m),
   fail closed except a narrow prose allowlist, never use top-level paths-ignore
   for required checks, make merge_group/scheduled/manual full, serialize every
   EDGE-DEV Windows job with shared job-level concurrency and no cancellation,
   preserve check names until #166, and add a manifest proving all 61 Bash plus
   17 PowerShell suites are assigned exactly once. Do not invent per-suite path
   partitioning before #162/#163.
7. Start #161 from a new worktree/session only after #160 closes. Keep #166 last.
8. Complete #200 independently after #160: modify canonical Windows bootstrap,
   TestOnly, verifier, docs, and tests; require recoverable policy backup,
   idempotent state 0, runner listener load proof, disposable Windows two-run
   proof, and the irreversible-until-reset warning.

## 7. Constraints and gotchas

- No reset, clean, force push, broad staging, weakened tests, retry-until-green,
  or local reviewer tests while EDGE-DEV CI is active.
- Use `C:\Program Files\Git\bin\bash.exe` on Windows.
- Exact-head review is invalid after every commit, rebase, merge, or evidence edit.
- Preserve PR #193, branch, `7da4411`, `3ca8ad7`, and `1b4e5dd`.
- Keep Smart App Control Off. Do not restore the rejected unsigned policy or
  claim it is a whitelist. #200 is separately scoped so it cannot invalidate
  #160 evidence.

## 8. Access and environment

- Authenticated `gh`, Git Bash, PowerShell 7, and repository reviewer wrappers
  work. Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Offline tests use no secrets. Provider secrets remain in 1Password vault
  `vibe_coding`; never print or commit them.
- PR: https://github.com/popcre/ai-devops/pull/193
- Issues: #159 parent, #160 current, #161 next, #200 Windows policy setup.

## 9. Open questions and risks

- Evidence-bound question: which Bash suite produced the first full run's lone
  failure? The durable rerun log resolves it; Albert does not need to decide.
- Another PR can consume both logical runner registrations because they share
  one host. Recheck live CI before every local full/reviewer run.
- Windows reset/reinstall can restore Smart App Control eligibility; #200 must
  reapply the explicit ai-devops runner state on recovery.

## Fresh-session start prompt

Open `C:\repos\ai-devops-throughput-160`. Read `AGENTS.md`, then this handoff and
the two earlier #160 handoffs it names. Continue parent #159 from #160. First
finish and diagnose terminal session 49989 / `.ai/issue-160-bash-rerun.log`;
do not rerun blindly. Preserve branch, commits, tests, PR #193, Smart App Control
Off, and #200 scope. Finish exact full proof, fresh exact-head review, merge
queue/merge, #160 closeout, downstream drift audit, then create a clean #161
handoff/session. Keep #166 last.

## Handoff self-audit

All required sections 0–9 are present. A new developer has the exact branch,
commits, PR/check state, active diagnostic/log, Smart App Control incident and
settled authorization, failed approaches, acceptance gates, downstream design,
and copy-pasteable start prompt. No secret value is included and no owner
decision remains hidden.
