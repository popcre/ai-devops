---
issue: 42
status: BLOCKED
owner: codex/finish-windows-setup-42
---

# HANDOFF — finish Windows setup after Codex restart (2026-08-18 19:57 UTC, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Albert only needs to fully quit Codex before a fresh session performs §6. Do not ask him to reconsider the completed Kimi or SSH work.

Already settled, do not re-ask:

- 2026-08-18: Kimi Windows reliability is complete, installed, live-tested, and issue 31 is closed.
- 2026-08-18: verified SSH server keys are merged and installed through PR 41.
- The remaining failure is only a file lock held by the running Codex app.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for installing AI coding tools, skills, settings, SSH access, and reviewer wrappers. On this Windows machine the canonical checkout is `C:\repos\ai-devops`; `bin/setup-machine.ps1` installs the machine configuration.

## 2. What we set out to do this session, and why

Implement and finish `plan_kimi-windows-execution-reliability.md`, then investigate and merge the unrelated work that prevented the canonical checkout from updating. The session also completed the normal Windows installer so Kimi could be verified from its real installed launcher.

## 3. Current state — what is true right now

- `main` and `origin/main` match at `2d1a3088df333354b23d063299dbefeb45677532`.
- Kimi implementation merged in PR 37. The installed launcher points to `C:\repos\ai-devops\bin\ai-kimi`; local and remote source share blob `526ec66ed7b1880f3b2f457cdff3fc1c41353836`.
- Installed `AI_KIMI_CALLER=codex ai-kimi doctor --live` passed on Kimi 0.36.1. The authenticated suite passed 174 checks with zero failures. Issue 31 is closed.
- Shared-database finish-first planning was already on GitHub. Its apparent dirty files came from a stale local checkout, not unsaved unique work.
- Windows SSH known-host work merged in PR 41 as merge commit `39900c704e60f4e0a583f5731434286a90fa75bd`. All 12 public keys matched the machine's previously trusted entries; four reachable private hosts also matched live. The installer registered all 12 without changing them.
- The primary checkout was reconciled and pushed. Only the pre-existing untracked `.ai/` review-artifact directory remains; do not commit it.
- `setup-machine.ps1` completed Kimi, SSH, skills, launchers, Claude settings, memory scheduling, and other steps. It exited 1 at `bin/configure-codex-mcps.ps1:153` because this running Codex app held `C:\Users\ahazan\.codex\config.toml` open.
- Issue 42 tracks the one remaining action: rerun setup after fully quitting Codex.
- A recovery stash remains: `stash@{0}: recovery: shared-db plan files already merged before primary sync 2026-08-18`. Its files were verified on GitHub before the primary merge. Keep it until the fresh session confirms setup success, then drop it.
- Merged temporary worktrees remain for the Kimi and Windows SSH branches. Other listed worktrees belong to other active workstreams and must not be touched.

## 4. Everything we tried that did NOT work

1. Initial Kimi live tests retained the offline fake Kimi home and 15-second timeout. They produced false failures and a possible false-green hostile-write result. The live harness now restores the real protected home, uses a bounded 300-second ceiling, requires successful provider output, and passed 174 checks.
2. The first waiter-death test killed a surrounding shell instead of the actual waiter. It now uses `exec bash`; the authenticated worker survived the real waiter termination and returned its result to a replacement waiter.
3. The SSH sync originally could overwrite its one backup repeatedly during a multi-key run. It now creates exactly one millisecond-named pre-update backup; a test proves the backup retains the original file.
4. A direct primary-checkout merge produced four document conflicts because five old local commits overlapped newer GitHub versions. Each conflict was inspected; GitHub had the newer completed truth, so those versions were selected. The reconciliation merge was pushed safely.
5. The final completion push was briefly rejected because another session updated GitHub first. The documentation commit was rebased onto the new main and pushed as `2d1a308`.
6. The normal setup run could not write Codex's own settings while Codex was running. Retrying inside this same task would hit the same lock; Codex must be fully quit first.

## 5. Root causes and key findings

- The “other work” was two workstreams: shared-database planning already merged remotely, and genuine unmerged Windows SSH setup changes.
- Windows launchers use absolute paths into the canonical checkout, so installation must run from `C:\repos\ai-devops`, never a temporary linked worktree.
- SSH identity updates must preserve unmanaged entries, stop if an old-key removal fails, and keep one original pre-run backup. `bin/sync-ssh-known-hosts.ps1` now does so and its second run is test-proven idempotent.
- Codex locks `C:\Users\ahazan\.codex\config.toml` while running. This is the only reason the installer did not return zero.

## 6. Exact next steps

1. Fully quit every Codex window and confirm no Codex process is holding `C:\Users\ahazan\.codex\config.toml`. Start a fresh Codex session afterward. You'll know it worked when the setup command in step 2 can write the file without “used by another process.”
2. Run `pwsh -ExecutionPolicy Bypass -File C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops`. You'll know it worked when the command exits 0 and reaches the final success output without a `Set-Content` lock error.
3. Run `$env:AI_KIMI_CALLER='codex'; ai-kimi doctor --live`. You'll know it worked when preflight, authentication, and live probe report PASS/OK on Kimi 0.36.1.
4. Verify `git -C C:\repos\ai-devops status --short --branch` shows `main...origin/main` with no source changes. Ignore only the known `.ai/` review artifacts. You'll know it worked when local and remote HEAD match.
5. Using the `cleanup-worktree` skill, review and remove only the merged Kimi and Windows SSH temporary worktrees/branches. Do not touch the POP business-rules, Kimi orchestrator-opinion, or shared-db-plan worktrees without their owners' evidence. You'll know it worked when the two completed worktrees no longer appear in `git worktree list` and their merged commits remain on main.
6. Confirm every file in recovery `stash@{0}` is already present or superseded on `origin/main`, then drop only that stash. You'll know it worked when `git stash list` no longer contains the named 2026-08-18 recovery stash and no source diff appears.
7. Close issue 42, delete this handoff under the successor rule, commit, push, and verify GitHub main. You'll know it worked when issue 42 is closed, this file is absent from `origin/main`, and git history preserves it.

## 7. Constraints and gotchas in force

- Do not edit `config.toml` manually while Codex runs. Rerun the managed installer after quitting the app.
- Do not weaken Kimi-home permissions, copy OAuth files, or call Kimi directly; use `ai-kimi` with `AI_KIMI_CALLER=codex`.
- Do not remove worktrees or branches without the `cleanup-worktree` skill and merged-work proof.
- Do not touch another session's handoff or worktree.
- Do not commit `.ai/` review artifacts or raw transcripts.
- Do not use reset-hard or overwrite unreviewed work.

## 8. Access and environment

- Machine: `edge-dev`, Windows 11, PowerShell 7 and Git Bash.
- Repository: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- GitHub CLI is authenticated as `u2giants`.
- Kimi OAuth is valid in its protected home; no credential value was read or recorded.
- 1Password remains vault `vibe_coding`; this session created or changed no secret.
- GLM reviewed the SSH exact head read-only and approved with no Critical, High, or Medium findings.

## 9. Open questions and risks

- No product or owner decision is open.
- The only blocker is the running Codex process's file lock. A future installer failure with a different message must be diagnosed rather than treated as the same issue.
- The recovery stash is intentionally retained for one more session. It is believed redundant, but dropping it is destructive and must follow the verification in §6.
- Several other worktrees are active. Their presence is not evidence they are stale; touch only the two completed worktrees named in §6.

## Mandatory self-audit

1. Yes. Sections 1–3 define the toolkit, goal, exact commits, installations, blocker, and repository state; §6 gives literal commands and success gates.
2. Yes. Sections 4–5 preserve every failed attempt and the non-obvious Kimi, SSH-backup, concurrent-Git, launcher-path, and file-lock findings.
3. Yes. Section 4 records failures and why they failed; §§2–3 and 5–9 cover background, outcome, current state, decisions, constraints, access, risks, and next actions.
4. Yes. Every numbered step in §6 has an observable success condition.
5. Yes. Sections 1, 3, 6, and 8 define all paths, issue numbers, commits, commands, and environments required by a newcomer.
6. Yes. A line-by-line sweep of §§1–9 found no decision requiring Albert beyond quitting Codex, which is an action rather than a judgment. Section 0 states that and preserves settled decisions.

Final synthesis:

1. Yes, this handoff is comprehensive enough for a new developer; §§1–9 carry the entire state and executable continuation.
2. Yes, the next session can continue as effectively as this one; §§4–5 preserve all material learning and failed paths.
3. Yes, every relevant background fact, goal, result, failure, constraint, risk, command, and verification gate is present.
4. Yes, if Albert reads only §0 he sees that no decision is required and that he only needs to quit Codex before the managed rerun.
