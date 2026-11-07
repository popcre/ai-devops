---
issue: 2367
status: OPEN
owner: zcode/ci-process-repair (edge-dev)
---

# HANDOFF — CI process repair: #4540 drain closed, phases 4–5 landed, 5.2 in the queue (2026-11-06 ~9:40 PM EST, ZCode/edge-dev)

## 0. Business decisions only the owner can make

**Blocking (one UAC click, platform-limited — Windows will not show an AI session's elevation prompt):**
- Repair-runner-bash: `C:\Users\ahazan\Desktop\Repair-runner-bash.cmd` needs ONE double-click + UAC "Yes" on edge-dev. It adds `C:\Program Files\Git\bin` to the SYSTEM PATH (the runner service runs as NETWORK SERVICE and cannot find bash — the real cause of edge-dev-win's never-started signals) and restarts the runner service. Without it step 3.2's live canary round-trip cannot pass and edge-dev-win stays parked. Safe: idempotent, logs to `C:\Users\ahazan\AppData\Local\Temp\fix-runner-path.log`. Recommendation: click it any time; nothing else changes.
- The October billing-lock cause read needs `gh auth refresh -h github.com -s admin:org` completed in a browser as u2giants (carried unchanged from the 2026-11-06 MiMo handoff §7). Recommendation: do it when convenient; it unblocks the 3.3 cause report only.

**Not part of this work and nobody is on it:** none new. The two claim-title fixes (shared-db #5662, #5652) are other sessions' claims; they were notified 2026-11-06 (~6:20 PM EST) and the abandonment audit stays red until they act or the claims close — by design, not a defect.

**Already settled — do NOT re-ask:** review is advisory and never gates (2026-10-29); no reviewer needed for shared-db merges; never admin-merge code; the #4540 close criterion (Albert's own words this session: all four versions live + #5902 merged → live read → close) — done 2026-11-07 ~7:05 PM EST.

## 1. What this application is

`popcre/ai-devops` (public) is Albert's AI toolkit; the CI process repair (tracker [#2367](https://github.com/popcre/ai-devops/issues/2367), plan [`plan_ci-process-repair.md`](https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md)) makes red and green mean something. Albert owns POP Creations and is not a programmer. Machine: edge-dev (Windows). Session: ZCode.

## 2. What this session set out to do, and why

Resume the repair per the [2026-11-06 MiMo handoff](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-11-06T1835Z-edge-dev-mimo-ci-process-repair-drain-resume.md): finish the #4540 ledger drain, merge #5902/#5913/popdam3#858, then one small PR per remaining step (4.2 remainder, 4.3, 5.1–5.3, 6.1), plus the owed closeout receipts.

## 3. Current state — verified on GitHub (times EST)

- **#4540 CLOSED** (2026-11-07 ~7:05 PM): all four pre-activation versions live in production (independent pooler ledger reads cited in [#4540 comments](https://github.com/popcre/shared-db/issues/4540)); #5902 merged 21:35Z; #5913 merged (queue ejected the first stamp as backdated; file renamed **20261106214905**, SQL unchanged); review-finding #5860 closed; the last pre-activation straggler **20261021152741 retired as superseded** by the applied re-land 20261021190510 ([#5931](https://github.com/popcre/shared-db/pull/5931), merged 2026-11-07T00:04:58Z; the 00:05Z drift run no longer lists it). Remaining drift entries are post-activation automatic-queue backlog by design.
- **4.2 done**: popdam3 #858 (typecheck build) + #859 (justify comments) + #860 (audit `--omit=dev` + ubuntu-24.04 pin), poppim-web #25, popcrm-web #25, theoracle #469 (drift check moved to post-merge `drift-watch.yml`, first live run green). Tracker: [comment 6694939036](https://github.com/popcre/ai-devops/issues/2367#issuecomment-6694939036).
- **4.3 list + dispositions posted** ([comment 6696252846](https://github.com/popcre/ai-devops/issues/2367#issuecomment-6696252846)): queue-hygiene's red days were correct alarms on a stuck queue; the abandonment audit fails closed BY DESIGN on claims #5662/#5652 (owners notified). Follow-up (open): wire red-run-only monitors through the 1.4 route.
- **#2095 closed** via [#2447](https://github.com/popcre/ai-devops/pull/2447) (merge 7dae028e).
- **5.1 landed** via [#2449](https://github.com/popcre/ai-devops/pull/2449): `queued too long` warn (`AI_PR_WAIT_QUEUE_WARN_SECONDS`, default 3600), `still queued at the deadline` names the two runner-stall causes, cheat-sheet documents all reasons.
- **5.2 PR [#2453](https://github.com/popcre/ai-devops/pull/2453) OPEN, checks green, in the merge queue at handoff** (an earlier run was cancelled mid-flight by push churn; rerun completed clean). Doctor "Install lag (report only)" section + `tests/test-ai-devops-doctor-install-lag.sh` (behind/current/ahead cases; suite carries its own git identity for CI runners).
- **5.3 code landed** via [#2456](https://github.com/popcre/ai-devops/pull/2456) (merge 9f4f1ba3): `authorization-header` and `vendor-key` redaction patterns + `prompt_v6` with an obviously-generic example header (v5's example minted 67 false "billing lock" subjects — private findings_00 warning 1). **The store rebuild with the new patterns has NOT been run.**
- STATUS rows synced (#2450 merged 2026-11-07 ~00:4xZ). Closeout receipts: `ai-shared-db-closeout-check` **ok:true** (session `892c98b3-eccc-4876-bf88-1a9f7a328321`); `ai-housekeeping` clean.
- Canary: first dispatch 42282663335 failed `bash: command not found` — runner service PATH (see §0). Runner edge-dev-win (26) still parked at `["edge-dev","ai-devops-windows","canary-edge-dev-win","ai-devops-windows-paused","was-ai-devops-windows"]`; zero routing impact. Health pass logs at `~/.ai-devops/runner-pool-watch/tick.log`.

## 4. What we tried that did NOT work

- **Naive main-vs-ledger diff**: 83 "missing" — mostly empty markers, retired/foreign-target versions and in-flight queue items; the sanctioned verdict is `migration-ledger-drift.yml` / `scripts/check-migration-ledger-drift.mjs --target production` (it knows retirement/scope). Use the workflow, not a hand diff.
- **v12 drain of the straggler**: the historical lane refused the pull_request rehearsal run as original evidence ("wrong event", run 42307695050) and high-risk blocked the ephemeral route. Supersession retirement was the correct disposition instead.
- **5.1 fixtures were timing-flaky**: synthetic clocks derived from date-call counts flip verdicts with runner speed; the wrapper's quota probe (`api rate_limit --jq .resources...`) needs TSV rows (`core\t4999\t5000\t<reset>`), not a bare number, or every read backs off "quota unknown". Final fixtures derive time from the STATUS-call counter (100s per call) — deterministic. Local Windows runs of `test-ai-pr-wait.sh` are spawn-bound and hang; Linux CI is the gate.
- **New suite on Windows CI failed in 0s**: CI runners have no git identity; fixtures that commit need `git config user.email/user.name` locally.
- **`#5913` queue ejection**: reissued stamp went backdated the moment main advanced past it; the guard's own instruction (rename to a fresh stamp, pure rename) is the fix — expect this on any reissue that waits in a busy queue.
- **ai-gh hangs on this machine** (standing): the health pass needed `AI_RUNNER_POOL_WATCH_GH=gh` to finish dispatching its canary.
- **--admin docs merge before doc-safety**: #2450 was admin-squashed before running `bin/ai-doc-safety`; it passed on the merged tree after the fact. Run the check BEFORE the admin merge.

## 5. Root causes and key findings

- The pre-activation backlog is fully dispositioned; the drain pattern (driver v11/v12 shape, `C:\Users\ahazan\AppData\Local\Temp\drain-backlog*.py`) remains reusable: serial lane, re-dispatch on main-moved, poll the ledger not the run.
- Production pooler read: `aws-1-us-east-1.pooler.supabase.com:6543`, user `postgres.qsllyeztdwjgirsysgai` (tenant-qualified user is REQUIRED — bare `postgres` gives ENOIDENTIFIER); preview is `aws-0...:6543`. Secret: 1Password `vibe_coding` item `246sf23gymd64yudpmhswcnyle` (`password` field).
- False "billing lock" labels came from the v5 prompt's example header (67 segments, findings_00 warning 1); v6 stops minting them.
- edge-dev-win's never-started signals trace to SYSTEM PATH lacking `Git\bin` — likely the root cause 3.2's watchdog was built to detect.

## 6. Exact next steps

1. **Land 5.2**: PR #2453 is in the queue; verify `MERGED` (you'll know: `gh pr view 2453 --repo popcre/ai-devops --json state` = MERGED). If ejected again, requeue with `gh pr merge 2453 --merge`.
2. **After Albert clicks the desktop repair** (`fix-runner-path.log` exists and ends `done`): re-run `AI_RUNNER_POOL_WATCH_GH=gh AI_RUNNER_POOL_WATCH_SETTLE=5 bash bin/ai-runner-pool-watch health` from an ai-devops checkout; expect a green canary run and runner 26 labels back to `["edge-dev","ai-devops-windows"]`. That completes 3.2's live proof — tick the STATUS row.
3. **Rebuild the transcript store with the new redaction** (5.3 verification): `python tools/transcript_store/build.py` from an ai-devops checkout on main (store root `~/Dropbox/ai/transcript-store`, ~10 min class). Verify: query the two segment ids from `reports/ci-findings-2026-11-04/findings_00.md` (f8c6c327…, 30d7b0f7…) — the shapes must now show `[REDACTED:*]`; never record the values. Add the false-label query note (flagging the 67 bogus "billing lock" subjects) in `reports/` while there. Done when a fresh read of those segments contains no token-shaped text.
4. **6.1 acceptance**: phases 0–5 finish with 5.2; start the 7-day baseline window now (from 2026-11-07) per plan §Phase 6 and write `tests/verification/ci-process/acceptance-<date>.md` against §13's targets. Done when the 7-day re-measure passes or reopens its step.
5. **3.3 second half** once the `admin:org` scope exists: read spending-limit/payment settings, record the October cause on #2367 (plan step 3.3 has the exact done-when).

## 7. Constraints and gotchas

- Never admin-merge code; never manual production commands; the promotion queue owns applies. Shared-db merges go through the queue (`gh pr merge <n> --merge`); force-push removes queue membership.
- Sign GitHub posts `Posted by ZCode chat <session-id> on <machine>` (this session: `sess_892c98b3-eccc-4876-bf88-1a9f7a328321` on edge-dev).
- Task-gates: re-declare `--class shared-db` before shared-db PR waits (a `code` declaration refuses them).
- Standing: review advisory; lean required checks; 1Password `vibe_coding`, values never in transcript.

## 8. Access and environment

gh authenticated (u2giants). 1Password CLI `op` works (vault `vibe_coding`; prod DB item `246sf23gymd64yudpmhswcnyle`, preview `qbvfk7umc3n75ejekd65zwd4ty`). Local checkouts: ai-devops `D:\repos\ai-devops` (installed; don't pull) with worktrees under `D:\repos\ai-devops-worktrees\` (issue-2095 worktree carries branches 5.1/5.2/5.3/status; `wt-32` still has stale byte-duplicate edits safe to `git checkout --`); shared-db `C:\repos\shared-db` (read-only) with merged worktrees `C:\repos\shared-db-worktrees\retire-152741`, `D:\repos\shared-db-worktrees\jev-reissue` (reap candidates); popdam3 `D:\repos\popdam3` + worktrees (justify-comments, audit-scope merged); poppim/popcrm/theoracle worktrees merged.

## 9. Open questions and risks

- #2453's queue entry could be ejected again by the same push-churn cancellation (recoverable by requeue; its fixtures are now deterministic).
- The automatic queue's post-activation backlog (12 at 00:05Z) drains on its own schedule; the drift monitor keeps reporting it on closed #4540 — expected, not a regression.
- The abandonment-audit red persists until claims #5662/#5652 are titled or closed by their owner sessions — tracked on those claims.
- 6.1's window needs 5.2 merged first; if #2453 stalls, start the window from its eventual merge date.

## Self-audit

All four questions pass: a newcomer continues from §6's numbered steps with §4's dead ends and §5's pooler/quota-probe traps; §0 consolidates the two owner items (UAC click, admin:org) and the settled rulings; every artifact is a GitHub URL or an explicitly-local operational file (desktop script, logs) the successor on this machine needs.

Posted by ZCode chat sess_892c98b3-eccc-4876-bf88-1a9f7a328321 on edge-dev
