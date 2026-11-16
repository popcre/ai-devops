# Plan: ghost-run escape for popcre/ai-devops (LANE_EPOCH)

Handoff: [HANDOFF.d/2026-11-16T2041Z-edge-dev3-claude-ghost-run-epoch-plan.md](HANDOFF.d/2026-11-16T2041Z-edge-dev3-claude-ghost-run-epoch-plan.md) · Umbrella issue: popcre/ai-devops#2367 · Source of the
design: popcre/shared-db#6426 (PRs popcre/shared-db#6427, #6434).

## STATUS (read first — do not re-plan)

| # | Step | State | Evidence |
|---|------|-------|----------|
| 1 | Suffix every concurrency group with LANE_EPOCH | ⬜ open | — |
| 2 | Guard test pinning the suffix | ⬜ open | — |
| 3 | Sweep "unreapable" message names the escape | ⬜ open | — |
| 4 | Runbook `docs/ghost-run-escape.md` | ⬜ open | — |
| 5 | PR, merge, post-merge live proof | ⬜ open | — |

Fresh session starts at step 1. Written 2026-11-16 3:50 PM EST.

## 1. Ultimate goal

When GitHub glitches and leaves a "ghost" run behind, it must never again be
able to freeze a check in this repository until GitHub Support answers. Any
AI session must be able to unblock the frozen check itself in minutes, safely.
**If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is Albert's (POP Creations) public toolkit repo: global AI
instructions, skills, `bin/` helpers, CI tooling under `tools/ci/`, tests under
`tests/` (Bash suites run by `tests/test-all.sh`, which runs every
`tests/test-*.sh`). CI = GitHub Actions in `.github/workflows/` (18 files),
main is protected and uses a merge queue (`merge_group`). Nothing deploys from
this plan; it changes CI configuration only.

## 3. What triggered this work

On 2026-11-11 20:22 UTC GitHub had a dispatch failure that left ghost run
records: the runs list shows them `queued` forever with zero jobs; GET/DELETE
`/actions/runs/{id}` return 404/403; cancel is refused ("already completed").
A ghost still holds its workflow's `concurrency` group, so every later run in
that group waits forever. Same event 2026-10-06. In ai-devops the ghosts are
runs 43098438008 (ai-review) and 43098438147 (verify) on branch
`fix/gates-dochealth-signature`; Albert asked GitHub Support to purge them
(ticket 4997919, reply sent 2026-11-16). In popcre/shared-db the same fix was
built and landed 2026-11-15 (#6427/#6434); this plan ports the missing parts.

## 4. Scope

In: the four changes in §9 for ai-devops only.
NOT in this plan: changing the existing ghost sweeper's reap logic or its
30-minute floor; removing or re-keying any concurrency group; cancel-in-progress
changes; the two remaining ghosts (Support owns them); other repos; other
#2367 phases.

## 5. Current state of the code (origin/main, 2026-11-16)

- Already done: ghost sweeper `tools/ci/ghost-run-sweep.mjs` +
  `.github/workflows/ghost-run-sweep.yml` (every 30 min, cron 13,43) +
  tests `tests/test-ghost-run-sweep.sh` / `.mjs` (PR #2492, commit 0ffe877f).
  It is red on every run because the 2 ghosts above are unreapable — that red
  is expected until Support purges them.
- Concurrency groups today (9 in 8 files), none suffixed:
  `ai-review.yml:29`, `doc-health.yml:27`, `ghost-run-sweep.yml:26`,
  `merge-queue-drift.yml:32`, `review-fixer.yml:85` (job-level, indented),
  `stuck-work-watchdog.yml:35`, `verify.yml:30` (long expression),
  `windows-offline-hosted.yml:29`. Files with no group: leave alone.
- Unreapable message: `tools/ci/ghost-run-sweep.mjs:150` ("a GitHub support
  purge is the only route left"); exit-code comment at :22-23 and :107.
- Repo variables: only `MERGE_QUEUE_DRIFT_LIVE`; `LANE_EPOCH` does not exist
  (unset means 0 by design).

## 6. Key findings

- A ghost blocks only its own group. Group names are evaluated per run, so
  renaming the group for new runs escapes the ghost.
- Bumping one repository variable referenced by every group renames all groups
  atomically; hand-editing one file's group could split a group shared by two
  workflows (shared-db had such sharing; ai-devops currently has none, but the
  pattern must stay safe if one is added).
- `vars.*` is accepted in `concurrency.group` (proven live in shared-db after
  #6427: post-merge runs on main started and completed normally).
- A shared-db guard test caught a workflow added concurrently without the
  suffix (#6434) — the guard is what keeps the protection from rotting.

## 7. Approaches rejected (with why)

- Removing concurrency groups from stateless checks (Muse's first suggestion):
  loses dedupe/ordering for no extra safety once the epoch exists.
- Keying groups by commit SHA: a ghost on the current head SHA still blocks;
  breaks per-PR supersession.
- Lowering the sweep's 30-minute floor: risks deleting runs legitimately
  waiting behind a long lane. Both Muse and GLM advised against.
- Waiting on GitHub Support only: took days both times.

## 8. Decisions

Locked (2026-11-15, Albert approved the shared-db design; Muse + GLM reviewed):
- Suffix is exactly `-${{ vars.LANE_EPOCH || '0' }}` appended to the end of
  the existing group expression, identical string to shared-db.
- Existing group text and `cancel-in-progress` values do not change.
- Escape = drain, then bump `LANE_EPOCH`; never hand-rename one group.
Open: none.

## 9. Steps

1. **Suffix groups.** In each of the 9 `group:` lines listed in §5 append
   `-${{ vars.LANE_EPOCH || '0' }}` (keep everything before it byte-identical;
   for `verify.yml:30` append after the closing `}}`). Do not touch
   `::group::` log lines in `review-fixer.yml` (129/131).
   Gate: `grep -n "group:" .github/workflows/*.yml | grep -v "::group" | grep -vc LANE_EPOCH` prints 0; `actionlint` (if installed) clean.
2. **Guard test.** Add `tests/test-concurrency-epoch.sh` running a new
   `tests/test-concurrency-epoch.mjs` (node:test) that scans
   `.github/workflows/*.yml`, finds every `group:` line inside a
   `concurrency:` block (top-level or job-level, ignoring comments and
   `::group::`), and asserts each contains the exact suffix; test name
   "every workflow concurrency group carries the shared LANE_EPOCH suffix".
   Reference implementation: popcre/shared-db
   `scripts/db-flow/lane-watchdog.test.mjs` (last test). Also a negative case:
   a fixture YAML string without the suffix is reported.
   Gate: `bash tests/test-concurrency-epoch.sh` passes; fails if you remove
   one suffix locally.
3. **Sweep message.** `tools/ci/ghost-run-sweep.mjs:150`: replace "a GitHub
   support purge is the only route left" with "it may hold its concurrency
   group. Escape: follow docs/ghost-run-escape.md (drain, then bump repo
   variable LANE_EPOCH); file a GitHub support purge for the record"; update
   comments :22-23 and :107 to match. Gate: `bash tests/test-ghost-run-sweep.sh`
   passes (update any assertion on the old wording).
4. **Runbook.** Create `docs/ghost-run-escape.md` adapted from popcre/shared-db
   `docs/ghost-run-escape.md` (drop shared-db DB-lease paragraphs; ai-devops has
   no DB mutators). Procedure: (1) ghost on a merged/deleted branch blocks
   nothing — leave it for Support; (2) else drain: confirm no non-ghost run is
   queued/in progress in the affected workflows; (3)
   `gh variable set LANE_EPOCH -R popcre/ai-devops --body <current+1>`;
   (4) re-run the blocked workflow, confirm it starts; (5) file the Support
   purge and record both on #2367. Link it from `AGENTS.md` "Critical
   incidents" and from the header comment of `ghost-run-sweep.yml`.
   Gate: `docs-reachability`/`doc-health` checks pass on the PR.
5. **Land.** One PR to main titled "Let one variable rotate every concurrency
   group to escape ghost runs", body `Refs #2367`, signed with
   `$AI_GH_SIGNATURE`. Wait with `ai-pr-wait <pr> --repo popcre/ai-devops`
   (background). Merge via merge queue (`gh pr merge <pr>`). Gate: post-merge
   runs of verify and doc-health on the merge commit start and complete
   (`gh run list -R popcre/ai-devops --commit <sha>`). Update STATUS with run
   ids, tick a "LANE_EPOCH escape" checkbox on #2367 with the evidence.

Steps 1-4 are independent; do them in one branch, one PR.

## 10. Tests

New: `tests/test-concurrency-epoch.sh` (+ `.mjs`) as in step 2.
Must stay green: `tests/test-ghost-run-sweep.sh`, `bash tests/test-all.sh
--changed-since origin/main`, PR checks verify / doc-health / docs-reachability.

## 11. Constraints and gotchas

- Own worktree from origin/main; never edit the canonical checkout.
- Declare `ai-task-gates start --class code` before edits (changing AGENTS.md
  may require `reviewer-safety`; if the gate says so, re-declare).
- Never push to main; PR + merge queue; Albert does not merge — you do.
- Reviews are advisory; never wait on one.
- Do not bump `LANE_EPOCH` as part of this work (nothing is blocked; the 2
  ghosts are on a dead branch).
- Sweep red on main is expected until Support purges 43098438008/43098438147;
  do not "fix" it by suppressing the alarm.
- Times to Albert in EST.

## 12. Access

`gh` is authenticated as u2giants with admin on popcre/ai-devops (needed only
for `gh variable set`, which this plan does not run). No secrets needed.
Local: `bash tests/test-all.sh --only concurrency-epoch`.

## 13. Done, risks, open questions

Done when: all 9 groups suffixed; guard + sweep tests green; runbook linked
from AGENTS.md; PR merged; post-merge runs on the merge commit started and
completed; STATUS rows cite PR, merge SHA, run ids; #2367 box ticked.
Risk: a typo in `verify.yml`'s group breaks the required queue gate — the
merge-queue run of the PR itself proves it; rollback = revert PR.
Risk: suffix changes group names once, so a run in flight at merge time
won't dedupe with the next one — harmless.
Open: none.

## Self-audit (2026-11-16)

1. Fresh session executes without questions? Yes — §5 lists every file:line,
   §9 gives exact text and gates, §12 access.
2. All background including rejections? Yes — §3, §6, §7, §8.
3. Goal clear enough to steer? Yes — §1, with goal-wins rule.
