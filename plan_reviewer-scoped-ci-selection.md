# Plan: scope reviewer test runs so each new reviewer stops slowing every change

Issue: [#1563](https://github.com/popcre/ai-devops/issues/1563) (filed 2026-10-11).
Related umbrella: [#650](https://github.com/popcre/ai-devops/issues/650) (delivery time / scoped verification). This plan is one bounded piece of it; it does not replace it.
Handoff registration: [HANDOFF.d/2026-10-11T1500Z-edge-dev3-claude-reviewer-scoped-ci-plan.md](HANDOFF.d/2026-10-11T1500Z-edge-dev3-claude-reviewer-scoped-ci-plan.md)

## STATUS (read first)

| Step | State | Evidence |
|---|---|---|
| 0. Baseline measurement script + numbers recorded | ⬜ open | — |
| 1. Per-reviewer door files map to their own suites | ⬜ open | — |
| 2. Split `tools/lib/**` select-all into reviewer-local vs truly shared | ⬜ open | — |
| 3. Split `tools/reviewer_*` select-all into mapped suites | ⬜ open | — |
| 4. Selector regression tests | ⬜ open | — |
| 5. Safety net confirmed (merge queue / schedule still run everything) | ⬜ open | — |
| 6. After-measurement + live proof on a real reviewer-only PR | ⬜ open | — |

Fresh session starts at Step 0.

## 1. Ultimate goal

Albert keeps adding AI reviewers (next candidate: Tencent HY4 via CodeBuddy). Today each reviewer adds tests, and a change to one reviewer's private files makes CI run **all ~144 test suites on Linux and the Windows lane**, so every reviewer added makes ordinary changes slower. Goal: a change that only touches one reviewer runs that reviewer's tests plus the genuinely shared reviewer tests — not everything — **without ever letting a breaking change merge untested**.

If a step conflicts with this goal, the goal wins — stop and flag it on the issue. Coverage safety beats speed: when unsure whether a path is shared, it stays select-all.

## 2. What this application is

`popcre/ai-devops` is Albert's (POP Creations) tooling repository: AI reviewer wrappers (`bin/ai-*`), the reviewer allocator and gates, installers, skills, and CI. It runs on developer machines (Linux: edge-dev3, hetz; Windows: several hosts) and in GitHub Actions. Default branch `main`, protected, merge queue; changes land by PR (`feature-branch-pr` policy in `config/repository-policy.json`).

## 3. What triggered this

Owner question on 2026-10-11 (chat): does each new reviewer slow things down permanently, and can the "runs on every change" part be fixed? Measurement on that date (origin/main `167790b0`): of the last 60 first-parent merges, **31 selected every suite** (method: run `selection_affected_suites` from `tests/lib-selection.sh` over each merge's changed paths; Step 0 turns this into a committed script). Frequent triggers among those: `tools/lib/review-doors/deepseek.sh` (3), `tools/lib/review-doors/stepfun.sh` (2), `tools/reviewer_*.py|sh` (several), plus `config/task-gates.json`, workflows.

## 4. Scope

In: the affected-suite mapping for reviewer-owned paths (`tools/lib/review-doors/*`, other reviewer-only files under `tools/lib/`, `tools/reviewer_*`), its manifest entries, selector tests, measurement.

NOT in this plan:
- Changing the merge-queue, scheduled, or manual runs (they stay full — they are the safety net).
- The Windows reviewer lane gate list `config/reviewer-ci-paths.txt` (separate mechanism; touch only if Step 5 shows it is the bottleneck, and then as a new issue under #650).
- Splitting/speeding individual slow suites, runner routing, shard counts.
- Adding HY4/CodeBuddy.
- Narrowing `.github/workflows/**`, `tests/lib-*`, `config/task-gates.json`, installers — those stay select-all.

## 5. Current state of the code

- `tests/test-all.sh --changed-since <base>` (issue #805) already selects affected suites on pull requests; `.github/workflows/verify.yml` `linux-offline-shard` passes `SELECTION_BASE` = PR base SHA. `merge_group`/schedule pass no base → full run.
- Mapping lives in `tests/lib-selection.sh` `selection_affected_suites` (fail-closed: unknown path, removed suite, or `bin/*` with no `tests/test-<name>.sh` → every suite).
- Rules data: `config/ci-suite-manifest.json` `.affected_suite_rules` with keys `path_suites` (path → suites), `companion_suites`, `select_all_globs`. Current `select_all_globs` include `tools/lib/**`, `tools/reviewer_*`, `tools/ci/**`, `.github/workflows/**`, `config/ci-suite-manifest.json`, `config/task-gates.json`, test harness libs.
- Reviewer suites exist per engine: `tests/test-ai-deepseek*.sh`, `test-ai-glm.sh`, `test-ai-qwen*.sh`, `test-ai-muse*.sh`, `test-ai-gemini*.sh`, `test-ai-grok-*.sh`, `test-ai-kimi.sh`, StepFun suites, plus shared `test-ai-review-*.sh`.
- Selector tests: `tests/test-test-selection.sh`, `tests/test-windows-bash-selection.sh`.
- Nothing from this plan is implemented.

## 6. Key findings

- The slowdown is not reviewer tests running for unrelated `bin/` changes (that is already scoped); it is that **reviewer-private files live under select-all globs** (`tools/lib/**`, `tools/reviewer_*`), so touching one reviewer reruns everything.
- `tools/lib/review-doors/<engine>.sh` is per-engine by name, so it can follow the same convention as `bin/<name>` → `tests/test-<name>.sh`.
- `tools/lib/` also holds genuinely shared code (e.g. `tools/lib/task-gates.sh`, sourced by `tools/ci/classify-changes.sh`) — that must stay select-all.
- Whether a file is shared must be established by who sources/imports it, not by its name.

## 7. Rejected approaches

- **Drop select-all entirely / trust names** — rejected: a shared helper change could merge with its dependents untested.
- **Nightly full run as the only safety net** — unnecessary: the merge queue already runs the full suite before anything lands (verify in Step 5). The win here is faster PR iteration, not skipping the merge-queue run.
- **Path filters in workflow YAML (`on.paths`)** — rejected: required checks would never report and block merges; the repo deliberately uses the in-script selector.
- **Separate per-reviewer workflow files** — rejected: more moving parts, duplicates `verify.yml`.

## 8. Decisions

Locked (2026-10-11): fail-closed stays the rule; merge queue/schedule/manual stay full; mapping data goes in `config/ci-suite-manifest.json`, logic stays in `tests/lib-selection.sh` (no new copy).
Open (implementer judgment): exact list of which `tools/lib/*` files are reviewer-local — criterion: a file is local to engine X only if every file that sources/imports it is X's wrapper, X's door, or X's tests (prove with `rg`). Anything else stays select-all.

## 9. Steps

**Step 0 — Baseline.** Add `tools/ci/measure-selection.sh <n>`: for the last n first-parent commits on `origin/main`, print commit, suite count selected, and whether it was select-all, plus a summary line. Uses `selection_affected_suites`. Record the 60-commit result in `tests/verification/reviewer-scoped-ci/<UTC>/baseline.md`. Gate: script reproduces ≈31/60 select-all on `167790b0`'s history.

**Step 1 — Door files.** In `selection_affected_suites`, before the select-all glob check, map `tools/lib/review-doors/<engine>.sh` → all `tests/test-ai-<engine>*.sh` plus the shared reviewer set (`test-ai-review-engine.sh`, `test-ai-review-preflight.sh`, `test-ai-review-lifecycle.sh` — confirm with `rg review-doors tests/`). If no `test-ai-<engine>*` suite exists → select-all (fail-closed). Prefer data in `path_suites`/a new `door_suites` key over hard-coded names. Gate: `printf 'tools/lib/review-doors/deepseek.sh\n' | ...` selects only deepseek + shared reviewer suites.

**Step 2 — Other `tools/lib/` reviewer files.** Inventory `tools/lib/` with `rg -l` for sourcers of each file. Add explicit `path_suites` entries only for files proven engine-local or reviewer-shared (→ all `test-ai-*` reviewer suites, still far fewer than 144). Keep `tools/lib/**` as the catch-all select-all for everything unlisted; ensure explicit entries are checked first. Gate: `tools/lib/task-gates.sh` still selects all.

**Step 3 — `tools/reviewer_*`.** Same method: each `tools/reviewer_*.py|sh` gets `path_suites` to the suites that exercise it (`rg -l <basename> tests/`). Unmapped ones remain select-all. Gate: `tools/reviewer_admission.py` selects its suites only.

**Step 4 — Tests** (see §10). Gate: `bash tests/test-test-selection.sh` and `bash tests/test-windows-bash-selection.sh` pass.

**Step 5 — Safety net.** Confirm in `verify.yml` that `merge_group` runs the full Linux and Windows sets (no `SELECTION_BASE`). If not, stop and flag — do not land Steps 1–3 without it. Gate: a merge-group run log for the landing PR shows all shards running the full list.

**Step 6 — Measure and prove live.** Re-run Step 0 script against a synthetic history (or the next 20 merges) and record `after.md`. Live proof: one real reviewer-only PR whose `linux-offline-shard` logs show the narrowed selection. Gate: select-all rate for reviewer-only changes drops to ~0; the PR merges via the full merge-queue run.

## 10. Tests required

In `tests/test-test-selection.sh` add cases:
- door file for an engine with suites → only that engine + shared reviewer suites;
- door file for an engine with no suite (e.g. fixture `tools/lib/review-doors/nosuch.sh`) → all suites;
- `tools/lib/task-gates.sh` → all suites;
- each newly mapped `tools/reviewer_*` file → exactly its mapped suites;
- unmapped new file under `tools/lib/` → all suites;
- deleted door file → all suites.
Must stay green: `bash tests/test-all.sh` (full), `tests/test-verify-closure.sh`, `tests/test-workflow-policy.sh`.

## 11. Constraints and gotchas

- Changing `tests/lib-selection.sh` or `config/ci-suite-manifest.json` itself selects everything — expected; the landing PR runs the full suite.
- Never push to `main`; PR + merge queue. Implementer merges (Albert does not).
- Windows: suites run under Git Bash; files must stay LF (see `.gitattributes`).
- Fail-closed everywhere: any parse failure, missing manifest key, or unknown path → all suites.
- An AI reviewer from the rotation (via `ai-review`, engine different from the implementer) reviews the PR.
- Times in issues/comments in EST.

## 12. Access and environment

Needs `gh` authenticated to `popcre/ai-devops`, `jq`, `rg`, `bash`. No secrets. Run locally: `bash tests/test-all.sh --changed-since origin/main --list` shows the selection without running.

## 13. Definition of done, risks

Done: Steps 0–6 ✅ with artifacts cited; selector tests added and green; PR merged through the merge queue; `after.md` committed; live proof checkbox ticked on the issue; plan index row updated.
Risk: an under-mapped file lets a PR pass with fewer tests — mitigated by the full merge-queue run (Step 5), so the worst case is a later merge-queue ejection, not broken `main`. Rollback: revert the manifest entries.
Open question: whether the Windows lane benefits equally (it uses `--changed-since` too) — measure in Step 6; any further Windows work goes under #650.

## Self-audit (2026-10-11)

1. Fresh session executes without questions? Yes — §2, §5 give files and mechanisms; §9 names exact files and gates; §8 gives the criterion for the one judgment call.
2. All background incl. ruled-out options? Yes — §3 measurement and method, §6 findings, §7 four rejected approaches.
3. Goal clear enough to override a wrong step? Yes — §1 states the goal and that coverage safety wins; §11/§13 restate fail-closed.
