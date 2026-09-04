# Reviewer 3.8 reintegration plan — 2026-09-03

## STATUS

| Work | Status | Evidence / next gate |
|---|---|---|
| Protect the active Windows runs | IN FORCE | Local detached worktree at `e1c9f0d6866fc3e0acfb7a5b65304c7c4a872a62`; no push, PR, merge, dispatch, cancellation, runner action, install, or local suite |
| Qwen 3.8 Max source preparation | OFFLINE GREEN ON IDLE POOL HOST | Stable `qwen3.8-max` pin; Qwen Code 0.23.0 installed on `EDGE-RUNN-ENVY` through the repo-owned installer with recoverable backup and verified child-secret hardening; non-live doctor passed with runtime SHA-256 `8f3cbb225324286bc163aa4ccd66405ba95ed357894d34ff781e57d139190c4a`; focused suite 92/92 |
| Gemini 3.8 Flash source preparation and live qualification | LIVE QUALIFIED | `agy models` confirmed `gemini-3.8-flash-high`; focused suite 62/62 on `EDGE-RUNN-ENVY`; governed live qualification passed on idle `EDGE-DEV` with agy 1.1.25 and wrapper SHA-256 `dac5862e5f12b75ff3f8b00075c339e404b62db8b55441012d2fcde6f3ca1f9e` |
| Shared quarantine/preflight | OFFLINE GREEN ON IDLE POOL HOST | 51/51 on `EDGE-RUNN-ENVY`; former-model or changed-wrapper/runtime qualification remains invalid |
| Qualification and reviewer rotation | PENDING | Both providers remain quarantined and receive no assignments until exact-model hostile qualification, exact-head review, full gates, installation, and current evidence succeed |

## Goal

Restore Gemini Flash 3.8 and Qwen 3.8 Max as governed, read-only reviewers
without interrupting or invalidating an active Windows run and without inheriting
qualification from their former models.

## Safety boundary

Preparing files in this detached worktree does not start GitHub Actions. Do not
push a branch, open or update a pull request, merge, dispatch a workflow, cancel
or rerun a job, install wrappers, invoke a live reviewer, run local reviewer/full
suites on EDGE-DEV, or touch runner services while any `windows-*` job is active.
Before each later action, re-read live job state rather than relying on this plan.

## Ordered work

1. COMPLETE: after every active Windows job was terminal, `agy models` returned
   the exact identifier `gemini-3.8-flash-high` without a paid review.
2. Update the Gemini default pin, fixtures, shared skill, and investigation/current
   plan wording to the exact returned identifier. A model change must invalidate
   every older Gemini qualification record.
3. Complete the Qwen `qwen3.8-max` pin migration. Confirm the installed Qwen Code
   version supports the stable model and preserves safe mode, excluded write/edit/
   shell tools, exact returned-model checks, bounded turns/tools/time, private
   snapshots, credential isolation, and source-drift refusal.
4. Run only focused offline Gemini, Qwen, preflight, sandbox, packet, scoreboard,
   and incident tests first. Repair failures; do not weaken assertions or raise
   timeouts to obtain green output.
5. Obtain one bounded hostile live qualification per provider on each supported
   machine. Prove exact returned model, exact conversation resume, denied/no
   mutation, unchanged source and outside sentinels, durable terminal report, and
   current wrapper/runtime hashes. Any uncertainty remains quarantine.
6. Run the repository-required complete gates and independent exact-head final
   review. Reconcile onto current `main` only after checking concurrent changes.
   Verify Albert's Git identity, commit only owned files, then push once; do not
   merge a separate feature branch because this repository is main-only.
7. Install from the verified `main`, prove installed hashes, update the scoreboard
   and reviewer assignment policy, then remove the no-new-work restriction only
   for the provider whose current qualification is valid. Re-check orchestrator/
   reviewer separation before shared-db assignments.

## 2026-09-04 pool-slot progress

`EDGE-RUNN-ENVY` was confirmed online and idle before work began. The remaining
long `windows-offline` jobs were running on GitHub-hosted Windows machines, not
on that self-hosted runner. A temporary isolated checkout at
`C:\ai-devops-reviewer-38` received only this workstream's files.

The Windows provider installer was extended to select only Qwen, request an
exact vendor version, preserve an existing runtime backup, verify the installed
version, reapply the child-process credential hardening, and behaviorally test
it. Two portability changes were required and tested: literal-SID ACL syntax on
the remote host, and Qwen 0.23.0's case-insensitive sanitizer helper. The first
install attempt stopped before download on the ACL guard. The second installed
0.23.0 but correctly refused completion when the old verifier could not execute
the new helper. The repaired installer then completed with backup
`C:\Users\ahazan\.local\state\ai-devops\qwen\vendor-backups\runtime-20260904T005451Z`.

The wrapper's non-live doctor was also repaired to secure a fresh dedicated
Qwen home before checking its session store. Final evidence on the idle host:
Qwen version 0.23.0; supported safety/budget/session flags present; child-secret
hardening passed; runtime SHA-256
`8f3cbb225324286bc163aa4ccd66405ba95ed357894d34ff781e57d139190c4a`;
preloader SHA-256
`774520d5e12ed1fc586d7d30c8278310b779672b51a4ba24ed663b0d7ad44291`;
Qwen 92/92; shared preflight 51/51; Gemini 62/62.

The governed 1Password bootstrap was installed on `EDGE-RUNN-ENVY` and the
paused `EDGE-ALIEN` through protected stdin transfer; no value entered an
argument, log, or repository. The original Qwen qualification path used the
10-second general doctor timeout, which was shorter than a 0.23.0 runtime hash
on either host and failed before provider contact. A dedicated bounded
30-minute Qwen qualification timeout was added.

Exact-model live qualification was then attempted once on each independent
idle host. Both reached the guarded live probe with version 0.23.0, identical
runtime and preloader hashes, managed 1Password reference, correct international
endpoint, hardened child environment, and healthy session store. Both failed
closed because no terminal success for exact `qwen3.8-max` was returned. Qwen
therefore remains quarantined. This repeated cross-host result is now a
provider/model response blocker, not a Windows capacity blocker; do not repeat
an unchanged paid attempt.

`EDGE-DEV` was checked and remained busy, so its existing Qwen 0.21.15
installation was not touched. GitHub assigned a reviewer-safety job to
`EDGE-RUNN-ENVY` only after the first focused tests had finished; work stopped
there until the runner became idle again. `EDGE-ALIEN` was deliberately paused
from GitHub scheduling throughout its qualification.

After all three self-hosted runners reported idle and `Runner.Worker` was absent
on `EDGE-DEV`, the governed Gemini gate ran there and passed. The durable
qualification binds exact model `gemini-3.8-flash-high`, agy 1.1.25, and wrapper
SHA-256 `dac5862e5f12b75ff3f8b00075c339e404b62db8b55441012d2fcde6f3ca1f9e`.
Do not repeat that paid gate unless one of those identities changes.

## Definition of done

Both model identities are exact and current; offline, hostile live, independent
review, GitHub, and installed-hash evidence pass; neither provider can modify the
review source; former-model evidence is stale; reviewer assignment uses only a
currently qualified provider. A prepared patch or green test alone is not done.
