# Plan: self-clearing stuck locks and a live-settings drift check

Handoff registration: [HANDOFF.d/2026-09-28T1755Z-edge-dev3-claude-plans-manifest-and-self-healing.md](HANDOFF.d/2026-09-28T1755Z-edge-dev3-claude-plans-manifest-and-self-healing.md)
Owner issue: https://github.com/popcre/ai-devops/issues/1002.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Lock inventory | ✅ done (2026-09-28) | `docs/locks.md` covers every hit of `grep -rnE 'flock|lock\.d|\.lock' bin` (62 pre-change; 87 after step 2, all re-cited); `docs/task-router.md` router row added |
| 2 Stale-holder recovery for flock locks | ✅ done (2026-09-28, Linux CI proof pending merge) | `bin/ai-lock-doctor` + wiring at all 5 flock sites; Windows `lock_acquire` pid+age reclaim; `tests/test-ai-lock-doctor.sh` portable cases green locally; /proc cases prove on the Linux CI lane |
| 3 Settings snapshot + drift check | ✅ done (2026-09-28) | `config/merge-queue-expected.json` + `bin/ai-merge-queue-drift`; passes against the live ruleset (read via ai-gh) and `tests/test-ai-merge-queue-drift.sh` proves renamed-job, paths-filter, .ps1-divergence, and clean-pass cases |
| 4 Scheduled drift check + alert | ✅ done (2026-09-28, dispatch proof in Step 5) | `.github/workflows/merge-queue-drift.yml`: daily cron + PR-path trigger + standing-issue alert job |
| 5 Live proof | ⬜ open | — |

A fresh session starts at Step 1.

## 1. Ultimate goal

Two failures on 2026-09-28 each froze work for more than an hour until a session noticed
them and wrote a fix:
- a reviewer credential lock jammed, stopping Qwen reviews for about 2 hours;
- the tools' idea of what the merge queue runs differed from what it really runs, which
  ejected PRs repeatedly for about 3.6 hours.

The goal: **a stuck lock clears itself safely within minutes, and a mismatch between the
tools and GitHub's live settings is caught and reported automatically**, before anyone
waits an hour.

If a step conflicts with this goal, the goal wins — stop and flag it on the owner issue.
Safety outranks speed: never kill or delete a lock that a live process still holds.

## 2. What this application is

`popcre/ai-devops` (branch `main`, protected, merge queue; the only required check is
`verification-closure`) holds Albert's shared AI tooling. Reviewer wrappers live in
`bin/`: `ai-qwen`, `ai-muse`, `ai-deepseek-agent` and others. Credentials come from
1Password via `op`. It runs on edge-dev3 (Linux), edge-dev (Windows) and hetz (Linux).

## 3. Trigger

- **#940, "Qwen refresh-lock repair and live recovery"** (06:20Z–08:27Z 2026-09-28). The
  Linux lock `$CFG_DIR/op-refresh.lock` is taken by `flock` at `bin/setup-secrets.sh:283`
  and `:317`, and at `bin/ai-qwen:428`. A child `op` process inherited the lock's file
  descriptor. The issue's evidence: "lock inode 102105116 is held by reported PID 3663783
  in /proc/locks while that /proc PID is absent". PR #939 fixed the cause by adding
  `flock --close`.
- **#913, "Prevent PowerShell-only changes from ejecting merge queue"** (03:05Z–06:41Z).
  PR test selection skipped the ASCII guard for `.ps1` edits, but the merge-queue run
  executed it, so PRs were ejected repeatedly. PR #905 (`cede8ea`) fixed it. A related
  drift was also found in `docs/context-engineering.md` (commit `35217a9`).

## 4. Scope

In scope:
- Stale-holder detection and recovery for every lock in `bin/`.
- A committed snapshot of the live merge-queue ruleset.
- A drift check that compares the tools' expectations with the live ruleset and with the
  merge-queue job's actual check set.

NOT in this plan:
- Changing the ruleset itself. Any ruleset change needs Albert's approval.
- Re-fixing #939 or #905, which are merged.
- 1Password token rotation.
- shared-db's own merge-queue tooling.

## 5. Current state

- Linux `flock` paths wait 90–120s and then fail. They have no staleness logic.
- The Windows `mkdir` lock (`lock_acquire`, `bin/ai-qwen:527+`) checks the owner's pid and
  age. It shares Muse's `credential.lock.d` (`bin/ai-qwen:366-388`,
  `bin/ai-deepseek-agent:322`, busy error at `:368`) but never reclaims Muse's lock.
- `config/repository-policy.json` has no merge-queue or required-check fields. Nothing
  compares the tools with the live ruleset 21564317.
- Existing drift tools can serve as patterns: `bin/ai-reviewer-membership-drift`,
  `bin/check-mcp-drift.ps1`, `bin/ai-machine-tools-doctor` and
  `tests/test-workflow-policy.sh`. `bin/ai-devops-doctor` does not exist.

## 6. Key findings

- A `flock` lock is released by the kernel when every holder's descriptor closes. Its
  "stuck" form is therefore a live but unrelated holder (an inherited descriptor), never a
  dead one. Recovery means finding the holder via `/proc/locks` and `/proc/*/fd`, then
  checking that the holder is not one of our tools.
- In #940 the pid reported by `/proc/locks` was absent from `/proc`. That happens when the
  holder runs in another pid namespace or has already exited while the descriptor lives
  on in a sibling. The check must scan every process's fds for the lock's inode, not trust
  the pid alone.
- In the merge-queue mismatch, the tools selected tests one way and the queue selected
  them another way. The fix is to run the queue's exact test-selection logic for a
  synthetic diff of each file type and compare it with the PR path. `tests/lib-selection.sh`
  is the shared selector.

## 7. Rejected approaches

- **Deleting lock files by age.** Unsafe with `flock`: deleting the file while a holder
  exists lets two processes "hold" different inodes. The #940 evidence line says "do not
  delete file or kill unknown holder".
- **Killing any process that holds the lock.** It could kill a real 1Password read
  mid-write, so only our own tools' processes may be killed.
- **Polling the ruleset every few minutes.** That wastes GitHub quota, and a GitHub rate
  limit was just fixed (PR #999). Check once a day, and on PRs that edit
  workflows or selection.

## 8. Decisions

- LOCKED: `flock` recovery is non-destructive. When the holder is not an ai-devops
  process, report it with the full evidence line and fail loudly; never kill it.
- LOCKED: the ruleset snapshot lives in `config/merge-queue-expected.json`, and a change to
  it goes through a PR.
- OPEN: the alert channel for scheduled drift. Default: comment on one standing issue in
  popcre/ai-devops, the same pattern as the BlockerWatch digest.

## 9. Steps

1. **Lock inventory.** Grep `bin/` for `flock`, `mkdir .*lock`, `.lock` and `lock.d`, and
   write `docs/locks.md` with a table: path, acquire and release lines, platform, and
   current staleness handling. Gate: the table lists every hit from
   `grep -rnE 'flock|lock\.d|\.lock' bin`.
2. **Recovery helper.** Add `bin/ai-lock-doctor <lockfile>` (Bash, Linux). It reads the
   lock's inode, scans `/proc/*/fd` for holders, and classifies each as `our-tool`
   (command line under this repo's `bin/` or `op` spawned by one), `foreign`, or `none`.
   With `--recover`, it sends TERM and then KILL only to `our-tool` holders older than the
   lock's timeout. Wire it into the timeout branch of every `flock` site from Step 1, and
   extend the Windows `lock_acquire` to reclaim Muse's lock under the same pid+age rule.
   Gate: the Step 5 tests pass, and a manual reproduction (hold the lock with
   `flock file sleep 600 &` started from a script under `bin/`) recovers in under 2 minutes.
3. **Settings snapshot and drift check.** Add `config/merge-queue-expected.json` (required
   check names, `merge_group` workflows, and the ruleset merge-queue parameters) and
   `bin/ai-merge-queue-drift`. The script:
   (a) reads `gh api repos/popcre/ai-devops/rulesets/21564317` and diffs it against the
   snapshot;
   (b) checks that every required check name is produced by a job in a workflow that
   subscribes to `merge_group` and has no `paths:` filter or `if:` skip;
   (c) for each file class (`.sh`, `.ps1`, `.md`, `.json`, `.yml`), runs
   `tests/lib-selection.sh` in PR mode and in merge-group mode and fails if they differ.
   Gate: it passes on current `main`, and it fails on a branch that renames a required job.
4. **Schedule.** Run the drift check daily from `.github/workflows/`, and on PRs touching
   `.github/workflows/**`, `tests/lib-selection.sh` or the snapshot. On failure, comment
   on the standing issue. Gate: a manual `workflow_dispatch` run posts nothing when clean,
   and posts one comment on a seeded mismatch.
5. **Live proof.** Reproduce both incidents on a throwaway branch or local lock and record
   them in `tests/verification/self-healing/2026-MM-DD.md`. Gate: the file cites run ids.

## 10. Tests

- New `tests/test-ai-lock-doctor.sh` covers five cases:
  - a live our-tool holder is recovered;
  - a foreign holder is reported and not killed;
  - no holder means nothing to do;
  - an inherited descriptor in a child is found by inode;
  - a lock under its timeout is left alone.
- New `tests/test-ai-merge-queue-drift.sh` covers four cases: a renamed required check, a
  required job with a `paths:` filter, a selection divergence for `.ps1`, and a clean
  pass. Use fixture ruleset JSON with no network.
- New suites also need per-suite entries in `config/ci-suite-manifest.json`, or in the
  split files if that plan landed first.
- `tests/test-ai-qwen.sh` and `tests/test-mcp-launch-lock.sh` must stay green.

## 11. Constraints

- Never push to `main`. Use a PR and the merge queue.
- Never change the ruleset without Albert naming it.
- GitHub calls go through `bin/ai-gh`.
- Do not touch the secrets values path. Pipes only.
- Tests must be offline.

## 12. Access

- `gh` is authenticated as `u2giants` (admin, able to read rulesets).
- 1Password vault `vibe_coding` is not needed.
- Linux work runs on edge-dev3, and the Windows lock path is tested on edge-dev.

## 13. Done, risks, open questions

Done means all of the following:
- Steps 1–5 are ticked with artifacts.
- PRs are merged and CI is green.
- The daily workflow has a clean run id recorded.
- The issue is closed.

Risks and open questions:
- **Killing the wrong process.** Mitigated by the our-tool classification; Rollback is
  to remove `--recover` from the call sites.
- **Unknown lock sites.** Step 1 may find more locks than expected. Split them if there
  are more than 8.

## Self-audit

1. A fresh session can execute this without questions. Evidence: §3 gives the exact
   incidents and lines, and every step in §9 has a gate.
2. All known background is carried: the pid-absent finding (§6) and the rejected
   approaches (§7).
3. The goal (§1) is enough to judge a wrong step: safety over speed, and never kill a
   foreign holder.
