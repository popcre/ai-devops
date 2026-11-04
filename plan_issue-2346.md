# Implementation plan — popcre/ai-devops#2346 (edge-dev3 heartbeat bypasses the GitHub call throttle)

## STATUS (2026-11-04 3:52 PM EST)

| Step | State | Evidence |
|---|---|---|
| 0. Confirm still real on main | done 2026-11-04 | `tools/ci/edge-dev3-heartbeat.sh:31` on main `f2b4f5bd` calls bare `gh variable set`; `systemctl --user list-timers` on edge-dev3 shows `edge-dev3-heartbeat.timer` live, firing every minute |
| 1. Route the write through `bin/ai-gh` | open | |
| 2. Add regression test | open | |
| 3. PR, merge, live proof on edge-dev3, close #2346 | open | |

**Verdict: STILL REAL.** Small fix, worth doing under skinny rules (one-line change in an existing script, no new tool, no new gate). Fresh session starts at step 1.

Handoff link: the implementing session creates its own `HANDOFF.d/<UTC>-edge-dev3-<agent>-heartbeat-ai-gh.md` linking this plan (and this plan's copy in the PR links back) — see §13.

---

## 1. Ultimate goal
The edge-dev3 desktop tells GitHub, every minute, whether its CI runners are free, so jobs from ~28 repositories go to edge-dev3 first and to free GitHub-hosted runners otherwise. That reporter must not be able to exhaust Albert's GitHub request allowance, because when that allowance is exhausted every AI session on the machine stops working against GitHub. The house rule (AGENTS.md line ~143) is: every GitHub call goes through `bin/ai-gh`, the machine-wide throttle. Done = the heartbeat obeys that rule and routing still works. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is
`popcre/ai-devops` (public) is Albert's AI tooling repository: scripts, skills, CI. Relevant pieces, all added by PR #2345 (merged 2026-11-04 05:10 UTC):
- `tools/ci/edge-dev3-heartbeat.sh` — runs on host **edge-dev3** (Ubuntu desktop) via systemd user timer `edge-dev3-heartbeat.timer` (every minute). For each row of `config/edge-dev3-runners.tsv` (28 repos) it writes repo variable `EDGE_DEV3_RUNNER_HEARTBEAT` = `<online|offline>,<idle|busy>,<unix-seconds>`, only on state change or every 120 s (`REFRESH`).
- `tools/ci/edge-dev3-route.sh` + `.github/workflows/edge-dev3-route.yml` — reusable router; a heartbeat older than 330 s (`MAX_AGE`) or missing means "use GitHub-hosted". So a skipped/failed heartbeat write is safe: it only degrades to hosted runners.
- `bin/ai-gh` — machine-wide throttle wrapper around `gh` (lock, 3 s spacing, back-off on secondary rate limit, refuses watch commands). State in `~/.ai-devops/gh-throttle`.

## 3. Trigger
The advisory AI review of PR #2345 filed review-finding #2346: the heartbeat calls bare `gh` instead of `bin/ai-gh`. The automatic fixer deferred it ("source PR is closed"), label `fixer-deferred`. Worst case today: 28 writes every 2 minutes ≈ 840 mutating calls/hour, unthrottled and invisible to `ai-gh`'s shared accounting, from the same account every other session uses.

## 4. Scope
In: change the heartbeat's one GitHub call to use `bin/ai-gh`; one regression test; live proof; close #2346.
NOT in scope: changing REFRESH/MAX_AGE/MAX_WORKERS, batching variable writes, the router, `install-edge-dev3-runner.sh` (its registration-token `gh api` is a one-off manual install call), the `shared-db-runner-heartbeat` timer (separate; file a separate finding only if it has the same defect — do not fix here), any new waiting tool or required check.

## 5. Current state
Main `f2b4f5bd`. `tools/ci/edge-dev3-heartbeat.sh:14` computes `ROOT` (repo root, symlink-resolved); `:31` is `if gh variable set EDGE_DEV3_RUNNER_HEARTBEAT -R "$repo" --body "$state,$work,$now" >/dev/null 2>&1; then`. No test covers the heartbeat; `tests/test-ci-edge-dev3-route.sh` covers only the router; suite manifests live in `config/ci-suites/<test>.json` (e.g. `{"kind":"bash","linux_seconds":1}`). Timer is installed and live on edge-dev3 (state files in `~/.cache/edge-dev3-heartbeat/`).

## 6. Key findings
- `bin/ai-gh` passes arbitrary gh args through and logs `variable set` as verb only (`bin/ai-gh:387-390`), so the value is never logged — no leak concern.
- Spacing 3 s × up to 28 writes = up to ~84 s per run, longer than the 60 s timer. systemd does not start a oneshot service that is still running, so the next tick is simply skipped; heartbeats stay well within the 330 s freshness window (worst case ~84+120 s). Acceptable.
- When `ai-gh` is in back-off it refuses the call; the script already treats failure as "don't record state, rc=1", so it retries next minute and routing falls back to hosted if stale. Safe.

## 7. Rejected approaches
- Batch all repos into one GraphQL mutation — more moving parts; not needed.
- Raise REFRESH to cut call volume — changes routing behavior; out of scope.
- Exempting the heartbeat from the throttle — contradicts the standing rule.
- Closing as "not worth it" — the fix is one line and the call volume is the single largest steady GitHub write source on the machine.

## 8. Decisions
Locked: use `$ROOT/bin/ai-gh` (not PATH lookup — the systemd environment may lack the repo's `bin` on PATH). Locked: allow override via env `EDGE_DEV3_GH` for tests only. Open: none.

## 9. Steps
1. **Edit `tools/ci/edge-dev3-heartbeat.sh`.** After line 18 add `GH="${EDGE_DEV3_GH:-$ROOT/bin/ai-gh}"`; on line 31 replace `gh variable set` with `"$GH" variable set`. Update the header comment line 11-12 ("Uses the host's own gh login") to say "through bin/ai-gh, the machine-wide throttle". Gate: `bash -n tools/ci/edge-dev3-heartbeat.sh` passes; `grep -n '\bgh variable' tools/ci/edge-dev3-heartbeat.sh` returns nothing.
2. **Add `tests/test-ci-edge-dev3-heartbeat.sh` + `config/ci-suites/test-ci-edge-dev3-heartbeat.sh.json` (`{"kind":"bash","linux_seconds":2}`).** Test: temp dir; one-row TSV `o/r<TAB>$tmp/runner<TAB>nonexistent-unit.service`; stub script as `EDGE_DEV3_GH` that appends its args to `$tmp/calls`; run with `EDGE_DEV3_RUNNERS`, `EDGE_DEV3_STATE_DIR=$tmp/state`. Assert (a) calls file contains `variable set EDGE_DEV3_RUNNER_HEARTBEAT -R o/r --body offline,busy,`; (b) second immediate run makes no call (REFRESH dedup); (c) a stub exiting 1 makes the script exit 1 and leave no state file. Also a static assert: script contains no bare `gh ` command invocation. Gate: `bash tests/test-ci-edge-dev3-heartbeat.sh` prints all ok, exit 0. (Copy structure from `tests/test-ci-edge-dev3-route.sh`.)
3. **Land.** Branch from main in its own worktree, commit as Albert (`git var GIT_COMMITTER_IDENT`) with the Claude co-author trailer, PR body "Fixes #2346", signed with `$AI_GH_SIGNATURE`. Wait with `bin/ai-pr-wait <pr>` in background; review is advisory; merge yourself. Then on edge-dev3 pull the toolkit checkout the timer runs from (check `systemctl --user cat edge-dev3-heartbeat.service` ExecStart path) to the merge SHA. **Live proof:** after the next tick, `journalctl --user -u edge-dev3-heartbeat.service --since -5min` shows no errors, `~/.ai-devops/gh-throttle` logs show `variable set` entries, and `gh variable get EDGE_DEV3_RUNNER_HEARTBEAT -R popcre/ai-devops` timestamp is < 330 s old. Close #2346 with a signed comment citing merge SHA and the proof.

## 10. Tests
New: `tests/test-ci-edge-dev3-heartbeat.sh` (cases a–c + static check). Must stay green: `tests/test-ci-edge-dev3-route.sh`, the repo's verify workflow.

## 11. Constraints and gotchas
Never push to protected `main`; PR only. Lean required checks: nothing new becomes required. Never log the variable value beyond what `ai-gh` already redacts. Don't `git checkout -b` in a live worktree. Times to humans in EST. Stage only owned files. The host checkout must be updated through git pull of merged main, never live-edited.

## 12. Access
`gh` authenticated on edge-dev3 as the owner account; repo variable writes need repo admin on each listed repo (already true — heartbeat works today). No secrets needed.

## 13. Done + risks
Done: steps 1-3, CI green, merged, host on merge SHA, live proof recorded on #2346, issue closed; handoff file created under `HANDOFF.d/` linking this plan. Risk: wrong `ROOT` resolution under systemd → every write fails → all routing falls back to hosted (safe, visible in journal); rollback = revert PR. Open questions for owner: none.

## Self-audit
1. Fresh session can execute without questions? Yes — §2, §5 give exact files/lines; §9 gives edits, test cases, gates.
2. All background incl. rejected options? Yes — §6, §7.
3. Goal clear enough for judgment calls? Yes — §1 states the rule and the safety property (stale heartbeat = hosted fallback).
