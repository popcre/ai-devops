---
summary: Plan for issue 2280 review findings on a merged PR - capture status fail-closed in update.sh, plus tests.
kind: plan
status: open
read-when: Fixing update.sh fail-closed status capture (issue 2280)
---

# Plan: popcre/ai-devops#2280 — updater "dirty checkout" guards fail open

**Verdict (checked 2026-11-04 against main f2b4f5bd): STILL REAL.** Findings 1 and 2 of the review on merged PR #2279 reproduce on current main: `update.sh:102`, `:227`, `:239` still discard `public_git`'s exit status, and `tools/lib/install-public-git.py:161-163` still raises on a dirty tree. Worth doing under the skinny rulings: it is a small fix to a data-safety guard (protecting uncommitted local edits in the installed checkout), not a new check, waiter, or gate.

## STATUS
| Step | State | Evidence |
|---|---|---|
| 1 Capture status fail-closed in update.sh | ⬜ open | — |
| 2 Dirty tree is not a restore failure in the wrapper | ⬜ open | — |
| 3 Tests | ⬜ open | — |
| 4 PR, merge, close #2280 | ⬜ open | — |
Fresh session starts at step 1.
Handoff backlink: create `HANDOFF.d/<UTC>-<machine>-claude-2280-updater-dirty-guard.md` linking here (not yet created; this plan was written read-only).

## 1. Ultimate goal
When Albert's toolkit updates itself, it must never overwrite or roll back over someone's unsaved local edits, and it must never claim "restored" when it did not check. Today, if the helper that reads checkout status cannot run, the updater treats the checkout as clean and proceeds. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is
`popcre/ai-devops` (public): Albert's AI toolkit (skills, global instructions, `bin/` tools) installed on each machine by `install.sh`; `update.sh` fast-forwards the installed checkout to `origin/main` and re-runs the installer, optionally as root on Linux. `public_git` (`update.sh:99-101`) runs git through `tools/lib/install-public-git.py`, which, when root runs it on a user-owned checkout, re-owns any root-created files afterwards.

## 3. Trigger
Automatic AI review (StepFun, run 41325767363) of PR #2279 (merged 2026-11-01 16:20 UTC) filed #2280 with label `review-finding`; the fixer deferred because the PR was already closed (label `fixer-deferred`). No live incident observed.

## 4. Scope
In: the three status reads in `update.sh`; the dirty-tree exception in `install-public-git.py` for read-only status; tests for both.
NOT in: redesigning `public_git`, other `public_git` call sites (already `|| exit 1`/`|| return 1`), Windows updater, adding CI checks, adding `tools/lib/install-public-git.py` to the test fixture copy list unless step 3 needs it, finding 3 beyond the tests listed here.

## 5. Current state
- `update.sh:102` `if [ -n "$(public_git --no-optional-locks status --porcelain)" ]` — no `-e`, exit status lost.
- `update.sh:227` first line of `rollback_checkout()`, same pattern.
- `update.sh:239` last line of `rollback_checkout()`: `[ -z "$(public_git …)" ]` — success if the wrapper printed nothing, so `:245-246` can print "restored prior checkout SHA" unverified.
- `install-public-git.py:150-158`: when root and owner≠root, calls `restore_outputs`; `:162-163` raises `ValueError("public source changed outside Git result")` whenever `git diff --quiet HEAD` is non-zero, i.e. any dirty tree. Refusal paths (`:129-144`) print only to stderr.
- `update.sh:71` (source-root clean check) uses plain git, not in scope.

## 6. Key findings
- Wrapper refusals / missing python3 / missing module ⇒ empty stdout ⇒ guard skipped (fail-open).
- `tests/test-ai-task-gates-linux-install.sh:22-43` fixture omits `tools/lib/install-public-git.py`, so the guard already silently no-ops in tests (`:252`, `:342`).
- Dirty tree under root ⇒ traceback + "ownership restoration failed" noise before the real warning; guard only works because git flushed stdout first.

## 7. Rejected approaches
- `set -e` for update.sh: changes behavior of every line; too broad.
- New wrapper return code protocol (distinct "dirty" exit code): more moving parts than needed.
- Removing the diff guard entirely in `restore_outputs`: it protects mutating commands; keep it for them.

## 8. Decisions
Locked: fail closed on any status-read failure; keep `--no-optional-locks`; keep `public_git` as the only route for root-run git. Open: exact way the wrapper recognizes a read-only status call (criteria: first non-`-c`/option argument is `status` and `--no-optional-locks` present; simplest readable test wins).

## 9. Steps
1. **update.sh fail-closed.** Replace `:102` with `dirty="$(public_git --no-optional-locks status --porcelain)" || { warn 'could not read installed checkout status'; exit 1; }` then `[ -z "$dirty" ] || { warn 'checkout has local changes; preserve and reconcile them before updating'; exit 1; }`. In `rollback_checkout()` do the same with `local dirty` and `|| return 1` at `:227` and `:239` (final line becomes `[ -z "$dirty" ]` after a checked capture). Gate: `bash -n update.sh`; manual run with `SOURCE_ROOT` pointing at a copy missing the module exits 1 with the new warning.
2. **Wrapper: dirty tree is a normal status result.** In `install-public-git.py`, skip the `git diff --quiet HEAD` raise in `restore_outputs` when the invocation is a read-only `status` (pass a flag from `main`). Ownership restoration still runs. Gate: as root on a dirty user-owned temp checkout, `python3 tools/lib/install-public-git.py <root> --no-optional-locks status --porcelain` prints porcelain, exit 0, no traceback on stderr.
3. **Tests.** In `tests/test-install-public-git.py` add `test_status_on_dirty_tree_returns_porcelain_without_error` (root-skippable if not root, matching existing skips) and `test_refusal_prints_nothing_to_stdout_and_nonzero`. In `tests/test-ai-task-gates-linux-install.sh` (or `test-linux-install-authorization.sh`) add a case: installed checkout fixture without the module ⇒ `update.sh` exits non-zero with "could not read installed checkout status"; and a case with a dirty tracked file ⇒ "checkout has local changes". Gate: `python3 tests/test-install-public-git.py` and `bash tests/test-ai-task-gates-linux-install.sh` and `bash tests/test-linux-install-authorization.sh` all pass.
4. **Land.** Branch `fix/2280-updater-dirty-guard`, worktree, commit as Albert (`git var GIT_COMMITTER_IDENT`), PR body "Fixes #2280", signed `$AI_GH_SIGNATURE`; wait with `bin/ai-pr-wait <pr>` in background; merge (review advisory only). Live proof: on one Linux machine run the updater normally and confirm it updates; note result on #2280; close.

## 10. Tests
Named in step 3; existing suites above must stay green.

## 11. Constraints
Never push to main; commit only owned files; no new required checks; reviews never gate; times in EST; no secrets involved. Keep `public_git` umask/ownership semantics unchanged for mutating commands.

## 12. Access
`gh` authenticated as u2giants with popcre access; Linux shell with sudo for root-path test; no 1Password items needed.

## 13. Done / risks
Done: steps 1-4, CI green, PR merged, live updater run proven, #2280 closed with evidence. Risk: a status-read failure now blocks updates that previously proceeded — intended; rollback is reverting the PR. Open question: none for the owner.

## Self-audit
1. Fresh session can execute without asking: yes — §5 gives exact lines, §9 exact edits and gates.
2. Carries background and rejected options: §3, §6, §7.
3. Goal clear for judgment calls: §1 and §8 locked "fail closed".
