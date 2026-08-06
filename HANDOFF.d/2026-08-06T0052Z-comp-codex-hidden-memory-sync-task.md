# HANDOFF — hidden Windows memory sync task (2026-08-06 00:52 UTC, comp/codex)

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's private GitHub toolkit for restoring and
keeping his AI coding setup consistent across Windows and Ubuntu computers. It is
made of PowerShell and Bash setup scripts, documentation, skills, and tests. It
is not a hosted application. This work affects the Windows setup script
`bin/setup-machine.ps1` and the `ai-memory-sync` Scheduled Task it installs.

## 2. What we set out to do this session, and why

Albert reported that an empty Windows Terminal window opened periodically and
stayed open. The screenshot identified Git Bash at
`C:\Program Files\Git\bin\bash.exe`. Repository inspection proved that
`setup-machine.ps1` registered `ai-memory-sync` to launch that executable every
30 minutes. The goal was to keep the sync automatic while preventing any visible
terminal and bounding a stalled run.

## 3. Current state — what is true right now

- `bin/setup-machine.ps1:635` now creates
  `%USERPROFILE%\.config\ai-devops\ai-memory-sync-hidden.vbs`.
- The VBScript uses the GUI-based `wscript.exe` host and starts Git Bash with
  window style `0`, which is hidden.
- `bin/setup-machine.ps1:656` limits each run to 15 minutes and uses
  `IgnoreNew`, so a second sync cannot overlap a running one.
- `tests/test-memory-sync-scheduled-task.ps1` checks the launcher, time limit,
  overlap rule, task registration, removal of the old `schtasks` command, and
  PowerShell parsing.
- `docs/development.md` lists the new test and `docs/onboarding-secrets.md`
  explains the Windows behavior.
- The Bash memory-sync regression test and `git diff --check` passed on `comp`.
- This Ubuntu session has no `pwsh` and no Windows bridge, so the PowerShell test
  and live Task Scheduler behavior could not be run here.
- The affected Windows computers still have the old visible task until they pull
  this commit and run their normal setup once. New computers will receive the
  fixed task automatically from the current setup script.
- Target repository and branch are `u2giants/ai-devops`, `main`. The fix is
  committed and pushed as `3773a49534769ccf33f2e5e158e8f3b9c9e1514d`.
  GitHub was queried directly and returned that SHA, Albert's correct noreply
  identity, and commit message `fix: hide Windows memory sync task`.

## 4. Everything we tried that did NOT work

1. The original implementation used `schtasks /Create` with Git Bash as the task
   action. That looked simple, but Windows Terminal is the default console host,
   so every run created the visible empty window. A stuck Git operation left it
   open indefinitely.
2. The first attempt to run the new PowerShell regression test on `comp` failed
   because `pwsh` is not installed on this Ubuntu host. This does not show a code
   failure; it means Windows or a host with PowerShell 7 must run that gate.
3. The first push preparation found this checkout 784 commits behind
   `origin/main`. The fix was stashed, `main` was updated with a fast-forward,
   and the stash reapplied. Code and docs merged cleanly. The old root handoff
   conflicted because the repository had since migrated to write-once files in
   `HANDOFF.d/`; the new pointer was preserved and this separate handoff was
   created as required.

## 5. Root causes and key findings

- The sync itself was not the reason a terminal existed. The cause was directly
  registering a console program, Git Bash, as the Scheduled Task action.
- Hiding output inside Bash is not enough because Windows creates the console
  before Bash handles redirection. A GUI host, `wscript.exe`, avoids creating a
  terminal at all.
- Hiding the window alone would conceal a permanent hang. Task Scheduler's
  15-minute execution limit stops a stalled task tree, while `IgnoreNew` prevents
  repeated hidden copies from building up.
- The setup script is the correct source of truth. Existing computers need one
  setup run to replace their stored task; new computers need no special step.

## 6. Exact next steps

1. On every existing Windows computer, pull the pushed `main` commit through the
   normal dotfiles sync or `git -C C:\repos\ai-devops pull --ff-only`.
   **Gate:** `git -C C:\repos\ai-devops rev-parse HEAD` is at or after
   `3773a49534769ccf33f2e5e158e8f3b9c9e1514d`.
2. Run `pwsh -NoProfile -File
   C:\repos\ai-devops\tests\test-memory-sync-scheduled-task.ps1`.
   **Gate:** it prints `PASS: Windows memory sync scheduled task is hidden and bounded`.
3. Run `pwsh -NoProfile -ExecutionPolicy Bypass -File
   C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops` once.
   This setup script also checks and updates the machine's other managed AI
   configuration.
   **Gate:** it prints `Scheduled task 'ai-memory-sync' every 30 min (hidden; 15 min limit)`.
4. In Task Scheduler, confirm the `ai-memory-sync` action starts
   `C:\Windows\System32\wscript.exe`, then either run the task manually or wait
   for its next 30-minute trigger.
   **Gate:** the task completes without opening Windows Terminal, and
   `%USERPROFILE%\.cache\ai-memory-sync.log` receives a new timestamped entry.

## 7. Constraints and gotchas in force

- This repository commits directly to `main` under the standing repo rule.
- Git identity must remain `Albert Hazan <u2giants@users.noreply.github.com>`.
- Do not edit the Scheduled Task by hand as the lasting fix. Re-run the
  repo-owned setup script so future setup remains repeatable.
- Do not remove automatic memory sync. The hidden launcher changes presentation
  and safety limits, not sync behavior.
- Do not edit the root `HANDOFF.md` pointer or another session's file in
  `HANDOFF.d/`.

## 8. Access and environment

- Working checkout: `/root/ai-devops` on Ubuntu host `comp`.
- GitHub CLI is authenticated as `u2giants`; remote is
  `https://github.com/u2giants/ai-devops.git`.
- Branch: `main`, updated to remote base `6e736c8` before the fix was committed.
- Commit identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- No secrets or 1Password access were needed. This work contains no credential.
- No Windows host was reachable from this session, and `pwsh` is not installed
  on `comp`.

## 9. Open questions and risks

- Live Windows behavior remains to be verified on the first existing computer.
  The design uses standard Windows Task Scheduler and Windows Script Host parts,
  but static Linux-side checks cannot prove the real desktop stays quiet.
- The scheduled task uses an interactive user identity, matching the old task's
  user context. It therefore runs when that user is logged on, which is the
  intended time for Claude memory sync.
- A 15-minute limit was chosen because a normal memory sync should finish much
  sooner. A very slow first clone could hit the limit; the next scheduled run
  retries safely from the isolated cache.

## Self-audit

1. Yes, a new developer can continue without questions. Sections 1–3 define the
   toolkit, bug, files, behavior, and exact state; section 6 gives runnable steps.
2. Yes, they can continue as effectively as this session. Sections 4–5 preserve
   the stale checkout, handoff conflict, missing PowerShell test environment,
   root cause, and design choices.
3. Yes, failed attempts and their causes are included in section 4.
4. Yes, every next step is concrete and has a visible success gate in section 6.
5. Yes, unfamiliar paths, task names, tools, repo, branch, and access are defined
   in sections 1, 3, 6, and 8.

Final synthesis:

1. **Is my `HANDOFF.d/` file comprehensive enough that a brand-new developer with
   no knowledge of this project and no context about what we did or what remains
   could pick up where I left off and not skip a beat?** Yes. Sections 1–9 cover
   the full background, implementation, proof, failure history, rollout, and risk.
2. **Is it detailed enough that they could continue as well as I could right
   now, with all my knowledge from this session and all relevant background about
   what we are trying to accomplish?** Yes. Sections 3–6 preserve every material
   fact and give exact commands and gates.
3. **Is every single relevant detail—background, goals, intended outcome,
   current state, failed attempts, decisions, constraints, risks, exact next
   actions, and verification evidence—present for the implementing agent to
   execute flawlessly?** Yes. These map to sections 1–2, 2, 3–5, 7, 9, 6, and 3.
   No gap remains in this handoff.
