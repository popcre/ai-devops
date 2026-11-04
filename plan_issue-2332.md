# Implementation plan — popcre/ai-devops#2332 (review finding on PR #2329)

**Verdict (checked 2026-11-04 on main `f2b4f5bd`): STILL REAL, small.** Both findings reproduce on main:
- `tests/reviewer_maintenance_cases.py:561-562` still calls `self.skipTest(...)` inside the provider loop of `test_delete_preserves_metadata_and_provider_when_snapshot_cleanup_refuses` (loop at line 558). `bin/ai-glm` no longer has `cmd_delete()`, so the skip fires on `glm` and the `grok` iteration never runs, although `bin/ai-grok-review:2197`, `bin/ai-kimi:2264`, `bin/ai-qwen:2348` still own `cmd_delete()`.
- `grep -rn reviewer_maintenance_cases` over `*.sh`, `*.json`, `*.yml`, `.github/` returns nothing: no CI lane runs this module at all.

Worth doing under skinny rules: a one-line logic fix plus one tiny wrapper suite; no new tools, gates, or waits.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Fix per-provider skip | ⬜ open | — |
| 2 Wire module into CI via a shell suite | ⬜ open | — |
| 3 Local run green | ⬜ open | — |
| 4 PR, merge, close #2332 | ⬜ open | — |

Fresh session starts at Step 1. Handoff backlink: the implementer creates `HANDOFF.d/<UTC>-<machine>-<agent>-2332-maintenance-cases.md` linking here (the planning session was read-only and could not create it).

## 1. Ultimate goal
The safety test proving "deleting a reviewer session never loses its metadata when snapshot cleanup refuses" must actually run, for every reviewer wrapper that still has a delete path, in CI. Today it silently skips Grok and never runs anywhere. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
`popcre/ai-devops`: Albert's public AI toolkit (CLI wrappers under `bin/`, tests under `tests/`, CI under `.github/workflows/`). `tests/test-all.sh` / `tests/test-all.ps1` run `tests/test-*.sh` suites, honoring `config/ci-suite-manifest.json` (which lists suspended suites). Branch from `main`; PR into protected `main`.

## 3. Trigger
Advisory GLM review of PR #2329 (merged 2026-11-03, merge commit `16b60de4`), filed as `review-finding` #2332. The automatic fixer deferred it (overlap with PR #684). Repro: `python3 tests/reviewer_maintenance_cases.py -v` — the delete test reports "skipped" and grok is never exercised.

## 4. Scope
In: the skip logic in that one test; one new wrapper suite so the module runs in CI.
NOT in: migrating qwen/kimi/grok delete into `ai-second-opinion`; un-suspending any suspended suite; changing `tools/reviewer_maintenance.py`; any other test in the module; review/CI gating changes.

## 5. Current state
`tests/reviewer_maintenance_cases.py` was restored by #2329 (synthetic `ai-reviewer-issue` stub at lines 41-62, `resolve_bash()` at 79-84). Delete test at 557+. Nothing calls the module (verified by grep above). Example wrapper pattern: `tests/test-reviewer-credit-stream.sh:1-6` (`PYTHON="$(command -v python3 || command -v python)"; "$PYTHON" "$ROOT/tests/<module>.py"`).

## 6. Root cause
`unittest.SkipTest` ends the whole test method; there is no per-subTest skip. Provider order is qwen, kimi, glm, grok, so glm's skip kills grok's iteration. Separately, the module's old runner `tests/test-ai-reviewer-issue.sh` was deleted in #2074 and never replaced.

## 7. Rejected approaches
- Reorder the tuple so glm is last: fragile; breaks again when kimi/qwen migrate.
- Delete the glm entry: loses the automatic "now covered by ai-second-opinion" signal; `continue` is equally simple.
- Add it to a new CI workflow/job: more moving parts; a `tests/test-*.sh` file is picked up by the existing runner.
- Leave as-is because reviews are advisory: the finding is a real coverage loss on a data-preservation safety property; the fix is trivial.

## 8. Decisions
Locked: use `continue` per provider; call `skipTest` only when zero providers own `cmd_delete`. Locked: run via a `tests/test-*.sh` wrapper, no workflow edits. Open: suite file name (suggested `tests/test-reviewer-maintenance-cases.sh`).

## 9. Steps
1. **Fix skip** in `tests/reviewer_maintenance_cases.py` (~556-562): add `ran = 0` before the loop; replace `self.skipTest(...)` with `continue`; increment `ran` after the provider's assertions; after the loop, `if not ran: self.skipTest("no wrapper owns cmd_delete; delete moved to ai-second-opinion")`. Gate: `python3 tests/reviewer_maintenance_cases.py -v` shows the delete test **ok** (not skipped), and temporarily printing provider proves grok ran.
2. **Wire into CI**: create `tests/test-reviewer-maintenance-cases.sh` mirroring `tests/test-reviewer-credit-stream.sh:1-6` (shebang, `set -euo pipefail`, ROOT, PYTHON, run module), LF line endings, mode 755. Confirm `tests/test-all.sh` discovers `tests/test-*.sh` by glob (read its loop); if it uses an explicit list or the manifest needs a shard entry, add it there instead of anything new. Gate: `bash tests/test-all.sh` (or its single-suite filter) runs the new suite and passes.
3. **Local run**: run the new suite on Linux; if a Windows box is available, run it in Git Bash (module already uses `resolve_bash()`). Gate: exit 0.
4. **Land**: branch `fix/2332-maintenance-delete-coverage`, commit as Albert's verified identity with the Claude co-author trailer, PR body says `Closes #2332`, signed with `$AI_GH_SIGNATURE`. Wait with `bin/ai-pr-wait <pr>` in background; merge yourself when required checks pass (reviews advisory, never wait on them). Gate: PR merged, #2332 closed, CI run on the merge commit shows the new suite passed.

## 10. Tests
Existing `test_delete_preserves_metadata_and_provider_when_snapshot_cleanup_refuses` must run grok (and kimi/qwen) and pass; the whole module must pass under `python3` and `pytest`. New suite must pass in CI.

## 11. Constraints / gotchas
Never push to `main`. LF only (Git Bash chokes on CRLF). Do not un-suspend suites in `ci-suite-manifest.json`. If the grok/kimi/qwen iteration now FAILS (it never ran before), that is a real finding: fix the test fixture only if the fixture is wrong; if the wrapper is wrong, file/fold into the existing issue rather than silencing it. Never "fix" by re-adding a skip.

## 12. Access
`gh` authenticated for `popcre/ai-devops`. No secrets needed. Python 3 and bash on PATH.

## 13. Done / risks
Done: steps 1-4 gated; STATUS updated with commit SHA and CI run id; handoff file written. Risk: newly running grok iteration exposes a latent failure — handle per §11. Rollback: revert the PR. No business question for the owner.

## Self-audit
1. Fresh session executable without questions? Yes — §5/§9 give exact lines, patterns and gates.
2. All context incl. rejected options? Yes — §6, §7.
3. Goal clear enough for judgment? Yes — §1 plus §11's "never re-skip" rule.
