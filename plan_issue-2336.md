---
summary: Plan for issue 2336 review findings on ai-doc-safety --changed and public boundary check; small fixes remain.
kind: plan
status: open
read-when: Fixing ai-doc-safety --changed findings (issue 2336)
---

# Implementation plan — popcre/ai-devops#2336 (review findings on `ai-doc-safety --changed`)

**Verdict (checked 2026-11-04 against main `f2b4f5bd`): STILL REAL, small, worth doing in a skinny form.**
PR #2335 merged 2026-11-04 00:28 UTC as commit `4398a4be`; `bin/ai-doc-safety` on main is byte-for-byte the
reviewed code (line 51 `--diff-filter=d "$base...HEAD"`, line 33 `sed -n '2,32p'`, line 68 any `timeout` on PATH),
and `bin/ai-public-boundary-check:7` still consumes `$1` as root unconditionally. One finding (#7, "the whole-repo
sweep is lost") is **already covered**: `.github/workflows/verify.yml:247-258` (`doc-safety` job) and `:558` still run
the full-tree boundary and link checks in CI, so no work is needed there beyond one doc sentence.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Refuse a dirty worktree in `--changed` mode | ⬜ open | |
| 2 Whole-tree link check when the diff deletes/renames files | ⬜ open | |
| 3 Use `timeout` only when it is GNU | ⬜ open | |
| 4 Validate the `--changed` base ref | ⬜ open | |
| 5 Fix `--help` range and `ai-public-boundary-check -- path` | ⬜ open | |
| 6 Tests, doc sentence, PR, merge, close #2336 | ⬜ open | |

Fresh session starts at Step 1. Handoff backlink: none yet — the implementing session creates its own
`HANDOFF.d/<UTC>-<machine>-<agent>-ai-doc-safety-2336.md` linking here only if it stops unfinished.

## 1. Ultimate goal
Albert's toolkit lets prose-only pull requests skip the merge queue after a quick local safety check
(`bin/ai-doc-safety --changed origin/main`). That check must not say "safe" when the content that lands could
leak a private value, or when the PR breaks a documentation link. Done = the quick check is honest about what it
checked, with no new tools, no new waits, and no new required CI checks.
**If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is
`popcre/ai-devops` (public) — Albert's multi-model AI toolkit: Bash/PowerShell tools in `bin/`, Python helpers in
`tools/`, offline test suites in `tests/`, CI in `.github/workflows/verify.yml`. Runs on Linux and Windows Git Bash.
Not a deployed app. Branch from `origin/main`; protected `main` uses a merge queue.

## 3. Trigger
Advisory reviewer (Muse) on PR #2335 filed issue #2336 with 8 findings; the auto-fixer deferred because the PR was
already merged. No incident has occurred; these are latent gaps.

## 4. Scope
In: `bin/ai-doc-safety`, `bin/ai-public-boundary-check` (arg parsing only), `tests/test-ai-doc-safety.sh`,
`tests/test-public-boundary.sh`, one sentence in `docs/ai-tools-cheat-sheet.md`.
NOT in scope: changing CI jobs or required checks; a portable watchdog replacing `timeout`; changing
`tools/check-markdown-links.py` logic; changing the hard-coded `:!tests/...` exclusions (intentional fixtures);
reworking the prose-lane policy in `AGENTS.md`.

## 5. Current state of the code
- `bin/ai-doc-safety:30-63` parses args; `:49-56` builds the `--changed` path list from committed `BASE...HEAD`
  only, excluding deletions. Checks then read the **worktree files**, not HEAD blobs.
- `:65-81` `run_check` uses whatever `timeout` is on PATH, unbounded if none.
- `:94-102` runs `ai-public-boundary-check` and `tools/check-markdown-links.py` with `-- paths`.
- `bin/ai-public-boundary-check:7-8` — `root="${1:-.}"; shift`; `--` as first arg becomes root.
- Tests: `tests/test-ai-doc-safety.sh:49-65` cover scoped modes and timeout.

## 6. Key findings / root cause (per review finding)
1. Deleted/renamed link targets: `--diff-filter=d` drops them and the link checker only reads changed `.md` files,
   so an unchanged doc linking to a deleted file is never checked. Real (link breakage, not a leak).
2. Dirty worktree: checks read worktree content while only committed HEAD lands. A file whose committed version
   contains a secret but whose worktree copy was cleaned passes. Real and secret-leak relevant → fix.
3. Windows `timeout.exe`: only bites if System32 precedes `/usr/bin` on PATH in Git Bash (unusual); missing GNU
   timeout silently drops the limit. Real but minor.
4. Option injection via `--changed -x`: caller-controlled only; cheap to close.
5. `--help` prints code lines 26-32: cosmetic, one-character fix.
6. `ai-public-boundary-check -- clean.md` misparses: real, tiny.
7. Lost whole-repo sweep: already covered by CI (`verify.yml:247-258`, `:558`). Doc sentence only.
8. Missing tests: addressed by Step 6.

## 7. Rejected approaches
- Union `git status` dirty/untracked files into scope: untracked/uncommitted files do not land, so checking them
  is noise; and a cleaned-but-committed secret still slips. Refusing a dirty tree is simpler and exact.
- Checking HEAD blobs via `git show` instead of the worktree: rewrites both checkers; too many moving parts.
- Portable Bash watchdog replacing `timeout`: new moving part; the limit is anti-hang, not safety.
- Adding a required CI check for prose PRs: violates the 2026-10-30 lean-required-checks ruling.

## 8. Decisions
Locked: dirty tree in `--changed` mode → exit 2 with a clear message; any deletion/rename in the diff →
link check runs whole-tree (boundary check stays scoped; deleting files cannot leak); non-GNU or missing
`timeout` → run unbounded with a visible one-line warning (not fail-closed — it would block Windows hosts for a
non-safety feature). Open: exact message wording.

## 9. Steps
1. **Dirty-tree refusal** — in `bin/ai-doc-safety` after line 49, if `git -C "$tree" status --porcelain
   --untracked-files=no` is non-empty, print `ai-doc-safety: --changed needs a clean worktree (commit or stash first)`
   and exit 2. Untracked files are ignored (they do not land). Gate: new test "a dirty tracked file refuses --changed".
2. **Deletions widen the link check** — run a second `git diff --name-only --diff-filter=DR "$base...HEAD"`; if
   non-empty set `links_scope_args=()` (whole tree) and label it in the progress line; boundary check keeps
   `scope_args`. Gate: test "deleting a link target fails --changed" (fixture: a.md links b.md; PR deletes b.md).
3. **GNU timeout probe** — replace line 68 with: use `timeout` only if `timeout --version 2>/dev/null | grep -q
   coreutils`; otherwise print `ai-doc-safety: no GNU timeout; running without the time limit` once. Gate: existing
   timeout test still passes; new test with a fake non-GNU `timeout` first on PATH prints the warning and passes.
4. **Validate base** — before the diff, `git -C "$tree" rev-parse --verify --quiet --end-of-options
   "$base^{commit}"` else exit 2; then pass the range after `--end-of-options` too. Gate: test "--changed --help
   exits 2" (`--changed=-x` form).
5. **Small fixes** — line 33 range → `'2,25p'` (end of header comment; recheck after edits). In
   `bin/ai-public-boundary-check` treat a leading `--` as "root=. then paths". Gates: `--help` output has no
   `set -uo`; `bash bin/ai-public-boundary-check -- README.md` exits 0 in this repo.
6. **Land** — add the tests above to `tests/test-ai-doc-safety.sh` / `tests/test-public-boundary.sh`; add to
   `docs/ai-tools-cheat-sheet.md`: "`--changed` proves the diff only; CI's doc-safety job sweeps the whole tree."
   Branch, PR via merge queue (code change — never admin-merge), wait with `bin/ai-pr-wait <pr>` in background,
   verify on `origin/main`, close #2336 with a signed comment citing the merge SHA and test names.

## 10. Tests
New (in `tests/test-ai-doc-safety.sh`): dirty tracked file refuses `--changed` (exit 2); untracked file does not;
deleted link target fails; dash-leading base exits 2; non-GNU timeout warns and still runs; `--help` excludes code.
New (in `tests/test-public-boundary.sh`): `-- path` with no root works. Must stay green: `bash
tests/test-ai-doc-safety.sh`, `bash tests/test-public-boundary.sh`, `bash tests/test-markdown-links.sh`,
`bash tests/test-workflow-policy.sh`, and CI `verify.yml`.

## 11. Constraints / gotchas
Skinny rulings (`docs/owner-rulings.md`, 2026-10-29/30): reviews advisory, only data-safety/secret checks block,
no new waiting tools. Windows CRLF breaks Bash scripts — keep LF. Commit as `Albert Hazan
<u2giants@users.noreply.github.com>` (check `git var GIT_COMMITTER_IDENT`); own worktree; stage only owned files;
sign GitHub posts with `$AI_GH_SIGNATURE`. `--diff-filter=DR` with renames needs default rename detection — fine.

## 12. Access
`gh` authenticated for `popcre/ai-devops`. No secrets needed. Run locally from a fresh worktree off `origin/main`.

## 13. Done + risks
Done: steps 1-6 merged via queue, CI green, `origin/main` contains changes, #2336 closed with evidence.
Risk: dirty-tree refusal surprises a session mid-landing — message says what to do; rollback = revert the PR.
Open question: none for the owner.

## Self-audit
1. Fresh session can execute without questions? Yes — §5/§9 give exact lines, commands, gates.
2. All background incl. rejected options? Yes — §6 per-finding triage, §7 rejections, verdict on #7 with CI lines.
3. Goal clear for judgment calls? Yes — §1, plus §8 locked choices explain the trade-offs.
