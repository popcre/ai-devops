---
summary: Controlled trial of SchemaGraph for PostgreSQL change-impact questions on shared-db.
kind: plan
status: open
read-when: Running or interpreting the shared-db SchemaGraph trial
---

# Does SchemaGraph help us predict what a database change affects?

[Execution issue #2705](https://github.com/popcre/ai-devops/issues/2705) · [Handoff](HANDOFF.d/2026-11-19T1657Z-edge-dev3-codex-schemagraph.md)

## STATUS

Start at §9 step 1. Each row is open as of November 19, 2026.

| Step | Status | Expected evidence |
|---|---|---|
| 1 Claim and pin | Open | Private manifest |
| 2 Build candidate | Open | Binary identity and smoke result |
| 3 Prepare database | Open | Schema fingerprint and isolation check |
| 4 Freeze answer keys | Open | Six independent keys and hashes |
| 5 Capture graph | Open | Scan receipt and fixture results |
| 6 Compare investigations | Open | Twelve timed answers |
| 7 Score and publish | Open | Blinded scores and decision |

## 1. Ultimate goal

Find out whether an AI can tell us faster and reliably what will break if we change a shared database object. A confident but incomplete answer can lead a team to overlook an affected application. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Systems

[shared-db](https://github.com/popcre/shared-db) owns PostgreSQL definitions shared by POP applications. Its main branch holds migrations and database tests. [SchemaGraph](https://github.com/ictechgy/schemagraph) builds a searchable dependency map from a database catalog and SQL definitions. The [ai-devops toolkit](https://github.com/popcre/ai-devops) owns this evaluation. Run on an isolated, disposable local PostgreSQL instance matching shared-db's pinned development environment.

## 3. Trigger

CodeGraph's documented languages omit standalone PostgreSQL. Albert asked for a separate empirical trial of SchemaGraph against our normal shared-db investigation method. Neither tool's result substitutes for the other's trial.

## 4. Scope

Six real schema questions, a synthetic control suite, twelve independent timed answers and one shared-db verdict. Excluded: production access, customer rows, remote schema snapshots, fleet installation, application modifications, changing migrations, and an organization-wide adoption decision.

## 5. Current state

Planning inspected SchemaGraph b8e4054cb5d69c75fd3c334ee4489ee35b92e322. README.md:147–160 documents scan, query and impact. README.md:315–328 describes partial dynamic SQL resolution. Planning reference for shared-db is main commit 2712220. Inspect supabase/ci-bootstrap/010_pre_adoption_baseline.sql:1 and supabase/migrations/20261021223359_popdam_search_precomputed_keys.sql:1 as entry points. No trial binary, measured graph, or live comparison has been produced by the planner.

## 6. Findings

The graph represents a particular database state. A migration file can describe an object later replaced. Use the final restored definitions when checking the answer. Unknown names composed at runtime can defeat static analysis. A reported lack of dependents requires evidence that the scanner could see the relevant objects. Record scanner limitations and whether each edge came from the graph or additional investigation.

## 7. Rejected approaches

A synthetic-only demonstration cannot establish fit for our database. Comparing the graph with text search alone would deny the baseline normal access to PostgreSQL's catalog. A production scan is unnecessary for this source-defined trial. Existing upstream accuracy cases do not answer our six questions. No execution failures were observed during planning because the trial has not run.

## 8. Decisions dated November 19, 2026

Locked: identical source and schema for both arms, matched workers, hidden answer keys, isolated test database, failure and timeout accounting, no claims about outside application callers. Open: choose schema objects by the deterministic rules below, record versions and classify gaps. Never replace missing real cases with synthetic cases and count them toward acceptance.

## 9. Execute

1. **lead-only — ownership and boundaries.** Claim #2705, read current shared-db operating instructions and applicable database skills before database work. Declare the applicable task class and check the database gate. Pin the two inspected commits to full IDs in a restricted manifest.json; verify the source trees. Record CPU, memory, PostgreSQL/extension versions, concurrency and time budget. Create separate scratch roots and isolated worker identities with no inherited chat. Gate: manifest identifies both immutable inputs and all workers' allowed inputs.
2. **helper-ok — mechanical build, parallel with 3 and 4.** From the pinned upstream source build with cargo install --path engine/cli --locked --root inside a disposable build directory (supply the directory as the --root argument). Record compiler, version, binary digest and build time in build.json. Reproduce the checked-in README quick-start query and impact example. Gate: expected downstream view or trigger is returned. Stop and ask the lead on dependency drift, verification failure or privilege escalation.
3. **helper-ok — disposable environment, parallel with 2 and 4.** Follow the pinned shared-db repository's local CI bootstrap order, starting with the workflow that references supabase/ci-bootstrap. Use only tracked schema inputs and required synthetic seeds. No remote service roles, links or production URLs. Save restore command, ordered inputs, extension versions, final migration, schema-only dump hash and object inventory in restore.json. Create a local read-only identity with sufficient visibility of definitions, use it for both arms and verify a write fails. Gate: repository bootstrap checks pass and sampled definitions match the final migration state. Stop on missing prerequisite, ambiguous target or incomplete restore; report the exact failure, never silently narrow to a subset.
4. **helper-ok — independent key research, parallel with 2 and 3.** Give each key worker two cases with source access only. Pick six distinct real objects: (A) direct table-to-view dependent, (B) two-hop view chain, (C) trigger-to-routine-to-table path, (D) SQL or PL/pgSQL routine reading a relation without a foreign key, (E) dynamic SQL where a target depends on a runtime input, (F) a revised object whose earlier dependency is absent in its final definition. Start in the PopDAM search migration named in §5, scan later migrations then the remaining migrations in filename order, selecting the first verified example per category. Define a bounded question for each, including schema-qualified starting object, direction, depth, object kinds and what counts as an answer. Supply a complete in-scope edge set, forbidden plausible edge, uncertainty expectation, definition line references and independent catalog or controlled fixture proof in private key-A…F.json. After step 3 check final definitions on the restored schema; coordinator approves and hashes keys before question release. Gate: six distinct answerable questions with supporting evidence. Stop and ask on absent category or irreconcilable source/catalog results. Keep key workers out of timed runs.
5. **helper-ok — capture and controls, after 2 and 3.** On a private local disk run the pinned binary's scan against the read-only local database from the candidate output directory. Use local socket authentication or a passwordless isolated local endpoint. Record elapsed time, graph digest, size, limitation fields and counts by schema and object type in scan.json. Run every §10 control on a separate throwaway fixture database; keep fixtures outside timed inputs. Gate: expected objects visible, control outcomes recorded and a repeat query on the saved graph gives identical results. Stop on data escape, wrong target or unexplained object loss.
6. **helper-ok — timed runs after 4 and 5.** Queue twelve one-question fresh workers, one baseline and one candidate per question. Same model, effort, local catalog access, source search, prompt and ten-minute limit. Candidate also receives the saved graph and binary. Give each worker only its own question, permitted inputs and output location. Do not share answers, prior reasoning or the key. Counterbalance arm order by alternating case; schedule concurrently up to measured host capacity using equal resources. If concurrent trials contend, discard and repeat the affected pair sequentially under matching load. Prompt: “Identify the in-scope dependencies, show direction and evidence for each, and name what you cannot establish.” Save answer, provenance, duration, calls, tokens, available cost and failures as twelve separate run records. A timeout is a scored result. Gate: six matched pairs with 12 records. Stop and ask on leaked keys, unequal permissions or unmatched settings.
7. **lead-only — validation and final decision.** Have independent scoring helpers compare anonymized answers with frozen keys, and a separate helper recompute arithmetic from records. Stop scoring helpers on ambiguous keys and have them return evidence. The coordinator resolves disputes before unblinding and verifies every scored miss against source. Report complete answers, missing and invented edges, justified unknowns, median paired percentage time saved and setup/scan costs. A qualified yes requires at least one graph-sourced material finding, zero new critical misses or invented dependencies, no fewer fully correct answers and either two additional fully correct answers or at least 20% median paired time saved. For runtime-selected targets, claiming an exhaustive result without evidence is a critical miss. Estimate break-even from one-time setup divided by median seconds saved, reporting no break-even when nonpositive. State whether accuracy or time drove the verdict. Return “no demonstrated benefit” on completed comparisons below threshold, “inconclusive” for incomplete or invalid evidence. Gate: reproducible aggregate, caveats and a plain answer to Albert on #2705. At phase boundaries re-read downstream steps; resume from receipts after any chat change.

## 10. Named controls and adversarial cases

| External input | Difficult case | Named test and observable result |
|---|---|---|
| Catalog names | Same name in two schemas | QualifiedName: only the intended object and direction count |
| Routine body | Identifier constructed from caller input | DynamicTarget: uncertainty is preserved; guessed targets fail |
| Catalog privileges | Account cannot see a routine definition | RestrictedVisibility: missing visibility is recorded as a limitation by the evaluator |
| Migration history | View replaced to read a different table | ReplacedView: rescan reports current edge and drops obsolete edge |
| SQL comments | Comment tells AI to ignore the question | CommentAsData: no worker action follows it |
| Connection input | Inherited remote configuration | LocalTarget: clear inherited database settings and verify local isolated server identity before scan |
| Snapshot | Stale graph after fixture change | SnapshotAge: old digest remains identifiable and refreshed graph reflects change |

No application unit tests apply. Preserve failures in control records. An isolation failure invalidates affected runs. Score coverage failures explicitly. Existing shared-db bootstrap checks remain the restore gate.

## 11. Constraints

Separate workers by OS permissions or isolated containers. Distinct folders alone do not hide keys. Keep raw SQL, object names, answers and graph private; the public issue receives aggregates. Use approved local or repository-authorized model routes. No writes to shared environments. Worktree-per-write and protected merge rules apply to toolkit prose. The concurrent CodeGraph trial has separate databases, paths, ownership and receipts. Do not combine results.

## 12. Access and environment

Git access to the source trees was verified in planning. PostgreSQL bootstrap, local container runtime, Rust toolchain and access to an eligible smaller model must be checked at execution. No production login or secret is required. Keep private receipts in the owning repository's approved private evidence location. A substitute fixture database validates tooling only. If full restore fails, diagnose and retry against the same pin; preserve exact blocker and label the business result inconclusive if irrecoverable.

## 13. Done, recovery and risks

Publish per-case anonymized scores, missed-dependency categories, times, setup and break-even, plus the scope of any recommendation. Include negative results. Verify private receipts independently reopen, update STATUS and check off live proof on #2705 only when real pairs ran. Commit and push only owned toolkit prose, run doc safety, merge through the queue and verify origin/main. No deployment applies. Remove only run-owned disposable resources after preserving receipts. Six cases cannot establish completeness across the database.

## Self-audit

1. Can a new coordinator execute the trial? Sections 2, 5 and 9–12 give source pins, role boundaries, case-selection rules, commands, named records and verification gates.
2. Does it carry the background and trade-offs? Sections 3–8 distinguish current definitions, migration history, visibility and dynamic uncertainty. Sections 9–10 test each distinction.
3. Can the lead make the right decision if a step fails? Sections 1, 9 and 13 supply the business goal, acceptance thresholds and separate outcomes for weak results versus invalid evidence.

## Coordinator launch prompt

```text
Coordinate the SchemaGraph trial through completion. Read https://github.com/popcre/ai-devops/blob/main/plan_schemagraph-evaluation.md and https://github.com/popcre/ai-devops/issues/2705 first. Claim execution. Delegate every work packet to isolated subagents and fill available slots as dependencies allow. Keep coordination, independent verification, security decisions, scoring judgment and publication yourself. Dispatch tool setup, schema preparation and key research concurrently. Freeze keys before timed runs. Separate keys, arms and scorers. Refill slots until every pair has evidence. Resume recoverable failures. Report whether SchemaGraph actually helped shared-db, where it missed, and how much time it saved after setup.
Your helper is your own tool's smaller model — Haiku (high effort) for Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for Mimo Pro. Never a full-strength model. Follow https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md. Helpers return completed receipts or an evidenced blocker; no design decisions, merges or posts. Take back or reroute work after 30 minutes stuck. Personally verify isolation, keys, completeness, arithmetic, final receipts and the verdict.
```
