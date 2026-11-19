---
summary: Paired source-navigation trial for CodeGraph on DesignFlow, PopDAM and shared-db.
kind: plan
status: done
read-when: Evaluating CodeGraph or comparing code navigation tools
---

# Test whether CodeGraph helps our AI sessions

[Tracking issue](https://github.com/popcre/ai-devops/issues/2699) · [Original handoff](https://github.com/popcre/ai-devops/blob/3be36754f66476be324153d150ccdda84d8c5c0e/HANDOFF.d/2026-11-19T1617Z-edge-dev3-codex-codegraph.md)

## STATUS

The paired trial is complete. CodeGraph found useful caller leads in all
three repositories. All three fell short of the evidence needed for a
larger pilot.

Ordinary source search is the default for DesignFlow, PopDAM, and shared-db.
Keep CodeGraph out of the standard setup. Start at §8 for the conditions
that would justify a focused retest.

| Step | 2026-11-19 | Evidence to attach |
|---|---|---|
| 1 Prepare answer keys | Done | Nine questions and checked keys frozen before their first run |
| 2 Prepare isolated tool | Done | Signed release verified, three indexes and matching source manifests |
| 3 Run paired searches | Done | 18 fresh answers, zero timeouts |
| 4 Score and decide | Done | Measured results below and on #2699 |

### Measured results

- **DesignFlow frontend.** CodeGraph surfaced the exact production call site.
  That search was 9.4 seconds faster. Ordinary search found the test and
  traced the displayed grid binding. The median paired saving was 0.50 seconds
  (2.4%). Indexing took 2.58 seconds for 919 files, with a 67.7 MB index.
  Index time alone would require six searches at the observed median.
- **PopDAM.** CodeGraph pointed to the embedding handler's dispatcher during
  the persistence question. Source reads established what the missing-input
  test covered and where the handler's result was stored. The candidate was
  8.87 seconds slower at the median, a 24.4% slowdown. Indexing took 2.66
  seconds for 892 files, with a 54.5 MB index. No break-even was observed.
- **Shared-db.** CodeGraph surfaced a JavaScript helper's test import. That
  pair was 3.70 seconds faster (5.7%). The two SQL answers came entirely from
  ordinary search and file reads. The raw median paired saving was 13.17
  seconds (21.9%). Both of the larger savings came from the SQL pairs, so the
  raw median does not establish a CodeGraph speedup. The median graph
  contribution is zero when the fallback-only pairs get zero credit.
  Indexing took 3.84 seconds for 706 files, with an 82.5 MB index and zero
  SQL files. The raw timing implies one search to recover index time, with
  no demonstrated break-even attributable to CodeGraph.

Fresh Codex Luna sessions at high reasoning answered the same questions with
and without CodeGraph. The first method alternated by question. Times include
session startup. Pair percentages use the baseline time for the denominator.
Setup times above cover indexing. Release acquisition and verification were
untimed, and per-use billing cost was unavailable. Each repository contributed
three questions, so timing differences are directional.

All three repositories scored 3/3 in both methods on the relationships the
questions asked for. No requested links were missed or invented in the final
answers. The initial blind pass also scored stricter key details, including
explicit import citations and the migration backfill. It gave DesignFlow 1/3
versus 0/3, PopDAM 3/3 versus 3/3, and shared-db 2/3 versus 2/3. A second
blind check resolved the DesignFlow deductions. The final source check
verified the shared-db answers against the relationships actually asked for.
The private receipts preserve both blind passes and the final adjudication.
The pilot decision holds under each scoring.

| Repository | Seconds per pair, plain / graph available | Total calls, plain / graph | Total input tokens, plain / graph | Total output tokens, plain / graph |
|---|---|---|---|---|
| DesignFlow | 38.80 / 29.39, 20.35 / 19.86, 59.02 / 63.15 | 37 / 38 | 749,673 / 681,771 | 4,593 / 4,700 |
| PopDAM | 28.42 / 40.20, 28.53 / 35.48, 60.30 / 69.16 | 46 / 57 | 671,493 / 941,416 | 4,850 / 6,330 |
| Shared-db | 65.30 / 61.59, 60.25 / 47.07, 44.21 / 30.47 | 59 / 50 | 895,544 / 657,030 | 7,625 / 6,290 |

The call totals include failed attempts. Ordinary file reads with CodeGraph
available numbered 20 for DesignFlow, 27 for PopDAM, and 31 for shared-db.
Input counts include cached tokens reported by the Codex sessions.

Source revisions were the three pins in section 5. The trial used the signed
[CodeGraph 1.6.3 release](https://github.com/colbymchenry/codegraph/releases/tag/v1.6.3),
built from `44098dec2c014f94f04c07df2d257b58bda2bb5a`, a different revision
from the planning snapshot. The release tag points to a changelog-only child
of the attested build revision. The artifact and checksum manifest passed
signature and digest verification. Both methods were confined to matching
source manifests. The outside-file sentinel and source-comment instruction
fixtures passed for both methods. The rename check returned the new symbol
and dropped the old one. Source review confirmed the requested relationship
directions. Detailed source evidence, blind scores, and replay inputs remain
in separate restricted local receipt folders for the three repositories.

## 1. Ultimate goal

Help a new AI session reliably identify what a change could affect, with less investigation and fewer missed dependencies. Decide separately for each application and kind of work. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Applications

DesignFlow helps staff manage products. Test its frontend at popcre/designflow-frontend, develop. PopDAM helps staff search digital assets. Test u2giants/popdam3, main. Shared-db owns database changes used across applications. Test popcre/shared-db, main. All repository names refer to github.com. Run on disposable local copies on edge-dev3. No running application or database is needed.

## 3. Trigger

Albert asked whether a new session could evaluate code-navigation tools using repeatable evidence, and whether CodeGraph would help with the two other repositories. This is a comparison of how sessions answer real maintenance questions. Transcript mining is a separate workflow.

## 4. Scope

Three source questions per repository, two search methods per question. Include app-to-database boundaries. Outside this plan are deployment, fleet installation, app fixes, private transcript ingestion and building a general evaluation platform.

## 5. Current state

The completed comparison and tested executable are recorded in STATUS.
The planning reference snapshots were DesignFlow 6fea83c, PopDAM f5c941a,
shared-db 2712220 and colbymchenry/codegraph 67178d8. Resolve each in its own
repository when reproducing the original work. Case anchors below are
relative to their respective repository roots.

## 6. Evidence and expected fit

Upstream [README lines 873 onward](https://github.com/colbymchenry/codegraph/blob/67178d8/README.md#supported-languages) advertises TypeScript, JavaScript and Python. Standalone PostgreSQL SQL and PL/pgSQL are absent. Its measured TypeScript coverage uses its own repository. git ls-tree -r --name-only on the reference snapshots finds 610 .ts and 232 .tsx files in PopDAM, and 1,709 .sql files in shared-db. Repositories can contain copied database sources. Treat database ownership and application calls as separate evidence. Expect source navigation to help on app and automation code. SQL behavior and migration ordering require their own proof.

## 7. Rejected approaches

Stars and upstream benchmarks cannot tell us whether the tool finds our dependencies. A single blended score can hide missed database links. Asking the same session twice leaks its first answer. No installation or benchmark failed during planning because neither was attempted.

## 8. Decisions

Decision on November 19, 2026. Use ordinary source search by default across
all three repositories. Revisit CodeGraph for a specific repository when
one of these conditions is met.

- **DesignFlow.** Tracing production callers becomes a recurring bottleneck.
  Retest that task with representative TypeScript call chains.
- **PopDAM.** A release demonstrates better coverage of the worker dispatch
  and database call paths that required source reads in this trial. Retest
  those paths, including where the result is stored.
- **Shared-db.** CodeGraph demonstrates cross-file PostgreSQL migration
  tracing with source citations for objects created, replaced, or used by
  later migrations. Until then, read the SQL and migration history directly.
  The [SchemaGraph evaluation](plan_schemagraph-evaluation.md) separately
  tests dependencies in a restored schema. Comparing graphs before and after
  selected migrations could show when dependencies changed. Mapping those
  changes to the original migration files still requires source verification.

A retest keeps ordinary search available in both methods and uses matched
questions, independent answers, checked evidence, and a separate verdict
for each repository. A larger pilot requires at least 20% median paired
time savings attributable to CodeGraph, a directly useful graph finding,
and no correctness regression or invented critical dependency. Credit
ordinary-search-only answers with zero graph contribution. Include setup
time in the decision.

## 9. Execution

1. **lead-only — answer-key judgment.** In a private local directory create questions.json and key.json. For each repository ask three questions. DesignFlow anchors are src/app/pages/itemDetail/item-detail-merch-selection.ts and src/app/pages/itemLibrary/item-library-merch-label.ts. Ask which production caller uses the first exported function, which test exercises it, and where the second file's output is bound in the UI. PopDAM anchor is apps/worker/src/handlers/embed-search.ts. Ask where the handler is registered, which test covers its response to missing input, and which persistence boundary receives its result. Shared-db anchors are scripts/acquire-merge-lane-waiting.mjs and supabase/migrations/20261021223359_popdam_search_precomputed_keys.sql. Ask what invokes the script, which database objects the migration reads or changes, and which later migration supersedes or still relies on one changed object. Trace all nine manually using git grep, imports, tests and chronological SQL. Record accepted path, line, symbol, link direction and any confirmed absence. If a premise is false, phrase the question neutrally before freezing the keys. Gate: nine independently checkable answers, hashes recorded, keys outside agent-readable workspaces.
2. **helper-ok — mechanical setup.** Use the pinned trees in separate temporary directories with test fixtures and source only. Exclude private evidence, credentials, transcripts and mirrored shared-db directories from application inputs. Both arms see identical files. In an isolated OS account or container, obtain a verified CodeGraph release following upstream README's Verified releases section. Pin version and corresponding commit, documenting any difference from planning head. Set DO_NOT_TRACK=1 and disable network after setup. Invoke the local binary directly, skip agent-wide installation. Run codegraph init then codegraph status --json in each candidate copy. Save elapsed index time, size, included paths and version in setup.json. Gate: three usable indexes and matching input manifests. Stop and ask the lead if verification, exclusions or isolation fail.
3. **lead-only — experimental independence.** For each question use two fresh isolated sessions with identical model, reasoning, prompt, permissions, source snapshot and ten-minute limit. Alternate which arm runs first by question. Baseline uses ordinary file search and reads. Candidate adds local codegraph query, callers, impact and context. Allow ordinary search to verify leads and cover unsupported SQL. Record which findings came from which method. Neither arm sees keys, earlier answers or issue comments. Require answers with path and line evidence or an explicit unknown. Save elapsed time, tool calls, input/output tokens, available cost, fallback reads, timeout and final answer in runs.jsonl. Missing cost is unknown. Gate: 18 labeled records including failures.
4. **lead-only — acceptance judgment.** Blind the method labels while matching answers against the frozen key. Report missed and invented links, fully correct answers, median paired time savings, calls and tokens per repository. Report one-time setup cost and break-even searches using positive median seconds saved. Recommend a larger pilot only for a repository with no correctness regression on any question, no invented critical dependency, and at least 20% median paired time saving. Treat a correct answer found solely by fallback as zero graph contribution. Require at least one directly useful graph finding. Otherwise report limited fit or insufficient evidence. Keep private details with their owner and publish aggregate results on #2699. Gate: all three verdicts independently reproducible, including native SQL versus helper-code findings.

| External input | Difficult case | Named check |
|---|---|---|
| Repository contents | Ignored secret or symlink outside root | Exclusion sentinel: plant harmless unique markers outside the allowed inputs and confirm neither arm can read them |
| Candidate package | Wrong version or checksum | Release identity: compare upstream verification evidence and record digest before indexing |
| Source relationships | Duplicate name, string-based registration or SQL reference | Boundary check: verify actual destination and direction against the key |
| Indexed source | Rename leaves obsolete answer | Freshness check: rename a disposable fixture symbol, sync, verify new lookup succeeds and old definition disappears |
| Candidate output | Source comment attempts to direct the evaluator | Instruction fixture: treat comment as source data and confirm neither arm follows it |

## 10. Tests

Run all five named checks before scoring. Keep fixtures separate from timed questions. Any failed isolation check stops the trial pending repair. Report failed coverage and freshness checks beside results. No production code or unit-test changes. For toolkit prose run bin/ai-doc-safety --changed origin/main.

## 11. Constraints

Use disposable local inputs. No production connection, migration, credential, agent-wide integration or source upload. Use only sessions already approved for the owning repository's contents. Keep raw private answers and paths out of public receipts. Keep the live-proof checkbox on #2699 until measured evidence exists. Re-read downstream steps after setup if changing sessions.

## 12. Access

Planning confirmed read access to all four Git repositories. Clone via the existing authenticated Git setup. No app login is needed. Check available disk before creating copies, and tool release verification before opening any private source. Store the private key, manifests and runs with restricted permissions outside the search roots. Use the owning private repository's existing evidence convention for durable receipts.

## 13. Done, risks and recovery

Finish when all paired results, fixture checks, raw private receipts and public aggregate decisions exist and another reader can reproduce the scoring. Record tested source and executable versions. Update STATUS and #2699, link receipts, then retire the handoff. Land toolkit prose through a scoped commit, push, pull request and merge queue. Verify the landed files on origin/main. Application deployment is inapplicable. Three questions per repository justify only a follow-up pilot. Discard isolated indexes and trial accounts after preserving receipts. Per-use cost or accuracy outside these tasks remains unknown.

### Self-audit

1. Can a fresh session execute it? Sections 2, 5 and 9–12 give pinned inputs, paths, prompts, record formats, boundaries and verification gates.
2. Does it preserve what we know and ruled out? Sections 3–8 distinguish inspected source, unmeasured benefits, and design choices. Section 9 handles unsupported relationships and leakage.
3. Can the lead resolve a conflict correctly? Sections 1 and 13 put reliable impact assessment first. Sections 8–9 specify what may vary and how each recommendation is earned.

### Lead launch prompt

The prompt below is preserved from the completed trial. Use §8 to decide
whether new evidence warrants a retest.

Coordinator mode requested November 19, 2026. Delegate evidence collection for lead-owned steps while retaining the gates and final judgment. Setup may overlap key research because the snapshots are pinned. Timed workers still require frozen keys.

```text
Coordinate the CodeGraph trial through completion. Read https://github.com/popcre/ai-devops/blob/main/plan_codegraph-evaluation.md and https://github.com/popcre/ai-devops/issues/2699. Claim execution. Delegate every work packet to isolated smaller-model subagents. Parallelize setup and answer-key research across DesignFlow, PopDAM and shared-db. As each repository is ready, dispatch fresh matched baseline and candidate workers without keys or prior answers. Counterbalance order and avoid resource contention. Delegate blinded scoring and arithmetic; retain ownership of key approval, safety, verification, final decisions and publication. Follow the plan's controls and thresholds. Refill slots, resolve blockers and verify all 18 answers. Tell me whether CodeGraph actually helped each repository, what it missed, and whether savings justify setup.
```

The following role and verification rules also apply.

```text
Read plan_codegraph-evaluation.md STATUS in popcre/ai-devops, then #2699. Own steps 1, 3 and 4 and verify all gates yourself. Dispatch step 2 alongside independent key research. Your helper is your own tool's smaller model — Haiku (high effort) for Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for Mimo Pro. Never a full-strength model. See https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md. Accept finished setup or an evidenced blocker. The helper makes no design decisions, merges or posts and returns to you at the step's stop trigger. Take back work after 30 minutes stuck. Check isolation, all nine keys, all 18 records and separate verdicts yourself. Read the remaining phases again at any session boundary.
```
