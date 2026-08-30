# Implementation plan — repository throughput restructure

**Repository:** `popcre/ai-devops`

**Parent issue:** [#159](https://github.com/popcre/ai-devops/issues/159)

**Replacement authored:** 2026-08-28 by Codex on `edge-dev`

**Source baseline:** `9a77ce67e492316f457b78fb3e9b8ce7d332995b` on `main`

**Active handoff:** [`HANDOFF.d/2026-08-28T1858Z-edge-dev-codex-repo-throughput-restructure.md`](HANDOFF.d/2026-08-28T1858Z-edge-dev-codex-repo-throughput-restructure.md)

This replaces the earlier plan and consolidates every still-relevant obligation from that plan, `HANDOFF.d/2026-08-27T1630Z-edge-dev-claude-repo-throughput-restructure.md`, and superseded issues #89, #98, and #112. Git history preserves the sources. Live work is owned only by #159 and children #160–#169.

## STATUS — read this first

A fresh session starts with **#165**, then **#160**. Final cutover #166 always runs last. Update this table in the same commit as completed work; cite a commit, CI run, or `tests/verification/` artifact, never an issue number alone.

| Order | Issue | Deliverable | State | Evidence |
|---|---:|---|---|---|
| 1 | [#165](https://github.com/popcre/ai-devops/issues/165) | Session waiting and repository growth rules | done | Merge `15991e63e53dbded3d52c218ff7f62430ef05bca`; [`tests/verification/repo-throughput/issue-165-session-conduct.md`](tests/verification/repo-throughput/issue-165-session-conduct.md) |
| 2 | [#160](https://github.com/popcre/ai-devops/issues/160) | Deterministic reviewer safety tests under real load | acceptance complete; ready to land | [`tests/verification/reviewer-reliability/issue-160-determinism.md`](tests/verification/reviewer-reliability/issue-160-determinism.md) |
| 3 | [#161](https://github.com/popcre/ai-devops/issues/161) | Fast change-aware CI | open | — |
| 4 | [#162](https://github.com/popcre/ai-devops/issues/162) | Remove duplicate Windows and post-merge verification | open | — |
| 5 | [#163](https://github.com/popcre/ai-devops/issues/163) | Targeted local test selection | open | — |
| 6 | [#164](https://github.com/popcre/ai-devops/issues/164) | Merge-queue convergence | open | — |
| 7 | [#166](https://github.com/popcre/ai-devops/issues/166) | Required-check cutover and final throughput proof | open; runs last | — |
| 8 | [#167](https://github.com/popcre/ai-devops/issues/167) | Shared offline test harness | open; after #161–#163 | — |
| 9 | [#169](https://github.com/popcre/ai-devops/issues/169) | Shared provider-wrapper infrastructure | open; after #160/#163 | — |
| 10 | [#168](https://github.com/popcre/ai-devops/issues/168) | Root plan backlog consolidation | open; after #165 | — |

Natural context cuts are after #160, after #163, and before #166. Use `fresh-session` and reread the next phase at each cut.

## 1. Ultimate goal

Albert runs many AI sessions against this repository at once. Today a session can spend hours rerunning or waiting for verification and still ship nothing. When complete, a normal scoped change can be checked and shipped in one sitting, failures are trustworthy, and concurrent changes converge through GitHub instead of repeatedly starting over.

The outcomes are: useful feedback in minutes; only relevant work on each change with a scheduled complete safety net; red means a real defect; merge-queue work converges; and all safety coverage protecting paid reviewer calls and local machines remains intact.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Never improve a timing number by removing an assertion, hiding a failure, weakening a required check, or skipping a platform without an evidence-backed safety net.

### Success measures

- Fast workflow p50 and p90 under 3 minutes; documentation-only required CI under 5 minutes.
- Ten consecutive serial Grok and Kimi passes under realistic Windows contention, plus deliberate guarded-defect failures.
- Grok at least 191 checks and Kimi at least 203 unless a reviewed mapping preserves every assertion.
- Queue p95 open-to-merged at most 60 minutes under representative concurrency, with no indefinite overtaking.
- No undocumented third full test of an exact tree after pull-request and merge-group proof.
- Improved landed-commit versus unfinished-handoff ratio from the recorded baseline.

## 2. What this repository is

`popcre/ai-devops` is POP Creations' public backup-and-restore toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell commands, reviewer safety wrappers, prompt and skill packages, machine setup, documentation, and offline verification. It is not a web application or deployed service.

- Default branch: `main`; work lands through a branch, pull request, and merge
  queue under the live repository policy.
- GitHub identity: `u2giants`; never use the DesignFlow `popcre` identity.
- Runtime: Windows developer machines and Linux, plus GitHub runners.
- GitHub is source of truth. Installation is deployment; there is no application deployment.
- Reviewer wrappers spend real money. Locks, terminal checks, bounded turns, and remote-uncertain states are capabilities, not incidental complexity.

## 3. What triggered this work

On 2026-08-27 Albert found two sessions running for roughly a day without finishing. One repeatedly ran long tests; another polled CI in ten-minute commands. The request was to repair the repository operating model, not one flaky check.

Earlier records each held part of the same failure:

- **#89:** Grok and Kimi tests flipped on the same commit because compressed wall-clock budgets, fixed sleeps, and silent polls confused machine load with wrapper defects.
- **#98:** measured run `32967607403` had `windows-offline` at 64 minutes, Linux at 9, and Windows reviewer safety at 14. Pull-request, merge-group, and `push: main` could repeat work; concurrency keys left superseded work running.
- **#112:** PR #102 rebuilt three times as changes landed ahead and took 3h02m. Faster tests shrink the window but do not remove queue invalidation.

The prior plan/handoff connected these but left partial overlap and ownerless work. #159 is now the outcome contract; #160–#169 are independently verifiable units.

### Reproduction and measurement

- Run Grok and Kimi serially on a loaded Windows machine at an exact commit; idle is not representative.
- Measure Actions by change type and event (`pull_request`, `merge_group`, `push`).
- Record queue entry, rebuild count, completion, and intervening merges.
- Time full local verification versus selected relevant suites.

## 4. Scope

### In scope

- Reviewer synchronization/timing reliability across Grok, Kimi, and a sweep of other reviewer suites.
- `verify.yml`, a separate fast workflow, event/path filters, concurrency, and scheduled safety coverage.
- `test-all.sh`, `test-all.ps1`, selection and workflow-policy tests, and evidence artifacts.
- Required-check contexts and merge-queue settings on `main`.
- Session CI-waiting conduct, repository growth rules, and before/after measurements.

### Explicitly out of scope

- Rewriting provider behavior or changing paid-work semantics.
- Deleting, quarantining, or weakening assertions.
- General cleanup of all plans/Markdown; shared database, DesignFlow, production infrastructure, or other repositories.
- Adding an AI provider.

## 5. Current state

All #159 children start open. Earlier #89 code changed, but the holistic acceptance contract is unproven.

- `tests/test-all.sh` serially runs Bash suites.
- `tests/test-all.ps1` invokes Bash and then PowerShell, repeating Linux work on Windows.
- #89 recorded 191 Grok and 203 Kimi checks.
- Earlier Grok repairs added measured baselines and louder polling, but a six-run series still had one failure. One idle 191/0 run is not proof.
- The old handoff later named PR #142 for progress-sensitive waits but said the ten-run proof was incomplete. Re-derive current code before editing and coordinate with live work.
- Original CI measurements were 9m Linux, 14m focused Windows reviewer safety, and 64m Windows full offline.
- `main` uses GitHub rulesets, not classic protection. Ruleset `21564317` originally required `linux-offline` and `windows-offline`, used `ALLGREEN`, grouped up to five entries, and had `OrganizationAdmin` bypass. Re-read live state immediately before writes.
- This file is the only live plan for #159. The active handoff is linked above. #89/#98/#112 and the old handoff are historical, not parallel owners.

## 6. Findings and root causes

### Reviewer tests

Compressed timeouts, fixed sleeps, or deadlines derived from an early baseline let a loaded fixture miss readiness and blame the wrapper. Failures must distinguish fixture-not-ready from violated behavior.

The historical Grok poll locations were lines 148, 202, 213, 219, 295, 642, and 649; re-derive current lines. Single events can be state/event driven. Counts need bounded progress-sensitive polls with loud ceilings. Kimi remains mandatory: #89 required both suites under load, defect reintroduction, count protection, and green CI.

### Duplicate work

Linux ran Bash in roughly 9 minutes; Windows ran Bash plus PowerShell in roughly 64. Per-suite Windows timing was never recorded, so process-spawn overhead remains a lead, not proof. A safe split retains suites involving Git Bash paths, CRLF, `cygpath`, `AppData`, Windows process trees, or PowerShell. When uncertain, retain them; scheduled complete Windows Bash is the safety net.

Fast feedback belongs in its own workflow because logs can be held behind slow sibling jobs. Exact trees may also receive pull-request, merge-group, and post-merge matrices. Remove a post-merge run only after exact-tree equivalence proof. Concurrency must cancel obsolete ordinary runs without cancelling unrelated required merge-group evidence.

### Queue and session behavior

Queue rebuilds survive faster tests: another merge changes the base. Batch/group settings and merge cadence are structural levers. Reassess after runtime work and choose the least risky evidence-backed lever.

Even perfect CI does not prevent repeated local full-suite runs or blind polling. Targeted selection and an event-aware waiting rule directly address the two triggering behaviors.

## 7. Rejected approaches

These are locked unless new evidence invalidates their reason.

1. Quarantine/allowed-to-fail lists: divergent output formats could hide real regressions.
2. Delete assertions or merely inflate timeouts: symptom suppression that can allow early-return/double-billing defects.
3. Six-plus-six-plus-three sharding: multiplies runners before removing duplication or measuring bottlenecks.
4. Fast lane beside long jobs: useful logs can remain hostage to the slow run.
5. Universal harness before change-aware CI: selection does not depend on normalized output; migration adds many long runs.
6. Adopt Grok locks across providers: policies/signatures differ; GLM waits while Grok can refuse.
7. Treat faster tests as queue proof: it does not remove base invalidation.
8. Remove all `push: main` verification by assumption: exact-tree and safety-net proof are required.
9. Infer no protection from classic API 404: this repository uses rulesets.
10. Use stalled PR count alone: direct-to-main work makes it gameable.
11. Parallelize ten reliability runs on one machine: copies alter the concurrency being tested.

## 8. Design decisions

### Locked, 2026-08-28

- One parent (#159), ten sub-issues (#160–#169); #89/#98/#112 are historical sources.
- Preserve assertions/capabilities; fix reliability before required-check renaming.
- Separate fast workflow; coarse categories now; keep `skills/` verified.
- Scheduled complete matrix includes unsplit Windows Bash.
- Ruleset cutover runs last and preserves `OrganizationAdmin` recovery.

### Bounded implementer judgment

- Windows-sensitive suites meet the criteria in §6; when uncertain, keep them.
- Remove/narrow post-merge work only for an exact duplicate tree.
- Choose the smallest queue lever reaching p95 without reduced coverage.
- Repair similar reviewer races within #160 when bounded; otherwise create a named sub-issue before closing it.

No owner decision is open. The user authorized this holistic plan and issue reorganization. Safety reduction or production infrastructure changes require new authority.

## 9. Execution plan

### Phase A — behavior and reliability

#### A1. #165 — waiting and growth rules

**Targets:** `AGENTS.md`, affected `templates/system/` and shared guidance, policy tests.

**Change:** require bounded event-aware CI waits, useful independent work during long checks, actionable failures, and justification/reuse before new top-level plans, workflows, or copied infrastructure.

**Gate:** a fresh session can tell how to wait and where new infrastructure belongs; focused policy evidence and origin/main commit are recorded.

#### A2. #160 — deterministic reviewer safety

**Targets:** current Grok/Kimi suites, shared timing helpers, other reviewer suites found by sweep.

**Change:** separate readiness from behavior; use event/state waits for single events and bounded progress-sensitive polls for counts; do not merely raise multipliers. Coordinate with live reviewer work.

**Gates:** ten serial loaded Windows passes for each suite; injected early-return/cancellation/locking defects fail; counts at least 191/203; exact-commit CI green; evidence under `tests/verification/reviewer-reliability/`.

Use `fresh-session` after #160.

### Phase B — fast and non-duplicative verification

#### B1. Baseline once

Create `tests/verification/repo-throughput/baseline.md` plus machine-readable data where practical. Record job/suite timings by event/change type, SHAs, runner, queue rebuilds, and landed-versus-handoff outcomes. Include run `32967607403`, PR #102, and fresh samples. Gate: every §1 metric has a current reproducible baseline or an explicit API limitation.

#### B2. #161 — fast workflow and coarse filtering

**Targets:** new workflow, `verify.yml`, `test-workflow-policy.sh`, fixtures.

**Change:** separate always-on syntax/policy workflow; prose-only long-matrix filters; never ignore `skills/`; scheduled complete matrix with actionable failure routing.

**Gates:** fast p50/p90 under 3m; docs-only under 5m; skills/code still verify; scheduled full matrix complete.

#### B3. #162 — duplicate platform/event work

**Targets:** `test-all.ps1`, Bash classification, workflow event/concurrency expressions, EOL policy, evidence.

**Change:** time suites, run only Windows-sensitive Bash ordinarily, keep complete scheduled set, inject a Windows defect, prove exact-tree equivalence before narrowing post-merge runs, and correct concurrency identity.

**Gates:** before/after timings; injected defect caught; no undocumented exact-tree third matrix; obsolete ordinary runs cancel without destroying merge-group evidence; `git ls-files --eol` proves line endings.

#### B4. #163 — local selection

**Targets:** `test-all.sh`, new `test-selection.sh`, developer guidance.

**Change:** `--only <pattern>` and coarse `--changed-since <ref>`; no args remains complete; invalid/unexpected empty selections fail loudly.

**Gates:** no args all; `--only grok-review` one; docs-only no long suite with clear message; representative bin/skills/workflow/PowerShell/test changes select documented categories.

Use `fresh-session` after #163.

### Phase C — convergence and cutover

#### C1. #164 — merge-queue convergence

**Targets:** live ruleset/queue settings, measurements, coordination guidance only if cadence is the least-risk lever.

**Change:** remeasure after Phase B; if p95 exceeds 60m, change the smallest supported lever among batch/grouping, concurrency policy, or merge cadence.

**Gates:** representative queue/rebuild/intervening-merge data; p95 at most 60m; no indefinite overtaking; prior values recorded for rollback.

### Phase D — consolidation that must follow the throughput foundation

These were named follow-ons in the old plan. They remain inside parent #159 so they cannot become ownerless, but their dependencies prevent them from delaying the first usable throughput improvements.

#### D1. #167 — shared offline test harness

**Targets:** duplicated Bash test helpers, suite reporting, and per-suite mapping only where coarse selection evidence justifies it.

**Change:** normalize test infrastructure in bounded batches without changing assertions. Do not begin before #161–#163.

**Gates:** before/after assertion maps, injected failures, complete scheduled matrices after every batch, and measured value before adding per-suite mapping.

#### D2. #169 — shared provider-wrapper infrastructure

**Targets:** duplicated helpers across Grok, GLM, Kimi, and Qwen plus provider-specific safety tests.

**Change:** first resolve whether GLM, Kimi, or Qwen can double-bill without Grok's `remote-uncertain` protection. Then extract only byte-equivalent or behavior-proven infrastructure; preserve distinct lock wait/refusal policies.

**Dependencies:** #160 and #163. **Gates:** explicit paid-work uncertainty/terminal tests, unchanged provider policies, and exact-head independent review for each safety batch.

#### D3. #168 — root plan backlog consolidation

**Targets:** root `plan_*.md`, their issues, router entries, and matching handoffs.

**Change:** inventory by live issue/completion/successor; preserve unique decisions; retire only proven complete or fully superseded plans. Count reduction is not the goal.

**Dependencies:** #165. **Gates:** every remaining plan has live ownership/current STATUS/discoverability; every retirement has evidence and preserved decisions; no issue points only to a deleted plan.

### Phase E — final cutover

#### E1. #166 — cutover and final proof

**Targets:** live ruleset or successor, final job names, throwaway PR, plan/handoff, final evidence.

**Change:** repoint required contexts only after names stabilize; preserve history protection/admin bypass; remove stale contexts; record final comparison.

**Gates:** throwaway PR reports every required context and enters/merges through queue; no stale context; recovery proven; §1 measures recorded; all children and #159 close; active handoff retires in completion commit.

## 10. Tests required

| Test/artifact | Required behavior |
|---|---|
| Grok/Kimi reviewer suites | Loaded serial stability and injected-defect failure; counts protected |
| Other reviewer suites | No equivalent fixed-sleep/silent-ceiling left undocumented |
| `tests/test-workflow-policy.sh` | Separate fast workflow, path policy, schedule, event/concurrency shape |
| `tests/test-selection.sh` | No-arg, `--only`, `--changed-since`, invalid, expected-empty cases |
| PowerShell suite | Windows selection plus complete scheduled fallback |
| EOL checks | Executable in actual shell; `git ls-files --eol` |
| Reviewer reliability artifacts | Exact SHA, machine/load, ten serial runs, counts, injection |
| Throughput artifacts | Baseline/final timing, events, rebuilds, p95, outcomes |
| Throwaway PR | Required contexts, queue admission, recovery path |

Run full offline verification before each code child lands. #165 includes an
executable policy test and therefore uses the normal code-change checks, not the
documentation exception.

## 11. Constraints and gotchas

- Read current `AGENTS.md` and routed docs at each child start.
- Work on a task branch and merge through a pull request; stage only owned
  files; verify Git identity; never force-push.
- Inspect concurrent changes before pull/merge/commit/cleanup.
- Use Git Bash for Bash checks on Windows; PowerShell `bash` may invoke WSL.
- Re-read exact live rules, bypass actors, contexts, and target before every ruleset write.
- A required context naming a deleted job blocks every merge; cutover last.
- Verify remote PR state if `gh pr merge` reports only local worktree cleanup failure.
- Keep fast workflow separate; do not use job-level `continue-on-error` for safety.
- Run reliability repetitions serially per machine.
- One green run, a PR description, or a bare count is not evidence.
- Exact-head independent review is required for reviewer safety path changes.

## 12. Access and environment

- Repository `https://github.com/popcre/ai-devops`, branch `main`.
- Verify GitHub CLI identity before writes.
- Local Windows evidence records hostname, SHA, and concurrent load.
- Offline tests need no secrets. Paid probes use 1Password vault `vibe_coding` by item title only.
- No application URL or production database. Machine config under `/etc/ai-devops/` is not source.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] #160–#169 closed with acceptance evidence and STATUS artifacts.
- [ ] Focused plus full offline tests pass; exact Git identity checked.
- [ ] Task-owned commits are on `origin/main`; live workflow/ruleset changes are proven.
- [ ] Baseline/final evidence is under `tests/verification/repo-throughput/`.
- [ ] No assertion, platform capability, recovery bypass, or paid-work safety is lost.
- [ ] #159 closes only after all children/final measures; active handoff retires in completion commit.

### Risks and rollback

| Risk | Prevention | Rollback |
|---|---|---|
| Stale context blocks merges | Cutover last; throwaway PR | Restore recorded context list via admin bypass |
| Platform split hides defect | Conservative list; injection; schedule | Restore complete ordinary Windows Bash |
| Event filter skips distinct tree | Exact-tree proof | Restore prior trigger |
| Concurrency cancels queue evidence | Event/PR identity; observe queue | Restore prior expression |
| Reliability fix weakens tests | Counts, injection, review | Revert focused commit; reopen #160 |
| Queue tuning reduces safety | Never drop required coverage | Restore recorded ruleset values |
| Session collision | Read claims/handoffs/PRs | Stop and coordinate; never overwrite |

### Open questions

No owner decision blocks work. Evidence-bounded questions are the exact Windows suite list, whether post-merge proves a distinct tree, the least-risk queue lever, and whether other reviewer suites share #89's pattern.

### Mandatory self-audit

1. **Could a new session execute without chat? Yes.** §§2–6 establish repository, incidents, source obligations, state, and causes; §9 gives targets, dependencies, and gates.
2. **Is all material background/rejected reasoning preserved? Yes.** §§3, 6, and 7 carry #89's Grok/Kimi contract, #98 timing/event/cancellation, #112 queue criteria, session failures, and dead ends.
3. **Can the goal guide a wrong step? Yes.** §1 makes trustworthy safety coverage the controlling rule.

All 13 sections are present. Locked/bounded decisions, scope, tests, environment, risks, landing proof, issue ownership, STATUS evidence, and handoff links are explicit.
