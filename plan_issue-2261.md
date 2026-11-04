# Plan — popcre/ai-devops#2261 (review finding on PR #2259, shared-db worktree reaper cwd)

**Verdict (checked 2026-11-04 on main `f2b4f5bd`): STILL REAL, small, worth doing under skinny.**
All three findings reproduce on main by reading the code. Findings 1 and 2 are
a test that cannot catch the regression it names; finding 3 is a real
honesty gap in a scheduled-task exit code. Fix is ~10 lines across two files,
adds no tool, no check, no wait.

Handoff backlink: none yet — this plan was produced read-only in a planning
session; the implementing session must create its `HANDOFF.d/` entry linking
here (see §13) or simply finish in one PR and close the issue.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Wrapper: check `cd` separately | ⬜ open | — |
| 2 Test: run from non-git dir, record real toplevel to absolute path | ⬜ open | — |
| 3 Test: assert cd-failure is non-zero | ⬜ open | — |
| 4 PR, merge, close #2261 | ⬜ open | — |

Fresh session starts at step 1.

## 1. Ultimate goal
Every agent machine runs a nightly job that deletes finished shared-database
work copies. When that job silently does nothing, disk fills and stale copies
confuse agents. Goal: if the nightly sweep cannot actually run, the scheduler
history says so, and the automated test would catch it if anyone reintroduces
the "ran in the wrong folder" bug (#2242). **If a step conflicts with this goal,
the goal wins — stop and flag it.**

## 2. What this application is
`popcre/ai-devops` = Albert's AI toolkit (scripts installed on every machine).
`bin/ai-reap-shared-db-worktrees` is a bash wrapper, scheduled by `install.sh`
(cron) and `bin/install-ai-devops-windows.ps1` (Task Scheduler), that runs the
`popcre/shared-db` repo's `scripts/reap-merged-worktrees.mjs` and maps its exit
codes (0 swept, 1 safe refusal → 0, else failure). Tests: bash suites under
`tests/`, auto-discovered by `tests/test-all.sh:147`.

## 3. What triggered this
Advisory StepFun review of PR #2259 (head `84f9e3ac`), posted as #2261 with
labels `review-finding`, `fixer-deferred` (auto-fixer deferred because source moved).

## 4. Scope
In: `bin/ai-reap-shared-db-worktrees` `cmd_run`; `tests/test-worktree-reap-tool.sh`.
NOT in: the shared-db reaper itself, schedule/installer wiring, config, the
Node-crash detection, any new CI check or required check, the weak `--dry-run`
assertion at test lines 81-83 (cosmetic; leave unless trivially touched).

## 5. Current state (main f2b4f5bd)
- `bin/ai-reap-shared-db-worktrees` ~line 88/90: `out="$(cd "$checkout" && node "$script" --apply 2>&1)"; rc=$?` (and dry-run twin). A failed `cd` gives rc=1 → logged "refused for safety", exit 0. Finding 3 real.
- `tests/test-worktree-reap-tool.sh:22-35` stub records only whether `git rev-parse --show-toplevel` succeeded, writing `REAP_STUB_RAN_FROM_CWD` relative to cwd (line 32). `run()` lines 38-39 inherits caller cwd (the ai-devops repo when CI runs it), so the assertion at 75-79 passes even without the `cd` fix. Findings 1 and 2 real.

## 6. Root cause
Test proves "ran in *a* git repo", not "ran in *the shared-db checkout*"; and
the caller's cwd is itself a git repo. Wrapper fuses `cd` and `node` status.

## 7. Rejected approaches
- New CI check / gate for this: violates skinny rulings (only data-safety/secret checks block).
- Running the whole suite from `/` in test-all: changes shared harness for one suite.
- Keeping `(cd && node)` and inspecting output: fragile; a separate checked `cd` is simpler.

## 8. Decisions
Locked: fix in place, no new files/tools; cd failure exits non-zero with a logged reason.
Open: exact exit code for cd failure — use the existing `die` (whatever it returns, must be non-zero).

## 9. Steps
1. **Wrapper.** In `cmd_run`, inside the `{ … }` block before the mode branch, add
   `cd "$checkout" || { note "run end: cannot enter shared-db checkout $checkout"; exit 2; }`
   then run `out="$(node "$script" --apply 2>&1)"` / `out="$(node "$script" 2>&1)"`.
   (Check whether the `{}` block is a subshell/pipe to a log; if it is a plain group,
   the cd changes the wrapper's cwd — acceptable since nothing after uses relative paths; verify.)
   Gate: `bash -n bin/ai-reap-shared-db-worktrees`; step 3 test passes.
2. **Test stub.** Stub writes `execSync('git rev-parse --show-toplevel').trim()` (or `process.cwd()`) to `process.env.AI_TEST_STUB_OUT`; `run()` exports `AI_TEST_STUB_OUT="$WORK/stub-cwd"` and runs `(cd "$WORK/home" && …)` (non-git dir, like cron). Assertion (lines 75-79) compares content to `$CHECKOUT` canonical (`cd "$CHECKOUT" && pwd -P`; on Windows Git Bash compare after `pwd -W`-insensitive normalisation — simplest: compare `basename` + existence of `$CHECKOUT/scripts`, or use `process.cwd()` and `realpath` both sides).
   Gate: revert step 1 locally (`git stash push -m tmp-2261` per stash rule or temp edit) → assertion FAILS; restore → PASS.
3. **cd-failure test.** Make the checkout un-enterable after discovery: simplest is `chmod 000 "$CHECKOUT"` is unusable (discovery reads the script first). Instead stub `cd` failure by pointing `AI_SHARED_DB_CHECKOUT` at a dir whose script exists but… if no clean way exists offline, skip the test and rely on code review of the one-line change (judgment call: do not add harness machinery for it).
   Gate: if added, assert rc ≠ 0 and log contains "cannot enter".
4. Branch `fix/2261-reap-test-cwd`, commit as Albert (`git var GIT_COMMITTER_IDENT`), PR body "Fixes #2261" signed with `$AI_GH_SIGNATURE`, merge (advisory review never waited on), confirm #2261 closed.

## 10. Tests
`bash tests/test-worktree-reap-tool.sh` green from both the repo root and `/tmp`;
mutation check in step 2 must fail on the reverted wrapper. `tests/test-all.sh` affected-mode stays green in CI.

## 11. Constraints / gotchas
Own worktree; never push to main; Windows Git Bash runs this suite (path forms differ — compare canonical paths); no stray files in repo tree (finding 2); no new waiting tools; sign GitHub posts.

## 12. Access
`gh` authenticated as needed for popcre; no secrets involved; runs fully offline.

## 13. Done / risks
Done: PR merged, CI green on merge SHA, #2261 closed by PR, nothing else. Live proof: next nightly reap log on any machine shows "swept cleanly" (not required to block close — test is the proof of the regression guard).
Risk: path-form mismatch on Windows makes step 2 flaky → use `process.cwd()` vs `pwd -P` and accept basename match if needed. Rollback: revert PR.

## Self-audit
1. Fresh session could execute without questions? Yes — §5 gives exact lines, §9 exact edits and gates; step 3 judgment criteria stated.
2. All background and rejected options carried? Yes — §6, §7.
3. Goal clear for judgment calls? Yes — §1.
Gap: no HANDOFF.d backlink (read-only planning constraint); noted at top.
