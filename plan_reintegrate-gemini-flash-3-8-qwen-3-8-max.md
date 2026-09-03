# Reviewer 3.8 reintegration plan — 2026-09-03

## STATUS

| Work | Status | Evidence / next gate |
|---|---|---|
| Protect the active Windows runs | IN FORCE | Local detached worktree at `e1c9f0d6866fc3e0acfb7a5b65304c7c4a872a62`; no push, PR, merge, dispatch, cancellation, runner action, install, or local suite |
| Qwen 3.8 Max source preparation | OFFLINE GREEN | Stable `qwen3.8-max` pin, fixtures, skill, and Windows path normalization complete; non-live doctor passed on Qwen Code 0.21.15; focused suite 91/91 |
| Gemini 3.8 Flash source preparation | OFFLINE GREEN | `agy models` confirmed `gemini-3.8-flash-high`; pin, fixtures, and skill complete; focused suite 62/62 |
| Shared quarantine/preflight | OFFLINE GREEN | 51/51; former-model or changed-wrapper/runtime qualification remains invalid |
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

## Definition of done

Both model identities are exact and current; offline, hostile live, independent
review, GitHub, and installed-hash evidence pass; neither provider can modify the
review source; former-model evidence is stale; reviewer assignment uses only a
currently qualified provider. A prepared patch or green test alone is not done.
