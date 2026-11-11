---
summary: Plan for issue 1836 installed checkout moved by git pull - hook already built, live proof, stale-text cleanup and closing remain.
kind: plan
status: open
read-when: Closing out issue 1836 reference-transaction hook proof
---

# Implementation plan — popcre/ai-devops#1836: installed toolkit checkout can be moved by a plain `git pull`

> **VERDICT AT THE TOP: the build is already done. Only live proof, a stale-comment cleanup, and closing remain.**
> The `reference-transaction` hook the issue proposes has shipped. It is in `main` as `hooks/reference-transaction`, landed through PRs #1844, #1847, #1848, #1899 and #1913. It is installed by `bin/ai-install-post-merge-hook:120`, which `install.sh:590` and `bin/install-ai-devops-windows.ps1:610` call. It is tested in `tests/test-ai-review-preflight.sh:578-660` and `tests/test-install-ai-devops-windows.ps1:49`, and documented in `docs/deployment.md:106-125`.
> On edge-dev3 the installed checkout `/home/ahazan/repos/ai-devops` (HEAD `4398a4be`, detached) has `.git/hooks/reference-transaction` installed. The file is dated 2026-11-03 10:43 PM EST.
> **Do not rebuild or redesign it.** The issue is still open only because its "Done when" live proof was never recorded.

Written 2026-11-04 3:53 PM EST (America/New_York) by a Claude planning subagent, read-only. Handoff link: none. This planning run was not allowed to write outside the scratchpad, so the implementer must create `HANDOFF.d/<UTC>-<machine>-claude-1836-main-guard-proof.md` that links to this plan (step 5).

## STATUS

| # | Step | State | Evidence |
|---|------|-------|----------|
| 0 | Build hook + installer + tests + docs | ✅ done (2026-10-18..10-23) | `git log --oneline -- hooks/reference-transaction` → 6c5cb876, fbc8d786, 41decd5f, 554e7b37, 578bc4a1 |
| 1 | Linux live proof (edge-dev3) | ⬜ open | — |
| 2 | Next protected update still succeeds (Linux) | ⬜ open | — |
| 3 | Windows live proof (one host) | ⬜ open | — |
| 4 | Remove stale "second layer" text and dead warning reader | ⬜ open | — |
| 5 | Record proof on #1836, close it | ⬜ open | — |

**Start at step 1.**

---

## Part 1 — Why

### 1. Ultimate goal
Albert's AI toolkit is installed on each machine from one git checkout. Only the reviewed, protected installer should be able to change that installed copy. Then no session can quietly put unreviewed code onto a machine by typing `git pull`. When this work is done, a stray pull in the installed checkout is refused with a clear message, and the normal installer keeps working.
**If a step conflicts with this goal, the goal wins. Stop and flag it.**

### 2. What this application is
`popcre/ai-devops` is Albert's public toolkit: AI skills, global instructions, reviewer wrappers and installers.
- The "installed checkout" is the clone the installer runs from:
  - Linux: edge-dev3 `/home/ahazan/repos/ai-devops`, and hetz `/worksp/ai-devops`.
  - Windows: `C:\repos\ai-devops` on edge-dev, or `D:` on 916 (see memory `916-live-toolkit-on-d-drive`).
- Protected updaters:
  - Linux: `update.sh`, which moves `main` with `-c core.hooksPath=<empty dir>`, lines 178-237.
  - Windows: `bin/install-ai-devops-windows.ps1`, line 546.

### 3. Trigger
On 2026-10-16 and 2026-10-18 a plain `git pull --ff-only` moved the installed checkouts on edge-dev and hetz. Prose rules did not stop it. The parent issue #1833 is CLOSED.

### 4. Scope
In scope: live proof on one Linux and one Windows host, the comment and dead-code cleanup in step 4, and closing #1836.
NOT in scope:
- Any redesign of the hook.
- Real enforcement against a deliberate `-c core.hooksPath` bypass. The issue accepts that it is a guardrail.
- New test suites.
- Rolling the change out to every machine beyond the normal installer.
- Reviewer requalification. It was retired in #2073.

## Part 2 — What we know

### 5. Current state
Everything in the issue's "Do" list is merged on `main` (f2b4f5bd) and installed on edge-dev3.
- **The guard hook.** `hooks/reference-transaction`, running in the `prepared` state:
  - It refuses changes to `refs/heads/main`.
  - It refuses a detached `HEAD` move in the primary worktree.
  - It allows `git fetch`, tags, other branches and linked worktrees.
  - In the `aborted` state it restores the files from a refused move that targeted existing history.
- **The old post-merge hook.** The recorder in `hooks/post-merge` is now *removed* by the installer (`bin/ai-install-post-merge-hook:119`, skinny review #2073). Nothing writes `unprotected-advances.log` any more. As a result `warn_unprotected_advances` in `bin/ai-task-gates:2615` is dead. These still describe that layer as active:
  - the guard hook's own header ("the post-merge recorder ... remain the second layer")
  - `docs/deployment.md`
  - Muse note (2) on the issue

### 6. Findings
- The protected updaters bypass all hooks, so the guard cannot block them.
- Git resolves hooks through the common dir, which is why linked worktrees need the allowances above.
- git 2.53 `worktree add` looks like a primary HEAD move. The hook tells the two apart by which lock file exists (#1899, #1901).

### 7. Rejected approaches
- **Sentinel remote.** `update.sh:111-115` rejects non-origin remotes, and worktrees share config.
- **Prose only** (sync-dotfiles text). It failed twice.
- **Keeping the post-merge recorder as a second layer.** It was retired in #2073. Do not restore it: the guard alone is the fewest-moving-parts answer.
- **A lighter replacement** (for example a read-only `main`, or `receive.denyCurrentBranch`). Neither covers a local pull or reset. The shipped hook already works, so replacing it would add churn with no benefit.

**Is the heavy mechanism still warranted?** Yes, but only because it already exists, is tested, and is about one screen of shell. Under the skinny rework we would not build *more* than this. We also should not tear it out, because the standing rule says to preserve the capability. The extra layer that was heavy (post-merge recorder plus the task-gates warning) is the part to finish deleting.

### 8. Decisions
- LOCKED: the guardrail is not enforcement; protected installers run with hooks off; ownership marker rules in `bin/ai-install-post-merge-hook`.
- OPEN: how step 4 is done (delete `warn_unprotected_advances` and its call at `bin/ai-task-gates:2636`, or leave it). Default: delete. It is dead code.

## Part 3 — How

### 9. Steps
1. **Linux proof (edge-dev3), done in a disposable way.** Run `git -C /home/ahazan/repos/ai-devops fetch origin`. Then run `git -C /home/ahazan/repos/ai-devops pull --ff-only origin main`, or `git merge --ff-only origin/main` if HEAD is detached.
   - Gate: the command exits non-zero, stderr shows "ai-devops: refusing to move", and `git rev-parse HEAD` is unchanged (`4398a4be` or whatever it was before). `git status --porcelain` is clean, which proves the restore worked.
   - If HEAD already equals origin/main, there is nothing to pull. Instead try `git reset --hard HEAD~1`. It must be refused and HEAD must stay the same.
2. **Protected update still works (Linux).** Run the documented protected install (`update.sh` per `docs/deployment.md`, with `ai-task-gates authorize-install`).
   - Gate: it exits 0, HEAD equals the target, and `.git/hooks/reference-transaction` still exists and matches `hooks/reference-transaction` (`cmp`).
3. **Windows proof.** Do steps 1 and 2 on one Windows host, over SSH to edge-dev or 916. Use Git Bash for the git commands and `bin/install-ai-devops-windows.ps1` for the protected update. Use the toolkit path from memory, not a stray clone.
   - Gate: the same as steps 1 and 2.
   - If no Windows host is reachable, report `Blocked —` naming the host. Do not skip this step.
4. **Cleanup (one small PR).**
   - Change the header of `hooks/reference-transaction` lines 9-10 to say the guard is the only layer.
   - Delete `warn_unprotected_advances` (`bin/ai-task-gates:2615-2630`) and its call at line ~2636.
   - Fix the matching sentence in `docs/deployment.md` near line 125.
   - Remove any test that asserts the warning: `grep -n unprotected tests/`.
   - Gate: `bash tests/test-ai-review-preflight.sh` passes, and so does the ai-task-gates suite that `grep -l unprotected tests/` finds. CI on the PR is green. Merge it yourself.
   - Note: editing `hooks/reference-transaction` changes the bytes, so the next protected install refreshes the hook automatically. That is expected.
5. **Close.**
   - Post one signed comment (`$AI_GH_SIGNATURE`) on #1836. It records the two hosts, the times in EST, the HEAD SHAs before and after, and the exit codes.
   - Close the issue and mark the STATUS rows.
   - Create the HANDOFF.d file only if something stayed blocked.

Steps 1 and 3 can run in parallel. Step 2 comes after step 1, and step 4 is independent.

### 10. Tests
Existing tests that must stay green:
- the `tests/test-ai-review-preflight.sh` guard section (lines 578-660)
- `tests/test-install-ai-devops-windows.ps1`
- the ai-task-gates suite

No new tests are needed. Step 4 only removes things.

### 11. Constraints and gotchas
- Never push to `main`. Use a worktree, a branch and a PR, and commit as Albert's verified identity.
- Production-safe: the proof uses only a refused pull or reset, which is reversible.
- Do not bypass the guard with `-c core.hooksPath` except through the protected installers.
- Memory `local-run-cancels-live-ci`: run tests in your own worktree.
- Windows: PowerShell 5.1 strips argument quotes, and SSH sessions can't read the gh keyring.

### 12. Access
- `gh` is authenticated on edge-dev3.
- Windows hosts are reached over Tailscale SSH (see memory entries).
- No secrets are needed.

## Part 4 — Landing

### 13. Done, risks and open questions
**Done when:**
- Steps 1-3 have their gates recorded on #1836.
- The step 4 PR is merged with CI green.
- #1836 is closed.

**Risks:**
- A refused pull with a failed restore leaves the old HEAD over new files. The message prints the fix command `git read-tree -m -u <sha> HEAD`.
- Rollback for step 4 is to revert the PR.

**Open question:** none for the owner.

## Self-audit
1. Can a fresh session execute this without asking? Yes. Each step names the host, path, command and gate (§2, §9, §12).
2. Does it carry all the background, including what was ruled out? Yes. History is in §3 and §5-§7, including the #2073 retirement that made the second layer dead.
3. Is the goal clear enough to steer by? Yes (§1). Any step that would weaken the protected installer, or leave a pull unrefused, conflicts with it.
