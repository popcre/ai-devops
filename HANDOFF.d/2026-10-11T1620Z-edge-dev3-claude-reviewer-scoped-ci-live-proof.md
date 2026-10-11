# Handoff: reviewer-scoped CI — only the live proof remains

Owner issue: [#1563](https://github.com/popcre/ai-devops/issues/1563). Plan: [plan_reviewer-scoped-ci-selection.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-scoped-ci-selection.md) (STATUS table current).
Supersedes the plan-stage note [2026-10-11T1500Z-edge-dev3-claude-reviewer-scoped-ci-plan.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-11T1500Z-edge-dev3-claude-reviewer-scoped-ci-plan.md) (written by another session; that file is a successor-review candidate, not edited here).

## 1. Goal
A change touching only one AI reviewer runs that reviewer's tests, not every suite, without ever letting untested work merge.

## 2. Done (merged 2026-10-11 via [PR #1566](https://github.com/popcre/ai-devops/pull/1566), merge commit 532595e5)
- Reviewer-owned paths mapped in [config/ci-suite-manifest.json](https://github.com/popcre/ai-devops/blob/main/config/ci-suite-manifest.json) `path_suites` (six doors, reviewer-local `tools/lib` helpers, four `tools/reviewer_*` files, reviewer Python tests).
- [tests/lib-selection.sh](https://github.com/popcre/ai-devops/blob/main/tests/lib-selection.sh): a mapped path that no longer exists now selects every suite.
- [tests/test-test-selection.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-test-selection.sh): 7 new cases, 28/28 pass.
- [tools/ci/measure-selection.sh](https://github.com/popcre/ai-devops/blob/main/tools/ci/measure-selection.sh); records in [tests/verification/reviewer-scoped-ci/2026-10-11T1600Z](https://github.com/popcre/ai-devops/blob/main/tests/verification/reviewer-scoped-ci/2026-10-11T1600Z/after.md): 31/60 -> 27/60 select-all.
- DeepSeek diff-review APPROVE on the exact head; merged through the full merge-queue run (Step 5 safety net proven).

## 3. Remaining
- Step 6 live proof: the next real PR that changes only a reviewer door/mapped reviewer file. Open its `linux-offline-shard` logs; the selected suite list must be the narrowed one (e.g. DeepSeek door = 7 suites), not 145. Then tick `- [ ] live proof` on #1563, set plan STATUS row 6 to done, update the [plan index](https://github.com/popcre/ai-devops/blob/main/docs/implementation-plan-index.md) row, delete this file, close #1563.
- Do NOT manufacture a throwaway PR just for proof unless none arrives; if one is needed, a one-line comment edit in `tools/lib/review-doors/deepseek.sh` suffices.

## 4. Deliberately left select-all (do not "fix" without proof)
`tools/reviewer_admission.py`, `tools/reviewer_event_guard.sh`, `tools/reviewer_events.py`, `tools/lib/review-operation.sh`: consumed by `bin/ai-review` / `bin/ai-review-pool`, which have no dedicated suite. `tools/lib/task-gates.sh`, `session-tmp.sh`, `local-watch.sh`: shared beyond reviewers. Further gains belong under [#650](https://github.com/popcre/ai-devops/issues/650).

## 5. Tried and rejected
Transitive consumer search by bare basename exploded (e.g. `ai-review` matches everything); mapping uses direct consumers plus the doors config's test references instead.

## 6. Verify
`bash tests/test-test-selection.sh`; `bash tools/ci/measure-selection.sh 60`.
