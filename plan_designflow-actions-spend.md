---
summary: Reduce GitHub Actions charges from shared database copies reaching DesignFlow while retaining release readiness and database protection.
kind: plan
status: open
read-when: Investigating paid Actions usage, mirror-triggered checks, or DesignFlow workflow spending.
---

# Reduce DesignFlow GitHub Actions spending

Owner tracker [ai-devops #2510](https://github.com/popcre/ai-devops/issues/2510). Keep the live-proof item there. Existing workflow owners retain implementation ownership.

## STATUS

| Step | State on November 13, 2026 | Proof needed |
| --- | --- | --- |
| 1. Measure and map checks | Open | Comparable paid Linux usage and exact check inventory |
| 2a. Stop starting the weekly check on pushes | Open | Manual bridge and mirror-only and mixed events |
| 2b. Prove weekly operation | Open | First real weekly run in all six apps with the intended permissions |
| 3. Remove paid duplicate notifications | Open | Central, app and partial-failure receipts with the candidate routing |
| 4. Measure other duplicate paid jobs | Open | Evidence-based disposition by workflow and event |
| 5. Verify savings and hand back | Open | Live run receipts, normalized paid-minute comparison, documentation |

Start at step 1, then re-read the downstream steps against current upstream before starting each. Steps 2a and 3 can start independently after step 1. Do not wait for 2b to investigate steps 3–4. Use the end of 2a as a context cut when moving between repositories. Continue from the [handoff](HANDOFF.d/2026-11-13T2126Z-edge-dev3-codex-actions-spend.md).

## 1. Ultimate goal

Keep GitHub checks affordable during busy weeks while keeping every app current and every release safeguard working. Stop paying to start jobs that would do no useful work. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Applications and owners

[Shared-db](https://github.com/popcre/shared-db) owns the common database description and distributes a read-only copy from its protected main branch. The six private GitHub repositories are popcre/designflow-{backend,frontend,bff,tracking,item-master,data-syncing}. Their normal route is sandbox-albert → develop → main. DesignFlow uses Cloud Build for app deployment. The GitHub jobs discussed here check changes, route checks to runners, and notify the central database release observer. Uma owns DesignFlow merges and production promotion. ai-devops owns the shared runner router. edge-dev3 is the POP Linux runner with a GitHub-hosted fallback.

## 3. Trigger and reproduction

Albert asked why the Actions budget suddenly ran down and requested a plan and Muse debate. GitHub billing reported $69.95 total by November 13 versus $14.11 by October 13. DesignFlow accounted for $69.88 and 15,023 GitHub Linux minutes versus 4,352 in the October comparison. Both had the same $0.006 Linux rate. November 13 was partial. The hard budget was $200 when inspected, versus $70 in the November 8 receipt. Use the [billing usage endpoint](https://docs.github.com/en/rest/billing/usage#get-billing-usage-report-for-an-organization) and compare UTC billing dates consistently. For event analysis use New York dates and join Actions runs to the exact mirror commit in each app. The November 11–12 join yielded 96 source updates, 576 app copies and 1,884 runs, including 576 notification and 156 documentation runs. These are workflow starts, with varying job counts and costs. The billing report does not allocate charges to workflows. At the current rate, 576 one-minute hosted notification jobs would cost $3.46 before included minutes. This is an illustrative calculation. Replace it with matched job-level evidence before claiming savings.

## 4. Scope

In scope are documentation trigger frequency, paid no-op release notifications, and measured duplication from lightweight app checks and runner selection. Preserve timely exact copies and the central completion notification. Out of scope are budget changes, database writes or migrations, changes to what authorizes releases, replacing the runner platform, and changing other organizations' workflows. A change to mirror cadence or contents requires its own dependency case and scope decision. Leave it outside this rollout.

## 5. Current state

- Shared-db [deployment guide](https://github.com/popcre/shared-db/blob/main/docs/deployment.md#what-release-means-here) and [sync workflow](https://github.com/popcre/shared-db/blob/main/.github/workflows/sync.yml) describe the per-update copy and central completion dispatch. [PR #4847](https://github.com/popcre/shared-db/pull/4847) consolidated notifications. The canonical consumer source is [config/designflow-consumer-release-notify.yml](https://github.com/popcre/shared-db/blob/main/config/designflow-consumer-release-notify.yml). The app file is .github/workflows/designflow-db-release-notify.yml. All six copies follow the canonical source. See [delivery rules](https://github.com/popcre/shared-db/blob/main/docs/designflow-db-release.md#consolidated-mirror-notifications-issue-4655).
- DesignFlow [docs upkeep plan §4.2](https://github.com/popcre/designflow-backend/blob/develop/plan_docs-lookup-cleanup-and-upkeep.md) calls for weekly upkeep. The [November 11 change](https://github.com/popcre/designflow-backend/commit/55f54c812) added pushes to sandbox-albert and develop. All six GitHub default branches were verified as develop on November 13. Current app paths are .github/workflows/doc-health.yml and .doc-health.json. The latter excludes the copied tree from scanning.
- App .github/workflows/task-gates.yml and forbid-shared-db-bypass.yml both run on develop pushes. The [shared runner router](https://github.com/popcre/ai-devops/blob/main/.github/workflows/edge-dev3-route.yml) starts on GitHub even when the next job runs on edge-dev3. Inspect unit-environment-matrix.yml and sample-tracking-regression.yml only where present. The observed November 5–6 backend mirror events started 426 workflows before the November 8 backend develop routing merge. No workflow or runtime changes were made in the planning session.

## 6. Root causes and known evidence

1. The copy operation sends a normal update to six apps. Trigger patterns match that event just as they match app work. The design keeps apps on one source of truth. Existing docs give no reason every downstream check must wake up on a copy.
2. The app notifier pays to start a GitHub job before examining commit metadata and comparing trees. The apparent bot name is a Git commit author, not the authenticated sender. The mirror uses the existing SYNC_TOKEN and [the observed notifier run](https://github.com/popcre/designflow-frontend/actions/runs/43504009082) records a human-account sender. The code does not establish that this sender can only publish mirror changes. [Frontend run 43504009082](https://github.com/popcre/designflow-frontend/actions/runs/43504009082) took the mirror-only exit after the job started. The central observer independently evaluates exact app heads.
3. The weekly-check comment promised a first-of-week push to compensate for GitHub timers running only from the default branch. The implemented trigger accepts every matching push. [Backend run 43497533716](https://github.com/popcre/designflow-backend/actions/runs/43497533716) shows a paid chooser and a local keeper. Documentation upkeep shipped after the first cost spike.
4. [Backend run 42316029935](https://github.com/popcre/designflow-backend/actions/runs/42316029935) used a GitHub-hosted task gate before develop adopted the chooser. [Run 43504010942](https://github.com/popcre/designflow-backend/actions/runs/43504010942) used a GitHub chooser then edge-dev3. This establishes added overhead per routed run, without establishing that the router raised total costs. The shared-db switch from Blacksmith [PR #5572](https://github.com/popcre/shared-db/pull/5572) increased visible GitHub activity. Its own November net Actions cost was zero, though restored mirror throughput can create paid app work.

## 7. Approaches considered

- Skip all workflows on copy commits using a commit-message tag. Broad suppression affects unrelated and required checks and can strand pending checks. Keep it out.
- Use a path-only filter for the release notifier immediately. The existing contract retains notifications for unauthenticated or uncertain updates. Path filters cannot establish the sender's identity and GitHub's diff limits can omit a changed path. Preserve that contract until an equivalent supported route is demonstrated.
- Wait for the hosted job and shorten its body. That is the existing behavior in the verified duplicate example. Savings require avoiding paid allocation or routing the existing classification to a proven lower-cost execution path.
- Make the first update of the week an in-workflow condition. This still wakes the workflow repeatedly and creates state and races. Use the default-branch timer with existing manual operation as the bridge.
- Group, delay or shrink the database copies as the first change. This would change what apps receive and when. Avoid it while the measured waste can be removed at the receiving end.

## 8. Design decisions

Locked for this plan on November 13: preserve release and database safeguards, exact-head readiness, normal app-change notifications, central completion for partial batches, and GitHub fallback for any required runner work. Keep the existing budget setting. Preserve the current advisory documentation check on real app documentation changes and the rolling issue behavior. Use the already-working manual trigger for pre-default-branch operation.

Open to implementation evidence: how to pre-classify release notifications without paid execution or reduced coverage, and whether measured savings justify further runner or lightweight-check work. The decision criteria and stop rules are in steps 3 and 4.

## 9. Execution

1. **Measure and inventory.** In the six current upstream app worktrees inspect .github/workflows/{doc-health,designflow-db-release-notify,task-gates,forbid-shared-db-bypass}.yml and .doc-health.json. Read live rulesets plus legacy branch protection for develop and main. Record required check names, producers, event and runner labels. Pull Actions runs by narrow date windows to avoid the filtered 1,000-run cap. Join SHA, workflow, event, attempt, runner and job duration to verified mirror commits. Separate paid hosted jobs from self-hosted jobs. Match billing totals independently and measure per 100 mirror updates and per 100 real app changes. Retain private exports locally and post aggregates to #2510. Gate: reproduce the historical counts or explain drift and get a current baseline before changing triggers.
2a. **Restore weekly docs upkeep.** Start in backend under #391. Remove the keeper's push trigger in .github/workflows/doc-health.yml. Keep Monday scheduling on the default branch, which was verified as develop in all six apps, and manual dispatch. Keep scheduled scans explicitly on develop and manual scans on the requested authorized ref. Set the generated-index PR base to the scanned branch. Before rollout, verify each default branch, token contents/pull-request/issues permissions, repository settings for Actions PR creation, and writable target for the existing regeneration path. Prove manual dirty-to-clean reuse of the same rolling issue and an index-only case in an authorized test branch. Preserve advisory checks on app documentation PRs. Add the copied-tree exclusion to the advisory trigger only if mixed and large-diff tests support it. Gate: the manual bridge works, mirror-only pushes start zero docs jobs, and real or mixed app docs PRs retain feedback. Roll out in the six apps through their normal promotion route.
2b. **Prove the real schedule.** Link one actual scheduled receipt per app showing the develop scan and correct outcome. Keep manual dispatch available during and after this check. If a default branch moves, keep the workflow on the trusted default branch and preserve the develop target. Scheduled verification stays open without blocking other work.
3. **Defer changing the release notifier on current evidence.** Use shared-db canonical config/designflow-consumer-release-notify.yml, .github/workflows/sync.yml, .github/workflows/designflow-db-release.yml and scripts/test_designflow_sync_notification_batch.py to document the current behavior. First verify central coverage for complete and genuine partial batches, plus recovery for cancellation and lost dispatch, using existing evidence or nonproduction replay. Reopen a notifier change only if a supported existing signal is authenticated and can suppress only genuine mirror-only pushes while retaining delivery for mixed or uncertain updates, or if a proven existing runner route saves paid minutes without requiring new infrastructure or reducing delivery. Git author and commit message are forgeable. A sender-only job condition is unsafe with the existing general-purpose sender. The current hosted chooser costs a job before classification, so moving a one-minute notifier behind it has no demonstrated savings. Keep the current notifier and its credential otherwise. If a candidate later passes, update canonical config first and roll out byte-identically from backend to the other five, preserving exact-head observation and least-privilege dispatch. Gate: verified mirror-only pushes spend zero paid notification minutes in the healthy path, real app pushes and production PRs still notify, partial failure is visible, and fallback and total paid minutes improve without new trust or availability gaps. Record the evidence or measured reason for deferral on #2510.
4. **Address other paid duplication only where proven.** Use the inventory to compare task gates, shared-db bypass checks, unit matrices and browser regression on PRs and pushes. Consider only configurations that preserve the existing event trust boundary. Read [router finding #2346](https://github.com/popcre/ai-devops/issues/2346) before adding callers or event types. Compare the shared ai-devops chooser and the chosen job as a pair against a hosted-only baseline. Test a single paid start for independent short advisory tasks only if it saves minutes and retains check identities and coverage. Keep guarded PR events and required contexts intact, including when edge-dev3 is offline or busy. Add cancellation only for demonstrably superseded advisory app jobs. Leave queue jobs out. Gate: equal protection and fewer paid jobs/minutes on comparable events, with a preserved pending/failure signal. Stop if a candidate fails these criteria.
5. **Measure and close.** Update shared-db docs/designflow-db-release.md, the app docs upkeep plan, and this plan with landed behavior and evidence. Compare two matched seven-day periods after reporting settles, with counts and dollars, and show normalized paid minutes per 100 mirror updates plus normal-app coverage. Report separately for job types actually measured. Require zero paid doc-keeper jobs from mirror-only pushes. For the notifier, close its decision with evidence of safe savings or record the specific failed criterion and residual cost. Never count deferred savings. Report any spend remaining and its measured drivers. Keep proof open until both live behavior and savings for the changes that shipped are observed.

## 10. Tests

Use workflow checks and existing shared-db test fixtures for the canonical classifier, completion dispatch, and exact-head release observer. Run `python3 scripts/test_designflow_sync_notification_batch.py` in shared-db, then run the existing repo checks on the exact candidate. Existing fixture methods include `test_real_or_mixed_code_changes_notify_even_with_large_mirror`, `test_api_error_and_incomplete_or_ambiguous_roots_notify`, and `test_completion_is_after_entire_matrix_even_partial_failure`. Add these cases to the existing fixtures and confirm live Actions receipts for representative allowed cases.

| Input | Failure to exercise | Required test |
| --- | --- | --- |
| Push metadata and actor | Forged author/message, lookalike actor, incorrect repo or branch, absent or zero SHA | mirror_requires_trusted_identity_and_exact_heads |
| Before/after root trees | Mixed app edit, moved path or type change, no mirror tree, truncated comparison | mixed_or_unverifiable_change_retains_notification |
| Large or missing comparison | Large push, timeout, API error and pagination limits | ambiguous_diff_preserves_release_event |
| Events | Genuine mirror, normal app-only develop/main, mixed push, relevant production PR, fork PR | release_event_matrix_and_fork_isolation |
| Central batch and app head | Partial sync, cancellation, lost dispatch, stale or mismatched head | batch_failure_visible_and_exact_head_required |
| Documentation events | Mirror markdown, app markdown and mixed changes, scheduled and manual dispatch | doc_upkeep_trigger_matrix |
| Scheduled or manual inputs | Wrong target, overlapping runs, stale index PR, dirty to clean | weekly_keeper_targets_develop_and_reuses_issue |
| Runner heartbeat and contention | Missing, stale, busy or offline, concurrent burst, fork | runner_fallback_preserves_checks_and_measured_cost |
| Required check and cancellation | Skipped/pending status, cancellation after newer advisory run | required_contexts_and_queue_survive |

GitHub trigger and large-diff semantics are documented in [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore). Schedule behavior is in [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule). Read the active rules before selecting event filters.

## 11. Constraints

Use separate fresh upstream worktrees. Use the normal DesignFlow promotion route under Uma and the protected queue for shared-db and ai-devops. No direct pushes to protected main, copied success status, broad skip markers, new required checks, or change to production release proof. Keep release-notify changes centralized and copy them byte-for-byte. Record decisions and output on #2510 and link the existing feature trackers. A review is advice. Preserve secrets and private evidence off public GitHub.

## 12. Access

Use the installed ai-gh wrapper for GitHub reads and writes. Organization billing read-back succeeded with existing authenticated access. Use the app and shared-db worktree identity required by their AGENTS.md. The existing named GitHub App and repository secrets are provisioned under #4655. The shared-db SYNC_TOKEN authenticates copy pushes. The separate existing DesignFlow dispatch App starts the central observer, whose publisher posts status. Read only credential names and permission metadata. Runtime login is N/A because this work changes GitHub jobs. Use [DesignFlow sandbox](https://alsand.designflow.app) only when existing release validation calls for it. Reconfirm permissions and target branch before any mutation.

## 13. Completion and rollback

- Commit and push only owned changes, verify exact-head checks and protected merges, then link the actual workflow heads and run receipts. No application or database deployment is required beyond the normal repository workflow rollout.
- Prove the first scheduled documentation run and a manual dirty/clean cycle. Prove release notification safety and savings for any notifier change that ships. If it stays deferred, attach the decision and paid baseline on #2510.
- Close the live-proof box on #2510 only after the matching billing and workflow evidence. Record deferred paths with their measured reason. Roll back an individual rollout by reverting its source change through the original repository route. Restore the known-good canonical notifier and matching app copies if central proof or a real app notification is lost. Restore documentation dispatch first if scheduling fails.
- Risks are large changed-file lists, pending required contexts, misclassified mirror events, stale central status and runner outages. Treat lower app activity and billing discounts separately from measured savings.

## Muse debate

November 13, 2026. Muse first requested parallel investigation, confirmation of the weekly scan target and permissions, and explicit authentication criteria for a pre-run skip. The second round accepted the revised order and deferral criteria. We agreed the evidence supports fixing the weekly trigger first and retaining notification delivery until a viable replacement is proved. This is agreement on the implementation plan. The workflow and cost proof remains in steps 1–5.

## Self-audit

1. A new implementer can proceed using §§2–6 and §§9–12. The plan names the owning repos, files, baseline method, open technical choices and verification for each step.
2. §§3, 5–8 and 10 carry the cost evidence, dates, failures to avoid, safety decisions, and cases that would invalidate a proposed shortcut.
3. §§1, 8, 9 and 13 make the trade-off explicit: keep the checks and freshness that matter, measure savings, and roll back a change that weakens either.
