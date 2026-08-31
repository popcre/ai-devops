# Issue #160 — reviewer determinism evidence

Status: final lock-handoff repair passed focused and complete Windows
verification; exact-head independent re-review and CI landing remain pending.

## Source and trigger

- Starting main: `5f3f56438f5440a8d524e490e70513c62f2ee7af`.
- Open defect: #177.
- Reproduction: Actions run `33237124406`, Windows offline job
  `99059929773`, on documentation-only commit `529d5408`.
- Failure: Grok reported 193 passes and 3 failures after its review-snapshot
  fingerprint advanced, then remained silent for 135 seconds. The focused
  reviewer job passed the same source; this was an intermittent fixture race.
- Fresh confirmation: post-merge run `33292673304`, focused Windows job
  `99206932670`, on `15991e63e53dbded3d52c218ff7f62430ef05bca`
  reported 193 passes and the same 3 failures. Readiness advanced and then went
  silent for 150 seconds after 414 seconds; the complete Windows job passed the
  same source. This is the out-of-boundary progress race, not a product failure.

## Root cause and repair

`test-ai-grok-review.sh` isolated Grok session state under the suite temp tree,
but did not isolate review snapshots there until its final worktree-boundary
section. The named-session readiness fingerprints watched the temp tree while
the actual snapshot refresh and source-digest work happened in the account-wide
default directory. Healthy preparation could therefore look stalled.

The repair sets `AI_REVIEW_SANDBOX_DIR` at suite startup. All packet, clone,
digest, and atomic-refresh activity is now inside the suite-owned temp tree that
the existing progress fingerprint already watches. The 135-second stall window
and its absolute runaway ceiling are unchanged, so a genuine hang is not hidden.

## Independent review history

- `20260830T024631-549075-8893`: REJECT. Worker liveness alone would have hidden
  a genuine hang for the absolute 10x ceiling. That approach was removed.
- `20260830T025029-575251-26851`: REJECT. Watching the shared snapshot parent
  could let unrelated reviews hide a stall. That approach was removed.
- `20260830T025518-605832-2913`: REJECT. Exact snapshot-family watching still
  missed source-digest phases. The fixture boundary itself is now corrected.
- `20260830T054604-1209397-19602`: REJECT. Moving review snapshots alone still
  left `ai-review-sandbox` digest staging in the system temp directory. The
  suite now places its `TMPDIR` under the watched fixture tree and asserts that
  standard temporary files, including digest inventories, resolve there.
- `20260830T061055-1293582-22418`: REJECT. Its sealed loaded run reproduced the
  three failures because filesystem sampling still missed hashes between
  samples. `ai-review-sandbox` now exposes one test-only progress touch after
  each real inventory item; sandbox tests prove the hook works only in test
  mode. The review also found that a hung GitHub request could outlive
  `ai-pr-wait`'s deadline. Each request now runs under the native process-tree
  supervisor with a per-call bound capped by the overall deadline.
- `20260830T071615-1512237-30216`: REJECT. The Grok suite had not enabled the
  shared sandbox test-mode flag, so its new progress hook was inert. It now
  does. The waiter also used an external timer whose child could outlive a fast
  request; timeout ownership now lives inside `ai-process-supervisor`, invoked
  through a verified Python 3.10+ runtime with the exact resolved `gh` path.
- `20260830T075402-1675435-14586`: REJECT. A value-taking waiter option with no
  following argument could repeat its parser loop before the deadline existed.
  All four value-taking options now fail immediately when their value is
  missing, with an executable regression case for each.
- `20260830T081037-1736573-18538`: REJECT. No new code or data-exposure finding;
  the reviewer required the plan's full loaded repetition and Windows-suite
  acceptance evidence before approval.
- `20260830T092829-2034184-7247`: APPROVE. The exact revised source digest
  `ea3cc713898a4f07f5998b06c97b86f8050ca9dda7c8716cf02b4bf82e9aad64`
  passed the affected packet; the reviewer reported no correctness,
  regression, data-exposure, or material test-coverage finding.
- `20260830T215317-580053-13919`: REJECT on rebased commit `f01737e`. Cleanup
  deletion failures could be ignored before Kimi published `completed`, and
  this evidence file still contained one stale `pending` sentence. Terminal
  cleanup now verifies that the prompt, launchers, and repository lock are
  absent before disabling the EXIT safeguard. Any residue records
  `recovery-required` with `transient-cleanup-failed`; a deterministic injected
  deletion failure proves readiness is never published. The stale sentence was
  corrected.
- `20260831T000304-1076947-9812`: APPROVE on exact implementation commit
  `b9c203cf900856eae9397ee66b8a86677af2a0c4`, source digest
  `60b9eab44ffe22ffc07bc46cc54edff32b0591d85e00f1c46a91783170e91d30`.
  The reviewer reported no correctness, regression, data-exposure, or material
  test-gap finding after the terminal-cleanup repair.
- `20260831T004143-1251035-10407`: REJECT on commit `96374d6`. After releasing
  the public repository-lock path, the old worker could mistake a successor's
  newly acquired lock for its own residue and delete it from the EXIT trap. The
  repair atomically renames the owned lock to a private release path before
  making the public path available; the old worker thereafter can clean only
  that private path. A deterministic reacquisition test proves the successor
  lock survives.

## Other reviewer-suite sweep

The current Grok, Kimi, Claude, Codex, DeepSeek, Muse, Gemini, Qwen, and GLM
suites were searched for fixed sleeps, bounded readiness loops,
`poll_until_progress`, and `poll_worker_until`.

- Muse readiness uses `poll_worker_until` and names worker exit separately from
  timeout; issue #148 already protects this distinction.
- Gemini, Qwen, DeepSeek, Codex, and GLM short loops watch direct suite-owned
  marker/state files and are scaled or explicitly bounded. None routes work to
  an account-wide directory outside its watched fixture boundary.
- Kimi's sleeps model provider stream timing or explicit live probes, not a
  silent readiness fallthrough equivalent to #177.
- No second instance of #177's out-of-boundary progress signal was found. Any
  future race with evidence gets its own named issue rather than a timeout or
  retry added by assumption.

## Required results

- Timing helper: 12/12 passed on the repaired working tree; no helper change was
  needed.
- Current repaired Grok run: 199/199 passed under concurrent Windows reviewer
  load. Both boundary assertions and all three assertions that failed in run
  `33292673304` passed without changing the stall window.
- Review sandbox: 73/73 passed, including test-only progress and production-off
  behavior. Pull-request waiter: 21/21 passed, including a five-minute hung
  request killed inside five seconds with no surviving process tree.
- Serial loaded series attempt on source digest `9de5ff8973daa0c87c943dba716a6a27cd1ecf03dcac7385cccc335ebd20f252`:
  run 1 passed 199/199 in 819.1 seconds; run 2 stopped the series at 196/199
  after 1,849.6 seconds with the same three readiness failures. Inventory
  touches alone were insufficient during long Git clone/checkout work. Test
  mode now routes Git's real `--progress` output into the watched fixture file
  and touches it for each untracked-file copy; production output is unchanged.
- Grok: 10 consecutive serial loaded-Windows passes on source digest
  `614400b15832df45501eb77e43cc1cd1b7c56aebfbdc43dbdc76e0e374fe12ef`.
  Every run passed 199/199; elapsed times were 670.2, 661.2, 640.8, 640.1,
  640.0, 639.9, 634.2, 649.9, 641.4, and 639.5 seconds. Starting CPU load
  was 7, 4, 8, 0, 1, 3, 8, 2, 7, and 6 percent.
- Kimi exposed a second terminal-readiness race while proving its series. The
  first attempt passed three 203-check runs, then run 4 failed 202/203. A
  logged restart reproduced the defect in run 2 after 809 seconds: `ask resumes
  with -r` failed because a worker published `completed` before its EXIT trap
  released the repository lock. Terminal publication now occurs only after
  transient cleanup and exact lock release. A two-second test-only cleanup
  delay makes the old ordering fail deterministically; the repaired complete
  suite passed 204/204.
- A fresh Kimi series on source digest
  `d2c38a095e4917ad69a1cf50a76aeef9c8a0b53da4945b96b16cfac7ffe8c5d6`
  passed runs 1 and 2 at 204/204, then run 3 reported 203/204 on
  `concurrent refusal starts no second provider turn`. The implementation had
  correctly refused the duplicate; the fixture counted every stub invocation,
  including a later transcript/export helper from the original turn, as a new
  provider turn. The stub now records only actual model turns in a dedicated
  file, and the assertion always reports its before/after counts on failure.
- Kimi: 10 consecutive serial loaded-Windows passes on source digest
  `8d92e5fe89c107c22642e6a4e0ee38061001a2fdeebf9de83b3337a17f0fe19e`.
  Every run passed 204/204; elapsed times were 674.7, 663.1, 630.4, 658.6,
  680.5, 668.6, 588.6, 574.4, 592.1, and 574.8 seconds. Starting CPU load was
  16, 39, 7, 42, 16, 40, 0, 16, 17, and 16 percent; starting process counts
  were 1501, 1563, 1590, 1481, 1488, 1520, 1174, 1207, 1221, and 1300.
- Guarded-defect injections passed in the recorded 199-check Grok and 204-check
  Kimi runs. Grok's early-return fixture proved `await_result blocked through
  empty+partial`; its cancellation fixture proved `cancelled exits non-zero`,
  `cancelled has cancellation recovery message`, and no unsafe resume advice;
  its lock/uncertainty fixtures proved `same_exact_session_and_turn_is_refused`,
  `signal_releases_owned_locks_and_warns_about_remote_turn`,
  `remote_uncertainty_blocks_only_its_exact_duplicate`,
  `missing_terminal_result_fails`, and
  `missing_terminal_result_blocks_exact_retry`. Kimi's corresponding injections
  proved `await blocked through an answer with no terminal record`, `no resume
  hint exits non-zero`, `durable cancel is worker-confirmed`, `a second
  concurrent run is refused`, `answer defect is typed and removes its private
  prompt and launchers`, `detached launch failure refuses immediately`, and
  `durable wall deadline records timed-out`. These are fail-closed assertions:
  each injected bad condition must return nonzero or a typed non-success state,
  while the suite itself returns zero only when every refusal is observed.
- Complete Windows offline suite passed on 2026-08-30: all 61 Bash suites
  passed with zero failures in 4,703 seconds, followed by all 17 PowerShell
  suites with zero failures. The run included Grok 199/199, Kimi 204/204,
  reviewer sandbox 73/73, and pull-request waiter 21/21 on the repaired tree.
  The exact-source independent review result is recorded below.
  Independent run `20260830T141059-2767132-15997` reviewed source digest
  `20229dc9665a8ceaab5e24fc87dbcae60238255f794745dce958941ee499df4d`.
  It reported no repair-specific finding and rejected overall readiness because
  the then-pending ten-run Kimi, guarded-defect, and complete-Windows gates were
  not yet present. The Kimi, guarded-defect, and full Windows gates are now
  complete. Final independent run `20260830T214906-575090-13798` reviewed
  source digest `db871c37c83c1e77816306d1b7fe8600684a1654566465ce87232e4022d44dbf`
  after the complete Windows result was recorded and returned `APPROVE` with
  no findings or data-exposure regression.
- After the terminal-cleanup repair, the focused Kimi suite passed 205/205 and
  the complete Windows offline suite passed again: all 61 Bash suites passed
  with zero failures in 4,480 seconds, followed by all 17 PowerShell suites
  with zero failures. Exact-head independent run
  `20260831T000304-1076947-9812` then approved commit `b9c203c` with no findings.
- Final successor-lock repair proof on `EDGE-DEV`, working head `d80d2f9`, tree
  `c363bec803763cc75397639c2dcf9f394c75643c`, focused implementation/test diff
  SHA-256 `838e25351cb92de89fa9d0afae8026ec517e09c8383dce822914c84c3662712b`:
  `tests/test-ai-kimi.sh` passed 206/206. This includes the deterministic
  successor reacquisition assertion and the existing cancellation, refusal,
  missing-terminal, timeout, artifact, and cleanup defect injections.
- The authoritative complete Windows run started `2026-08-31T06:44:24Z` on an
  otherwise idle machine and passed all 61 Bash suites and all 17 PowerShell
  suites with zero failures in 4,014.1 seconds. The Kimi suite within that run
  also passed 206/206. Both GitHub self-hosted runners were idle before the
  local run; starting CPU after completion was 0.7 percent.
