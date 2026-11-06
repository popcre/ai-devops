---
issue: 2367
status: OPEN
owner: zcode/ci-process-repair (edge-dev)
---

# HANDOFF — CI process repair: phase 2 done, 2.10 drain mid-flight (2026-11-06 ~1:15 PM EST, edge-dev/ZCode)

## 0. Nothing needs Albert

The one question that was his (PopPIM review-approval override) was answered this
session: requirement removed, poppim-web PR #24 merged, and the follow-on deploy bug
it exposed was fixed same-day (see §2). No other decision is his.

## 1. What this application is

`popcre/ai-devops` (public) is Albert's toolkit for AI coding sessions; this
programme repairs CI so red and green mean something and correct changes go live
unaided. Tracker: https://github.com/popcre/ai-devops/issues/2367. Plan:
https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md (STATUS
table is STALE for landed steps — trust the tracker comments and this file).
Albert owns POP Creations and is not a programmer.

## 2. What this session actually did (all verified on GitHub)

- **PopPIM decision (Albert, this chat):** removed the review-approval requirement
  (ruleset 25905559 → 0 approvals; classic required_pull_request_reviews deleted);
  PR https://github.com/u2giants/poppim-web/pull/24 merged as `0eb3de6`.
  Found+fixed same session: PR #24's verify step ran in the deploy job with no
  checkout — every main deploy failed exit 127 AFTER the redeploy succeeded (false
  red). Fix pushed to poppim-web main `648b4e4` (add checkout before the proof);
  the fix-commit deploy completed SUCCESS, so the live-version proof now works.
- **Step 2.5 merged** — shared-db PR #5833 (`8f9ea126`): preview/production
  evidence survives unrelated workflow edits; the apply workflow itself, gate
  code, config and modified migrations still void it.
- **Step 2.6 merged** — shared-db PR #5840 (`f4f60c70`): large-table preflight in
  both apply lanes; atomic `--statement-timeout-ms` (bounded); atomic policy
  parity (both targets). Two fixups were forced by the repo's own closed-inventory
  tests (unpinned preflight in the preview custody surface; single-target fixtures).
- **Step 2.7 merged** — shared-db PR #5847 (`90486a1e`): crossed versions land in
  merge order; only duplicate versions refuse (queue check, freshness
  verified-prefix rule, freeze-tolerant merge, §4 rulebook all aligned).
- **Step 2.8 merged** — shared-db PR #5853: 149 test cleanups retry
  (ENOTEMPTY class); task-gates verify got the last missing job budget.
- **Step 3.1 merged** — ai-devops PR #2425: `tools/ci/check-runner-labels.mjs` +
  weekly `runner-label-scan.yml` + fixture test; live scan of 171 workflows clean.
- **Step 3.5 merged** — ai-devops PR #2427: `config/required-checks-expected.json`
  + daily `required-list-drift.yml` + `tools/ci/check-required-lists.mjs`
  (`--apply` restores exactly the ruling list); both repos match today.
- **Step 2.9 resolved as record-only** — dependency check proved nothing is
  deletable from shared-db alone (8 observation workflows have ACTIVE
  designflow-backend proof consumers; recover-author-mutex is named by live CLI
  code; abandonment audit is woven into guard tests). Full disposition table:
  https://github.com/popcre/ai-devops/issues/2367#issuecomment-6679391844
- **Step 3.4 verified, no code change** — mirror in place since #3451; shared
  transport already does bounded retry; measured busiest hour 393 runs (vs ~950
  incident level). Evidence in the same tracker comment.
- **Step 2.10 IN FLIGHT** — see §4.
- **Step 2.1-completion PR OPEN** — shared-db PR
  https://github.com/popcre/shared-db/pull/5871 (branch
  `ci-process-repair/promotion-freeze-no-issue`, worktree
  `D:/repos/shared-db-worktrees/ci-2.5-evidence-lifetime`): a merged PR with no
  resolvable work issue still freezes promotion on the PR alone. Fixup `bfe499123`
  pushed after the workflow-coverage test; checks re-ran — CONFIRM ITS STATE
  FIRST (it may be green-queued or merged by the time you read this).

## 3. Applied to preview / production

- **Preview (via the workflow, bounded+allowlisted, no manual DB commands):**
  `20261021063716` (PR #4531, run 42183400427) and `20261021150012` (PR #4534,
  run 42184929162). Their PROMOTIONS were refused (see §4) — they are on preview,
  NOT production.
- **Production: nothing applied by this session.** No data rows written anywhere.
- Earlier dispatch attempts that lost the freshness race were refused BEFORE any
  write (several cancelled/failed runs of shared-supabase-migrations on
  2026-11-06 ~07:20–08:15 UTC — expected noise, self-cleaned).

## 4. The 2.10 drain — exact state and exact next actions

Alarm https://github.com/popcre/shared-db/issues/4540 is REAL: ~10 merged
migrations (2026-10-12→10-28) predate the automatic queue's activation
(2026-10-29T23:00Z) and are invisible to the selector's window. Full routing
state is on the issue:
https://github.com/popcre/shared-db/issues/4540#issuecomment-6686400884

Driver script (readable, rerunnable): `C:\Users\ahazan\AppData\Local\Temp\drain-backlog.py`
on edge-dev — v5 is two-phase per item (merged-lane apply on preview if absent →
historical recovery naming the applying run → promotion), waits for a quiet lane,
retries freshness races, parses freeze "until <ts>" windows, verifies delivery by
reading the production ledger via 1Password items (preview item
`qbvfk7umc3n75ejekd65zwd4ty`, production item `246sf23gymd64yudpmhswcnyle`, pooler
host `aws-0-us-east-1.pooler.supabase.com`).

**Exact next action:** (1) confirm PR #5871 merged (merge it through the queue if
green); (2) EDIT the driver's ITEMS list — REMOVE `merged_pr_issue_binding` from
every dispatch (the binding path refuses closed issues; with #5871 the PR alone
keys the freeze, so the binding input is unnecessary); keep historical entries:
`("4531","20261021063716","42183400427")`, `("4534","20261021150012","42184929162")`,
`("4996","20261028230411","40811041674")`, `("4213","20261012005136","38198539465")`
and merged-lane entries for 4572/4507/4597/4221 (issue numbers in the ITEMS list
are then unused — drop them); (3) run it in the background; (4) as each version
lands in production, append evidence to #4540; (5) when the ledger is clean, the
alarm's next run reports clean — close #4540 citing the live read. The alarm
closes only on a live clean read (Done-when of step 2.10).
**Flagged, NOT drainable:** `20261013174336` — base `20261009170724` is
designflow-nonprod-only by #3869; needs a reviewed derivation override or
retirement on #4540. That is a decision for the owning session, with the drift
report's own classification as the starting point.

## 5. Remaining plan steps (order matters)

3.2 (host health — the one heavy build left in phase 3; touches LIVE runner
machinery: read `bin/ai-windows-queue-watch`, `tools/ci/runner-router.cjs`,
`config/ci-runner-routing.json`, docs/watchdog-duty-pool.md first; a bug pauses
every Windows host — the plan's own risk table) → 3.3 LAST in phase 3 (billing
lock detection in `bin/ai-pr-wait` + `tools/ci/action-taxonomy.sh`; cause of the
October lock) → 4.2 (swallowed failures audit in app repos + popdam3 type check)
→ 4.3 (scheduled-workflow dispositions — now also owns queue-hygiene-report
failing daily since 11-03 and author-lane-abandonment-audit failing daily with
unwired secrets) → 5.1 (waiter reasons; check plan_issue-2095 state first) → 5.2
(doctor install-lag report) → 5.3 (transcript store redaction) → 6.1 (7-day
acceptance window against plan §13). Also: the plan STATUS table is stale for
every landed step (1.4–2.8, 3.1, 3.5) — a docs-only PR should sync it.

## 6. What we tried that did NOT work (mandatory)

- **Dispatching all drain items at once:** the workflow's concurrency group
  cancels superseded pending dispatches — only one survives. Dispatch serially
  after each completes.
- **`merged_pr_issue_binding` for old PRs:** refuses closed work issues ("a
  binding never reopens closed work"). With #5871 merged you don't need it.
- **Gh CLI `--json status conclusion` through Python subprocess:** two surprises
  — fields must be comma-joined (`status,conclusion`), and `--jq` strings use
  DOUBLE quotes (single quotes are shell syntax; without a shell they reach gojq
  literally and fail to parse).
- **`--paginate --slurp` cannot combine with `--jq`** (gh rejects); slurped pages
  are arrays-of-arrays — flatten before iterating.
- **The Bash tool mangles `$`-escapes and backslashes in heredocs** (known host
  trap, hit repeatedly): author edit scripts with the Write/Edit tools, not
  heredocs.
- **Dispatching while the lane is busy:** the run queues behind the exclusive
  lock while main keeps moving, then the freshness gate refuses the dispatched
  tip. Wait for a quiet lane (no in-progress/queued run of
  shared-supabase-migrations) before dispatching; even then budget retries.
- **ai-shared-db-closeout-check identity:** rejects ZCode `sess_…` ids (regex
  wants `ses_[A-Za-z0-9]{16,64}` or a bare UUID); run it with
  `--session-id d7a65b0f-bd3d-45bb-b3b1-2abcb9cc5bb2` AND
  `env -u CODEX_THREAD_ID -u CLAUDE_CODE_SESSION_ID -u MIMO_SESSION_ID` (a set
  env id that fails normalization poisons the candidate list). One run also hit a
  transient "GitHub request failed" — retry. A toolkit fix for the ZCode id shape
  is a legitimate small follow-up.
- **ENOTEMPTY sweep sanity:** 14 local Windows test failures in
  check-required-checks-preflight/check-sql suites are PRE-EXISTING on clean
  main (Windows-only, pass on Linux CI) — not caused by the 2.8 sweep.

## 7. What I own right now

- Open PR: shared-db **#5871** (branch `ci-process-repair/promotion-freeze-no-issue`,
  worktree `D:/repos/shared-db-worktrees/ci-2.5-evidence-lifetime` — also holds
  the merged step-2.5–2.8 branches; retire it after #5871 merges).
- Branches (local, shared-db): step-2-5/2-6/2-7/2-8 all MERGED (safe to delete);
  `ci-process-repair/step-2-9-dead-workflows` has NO commits (no PR — 2.9 was
  record-only; safe to delete).
- ai-devops worktree `D:/repos/ai-devops-wt-ci31` — branches step-3-1 and
  step-3-5 MERGED; tree clean; safe to retire.
- No database claims, no author reservations, no lane locks held by this session
  (closeout check receipt in the session log; workflow-owned freeze records have
  45-min TTLs and are released by their runs' always() cleanup).
- poppim-web canonical checkout `D:/repos/poppim-web` is on main, clean, pushed
  through `648b4e4`. `D:/repos/poppim-web-wt-verify-live-version` (branch
  `verify-live-version`, merged via #24) is safe to clean.

## 8. Blocked on

- #5871 must merge before the drain can promote anything (its checks were
  re-running after fixup `bfe499123` at handoff time — check first, merge through
  the queue if green).
- Nothing needs Albert.

## 9. Facts that may already be stale

- shared-db `origin/main` tip `0d05c1f6098837dbf9fa5b6e34dde252acb5cd78`,
  max migration `20261106064511` (checked 2026-11-06 ~1:10 PM EST).
- PR #5871 state OPEN with checks re-running (fixup `bfe499123`).
- Preview carries the two §3 versions; production does not (ledger read ~12:30 PM
  EST).
- Tracker comments: #2367 comments 6676904185 / 6679391844 / 6680320683; #4540
  comment 6686400884.
- The installed ai-devops checkout at C:/repos/ai-devops is main-guarded and
  ~35+ commits behind origin/main; bin/ tools from it still work (that is what
  this session used). Steps that CHANGE toolkit commands (3.2, 3.3, 5.1) must
  install by the protected route afterward.

## Self-audit

A stranger continues from §4 (exact driver edits + run), §5 (ordered remaining
steps), §6 (dead ends that cost hours), §7 (what is safe to clean). Every landed
item cites a PR/commit; the one open PR and the two preview-applied versions are
named exactly. Signature and EST times throughout; GitHub URLs for every artifact.

Posted by ZCode chat sess_d7a65b0f-bd3d-45bb-b3b1-2abcb9cc5bb2 on edge-dev
