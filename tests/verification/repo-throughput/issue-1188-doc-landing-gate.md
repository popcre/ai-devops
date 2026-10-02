# Doc-only landing jam — diagnosis and gate (#1188)

Owner issue: [#1188](https://github.com/popcre/ai-devops/issues/1188).
Recorded: 2026-09-30, edge-dev worktree `C:/repos/ai-devops-1188-docjam`.

## The three jams (all reproduced from PR evidence)

| Jam | Defect that landed | Check that fired later | Unblock PRs |
|---|---|---|---|
| 1 | Private-network addresses in Step 9 fleet re-adopt records and a handoff (landed via #1160/#1161) | `linux-offline-shard (3)` → `bin/ai-public-boundary-check` | #1171 |
| 2 | Plan link with four `../` where three are needed (landed via #1158) | `linux-offline-shard (2)` → `tools/check-markdown-links.py` | #1162, duplicated by #1174 |
| 3 | LAN address reintroduced by the #1178 handoff | `linux-offline-shard` → boundary | #1180 |

## Root cause

Two independent holes, both verified in the tree at `3459c32d`:

1. The prose bypass (`tools/lib/task-gates.sh`, narrow prose list) makes a
   prose-only pull request `run_long=false`, so the pull-request lane skips
   every offline suite — including the only two checks whose input a prose
   change controls. The immediate `gh pr merge --squash --admin` lane then
   merges without waiting for anything.
2. Even in a mixed (non-prose) pull request, `selection_path_is_prose` in
   `tests/lib-selection.sh` makes prose paths select no suite, so a doc defect
   riding a code change is also invisible on the pull-request lane.

The defect therefore lands green and is discovered only by the next full
merge-group run (the queue keeps the complete inventory), which is exactly the
jam: an unrelated pull request fails, and a manual doc-only unblock PR is
needed. The #1077 14d/30d measurement window has produced only its 2026-09-30
baseline (first checkpoint due 2026-10-14) and measures shared-db issue flow,
not this class, so it could not arbitrate this fix.

## The fix (both layers, #1073 untouched)

- **CI layer.** `verify.yml` gains an unconditional `doc-safety` job (no `if:`,
  no path filter, runs on every event) executing `tests/test-public-boundary.sh`
  and `tests/test-markdown-links.sh`. `verification-closure` — the single
  required context, kept unfiltered per #1073 — now depends on it and passes
  its result to `tools/ci/verify-closure.sh`, which fails closed on anything
  but success for every event, prose-only included. This strengthens closure;
  no lane lost a check, and no required context gained a path filter.
- **Immediate-lane layer.** `bin/ai-doc-safety` runs both whole-repo invariants
  offline on one tree. `bin/ai-pr-wait` runs it on the caller's worktree before
  offering the prose shortcut: pass → the immediate squash-admin advice stands;
  fail → the refusal names the offending file and withholds the shortcut.
  Documented in `AGENTS.md` (Editing and delivery).

## Local verification (edge-dev, Git Bash)

- `tests/test-ai-doc-safety.sh` — new suite, 9/9: clean tree passes; the
  #1171/#1180 topology fixture and the #1174/#1162 link-depth fixture each
  fail with the invariant named; default tree is the invoking repository;
  usage errors exit 2; this repository passes its own gate.
- `tests/test-verify-closure.sh` — 42 checks including six new
  `closure_doc_safety_required` cases (failure/skip/cancel/missing/malformed
  rejected on both events; green doc lane closes a prose-only pull request).
- `tests/test-workflow-policy.sh` — PASS including five new doc-safety pins
  (job exists; unconditional; runs both suites; Blacksmith Linux pool;
  closure evaluates the result) and the updated closure `needs:` pin.
- `tests/test-ai-pr-wait.sh` — 50 passed, 2 failed; the same two
  (`a fast successful request returns without an orphan timer`,
  `a nonzero upstream page with usable rateLimit still records its cost`)
  fail identically on pristine `origin/main` (f6463379) — environmental,
  not caused by this change. The four new prose-path checks pass.
- `tests/test-ci-suite-loader.sh` 17/0; `tests/test-all.sh --list` discovers
  `test-ai-doc-safety.sh`; balanced 4-section partition still reconstitutes
  every suite exactly once; `tools/ci-suites/load-manifest` equality holds;
  `python3 tools/ci/check-managed-github-transport.py .` PASS after the
  ai-pr-wait guidance strings were added to its exact-string allowlist.

Exact-head GitHub verification remains the merge-time gate.
