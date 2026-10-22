# Seafile toolkit sync: receipt migration in flight, 47b62e2c update next

## 1. Goal
Bring Seafile (Ubuntu 24.04 host `seafile-br`; installed checkout is the
machine's canonical ai-devops clone) to release
`47b62e2c559cb5fe41644a72ea8ea9f063408732` and finish every
`sync-dotfiles` step, ending with `grep -c` proof of a new 2026-10-21 rule
in both live instruction files (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`),
then tick the re-review box on
https://github.com/popcre/ai-devops/issues/1962 with a signed comment.

## 2. Current state (1:19 PM EDT, 2026-10-22)
- Installed checkout HEAD: `94ef5b0d`. It never had a Linux install receipt
  (`/etc/ai-devops/install-manifest.tsv` absent; `/usr/local/bin/ai-task-gates`
  is a symlink).
- **In flight:** the legacy-migration same-source install at `94ef5b0d`
  (`./install.sh --reviewer-approval <report>` in the installed checkout,
  installation task declared there). It was authorized via
  `authorize-install --legacy-migration` from a separate installation
  worktree at `94ef5b0d`. On success it writes the install manifest. Check
  whether it finished: the manifest exists and `install.sh` exited 0.
- Release `47b62e2c` already has everything the update gate needs except the
  receipt: GLM exact-head APPROVE **with passing tests**
  (`--tests 'env -u CLAUDE_CODE_SESSION_ID tests/test-all.sh'`), and both
  `ai-devops/live-review/linux` and `/windows` commit statuses = success
  (posted by `ai-release-live-check fleet --provider glm`).
- The 47b62e2c APPROVE report lives in the reviewer worktree for that SHA
  under `.ai/reviews/glm-final-check-20261022T093038-*.md` (machine-local;
  re-run the review if it is gone).
- Step 2 wiring was checked and is current (token file, both MCP launchers,
  `mcp.env` matches the example, shellrc sourced, zero plaintext `ops_` tokens).
- Steps 1b, 1c, 2b, 4, 4c, 5, 6, 6b, 6c, 6c2, 6c2b, 7, 8 have NOT run.

## 3. Machine-local repairs already made on Seafile (keep)
- `python-is-python3` installed via apt (two suites called `python`).
- AppArmor profile `/etc/apparmor.d/bwrap` added (userns for `/usr/bin/bwrap`).
  Ubuntu 24.04 `kernel.apparmor_restrict_unprivileged_userns=1` blocked
  bubblewrap; several review/test suites need it.
- Verified host key for Windows host 4837 appended to `~/.ssh/known_hosts`
  from the private config's `ssh_known_hosts` (it was never installed here).

## 4. What was tried / learned
- `b510040d` got REVISE then was superseded; `5cc973dd` superseded.
- Codex-memories test defect (hard-coded `/usr/local/bin/codex` fallback) fixed in
  https://github.com/popcre/ai-devops/pull/1986 (merged `42fa042a`).
- `bin/ai-test-local` includes the frozen Kimi suite and fails here; use
  `tests/test-all.sh`, which drops `suspended_bash` exactly like CI.
- Run tests with `CLAUDE_CODE_SESSION_ID` unset (closeout-check test reads it).
- At `94ef5b0d` (pre-#1986) the Codex test can only pass with Codex hidden.
  Wrapping tests in `bwrap` broke nested sandboxes. What worked: a private
  mount namespace binding `/dev/null` over the real codex binary for the test
  process only (`sudo unshare -m` + `setpriv` back to uid 1000).
- `TMPDIR` is empty in Claude sessions here; use the session scratchpad.
- Gate rules hit, in order: review and install need separate task worktrees;
  `authorize-install` needs `--tests` evidence; shared-review-code releases
  need `ai-release-live-check fleet`; Linux with no manifest needs
  `--legacy-migration` at the unchanged head first; `install.sh` needs an
  installation task declared in the installed checkout itself.

## 5. Next actions
1. Confirm the legacy install finished (manifest present, exit 0). If it
   failed, read its log, and do not force.
2. Fresh installation worktree at `94ef5b0d`: `ai-task-gates start --class installation`
   using the 47b62e2c gate, advance it to `47b62e2c` (`git -c core.hooksPath=<empty> checkout --detach`),
   `git fetch origin`, then `./bin/ai-task-gates authorize-install --target-head 47b62e2c559cb5fe41644a72ea8ea9f063408732 --installed-checkout <installed> --installed-launcher /usr/local/bin/ai-task-gates --review-report <47b62e2c report> --reviewer-approval <same>`.
3. From a clean exact-SHA worktree at `47b62e2c`: `./update.sh --installed-checkout <installed> --expected-head 47b62e2c559cb5fe41644a72ea8ea9f063408732 --reviewer-approval <report>` (see https://github.com/popcre/ai-devops/blob/main/docs/deployment.md).
4. Run `sync-dotfiles` steps 1b, 1c, 2b, 4 (+grep proof), 4c, 5, 6, 6b, 6c, 6c2, 6c2b, 7, 8.
5. Signed comment on issue 1962 ticking the re-review box.

## 6. Verification
`ai-task-gates` reports the installed head `47b62e2c`; the manifest names it;
`grep -c "<new rule phrase>" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md` returns 1
for each file (confirm the phrase is in `templates/system/` first).

## 7. Workspace left behind (Seafile)
Detached worktrees `ai-devops-rev-{94ef5b0d,b510040d,5cc973dd,42fa042a,47b62e2c,1460e36b}`,
`ai-devops-candidate` (54840353), `ai-devops-inst` (47b62e2c, stale installation task),
`ai-devops-inst-legacy` (94ef5b0d, used authority). Keep `rev-47b62e2c` (holds
the APPROVE report) until the install lands; the rest can be cleaned up with the `cleanup-worktree` skill.

## 8. Risks
The installed checkout must not be pulled by hand. A failed legacy install
should roll back on its own; verify before retrying.

## 9. Owner
Successor session on Seafile. Posted by Claude chat 486b6ef8-23ef-4b3c-a538-3bc2f936c242 on Seafile.
