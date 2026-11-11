---
summary: Plan to repair the CI process (issue 2367) with phased steps, many done and some still closing or in progress.
kind: plan
status: open
read-when: Working on CI process, ci-red, or required-check repair
---

# Implementation plan: CI process repair

- **Owner issue:** [popcre/ai-devops#2367](https://github.com/popcre/ai-devops/issues/2367). Unproven outcomes stay as checklist items on that issue.
- **Handoff:** [HANDOFF.d/2026-11-04T2324Z-al8960ofc-claude-ci-process-repair-plan.md](HANDOFF.d/2026-11-04T2324Z-al8960ofc-claude-ci-process-repair-plan.md).
- **Baseline:** [tests/verification/ci-process/baseline-2026-11-04.md](tests/verification/ci-process/baseline-2026-11-04.md).
- **Written:** 2026-11-04 6:30 PM EST, Claude on al8960ofc, main at `069c4b09`.

## STATUS (read first)

| Step | Work | State | Evidence |
|---|---|---|---|
| 0.1 | Retire stale automatic-fix pull requests, stop new ones going stale | ✅ done | PR #2383; 33 stale fixer PRs closed 2026-11-04 (shared-db 19, ai-devops 14, findings all closed), 4 theoracle conflicted PRs retired and re-dispatched once (#279, #283, #289, #304); 62 fixer-state tests cover finding-closed and idle |
| 1.1 | `merge-group-evidence` stops reporting an unfinished run as failure | ✅ done | PR #2388; `--accept-pending` reports an unfinished run as "evidence pending" (job summary + exit 0), finished-failed and mismatched stay red, direct callers keep the fail-closed exit codes; 67 evidence tests pass (5 new) and 39 closure tests pass. Live proof satisfied 2026-11-05 (tracker comment) |
| 1.2 | Repair the tests failing today on Linux | ✅ done | PR #2392; executable bit and .cmd launcher for `bin/ai-transcripts-to-dropbox-hetz`, cleanup trap in `bin/ai-transcript-upload`, and the `test-ai-transcript-query` machine-state assertions updated for #2358 (none deleted). Five consecutive green merge-queue Linux shards satisfied 2026-11-05 (tracker comment) |
| 1.3 | New suites register themselves | ✅ done | PR #2393 + PR #2397 (commits `1d371a1c`, `2f1a7127`); the loader discovers `tests/test-*.{sh,ps1}` and synthesizes an entry for each suite with no JSON; the hand-maintained `path_suites` map is gone; 22 loader tests pass (5 new) |
| 1.4 | A real test failure after merge gets an owner automatically | ✅ done | PR #2399 (`bad96f82`); merge-group failures with a `result` taxonomy open/update one `ci-red` issue per failing test and close it after later green runs; capacity failures produce none |
| 1.5 | `review-fixer` stops running on every push and branch delete | ✅ done | PR #2402 (`49061d38`) + callers in shared-db (`9cb5b070`), theoracle (`ae6852d9`), popdam3 (`cc8cef61`); retirement runs on the two-hourly schedule and finding-closed events |
| 1.6 | Advisory shared-db gates stop saying REFUSED for things they do not stop | ✅ done | shared-db PR #5694 (`4b9da311`); advisory gates say "advisory: would have ..."; the Cross-PR object collision job is retired |
| 2.1 | Paperwork refusals removed from post-merge rehearsal and promotion | ✅ done | shared-db PR #5738 (`aebec3ba`) + PR #5871 (`74dc1245`); a merged migration whose PR closes no issue promotes on the PR alone |
| 2.2 | Promotion trigger reports expected holds as success | ✅ done | shared-db PR #5753 (`b61e76ab`); holds, waits, used-up attempts and acknowledged history exit 0 with the reason in the summary |
| 2.3 | A change out of promotion attempts gets an owner | ✅ done | shared-db PR #5770 (merged 2026-11-05); exhausted attempts open one owned issue with the merged-not-live duration; later independent changes promote past a failed one |
| 2.4 | Post-apply catalog check stops marking good applies red | ✅ done | shared-db PR #5786; catalog change-type tracking reports "applied, not verifiable by catalog" as success with a note; a wrong object still goes red |
| 2.5 | Preview evidence stops expiring for unrelated reasons | ✅ done | shared-db PR #5833 (`8f9ea126`); evidence survives unrelated workflow edits; changed migration bytes, apply tool or the apply workflow still void it |
| 2.6 | Large-table migrations are caught before production | ✅ done | shared-db PR #5840 (`f4f60c70`); large-table preflight in both apply lanes; bounded atomic statement timeout; atomic policy parity on both targets |
| 2.7 | Migration version ordering decided and made true | ✅ done | shared-db PR #5847 (`90486a1e`); crossed versions land in merge order, duplicate versions refuse; guard, advisory gate and promotion share one rule |
| 2.8 | Fix the temp-folder cleanup flake and the unbounded jobs | ✅ done | shared-db PR #5853; 149 test cleanups retry the ENOTEMPTY class; every job has a budget |
| 2.9 | Retire dead shared-db workflows | ✅ done (record-only) | Dependency check proved nothing is deletable from shared-db alone (observation workflows have active designflow-backend consumers; the lane-policy test surface pins author-lane-abandonment-audit). Disposition table: https://github.com/popcre/ai-devops/issues/2367#issuecomment-6679391844 |
| 2.10 | Reconcile open ledger drift alarm #4540 | 🟡 closing | All four safe versions drained live 2026-11-06 (production ledger read on #4540; runs 42290916442/42292326892/42293840317/42295011388); dispositions registry merged (#5902), reissue merged (#5913, renamed 20261106214905 after a backdated-stamp ejection), review-finding #5860 closed. Last pre-activation straggler 20261021152741 proven superseded by applied re-land 20261021190510; retirement PR #5931 in the queue. Remaining alarm entries are post-activation automatic-queue backlog the selector owns |
| 3.1 | Runner labels checked against what exists | ✅ done | PR #2425; `tools/ci/check-runner-labels.mjs` + weekly `runner-label-scan.yml` + fixture test; live scan of 171 workflows clean |
| 3.2 | Slow or dead Windows hosts leave the pool automatically | ✅ done | #2438 merged; live round-trip proven 2026-11-07: the host PATH repair (missing `Gitin` for the NETWORK SERVICE account — root cause of its never-started signals) landed, canary run 42425615521 passed, and the labels restored to the work set (tick log `RESTORED ... canary_run=42425615521`; tracker comment 6714544504) |
| 3.3 | Billing lock detected and named; cause established | ✅ done | #2444 named the state; cause recorded 2026-11-08 (tracker comment 6725146141, read live with the granted admin:org scope): a $70/month Actions budget with prevent_further_usage on popcre stops runs at the cap; alerts to u2giants confirmed by read-back; sister $0 budgets deliberately disable Codespaces/Packages/LFS |
| 3.4 | Registry and API limits stop failing checks | ✅ done (verified, no code change) | Mirror in place since #3451; shared transport already does bounded retry; measured busiest hour 393 runs (vs ~950 incident level). Evidence in the tracker comment linked from 2.9 |
| 3.5 | Required-check lists protected from silent reversal | ✅ done | PR #2427; `config/required-checks-expected.json` + daily `required-list-drift.yml` + `tools/ci/check-required-lists.mjs` (`--apply` restores exactly the ruling list) |
| 4.1 | Deploys prove the live version | ✅ done | popdam3 `6d75ec71`, popcrm-web `f9fc0987`, synology-monitor `819ff4f4`, theoracle `113b2361`, shared skill `6249cdd8`, poppim-web PR #24 (`0eb3de6`) + deploy proof fix `648b4e4`; each deploy compares the live version with the merged commit and fails on mismatch |
| 4.2 | Swallowed failures removed from app workflows | ✅ done | Every corrected-audit entry justified in-file: popdam3 #859, poppim-web #25, popcrm-web #25 (merged 2026-11-06); popdam3 type check in build #858; oracle CI separated from the production ledger (theorcle #469, drift-watch.yml post-merge, first run green). Enabling fixes popdam3 #860 (audit scoped to the shipped tree, ubuntu-24.04 pin). Tracker: comment 6694939036 |
| 4.3 | Scheduled workflow failures reach an owner | 🟡 list done | Inventory of 29 scheduled workflows across six repos with reporting paths on #2367 (comment 6696252846). Today's two failing ones dispositioned: queue-hygiene was a correct alarm on a genuinely stuck queue (green since); author-lane-abandonment-audit fails closed BY DESIGN on claims #5662/#5652 (no work-issue reference in title — owners notified). Follow-up: wire red-run-only monitors through the 1.4 route |
| 5.1 | Waiter names the reason for a stall | ✅ done | Prerequisite plan_issue-2095 landed (#2447). #2449 merged: `queued too long` warn window, `still queued at the deadline` names the two runner-stall causes, billing/capacity/review-step/failing-test named from #2444/#2447, cheat-sheet documents them all. One fixture per reason |
| 5.2 | Merged-but-not-installed is visible | ⬜ open | — |
| 5.3 | Transcript store: remove the false label, close redaction gaps | ✅ done | PR #2456 (two redaction patterns + v6 generic-example prompt, with tests); PR #2465 (reredact.py — re-applies patterns to PUBLISHED stored text; run 2026-11-08: 4 residual segments scrubbed into store-20261108T212129Z, whole-store residual scan 0); false-label note in the store's reports folder; verification on the tracker (comment 6727319257) |
| 6.1 | 7-day live acceptance against the targets in section 13 | ⬜ open | — |

**A fresh session starts at step 0.1.** Phases 1 to 5 can run in parallel after that, one session per phase. Re-read later phases before starting each one, because the existing owners below keep landing work.

## Part 1: Why

### 1. The ultimate goal

Albert runs POP Creations and is not a programmer. AI sessions build everything. CI is the machinery that checks each change, merges it, and puts it live.

When this work is done, four things are true that are not true today:

1. **A correct change goes live without anyone waiting or intervening.** Database changes reach production automatically. Albert is never involved.
2. **Red means something real.** A failed check points at a real problem that already has an owner. Today, most failures are noise, so sessions ignore them or misread them.
3. **Green means something real.** A pass means the code was tested, or the site really runs the new version.
4. **Outside stops are named immediately.** A billing lock, a missing runner or a rate limit is identified at once, in plain words.

**If a step conflicts with this goal, the goal wins. Stop and flag it on #2367.**

### 2. What this application is

- `popcre/ai-devops` (public, this repo) is the toolkit for all AI sessions. CI: `.github/workflows/verify.yml`, with the required check `verification-closure` and a merge queue.
- `popcre/shared-db` (public) holds the shared Supabase database structure. CI is 52 workflows. Merged migrations go to a preview database, then automatically to production through `shared-supabase-migrations.yml` and `automatic-production-trigger.yml`.
- Application repos consume these: `u2giants/theoracle`, `u2giants/popdam3`, popcrm-web, poppim-web, monitor and the private `popcre/designflow-*` repos. DesignFlow deploys through Google Cloud Build. Hetz apps deploy through Coolify.
- Runners: GitHub-hosted (free on public repos), edge-dev3 (Ubuntu, self-hosted), and Windows self-hosted hosts with labels in `config/ci-runner-routing.json`.

Terms: **merge queue** is GitHub's line that tests a change on top of current main before merging. **Preview rehearsal** applies a migration to a copy before production. **Ledger** is the database's record of applied migrations. **Advisory check** reports but cannot stop a merge. **Fixer** is `review-fixer.yml`, which turns review findings into fix pull requests.

### 3. What triggered this work

On 2026-11-04 Albert asked for all CI transcripts to be reviewed and for a plan solving every problem in the CI process.

The review read all 7,152 CI-tagged segments, April 5 to November 4, 2026, across 16 reading passes. Live GitHub data was then read to separate history from today's problems. Full private catalogue, with segment ids and examples: `Dropbox/ai/transcript-store/reports/ci-findings-2026-11-04/` (never paste it into GitHub).

### 4. Scope

**In:** every problem still live in section 6, in ai-devops, shared-db and the app repos' CI and deploy workflows.

**NOT in this plan:**

- Work with an existing owner, listed in section 5. Do not redo it.
- Adding any required check. Adding any review gate.
- Paid runners, or reducing Actions minutes (owner cancelled that 2026-10-07).
- Rebuilding the merge queue or moving off GitHub Actions.
- DesignFlow branch policy. Application feature bugs that merely carried a `ci` tag.
- GitHub request-count reduction, which #658 owns.

## Part 2: What we already know

### 5. Current state

**Already solved. Do not re-solve, and do not bring back:**

| Past problem | What ended it |
|---|---|
| AI reviews blocking merges, for months the largest pain | Owner rulings 2026-10-29; [plan_skinny-review.md](plan_skinny-review.md) |
| Exact-head approvals voided whenever main moved | Same rulings |
| Too many required checks | Owner ruling 2026-10-30; ai-devops requires `verification-closure`; shared-db requires three data-safety checks |
| Evidence-pair files, guarded merge, author-lease checks | shared-db stage C1 and C2 |
| Queue entries that never start checks | shared-db #4766, #4773 |
| Hour-long serial Windows job | Sectioned lanes |
| Waiter defects and unfair GitHub request lock | #2094, #2219, #2225, #2229 |
| Blacksmith runners, which left 59 runs queued | #2339, shared-db #5572, router #2345 |
| Promotion stopping at the first bad change | The trigger now says later changes still promote. Confirm in step 2.3 |

**Existing owners. Finish through them, and only link from here:**

| Owner | Covers |
|---|---|
| [plan_issue-2172.md](plan_issue-2172.md), shared-db #5228 | Remaining claim and lane code removal |
| [plan_issue-988.md](plan_issue-988.md) | Weekly complete verification being red |
| [plan_issue-2340.md](plan_issue-2340.md) | Runner wording and manual Windows timeout |
| [plan_issue-2095.md](plan_issue-2095.md) | `ai-pr-wait` advisory-failure wording |
| [plan_issue-2346.md](plan_issue-2346.md) | Heartbeat request throttling |
| [plan_issue-1941.md](plan_issue-1941.md) | Slow Windows GitHub authentication |
| [plan_github-request-reduction.md](plan_github-request-reduction.md), #658 | GitHub request volume |

[plan_ci-reviewers-runners-remediation.md](plan_ci-reviewers-runners-remediation.md) predates the rulings and has no owner issue. Where it conflicts with this plan, this plan wins. Do not execute its review rows.

Nothing in this plan has been implemented. The plan, its baseline and the handoff are the only changes.

### 6. Key findings

Numbers come from the [baseline](tests/verification/ci-process/baseline-2026-11-04.md).

**A. ai-devops results carry almost no signal.**

- `verify` failed 66 of 72 merge-queue runs over four days. 13 of the last 20 merged pull requests merged with a failed check.
- The largest cause is a race. `bin/ai-merge-group-evidence:256` rejects when the pull request's own run is unfinished. Since general tests became advisory, changes reach the queue before that run ends. `verify.yml:212` runs it, and `verification-report` turns it red.
- Real tests are also failing and nobody owns them: `tests/test-ai-transcript-query.sh:62`, `tests/test-github-request-qualification.py` (`ActiveParentTests`), `tests/test-ai-task-gates-linux-install.sh:315`.
- This is the side effect of the lean-checks ruling. Tests stopped blocking, but nothing replaced the pressure to fix them.

**B. The fixer is most of the traffic.** `review-fixer.yml:17-18` triggers on every `push` and `delete`. That was 675 of 1,000 ai-devops runs, and 156 of 1,000 in shared-db. On 2026-09-28 about 950 runs in an hour exhausted the GitHub limit and stopped merges and production recovery.

**C. Stale fixer pull requests accumulate.** shared-db has 19 open, 11 with conflicts, some from 2026-10-30. #5541 belongs to a finding that is already closed, and carries a migration version older than current work.

**D. shared-db's advisory gates produce false alarms.** `merge-queue-gate.yml` is advisory but logs REFUSED. It refused #5579, #5588 and #5590 for being behind #5541, and all three merged. Two consequences: readers wrongly believe the queue is blocked, and the version-order rule it describes is not enforced by this gate.

**E. Production promotion has failed in a new form after every fix.** This was the longest-lived pain. Named causes:

- Paperwork at apply time. A merged change is refused for not naming exactly one structural issue, and retries the same refusal (`scripts/manage-migration-coordination.mjs`, `scripts/merged-pr-issue-binding.test.mjs`).
- The trigger exits red for normal states such as a hold (`automatic-production-trigger.yml`, `scripts/automatic_promotion_candidates.py`).
- Post-apply catalog verification marks successful applies red for change types it does not recognise (`scripts/production_catalog_verification.py`).
- Preview evidence expires when workflow files change or main moves. This forced changes to be reissued under new versions, up to nine times for identical SQL.
- Statement timeouts on production-size tables are not rehearsed. #1427 and #5165 passed preview and failed production.
- A failed change can have no owner. #5165's issue was closed unfixed after its session went silent.
- The worst outcome was the backlog of 63 merged but unapplied migrations, which took the DesignFlow sandbox login down on 2026-08-12.

**F. Ordering conflicts are real.** Migration timestamps are reserved early, so a slower change falls behind. Duplicate timestamps were once silently skipped. Backdated renames caused weeks of churn (the "backdated" refusal in SQL migration guards).

**G. Flaky checks.** The temp-folder `ENOTEMPTY` cleanup race in shared-db's guard tests recurred repeatedly from 10-23 to 11-04, always cleared by rerun. Timeouts set inside normal variance killed healthy runs. Merge Queue Gate has reached 757 minutes and Database Contract Tests 224.

**H. Windows.** Tests get written for Linux and fail on Windows through shebang fakes, CRLF, path rewriting, `fcntl`, file modes and symlinks. New suites can miss the manifest, which once silently skipped all Windows sections (run 41340783808). Slow hosts cause timeouts. Smart App Control left EDGE-RUNN-ENVY and EDGE-ALIEN accepting jobs they could not launch. The router cannot avoid such a host.

**I. Outside stops.**

- A real GitHub billing lock stopped all hosted jobs on 2026-07-27 and on 2026-10-28 and 10-29. Its cause was never recorded.
- Registry rate limits broke the required database test on every pull request once.
- The retired-runner outage was first reported as "cause not established".
- Another session reverted the shared-db required list on 2026-10-30, and it had to be reapplied.

**J. "Billing lock" is mostly a false label.** About 900 segments have that subject. `tools/transcript_store/prompt_v5.txt:53` and three older prompts use "Merge queue blocked by billing lock" as their example header, and the summariser copied it. Most bodies are unrelated. One owner escalation was prompted by the wrong label. Do not count by that subject.

**K. Green but not live.** Across five apps, builds passed while production stayed old, once for over 8 days, through a registry write denial, mutable tags and no-op deploy calls. Workflows swallowed failures, which hid a stuck version for 12 days. PopDAM stays on the old page silently after a failed deploy. Its build skips the type checker, so type errors ship. DesignFlow build triggers broke four times in six weeks.

**L. Scheduled and watcher workflows.** Scheduled workflows failed unseen for days. In the sample read today, No-progress alarm, Queue Hygiene Report and ColdLion Order Intake had failures. Confirm each is still failing in step 4.3.

**M. Agent behaviour multiplies all of it.** Idle waiting, hand-written polling, blind reruns and wrong diagnoses appear in every period, including a subagent that spent over 200k tokens repeating that it was waiting. Standing rules exist. The remaining cause is tools that do not say why something is stuck.

### 7. Approaches rejected, and why

| Rejected | Why |
|---|---|
| Making tests required again to restore signal | Violates the 2026-10-30 ruling. Long required checks caused 10-hour merges |
| Automatic reruns to clear flakes | Hides real failures; reruns are already the habit that left `ENOTEMPTY` unfixed |
| Self-hosted or paid runners as the main fix | Blacksmith cost and outage led to its removal; self-hosted hosts caused much of the Windows pain |
| Cutting minutes or merging workflows to save money | Owner: "if it's just pennies, i don't really care". Public repos are free. Reduce runs only for rate limits and noise |
| Another coordination layer, lock or lease | These were a main source of outages; removal is what worked |
| New wait tooling | Owner ruling 2026-10-21: no new wait tooling. Extend `ai-pr-wait` |
| A new CI dashboard or service | More moving parts. The baseline command is enough |
| Serving the queue one change at a time everywhere | shared-db does this for ordering. Extending it costs throughput |
| Filing CI failures as `review-finding` in shared-db | An open finding holds production promotion, so a flaky test would stop releases |
| Trusting the "billing lock" subject count | False label, finding J |

### 8. Decisions

**Locked (do not relitigate):**

- Review is advisory; no review gates anything (owner, 2026-10-29).
- Promotion is automatic after preview rehearsal, tests, and no open real finding (owner, 2026-10-29).
- Only checks stopping production-data damage or secret leaks may block. A hanging or flaky required check is dropped first and repaired after (owner, 2026-10-30).
- Blacksmith is gone; fork pull requests never use self-hosted runners; hetz is not a runner (2026-11-03).
- EDGE-ALIEN keeps lighter section work (owner, 2026-10-06). Envy and alien stay runner-only.
- No manual production command. Migrations reach production only through the promotion workflow.
- No human approval is requested. Albert gets business questions only.

**Open (implementer judges, using the criteria in the step):** the fixer's trigger design (1.5), the ordering design (2.7), and how evidence reports a pending run (1.1).

## Part 3: How to build it

### 9. The plan

Each step lands as its own small pull request. Shared-db steps land in `popcre/shared-db` and load the `shared-db-change` skill first.

#### Phase 0: clear the noise source

**0.1 Stale fixer pull requests.** Files: `tools/ci/review-fixer.sh`, `tools/ci/review-fixer-state.py`.
- First, close every open fixer pull request whose source finding is closed, starting with shared-db #5541. Keep the branch so it is recoverable. For an open finding with a conflicted pull request, close the pull request and re-dispatch the finding.
- Then make it permanent: when a finding closes, close its fix pull request; a fix pull request idle over 48 hours or in conflict is retired and its finding re-dispatched once. Reuse the existing stale-retirement path from #2171.
- **Done when:** shared-db has no fixer pull request older than 48 hours, the fixer tests cover finding-closed and idle cases, and the queue gate no longer names #5541.

#### Phase 1: red and green mean something (ai-devops, plus 1.6)

**1.1 Evidence race.** Files: `bin/ai-merge-group-evidence:256`, `verify.yml:212-245`, `tools/ci/verify-closure.sh`.
- An unfinished pull-request run is reported as "evidence pending" in the job summary and is not a failure. A finished run that failed stays red, and stays advisory. Mismatched commits stay red. Keep exit codes for direct callers. Judgment call: a flag or a separate exit code, whichever keeps the existing fail-closed tests truest.
- **Done when:** tests for the command cover the pending case, and a change queued while its pull-request run is active shows `merge-group-evidence` green with a pending note.

**1.2 Today's failing tests.** Files: `tests/test-ai-transcript-query.sh:62`, `tests/test-github-request-qualification.py`, `tests/test-ai-task-gates-linux-install.sh:315`.
- Line 62 hard-codes `EDT` and a fixed date format. It may depend on recent store changes (#2358), or on the season. `ActiveParentTests` and the awk test began failing around the runner change (#2339, #2347), so suspect GitHub-hosted environment differences first. Fix the cause. Never delete the assertion.
- Then read the current failure list again and fix whatever remains.
- **Done when:** five consecutive merge-queue runs have green Linux shards.

**1.3 Self-registering suites.** Files: `config/ci-suite-manifest.json`, `tools/ci/classify-changes.sh`, `.github/workflows/fast-classifier.yml`.
- Discover suites by file pattern, keeping the manifest only for exceptions such as section placement and platform. This removes merge conflicts, and a new suite defaults to running on both systems. A new suite failing on Windows stays advisory and is reported through 1.4.
- **Done when:** a pull request adding a suite with no manifest edit runs it on Linux and Windows, and a test proves that a missing entry cannot skip sections.

**1.4 Automatic owner for real failures.** Files: `tools/ci/report-scheduled-failure.sh`, `tools/ci/action-taxonomy.sh`, `verify.yml:560`, `.github/workflows/review-fixer.yml`.
- Extend the existing reporter to merge-group runs. When a failure's taxonomy is `result` (not capacity), open or update one issue per failing test, labelled `ci-red`, with run links. Close it automatically after three later green runs of that test. The fixer also accepts `ci-red`.
- This is advisory: it blocks nothing. A test failing on two or more unrelated changes is treated as flaky and gets the same issue.
- **Hard rule:** never use `review-finding` for this. In shared-db that label holds production.
- **Done when:** a deliberately broken test on a scratch pull request produces exactly one issue and then a fix pull request; capacity failures produce none; the issue closes after repair.

**1.5 Fixer traffic.** File: `.github/workflows/review-fixer.yml:13-18`.
- Remove the `push` and `delete` triggers if stale retirement can use `pull_request_target`, finding-closed events and the existing two-hourly schedule. Criteria: fix pull requests are retired within the schedule interval, and no model starts on the events removed. Apply to callers in other repositories too.
- **Done when:** the re-measured `review-fixer` share of runs is under 15% in both repos and the retirement tests pass.

**1.6 Honest advisory gates (shared-db).** Files: `merge-queue-gate.yml`, `scripts/merge-queue-contract.mjs`, `pr-guards.yml`.
- An advisory gate must not print REFUSED or imply a merge is stopped. Use "advisory: would have ...". Remove the `Cross-PR object collision` job and other retired-process jobs, per the 2026-10-30 ruling, and keep only what step 2.7 settles. Coordinate with #5228.
- **Done when:** no advisory workflow log contains REFUSED for a change that merged, in a one-week sample.

#### Phase 2: shared-db delivery

**2.1 Paperwork.** Files: `scripts/manage-migration-coordination.mjs`, `designflow-sandbox-migrations.yml`, `shared-supabase-migrations.yml`, `scripts/production_business_risk_gate.py`.
- A merged change is never refused for its pull request's wording, labels or issue links. Remove those conditions from rehearsal and promotion. Keep every data-safety condition: exact merged source, rehearsal success, tests, no open real finding. Move any useful wording hint to an advisory note at pull-request time.
- **Done when:** a merged migration whose pull request closes no issue promotes automatically, and the tests cover it. See the adversarial table.

**2.2 Trigger reporting.** Files: `automatic-production-trigger.yml`, `scripts/automatic_promotion_candidates.py`.
- Exit success for holds, waits, used-up attempts, and acknowledged history, with the reason in the summary. Exit failure only when the trigger itself broke. Also trigger on failed apply as well as success, so the queue does not idle until the hourly timer.
- **Done when:** `scripts/test_automatic_promotion_candidates.py` covers each state and the trigger's failure count over a week is only real trigger defects.

**2.3 Owner for a stuck change.** Same files.
- Confirm in a test that later changes promote past a failed one when their objects do not depend on it. After the attempts run out, open or update one issue with delivery wording and the failure text. Dispatch a repair session through the existing fixer, under its existing permissions. Include how long the change has been merged and not live.
- **Done when:** a failing rehearsal fixture produces one owned issue, later changes promote, and no merged migration waits over 24 hours without an open owned issue.

**2.4 Catalog check.** File: `scripts/production_catalog_verification.py`.
- List every change type found in the migration history. For types it cannot verify, report "applied, not verifiable by catalog" as a success with a note, and never a failed apply. Types it can verify and that really differ stay red. The ledger remains the record of what applied.
- **Done when:** replaying every migration from the past 60 days through the verifier gives no false red, and a deliberately wrong object still goes red.

**2.5 Evidence lifetime.** Files: `shared-supabase-migrations.yml`, `scripts/production_business_risk_gate.py`.
- Tie preview evidence to what affects the database: migration bytes, base migrations, and the apply tool. Unrelated workflow edits and main moving must not void it. Never reissue identical SQL under a new version: rerun the rehearsal instead.
- **Done when:** a workflow-only change merged between preview and production does not void evidence, while a changed migration byte or changed apply tool does.

**2.6 Production-size rehearsal.** Files: `scripts/production_migration_guard.py`, `shared-supabase-migrations.yml`, `scripts/atomic_migration_apply.py`.
- Before applying, read table sizes for tables the migration rewrites or indexes. Over a set threshold, run with a longer bounded timeout and report it, or split the work. Judgment call: start from the real failures (#1427, #5165) and pick the smallest rule that would have caught both. Also ensure preview and production share the same atomic-function allowlist (the #5445 gap).
- **Done when:** both historical migrations are flagged by a test fixture and a small migration is not.

**2.7 Ordering.** Files: `scripts/merge-queue-contract.mjs`, SQL migration guards in `shared-supabase-migrations.yml`.
- The required guard, the advisory gate and promotion must agree on one rule. Default design: apply in merge order, with the guard refusing only duplicates and true dependency violations, so a late change needs no rename. Verify first that the Supabase tooling applies out-of-order versions safely (`--include-all`) on preview. If it cannot, assign the version automatically at merge time instead. Choose whichever needs no human or session renaming.
- **Done when:** two overlapping pull requests with crossed versions both land and promote with no rename, duplicates are still refused, and a preview replay from empty passes.

**2.8 Flake and hang repair.** Files: guard test helpers under `scripts/`; `merge-queue-gate.yml`; `database-contract-tests.yml`; `shared-supabase-migrations.yml`.
- Fix `ENOTEMPTY` with retried recursive removal of a per-test temp folder. Give every job a timeout based on its measured run time: about twice its 95th percentile. Waits inside jobs get their own bound. Also check the 35-test failure in Database Contract Tests of 2026-11-04 for a shared cause.
- **Done when:** no `ENOTEMPTY` in two weeks of runs, and no shared-db job exceeds 60 minutes without a stated reason.

**2.9 Dead workflows.** Files: `shared-db-*-observation.yml` (eight), `author-lane-abandonment-audit.yml`, `lane-watchdog.yml`, `recover-author-mutex.yml`, `recover-exclusive-db-lane.yml`, `handoff-stale-report.yml`, `queue-hygiene-report.yml`.
- Delete those whose purpose ended, after checking nothing depends on them. Check `lane-watchdog` and the `recover-*` jobs against #5228, because the exclusive locks still live there until it finishes.
- **Done when:** the deletion list is recorded on #2367, shared-db has under 35 workflows, and promotion still runs. Deleted files stay recoverable through git.

**2.10 Ledger drift.** Issue shared-db #4540, `migration-ledger-drift.yml`.
- Reconcile the open alarm. Close if false, with the check corrected. If merged work is genuinely unapplied, send it through promotion.
- **Done when:** the alarm is closed on a live read showing no unexplained difference.

#### Phase 3: runners and outside stops

**3.1 Runner label check.** Files: `config/ci-runner-routing.json`, `.github/workflows/runner-pool-watchdog.yml`.
- A check across all `popcre` and `u2giants` workflows flags any `runs-on` label that matches no known hosted image or registered runner. Advisory, and runs on schedule. This would have caught the Blacksmith outage.
- **Done when:** a fixture with a dead label is flagged, and the live scan is clean.

**3.2 Host health.** Files: `tools/ci/runner-router.cjs`, `.github/workflows/runner-pool-watchdog.yml`, `.github/workflows/windows-queue-watchdog.yml`, `config/ci-runner-routing.json`.
- If a host accepted a job that never started, or timed out on two section runs, the watchdog moves it to the paused label and reports it. It returns after a passing canary. Sections fall back to hosted Windows. Do not change the section lane rule (locked).
- **Done when:** a simulated dead host is paused with sections running hosted, then restored after a pass. `plan_issue-2340.md` covers timeouts on the manual lane.

**3.3 Billing lock.** Files: `bin/ai-pr-wait`, `tools/ci/action-taxonomy.sh`.
- Detect the account-locked message on jobs and name it as a distinct state. Read the account's billing limits to establish why the lock happened. If the available token lacks the scope, name the exact permission and route it to a session that has it. Check the spending-limit and payment settings, then report the cause on #2367.
- **Done when:** a fixture shows the named state, the cause of the October lock is recorded, and a preventive setting is confirmed by read-back. If only Albert can act on the payment side, that is the single plain request made to him.

**3.4 Registry and API limits.** Files: `database-contract-tests.yml`, `tools/github-requests/`.
- Authenticate image pulls with the GitHub token or use a mirror, so the required database test cannot fail on anonymous limits. Run fewer workflows per push (1.5, 2.9). Fix any required step that makes a single-attempt GitHub read: bounded retry.
- **Done when:** the required database test pulls images authenticated, and a re-measured peak hour is well below the 2026-09-28 level of about 950 runs.

**3.5 Protect the required list.** Files: `.github/workflows/merge-queue-drift.yml`, shared-db equivalent.
- Store each repo's expected required list in the repo. A scheduled check compares it with the live ruleset and reports differences through the 1.4 route. It restores only the list the 2026-10-30 ruling allows.
- **Done when:** a test ruleset change in a scratch repo is detected within a day.

#### Phase 4: deploys and apps

**4.1 Prove the live version.** Files: `skills/shared/deploy-and-verify`, a new reusable workflow here only if at least three apps can share it, and each app's deploy workflow (popdam3, theoracle, popcrm-web, poppim-web, monitor).
- After deploy, read the running version from the live site and compare it with the merged commit. Mismatch fails the deploy workflow and reports. Use immutable image tags. Each app exposes its version at a known path.
- **Done when:** each listed app has a run showing a matching version, and a deliberately stale check fails.

**4.2 Swallowed failures.** Files: workflows in the app repos.
- Search for `|| true`, `continue-on-error`, discarded stderr, and skipped steps on deploy paths. Fix each or justify it in a comment. Add the type check to popdam3's build. Separate oracle CI from the production ledger.
- **Done when:** the audit list is on #2367 with every entry fixed or justified, and popdam3 fails a build on a type error.

**4.3 Scheduled failures.** Files: `tools/ci/report-scheduled-failure.sh`, `.github/workflows/stuck-work-watchdog.yml`, and shared-db's and app repos' scheduled workflows.
- Each scheduled workflow reports repeat failures through the 1.4 route, or is deleted if no one needs it. Include DesignFlow Cloud Build trigger failures, which need a separate read of the build status.
- **Done when:** a list of scheduled workflows and their reporting exists on #2367, and today's failing ones are fixed or removed.

#### Phase 5: agents and tooling

**5.1 Waiter names the reason.** Files: `bin/ai-pr-wait`, `tools/ci/action-taxonomy.sh`, `tests/test-ai-pr-wait.sh`, `docs/ai-tools-cheat-sheet.md`.
- After `plan_issue-2095.md` lands, add named reasons: billing lock, no runner for label, runner accepted but not started, queued too long, advisory-only failure, real failure with its failing test. Add one line saying what to do. Adds no new tool and no extra polling.
- **Done when:** a fixture exists per reason, and tests pass on Linux and Windows.

**5.2 Install lag.** Files: the toolkit's doctor command, installed `source-sha` headers, `docs/deployment.md`.
- Doctor reports how far each machine's installed tools are behind main. Reports only; never installs. Agents' closeouts must read this before calling a toolkit change live.
- **Done when:** doctor on Windows and Ubuntu prints the correct gap.

**5.3 Transcript store.** Files: `tools/transcript_store/prompt_v5.txt:53`, `tools/transcript_store/redact_patterns.tsv`, `tools/transcript_store/normalize.py`.
- Replace the example header with an obviously generic one in a new prompt version. Flag existing false labels in a query note or relabel. Reading found two unredacted credentials in store text. Add patterns covering the shapes found, using the private catalogue (`findings_00.md`) to identify them, and rebuild. Follow the standing secrets rule for those values; do not record them anywhere.
- **Done when:** the patterns have tests, a rebuilt store no longer contains those shapes, and new segments stop gaining the false label.

#### Phase 6: acceptance

**6.1** After phases 0 to 5 land, re-measure with the baseline command across a 7-day window and write `tests/verification/ci-process/acceptance-<date>.md`. Compare against section 13. Any target missed reopens its step.

Adversarial cases, for the trust boundary in steps 2.1, 2.5, 2.7 and 1.4:

| External input | Hostile case | Test that proves it |
|---|---|---|
| Merged pull request metadata | Wording removed from conditions lets an unmerged source through | `test_automatic_promotion_candidates`: unmerged source refused |
| Migration bytes after rehearsal | File changes after preview, evidence reused | Evidence-lifetime test: changed byte voids evidence |
| Apply tool version | Tool changes after preview | Evidence-lifetime test: changed tool voids evidence |
| Migration version | Duplicate timestamp in two pull requests | SQL guards test: duplicate refused |
| Migration dependency | Later change depends on the failed one | Promotion test: dependent change held, independent promoted |
| Open `review-finding` | Finding closed by an unrelated actor or a fixer race | `test_review_finding_hold`: hold ends only on verified disposition |
| CI failure text | Failing test name containing "quota" or "429" misread as capacity | `action-taxonomy` test, existing cases extended to `ci-red` |
| `ci-red` issue flood | Hundreds of failures from one bad commit | Reporter test: one issue per test, cap per run |
| Fork pull request | Fork reaches a self-hosted runner through new routing | Router test: fork always hosted |

### 10. Tests required

| Step | New or changed test | Must stay green |
|---|---|---|
| 0.1, 1.5 | Fixer lifecycle suite: finding closed, idle, no model on removed events | Fixer lifecycle suites on both systems |
| 1.1 | Evidence tests: pending, finished-failed, mismatched | Existing evidence suite |
| 1.3 | Classifier test: unlisted suite selected on both systems | `fast-classifier` policy test |
| 1.4 | Reporter tests: one issue per test, capacity excluded, auto-close | `report-scheduled-failure` tests |
| 2.1 to 2.7 | The Python and Node tests named in each step, plus the adversarial table | `tools-offline-tests.yml`, `promotion-selector-tests.yml`, required shared-db checks |
| 3.1, 3.2 | Dead-label fixture, dead-host fixture | Router tests |
| 5.1 | `tests/test-ai-pr-wait.sh`: one fixture per reason | Same suite on Windows |
| 5.3 | Redaction fixtures, `tests/test-ai-transcript-query.sh` | Store build tests |

Run `verify.yml` through a pull request for ai-devops code changes. Do not run the full suites on a machine that is also a busy runner.

### 11. Constraints and gotchas

- Run `ai-task-gates start --class <class>` before each step. Workflow changes are `code`; shared-db promotion changes use the class the skill names.
- Work in a worktree. Commit only as `Albert Hazan <u2giants@users.noreply.github.com>`. Sign GitHub posts. Quote times in EST or EDT.
- Prose-only pull requests in ai-devops: `bin/ai-doc-safety --changed origin/main`, then `gh pr merge --squash --admin`. Anything else uses the merge queue.
- Use `bin/ai-gh` for GitHub calls and `bin/ai-pr-wait` for waits. Never `gh run watch`.
- Both repos are public. Never paste transcript text or segment text into GitHub.
- Tooling changes run on Ubuntu and Windows; prove both, and install each by its route.
- A green `merge_group` run was rare during the baseline, so judge your own change by its failing job names, not the overall color.
- `TZ=America/New_York date` printed GMT in Git Bash on al8960ofc during this work. Convert from UTC carefully.
- `ai-transcript-query` reports the store unavailable on al8960ofc because Dropbox is on `D:`. Set `AI_TRANSCRIPT_STORE_ROOT=D:/Dropbox/ai/transcript-store`.
- The GitHub-run API caps at 1,000 runs, so a busy repo's window is short. Always state the window.
- Merge groups in shared-db use merge commits, one at a time; ai-devops squashes, up to five. Scripts must not assume either.
- `edge-alien`, `edge-runn-envy` and `edge-runn-xps` never get the toolkit.

### 12. Access and environment

- GitHub: `gh` authenticated on the dev machines, through `bin/ai-gh`. Org billing may need a scope the token lacks (step 3.3).
- Secrets: 1Password vault `vibe_coding`, by item title; load the `secrets-to-1password` skill. No secret value is needed by this plan apart from existing workflow secrets.
- Transcript store: read-only, through `ai-transcript-query`.
- Shared-db local checkout: its own worktree. No production access is needed. Promotion runs through workflows only.
- App repos: `u2giants` identity for those repos, `popcre` for DesignFlow. Never mix them.

## Part 4: Landing it

### 13. Definition of done, risks and open questions

Done means every STATUS row cites an artifact, every pull request is merged, every tooling change is installed on both operating systems, and a 7-day window meets these targets:

| Measure | Baseline | Target |
|---|---|---|
| ai-devops merge-queue `verify` runs green | 6 of 72 | At least 90% |
| Merged pull requests with a failed check | 13 of 20 | Under 10%, each with an owned issue |
| `review-fixer` share of runs, ai-devops | 675 of 1,000 | Under 15% |
| Open fixer pull requests older than 48 hours, shared-db | 19 open | 0 |
| Advisory logs saying REFUSED on a change that merged | Three found in one sample | 0 |
| Merged migration not live after 24 hours with no owner | Happened repeatedly | 0 |
| Good production apply marked red | #5494, #5523 | 0 |
| shared-db workflow count | 52 | Under 35 |
| Sessions told "blocked" with the reason unnamed | Common | 0 in a sample of ten waits |
| Live version mismatch unnoticed | Up to 8 days | Detected in the deploy run |

Also: #2367 checklist ticked, this STATUS updated, handoff marked closed, docs and `docs/pending-work.md` updated.

**Risks and rollback:**

- *Step 2.1 or 2.7 lets a bad change reach production.* This is the highest risk. Land it with the adversarial tests and watch the first three promotions. Roll back by reverting the pull request. Keep required data-safety checks untouched.
- *Step 1.4 floods issues.* The cap per run limits it. Turn it off by reverting the workflow change.
- *Step 1.5 slows retirement of stale fix pull requests.* The two-hourly schedule bounds it.
- *Step 2.9 deletes something in use.* Check references first. Git recovers it.
- *Step 3.2 pauses every Windows host.* Hosted Windows is the fallback, so work continues slower.

**Genuinely uncertain:**

- Why the October billing lock happened. Step 3.3 establishes it.
- Whether out-of-order apply is safe. Step 2.7 tests it first, with the merge-time fallback.
- Whether the Linux failures are environment or code. Step 1.2 decides by reproducing them on a hosted runner.

None of these needs a decision from Albert today.

## Self-audit

1. **Could a brand-new session execute this without asking?** Yes. Sections 1 to 4 give context. Section 5 lists what not to redo. Section 9 gives files, behavior and a done test per step. Section 8 labels the judgment calls with criteria. One gap was fixed during drafting: #5541 was first read as blocking the queue, and checking the merged state corrected it to a false alarm (finding D).
2. **Does it carry the background, including ruled-out options?** Yes. Section 6 holds findings, section 7 rejected paths, section 5 past fixes. Example-level detail stays in the private catalogue named in section 3, since this repo is public.
3. **Is the goal clear enough for judgment calls?** Yes. Section 1 states four outcomes and the goal-wins rule, and section 13 makes them measurable.

Checklist graded: 13 sections present; business goal first; rejected approaches present; each step names files and a gate; adversarial table present with named tests; locked and open labeled; out-of-scope list present; tests named; secrets by location only; done includes merge and install; handoff linked both ways. Fresh-reader check: skipped, optional.
