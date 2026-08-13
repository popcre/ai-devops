# IMPLEMENTATION PLAN — Make dotfiles sync reconcile local AI wrappers (2026-08-13)

## STATUS

| Step | Status | Date | Evidence |
|---|---|---|---|
| 1. Add one machine-tool doctor | ⬜ open | 2026-08-13 | §9.1; not implemented |
| 2. Keep platform repair in existing installers | ⬜ open | 2026-08-13 | §9.2; not implemented |
| 3. Wire both sync skills to check, repair, and re-check | ⬜ open | 2026-08-13 | §9.3; not implemented |
| 4. Add regression tests | ⬜ open | 2026-08-13 | §9.4 and §10; not implemented |
| 5. Update docs and reconcile this computer | ⬜ open | 2026-08-13 | §9.5; not implemented |
| 6. Commit, push, and verify a clean sync | ⬜ open | 2026-08-13 | §9.6; not implemented |

**Fresh-session starting point:** Start at §9.1 after reading §§1–8. This plan is registered by [HANDOFF.d/2026-08-13T1958Z-al8960ofc-codex-sync-wrapper-reconciliation-plan.md](HANDOFF.d/2026-08-13T1958Z-al8960ofc-codex-sync-wrapper-reconciliation-plan.md).

## 1. The ultimate goal — what we are trying to achieve

When Albert says “sync my dotfiles,” the computer must finish with every repo-owned AI command that the synced skills tell an agent to use. The sync must check real commands on the computer, install or repair missing commands, and refuse to report success if they still do not work. This must be true whether Claude or Codex handles the request and whether the computer runs Windows or Ubuntu.

The immediate failure is that `ai-grok-review` and `ai-grok-implement` existed in `C:\repos\ai-devops\bin` and on GitHub but were absent from this Windows computer’s command path after a reported successful sync. The fix must cover this class of failure, not only two filenames.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan’s public backup-and-restore toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell tools, setup scripts, skills, docs, and tests. It is not a hosted app. The repo is `C:\repos\ai-devops`, branch `main`; GitHub is the source of truth.

Relevant parts:

- `bin/ai-grok-review` and `bin/ai-grok-implement`: safe Grok wrappers.
- `bin/ai-kimi`: Kimi wrapper in the same local-command family.
- `bin/ai-glm`: GLM wrapper, with a separate mandatory service-health check.
- `bin/setup-machine.ps1`: Windows installer; writes extensionless Git Bash shims and `.cmd` PowerShell shims into `%USERPROFILE%\.local\bin`.
- `install.sh`: Ubuntu installer; symlinks executable files from `bin/` into `/usr/local/bin`.
- `skills/claude/sync-dotfiles/SKILL.md` and `skills/codex/codex-sync-dotfiles/SKILL.md`: the two “sync my dotfiles” procedures.
- `tests/`: local Bash and PowerShell tests. This repo has no GitHub Actions workflow or hosted deployment.

On this Windows computer, `grok.exe` is installed under `%USERPROFILE%\.grok\bin` and authenticated. The repo wrappers work by explicit repo path. Plain `ai-grok-review` and `ai-grok-implement` do not currently resolve in PowerShell or Git Bash.

## 3. What triggered this work

On 2026-08-13 Albert asked to sync dotfiles and then asked whether Grok was pinned to 4.6. The sync was reported complete. The Grok wrappers were changed and pushed in commit `4731240`, but a later real command-path check showed:

- PowerShell `Get-Command ai-grok-review` and `Get-Command ai-grok-implement` failed.
- Git Bash `command -v ai-grok-review` and `command -v ai-grok-implement` failed.
- Calling `bin/ai-grok-review doctor` by repo path worked and reported `model: grok-4.6`.

Reproduce on this computer:

```powershell
Get-Command ai-grok-review
Get-Command ai-grok-implement
& 'C:\Program Files\Git\bin\bash.exe' -lc 'command -v ai-grok-review; command -v ai-grok-implement'
```

Before the fix, all lookups fail even though the source files exist.

## 4. Scope — in and out

In scope:

- One executable, testable check for repo-owned delegate commands required after sync.
- At minimum reconcile `ai-grok-review`, `ai-grok-implement`, and `ai-kimi`; keep GLM’s deeper health check separate while reporting whether `ai-glm` resolves.
- Make both sync skills call the same check, repair missing commands through existing platform installers, re-check, and fail loudly if repair fails.
- Cover Windows PowerShell, Windows Git Bash, and Ubuntu.
- Add regression tests and update the config inventory, deployment docs if needed, skills, router, plan status, handoff, and memory pointer.
- Run the repaired path on `al8960ofc` and prove the installed Grok wrapper uses 4.6.

Not in this plan:

- Changing Grok permissions, sessions, worktrees, turn limits, completion rules, or the 4.6 pin.
- Installing or logging into third-party provider CLIs when they are absent. Wrapper installation and provider login are separate states.
- Refactoring all setup code, changing secret/MCP/SSH behavior, adding CI, touching production, or changing a database.
- Touching existing unrelated `.ai/` or `docs/claude-remote-control-hardening-v2.md` files.

## 5. Current state of the code

- `bin/setup-machine.ps1:633-668` already installs both Grok wrappers for PowerShell and Git Bash. Its shims point to repo source, so later source updates need only a pull.
- `docs/config-inventory.md:53` says Windows setup installs both launchers.
- `install.sh:90-116` already symlinks every executable repo command into `/usr/local/bin` on Ubuntu.
- `skills/claude/sync-dotfiles/SKILL.md:51-86` and `skills/codex/codex-sync-dotfiles/SKILL.md:46-75` run platform setup only when Phase 2 secret, MCP, SSH, or Codex-PATH wiring is missing.
- Both skills separately run `ai-glm doctor` because a pull cannot create machine-local GLM state.
- Neither skill checks Grok or Kimi commands on the real command path.
- `tests/test-windows-ai-kimi-shim.ps1` checks the Kimi shim. There is no equivalent Grok-shim test and no test that a sync checks installed commands.
- The Grok 4.6 pin is committed and pushed on `main` at `4731240`. No implementation from this plan exists yet.

## 6. Key findings and root cause

1. **Root cause:** sync success is gated by Phase 2 wiring, not the full machine state promised by the skill. When Phase 2 is current, setup is skipped even if later-added local commands are absent.
2. **Windows installer logic already exists:** `bin/setup-machine.ps1:633-668` is capable; sync never asks whether it needs to run.
3. **Source presence is not installed-command presence:** an explicit repo path can work while the plain command taught by a skill fails.
4. **Windows has two command surfaces:** setup creates both PowerShell `.cmd` and Git Bash extensionless shims; both need verification.
5. **Ubuntu has a different owner:** `install.sh` owns `/usr/local/bin` symlinks. `setup-secrets.sh` must not become a second entrypoint installer.
6. **A prose-only list will drift:** Kimi, GLM, and Grok arrived at different times. One executable doctor must own the required-command list.
7. **The old report gave false assurance:** the sync claimed full state without checking Grok commands. The final gate must make this impossible.

## 7. Approaches considered and REJECTED, and why

1. **Two `command -v` lines in each skill:** rejected because duplicated command lists will drift again.
2. **Always run full setup on every sync:** rejected because setup has broader effects, including secret/MCP rewrites, restart implications, GLM setup, and possible `sudo` prompts.
3. **Put repo `bin/` directly on PATH:** rejected because Windows shims deliberately pin the correct Windows home and Git Bash executable.
4. **Copy wrappers to a machine-local folder:** rejected because copies drift. Current shims point to repo source, so a pull picks up fixes.
5. **Make `setup-secrets.sh` install Ubuntu commands:** rejected because secrets and `/usr/local/bin` have separate owners.
6. **Treat provider absence as wrapper failure:** rejected because an installed wrapper and an optional logged-out provider are different states.

## 8. Design decisions already made (2026-08-13)

Locked:

- Add one repo-owned, read-only machine-tool doctor; do not maintain separate canonical lists in both skills.
- Repair stays owned by `setup-machine.ps1` on Windows and `install.sh` on Ubuntu.
- Sync succeeds only after a final doctor run returns zero.
- Check ordinary command resolution, not only source files.
- Verify PowerShell and Git Bash on Windows.
- Keep provider auth and GLM service checks separate from wrapper installation.
- Preserve every Grok STEP 0 safety rule; do not change wrapper runtime behavior.

Open implementation judgment:

- Name the doctor `bin/ai-machine-tools-doctor` or an equally clear `ai-*` name, then use the chosen name consistently.
- It may cover every required user-facing `ai-*` command or only delegate wrappers. Prefer broader coverage only if optional commands can be classified without false failures. Minimum: Grok, Kimi, and the `ai-glm` command.
- Windows dual-shell verification may live in the Bash doctor or a small PowerShell companion. Choose the smallest testable design that makes no provider model call.

## 9. The plan — numbered, ordered steps

### Phase 1: One truth source

1. **Add a read-only machine-tool doctor.**
   - Target: new executable under `bin/`, preferably `bin/ai-machine-tools-doctor`.
   - Own the canonical required wrapper list. Classify required repo wrapper, optional provider dependency, and separately health-checked service.
   - On Ubuntu use `command -v`. On Windows Git Bash verify the extensionless shim and matching `.cmd` under the Windows profile. Never read provider credentials.
   - Print one `PASS`, `FAIL`, or `INFO` per command. Exit zero only when every required repo command is installed.
   - Dependency: none.
   - Gate: a complete fixture exits zero; removing either Grok launcher exits nonzero and names it; provider absence is reported separately.

2. **Keep repair in existing installers and make it testable.**
   - Windows: retain `bin/setup-machine.ps1:633-668`. Extract a small internal shim function only if needed for idempotence/testing; do not broaden the refactor.
   - Ubuntu: retain `install.sh:90-116` as the sole `/usr/local/bin` owner.
   - Add a Grok Windows shim test modeled on `tests/test-windows-ai-kimi-shim.ps1` for both wrapper names, both shim forms, pinned `HOME`, Git Bash, and repo-source delegation.
   - Dependency: step 1 defines “installed.”
   - Gate: Windows shim tests pass and an Ubuntu temporary-prefix fixture proves both wrappers are symlinked without source copies.

### Phase 2: Enforce the sync promise

3. **Wire both sync skills to check, repair, and re-check.**
   - Targets: `skills/claude/sync-dotfiles/SKILL.md` and `skills/codex/codex-sync-dotfiles/SKILL.md`.
   - Add “local AI commands” to both sync tables and procedures.
   - Run the doctor by repo path so it works when its installed command is missing.
   - On pass, require “Local AI commands already current.”
   - On Windows failure, run `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-machine.ps1 -RepoPath <repo>` with its existing token precondition and MCP rewrite warning.
   - On Ubuntu failure, run `<repo>/install.sh`, the existing symlink owner.
   - Re-run the doctor. Stop with exact missing commands if it still fails. Never report sync complete.
   - Keep `ai-glm doctor` as the deeper service/model check.
   - Dependencies: steps 1–2.
   - Gate: both skills name the same doctor, both repair paths, a mandatory final check, and incomplete-sync behavior.

4. **Add regression tests for the original failure and drift.**
   - Add `tests/test-ai-machine-tools-doctor.sh` for pass, missing wrapper, optional provider, Windows shim fixture, and exit codes.
   - Add `tests/test-windows-ai-grok-shims.ps1` for generated shim controls.
   - Add a test that both sync skills call the same doctor, repair by platform, re-check, and block false success.
   - Run `tests/test-windows-scripts.sh`, both Grok suites, and `tests/test-ai-kimi.sh`.
   - Dependencies: steps 1–3.
   - Gate: deleting the doctor call from either skill or a Grok shim assertion makes a test fail; all related suites stay green.

### Phase 3: Document, install, and land

5. **Update durable docs and reconcile `al8960ofc`.**
   - Update `docs/config-inventory.md`, `docs/deployment.md` if install verification changes, `AGENTS.md`, both sync skills, this plan, its handoff, and memory pointer.
   - Run the repaired path on this computer.
   - Prove PowerShell `Get-Command` and Git Bash `command -v` for both Grok wrappers.
   - Run installed `AI_GROK_CALLER=codex ai-grok-review doctor`; require `model: grok-4.6` and `auth: OK`. This is free and must not run a model turn.
   - Dependencies: steps 1–4.
   - Gate: both shells resolve both commands and the installed doctor reports 4.6.

6. **Commit, push, and prove a clean sync.**
   - Update STATUS with exact artifact/command evidence. Retire this handoff only after every obligation is complete.
   - Verify `git var GIT_COMMITTER_IDENT` shows `Albert Hazan <u2giants@users.noreply.github.com>`.
   - Stage only this work. Never stage `.ai/` or `docs/claude-remote-control-hardening-v2.md`.
   - Commit on `main`, safely integrate later GitHub commits if needed, push, and verify `main...origin/main`.
   - From fresh PowerShell and Git Bash processes, run the machine doctor and installed Grok doctor again.
   - Dependencies: steps 1–5.
   - Gate: final SHA is on `origin/main`, named tests pass, STATUS cites evidence, and the missing-wrapper fixture cannot report success.

**Context cut:** one session should finish this. If cross-platform repair needs a larger installer refactor, stop after Phase 1, update STATUS and this plan, create a new handoff, and continue Phases 2–3 in a fresh session.

## 10. Tests required

New `tests/test-ai-machine-tools-doctor.sh` cases:

- all required wrappers present returns zero;
- either Grok wrapper missing returns nonzero and names it;
- provider missing is distinct from wrapper missing;
- Windows fixture requires extensionless and `.cmd` shims;
- both sync skills use the doctor, repair, re-check, and block false success.

New `tests/test-windows-ai-grok-shims.ps1` cases:

- setup writes both Grok wrapper names and both shim forms;
- launchers pin Windows `HOME`;
- launchers delegate to repo source through Git Bash.

Existing suites that must remain green:

```bash
tests/test-windows-scripts.sh
tests/test-ai-grok-review.sh
tests/test-ai-grok-implement.sh
tests/test-ai-kimi.sh
```

Parse changed PowerShell with PowerShell’s parser and run `git diff --check`. No live Grok turn is required.

## 11. Constraints, standing rules, and gotchas in force

- Main-only repo. Verify Albert’s noreply identity before committing.
- Preserve unrelated concurrent files. Use `apply_patch`; keep PowerShell ASCII-only.
- Never hard-code `C:\repos\ai-devops`; derive repo paths.
- Never trust Git Bash `$HOME` on Windows; pin `%USERPROFILE%` in launchers.
- Never read `~/.grok/auth.json`, call Grok directly, or spend money for this work.
- Do not change Grok permissions, turns, completion, locks, worktrees, or model pin.
- Do not make provider login a requirement for wrapper installation.
- No silent fallback: final machine-tool failure makes sync fail.
- Do not make `setup-secrets.sh` a second Ubuntu symlink owner.
- Windows setup may rewrite Claude Desktop MCP config; retain its backup and restart warning.
- No UI, database, container, cloud deploy, or production work applies.

## 12. Access and environment

- Repo: `C:\repos\ai-devops`; remote `https://github.com/u2giants/ai-devops`; branch `main`.
- Planning baseline: `4731240` plus later `origin/main` commits pulled by implementation.
- Shells: PowerShell 7 and `C:\Program Files\Git\bin\bash.exe`.
- Grok: `%USERPROFILE%\.grok\bin\grok`, observed version 1.0.3, authenticated. Never inspect its auth file.
- Git and GitHub access are active; verify with real read-only calls before claims.
- If Windows setup lacks its token file: 1Password vault `vibe_coding`, item `vibe_coding-service-account`, field `op_service_account_token`. Never record its value.
- Ubuntu repair may require `sudo`; use existing `install.sh` rather than inventing a privileged command.
- “Deployment” means installation on a computer. There is no hosted runtime.

## 13. Definition of done + risks and open questions

Done means:

- [ ] One read-only doctor owns the required-wrapper list.
- [ ] Both sync skills check, repair by platform, re-check, and fail loudly.
- [ ] Platform installer ownership remains clear.
- [ ] New tests fail on the original missing-Grok-wrapper condition.
- [ ] Existing Grok, Kimi, and Windows tests remain green.
- [ ] This computer resolves both Grok wrappers in PowerShell and Git Bash.
- [ ] Installed `ai-grok-review doctor` reports Grok 4.6 and successful auth.
- [ ] STATUS, handoff, router, docs, skills, and memory reflect reality.
- [ ] Commit uses Albert’s identity, is pushed to `origin/main`, and unrelated files remain unstaged.
- [ ] Handoff is retired only after completion.

Risks and rollback:

- Full setup has broader effects, so the read-only doctor must keep repair conditional.
- PATH changes may require a fresh shell; distinguish stale current process from missing installation.
- Ubuntu `install.sh` may prove too broad. If so, use §8’s open judgment to extract only its existing symlink loop into a shared installer and update this plan before doing it.
- Rollback is reverting the implementation commit. No credentials or production state are changed.

Open questions:

- Cover all installed `ai-*` commands or only delegate wrappers? Choose the smallest set that guarantees no synced skill points to a missing required command without making optional providers failures.
- Should Windows doctor inspect `%USERPROFILE%\.local\bin` as well as launching fresh shells? Do both if current-process PATH caching can hide a correct repair.

## Mandatory self-audit — passed 2026-08-13

1. **Can a new session execute without questions? Yes.** §§2–6 provide repo, symptom, evidence, owners, and root cause. §9 names files, order, behavior, dependencies, and proof gates. §12 defines access and environment.
2. **Does it carry the full reasoning? Yes.** §§6–8 preserve source-versus-installed state, Windows dual shells, Ubuntu ownership, false assurance, rejected approaches, and locked/open decisions.
3. **Is the goal clear enough for judgment calls? Yes.** §1 requires every skill-required command and forbids false success; §§4 and 13 bound scope and give criteria for the Ubuntu choice.

All 13 sections, exclusions, concrete tests, verification gates, constraints, access, rollback, definition of done, and the handoff backlink are present. The checklist passes.
