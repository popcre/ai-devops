# CI suite manifest split — implementation evidence (2026-09-28)

Owner issue: [#1001](https://github.com/popcre/ai-devops/issues/1001). Plan:
`plan_split-ci-suite-manifest.md` Steps 1–4. Collision proof:
[manifest-collision-2026-09.md](manifest-collision-2026-09.md).

## What changed

- `tools/ci-suites/load-manifest` (+ `load-manifest.jq`): assembles the legacy
  reader-shaped manifest (schema_version 2 contract) from the slim global file
  plus one JSON file per suite in `config/ci-suites/`. Fails closed naming the
  offending file on: malformed JSON, unknown kind, duplicate membership tags,
  reviewer-safety without offline, non-integer or bash-only `linux_seconds`,
  out-of-range `windows_section`, a section-less offline suite when sections
  are declared, and an empty declared section (other than the PowerShell
  owner).
- `config/ci-suites/<suite-file-name>.json`: 132 files generated 1:1 from the
  monolith (104 bash, 27 powershell, plus the new loader suite). Each holds
  `kind`, optional `linux_seconds`, `windows` membership tags, optional
  `windows_section`.
- `config/ci-suite-manifest.json` (schema_version 3) now carries only:
  `windows_offline_section_count`, `windows_offline_powershell_shard`,
  `suspended_bash`, `suspended_powershell`, `_comment_suspended`,
  `affected_suite_rules`. A policy check rejects any reintroduced per-suite
  array or map there and is proven on a mutated copy.
- Readers switched: `tests/test-all.sh` (cached loader snapshot for
  inventories/seconds/membership/sections; `suspended_bash` still read from the
  global file), `tests/test-workflow-policy.sh` (pins loader output),
  `tests/test-all.ps1` (a Bash suite's own `.sh.json` no longer forces the
  PowerShell run; the global file or a `.ps1.json` still does).
- `config/ci-suites/**` and `tools/ci-suites/*` added to the select-all globs
  and `config/reviewer-ci-paths.txt`; both trees pinned `eol=lf`.

## Gates and local results (2026-09-28, edge-dev worktree)

- Step 1/2 equality gate: `bash tools/ci-suites/load-manifest | jq -S .`
  equals `jq -S 'del(.windows_offline_section_count)'
  config/ci-suite-manifest.json` byte for byte, re-verified after migration
  and after registering the new loader suite (the one added global key is the
  section count the loader derives sections from).
- Step 3 membership gate: Windows sections 1–6 listed via
  `tests/test-all.sh --windows-offline --exclude-reviewer-safety --shard i/6
  --list` are identical to `git show 7f4a5f3d:config/ci-suite-manifest.json`
  shard arrays (diff empty after CR normalization; only intra-section run
  order is now canonical).
- Suites on this tree: `tests/test-workflow-policy.sh` PASS (incl. new
  slim-manifest checks); `tests/test-ci-suite-loader.sh` 17 passed, 0 failed;
  `tests/test-linux-offline-shards.sh` 27 passed; `tests/test-windows-bash-selection.sh`
  48 passed; `tests/test-test-selection.sh` 21 selected, 0 failures;
  `tests/test-reviewer-ci-paths.sh` PASS (48 dependencies).
- PowerShell platform gating proved per path class: `config/ci-suites/x.sh.json`
  skips the PowerShell run; `x.ps1.json` and the global manifest force it.

Exact-head GitHub verification and the Step 5 parallel-merge proof remain the
merge-time gates.

---

# Step 5 live proof — two trivial-suite PRs in one queue batch (2026-09-30)

Owner issue: [#1023](https://github.com/popcre/ai-devops/issues/1023). Plan:
`plan_split-ci-suite-manifest.md` Step 5.

## Method

Two throwaway pull requests each add exactly one trivial always-pass Bash suite
(its own `tests/test-queue-batch-<x>.sh`) and its own per-suite manifest entry
(its own `config/ci-suites/test-queue-batch-<x>.sh.json`,
`{"kind":"bash","linux_seconds":1}`); the two PRs share no file. After both
PRs' pull-request checks are green, both are added to the merge queue seconds
apart. The proof is the queue timeline: both entries must leave the queue by
MERGING — in one batch (one chained pair of merge-group runs), with no
`Merge remote-tracking branch 'origin/main'` commit ever added to either
branch.

## The two pull requests

- **#1175** — branch `zcode/1023-batch-a2`, one commit `3196b77e`
  "ci(#1023): add trivial suite A for the one-batch merge proof"; files:
  `config/ci-suites/test-queue-batch-a.sh.json`, `tests/test-queue-batch-a.sh`.
- **#1176** — branch `zcode/1023-batch-b2`, one commit `1b55395c`
  "ci(#1023): add trivial suite B for the one-batch merge proof"; files:
  `config/ci-suites/test-queue-batch-b.sh.json`, `tests/test-queue-batch-b.sh`.

Both branches were cut from the same repaired `main` (`0ec6cdcc`). Pre-split,
each of these was a one-line edit to the shared `config/ci-suite-manifest.json`
— the exact shape that forced #721 into two ejections and 78 minutes of queue
time (see the collision record).

## Timeline (all times UTC; EDT = UTC−4)

| Time (UTC) | Event |
|---|---|
| 14:14:26 / 14:14:41 | The two `gh pr merge --squash` enqueue commands run back-to-back |
| 14:14:40 | `AddedToMergeQueueEvent` #1175 (queue position 1, `AWAITING_CHECKS`) |
| 14:14:42 | `AddedToMergeQueueEvent` #1176 (queue position 2, `AWAITING_CHECKS`) |
| 14:14:59 | merge-group run [36727672299](https://github.com/popcre/ai-devops/actions/runs/36727672299) starts on `gh-readonly-queue/main/pr-1175-6c0683fa…` → success |
| 14:15:01 | merge-group run [36727675394](https://github.com/popcre/ai-devops/actions/runs/36727675394) starts on `gh-readonly-queue/main/pr-1176-6e517722…` → success |
| 14:23:58 | `RemovedFromMergeQueueEvent` on BOTH, reason **`merged`** (no ejection of either) |
| 14:23:59 | `MergedEvent` on BOTH: #1175 → `6e517722`, #1176 → `65377fc3`, both onto `main` in the same second |

## Batch evidence

The two merge-group runs are one chained batch, not two serialized batches:

- Run 36727675394's queue ref embeds `6e517722` — the commit #1175 landed on
  `main` with. Entry 2 was validated on a batch branch that already contained
  entry 1's merge result; the queue then atomically landed both PRs in the
  same second (both `RemovedFromMergeQueueEvent` reason `merged` at 14:23:58,
  both `MergedEvent` at 14:23:59).
- Both entries were in the queue simultaneously for their entire stay
  (14:14:40 → 14:23:58), ~9 minutes — one full queue cycle, not two.
- A foreign PR (#1177) had landed on `main` at 13:53:45, before the batch was
  built (the batch base `6c0683fa` is #1177's merge commit). Neither proof PR
  had to react to that landing: no refresh, no new PR run, no re-enqueue.

## No-refresh evidence

- PR #1175 `commits`: exactly one, `3196b77e` (the suite commit).
- PR #1176 `commits`: exactly one, `1b55395c` (the suite commit).
- Neither branch contains any `Merge remote-tracking branch 'origin/main'`
  commit; neither PR was removed from the queue for any reason other than
  `merged`.

## Gate verdict

**Step 5 gate met.** Two per-suite PRs that share no file entered the merge
queue together and merged in one queue batch, each still exactly one commit
old, with no main-refresh commit on either branch — the serialization the
split was built to remove (#1001) is gone for this shape. Both throwaway
suites are retired by this evidence PR.

## Repairs made before the proof could run (recorded honestly)

The first proof attempt (2026-09-30 ~8:15 AM EDT) could not go green because
`origin/main` itself carried two violations that only full-CI pull requests
execute — the doc-only PRs that introduced them skipped these whole-repo
suites, which is how they landed unnoticed:

1. `linux-offline-shard (3)` failed `test-public-boundary.sh`: the Step 9
   fleet re-adopt records (#1160/#1161) and an open handoff carried literal
   private-network addresses. Fixed by redaction PR **#1171** (merged
   `87306bbf`, 2026-09-30 8:42 AM EDT).
2. `linux-offline-shard (2)` failed `test-markdown-links.sh` on an
   escaping-repository link in
   `tests/verification/shared-db-coordination-deletion/2026-09-30T045654Z.md`
   (#1158). Fixed by **#1174** (merged `0ec6cdcc`, 2026-09-30 9:45 AM EDT),
   applying the identical one-line change already open in #1162; #1162 then
   merged conflict-free (`f90af5df`, 9:44 AM EDT) once its owner enqueued it.

Both proof branches were rebuilt as fresh single commits on the repaired
`main` before the proof run (first-attempt PRs #1164/#1165 closed as
superseded; their failure was main's, not the suites'). One transient flake
(`test-ai-memory-sync.sh` "private hub proof altered the repository") failed
one shard of #1175's first PR run and passed on the failed-jobs rerun;
#1176's identical run was green throughout.

Posted by ZCode chat unknown on edge-dev
