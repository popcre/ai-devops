# CI suite manifest collision proof — 2026-09-21..28

Owner issue: [#1001](https://github.com/popcre/ai-devops/issues/1001). Plan: `plan_split-ci-suite-manifest.md` Step 0.

## Method

`git log origin/main --since=2026-09-21 --until=2026-09-29 --name-only -- config/ci-suite-manifest.json`
found 21 commits on `main` touching the shared manifest, one per merged PR: #666,
#679, #687, #692, #718, #721, #740, #763, #790, #797, #819, #820, #823, #846,
#849, #855, #857, #935, #944, #950, #979. For each PR the branch commit list was
read for `Merge remote-tracking branch 'origin/main'` refresh commits, and the
GraphQL timeline (`AddedToMergeQueueEvent` / `RemovedFromMergeQueueEvent` /
`MergedEvent`) was read for queue removals before the merge. Every refresh merge
commit was then inspected locally: merge base vs each parent vs merge result for
`config/ci-suite-manifest.json`, using `git diff-tree -r` blob IDs.

## Result per PR

- Refresh commits into the head branch: #666 (e70bec46, 58169cf3 — later ones on
  resume branches), #692 (d57f7e81, d9e2ee0c), #721 (a3cc4ed7), #846 (f0b1feb1),
  #849 (d36e7f2e, 0e2f8169), #944 (ffeaffb2). All other manifest PRs: none.
- Queue removals before merge (removal timestamp != merge timestamp): #721 twice
  (added 02:56:24Z removed 03:02:35Z; added 03:20:35Z removed 03:26:53Z; merged
  04:14:10Z — 78 minutes from first add to merge), #944 once (added 12:02:08Z
  removed 12:09:30Z, re-added 12:14:40Z, merged 12:22:42Z). All other manifest
  PRs left the queue only at merge time (normal exit).

## Proven manifest conflicts in refresh merges

Two refresh merges had BOTH sides editing the manifest from the merge base, and
a merge result differing from both parents — a textual conflict resolved by hand
in the branch:

- **PR #721 (MiMo client parity), merge a3cc4ed7 (2026-09-24):** base blob
  `3b83a2a3`, main parent `483d4583` → `ea398a53`, branch parent `56d74b9f` →
  `e0b2cd07`, merge result `5526d388`. The branch then re-entered the merge
  queue and paid two full queue cycles (see removals above).
- **PR #849 (StepFun reviewer), merge d36e7f2e (2026-09-25):** base blob
  `20530710`, main parent → `9fc9dba0`, branch parent → `825c70ab`, merge result
  `98714e2a`.

The remaining refresh merges (e70bec46, 58169cf3, d57f7e81, d9e2ee0c, f0b1feb1,
0e2f8169, ffeaffb2) show the manifest changed on at most one side (plain sync).

## Ejection attribution (recorded honestly)

- PR #944's ejection: merge-group run
  [36419283664](https://github.com/popcre/ai-devops/actions/runs/36419283664)
  (12:02:28Z) failed `linux-offline-shard (1)` on
  `test-public-boundary.sh` ("protected private-network topology found") — not a
  manifest check.
- PR #721's ejections: batch runs with #719
  ([35949368146](https://github.com/popcre/ai-devops/actions/runs/35949368146),
  [35951068106](https://github.com/popcre/ai-devops/actions/runs/35951068106))
  failed a shard-4 suite and `merge-group-evidence`; the archived logs show no
  failing manifest-related check line. The observed queue ejections are therefore
  NOT attributed to the manifest.

## Gate verdict

Step 0 gate ("at least two PRs delayed by manifest refreshes or ejections") is
met by refreshes alone: #721 and #849 each carried a hand-resolved textual
conflict in `config/ci-suite-manifest.json` during a main refresh, and each
refresh restarts the full PR verification cycle (~20–40 minutes) before the PR
can re-enter the merge queue. With 21 PRs editing the file in seven days, the
same-file conflict window is continuous.

Collected 2026-09-28 via `bin/ai-gh` and local `git diff-tree` forensics in the
zcode-1001-split-manifest worktree.
