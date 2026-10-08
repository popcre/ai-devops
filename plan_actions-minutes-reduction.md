# Implementation plan — cut GitHub Actions minutes (fewer runs, cancel stale runs, tiny checks on edge-dev3 first)

Related handoff: [HANDOFF.d/2026-10-07T2335Z-edge-dev3-claude-actions-minutes-reduction.md](HANDOFF.d/2026-10-07T2335Z-edge-dev3-claude-actions-minutes-reduction.md). Do not rewrite root `HANDOFF.md`.
Parent issue: https://github.com/popcre/ai-devops/issues/1464 (children: ai-devops #1459 A, #1460 B, #1461 C, #1462 D, #1463 E; shared-db #4067 B, #4068 C).

## STATUS

| Step | Status | Evidence |
|------|--------|----------|
| 0. Baseline measurement script + numbers | ✅ done (2026-10-07) | `tools/ci/actions-minutes-report.sh`; `docs/evidence/actions-minutes-baseline-20261007.txt` — 2026-10-06 hosted: shared-db 946 est. vs 935 billed (+1.2%), ai-devops 272 vs 266, DesignFlow 6 repos 80–118 each; org 1,743 |
| 1. Router/tiny jobs off GitHub-hosted (ai-devops `push-settle`, shared-db `route / Pick runner`) | ⬜ open | — |
| 2. Cancel superseded runs everywhere they are missing | ⬜ open | — |
| 3. Combine shared-db small PR workflows into one PR-checks workflow | ⬜ open | — |
| 4. Combine ai-devops small PR workflows (drift checks) into `verify.yml` or one guard workflow | ⬜ open | — |
| 5. edge-dev3 as the preferred runner for tiny jobs in every repo (more runner slots, busy fallback) | ⬜ open | — |
| 6. DesignFlow repos (separate rules) | ⬜ open | — |
| 7. Live proof: 3 days of billing numbers vs baseline | ⬜ open | — |

**Where a fresh session starts:** step 0, then take the first unticked child issue only. Re-read Part 3 before each phase.

---

## Part 1 — Why

### 1. Ultimate goal

Albert (owner, POP Creations, not a programmer) is paying for far more GitHub Actions minutes than the work needs: about 1,000–1,700 GitHub-hosted Linux minutes a day across `popcre` repositories in early October 2026. When done, the same checks still protect every change and every merge, but:

- each change starts **few** check runs instead of a dozen,
- a run made obsolete by a newer push **stops** instead of finishing,
- tiny checks run on Albert's own machine **edge-dev3** first, and only use GitHub's machines when edge-dev3 is offline or busy.

Target: GitHub-hosted minutes down at least 60% vs the step-0 baseline, with **no** check weakened, skipped, or made able to block merges because one machine is down.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Protection beats savings: never remove a required check to save minutes.

### 2. What this is

- `popcre/ai-devops` — AI workflow toolkit; CI in `.github/workflows/verify.yml` (main pipeline), plus small workflows (`merge-queue-drift.yml`, `reviewer-membership-drift.yml`, `docs-reachability.yml`, watchdogs). Merge queue on `main`. Runner routing for Windows/Linux in `tools/ci/runner-router.cjs` + `config/ci-runner-routing.json`.
- `popcre/shared-db` — shared Supabase schema repo; 44 workflows in `.github/workflows/`. Merge queue on `main`. Has a reusable router `runner-route.yml` (prefers self-hosted `edge-dev3-linux`, label `shared-db-linux`, else hosted fallback) used by `business-rule-library.yml`, `coldlion-promotion-contract-tests.yml`, `pr-guards.yml`, `prepack-exclusion.yml`, `tools-offline-tests.yml`.
- `popcre/designflow-*` (backend, bff, frontend, tracking, item-master, data-syncing) — DesignFlow PLM; different rules (identity `popcre`, branch `sandbox-albert` → PR to `develop`, never self-merge).
- **edge-dev3** — Albert's Ubuntu workstation: 24 cores, 62 GiB RAM, 1.8 TB SSD. Self-hosted runners registered per repo, each named `edge-dev3-linux`, **one job at a time each** (ai-devops labels `self-hosted, Linux, X64, ai-devops-linux`; shared-db `shared-db-linux`). `/tmp` moved from RAM to SSD on 2026-10-07 (see `plan_session-temp-cleanup.md`).
- Runners billed: `ubuntu-24.04` / `ubuntu-latest` = GitHub-hosted (counts against Albert's minutes, **each job rounded up to a full minute**). `blacksmith-*` = Blacksmith (separate bill, not GitHub minutes). `self-hosted` = free.

### 3. What triggered this

2026-10-07 Albert: "i used 1800 Actions minutes in 5 days. what are we doing wrong?" Billing API (`gh api "/organizations/popcre/settings/billing/usage?year=2026&month=10&day=N"`) showed: Oct 1–3 Windows hosted spike (4,842 min, already stopped — Windows now Blacksmith/self-hosted); Oct 5–7 Linux 944 / 1,743 / 1,493 min/day; biggest repos Oct 6: shared-db 935, ai-devops 266, designflow-backend 118, designflow-tracking 93. Then Albert asked for this plan (verbatim): "Combine the many small checks into fewer runs per change. Cancel runs that a newer change has replaced. Prefer this machine for tiny checks and only use GitHub's machines if this machine is unavailable or too busy."

### 4. Scope

In: GitHub-hosted job count and duration in ai-devops, shared-db, DesignFlow repos; concurrency/cancel rules; workflow consolidation; runner preference for tiny jobs; edge-dev3 runner capacity.
NOT in this plan:
- Blacksmith spend or moving heavy test shards (ai-devops PR #1448, session "Ubuntu Linux Runner setup", already routes Linux offline shards to edge-dev3 — coordinate, do not duplicate).
- WarpBuild repair.
- Removing or weakening any required check, any security/destructive-change guard, or the merge queue.
- Scheduled production workflows in shared-db (coldlion-*, production-*) — leave alone.

---

## Part 2 — What we already know

### 5. Current state (origin/main, 2026-10-07)

- shared-db: main PR workflows already have `concurrency` with `cancel-in-progress: ${{ github.event_name != 'merge_group' }}` (`tools-offline-tests.yml:59-62`, `database-contract-tests.yml:77-80`, `pr-guards.yml:62`). **No concurrency** on the five `shared-db-*-observation.yml` workflows (2870, 2874, 2875, 3737, 3882) that run on every `pull_request`. `merge-queue-gate.yml:70-72` has `cancel-in-progress: false` (deliberate).
- shared-db `runner-route.yml:29` — the router job itself runs on `ubuntu-latest`, so every routed workflow pays ≥1 hosted minute just to choose a runner.
- shared-db run volume: ≥1,000 workflow runs created 2026-10-06 00:00Z → 2026-10-07 ~23:00Z (API page cap hit). Sample of 150 runs, hosted jobs only (`/tmp/claude-1000/sdb_jobs.tsv` at planning time; rerun step 0 to regenerate): biggest billed items `PR Guards / Queue-sensitive checks (aggregate)`, `Database Contract Tests / Database contract applicability`, `ColdLion Promotion Contract Tests / Promotion contract tests (offline)`, `Tools Offline Tests / Tools offline tests`, plus `route / Pick runner` in every routed workflow — each ~1 minute.
- ai-devops `verify.yml:82-84` `push-settle` runs on `ubuntu-24.04` and only waits ("Quiet window for abandoned pushes") — pays hosted minutes to sleep, on every run (≈470 verify runs in 5 days). `merge-queue-drift.yml` and `reviewer-membership-drift.yml` run on `pull_request` on `ubuntu-24.04` (21 and 19 runs in 5 days).
- ai-devops runner-router job already runs on Blacksmith (`verify.yml` `runner-router`), not hosted.
- edge-dev3 runners: `gh api repos/popcre/<repo>/actions/runners` → ai-devops `edge-dev3-linux` online busy; shared-db `edge-dev3-linux` online idle. One slot each. An org-level runner group could not be listed (`gh` token lacks `admin:org`).

### 6. Root causes

1. **Many separate workflows per change.** Each workflow is ≥1 billed minute per job even for a 5-second check; a shared-db PR triggers ~10–12 workflows, again on every push and again in the merge queue.
2. **Router and wait jobs on hosted runners** (shared-db `route`, ai-devops `push-settle`).
3. **Missing cancel rules** on observation workflows.
4. **edge-dev3 has one slot per repo**, so it is "busy" most of the time and the router falls back to hosted.

### 7. Rejected approaches

- **Delete checks / make them optional** — weakens protection; violates §1.
- **Self-hosted only, no fallback** — a powered-off edge-dev3 would block every merge. Fallback is mandatory.
- **Cancel merge_group runs** — GitHub re-requests checks for the same queue entry; cancelling ejects PRs (shared-db #2530). Never.
- **Run the router on edge-dev3** — if the machine is down, the router never starts and the job waits forever. Router must run somewhere always available that is not hosted-billed: Blacksmith small Linux (as ai-devops does).
- **Put tiny jobs on Blacksmith instead of edge-dev3** — Albert chose edge-dev3 first (2026-10-07). Blacksmith stays for router jobs and heavy shards only.
- **Paths filters to skip workflows** — breaks required checks (a skipped required workflow never reports); use one always-running workflow that decides internally instead (shared-db already has the documents-only route pattern in `documents-fast-ci.yml`).

### 8. Decisions

Locked (Albert, chat, 2026-10-07): the three goals above; edge-dev3 preferred, GitHub-hosted only as fallback when edge-dev3 is offline or busy; no check weakened.
Locked (this plan): never cancel `merge_group`; required check names must not change without updating the repo rulesets in the same PR (memory `merge-queue-required-check-name-trap`); router jobs run on Blacksmith, not hosted, not self-hosted.
Open (implementer): how many runner slots edge-dev3 gets (criteria: keep ≥16 GiB RAM free under load, measured with `free -g` during a busy hour; start at 4 per repo); whether to use one org-level runner group (needs an org admin token — if unavailable, register per repo); exact grouping of shared-db workflows (criteria below).

---

## Part 3 — How to build it

### 9. Steps

**Phase A — measure (child issue A)**

0. Add `tools/ci/actions-minutes-report.sh` in ai-devops: for a repo and date range, list runs, fetch jobs, keep only `ubuntu-*`/`windows-*`/`macos-*` labels, round each job up to a minute, total by workflow/job. Also print billing API totals per day. Save today's output to `docs/evidence/actions-minutes-baseline-20261007.txt`.
   Done when: script reproduces the billing-API daily total within ±15% for shared-db on 2026-10-06.

**Phase B — quick wins (child issues B-ai-devops, B-shared-db)** — independent, parallel.

1. ai-devops: move `push-settle` (`verify.yml:82`) to `blacksmith-2vcpu-ubuntu-2404` (or fold its wait into the Blacksmith `runner-router` job). Move `merge-queue-drift.yml` / `reviewer-membership-drift.yml` `pull_request` jobs to the same router-chosen label (step 5) with hosted fallback. shared-db: `runner-route.yml:29` `runs-on: ubuntu-latest` → `blacksmith-2vcpu-ubuntu-2404`, keeping callers' literal hosted fallback if the router fails.
   Done when: a PR run in each repo shows zero hosted jobs for router/settle (`actions-minutes-report.sh` on that run).
2. Add `concurrency: { group: <workflow>-${{ github.event.pull_request.number || github.ref }}, cancel-in-progress: ${{ github.event_name != 'merge_group' }} }` to every `pull_request`-triggered workflow missing it: shared-db `shared-db-*-observation.yml` (5), `documents-only-merge-authorization.yml` check, ai-devops drift workflows, `docs-reachability.yml`. Do not change `merge-queue-gate.yml`.
   Done when: two quick pushes to a test PR show the first run of each workflow `cancelled`.

**Phase C — combine (child issues C-shared-db, C-ai-devops)** — cut point; fresh session OK.

3. shared-db: create `pr-checks.yml` that runs on `pull_request` + `merge_group` and calls the small checks as **jobs or steps of one workflow** (reusable `workflow_call` workflows count as one run). Group by runner/length: tiny checks (<2 min: observation 2870/2874/2875/3737/3882, prepack-exclusion, business-rule-library, task-gates, migration-author-lease, destructive-analysis-guard, documents-only-merge-authorization) as **steps in one job**; keep heavier ones (database-contract-tests, tools-offline-tests, coldlion-promotion-contract-tests, shared-supabase-migrations) as separate jobs in the same workflow. Keep each required check's **context name** identical (`<workflow name> / <job name>` changes when moved — update rulesets in the same PR via `config`/ruleset files the repo uses, or keep a thin aggregate job named exactly as today). Follow shared-db rules: this is CI tooling, not schema — check `AGENTS.md` there for the CI change lane; branch + PR + merge queue.
   Done when: a normal shared-db PR creates ≤3 workflow runs (was ~10–12) and all required checks report.
4. ai-devops: fold `merge-queue-drift.yml` and `reviewer-membership-drift.yml` PR-time checks into `verify.yml` as jobs on the router label (keep their schedules as-is). Keep check names via the required-check list in `config/repository-policy.json`/rulesets.
   Done when: an ai-devops PR shows only `verify` (plus qualify Windows when relevant).

**Phase D — edge-dev3 first (child issue D)** — depends on step 1.

5. Capacity: register additional runner instances on edge-dev3 (`edge-dev3-linux-2..4`) for ai-devops, shared-db, each as a systemd service under user `ahazan`, same labels. Prefer one org-level runner group for all `popcre` repos if an org-admin credential exists (1Password vault `vibe_coding`, search "popcre org admin"); otherwise per repo. Routers (ai-devops `tools/ci/runner-router.cjs`, shared-db `runner-route.yml`) already pick self-hosted when an idle runner exists; extend them to count idle slots and pick hosted only if **all** edge-dev3 slots are busy or offline. Route the tiny-check job from step 3/4 through the router.
   Done when: during a normal day ≥80% of tiny-check jobs run on `edge-dev3-linux*` (report script), and with the runners stopped (`systemctl --user stop`) a test PR still completes on hosted.
   Gotcha: runner jobs write to `/tmp` — after `plan_session-temp-cleanup.md` lands, give runner services `TMPDIR` under their `_work` dir and clean it per job.

**Phase E — DesignFlow (child issue E)**

6. Apply steps 2 and 5 pattern to `popcre/designflow-*` only through DesignFlow rules: identity `popcre`, branch `sandbox-albert`, PR to `develop`, **Albert reviews; never self-merge**. Measure first with step 0; if a repo is <30 min/day, only add concurrency.

**Phase F — proof**

7. After all merged, run `actions-minutes-report.sh` for 3 consecutive weekdays; post totals vs baseline on the parent issue.
   Done when: hosted minutes ≥60% below baseline and no merge-queue ejections caused by the changes (`gh pr list --search "is:merged"` sample + queue history).

### 10. Tests required

- ai-devops: extend `tests/test-runner-router*.{sh,cjs}` (existing router suite) with cases: all slots busy → hosted; one idle → self-hosted; runner API failure → hosted; offline → hosted; fork PR → hosted.
- ai-devops workflow-policy test (existing, run by `verify`) must accept new concurrency blocks and fail on any `cancel-in-progress` that can be true for `merge_group` — add that assertion.
- shared-db: its existing workflow lint/guard tests (`pr-guards.yml` job suites) stay green; add a check that every `pull_request` workflow has a concurrency group.
- `tools/ci/actions-minutes-report.sh`: offline test with a fixture JSON of runs/jobs → expected totals (rounding up to minutes, hosted-only filtering).

Adversarial cases (routing decides where untrusted PR code runs):

| Input | Hostile case | Test |
|---|---|---|
| PR from a fork | fork code on Albert's machine | router test "fork PR → hosted" |
| runner API response | lookup fails / rate-limited | router test "API failure → hosted" |
| all runners offline | merge blocked | router test "offline → hosted" + live stop test (step 5) |
| merge_group event | cancellation ejects queue entry | policy assertion "no cancel on merge_group" |

### 11. Constraints and gotchas

- Never push to protected `main`; branch, PR, merge queue (`gh pr merge <n>` without `--squash`/`--admin` — queue sets strategy). Albert does not merge; the implementer does (except DesignFlow).
- Code/workflow PRs need the assigned AI reviewer APPROVE at exact head (`ai-review`; allocator chooses). Docs-only PRs skip.
- Changing a required check's name without ruleset update leaves PRs stuck "Expected — waiting" (memory `merge-queue-required-check-name-trap`).
- `gh run watch` burns API quota; use `bin/ai-pr-wait`.
- Self-hosted runner must never run fork PR code.
- Sign every GitHub post `Posted by <engine> chat <id> on <machine>`. Times in EDT.
- shared-db: CI tooling changes follow that repo's AGENTS.md lane; never touch schema/migrations here.

### 12. Access and environment

edge-dev3 shell user `ahazan` (no passwordless sudo — runner install must be user-level; if root is required, report Blocked with the command). `gh` authenticated as `u2giants` with repo access to popcre repos; no `admin:org` scope. Billing API works: `gh api /organizations/popcre/settings/billing/usage?year=Y&month=M&day=D`. Runner registration tokens: `gh api -X POST repos/popcre/<repo>/actions/runners/registration-token` (repo admin). Secrets only via 1Password vault `vibe_coding`, never in chat/args.

---

## Part 4 — Landing

### 13. Definition of done, risks, open questions

Done: each child issue closed with merged PR SHA + green CI + report output; STATUS rows cite artifacts; 3-day proof posted on parent; handoff updated; parent closed only after live proof.
Risks: renamed required checks stall PRs (rollback: revert PR); edge-dev3 overload slows Albert's desktop (reduce slots); router bug sends everything hosted (no breakage, just cost — report script catches it).
Open: org-level runner group availability; final slot count (measure); whether DesignFlow savings justify changes there (measure in step 0).

### Self-audit (2026-10-07)

1. Fresh session executes without asking? Yes — repos/runners/billing explained §2, exact files and lines §5, steps with gates §9, access §12. Open choices have criteria §8.
2. All background incl. rejected? Yes — §3 numbers, §6 causes, §7 six rejected options (no fallback, cancel merge_group, router on edge-dev3, Blacksmith-first, paths filters, deleting checks).
3. Goal clear for judgment calls? Yes — §1 target plus "protection beats savings" and the goal-wins rule.
