---
issue: 2367
status: open
owner: mimo/ghost-records-support-purge
---

# HANDOFF — ghost run records: sweeper live, waiting on GitHub Support purge

## What this workstream is

Three recurring CI-noise classes Albert asked to end permanently: failing
"Documents-only" checks that mean nothing, dead dispatches / zombie ("ghost")
run records, and failures that sit unnoticed. All three now have permanent
prevention landed; one external step remains — GitHub Support must purge 22
standing ghost records.

## Where things stand (2026-11-13 9:35 AM EST)

- **Landed and live:**
  - `popcre/shared-db` PR **#6216** (merged 2026-11-12 8:11 PM EST):
    `lane-watchdog.mjs --sweep-ghosts` reaps runs queued >30 min with zero jobs
    every 10 minutes and exits red naming anything it cannot remove; the
    documents-only gate now reddens only on a genuine revocation (status-history
    read retried once; unreadable change set routes green to guarded checks);
    `no-progress-alarm.yml` got its missing `actions: read` (popcre/shared-db#5922
    finding 1 — that issue's other findings stay open).
  - `popcre/ai-devops` PR **#2492** (merged 2026-11-12 8:50 PM EST): the sweeper
    ported as `tools/ci/ghost-run-sweep.mjs` + `tests/test-ghost-run-sweep.{mjs,sh}`
    + `.github/workflows/ghost-run-sweep.yml` (10-minute schedule). Branch
    `fix/ghost-run-sweeper-port`.
- **Tracking issues:** popcre/shared-db#**6215** (has the `- [ ] live proof` box;
  do not open a second ticket), umbrella popcre/ai-devops#**2367**, related
  popcre/shared-db#5922 (findings 2–4 still open) and closed #2838 (the original
  documents-only-red finding).
- **GitHub Support ticket:** filed 2026-11-12 ~8:05 PM EST via the support
  portal (Actions → Stuck workflow, priority normal), confirmation captured
  ("your message has been successfully submitted"). Ticket number not yet
  visible in help.github.com/support/tickets (indexing lag); it also arrives by
  email to u2giants. The ticket lists all 22 record IDs and the verbatim API
  evidence.

## The 22 ghost records (the thing being purged)

Signature: listing shows `queued` forever, zero jobs ever created, GET/DELETE by
id 404 (shared-db) or delete 403 "Could not delete the workflow run"
(ai-devops), cancel refused ("Cannot cancel a workflow run that is completed").

- popcre/shared-db (20): 43095669440, 43095669117, 43095669124, 43095669146,
  43095669170, 43095668966, 43095668891, 43095668975, 43095668984, 43095668955,
  43095668647, 43095668764, 43095569012, 43095568153, 43095568473,
  37655531031, 37655506554, 37642331862, 37642331820, 37539095200
- popcre/ai-devops (2): 43098438008, 43098438147

**Not a jam.** Merges and checks moved the whole time these stood (both PRs
above merged while they sat there). A ghost strands at most the one workflow on
the one ref it sits on (per-ref concurrency groups, `cancel-in-progress: false`).
Most sit on dead refs (merged PR branches). Go-arounds: a new PR/branch = a new
ref = a fresh concurrency group (proven 2026-11-06 on #5029 → #5812);
`lane-watchdog` re-dispatches missing check contexts on PR heads; a sweeper red
is the alarm that one is biting. Full narrative:
`docs/critical-incidents.md` 2026-11-11 entry.

## Exact next actions

1. **Capture the support ticket number** from the u2giants email or
   help.github.com/support/tickets once indexed; put it on popcre/shared-db#6215.
2. **Watch the first few sweeper runs** (both repos, every 10 min). Expected
   outcome: the sweepers go RED naming the 22 records as unremovable
   (`UNREAPABLE ... a GitHub support purge is the only route left`) — that is
   correct behavior, not a new failure. If instead a sweeper reports a record
   reaped, record it on #6215.
3. **When Support confirms the purge:** verify the 22 IDs are gone from
   `gh api "repos/<repo>/actions/runs?status=queued&per_page=100"`, confirm both
   sweepers return green ("ghost sweep: no wedged queued runs"), then check the
   live-proof box on popcre/shared-db#6215 and close it with the ticket number
   as evidence. This handoff file can then be deleted (presence = open).

## Constraints and traps

- Never re-derive or re-plan the prevention: it is landed (shared-db #6216,
  ai-devops #2492). `plan_ci-process-repair.md` STATUS has a 2026-11-13 addendum.
- Comments containing `missing` / `never created` / `not applied` in shared-db
  `scripts/**` and `.github/workflows/**` register truth-audit call sites:
  update `docs/verification/throughput-dispositions/` (ai-devops has no such
  audit).
- GitHub calls through `bin/ai-gh`; waits through `bin/ai-pr-wait` /
  `bin/ai-gh-wait` (bounded). Ghost records: cancel is ignored, DELETE 404s or
  403s — do not fight the API; the sweepers retry on schedule.

## Verification evidence so far

- shared-db: 84 focused tests pass (5 new: reap decisions, survivor reporting,
  dry-run, history-blip retry, unreadable-change-set routing);
  `manage-migration-coordination.test.mjs` 322 pass / 22 fail on both the branch
  and pristine main (pre-existing Windows temp EPERM flakes — identical counts).
  Merge commit on main 2026-11-13 01:11 UTC.
- ai-devops: `node --test tests/test-ghost-run-sweep.mjs` 3 pass,
  `bash tests/test-ghost-run-sweep.sh` 3 pass; one advisory Linux shard flaked on
  unrelated `test-ai-devops-doctor-install-lag.sh` (passes locally, fixture-only
  test). Merged 2026-11-13 01:50 UTC.
- Support ticket: portal confirmation text captured in-session.

## Docs-update final report (2026-11-13, codex-docs-update invocation)

- **Docs changed:** `plan_ci-process-repair.md` (plan-file gate: de-staled the
  fresh-session-start line, added a dated addendum with the three landings so no
  session re-fixes them); `docs/critical-incidents.md` (new 2026-11-11 entry —
  the ghost-run signature is exactly "odd tool behavior" this file exists for);
  `AGENTS.md` (one-line warning + pointer); this handoff.
- **Why they matter:** a future session seeing a red Documents-only check or a
  stuck-queued run must not re-diagnose for hours or re-open fixed work.
- **Docs intentionally not changed:** `docs/task-router.md` (the incidents file
  and plan already route this), `HANDOFF.md` (static pointer, never rewritten),
  shared-db docs (its knowledge landed in issue #6215 and code comments on the
  merged PRs).
- **Verification source:** live GitHub state (PR merges, check runs, support
  confirmation), local test runs quoted above, and `bin/ai-doc-health --repo .`.

## Completeness audit (mandatory handoff gate)

1. **Comprehensive enough for a cold developer?** Yes — background, the 22 IDs,
   ticket state, landed PRs with merge times, next actions with verification
   gates, and traps are all above; nothing depends on chat context.
2. **Detailed enough to continue as well as this session?** Yes — the go-arounds,
   the verbatim API refusal shapes (404 vs 403 vs "already completed"), the
   expected sweeper red wording, and the close-out proof steps are named.
3. **Every relevant detail included?** Yes — gaps found and filled during the
   audit: the exact ticket filing route (Actions → Stuck workflow, normal), the
   "unreapable" log wording to expect, and the truth-audit trap. Remaining
   unknown (by design): the support ticket number, which arrives externally.
