# IMPLEMENTATION PLAN — cut unneeded GitHub traffic (2026-09-25)

Companion execution plan under the programme
[`plan_github-request-reduction.md`](plan_github-request-reduction.md) (issue
[#658](https://github.com/popcre/ai-devops/issues/658)). This plan is **only**
the remaining source-reduction work: stop the GitHub calls that are not needed.
It does not re-plan measurement (P1), quota buckets (P2), fleet coordination
(P6), or programme acceptance (P8).

Linked handoff (this session):
[`HANDOFF.d/2026-09-25T1715Z-edge-dev-mimo-cut-unneeded-github-traffic.md`](HANDOFF.d/2026-09-25T1715Z-edge-dev-mimo-cut-unneeded-github-traffic.md).

## STATUS — read first

| Step | State | Owner / dependency | Evidence required to accept |
|---|---|---|---|
| S1. Land BlockerWatch snapshot reuse (P5 REST savings) | 🟡 code in PR (branch `claude/pr-860-6b49fd`, 2026-09-25) — reimplemented on edge-dev3 because the Windows WIP was unreachable; `link()` left on REST (it runs only in `wait`, where no snapshot exists); due scans now run before propagate/wake so their snapshot is reused. Live edge-dev tick proof pending in its leftover-proof issue | one implementation session; do not bundle | replay + tick tests green; live tick with fewer REST reads |
| S2. Share one PR status read across waiters (P4) | ⬜ open | after S1 helper edits settle | multi-waiter fixture: one upstream refresh, unchanged terminal outcomes |
| S3. Route leftover direct callers through `ai-gh` (P3) | ⬜ open | after S2 | caller inventory disposition + focused bypass regression test |
| S4. Before/after traffic sample + de-stale parent STATUS | ⬜ open | after S1–S3 installed | dated report under `tests/verification/github-requests/` |

**Start here:** a fresh session reads this entire file, then §5 "half-done WIP"
before touching code. Claim exactly one step. One unproven live outcome per
session. Update this STATUS when a step lands.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert's work should finish without GitHub rate limits interrupting it. The
machines should stop asking GitHub for information they already have, stop
asking it the same question from several places at once, and stop talking to it
outside the paced gate. Every safety check, wake, alarm, dependency link and
merge proof must keep working exactly as it does today.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**
Do not buy "fewer requests" by dropping a check, slowing detection past the
configured ceilings, or muting a failure.

## 2. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow: Bash/PowerShell tools, installers, skills, and GitHub Actions tests.
It is not an app, service, or database. **Installation is deployment.**

- Canonical landing-only checkout: `C:\repos\ai-devops` on Windows (also
  documented as `D:\repos\ai-devops` on some hosts). **Never edit it in place.**
  Every write task uses its own worktree from current `origin/main`.
- GitHub origin: `https://github.com/popcre/ai-devops.git`. Feature branch →
  pull request → merge queue. Never push to `main`.
- Key tool: `bin/ai-gh` — the only allowed GitHub CLI transport (lock, spacing,
  hourly budget, rate-limit back-off). Waiters: `bin/ai-pr-wait`,
  `bin/ai-gh-wait`. Scheduled watcher: `bin/ai-blocker-watch`.
- BlockerWatch runs on a 10-minute schedule (`config/blocker-watch.json`
  `schedule_every_minutes: 10`). Propagation and unowned-blocker alarms are
  owned by host `edge-dev`; every machine still wakes its own local sessions.
- Active hosts mentioned in the programme: `edge-dev`, `ALBT16`, `916`, `hetz`.
  GitHub REST core, GraphQL, and search are separate rate-limit buckets.

## 3. What triggered this work

On 2026-09-25 Albert said the account is **still hitting GitHub rate limits** and
asked what we send that is not needed. Measured P1 data (merged PR #663) already
showed **BlockerWatch is about 95% of managed traffic**. The four unneeded
streams still in play are listed in §6. Albert then asked for a plan to fix all
of them.

Reproduce the pain without burning quota: run BlockerWatch `tick --dry-run` and
count `gh_api`/`gh_call` sites in the tick path; compare with a replay fixture
(see `tests/test-ai-blocker-watch.sh` and the WIP replay script in §5). Do
**not** exhaust the live account to demonstrate a limit.

## 4. Scope — in and out

**In scope (this plan's steps S1–S4):**
- BlockerWatch: reuse the open-issue snapshot instead of per-item REST
  (propagate dependents, wake blocker state, link ids / existing links).
- `bin/ai-pr-wait` / `bin/ai-gh-wait`: one upstream status refresh shared by
  simultaneous waiters on the same target.
- Leftover direct `gh` callers: route through `bin/ai-gh` without changing what
  each caller is for.
- A dated before/after traffic sample and a de-stale of the parent plan STATUS.

**NOT in this plan:**
- Re-doing P1 telemetry, P2 multi-bucket quota admission, P6 fleet coordinator,
  P7 full-fleet install acceptance, or P8 programme acceptance contract.
- Reopening #401 throughput work or #650 workflow-efficiency work.
- Changing review/merge evidence rules, shared-db structure, production
  infrastructure, credentials, or buying capacity / splitting identities.
- Disabling BlockerWatch, lengthening the 10-minute tick, lengthening the
  5-minute waiter floor, or dropping wakes/alarms/links to save calls.
- A new webhook service, cloud broker, or remote coordinator.
- Implementing more than one step per session (see STATUS).

## 5. Current state of the code

Anchors were checked 2026-09-25 on `origin/main` at `f1758c21` and on merged
`5f8cf19b` (#853). **Search by symbol after drift** before editing.

### Already landed — do not redo

| Change | Commit / PR | What it did |
|---|---|---|
| Shared open-issue read for alarm + links | #806 (`72b8dcc2`) | one paginated `SNAP_Q` snapshot per scan instead of two full OPEN scans |
| `depends_on` naming a PR no longer fails the links scan | #812 (`2e039eb9`) | a PR target is skipped; previously the scan failed and **re-ran every 10 minutes for days** |
| Alarm read cache + node budget survive the subshell | #809 / #853 (`5f8cf19b`) | `issue_json` cache/budget live in files under `$ALARM_TICK`; wiped after the scan |
| Batched closed-issue search in `propagate` | already in `bin/ai-blocker-watch:360–375` | ~3 search queries per tick for 18 repos, not one per repo |
| Safe request telemetry (P1) | #663 (`f0dc027b`) | caller labels + scrubbed measurements; live on edge-dev |

**Important:** parent `plan_github-request-reduction.md` P5 STATUS still listed
#809 as remaining on 2026-09-24. That row is stale. S4 must fix the parent
STATUS; do not reimplement #809.

### Still true of the tick path (the remaining waste)

| Source | File:line (approx) | Behavior today | Why it is unneeded |
|---|---|---|---|
| `propagate` dependents | `bin/ai-blocker-watch:386` | for **each closed issue** found by search, REST `repos/…/issues/N/dependencies/blocking` | the open-issue snapshot already lists, for every OPEN issue, the blockers it waits on — invert that instead of asking GitHub |
| `wake` blocker probe | `bin/ai-blocker-watch:445` | REST `repos/…/issues/N` **every wait, every 10-minute tick** | if the blocker is still OPEN in the same-tick snapshot, that REST read is pure repeat |
| `link` id + existing-link probe | `bin/ai-blocker-watch:149–151` | REST issue id, then REST `dependencies/blocked_by` | snapshot already holds id and blocked-by lists for OPEN issues |
| Duplicate PR waiters | `bin/ai-pr-wait:243` | each waiter process runs the same GraphQL PR/check/queue query every 300s | N sessions on one PR cost N× the same read |
| Direct callers (bypass `ai-gh`) | see table in §6 of parent plan / `tests/verification/github-requests/p1-baseline.md` "Source inventory" | `bin/ai-test-local:158`, `bin/ai-verify-run:43–84`, `bin/ai-merge-group-evidence:98–140`, `bin/ai-memory-sync:90`, `bin/ai-transcript-destination-check:27`, `bin/ai-workspace-status:94` | they spend quota outside the paced gate and are invisible to the budget |

Alarm `ISSUE_Q` per unowned candidate (`bin/ai-blocker-watch:626–643`) is
**fresh authoritative state for a mutation** (request-for-owner comment). Keep
those reads. The cache (#809) only prevents *repeat* reads of the same issue
inside one scan.

### Half-done WIP — inspect before writing code

Worktree (leave it alone; do not delete or reset it):

- Path: `C:/repos/ai-devops/.claude/worktrees/p5-rest-savings-mimo`
- Branch: `mimo/p5-rest-savings-snapshot` (behind `origin/main`, uncommitted)
- Dirty files: `bin/ai-blocker-watch` (+~207/−28) and new
  `tests/test-ai-blocker-watch-replay.sh`
- Design already coded there (search these symbols):
  - `snapshot_index_build` / `snapshot_index_load` / `snapshot_index_set`
  - `SNAPIDX` (issue id/title/assignee count), `SNAPBB` (blocked-by edges),
    `SNAPNEWBB` (edges created this tick)
  - `snapshot_id`, `snapshot_open_hit`, `snapshot_has_link`,
    `snapshot_dependents_of` — invert OPEN issues' `blockedBy` to answer
    "what did closed issue X block?"
  - `link()` and `propagate()` and `wake()` already prefer the snapshot and
    fall back to REST only on a miss (a miss is **not** proof of closure).

That WIP is the intended S1 direction. A fresh session must either (a) re-apply
those hunks onto a new worktree from current `origin/main`, or (b) continue in
that worktree after rebasing — **never `checkout --` / `reset` uncommitted
work that is not yours**. If the hunks no longer apply, reimplement the same
symbol names and fallback rules so tests can share fixtures.

### Untouched

S2 waiter sharing, S3 direct-caller routing, S4 sample/report. No fleet install
of newer BlockerWatch beyond edge-dev is claimed here.

## 6. Key findings and root cause

1. **BlockerWatch dominates.** P1 live data: ~95% of measured managed traffic
   (parent STATUS, 2026-09-24). The largest remaining chunk is not the hourly
   snapshot itself — it is the **per-item REST** layered on top of data the
   snapshot already has (`propagate` dependents, `wake` probes, `link` ids).
2. **A failed links scan used to burn the account.** Before #812, a
   `depends_on` naming a pull request failed the links scan, so the scan clock
   never advanced and the full OPEN scan re-ran every 10 minutes for days.
   Fixed; never reintroduce "fail the whole scan on one bad fence".
3. **Shell subshell destroyed the alarm cache.** `j="$(issue_json …)"` runs in a
   command-substitution subshell, so shell-variable cache/budget updates died.
   #853 moved cache/budget to files under `$ALARM_TICK`. Do not "simplify"
   `issue_json` back to shell variables.
4. **Calls ≠ requests.** One `gh` invocation can paginate or hit several
   endpoints. Pacing without removing *source* demand does not fix limits
   (parent §6).
5. **GraphQL vs REST core are different buckets.** A healthy core probe does not
   mean GraphQL is available (parent incident §3). Waiters use GraphQL; most
   BlockerWatch item reads are REST.
6. **Waiters are honest but unshared.** `ai-pr-wait` already floors polling at
   300s and goes through `ai-gh`; the waste is N identical queries for one PR.

## 7. Approaches considered and REJECTED, and why

(These are parent-programme rejections that still bind this plan — do not
reopen them here.)

- Longer sleeps / fewer cron ticks: delays wakes and leaves duplicate demand.
- Probing quota before every call: creates another high-frequency caller.
- Caching mutations, privacy proofs, exact-head merge evidence, or collision
  checks: those need fresh authoritative state (parent §7).
- Disabling BlockerWatch or muting alarms to "save quota": capability loss.
- Giant combined GraphQL mega-query for all repos: can cost more points than
  several small ones (parent P5).
- Using `issue.updatedAt` alone as "nothing changed": it counts this tool's own
  comments as activity (see `alarm_scan` last-activity logic).
- Treating a snapshot miss as "the blocker closed": wrong for PRs, private
  repos outside the scan set, and pagination gaps. Always fall back to REST.
- Starting a new plan/programme beside `plan_github-request-reduction.md`:
  forbidden by AGENTS.md reuse rule. This file is an execution plan under it.
- Reimplementing P5 REST savings from scratch while the WIP exists: risks
  losing the fallback semantics already coded. Reuse or re-apply it.

## 8. Design decisions already made (dated)

**LOCKED (do not relitigate):**
- Preserve every wake, alarm, link, propagate comment, and waiter terminal
  outcome. Same detection ceilings: waiter ≥300s poll, BlockerWatch tick 10
  minutes.
- All managed GitHub CLI goes through `bin/ai-gh` (`gh_call` in BlockerWatch
  already does). Direct `gh` is a defect (S3).
- Snapshot is a **cache of display/relationship data**, never authority for
  mutations. Before a write: fresh validation (parent P5).
- Snapshot miss ⇒ REST fallback. Never infer CLOSED from "not in the snapshot".
- `issue_json` cache/budget stay file-based under `$ALARM_TICK` and are wiped
  after the scan (comment bodies must not linger).
- One step / one unproven live outcome per session. Update STATUS as you go.
- Public repo: no raw transcripts, secrets, or private identifiers in reports.

**OPEN (implementer's judgment within these criteria):**
- Exact snapshot index file format (in-memory vs saved between processes) —
  prefer the WIP's `SNAPIDX`/`SNAPBB` shape so the replay test can share it.
- How waiters share a read: lock file + short-lived status snapshot under
  `~/.ai-devops/` (recommended) vs. a tiny helper process. Must not become a
  new poller. Private visibility must not cross identities (parent P4).
- Whether `ai-verify-run` keeps one deliberate unwrapped dispatch/cancel path
  (parent P1 notes "dispatch and privacy-proof callers are not wrapped by
  design (P3)") — if so, document the disposition rather than force-wrap.
- Batch size / extra fields in `SNAP_Q` — only if measured cheaper in points.

## 9. The plan — numbered, ordered steps

Each step is **one session**. Mark the natural cut and use `fresh-session`
between them. Re-read this file's STATUS and §5 before each step (drift check).

---

### Phase S1 — Land BlockerWatch snapshot reuse (P5 REST savings)

**Intent:** the 10-minute tick stops re-asking GitHub for facts the same tick's
open-issue snapshot already holds. Propagate, wake, and link prefer the index
and fall back to REST only on a real miss.

**Targets:** `bin/ai-blocker-watch` (`propagate`, `wake`, `link`,
`open_snapshot`, snapshot helpers); `tests/test-ai-blocker-watch.sh`; WIP
`tests/test-ai-blocker-watch-replay.sh`; `config/blocker-watch.json` only if a
knob is required (do not change intervals).

**Steps:**

1. Create a **fresh worktree** from current `origin/main` (e.g.
   `git worktree add -b fix/p5-snapshot-reuse <path> origin/main`). Inspect the
   WIP diff in `p5-rest-savings-mimo`. Decide continue-vs-reapply (§5). Never
   destroy the WIP.
2. Ensure `open_snapshot` builds `SNAPIDX` / `SNAPBB` for every configured repo
   page, and `snapshot_index_load` restores them for processes that did not
   build them (wait registration path).
3. `propagate`: resolve `deps` via `snapshot_dependents_of "$repo" "$n"` first;
   only if empty, REST `dependencies/blocking` (keep the existing error note
   and `ok=0` path). Keep `notified.tsv` dedupe and `SCAN` clock advance rules
   — only a fully successful batch advances `SCAN`.
4. `wake`: if `snapshot_open_hit` returns `state/ispr/title`, skip the REST
   probe when the issue is still OPEN. On miss **or** when the blocker might be
   a pull request, use REST (snapshot issue nodes are Issues, not PRs).
5. `link`: use `snapshot_id` / `snapshot_has_link` before any REST id or
   `dependencies/blocked_by` read. Keep the "already blocked by" early return.
6. Do not rewrite giant `SNAP` pages per new link (the WIP's `SNAPNEWBB` exists
   because that is quadratic on Windows). Merge new edges at scan consumers.
7. Port/extend tests (names below). Run focused suite, then the full
   `test-ai-blocker-watch.sh`.
8. One **installed** tick on edge-dev with debug counters (the WIP's `BW_DEBUG`
   or `tools/github-requests` telemetry) showing: one snapshot build, zero
   dependents REST calls when the inverted index hits, wake REST only on miss.
9. Open a PR (code ⇒ normal checks + merge queue). In the landing session, if
   live proof is not finished, open **exactly one** leftover-proof issue and
   name it in this STATUS. Do not bundle S2.

**Verification gate — you'll know it worked when:**
- `tests/test-ai-blocker-watch.sh` and `tests/test-ai-blocker-watch-replay.sh`
  pass (replay ≥100 issues / ≥50 links, same wakes/alarms/links as before).
- A fake-CLI counter test shows `propagate` issues **no** `dependencies/blocking`
  call when the snapshot inverts cleanly, and one when the index is empty.
- A tick fixture shows `wake` does not REST-read a blocker still present as
  OPEN in the same-tick snapshot.
- One live edge-dev tick log shows the reduced call pattern without missing a
  wake/alarm/link (compare to the prior tick's notes).

**Adversarial cases (GitHub is external input) — every row needs a test:**

| External input | Hostile case | Test that proves it |
|---|---|---|
| GraphQL `SNAP_Q` page | `hasNextPage` true forever / truncated tail | `blocker_snapshot_pagination_replays_tail` (replay script) |
| GraphQL HTTP 200 with `errors` | partial `data` + errors | `snapshot_graphql_errors_are_not_success` |
| Snapshot miss for a blocker | issue exists but outside scanned repos / PR | `wake_snapshot_miss_falls_back_to_rest` |
| Snapshot contains blocker | still OPEN — must NOT treat as closed | `wake_open_snapshot_hit_skips_rest_but_stays_waiting` |
| Closed issue found by search | no OPEN dependents in index | `propagate_snapshot_empty_falls_back_to_rest` |
| Closed issue with dependents | index has them — no REST | `propagate_snapshot_dependents_no_rest` |
| `depends_on` names a PR | must skip, not fail the scan | `links_pr_target_skipped_clock_advances` (already from #812; keep green) |
| Duplicate link | already recorded | `link_snapshot_has_link_skips_rest` |
| Concurrent ticks | lock held | existing `lock_take` tests stay green |
| Cache files | leftover after crash; comment bodies on disk | `alarm_tick_cache_wiped_after_scan` |
| Non-regular cache path | FIFO / odd file (prior review rejection) | existing FIFO cases in `test-ai-gh.sh` / blocker-watch fixtures |
| Secondary rate limit | `gh` exit 75 / back-off | no busy-loop; tick fails visible, does not hang |

---

### Phase S2 — Share one PR status read across waiters (P4)

**Intent:** N sessions waiting on the same PR produce one upstream GraphQL
refresh per freshness window; every waiter still sees its own terminal outcome
at the same time as today (≤5-minute detection ceiling preserved).

**Targets:** `bin/ai-pr-wait`, `bin/ai-gh-wait`, optional small helper under
`tools/github-requests/`; `tests/test-ai-pr-wait.sh`, `tests/test-ai-gh.sh`.

**Steps:**

1. Fresh worktree. Re-read S1's landed helpers (do not fork a second cache
   format).
2. Add a **single-flight status snapshot** keyed by host/principal + repo +
   PR number + head SHA. One process refreshes; others within the age bound
   reuse. Recommended home: `~/.ai-devops/pr-status/` with the same scrubbing
   rules as P1 telemetry.
3. Keep terminal detection identical: merged / closed / failed check / queue
   ejection / deadline. A cancelled waiter must not cancel others. Do not cache
   "success" from a truncated check list — fetch missing pages or return
   incomplete/nonzero.
4. Private visibility: never share a snapshot across different authenticated
   principals (parent P4 gate).
5. Tests named in §10; then one live authorized PR with two concurrent
   `ai-pr-wait` processes and a call log showing one refresh.

**Verification gate — you'll know it worked when:**
- Multi-process fixture: two waiters, one upstream query per window, both exit
  with the same codes as before when the PR merges or a check fails.
- `tests/test-ai-pr-wait.sh` stays green (30+ assertions), including deadline
  and ejection cases.

**Adversarial cases:**

| External input | Hostile case | Test |
|---|---|---|
| GraphQL checks list | truncated `contexts(last:100)` | `waiter_truncated_checks_never_cache_success` |
| Two waiters, one dies mid-refresh | lock orphaned | `waiter_single_flight_recovers_stale_lock` |
| Different identities | private PR data leak | `waiter_snapshot_not_shared_across_principals` |
| PR ejected from queue | still `OPEN` | `waiter_ejection_is_terminal_for_all_subscribers` |
| Secondary limit during refresh | one waiter blocked, others starve | `waiter_refresh_backoff_visible_not_silent` |

---

### Phase S3 — Route leftover direct callers through `ai-gh` (P3)

**Intent:** every managed network path enters the paced gate or has a written
disposition saying why it must not.

**Targets (from `tests/verification/github-requests/p1-baseline.md` source
inventory — re-read that table first):**
`bin/ai-test-local:158` (runner collision check),
`bin/ai-verify-run:43–84` (dispatch/cancel),
`bin/ai-merge-group-evidence:98–140`,
`bin/ai-memory-sync:90`, `bin/ai-transcript-destination-check:27` (privacy),
`bin/ai-workspace-status:94`.
Workflow SDK callers (`.github/workflows/*`) are a **separate identity class** —
inventory disposition only; do not pool with the user quota.

**Steps:**

1. Fresh worktree. Re-read the inventory. For each caller: preserve purpose
   (collision safety, exact-SHA duplicate prevention, explicit cancel, fresh
   privacy proof).
2. Replace direct `gh` with `ai-gh` / `gh_call` **or** record an explicit
   allowlisted exception in the inventory (parent P1: dispatch and privacy
   proof were "not wrapped by design" — decide and document, do not silently
   wrap a safety path into a stale cache).
3. Add a focused regression test that fails if a new direct `gh` appears in
   `bin/` outside the allowlist (`tests/test-workflow-policy.sh` pattern).
4. One bounded installed operation per changed capability (e.g. a dry
   `ai-workspace-status`, a fake-CLI `ai-test-local` collision path).

**Verification gate — you'll know it worked when:**
- Inventory row for every source has disposition + owner.
- Fake-CLI spy test proves representative paths enter `ai-gh`, including
  failure paths.
- New-bypass fixture fails CI; legitimate test fakes still pass.

**Adversarial cases:**

| External input | Hostile case | Test |
|---|---|---|
| Direct `gh` reintroduced | bypass regression | `workflow_policy_rejects_new_direct_gh` |
| Dispatch race | duplicate workflow_dispatch | `verify_run_duplicate_dispatch_still_refused` |
| Privacy probe | repo made private/public mid-flight | `memory_sync_privacy_check_stays_fresh` |
| Runner list pagination | collision check misses a busy runner | `test_local_collision_paginates` |

---

### Phase S4 — Before/after sample + de-stale parent STATUS

**Intent:** prove the cuts, and make the programme's STATUS true again.

**Steps:**

1. Collect a bounded sample using `tools/github-requests/` telemetry (already
   merged): two windows, comparable workloads, requests and GraphQL points
   reported **separately**. Write
   `tests/verification/github-requests/2026-09-XX-after-s1-s3.md`.
2. Update `plan_github-request-reduction.md` STATUS: mark #809 done (cite
   `5f8cf19b` / #853), mark P5 REST savings done when S1 proof exists, note S2
   and S3 landings, and point remaining P5/P4/P3 rows at this plan's steps.
3. Close leftover-proof issues opened by S1–S3, or name who owns the last one.
4. Do **not** claim the parent P8 acceptance contract (50%/30% targets) from a
   small sample — those remain programme-level (parent §13).

**Verification gate — you'll know it worked when:**
- The report exists and cites command output / telemetry paths, not bare
  percentages.
- Parent STATUS rows match the artifacts.
- A reader can open one file and re-derive the savings claim.

## 10. Tests required

**Add / keep green (specific names, not "add tests"):**

- BlockerWatch: `tests/test-ai-blocker-watch.sh` (all existing; especially
  `blocker_unchanged_tick_no_duplicate_writes`, alarm cache/budget cases from
  #853, links PR-skip from #812). New/extended replay:
  `tests/test-ai-blocker-watch-replay.sh` — ≥100 issues, ≥50 links, pagination,
  reopen/close, crash/retry, identical wakes/alarms/links with fewer calls.
- Waiters: `tests/test-ai-pr-wait.sh` — single-flight coalescing, truncated
  checks, ejection, deadline, principal isolation.
- Gate: `tests/test-ai-gh.sh` — existing telemetry redaction/stream cases stay
  green (117+ assertions as of P1 baseline).
- Policy: `tests/test-workflow-policy.sh` — no new direct `gh` in `bin/`.
- Focused local command (Git Bash on Windows):
  `tests/test-ai-blocker-watch.sh`, `tests/test-ai-pr-wait.sh`,
  `tests/test-ai-gh.sh`, `tests/test-workflow-policy.sh`.
- Full required CI remains authoritative on the PR. Never overlap a local full
  series with a GitHub job on the same physical Windows host
  (`bin/ai-test-local --check-collision`).

## 11. Constraints, standing rules, and gotchas in force

- **Worktree, not the landing checkout.** Stage only task-owned files.
- **Branch + PR + merge queue.** Never push `main`. Docs-only PRs (every
  changed file is prose) may merge with `gh pr merge --squash --admin`
  immediately; any code/test change waits for checks.
- **`git var GIT_COMMITTER_IDENT` must show**
  `Albert Hazan <u2giants@users.noreply.github.com>` before the first commit.
- **Every GitHub call through `bin/ai-gh`** / `gh_call`. No `gh run watch`, no
  open-ended `until` loops; waits use `bin/ai-pr-wait` / `bin/ai-gh-wait`.
- **Long waits (>~10 min)** are registered with `ai-blocker-watch wait`, then
  the turn ends. Polling inside a turn is the exception.
- **One unproven live outcome per session.** If code lands without live proof,
  open exactly one leftover-proof issue before the session ends.
- **Do not rewrite** root `HANDOFF.md` (static pointer). One new
  `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` per session.
- **Sign GitHub posts** with `Posted by MiMo chat <id> on <machine>`.
- **Secrets:** 1Password vault `vibe_coding` only; never print values.
- **Times in EST (America/New_York)** in anything Albert reads.
- **Traps specific to this work:**
  - Do not replace `issue_json` file cache with shell variables (subshell bug).
  - Do not fail the whole links scan on one bad `depends_on` (#812).
  - Do not treat snapshot miss as closed.
  - Do not lengthen `schedule_every_minutes` or the 300s waiter floor.
  - Do not let ISSUE_Q comment bodies remain on disk after a scan.
  - Windows `.cmd` quoting breaks complex GraphQL — use Git Bash and
    file-backed bodies.
  - PowerShell is the native shell here; `bash -lc` may hit WSL absence —
    use `C:\Program Files\Git\bin\bash.exe`.
  - Another worktree may hold uncommitted P5 work — never reset it.

## 12. Access and environment

- GitHub CLI `gh` authenticated as Albert (`u2giants`). All calls via
  `bin/ai-gh`.
- 1Password: vault `vibe_coding` (names only, never values).
- Worktree example: `git worktree add -b fix/<step> <path> origin/main`.
- Run tests from the worktree with Git Bash. BlockerWatch dry-run:
  `bin/ai-blocker-watch tick --dry-run` (reads only; safe on any machine).
- Propagation/alarm posting is gated to host `edge-dev`. Dry-run alarm is
  allowed everywhere.
- Machine for this plan's handoff: `edge-dev`.
- MCP available this turn: 1password only. No Browser/GitHub MCP required.

## 13. Definition of done + risks and open questions

**Done when (programme-level for this plan's steps):**
- [ ] S1 landed + replay/tick tests green + one live edge-dev tick evidence
- [ ] S2 landed + multi-waiter fixture evidence
- [ ] S3 landed + inventory disposition complete + bypass regression green
- [ ] S4 dated after-sample filed + parent STATUS de-staled (#809 marked done
      with `5f8cf19b`)
- [ ] Every step's leftover-proof issue resolved or explicitly owned
- [ ] Commits on `origin/main` cited by SHA; required CI green (or docs-only
      admin merge where applicable)
- [ ] This plan STATUS updated by whoever did the work
  (`session-docs-update` / `codex-docs-update` gate)

**Rollback:** revert the step's commit(s) on a branch and reinstall from the
prior known-good toolkit commit; keep telemetry and logs. Do not clear
rate-limit state, disable watchers, or remove gates.

**Risks:** snapshot staleness causing a missed wake (mitigated by REST fallback
and same-tick build); private-data leakage through shared waiter snapshots
(principal partition tests); oversized GraphQL queries raising point cost
(measure points, not just calls); the WIP worktree rotting (S1 must reconcile
it early); another session editing `ai-blocker-watch` concurrently (serialize
S1 with any BlockerWatch change).

**Open questions:** none block starting S1. Judgment calls are listed in §8
OPEN. If live traffic after S1–S3 is still dominated by irreducible useful
demand, record that lower bound and escalate to the parent P8 contract — do
not invent waste or weaken safety to hit a percentage.

---

## Plan self-audit

1. **Could a brand-new AI session with no project knowledge execute this plan
   without asking anything?** Yes. §1–2 give the goal and product; §5 names the
   WIP worktree and exact symbols; §9 gives per-step targets, behavior,
   gates, and adversarial tables; §10–12 give tests, traps, and access. The
   only judgment calls are labeled OPEN in §8 with criteria.
2. **Does the plan carry every piece of background, nuance, and reasoning I
   currently hold — including rejected approaches?** Yes. §5 records already
   landed #806/#812/#853 so they are not redone; §6 carries the 95% finding,
   the subshell cache bug, and the PR-fence scan storm; §7 re-states the
   parent rejections and adds the ones unique to this cut (mega-query,
   updatedAt-only, snapshot-miss-as-closed, reimplementing over the WIP).
3. **Is the ultimate goal clear enough for a correct judgment call if a step
   turns out wrong?** Yes. §1 forbids buying savings with capability loss and
   says the goal wins over a bad step; §8 LOCKED and §13 risks give the
   fallback rules (snapshot miss → REST; never lengthen ceilings).

Checklist: all 13 sections present; STATUS table with dated open rows and a
start line; explicit NOT-in-scope; rejected approaches; concrete file/symbol
targets and gates; adversarial tables with test names on every row; locked vs
open decisions; named test suites; secrets by vault name only; DoD includes
commit/PR/CI; reciprocal links with `HANDOFF.d/`.

No claim that S1–S4 are already implemented. This document is the build brief.
