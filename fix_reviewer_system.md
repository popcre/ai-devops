# Fix the delegated reviewer system

Status: analysis complete; implementation is tracked by [ai-devops issue #34](https://github.com/u2giants/ai-devops/issues/34).

Ownership is deliberately split. `ai-devops` owns the reviewer wrappers, the
rules installed into every AI session, provider health checks, review packets,
and the source-level rule that prevents non-structural work from being sent to
shared-db. `shared-db` owns only its database-specific lane scheduling, merge
freeze, exact-main sequencing, and production-promotion workflow. The latter is
tracked separately in shared-db and must not be implemented as generic reviewer
behavior.

This report records what failed during the 24-hour shared-db orchestrator session
of 2026-08-16/17 and the permanent fixes required.

For the broader failure beyond delegated reviews, including concrete issues that
crossed sessions or remained unfinished, read
[`shared-db_orchestrator_failure_analysis.md`](shared-db_orchestrator_failure_analysis.md).

## Executive conclusion

The poor throughput was not caused by one problem. The reviewer system caused a
large, avoidable share of the delay: small, well-tested changes repeatedly spent
10–15 minutes in review, consumed millions of tokens, and returned no verdict.
Another provider then reread much of the same repository. Main sometimes changed
during the delay, invalidating the eventual review and restarting CI plus review.

It was not purely a reviewer problem. GitHub had a documented major outage;
preview contained incomplete and untracked migrations; production gates exposed
real defects; unrelated merges invalidated exact-head evidence; and the
orchestrator wrongly retained non-database issue #1113. These separate causes
must not be hidden by blaming one system.

The current review design is safe but operationally inefficient. Preserve its
read-only, exact-head, terminal-verdict, fail-closed rules. Replace repository
exploration with sealed evidence packets, short ordinary budgets, early verdicts,
provider health checks, and stable-head scheduling.

## Measured reviewer failures

### Fifteen minutes is configured behavior

- `bin/ai-grok-review`: 20 turns and a 900-second wait by default.
- `bin/ai-kimi`: 900-second wait.
- `bin/ai-glm`: 1,800 seconds for one turn.

These exceptional ceilings became routine budgets for small pull requests.

### Grok consumed full budgets without decisions

Measured runs included:

- 20 turns, 2,961,649 total tokens, $0.39477468, cancellation, no verdict;
- 20 turns, 2,727,014 total tokens, $0.30456044, cancellation, no verdict;
- 20 turns, 2,559,906 total tokens, $0.28644932, cancellation, no verdict;
- multiple 12-turn runs ending without a verdict or artifact.

Most input was reported as cache reads, but it still created long waits and no
business decision.

### Reviewers receive a repository, not a decision packet

The safe profiles provide read/search tools but no arbitrary shell. Reviewers
therefore cannot efficiently build a trusted comparison themselves. They receive
a directory and a prose brief, then spend turns locating files, reconstructing
scope, and rereading policy. Small diffs become repository investigations.

A wrapper-built packet should instead contain the exact base/head, file list,
patch, relevant policy files, test results, requested decision, and exclusions.

### The verdict is requested too late

Wrappers require a final `## Verdict`. If the model investigates until its last
turn, governance receives no verdict and correctly refuses approval. The current
Grok guidance then suggests more turns, which rewards failure to prioritize the
decision and increases cost.

### Provider failures are discovered after assignment

Observed cases:

- Kimi waited to 900 seconds and then returned HTTP 403 for exhausted allowance;
- GLM could not read linked-worktree Git metadata outside its allowed directory;
- GLM attempted web search when a snapshot lacked an expected local reference;
- GLM returned empty assistant turns until a no-progress limit;
- Grok hit turn limits without a final answer;
- one Grok result was unusable because of a wrapper quoting defect, despite a
  valid finding.

Authentication, allowance, snapshot readability, base/head availability, and
result-artifact creation must be proven before durable assignment.

### Exact-head safety multiplied the delay

Exact-head binding is correct. A verdict for one commit cannot approve another.
The scheduling was wrong: reviews began while prerequisite or unrelated merges
were still likely. Main advanced during long reviews, forcing refresh, CI, and
another review. This recurred across #1072, #1089, #1090, #1108, #1115, and
tooling repairs.

### Manually transcribed SHAs invalidated evidence

Agents sometimes expanded a short commit prefix into an incorrect full SHA. The
reviewer may have read the correct checkout, but durable evidence named a
different commit. The wrapper must derive the SHA directly; callers must never
type or reconstruct it.

### Failure rotation is too generic

Different failures need different responses:

- exhausted allowance: quarantine provider;
- broken snapshot: rebuild once, then quarantine;
- empty turns: fail in 2–3 minutes;
- turn exhaustion: shrink the packet, never simply double turns;
- service outage: bounded retry, then wait;
- substantive finding: stop and fix, never shop for a friendlier verdict.

The session handled these distinctions manually and late.

## Delays not caused by the reviewer system

### GitHub outage

GitHub publicly reported major outages affecting API requests, Actions, issues,
pull requests, and Git operations. The session repeatedly received HTTP 503/504
while reading approvals, posting statuses, comparing commits, creating locks,
and dispatching workflows. Local `gh` authentication was healthy.

### Real safety defects

The gates correctly found problems requiring permanent fixes:

- transaction handling for sequence locks;
- production approval rereads lacking bounded transport retry;
- collision checks depending on a failing GitHub comparison endpoint;
- incomplete preview application of Sample Tracking Release A;
- an untracked preview migration with unique live schema effects;
- a production-order conflict between #1090's new write guard and held licensing
  migrations;
- catalog verification unable to understand an expression index or sequence-only
  migration.

Faster reviews reduce repair-cycle time but do not remove these required repairs.

### Main-branch churn

Unrelated documentation and tooling merges repeatedly changed main during
production-bound reviews. Exact evidence then expired. Stabilization must begin
before final review, and unrelated merges must wait briefly.

### #1113 was misrouted

#1113 is offline Item Master taxonomy analysis. It changes neither database
structure nor schema. It stayed in shared-db because predecessor plan #1097 lived
there and the successor inherited the repository without reclassification. That
consumed a scarce shared-db agent and attention. Repository inheritance must
never determine ownership.

## Preventing another #1113

Every new or successor issue must answer from scratch:

> Does this work change the shape of the shared database?

- Yes: shared-db structural issue, exact objects, migration-author lane.
- No, it changes application data or performs offline analysis: owning
  application repository/session.
- Outside-sourced curated Master Data: the existing controlled exception.
- Planning or repository maintenance: non-migration route; no migration-author
  or shared-db implementation agent.

Required enforcement:

1. Require a machine-readable scope block on every actionable shared-db issue.
2. Reclassify successors; never copy the predecessor's route automatically.
3. Refuse shared-db implementation unless route is structural or the curated
   Master Data exception.
4. Require exact database objects before a structural claim.
5. Route application, source-data, offline-analysis, and maintenance work away
   from shared-db implementation agents.
6. Audit structural lanes, blocked structural work, non-structural work assigned
   to shared-db agents, and unclassified issues separately.
7. On misrouting, stop, preserve private artifacts, and hand off to the correct
   private application repository.
8. Add the exact #1097 → #1113 case as a regression test.

For #1113, the correct destination is a private
`popcre/designflow-item-master` issue. Its private artifact must not be published
or moved until a safe private handoff exists.

## Proposed reviewer redesign

### P0: sealed review packets

Create one wrapper-owned, hashed manifest containing:

- repository identity and exact base/head;
- changed files and unified patch;
- intentionally included untracked files;
- relevant tests and exact results;
- affected policy/dependency files;
- maximum scope and exclusions;
- required verdict vocabulary.

The reviewer may open named files for confirmation but must not rediscover the
basic comparison.

### P0: short ordinary budgets

| Review class | Turns | Wall time | Limit behavior |
|---|---:|---:|---|
| Small exact-head diff | 6 | 5 minutes | verdict or explicit no-verdict; no automatic continuation |
| Medium/security diff | 10 | 8 minutes | same |
| Explicit architecture investigation | 20 | 15 minutes | opt-in only |

Keep current long ceilings only as explicitly requested exceptional modes.

### P0: early verdict protocol

Require: provisional verdict, findings with evidence, final verdict. At halfway,
capture a provisional result. It cannot approve a change if the run later dies,
but it lets the orchestrator narrow or fix instead of waiting blindly.

### P0: provider preflight and quarantine

Before assignment, prove allowance/authentication, exact directory readability,
base/head presence, manifest readability, local-service health, and result-file
creation. Skip known-exhausted providers for a cooling period. Preflight failures
must take seconds and must not count as attempted reviews.

### P0: wrapper-owned identity

Read base/head from Git inside the wrapper. Record base, head, packet hash,
changed-file hash, provider/session, terminal reason, and verdict. Never accept a
manually expanded full SHA as evidence identity.

### P1: stable-head scheduling

Start final review only after implementation and tests are complete, CI is on a
stable head, prerequisites are merged, and merge order is declared. Briefly queue
unrelated merges behind production-bound final review.

The generic reviewer service should expose whether evidence is current or stale.
The shared-db repository, not ai-devops, decides when to freeze its own merges,
which database change goes first, and when production promotion may begin.

### P1: failure-specific rotation

Encode the differentiated responses above. In particular, turn exhaustion must
shrink the packet, not increase the turn budget, and a substantive blocker must
stop rotation.

### P1: reviewer performance ledger

Record elapsed time, turns, tokens/cost when available, verdict, accepted
findings, failure class, and whether evidence became stale. Select the fastest
healthy provider for each review class rather than rotating blindly.

### P1: one review service

Shared-db should call one `ai-review` interface. Provider wrappers remain below
it, but agents must not manually assemble prompts, clones, turn limits, or
terminal-state interpretations.

## Required tests

1. A two-file diff returns a verdict within 6 turns/5 minutes.
2. Only the sealed packet and named files are available.
3. Missing base/head fails before provider assignment.
4. Caller SHA transcription cannot enter evidence.
5. Exhausted allowance is skipped in seconds.
6. Linked worktrees produce complete self-contained snapshots with refs.
7. Empty turns terminate at the short no-progress limit.
8. Turn exhaustion recommends a smaller packet, never automatic extra turns.
9. A substantive blocker stops rotation.
10. Main advancement marks evidence stale before preview/merge.
11. A non-database successor like #1113 is rejected from shared-db execution.
12. Metrics distinguish provider failure, GitHub outage, code blocker, and stale
    head.

## Success criteria

Over at least 30 real reviews:

- 90% of small reviews finish within 5 minutes;
- 95% return a usable verdict;
- no small review exceeds 10 turns;
- no exhausted provider receives durable assignment;
- no SHA is manually transcribed;
- fewer than 5% of verdicts become stale before use;
- provider failures are identified within 2 minutes;
- zero non-structural issues consume shared-db agents;
- all production-bound changes still have valid exact-head independent review.

## Implementation order

1. Build and hash sealed review packets.
2. Move SHA/file identity into the wrapper.
3. Add provider preflight and quarantine.
4. Add short ordinary budgets and early verdicts.
5. Add failure-specific rotation.
6. Add performance metrics and a 30-review trial.
7. Add the global source-routing rule and the #1113 regression to the installed
   instructions and shared-db routing skills.
8. Implement shared-db's lane scheduling, merge-freeze, and promotion sequencing
   in shared-db under its separate tracker.

Do not trade safety for speed. Remove wasted search, waiting, and repeated work
while preserving read-only, exact-head, independent, fail-closed review.
