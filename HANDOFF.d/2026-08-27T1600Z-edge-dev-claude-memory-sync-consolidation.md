---
issue: none
status: OPEN
owner: claude/memory-consolidation-fix
---

# HANDOFF — Portable memory: duplicate storm repaired, sync made once-a-day, two PRs waiting on the merge queue (2026-08-27 16:00 UTC, edge-dev/claude)

- **Status:** OPEN only because two pull requests have not finished merging.
  All code, tests, docs and the live memory hub are already done and verified.
- **Written:** 2026-08-27 (UTC) on `edge-dev` by Claude (Opus 5), branches
  `claude/memory-consolidation-fix` (PR 126) and `claude/memory-sync-docs`
  (PR 135), base `origin/main`.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**BLOCKING** — none.

**RECOVERABLE:**

1. **The main checkout `C:\repos\ai-devops` (not this worktree) is behind
   `origin/main` and holds another session's eight uncommitted files.** This
   session deliberately did not touch it. Someone must decide whether that work
   is still wanted before that checkout can be fast-forwarded. *Recommendation:
   ask Albert whose session that is, then let that session finish.*

## 1. What this application is

`popcre/ai-devops` is the public toolkit that installs Albert's agent
configuration on every machine. Two scripts in it own portable memory:
`bin/ai-sync-memory` (the inner pull/push/forget tool) and `bin/ai-memory-sync`
(the transactional parent that fetches the hub, unions, secret-scans, gates on
health, commits and pushes). The memory itself lives in the **private**
`u2giants/ai-devops-memory` repository — a separate repo that takes direct
pushes to `main` with no PR and no CI. Facts live per project under
`~/.claude/projects/<slug>/memory/`, each project with a `MEMORY.md` index that
is loaded into every session, plus one file per fact.

## 2. What we set out to do this session, and why

Albert asked for a dotfiles sync. It failed its memory health gate, and chasing
that opened four further pieces of work he then authorized: consolidate the
oversized indexes and publish, explain and fix why the sync had gone from ~30
seconds to minutes, clear the phantom "projects" that had accumulated in the
hub, and add trend reporting to the weekly audit.

## 3. Current state — what is true right now

Done and verified:

- **Duplicate storm fixed and published.** The hub index merge now keeps the
  first occurrence of each entry line. Shipped in PR 121, merged as `f3a94a2`.
  `shared-db` went 19.9 MB to 37 KB, `licensor-source-data` 4.9 MB to clean.
- **Indexes consolidated.** 506 tombstones plus five index prunes; the hub went
  953 to 447 files and health findings 9 to 0. Published at `cf36745`.
- **Phantom projects cleared.** 62 throwaway paths removed; hub project folders
  90 to 28. Published at `0fa212b`.
- **The dotfiles sync is fast again** on this machine: 3m10s total, of which
  memory was 2m18s; with the once-a-day gate a routine sync is about 50s.
- **The audit reports its trend.** `tests/test-ai-memory-health.sh` is 27
  passed / 0 failed.

Not done:

- **PR 126** (`7065e4d`, `ea6f953`, `3c32eb9`, `0c31823`, `b7ccd1d`) — the
  superset union, `forget --batch` and `--prune-index`, forget-now-publishes,
  `sync-if-stale`, the disposable-project filter, and the audit trend. All
  three checks pass; it is sitting in the merge queue.
- **PR 135** — the docs for all of the above (the `docs/configuration.md`
  environment table and two new `docs/design-decisions.md` entries). Opened,
  not yet queued.

Until both merge, **only edge-dev runs any of this.** Every other machine still
forks a memory on any edit and still pays the full round trip on every sync.

## 4. Everything we tried that did NOT work

- **Deduping the machine's own index by hand.** Undone by the next pull: the
  merge preserves the hub index byte-for-byte, so the repair had to live in the
  tool.
- **Scoring consolidation candidates by "most subsets".** It picked a variant of
  `op-account-migration-2026-07` that had lost a 16-line vault/UUID remap block.
  Selection was changed to the maximal line-set and the ten remaining groups
  were checked by hand.
- **`forget` one file at a time.** Each call is a full transaction, and a failed
  health gate keeps none of them — unusable for 506 files. Hence `--batch`.
- **Patching the shell scripts with Python using ordinary strings.** The files
  contain a literal backslash-n, so anchors must be raw strings; a first attempt
  also wrote a real CR byte into an awk program and failed the build.
- **Deleting the bare `-` project folder as junk.** A `basename` error on the
  root path made it look empty; it holds real memories. It is now excluded
  explicitly.
- **Blocking ten-minute polls waiting on CI.** Five of them timed out and read
  as failures in Albert's transcript. Replaced with one background job.

## 5. Root causes and key findings

- The union could only ever **fork** a memory, never update one. Every ordinary
  edit on a second machine produced a `--<label>.md` copy, each adding an index
  line, and because the merge appended entries that were already present the
  indexes filled with exact duplicates until they broke the health gate.
- Nothing ever filtered which project folders were publishable, so worktrees,
  scratchpads and temp directories became permanent "memory projects".
- The 30-second sync became a multi-minute one when memory joined it. The data
  changes a few times a week, so paying the round trip every sync bought
  nothing.
- **This repo has no housekeeping process for the memory hub.** The weekly
  health audit reports but cannot repair, and nothing was watching growth. The
  trend line added this session is the first early warning.

## 6. Exact next steps

1. Confirm both PRs merged: `gh pr view 126 --repo popcre/ai-devops --json state`
   and the same for 135. If either is open with green checks, run
   `gh pr merge <n> --repo popcre/ai-devops --squash`.
2. On every other machine, run `ai-adopt-globals` (or a dotfiles sync) so it
   picks up the new scripts.
3. Verify on a second machine: edit one memory, sync, and confirm no
   `--<label>.md` copy appears in the hub.
4. Delete this file once step 3 passes.

## 7. Constraints and gotchas in force

- **Never delete a memory file with `rm`** — the next pull resurrects it. Use
  `forget`, which writes a tombstone into the project's `.forgotten` file.
- **The health gate exits 1 on any finding.** Limits are 200 index lines and
  12288 bytes per index.
- **Shell scripts must be committed LF-only**, and a raw CR byte inside an awk
  program fails the build too — write it as the escape, not the byte.
- **`bin/install-machine-tools.ps1` refuses to run from a linked worktree**, so
  `ai-adopt-globals` cannot be run from one.
- The merge queue re-runs all three verify jobs after the PR's own checks pass,
  so a merge takes roughly two hours. `windows-offline` alone is about 65
  minutes. Some reviewer tests are known-flaky; `main` itself was red on three
  of its last four pushes.
- Albert does not merge. The session that opens a PR merges it.

## 8. Access and environment

Work happened in the worktree
`C:\repos\ai-devops\.claude\worktrees\cleanup-worktree-c942a7` on `edge-dev`,
Git Bash. The hub clone lives under the user cache as
`ai-devops-memory-private`. New settings: `AI_MEMORY_STAMP`,
`AI_MEMORY_MAX_AGE_HOURS` (default 24) and `AI_MEMORY_HEALTH_STATE`. No
credentials were handled this session.

## 9. Open questions and risks

- **No automated housekeeping still.** Growth is now visible in the weekly
  audit, but nothing prunes. If indexes creep back over the limits the gate will
  block the fleet again and someone must consolidate by hand.
- **The disposable-project filter is a name-pattern list.** A future throwaway
  path that does not match one of those patterns will be published again.
- **Only one machine has been proven.** The superset union has unit coverage but
  has not yet been exercised between two real machines.
