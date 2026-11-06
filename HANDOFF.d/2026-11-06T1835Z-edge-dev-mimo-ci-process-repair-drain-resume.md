---
issue: 2367
status: OPEN
owner: mimo/ci-process-repair (edge-dev)
---

# HANDOFF — CI process repair: drain re-routed safely, 3.2/3.3 landed, 4.2 audit posted (2026-11-06 ~1:35 PM EST, edge-dev/MiMo)

## 0. What Albert asked for (still the standing order)

Continue the CI process repair (tracker: https://github.com/popcre/ai-devops/issues/2367;
plan: https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md —
its STATUS table was synced this session and is now accurate for landed steps).
Order given: (1) resume the shared-db ledger drain (alarm
https://github.com/popcre/shared-db/issues/4540; blocker PR #5871 was merged);
(2) then one small PR per step: 3.2 (host health), 3.3 last in phase 3, 4.2,
4.3 (owns the two daily-failing scheduled reporters), 5.1–5.3, 6.1 acceptance;
(3) sync the plan STATUS rows in one docs-only PR (DONE). Standing constraints:
never admin-merge code; never use `review-finding` for CI failures; never run a
manual production command; plain `gh` is an acceptable fallback when
`bin/ai-gh` hangs (it hangs often on this machine — used throughout).

## 1. What this application is

`popcre/ai-devops` (public) is Albert's toolkit for AI CI sessions; this
programme repairs CI so red and green mean something and correct changes go
live unaided. The ledger drain (shared-db #4540) is the step-2.10 backfill of
~10 merged migrations (2026-10-12→10-28) that predate the automatic
promotion queue's activation (2026-10-29T23:00Z) and are invisible to its
selector. Albert owns POP Creations and is not a programmer.

## 2. What this session actually did (all verified on GitHub)

**Drain safety work (the big discovery — read §8 before touching the drain):**
- Every one of the nine backlog versions was verified against the **live
  production ledger** (907 rows) and the later migration files. Result:
  - **4 SAFE, draining now** (additive/idempotent; no later production version
    touches their objects): `20261021150012` (PR #4534), `20261022014315`
    (PR #4572), `20261022071323` (PR #4597), `20261028230411` (PR #4996).
    PR↔version pairings verified via the commits API (each final stamp's
    adding commit belongs to its named PR).
  - **3 RETIRED, superseded — promoting them is a production rollback:**
    `20261021063716` (PR #4531) — its `CREATE OR REPLACE search_dam_documents`
    body is superseded by applied `20261106042721` + `20261106095531`
    (confirms review-finding https://github.com/popcre/shared-db/issues/5860
    independently); `20261022032116` (PR #4507) and `20261012005136` (PR #4213)
    — both `CREATE OR REPLACE search_style_guide_library_v2`, superseded by
    applied `20261022155012`, `20261027183509`, `20261104231707`,
    `20261105023331`, and their own baseline/recovery guards refuse any other
    body.
  - **1 RETIRED, unprovable stamp, reissued:** `20261015132149` (the pm_jev
    triage contract, Issue #3298) — its stamp was re-reserved AFTER PR #4221
    merged (commit `8717fc09f` renamed `20261013144638_...sql`), so no merged
    PR adds the stamp and the post-merge rehearsal proof can never accept it.
    Reissued **byte-identical** (body `cmp`-verified) as `20261106190000` in
    https://github.com/popcre/shared-db/pull/5913 — once merged, the normal
    automatic lane carries it (it postdates queue activation).
  - **1 scoped, not drained (the user's named item):** `20261013174336` —
    designflow-nonprod-only by #3869 scope (derived from `20261009170724`);
    disposition recorded in the registry PR below and on #4540.
- Dispositions land mechanically in `production_migration_guard.py`
  (`RETIRED_VERSION_REASONS` / `FOREIGN_TARGET_MIGRATIONS`) via
  https://github.com/popcre/shared-db/pull/5902 — the closed-inventory contract
  test in `scripts/test_post_batch_app_verification.py` was extended with the
  four entries (it pins the retired set exactly).
- Evidence comments with the full matrix posted on
  https://github.com/popcre/shared-db/issues/4540 (comments 6691363302,
  6691721591). Review-finding #5860 answered with the queue-owner decision
  (RETIRE `20261021063716`); it stays OPEN as the standing hold until #5902
  merges (comment 6691371838), then close it as resolved.

**Merged this session (ai-devops unless noted):**
- shared-db PR #5884 (`72d8bcf6`) — the production gate accepts the
  index-maintenance era's 8-job preview-evidence graph (historical recovery
  was refusing every Oct-21 apply run). 232 gate tests pass.
- PR #2441 (`392175b6`) — docs-only STATUS sync of plan_ci-process-repair.md.
- PR #2438 (`cd938d87`) — step 3.2 host health: `ai-runner-pool-watch health`
  pauses a dead Windows host (never-started job, or two section timeouts) to
  `ai-devops-windows-paused` with `was-<label>` + `canary-<name>`, restores
  only after a passing `windows-host-canary.yml`; the router never counts a
  paused host. Dead-host fixtures green (the plan's simulated gate).
- PR #2444 (merged through the queue) — step 3.3 code half: `billing-lock`
  named state in `tools/ci/action-taxonomy.sh` + waiter naming in
  `bin/ai-pr-wait`; check contexts now carry `title`/`description`
  (`tools/github-requests/pr-status-complete.sh`). 41 taxonomy tests green.

**Open PRs (handed over — DO NOT rush them):**
- https://github.com/popcre/shared-db/pull/5902 — disposition registry
  (`ci-process-repair/ledger-dispositions`). Checks were green except the
  "Documents-only" pair (expected for a code PR) and one ephemeral-suite run.
  Merge through the queue when green; it is the mechanical successor to
  review-finding #5860's hold and a prerequisite for a clean #4540 close.
- https://github.com/popcre/shared-db/pull/5913 — the `20261106190000` reissue
  (`ci-process-repair/jev-triage-reissue`). Migration PR; normal lane.
- https://github.com/u2giants/popdam3/pull/858 — step 4.2 type check wired
  into `npm run build`. Proof in the PR body (clean build passes; deliberate
  TS2322 fails the build). Live proof of the done-when ("popdam3 fails a build
  on a type error") is that run.

**Step 4.2 audit** posted on #2367 (comments 6691989700 and the correction
6692040912 — use the CORRECTION: the first table's line numbers came from a
stale contents-API scan). All popdam3/`shared-db-guard` hits are justify-class
capture/assert idioms (verified in context on exact main `2227167e`); none
suppresses a real result. Open remainder: the in-file justification comments
(small PRs per repo) and "separate oracle CI from the production ledger"
(unstarted; theoracle is clean of swallow-patterns, so the ledger coupling is
elsewhere in its CI — inspect its workflows for Supabase/ledger reads).

## 3. Applied to preview / production

- **Nothing applied by this session's hands.** No manual production command
  was run anywhere. The only database access was READ-ONLY ledger SELECTs via
  psql (production 907 rows; preview checked for the 6 versions).
- The background drain driver (`C:\Users\ahazan\AppData\Local\Temp\drain-backlog.py`,
  v11) DISPATCHES the sanctioned `shared-supabase-migrations.yml` lanes
  (workflow_dispatch). At handoff time item 1 of 4 (`20261021150012`) had its
  historical recovery **qualify** (run 42266759482) and is waiting for the
  serial production lane to land; the driver polls the production ledger and
  then moves to `20261022014315`, `20261022071323`, `20261028230411` (the
  latter two via historical recovery naming runs 42184929162-era and
  40811041674... see the ITEMS list in the driver — PRs #4572/#4597 take the
  merged lane, #4996 the historical lane with run `40811041674`).
- **Preview state (honest):** preview carries `20261021063716`,
  `20261021150012`, `20261028230411` (applied Oct 21–28). Its
  `search_dam_documents` body is the **Oct body** — replayed by the earlier
  drain attempts (runs 42183400427 / 42237043420) and now a regression vs the
  Nov bodies production carries (this is review-finding #5860's preview half).
  Preview needs a forward re-sync of the current body at some point — NOT this
  promotion. Nobody has fixed that yet.
- **Production:** nothing from this session; the drain's four safe versions are
  the only intended additions.

## 4. Half-finished / abandoned mid-way

- The drain is mid-flight (1 of 4 items in its promotion lane; the driver
  process is running on edge-dev as PID visible via
  `Get-CimInstance Win32_Process -Filter "Name like 'python%'"` matching
  `drain-backlog`; log `C:\Users\ahazan\AppData\Local\Temp\drain-backlog-v11.log`).
  If the log shows `STOP:` or `driver complete`, read it before anything else.
- The live canary round-trip proof for 3.2 was left RUNNING: edge-dev-win
  (runner id 26) is deliberately parked in the simulated paused label state
  `["edge-dev","ai-devops-windows","ai-devops-windows-paused","was-ai-devops-windows","canary-edge-dev-win"]`.
  A background `ai-runner-pool-watch health` pass (log `/tmp/health-live.out`,
  done marker `/tmp/health-live.done`) is queued behind the ai-gh lock to
  dispatch `windows-host-canary.yml` for `canary-edge-dev-win` and then restore
  the labels via the `was-` marker. If that pass died (Git Bash fork
  starvation killed an earlier attempt), re-run
  `AI_RUNNER_POOL_WATCH_SETTLE=5 bash bin/ai-runner-pool-watch health` from
  https://github.com/popcre/ai-devops/blob/main/bin/ai-runner-pool-watch and it
  will finish the loop; or set the labels back to `["edge-dev","ai-devops-windows"]`
  by `PUT repos/popcre/ai-devops/actions/runners/26/labels`. This state has zero
  routing impact (edge-dev-win carries no work label either way).
- `ai-shared-db-closeout-check` was launched in the background at wrap-up
  (output `/tmp/closeout-check.json`, marker `/tmp/closeout-check.done`) after
  the ai-gh lock starved it inline. Its JSON result must be checked: this
  session held **no** shared-db claims or author reservations (it never called
  the claim tooling), so it should report zero owned items — but verify rather
  than assume.

## 5. What we own right now

**Open PRs (all pushed, all handed over):** shared-db #5902
(branch `ci-process-repair/ledger-dispositions`, worktree
`D:/repos/shared-db-worktrees/ci-2.10-dispositions`), shared-db #5913 (branch
`ci-process-repair/jev-triage-reissue`, worktree
`D:/repos/shared-db-worktrees/jev-reissue`), popdam3 #858 (branch
`ci-process-repair/build-typecheck`, worktree
`D:/repos/popdam3-worktrees/typecheck-build`).

**Worktrees kept (live):** the three above. **Kept (dirty, named):**
`D:/repos/ai-devops-wt-32` (branch `ci-process-repair/step-3-2-host-health`
merged via #2438) still shows 4 modified files
(`bin/ai-pr-wait`, `tests/test-action-taxonomy.sh`, `tools/ci/action-taxonomy.sh`,
`tools/github-requests/pr-status-complete.sh`) — these are byte-duplicates of
the step-3-3 content that merged via #2444; safe to `git checkout --` and
remove the worktree next session. **Worktrees retired this session after
proving clean + merged:** `ai-devops-wt-33` (#2444 merged), `ai-devops-wt-status`
(#2441 merged), `shared-db-worktrees/ci-2.10-gate-graph` (#5884 merged).
**Left untouched deliberately:** the previous session's
`D:/repos/shared-db-worktrees/ci-2.5-evidence-lifetime` (its handoff asked for
retirement after #5871 merged — done condition met, but the wrap-up freeze
forbids new cleanup; run
https://github.com/popcre/shared-db/blob/main/scripts/reap-merged-worktrees.mjs
dry-run + the cleanup-worktree checks next session), and every other session's
worktree in `D:/repos/*-worktrees`.

**Background processes left running on edge-dev:** the drain driver (PID
26168-class, log `drain-backlog-v11.log`), `ai-runner-pool-watch health` (the
canary round-trip), `ai-shared-db-closeout-check`, and possibly stale
`test-ai-pr-wait.sh` instances (the suite completed its visible checks but its
summary line never arrived in `prwait.out.log`; the merged #2444 is now the
authoritative gate).

## 6. What we were about to do next

1. Watch the drain to completion: `Get-Content C:\Users\ahazan\AppData\Local\Temp\drain-backlog-v11.log -Tail 10`.
   For each `DELIVERED: <version> live in production`, append one evidence
   comment to https://github.com/popcre/shared-db/issues/4540 (version, run
   id, ledger read). When all four are live and #5902 has merged (so the four
   dispositions are machine-readable), do the live clean read
   (`select version from supabase_migrations.schema_migrations`) and close
   #4540 citing it — the alarm closes ONLY on that live clean read (the
   user's words).
2. Merge #5902 and #5913 through the shared-db merge queue when green (never
   `--admin`), then close review-finding #5860 as resolved (its decision is
   recorded; #5902 is the mechanical successor).
3. Merge popdam3 #858 when green.
4. Finish 4.2: the in-file justification comments (one small PR each in
   popdam3 / popcrm-web / poppim-web — the corrected audit table on #2367
   lists every line) and the oracle-CI/production-ledger separation.
5. Then 4.3 (it also owns the two daily-failing scheduled reporters —
   queue-hygiene-report failing daily since 11-03 and
   author-lane-abandonment-audit failing on unwired secrets), 5.1 (check
   plan_issue-2095 state first), 5.2, 5.3, 6.1.

## 7. Blocked on

- **The October billing-lock cause (step 3.3's second half)** needs the
  `admin:org` classic scope on the `gh` OAuth token (or a fine-grained PAT
  with "Organization administration: read" on `popcre`) to read spending-limit
  and payment settings. The current token has neither; vault PAT "GitHub PAT -
  u2giants repo push access" is dead (Bad credentials — needs rotation or
  deletion); the pop-ai-watchers app has no organization-administration
  permission. The routed external session (Claude Code) failed with "OAuth
  session expired". Exact named request if nothing else can grant the scope:
  Albert completes `gh auth refresh -h github.com -s admin:org` in a browser
  logged into github.com as u2giants (this is the one thing only he can do —
  payment-side actions would be the second, once the cause is read).
- Nothing else needs Albert.

## 8. What we tried that did NOT work (MANDATORY reading)

- **The drain driver's ledger reads were silently broken the whole time.**
  Production was read via `aws-0-us-east-1.pooler.supabase.com:5432` — the
  vault item's verified config is `aws-1-us-east-1.pooler.supabase.com:6543`;
  preview needs `aws-0...:6543` (the item's "POOLER HOST GOTCHA"). Every read
  failed ENOTFOUND and `ledger_has` returned None→False, so the driver thought
  nothing was delivered and could not see preview state. Fixed in v11. Anyone
  reusing the driver must keep the two poolers separate.
- **The merged-lane refuses versions already on preview** ("Hard guard
  preflight: BLOCKED: already applied on preview... dispatch the
  historical-recovery lane"). `20261021150012` and `20261028230411` are on
  preview — they must go the historical lane (driver's phase B) with their
  original apply runs (`42184929162`, `40811041674`); `20261022014315` and
  `20261022071323` are NOT on preview and take the merged lane. The driver's
  `preview_has` gate handles this — once its connection is right.
- **PR↔version pairs in the handoff's ITEMS were wrong for `20261015132149`.**
  The merged lane proved "versions were not added by pull request #4221" —
  PR #4221 added `20261013144638`, and commit `8717fc09f` re-reserved the
  stamp post-merge with no PR attached (it entered main through the
  recovery-era "Integrate" merges; `git log --first-parent` is useless there,
  use the commits API `.../commits/<sha>/pulls`). Correct pairs verified via
  that API. Never trust the old ITEMS table.
- **The production gate's exact-6-job graph refused all Oct-21 evidence.**
  Runs 42183400427 / 42184929162 carry 8 jobs (the workflow gained "Exact
  concurrent index maintenance" and "Nudge the production queue"); the gate
  only accepted 6 (and, since shared-db #5878, 7). Fixed by shared-db #5884
  (an explicit 8-job graph, mutation-tested). The same class of bug will
  recur when the workflow next gains a job — the graph is pinned on purpose.
- **`gh api -X PATCH .../actions/runners/{id}` 404s — there is no such
  endpoint.** Runner label writes are `PUT /repos/{owner}/{repo}/actions/runners/{id}/labels`
  (custom labels only; read-only labels preserved). Proven live on edge-dev-win.
- **Billing APIs are out of reach:** org billing endpoint returns 410 "moved"
  (new Budgets API is enterprise-scoped) and needs `admin:org`; user billing
  needs `user`; the vault PAT is dead; the GitHub App has no admin permission;
  browser/MCP tools are disabled in this session and the external agent route
  died on expired OAuth. See §7.
- **`merged_pr_issue_binding` refuses closed issues** (the previous session's
  finding, confirmed): the driver must never send it. With #5871 merged the PR
  alone keys the promotion freeze.
- **Run-id capture by recency is wrong** (`gh run list --limit 1`): the
  automatic queue dispatches concurrently and the driver watched the wrong
  run. v11+ identifies its run by the version string in the run-name.
- **A successful qualification run is NOT delivery** — it dispatches the
  serial production lane; the ledger fills later. The driver must poll
  (`wait_production`), not conclude at run completion.
- **Windows Git Bash fork starvation** ("fork: Resource temporarily
  unavailable", `ChildProcess.kill` wrapper errors) killed several background
  launches under load; `Start-Process` mostly still starts them — always
  verify by PID/log. `bin/ai-gh` hangs the tool wrapper on this machine —
  plain `gh` is the authorized fallback. PowerShell quoting mangles `gh --jq`
  strings with nested quotes — write jq filters to a file or use single
  quotes carefully.
- **test-workflow-policy.sh / test-ai-pr-wait.sh are extremely slow on
  Windows** (spawn-bound; load-manifest spawns jq per suite file). They are
  not hung — give them 10+ minutes or run them in the background; CI on Linux
  is the authoritative gate.
- **The first 4.2 audit table was wrong** (contents-API line numbers ≠ exact
  main; missed `continue-on-error`). Always audit from a checked-out tree.

## 9. Facts that may already be stale

- State snapshot 2026-11-06T18:33:41Z (1:33 PM EST): shared-db `origin/main`
  `6f34086a71fe36c03d622bb0dec40da37a912053`, max migration
  `20261106171924_sku_style_guide_resolution_input_snapshot.sql` (my reissue
  stamp `20261106190000` is still above it and lives only on PR #5913's
  branch). ai-devops `origin/main` `1f434bb76122d18877f2f4057b4fd9ecd04d7839`
  (includes merged #2444).
- Production ledger: 907 rows at 1:0x PM EST; the four safe versions were
  absent then. Preview carries `20261021063716`, `20261021150012`,
  `20261028230411` (and NOT `20261015132149`, `20261022014315`,
  `20261022071323`).
- Drain run ids in flight: `42266759482` (qualified; production lane pending
  for `20261021150012`). Older failed attempts: `42255292349` (freshness),
  `42259788279` (held by #5860 — for the retired `20261021063716`, expected),
  `42264120926` (wrong PR pair), `42265821402` (already-on-preview refusal).
- Review-finding #5860 is OPEN and holds PR #4531's promotion — correct and
  permanent for a retired version; close it as resolved only after #5902
  merges.
- The four dispositions' prose lives on #4540 (comments 6691363302 /
  6691721591) and in #5902's registry entries; the corrected 4.2 audit is
  #2367 comment 6692040912.

## Self-audit

A stranger can continue cold: the standing order (§0), the exact drain state
and its five failed-attempt lessons (§2, §8), which versions are safe vs
retired and WHY with production evidence (§2), the open PRs with branches and
worktrees (§5), the exact next actions (§6), the single blocked item and the
one plain request to Albert (§7), and the machine-local files of the live
driver and logs (§4–5). Every merged item cites its PR/commit; every open item
its URL. Signature and EST times throughout.

Posted by MiMo chat unknown on edge-dev
