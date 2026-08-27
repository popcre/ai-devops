---
issue: 119
status: OPEN
owner: claude/fix-script-line-endings
---

# HANDOFF — Windows checkouts corrupt every Bash script (CRLF); two machines still run the old completion rule (2026-08-27 01:00 UTC, edge-dev/claude)

- **Status:** OPEN. The repo-side fix is written and committed; what remains is
  (a) renormalising checkouts that predate it and (b) adopting the globals on
  the two machines that were never reachable.
- **Parent workstream:** [`plan_completion-honesty-enforcement.md`](../plan_completion-honesty-enforcement.md),
  which is **CLOSED**. This file carries forward only its two loose ends. Do not
  reopen that plan, and do not reopen its step 10.
- **Written:** 2026-08-27 (UTC) on `edge-dev` by Claude (Opus 5), branch
  `claude/fix-script-line-endings`, base `e29ef92`.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one** message before starting work.

**BLOCKING** — none. Everything below is authorized ordinary work in this repo.

**RECOVERABLE** (a wrong guess is fixable but wastes rework):

1. **Should `bin/ai-adopt-globals` on t16 and 916 be done by Albert at the
   keyboard, or should t16 get an SSH server so sessions can reach it like
   `al8960ofc`?** t16 is online over Tailscale but accepts no SSH, which is why
   this rollout could not finish. *Recommendation: enable SSH on t16* — it is a
   one-time setup, `al8960ofc` already works this way via the `4837` host alias
   in `config/ssh-config.template`, and it removes the whole class of "a machine
   was unreachable so the rollout is partial" report. Ask before configuring it,
   because it changes a machine's network exposure.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT:**

2. **Documentation-only pull requests run the ~50-minute `windows-offline`
   job.** `verify` has no path filtering, so a Markdown-only change pays full
   CI cost. Raised as a comment on issue
   [#98](https://github.com/popcre/ai-devops/issues/98), which already owns
   `windows-offline` latency, rather than acted on here — that issue has an
   active handoff and an owner. *Recommendation: leave it with #98.* See §9 for
   the two traps that make it less trivial than it looks.
3. **The reviewer test suites are flaky in a way that costs real time.** Three
   Grok turn-reservation tests failed inside the merge queue on 2026-08-26
   (`same_next_ask_turn_is_serialized`, `uncertain_ask_blocks_its_exact_retry`,
   `uncertain_ask_does_not_block_other_named_session`) after passing on the same
   commit 30 minutes earlier, which dequeued PR #101 and cost an extra
   ~50-minute cycle. Four analogous timing tests also failed on a local Windows
   run. There is an existing handoff,
   `HANDOFF.d/2026-08-26T1125Z-edge-dev-claude-flaky-reviewer-tests.md`.
   *Recommendation: none needed from Albert; noted so the next session does not
   diagnose a "broken build" that is a known flake.*

**Already settled — do NOT re-ask:**

- 2026-08-26 — **"stop measuring."** The completion-honesty rewrite is not, and
  will not be, validated by measurement. Say so plainly rather than describing
  it as proven. Do not rebuild the eval's model judge.
- 2026-08-26 — Codex gets no Stop-hook system. Instruction plus eval only.
- 2026-08-27 — Albert deferred t16 during this session ("nevermind t16, we can
  do it another time"). Deferred, not cancelled.

## 1. What this application is

`popcre/ai-devops` (formerly `u2giants/ai-devops`; **both owners stay valid on
purpose**) is Albert Hazan's public AI toolkit repo. Not a deployed product. It
owns the always-loaded instruction files every AI session reads at startup
(`templates/system/CLAUDE-global.md` becomes `~/.claude/CLAUDE.md`;
`templates/system/AGENTS-global-codex.md` becomes `~/.codex/AGENTS.md`), the
skills library, the `bin/` wrappers, the context-audit tool, and the test
suites. Users: Albert plus every AI session on `edge-dev` (Windows, primary),
`al8960ofc` and `t16` and `916` (Windows), and `hetz` (Ubuntu VPS). Work lands
on `main` through a pull request that **the session itself merges** — Albert
does not merge. The repo uses a **merge queue**.

## 2. What we set out to do this session, and why

The session was asked to finish the completion-honesty rollout: merge the open
pull request, adopt the rewritten globals on every reachable machine, and close
out. That is done (§3).

The line-endings work was **not** planned. It surfaced when Albert ran the adopt
command on t16 from a PowerShell prompt and got:

```
: invalid option name line 42: set: pipefail
```

Business goal behind both: Albert must never be told a job is finished when it
is not, and the tool that installs that rule must actually run on his machines.

## 3. Current state — what is true right now

**Done and verified:**

- **PR [#101](https://github.com/popcre/ai-devops/pull/101) merged to `main` as
  `e29ef92`.** It carries the rewritten closeout contract in both globals, the
  `completion honesty` safety marker plus three parity rules in
  `tools/context-audit/context-audit.py`, `bin/ai-completion-check-hook` and its
  installer, and `tools/completion-eval/`.
- **Globals adopted** with `bin/ai-adopt-globals` on **edge-dev**,
  **al8960ofc**, and **hetz** — the last for BOTH its `ai` and `root` accounts,
  which keep separate copies of `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.
  Every run printed `installed body matches the repo template exactly`, and
  `grep -c "Account for the whole job"` returns 1 for both globals on all of
  them. No machine had a machine-specific section to preserve.
- **The Claude `Stop` hook is live on `edge-dev` only.** It was never installed
  on the others; that was true before this session and is unchanged.
- **`.gitattributes` and `tests/test-line-endings.sh` are committed** on branch
  `claude/fix-script-line-endings` (commit `177b0e7`). The test passes 6 of 6
  here and was proven to fail when the `bin/**` rule is removed.

**Committed but NOT yet merged:**

- **PR [#118](https://github.com/popcre/ai-devops/pull/118)** — documentation
  closeout of the completion-honesty plan; deletes that plan's handoff. Two of
  three checks green, `windows-offline` still running when this file was
  written. **Auto-merge is enabled**, so it should land unattended. **Verify it
  actually merged** — `gh pr view 118 --json state` must say `MERGED`.
- **Branch `claude/fix-script-line-endings`** — the line-endings fix. See §6
  step 1 for its state at the time of writing.

**NOT done, and nobody may claim otherwise:**

1. **`t16` and `916` still run the OLD completion-honesty text.** t16 is online
   over Tailscale but runs no SSH server; 916 has been offline. Neither was
   reached at any point in this session.
2. **Every checkout made before `177b0e7` still has CRLF Bash scripts,**
   including `C:\repos\ai-devops` on `edge-dev` and on `al8960ofc`. The
   attribute cannot fix a checkout that already happened.

## 4. Everything we tried that did NOT work

- **`gh pr merge 101 --squash --delete-branch`** — refused; the repo has a merge
  queue. Plain `gh pr merge <n>` is the route, then let the queue take it. The
  queue deletes the branch itself, so a later `git push origin --delete` also
  failed, harmlessly.
- **Merging PR #101 while other sessions were landing work.** `main` moved twice
  during the wait, and each time the branch went `DIRTY` and needed `main`
  merged in and a fresh ~50-minute CI cycle. Six CI cycles were spent in total.
  **If you are merging into this repo, merge promptly once green** — a long poll
  invites a conflict.
- **`git grep -P '\r$' HEAD -- <files>` to detect committed CRLF.** Looks
  correct and is **wrong**: `git grep` re-applies the checkout conversion, so it
  reported all 111 scripts as CRLF when every one is stored as LF. Replaced with
  `git ls-files --eol`, which reports index (`i/`) and working-tree (`w/`)
  endings separately in one pass.
- **A `git cat-file --batch` plus `awk` version of the same check.** The `awk`
  program broke on embedded newlines in its `-v` argument and the suite still
  printed `ok` — a silently passing check, which is the exact failure class this
  work exists to kill. Do not reintroduce it.
- **A per-file `git show HEAD:<file> | grep $'\r'` loop.** Correct but slow —
  about 90 seconds on Windows for 111 files, on a suite that runs on every push.
- **`ssh hetz`** — `Host key verification failed`: the bare alias is not what
  the known-hosts entry is recorded under. Key auth then failed from `edge-dev`
  for every user tried (`ahazan`, `ai`, `root`). **hetz was reached through the
  `devops-mcp` MCP instead** (`run_command`), which has root access. Resolve the
  exact alias from the private machine atlas (`ai-private-config path
  machine_atlas`), never from this file — concrete topology must not be written
  into this public repo.
- **`ssh t16`** — tried by alias, by address, and by fully-qualified name; all
  `Connection timed out`. t16 runs no SSH server. Only `al8960ofc` (host alias
  `4837`) accepts SSH between dev machines.
- **Quoting `bash -lc "…"` inside single quotes over SSH to Windows.** The
  remote default shell is `cmd.exe`, which mangles it — one attempt produced
  `'machine' is not recognized as an internal or external command`. Use
  `ssh 4837 'bash -lc "…"'` (outer single, inner double) and redirect output to
  a local file to filter it.

## 5. Root causes and key findings

- **F1 — no `.gitattributes` plus `core.autocrlf=true` equals every Bash script
  corrupted on checkout.** Verified with `git ls-files --eol`: before the fix
  this checkout reported `i/lf w/crlf` for all 111 shell scripts — stored
  correctly, checked out wrongly.
- **F2 — the failure is invisible under Git Bash and fatal under WSL bash.**
  Git Bash tolerates the trailing carriage returns; WSL's `bash` does not. On
  these Windows machines `bash` invoked from PowerShell is **WSL's** bash (the
  machine atlas records this), which is why the same command worked in every AI
  session and failed the moment Albert ran it from a PowerShell prompt. **A
  session testing only in Git Bash will conclude, wrongly, that the script is
  fine.**
- **F3 — `git grep` is not a line-endings oracle.** It applies the checkout
  conversion. `git ls-files --eol` is. (§4.)
- **F4 — an attribute is not a repair.** `.gitattributes` governs future
  checkouts only. Existing clones stay CRLF until renormalised, which is why
  `tests/test-line-endings.sh` checks the working tree separately from the index
  and prints the repair command when it finds a stale one.
- **F5 — the merge queue re-runs the full suite,** so a flaky test costs a whole
  extra ~50-minute cycle and silently dequeues the pull request. That is what
  happened to PR #101 (§0 item 3).
- **F6 — hetz keeps two independent sets of globals** (`/home/ai` and `/root`).
  Adopting only one leaves half the machine on the old rule. Both were done;
  keep doing both.

## 6. Exact next steps

1. **Push `claude/fix-script-line-endings` and open its pull request** if that
   has not already happened — check with
   `gh pr list --head claude/fix-script-line-endings`. Commit `177b0e7` adds
   `.gitattributes` and `tests/test-line-endings.sh`.
   *You'll know it worked when:* all three checks are green and
   `gh pr view <n> --json state` says `MERGED`. Merge it yourself — Albert does
   not merge. Expect ~50 minutes for `windows-offline`; merge promptly once
   green, or `main` will move under you (§4).

2. **Confirm PR #118 merged.** It had auto-merge enabled.
   *You'll know it worked when:* `gh pr view 118 --json state` says `MERGED`. If
   it was dequeued by the flaky reviewer tests (§0 item 3), just re-run
   `gh pr merge 118` — do not debug those tests.

3. **Renormalise the checkouts that predate the fix.** On `edge-dev` and
   `al8960ofc`, in `C:\repos\ai-devops`, **after** confirming nothing is
   uncommitted (other sessions work in these checkouts — check
   `git status --porcelain` first and stop if it is not empty):
   ```bash
   git rm --cached -r -q . && git reset --hard
   ```
   *You'll know it worked when:* `bash tests/test-line-endings.sh` prints
   `6 passed, 0 failed`, including `this checkout has the scripts as LF`.

4. **Adopt the globals on `t16`.** It needs someone at the keyboard, or SSH
   enabled first (§0 item 1). Renormalise its checkout per step 3, then run
   `bash bin/ai-adopt-globals` **from Git Bash**, not from PowerShell (§5 F2).
   *You'll know it worked when:* the run prints `DONE. Both globals adopted` and
   `grep -c "Account for the whole job" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md`
   returns 1 for both.

5. **Adopt the globals on `916`** the same way, once it is online.
   `tailscale status | grep 916` shows whether it is reachable.
   *You'll know it worked when:* same gate as step 4.

6. **Close out.** When steps 4 and 5 are both done, update issue
   [#119](https://github.com/popcre/ai-devops/issues/119), delete **this** file,
   and say which machines were reached. If a machine is still unreachable,
   **name it** rather than implying full coverage.

## 7. Constraints and gotchas in force

- Public repo — no secrets, no private paths, no concrete machine topology. Run
  `bash tests/test-public-boundary.sh`.
- Branch, then pull request, then **the session merges it**. The
  `'main' is already used by worktree` error from `gh pr merge` fires *after* a
  successful merge; confirm with `gh pr view <n> --json state`.
- `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>` before the first commit.
- Concurrent sessions edit this repo, including the shared `C:\repos\ai-devops`
  working copy. Stage only your own files, never `git add -A`, never bare
  `git stash` or `git stash pop`.
- **Do not run `bin/ai-adopt-globals` from a linked worktree** — its launcher
  step refuses with `Refusing to install durable machine launchers from linked
  worktree`. The globals are still adopted when that happens; only the launcher
  reconcile is skipped. Run `bin/install-machine-tools.ps1` from the canonical
  checkout afterwards.
- `installed source drift: 2` is SUCCESS on a machine that has a machine
  section. These machines have none, so it reads 0.
- `.ps1` files must be pure ASCII. Bash suites in Git Bash, PowerShell suites in
  `pwsh`.
- Preserve the capability: if the new line-endings test is inconvenient, fix the
  checkout — do not delete the test.

## 8. Access and environment

Repo `popcre/ai-devops` (public; the `u2giants` remote still redirects and
**both owners stay valid on purpose** — never delete the `u2giants` entry from
`config/repo-identities.tsv`). Working copy `C:\repos\ai-devops` on `edge-dev`;
this session used the worktree
`.claude/worktrees/completion-honesty-enforce-0c2a1a`.

Authenticated and available from `edge-dev`: `gh` as `u2giants`; SSH to
`al8960ofc` via the `4837` host alias; the `devops-mcp` MCP for `hetz` (root
access — use `run_command`, and `su - ai -c '…'` for the `ai` account); the
1Password CLI and MCP, vault `vibe_coding` — **no secret is needed for any step
in this handoff**. `t16` and `916` are NOT reachable from here.

Run `py -3 tools/context-audit/context-audit.py`, `bash tests/test-all.sh`, and
`pwsh tests/test-all.ps1` from the repo root. Note `python3` is not on PATH on
`edge-dev`; use `py -3`. Nothing here is deployed — "shipped" means merged to
`main` with suites green and the installed globals updated.

## 9. Open questions and risks

- **Risk: renormalising a shared checkout destroys another session's
  uncommitted work.** `git reset --hard` is unconditional. Step 3 gates on
  `git status --porcelain` being empty for that reason. If it is not empty, stop
  and say so rather than guessing whose work it is.
- **Risk: the new test fails on every stale checkout until step 3 is run.** That
  is deliberate — the scripts genuinely are broken there — but it will look like
  a regression to a session that has not read this file. The failure message
  names the repair command.
- **Open question: are other repos affected?** The same `core.autocrlf=true`
  applies machine-wide, so any repo of Albert's with Bash scripts and no
  `.gitattributes` has the same latent bug. Not checked. Not scheduled.
- **Decision recorded 2026-08-27:** CI path filtering for documentation-only
  pull requests was **not** implemented here. It belongs to issue #98, which has
  an active handoff and an owner, and changing `verify` from two places at once
  would collide. Two traps make it non-trivial: whatever is skipped must still
  be satisfiable for the `merge_group` event or a queued pull request waits
  forever for a check that never starts, and required checks are matched by
  name, so silently skipping a required job blocks the merge instead of speeding
  it up.
- **Decision recorded 2026-08-27:** the completion-honesty rewrite rests on
  Albert's lived evidence, never on measurement. Do not describe it as proven,
  and do not reopen step 10 of the closed plan.
