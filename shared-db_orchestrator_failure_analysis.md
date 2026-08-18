# Why the shared-db orchestrator stopped delivering work

Date: 2026-08-18

Status: evidence-based postmortem. This document describes the operating failure. It does not propose weakening database safety or bypassing preview and production verification.

## Executive conclusion

The shared-db orchestrator began as a good solution to a real coordination problem: five applications share one database, so simultaneous uncoordinated structure changes can collide or break each other.

The system later optimized for **keeping work occupied and proving every intermediate step** instead of **finishing the few database changes applications were waiting for**.

The result was a growing chain:

1. A requested database change exposed a tooling limitation.
2. The orchestrator stopped the requested change.
3. It opened a tooling issue and pull request.
4. That tooling change needed independent review.
5. Review failed, timed out, or became stale when `main` changed.
6. More tooling was added to recover the failed review or stale state.
7. Preview or production exposed another historical inconsistency.
8. The original request gained another dependency and stayed open.

Many individual stops were correct. The system-level outcome was not. Five applications waited while the orchestrator spent most of its time improving its own governance machinery.

This is not purely a reviewer problem and not purely a GitHub outage problem. The main failure is architectural: **the orchestrator has no strict boundary on how much process repair it may put in front of a business request, no reliable fast path for ordinary changes, and no outcome-based measure of success.**

## Evidence sources

This report is based on:

- the prior orchestrator handoff, `shared-db/HANDOFF.d/2026-08-16T2118Z-al8960ofc-codex-orchestrator-transfer.md`;
- the next handoff, `shared-db/HANDOFF.d/2026-08-17T2357Z-al8960ofc-codex-orchestrator-transfer.md`;
- the GitHub issue and pull-request histories named below;
- the detailed reviewer report in [`fix_reviewer_system.md`](fix_reviewer_system.md);
- the 24-hour chat in which Albert repeatedly asked whether agents were working, why work was frozen, and why issues still were not complete.

The issue state described below is the state at the end of the 2026-08-16/17 orchestrator session unless a later state is explicitly identified.

## What this chat itself showed before later sessions finally closed some work

The later completion of #853 and #764 does not erase the operating failure in this chat. The question is not whether the work was eventually possible. The question is whether one orchestrator session could accept an application-blocking request and finish it in a reasonable, predictable time.

It could not.

The orchestrator marker for this chat was opened as #1053 at 04:37 UTC on 2026-08-16 and was not closed until 21:36 UTC. That is roughly 17 hours for this session alone, after predecessor sessions had already worked on and handed forward the same issues.

Albert's instruction was explicit:

1. complete #853;
2. assign every open issue to the three migration-author queues;
3. complete every issue all the way through production;
4. continue until the repository had zero open issues.

The session did not achieve that outcome. It closed with a comprehensive handoff precisely because the most important inherited work was still unfinished.

| Requested outcome | State when this chat ended | What consumed the session instead | Later result |
|---|---|---|---|
| #1049 Warner inferred views through production | Eventually completed in this chat, but only after Albert repeatedly asked why production was still pending | Multiple exact-head reviews, preview ancestry recovery, owner-evidence tooling that was hard-coded for a different migration batch, access-risk approval, and a correction after the issue had been treated as complete at merge rather than production | Production run `31969314143` finally applied and verified it |
| #853 OrderList and ColdLion work through production | Not complete; #1074 atomic-runner tooling and #1071 safe-forward migration were still open, and no safe-forward production write had occurred | Claim splitting, claim restoration, object expansion, multiple reviewer failures, preview lock recovery, a performance index, transaction experiments, retirement of the first migration, and creation of a general atomic migration runner | Completed only in the successor session on 2026-08-17 |
| #764 DesignFlow sequence repair through production | Not complete; tooling PR #1072 and migration PR #1047 were still open, with no preview or production apply from this session | A reserved migration number became too old, requiring new claim-reversion tooling; that tooling then needed filename discovery, real Git tests, rollback repair, fresh review, and another refresh from `main` | Completed only in the successor session on 2026-08-17 |
| Zero open issues | Not remotely achieved | The session classified a large queue into blocked, owner-decision, data-only, documentation, application, and production categories; it opened five new handover issues #1079–#1083 to carry unfinished work forward | Many legitimate issues remained open |
| Reliable independent review | Not achieved | Kimi and Grok calls from delegated tasks could not access their Windows credential/session locations; Qwen exhausted quota; GLM had worktree-boundary failures; more reviewer-recovery tooling became another dependency | Continued as separate ai-devops repair work |

### #1049 showed that “merged” had replaced “delivered”

Albert asked several times why production deployment for #1049 was still pending. The implementation agent had completed the migration, tests, exact-head review, preview proof, and merge. The issue nevertheless was not a finished application outcome because production had not run.

The chat then exposed three additional gates:

- the production owner-evidence tool was hard-coded for an earlier Disney two-migration deployment and refused #1049;
- preview already contained a #853 migration that was absent from the #1049 branch, so an ordinary preview run refused the history mismatch;
- the six views changed signed-in access, requiring an exact owner risk decision.

Each stop was individually defensible. The system failure was that these were discovered after implementation and review, not during one early end-to-end preflight. #1049 finally reached production only after another tooling PR, another exact-main evidence cycle, a historical preview recovery, and Albert's risk approval.

The predecessor handoff explicitly records that #1049 had first been closed after merge even though its delivery contract required production. It had to be reopened, promoted, verified, and closed again. This is direct evidence that the orchestrator's completion state was tied to repository activity rather than the requested live outcome.

### #853 was the named first priority and still crossed into another session

#853 had already been open since 2026-08-12 and was handed into this chat as priority work. During this chat it made real technical progress:

- 19,315 ColdLion identities were reconciled against 17,703 legacy IDs;
- ambiguous identities were correctly left unresolved rather than guessed;
- existing ERP links were preserved;
- bridge and index migrations were merged and rehearsed on preview;
- the scale refresh fell from a timeout to 4.720 seconds after indexing.

But it did not reach the requested production finish. The work repeatedly changed shape:

1. A preview refresh timed out, so a new index was required.
2. Adding the index to the same pull request violated the one-version-per-PR lease rule.
3. Restoring the original claim and splitting the index required new same-owner claim-split tooling.
4. The index parser discovered an additional table object, requiring new active-claim expansion tooling.
5. Preview lock cleanup failed twice because GitHub's deleted reference remained briefly visible, requiring new delayed-readback tooling.
6. The original migration's table lock failed outside a transaction.
7. Adding an explicit transaction made the SQL legal but proved that database changes could commit without the migration history row.
8. Removing the explicit commit still failed because the Supabase command did not wrap the migration in a transaction.
9. A general atomic runner became mandatory, producing PR #1074 before the actual safe-forward PR #1071 could proceed.
10. Reviewer transport failures then blocked both tooling and migration progress.

At handoff, the chat's own briefing said: “#853/#868 OrderList workstream is unfinished but stable.” It also said no safe-forward preview or production write had occurred. The first requested outcome therefore survived a roughly 17-hour orchestrator session and moved into yet another session.

This is the best example of the dependency-chain complaint. None of the dependencies was imaginary, but the orchestration model had no ceiling on how many new platform repairs could enter the critical path before the original application change was delivered.

### #764 had already waited for days and still left this chat unfinished

#764 was opened on 2026-08-11. By the end of this chat on 2026-08-16, it still had not reached preview or production.

The sequence repair itself was small and its live risk was already known. The migration's reserved version became older than newer merged migrations, so the repository guard correctly rejected it. Instead of having a stable supported version-replacement path, the session had to build one:

- active-claim reversion tooling;
- filename-only migration discovery;
- rollback after partial rename failure;
- real temporary-Git tests;
- another exact-head external review;
- another update after `main` advanced.

The handoff described #764 as “unfinished but stable,” with PR #1072 and PR #1047 both still open. The next session had to merge the tooling, replace the version, refresh and review the migration again, preview it, merge it, and promote it. #764 did not reach production until 2026-08-17, nearly a week after it opened.

### Reviewer failures became stopping points even though the main task had Full Access

Albert correctly pointed out that the main Codex task had Full Access for the entire chat. The failures occurred because reviewer work was delegated into restricted child tasks.

The chat recorded:

- Kimi could not create `C:\Users\ahazan2\.kimi-code\sessions\...` and waited to its 900-second limit without a verdict;
- Grok could not read `C:\Users\ahazan2\.grok\auth.json`, then also waited to the wrapper limit;
- moving `AI_KIMI_STATE_DIR` or `AI_GROK_STATE_DIR` moved wrapper state but not the provider's own credentials and sessions;
- GLM rejected linked worktrees whose real Git metadata lived outside its allowed folder;
- Qwen exhausted its weekly quota;
- several reviews became stale when `main` advanced before the long reviewer finished.

These were not code-review findings. They were execution failures. The orchestrator nevertheless allowed them to pause the application work instead of immediately rerouting the same exact-head review through the Full Access main task or a proven alternate reviewer.

The chat then opened more tooling work for reviewer replacement and provider failure records. That was another example of governance repair becoming a prerequisite to the database change.

### “Everything is classified” was reported where “everything is finished” was requested

The final audit was accurate: all returned open issues were classified, no issue was malformed or unclassified, and the queue had no immediately dispatchable unclaimed migration work.

That was still not the requested result.

Classification converted the impossible “finish every issue” instruction into an honest map of owner decisions, application work, source-data work, blocked programs, documentation, and production promotion. It prevented false closures, which was good. But the operating report repeatedly emphasized occupied lanes, clean locks, classified queues, green tests, and reviewer evidence while Albert's five applications still lacked their database outcomes.

The session ended by opening five more handover issues:

- #1079 for overall continuation;
- #1080 for #853;
- #1081 for #764;
- #1082 for reviewer transport recovery;
- #1083 for documentation cleanup.

Opening precise handover issues was the correct closeout action. It is also direct evidence that the orchestrator had generated more tracked work while failing to finish the two main inherited application blockers.

## The clearest examples

### 1. Issue #853 crossed multiple sessions and consumed most of another day before completion

Issue [shared-db #853](https://github.com/u2giants/shared-db/issues/853) was created on 2026-08-12 and was still unfinished in the 2026-08-16 predecessor handoff.

That prior handoff said:

- #853 remained the first engineering priority;
- the safe replacement migration was still an open pull request;
- atomic migration tooling had to merge first;
- the replacement then needed a fresh review, preview, merge, production evidence, and application verification;
- the first preview had already failed because a table lock was attempted outside a database transaction.

The successor session did eventually complete and close #853 on 2026-08-17, roughly four days after issue creation. But the path expanded far beyond the original business request:

- PR #1074 for a general atomic migration runner;
- PR #1071 for the actual #853 change;
- repeated updates from `main`;
- repeated full tests and exact-version reviews;
- line-ending and file-hash corrections;
- production risk-proof tooling;
- expression-index verification tooling;
- a verification-only recovery workflow after the database change had succeeded but the generic verifier could not understand the index definition.

The important distinction is that #853 was completed, but it demonstrates the core problem. A single application-blocking database change became a platform-development program. The orchestrator treated every newly discovered limitation as a prerequisite that had to be generalized before the original job could finish.

### 2. Issue #764 was handed between sessions and took nearly a week to reach production

Issue [shared-db #764](https://github.com/u2giants/shared-db/issues/764) was created on 2026-08-11. PR [#1047](https://github.com/u2giants/shared-db/pull/1047) was opened on 2026-08-16. The predecessor handoff still described #764 as “unfinished but stable.” It depended on a separate tooling PR before its reserved migration number could be safely replaced.

The successor session then added or relied on more machinery for:

- claim version replacement;
- lease renewal;
- support for migrations whose object parser found no ordinary table definition;
- exact issue-scope proof;
- reviewer replacement;
- repeated refreshes because `main` moved;
- explicit transaction handling after preview rejected a table lock;
- a test correction after independent review found a null check that could silently pass.

The migration finally reached production and #764 closed on 2026-08-17, more than five days after the issue was opened.

Again, the safety findings were real. The failure was that the system had no bounded, already-supported path for a small repair. The repair could not progress without first extending the claim manager, then reviewing the extension, then merging it, then refreshing the original repair and reviewing it again.

### 3. Issue #1090 remained open after a full day of concentrated work and many supporting pull requests

Issue [shared-db #1090](https://github.com/u2giants/shared-db/issues/1090) was created on 2026-08-16. Its main implementation PR [#1108](https://github.com/u2giants/shared-db/pull/1108) merged on 2026-08-17.

The requested outcome still was not complete when the session ended. The handoff had to create a new handover issue, #1147, because production promotion remained unfinished.

The work expanded through:

- issue-scope correction from 17 objects to 47 objects;
- new generalized claim-expansion tooling;
- Qwen removal and reviewer-chain repairs;
- several disposable-database failures and test-fixture corrections;
- repeated exact-version reviews that timed out or returned no verdict;
- an owner exception that expired immediately when `main` moved;
- migration number replacement after another migration made #1090's number appear older;
- production approval comment-read retry tooling;
- GitHub comparison fallback tooling;
- coordination-reference retry tooling;
- preview history investigation and restoration tooling;
- a later production discovery that the new write guard would block two older, deliberately held licensing migrations.

That final blocker was substantive: applying #1090 alone would prevent the older approved work from running. The system was correct not to force it through.

But the orchestrator then converted that discovery into another multi-migration program:

- a compatibility migration;
- a forward replacement for an older held migration;
- a complete French licensing removal migration;
- strict cleanup and proof;
- new claims and versions for each phase;
- a future all-or-nothing production package.

At session close, #1090 was still open, PR #1145 was still open, and more structural phases had not yet been authored. A day of activity produced substantial tooling and intermediate code, but not the production outcome the applications needed.

### 4. Issue #1115 was requested “through production” and still required another session

Albert explicitly asked for [shared-db #1115](https://github.com/u2giants/shared-db/issues/1115) to be completed to production simultaneously with the other work.

PR [#1117](https://github.com/u2giants/shared-db/pull/1117) was authored and repeatedly reached green tests and an approval on earlier versions. It still did not reach preview, merge, or production before the orchestrator ended.

Its first preview was blocked because preview contained migration version `20260817150944`, while the repository did not contain the matching historical file. That led to:

- a generic preview-ledger reconciliation workflow;
- a failed attempt to prove the history row was a duplicate of #1090;
- detailed forensic analysis showing it was unique PLM mirror work;
- a new restoration issue and claim;
- a tooling PR allowing exactly one historical restoration case;
- a second PR restoring the historical file;
- another refresh and complete re-review of #1115 because `main` had changed.

The history investigation was necessary once the inconsistency was discovered. The process failure was that #1115 had to wait for an entire new governance feature and two unrelated pull requests before its already-tested change could be rehearsed.

At the end of the session, #1115 was still open, PR #1117 was still open, and handover issue #1148 was created for the next orchestrator.

### 5. Sample Tracking Release A looked closed while its actual production outcome was unfinished

Issue [shared-db #975](https://github.com/u2giants/shared-db/issues/975) was opened on 2026-08-14. The original issue was later closed, but the release still had not completed the requested preview, generated types, and production promotion when the session ended.

Read-only inspection found a serious preview inconsistency:

- preview's ledger said the original Release A migrations had run;
- important workflow/path tables, functions, triggers, indexes, and a view were missing;
- the migration file had changed after an intermediate version was applied to preview;
- generated types therefore omitted structures needed by frontend and tracking consumers.

Albert authorized an exact reconciliation migration, `20260817190000`. PR #1126 implemented it and passed extensive tests. It still could not be previewed because the same unrelated `20260817150944` history mismatch blocked the migration tool.

The session ended with:

- the original #975 issue closed;
- the actual Release A production outcome unfinished;
- PR #1126 still open and behind current `main`;
- generated types intentionally uncommitted;
- handover issue #1149 required for the next orchestrator.

This exposes a measurement problem. Counting closed issues would report success even though the application-facing outcome was still pending. The system tracks implementation tickets, claims, tooling issues, and handovers, but it lacks one authoritative “customer outcome is live” state.

PR #1126 merged after this orchestrator session ended, on 2026-08-18. Handover issue #1149 remained open afterward, confirming that merge alone still did not equal completion.

### 6. Issue #1113 consumed scarce orchestrator attention despite not being database work

Issue #1097 was a planning issue for historical Item Description taxonomy. Its implementation successor, [#1113](https://github.com/u2giants/shared-db/issues/1113), inherited the shared-db repository even though it was offline application-owned taxonomy and data review, not a database structure change.

The orchestrator spent time on:

- loading the taxonomy skill;
- reproducing a 19,302-row baseline;
- inventorying 3,961 parser outputs;
- building a private status ledger;
- semantically reviewing 245 rows.

Only later was the routing error corrected. #1113 was closed and the private work was preserved for `popcre/designflow-item-master`.

This did not merely waste one agent. It occupied attention in a system that Albert had been told was resource-limited and already unable to move five applications' database requests. The routing rule existed in principle, but it was enforced after issue creation rather than at the source.

## The session-to-session pattern

The predecessor handoff on 2026-08-16 already carried forward:

- #853 unfinished;
- #764 unfinished;
- reviewer-resilience tooling unfinished;
- a large queue with many decision and dependency states;
- an explicit warning that the owner's goal of completing all open work was not complete.

The next handoff on 2026-08-17 showed that #853 and #764 had finally completed, but it carried forward three newly important unfinished outcomes:

- #1090 licensing Master Data production package;
- #1115 bulk OrderList relink through production;
- Sample Tracking Release A through preview, generated types, and production.

This is the defining failure pattern: one handoff closes some inherited work but creates or expands enough prerequisites that another set of application-blocking jobs moves into the next handoff. The queue changes shape without shrinking fast enough.

## What the problem was

### 1. Utilization was treated as success

Albert required all three migration-author slots to remain occupied. The system interpreted this literally, even when the fastest way to finish one job was to leave capacity available for its blocker or to concentrate on a single production path.

Keeping three claims open proves activity. It does not prove throughput. In practice it increased work in progress, merge conflicts, `main` movement, repeated reviews, and cross-dependencies.

### 2. Every discovered tooling limitation became a prerequisite project

The orchestrator had a strong “permanent fix first” rule. That rule prevented unsafe shortcuts, but it lacked a proportionality test.

A limitation found while delivering one migration often produced:

- a new issue;
- a generalized manager command;
- many tests;
- a new pull request;
- an independent review;
- another exact-main refresh;
- a second review of the original migration.

There was no firm rule such as: “Do the smallest safe change that completes the blocked outcome; generalize later unless more than one current job needs it.”

### 3. Exact-version review was safe but scheduled at the wrong time

Reviews were often started while prerequisite merges were still expected. Long reviewer runs then completed after `main` changed. The evidence was correctly rejected as stale, but all time spent on it was lost.

This happened repeatedly across #1072, #1089, #1090, #1108, #1115, and tooling pull requests.

The failure was not exact-version safety. It was allowing final review to start before the change had a stable merge window.

### 4. The reviewer system was too slow and unreliable

Small changes routinely received 10–15 minute reviewer budgets. Observed Grok runs consumed 12 or 20 turns and millions of tokens, then returned no verdict. Kimi waited until its limit before reporting exhausted allowance. GLM failed on linked worktrees, permissions, empty responses, or prohibited search attempts.

Each failed review then triggered provider rotation, immutable failure recording, and sometimes new reviewer-management tooling.

The detailed evidence and proposed wrapper fixes are in [`fix_reviewer_system.md`](fix_reviewer_system.md). Reviewer repair is necessary, but it will not fix the entire orchestrator failure by itself.

### 5. The system confuses safety evidence with business completion

The repository records many intermediate successes:

- tests green;
- review approved;
- preview green;
- pull request merged;
- owner evidence generated;
- production dry run green;
- claim released.

But applications care about one state: the required database behavior is live and verified.

#975 demonstrated the mismatch most clearly. Its original issue was closed while the release still lacked truthful preview structure, generated types, and production promotion.

### 6. Historical drift was discovered too late

Preview was known to be materially different from production in earlier handoffs. Yet individual workstreams often discovered their blocking drift only at the final preview attempt.

That is backwards. A full preview-history and catalog preflight should occur before authoring or final review, not after an issue has already consumed hours of implementation and reviewer time.

### 7. The orchestrator generalized incidents instead of isolating them

The preview history case `20260817150944` illustrates this. The correct final resolution was narrow: restore one proven historical file and permanently bar it from production.

Before reaching that resolution, the system built a generic orphan-deletion workflow tied to #1090. The workflow correctly refused, but the detour consumed another issue, pull request, review chain, tests, and workflow run.

A stronger early rule would have been: unknown historical database effects are evidence problems first, not deletion-tool problems.

### 8. Routing enforcement happened after work entered the queue

#1113 should never have reached shared-db. Once it did, the orchestrator treated it as assigned work and began execution.

The source rule must be enforced in global AI instructions and shared-db handoff skills before an issue is created. A non-structural successor must be reclassified from scratch rather than inherit its predecessor's repository.

### 9. GitHub outages exposed a lack of graceful degradation

GitHub had genuine 503/504 failures affecting actions, comments, statuses, comparison, and reference creation. The safety gates correctly stopped.

The orchestrator nevertheless spent many cycles immediately retrying, diagnosing, and building retry tooling while business work remained blocked. When the external service is broadly unhealthy, the correct operating mode should be a visible pause with offline preparation, not repeated end-to-end retries that create more stranded state.

### 10. The system had no stop-loss rule

There was no limit such as:

- after two prerequisite expansions, escalate the job as a program rather than claiming it is close to completion;
- after one stale review, freeze merges before reviewing again;
- after two provider failures, use a short owner-visible exception process or pause;
- after a job exceeds a day, dedicate one lane exclusively until it reaches production;
- do not open more tooling work than the number of business outcomes completed that day.

Without a stop-loss rule, every safety discovery could extend the chain indefinitely.

## Why the system looked busy while applications saw no progress

The orchestrator produced a large amount of real work:

- dozens of tooling tests;
- many pull requests;
- reviewer failure records;
- exact claims and permanent version records;
- detailed handoffs;
- preview and production evidence artifacts;
- increasingly sophisticated safety gates.

Those are engineering outputs, not application outcomes.

At the end of the session, Albert still needed new sessions to finish #1090, #1115, and Sample Tracking Release A. This is why the session felt interminable despite continuous messages and activity.

## What must change

### Replace “three occupied slots” with “three owned outcomes, finish-first”

Each slot should own one application outcome, not a chain of internal tooling tasks. A blocker discovered for that outcome remains inside the same outcome budget. Do not fill freed capacity merely to keep utilization at 100 percent.

### Establish a normal fast path

Ordinary additive database changes should use a stable, already-proven path:

1. classify exact structural scope;
2. check preview history and catalog before authoring;
3. claim version and objects;
4. author and test;
5. one stable-head review;
6. preview;
7. merge;
8. production decision only if the risk gate requires it;
9. production and verification;
10. close the outcome.

If the normal path cannot handle common work without new manager code, the platform is not ready and should be simplified rather than expanded per issue.

### Limit platform work in the critical path

Create a platform repair only when:

- the requested outcome cannot be completed safely without it;
- no narrow existing path can handle the case;
- the repair is the smallest safe change;
- its delivery time is explicitly included in the parent outcome;
- no speculative generalization is added.

General improvements should go to ai-devops or a later shared-db maintenance window after application blockers finish.

### Use a stable merge window

Do not start final review until prerequisites have merged and the orchestrator can hold unrelated merges briefly. One review should normally survive through preview and merge.

### Measure completion, not intermediate evidence

The primary daily report should be:

- application outcomes promoted and verified;
- oldest application blocker age;
- number of outcomes handed to another session;
- time spent on platform work versus requested database work.

Green tests, merged tooling PRs, and occupied lanes are supporting measures only.

### Separate outcome issues from implementation issues

Closing a migration implementation issue must not make an unfinished release look complete. Every request needs one parent outcome that stays open until the required behavior is live in the approved environment.

### Preflight preview once, early

Before implementation, verify:

- preview project identity;
- ledger versus current main;
- required predecessor versions;
- expected starting catalog shape;
- absence of unknown remote-only migrations.

This would have exposed the Release A partial state and `20260817150944` before #1115 and #975 reached their final preview gates.

### Enforce routing at issue creation

Global instructions must refuse a shared-db issue unless the request names an actual database structure change or the narrow curated Master Data exception. Successor issues must be classified anew.

### Add a one-day stop-loss

If an application-blocking change is not live after one business day:

1. stop opening new adjacent tooling work;
2. state the complete dependency chain in plain English;
3. identify which dependencies are essential and which are process inventions;
4. remove or defer the process inventions;
5. assign one finish-first owner;
6. give Albert one honest completion forecast.

## Final assessment

The orchestrator should not be discarded merely because coordination is unnecessary. Coordination is necessary for a shared database.

The current form should be retired because it has become a self-expanding governance program. It protects against many failure modes but does not reliably deliver application changes in a reasonable time.

The replacement should be smaller:

- one intake classifier;
- one preview preflight;
- one proven migration path;
- one short independent review;
- one bounded production path;
- outcome-based tracking;
- strict limits on critical-path tooling work.

The standard for success is not “nothing unsafe happened.” It is:

> The requested database change reached the correct environment safely, was verified, and the waiting application could continue.

The recent orchestrator often achieved the first half and failed the second.
