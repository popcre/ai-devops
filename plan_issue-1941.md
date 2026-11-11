---
summary: Plan for issue 1941 slow ai-gh auth status on Windows - symptom partly mitigated on main, live diagnosis and fix still open.
kind: plan
status: open
read-when: Fixing slow ai-gh auth status on Windows (issue 1941)
---

# Implementation plan — popcre/ai-devops#1941: `ai-gh auth status` slow on Windows; housekeeping / ai-pr-wait report GitHub unavailable

## VERDICT (read first)

**Partly mitigated on main, not fixed.** Checked against main `f2b4f5bd` (2026-11-04):

- The housekeeping *symptom* is very likely gone: PR #2320 (commit `eabb3f6a`, 2026-11-03) raised the per-call bound in `bin/ai-housekeeping` from 30 s to 300 s (`GH_CALL_TIMEOUT`, `bin/ai-housekeeping:269-284`) and reports a throttle timeout (rc 124) distinctly (`:600`, `:615`). The measured cost on al8960ofc was ~42 s per `ai-gh auth status` (issue comment, 2026-10-21 11:25 PM EDT), well under 300 s. Live proof of it on al8960ofc has **not** been recorded.
- The *cause*: about 42 s of `ai-gh`'s own per-call overhead on Windows, with the lock idle. It is undiagnosed and still present in code. Housekeeping also pays for a separate `auth status` probe before the call it actually needs (`:289` then `:299`). That doubles the wait.
- `ai-pr-wait` reading a PR on al8960ofc: unproven since 2026-10-21.
- The credential-helper contributor was already repaired (#1951 bypass at `bin/ai-gh:116`; helper re-pointed 2026-10-21).

So the work is: diagnose the overhead live, remove the redundant probe, and fix the overhead only if diagnosis names one specific step. Then prove all three checklist items live on al8960ofc.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Live timing diagnosis on al8960ofc | ⬜ open | — |
| 2 Drop redundant `auth status` probe in housekeeping | ⬜ open | — |
| 3 Targeted ai-gh overhead fix (conditional) | ⬜ open | — |
| 4 Tests green | ⬜ open | — |
| 5 PR, merge, install on al8960ofc | ⬜ open | — |
| 6 Live proof + issue checklist | ⬜ open | — |

Fresh session starts at Step 1.

Handoff: the planning session was read-only and could not create a `HANDOFF.d/` file. **The implementer's first commit must add `HANDOFF.d/<UTC>-<machine>-<agent>-ai-gh-windows-overhead-1941.md`.** It links to this plan (copy this plan into the repo as `plan_ai-gh-windows-overhead-1941.md`), and the plan links back to it.

## 1. Ultimate goal

On Albert's Windows machine al8960ofc, the daily housekeeping report and the PR waiter must actually see GitHub. Housekeeping says "GitHub: available" and shows real merged/open status for worktrees and branches, not UNKNOWN. `ai-pr-wait` reads a PR. Each GitHub call stops costing ~42 s of local overhead. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is Albert's shared AI toolkit: scripts, skills and global instructions installed on every machine (Linux and Windows/Git Bash). Main branch `main`; PRs are required. Relevant parts:
- `bin/ai-gh`: the governed GitHub transport. It wraps the real `gh` with a machine-wide throttle, quota admission and identity caching. Every repo tool must call GitHub through it.
- `bin/ai-housekeeping` (+ `.cmd` shim, Windows Scheduled Task): reports stale worktrees, branches and handoffs.
- `bin/ai-pr-wait`: the bounded, event-aware CI/PR waiter.
- al8960ofc: Albert's Windows workstation (Git Bash). The installed toolkit runs from the installed checkout, not from a worktree.

## 3. Trigger

Issue #1941 (2026-10-21, al8960ofc): `timeout 30 bin/ai-gh auth status` exited 124 at 32 s. Plain `gh auth status` was instant, and `ai-gh api rate_limit` returned normally. Housekeeping printed "GitHub: UNKNOWN (GitHub unavailable)". `ai-pr-wait 1927` failed for 9 min (`pr_status_singleflight.py` traceback, then "GitHub client exited 125 without a diagnostic"). The follow-up comment measured `ai-gh auth status` at 41.7–42.8 s, rc 0, with the throttle lock idle.

Repro on al8960ofc (Git Bash, installed checkout): `time bash bin/ai-gh auth status`.

## 4. Scope

In: diagnosing the per-call overhead of `ai-gh` on Windows; removing housekeeping's redundant probe; one targeted overhead fix if diagnosis identifies it; live proof of the three issue checkboxes.

NOT in this plan:
- Changing the throttle design, spacing, quota schema or identity cache semantics.
- Adding any new waiter, poller, retry loop or helper tool (owner rulings in `docs/owner-rulings.md`: fewest moving parts).
- Raising timeouts further. 300 s already exceeds 42 s, so a higher bound would only hide the cost. PR #1976 (a 120 s bound) was withdrawn for exactly this reason.
- Bypassing `ai-gh` with bare `gh` in housekeeping. This is forbidden by the comment at `bin/ai-housekeeping:253-256`.
- Linux performance work.

## 5. Current state of the code (main `f2b4f5bd`)

- `bin/ai-housekeeping:259-284`: `GH` resolves to `bin/ai-gh`. `gh_call` runs it through `bash` with `timeout ${AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS:-300}`.
- `:286-293`: `gh_call auth status` sets `GH_OK`.
- `:297-300`: only if `GH_OK=1`, `gh_call pr list --state all --limit 200 --json ...` fills `PR_DATA`.
- `:363`: `gh_call issue list ...` for handoff/plan resolution.
- `:600-620`: the report text distinguishes rc 124 (throttle timeout) from unavailable.
- `bin/ai-gh:116`: `auth git-credential` bypasses the throttle (#1951).
- `bin/ai-gh:~517-540`: per call it spawns the real `gh auth token` up to **twice** (hash, then PAT class check). It may then make a paced `/user` request (`sleep_ms` until spacing elapses) when the identity cache is missing or negative and older than 300 s. On Windows each `gh.exe` spawn plus pipes through `sha256sum`/`awk` is slow, and the paced sleep can be long. This is the leading suspect, but it is **unmeasured**.
- Tests: `tests/test-ai-housekeeping.sh` (#2320 added probe-timeout cases), `tests/test-ai-gh.sh`, `tests/test-ai-gh-admission.py`, `tests/test-ai-gh-app-auth.sh`.

## 6. Key findings / root cause

- Lock contention was ruled out (lock idle during sampling, 2026-10-21).
- A stale credential helper pointing at a staging copy's ai-gh was a separate contributor. It is fixed.
- The remaining ~42 s is ai-gh's own bookkeeping. **Which step is still unknown.** Step 1 measures it.
- `gh auth status` itself contacts GitHub. In housekeeping, the probe exists only to decide whether to try `pr list`, which is itself a sufficient availability signal.

## 7. Rejected approaches

- A longer timeout (PR #1976, 120 s): withdrawn. It hides the cost.
- Calling bare `gh` from housekeeping: it bypasses the governed transport.
- Adding a throttle bypass for `auth status` in ai-gh (like `git-credential`): `auth status` makes network calls, so it must stay paced.
- A new cache/daemon or "warm" helper: it adds moving parts.

## 8. Decisions

Locked:
- All GitHub calls go through `bin/ai-gh`.
- The 300 s bound in housekeeping stays as is.
- No new tools or waiters.

Open, with criteria:
- Whether Step 3 happens at all. Do it only if Step 1 attributes ≥ 20 s of the overhead to one identifiable block that can be changed without altering semantics (for example, the duplicate `auth token` spawn, or re-running the `/user` lookup every call because the cache is never written on Windows). Otherwise record the measurement on the issue and stop at Step 2.

## 9. Steps

**Step 1 — Live diagnosis on al8960ofc (no code change).**
Reach al8960ofc over SSH (see section 12). In Git Bash, in the installed checkout, run:
`PS4='+ ${EPOCHREALTIME} ${LINENO}: ' bash -x bin/ai-gh auth status 2> "$TMPDIR/aigh-trace.txt"`
Use `EPOCHREALTIME`, not `date +%3N`: uutils `%3N` drops leading zeros. Find the largest gaps between consecutive timestamps and map them to line numbers. Also record:
- `time bash bin/ai-gh api rate_limit`
- whether `$STATE/identities/*` exists and holds a numeric principal
- `time bin/ai-housekeeping` and its "GitHub:" line
- `bin/ai-pr-wait <any open or recent PR> --repo popcre/ai-devops` result

Do not paste tokens. The trace prints the `auth token` pipeline but not its value, because the value is consumed in a subshell. Still grep the trace for `ghp_|github_pat_|gho_` and redact before quoting anything.
Gate: a list of the top 3 time sinks with line numbers and seconds, posted (signed) on #1941.

**Step 2 — Remove the redundant probe in `bin/ai-housekeeping`.** (Can be done in parallel with Step 1.)
Replace `:286-300` so that `pr list` is the probe: run `gh_call pr list ...` once, capture rc into `GH_PROBE_RC`, and set `GH_OK=1` and `PR_DATA` only on rc 0 with output that parses as a JSON array (`jq -e 'type=="array"'`). The rc-124 and unavailable report branches at `:600-620` must keep working unchanged. Update their wording only if it names "auth status".
Behavior: one GitHub admission instead of two, and identical report output.
Gate: `bash tests/test-ai-housekeeping.sh` passes, including the #2320 timeout cases.

**Step 3 — Targeted ai-gh overhead fix (conditional on Step 1).**
Likely candidate: `bin/ai-gh:~517-523` calls `"$REAL" auth token` twice. Read the token once into a local variable that is never exported, echoed or logged, and derive both `credential_hash` and `credential_class` from it, then `unset` it. If Step 1 instead shows the `/user` lookup recurring because the identity cache is never persisted on Windows, fix the cache write. Do not change the cache TTL. Change only the block Step 1 identifies.
Gate: the Step 1 trace re-run shows that block's time reduced, and `ai-gh auth status` total < 10 s on al8960ofc (target; if it is not met, report the actual figure on the issue).

**Step 4 — Tests.** Run `bash tests/test-ai-housekeeping.sh`, `bash tests/test-ai-gh.sh`, `python3 tests/test-ai-gh-admission.py`, `bash tests/test-ai-gh-app-auth.sh`, and on Windows `tests/test-ai-gh-ssh-credentials.ps1` (both `powershell` and `pwsh`).

**Step 5 — Land.** Branch from `main` in a fresh worktree, then open a PR whose body references #1941 (not "Fixes" — live proof is still pending). Wait with `bin/ai-pr-wait <pr>` in the background. Merge it yourself; Albert does not merge. AI review is advisory only. Then install on al8960ofc through the repo's normal installer (sync-dotfiles skill) so the installed checkout is at the merge SHA. Verify with `git -C <installed checkout> rev-parse HEAD`.

**Step 6 — Live proof on al8960ofc.**
Re-run the Step 1 measurements on the installed merge SHA. Tick the issue checkboxes only with evidence: housekeeping "GitHub: available" with non-UNKNOWN merged-ness, a successful `ai-pr-wait` PR read, and the root cause stated. Post a signed comment with the times in EST, then close #1941.

## 10. Tests required

In `tests/test-ai-housekeeping.sh`:
- (a) Stub GH where `auth status` hangs but `pr list` succeeds. Expect "GitHub: available", proving the probe is gone.
- (b) Stub `pr list` exits 124. Expect the throttle-timeout message.
- (c) Stub `pr list` returns non-JSON or rc 1. Expect unavailable, with no crash.

If Step 3 is done, add to `tests/test-ai-gh.sh`:
- A fake real-gh counts `auth token` invocations. Expect exactly 1 per call.
- The token never appears in stdout, stderr or state files.

## 11. Constraints and gotchas

- Never push to `main`. Commit as Albert's verified identity, using the Claude co-author trailer.
- Use `EPOCHREALTIME` for ms timing.
- Windows CRLF breaks bash scripts, so keep LF.
- PowerShell 5.1 strips native argument quotes.
- `gh` keyring is unreadable over Windows SSH; use gh file storage (memory `windows-ssh-cannot-read-gh-keyring`).
- Running a local copy can re-pin the global credential helper. Install only from the canonical installer, not from a staging copy (this was the 2026-10-21 contributor).
- Sign GitHub posts with `$AI_GH_SIGNATURE`. Quote times in EST.
- Keep secrets out of output.

## 12. Access and environment

- SSH to al8960ofc as on prior sessions (memory: `windows-ssh-sessions-are-elevated`, `windows-ssh-cannot-read-gh-keyring--*`). Git Bash is at the standard Git for Windows path.
- `gh` is authenticated as `u2giants` on al8960ofc. No new secrets are needed. Any secret lives in 1Password `vibe_coding`.
- Linux test runs use any dev machine with bash, jq and python3 ≥ 3.10.

## 13. Definition of done, risks, open questions

Done means all of these are true:
- PR merged, CI green.
- al8960ofc installed checkout at the merge SHA (verified by `rev-parse`).
- Housekeeping on al8960ofc shows "GitHub: available".
- `ai-pr-wait` read a PR there.
- Root cause posted.
- #1941 checkboxes ticked with evidence, then closed.
- The handoff file is removed or marked done.

Risks:
- Collapsing the probe could misclassify an empty-but-valid `[]` result. `[]` must count as available.
- Reading the token once must not leak it via `set -x` in the tests.
- Rollback is reverting the PR.

Open question:
- The `ai-pr-wait` exit-125 failure from 2026-10-21 may not reproduce. If it does reproduce after Step 5, file it on this same issue with the trace. Do not widen this plan.

## Self-audit

1. Can a fresh session execute this without asking? Yes. Sections 2, 3, 5 and 9 give files, line numbers, commands and gates. Section 8 gives the criterion for the one judgment call (Step 3).
2. Does it carry all known background, including what was ruled out? Yes. Section 6 covers lock contention and the credential helper. Section 7 covers the timeout bump, bare gh, throttle bypass and cache daemon.
3. Is the goal clear enough to steer by? Yes. Section 1 states it as observable outcomes on al8960ofc.

Gap noted: the handoff link cannot be created by the read-only planner. It is assigned to the implementer's first commit (STATUS block).
