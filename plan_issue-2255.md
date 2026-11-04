# Plan — popcre/ai-devops#2255: deterministic test for the same-inode owner-repair branch

**Verdict (2026-11-04, checked on main f2b4f5bd): STILL REAL, small.** PR #2254 (merged 2026-11-01) added a repair branch in
`tools/lib/install-public-git.py:172-179` (`restore_outputs`): a same-inode file whose prior owner was non-root, now root-owned
with a changed ctime, is chowned back to the checkout owner. `tests/test-install-public-git.py` on main still has no test that
deterministically reaches that branch (the 15 tests are listed at lines 62-307; the two root-gated owner tests at 125-161 cover the
distinct-inode path and the preserve-root path only). Later commit d3c5aa3d (#2279) did not touch this. Under skinny rules this is
worth doing: one test, no new tool, no new gate.

## STATUS
| Step | State | Evidence |
|---|---|---|
| 1 Add test | ⬜ open | — |
| 2 Prove test fails without the fix | ⬜ open | — |
| 3 PR, merge, close #2255 | ⬜ open | — |
Fresh session starts at Step 1.

Handoff: none created (planning was read-only by instruction). The implementer creates `HANDOFF.d/<UTC>-<machine>-<agent>-2255-same-inode-test.md` linking to wherever this plan is committed, if work is left unfinished.

## 1. Ultimate goal
When the toolkit updater (run as root) updates Albert's installed ai-devops checkout, files must stay owned by the checkout's
normal account, or later non-root sessions break. The fix for one case exists; the goal is that a future edit cannot silently undo
it. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
`popcre/ai-devops` (public): Albert's shared AI toolkit (skills, installers, reviewers). `tools/lib/install-public-git.py` wraps
Git operations the Linux updater (`update.sh:102-104`, function `public_git`) runs as root against a non-root-owned checkout,
then `restore_outputs` returns ownership of new/replaced files to the checkout owner.

## 3. Trigger
Advisory StepFun review of PR #2254 (workflow run 41279594154) filed finding #2255 (labels `review-finding`, `fixer-deferred`;
the auto-fixer deferred because the source PR was closed/merged). Finding 1: the new repair branch has no deterministic test; it
is only reached by `test_restrictive_parent...` (line 62) when the filesystem happens to reuse an inode.

## 4. Scope
In: one new root-gated unit test in `tests/test-install-public-git.py`.
NOT in: changing `install-public-git.py`; making CI run as root; adding a root CI job or required check; the reviewer's "minor"
observations (truncated, non-blocking); any other review-finding issue.

## 5. Current state
Code fix merged (87790de4). Tests at lines 113-197 are `skipUnless(os.geteuid() == 0)`. The suite runs from
`tests/test-linux-install-authorization.sh:413` in `verify.yml`, non-root, so root tests skip in CI. Fixture `setUp`
(lines 21-52) makes repo owned by `nobody` when root; `old` differs between `self.before` and `self.after`.

## 6. Key findings
- Repair condition (line 172-173): skip only if same inode AND NOT (prior uid != 0 AND ctime changed). Reaching repair needs:
  same inode, prior uid = owner, observed uid = 0, ctime changed, and content matching HEAD (line 162 diff guard).
- The reviewer's suggested recipe (in-place rewrite without chown) does NOT reach it: an in-place write keeps uid `nobody`, so
  line 170 (`observed[2] != 0 → continue`) skips. The test must also `os.chown(path, 0, 0)` inside the side effect to simulate
  Git's root recreation on a reused inode. `chown` itself bumps ctime.

## 7. Rejected approaches
- Reviewer's exact recipe (no chown) — never reaches the branch (see 6).
- Forcing real inode reuse via Git — filesystem-dependent, nondeterministic (that is the bug in coverage).
- Adding a root CI job — more moving parts; owner ruling 2026-10-30 (docs/owner-rulings.md) keeps only data-safety/secret checks
  blocking; not needed to close a coverage gap.

## 8. Decisions
Locked: test-only change; root-gated like its siblings; no new workflow. Open: test name (suggested below).

## 9. Steps
**Step 1 — add test** after line 161 in `tests/test-install-public-git.py`:
`@unittest.skipUnless(os.geteuid() == 0, "same-inode owner transition requires root")`
`def test_same_inode_owner_to_root_transition_is_repaired(self):` — copy the structure of
`test_preexisting_root_file_same_inode_inplace_edit_keeps_owner` (141-161) but: no initial `os.chown(path, 0, 0)`; in the
side effect after `reset`, write `"modified fixture\n"`, then `os.chown(path, 0, 0)`, and create `new-directory` files as there.
Record `before = helper.metadata(path)`. Assert after: `after[:2] == before[:2]` (same inode), `after[2] == self.owner.pw_uid`,
`after[3] == self.owner.pw_gid`, content `"modified fixture\n"`.
Gate: `sudo python3 tests/test-install-public-git.py -k same_inode -v` passes; non-root run shows it skipped.
**Step 2 — prove it bites.** Temporarily change line 172-173 condition back to `prior is not None and observed[:2] == prior[:2]`
locally (do not commit); rerun as root; the new test must fail on the uid assertion. Restore the file (`git diff` empty for it).
Gate: fail then pass recorded in the PR body.
**Step 3 — land.** Branch, commit (Albert's verified identity, Co-Authored-By trailer), PR "tests: deterministic same-inode
owner repair (#2255)" with `Closes #2255`, signed with `$AI_GH_SIGNATURE`. Run `bin/ai-pr-wait <pr>` in background; merge
yourself when required checks pass (reviews advisory). Gate: PR merged, #2255 closed.

## 10. Tests
New: `test_same_inode_owner_to_root_transition_is_repaired`. Must stay green: `python3 tests/test-install-public-git.py`
(non-root and root) and `bash tests/test-linux-install-authorization.sh`.

## 11. Constraints / gotchas
Work in a worktree, never the canonical checkout. Never push to main. Root runs only on disposable temp fixtures. The diff guard
(line 162) aborts if content differs from HEAD — side effect must write exactly the `after` content. `safe.directory` env is set
by `setUp`; keep it. Times in EST.

## 12. Access
Linux machine with passwordless sudo (or root shell) for Step 1-2 proof; `gh` authenticated for popcre. No secrets needed.

## 13. Done + risks
Done: test added, fail-without-fix proof, root and non-root passes, PR merged, CI green, #2255 closed by the PR.
Risk: test is skipped in CI (non-root), so protection is only for root local runs — accepted under skinny. Rollback: revert the
test commit. No open owner questions.

## Self-audit
1. Fresh session executable without questions? Yes — §9 names file, line, exact asserts, commands; §6 explains the non-obvious chown.
2. All background incl. rejected paths? Yes — §6-7.
3. Goal clear for judgment calls? Yes — §1.
Gap noted: no HANDOFF.d file (read-only instruction); §STATUS tells the implementer to create one if unfinished.
