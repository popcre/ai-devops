# IMPLEMENTATION PLAN — Make dotfiles sync reconcile local AI wrappers (revised 2026-08-13)

## STATUS

| Step | Status | Date | Evidence |
|---|---|---|---|
| 0. Revise the design after Grok 4.6 and GLM 5.2 critiques | ✅ done | 2026-08-13 | This file §§6–10 records the corrected commands-only design and tests |
| 1. Add the shared command catalog and read-only doctor | ✅ done | 2026-08-13 | `config/machine-tools.tsv`; `bin/ai-machine-tools-doctor`; focused suite passes |
| 2. Add small Windows and Ubuntu commands-only installers | ✅ done | 2026-08-13 | `bin/install-machine-tools.ps1`; `bin/install-machine-tools.sh`; idempotence/conflict fixtures pass |
| 3. Reuse the installers from current setup paths | ✅ done | 2026-08-13 | `setup-machine.ps1` calls the catalog installer; `install.sh` unchanged |
| 4. Wire both sync skills and the old-skill bootstrap gate | ✅ done | 2026-08-13 | Both skills repair before install; `ai-install-skills` has dry-run and fail-closed gate |
| 5. Add regression tests | ✅ done | 2026-08-13 | `test-ai-machine-tools.sh`, Windows tests, install-skills, Grok review/implement suites pass |
| 6. Update docs and reconcile this computer | ✅ done | 2026-08-13 | Fresh PowerShell/Git Bash resolve all forms; installed Grok doctor reports 4.6/auth OK |
| 7. Commit, push, and verify a clean sync | ✅ done | 2026-08-13 | Completed by implementation commit recorded in git history; origin verification performed after push |

**Fresh-session starting point:** Start at §9.1 after reading §§1–8. This plan was registered by former handoff `HANDOFF.d/2026-08-13T1958Z-al8960ofc-codex-sync-wrapper-reconciliation-plan.md`.

## 1. The ultimate goal — what we are trying to achieve

When Albert says “sync my dotfiles,” the computer must finish with every repo-owned AI command that the synced skills tell an agent to use. The sync must install or repair missing command launchers, check the real machine state, and refuse to report success if required commands still do not work. This must be true whether Claude or Codex handles the request and whether the computer runs Windows or Ubuntu.

The immediate failure is that `ai-grok-review` and `ai-grok-implement` existed in `C:\repos\ai-devops\bin` and on GitHub but were absent from this Windows computer’s command path after a reported successful sync. The permanent fix must make one catalog drive installation, checking, and tests so the next repo-owned wrapper cannot be forgotten.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan’s public backup-and-restore toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell tools, setup scripts, skills, docs, and tests. It is not a hosted app. The repo is `C:\repos\ai-devops`, branch `main`; GitHub is the source of truth.

Relevant code:

- `bin/ai-grok-review`, `bin/ai-grok-implement`, `bin/ai-kimi`, and `bin/ai-deepseek-agent`: Bash wrappers that synced skills instruct agents to call by plain command name.
- `bin/ai-glm`: GLM session wrapper. Windows installs only `ai-glm.cmd`; its service and configuration remain owned by `bin/setup-opencode-glm.ps1`.
- `bin/setup-machine.ps1`: broad Windows machine setup. Today it separately writes Kimi and Grok launchers under `%USERPROFILE%\.local\bin`.
- `install.sh`: broad Ubuntu setup. Its generic executable loop already symlinks every repo `bin/*` into `/usr/local/bin`; this working fresh-install behavior must remain unchanged.
- `bin/ai-install-skills`: already runs during both old and revised sync procedures after every pull. It is the bootstrap point that can prevent an old installed skill from claiming false success after new repo code arrives.
- `skills/claude/sync-dotfiles/SKILL.md` and `skills/codex/codex-sync-dotfiles/SKILL.md`: the two “sync my dotfiles” procedures.
- `tests/`: local Bash and PowerShell tests. This repo has no GitHub Actions workflow or hosted deployment.

On `al8960ofc`, `grok.exe` is installed and authenticated. Repo-path Grok wrappers work. Plain `ai-grok-review` and `ai-grok-implement` do not resolve. `%USERPROFILE%\.local\bin` contains Kimi launchers and `ai-glm.cmd`, but not the two Grok launchers.

## 3. What triggered this work

On 2026-08-13 Albert asked to sync dotfiles and then asked whether Grok was pinned to 4.6. The sync was reported complete. The Grok wrappers were pinned to 4.6 and pushed in commit `4731240`, but later command-path checks showed:

```powershell
Get-Command ai-grok-review       # fails
Get-Command ai-grok-implement    # fails
& 'C:\Program Files\Git\bin\bash.exe' -lc 'command -v ai-grok-review; command -v ai-grok-implement'  # both fail
```

`bin/ai-grok-review doctor` worked by explicit repo path and reported Grok 4.6. That proved the source pin, not installation.

Grok 4.6 then critiqued the first plan in a 12-turn read-only review. It rejected the plan because it used full machine installers as repair, proposed an Ubuntu prefix test the existing installer could not support, treated GLM like a dual-shim Bash wrapper, left the required command list open, and did not make future wrapper drift mechanically fail.

GLM 5.2 critiqued the first revision. It agreed with the catalog, doctor, narrow installers, and bootstrap gate, but rejected changing `install.sh`'s working generic loop. That loop already handles future Ubuntu commands automatically; replacing it risked dropping non-provider commands. This revision keeps `install.sh` unchanged and applies GLM's clarity and test corrections.

## 4. Scope — in and out

In scope:

- Add one versioned catalog for required repo-owned AI command launchers.
- Add one read-only doctor that consumes the catalog and distinguishes launcher state, persisted PATH state, current-shell PATH state, and optional provider state.
- Add small commands-only installers for Windows and Ubuntu. They may only create/update command launchers and the minimum PATH setting needed to find them.
- Lock the required wrapper set to `ai-grok-review`, `ai-grok-implement`, `ai-kimi`, `ai-deepseek-agent`, and `ai-glm`, with platform forms defined in §8.
- Make Windows `setup-machine.ps1` call the small Windows installer rather than carry separate wrapper lists. Leave Ubuntu `install.sh`'s working generic loop unchanged.
- Make both sync skills repair with the small installers, then re-check.
- Make the already-invoked `bin/ai-install-skills` fail loudly when a pulled repo introduces missing required launchers, so the first sync using an older installed skill cannot report success.
- Cover Windows PowerShell, Windows Git Bash, Ubuntu, fresh-shell PATH, missing optional providers, and GLM’s Windows `.cmd`-only design.
- Add regression tests, update docs, and install/prove Grok 4.6 on this computer.

Not in this plan:

- Changing wrapper runtime behavior, provider models, Grok permissions, sessions, worktrees, turns, locks, or completion rules.
- Installing or logging into optional provider programs `grok` or `kimi`. Their absence is informational, not a launcher failure.
- Replacing GLM service setup or adding an extensionless Windows `ai-glm` launcher. Windows `.cmd` is the supported GLM form.
- Turning `ai-devops doctor` into the new check. It requires `/etc/ai-devops` and deliberately spends a real Codex sandbox write.
- Changing secrets, MCP, SSH, databases, production, cloud infrastructure, or adding CI.
- Touching unrelated `.ai/` content except model review reports, or `docs/claude-remote-control-hardening-v2.md`.

## 5. Current state of the code

- `bin/setup-machine.ps1:580-630` hard-codes Kimi launcher creation and adds `%USERPROFILE%\.local\bin` to User and process PATH only inside that Kimi block.
- `bin/setup-machine.ps1:633-668` separately hard-codes Grok launcher creation but does not independently add the launcher directory to PATH.
- `bin/setup-opencode-glm.ps1:243-259` creates `ai-glm.cmd` only. `bin/ai-glm:1509-1510` explicitly treats that `.cmd` as the Windows installed command.
- `install.sh:90-116` owns Ubuntu `/usr/local/bin` links but is embedded in a broad installer with no test-prefix option.
- `bin/install-ai-devops-windows.ps1` does not install delegate command shims.
- `bin/ai-devops:159-166` has a separate companion list that is already stale and is not suitable for this cheap machine-path check.
- Both sync skills gate broad setup on Phase 2 secret/MCP/SSH state and never check Grok, Kimi, or DeepSeek launchers.
- Both sync skills run `bin/ai-install-skills` after pulling. This makes it the only reliable hook available during the first sync after new repo code arrives while the live installed skill still contains the old procedure.
- `docs/config-inventory.md` has the open-plan note below the last table row. No implementation work remains for that cosmetic placement.
- The plan and handoff were committed at `9b6ccf3`. No implementation code exists.

## 6. Key findings and root cause

1. **Primary root cause:** sync success is organized around Phase 2 wiring, not all skill-required local commands. Healthy secrets caused broad setup to be skipped.
2. **Second root cause:** Windows wrapper installation is duplicated and name-based. Adding a new `bin/ai-*` requires remembering another setup block. A doctor alone would still leave a second hard-coded installer list.
3. **First-sync bootstrap gap:** a repo pull updates the source skill, but the current run is following the old loaded skill. The current run already calls the newly pulled `bin/ai-install-skills`; that script must fail closed when required commands are missing so false success cannot survive one extra sync.
4. **Full installers are unsafe repair tools:** `setup-machine.ps1` can rewrite MCP/Claude/Codex state and GLM setup; `install.sh` can use packages, `/etc`, permissions, secrets, memory, GLM, and a paid Codex doctor. Missing launchers need a narrow installer.
5. **Windows forms differ by command:** Grok, Kimi, and DeepSeek are Bash wrappers needing extensionless Git Bash plus `.cmd` PowerShell launchers. GLM is intentionally `.cmd` only.
6. **PATH has three states:** launcher files may exist, the persistent User PATH may include their directory, and the current process may still have stale PATH. The doctor must report these separately and must not delete/reinstall correct files because only the current shell is stale.
7. **Ubuntu testability requires extraction:** the current symlink loop has no prefix option. The new small installer must accept a test target rather than pretending `install.sh` already can.
8. **Future drift must fail mechanically:** the catalog, platform installers, doctor, and tests must share data. A new required catalog row must fail until every supported platform form is handled.
9. **DeepSeek belongs in scope:** `skills/shared/deepseek-second-opinion/SKILL.md` tells agents to run `ai-deepseek-agent`; omitting it would violate the stated goal.

## 7. Approaches considered and REJECTED, and why

1. **Separate command lists in both skills:** rejected because they drift.
2. **A doctor plus existing full installers:** rejected after Grok critique. The repair is too broad and may block on secrets or require unrelated restarts.
3. **Always run broad setup:** rejected for the same reason; idempotent does not mean narrow.
4. **Extend `ai-devops doctor`:** rejected because that command has `/etc` assumptions and a deliberately paid Codex sandbox proof.
5. **Put repo `bin/` directly on Windows PATH:** rejected because shims pin the Windows profile and Git Bash executable, protecting against the known Git Bash `$HOME` trap.
6. **Copy wrapper source into a local bin:** rejected because copies drift. Launchers must point to repo source.
7. **Make `setup-secrets.sh` install Ubuntu commands:** rejected because secrets and command links have separate owners.
8. **Require dual shims for every Windows command:** rejected because GLM intentionally supports `.cmd` only.
9. **Treat missing provider programs as missing wrappers:** rejected. The repo can install its launcher without controlling third-party login/install state.
10. **Only fix Grok:** rejected because Kimi and DeepSeek use the same plain-command contract and the goal is to prevent the next omission.
11. **Refactor Ubuntu `install.sh` to call the narrow installer:** rejected after GLM critique. Its generic loop already installs every executable `bin/*`; changing it adds regression risk without solving Ubuntu drift.

## 8. Design decisions already made (2026-08-13)

Locked:

- Canonical catalog: add `config/machine-tools.tsv` as ASCII, tab-delimited text. Skip blank lines and lines beginning with `#`. One row per command with command name, repo source, Windows form, Ubuntu repair flag, and provider classification. Bash parses with tab `IFS`; PowerShell splits on tab. No delimiter choice remains open.
- Required catalog rows:
  - `ai-grok-review`: source `bin/ai-grok-review`; Windows `bash+cmd`; Ubuntu link; required.
  - `ai-grok-implement`: source `bin/ai-grok-implement`; Windows `bash+cmd`; Ubuntu link; required.
  - `ai-kimi`: source `bin/ai-kimi`; Windows `bash+cmd`; Ubuntu link; required.
  - `ai-deepseek-agent`: source `bin/ai-deepseek-agent`; Windows `bash+cmd`; Ubuntu link; required.
  - `ai-glm`: source `bin/ai-glm`; Windows `cmd-only-external` owned by `setup-opencode-glm.ps1`; Ubuntu link; required-command check plus existing deeper `ai-glm doctor`.
- Optional provider rows/checks: `grok` and `kimi` are `INFO`, never failure. Do not read credential files or call provider APIs in the machine doctor.
- Add `bin/ai-machine-tools-doctor`, read-only and cheap.
- Add narrow platform installers: `bin/install-machine-tools.ps1` and `bin/install-machine-tools.sh`. Both read the same catalog. They do not touch secrets, MCP, SSH, memory, Git identity, provider auth, GLM service, or model APIs.
- Windows installer writes `bash+cmd` rows under `%USERPROFILE%\.local\bin`, pins `%USERPROFILE%` as HOME, invokes the absolute Git Bash path, and ensures the directory is on persistent User PATH independently of Kimi.
- Windows installer does not create GLM. Doctor accepts existing `ai-glm.cmd`; missing GLM remains repaired by the existing GLM setup step.
- Ubuntu narrow repair installer owns catalog links only when sync calls it, defaults to `/usr/local/bin`, and accepts `--target-dir` for tests. It replaces only missing links or links already pointing into this repo and leaves unrelated real files untouched.
- `setup-machine.ps1` calls the narrow Windows installer and removes its duplicated Kimi/Grok blocks. `install.sh` remains unchanged as the generic fresh-install owner of all executable `bin/*`; it does not call the narrow installer.
- Both sync skills call doctor, narrow repair, and doctor again. GLM’s existing deeper check stays separate.
- `bin/ai-install-skills` runs a bootstrap gate at the end. On Windows it runs the unprivileged narrow installer, then doctor. On Ubuntu it runs doctor only and never prompts for `sudo`. If unhealthy, print exactly `SYNC INCOMPLETE — do not report success; rerun 'sync my dotfiles'.` and exit nonzero. An old loaded skill may still mishandle a nonzero subprocess, so first-run protection is loud but agent-dependent; from the next run onward the revised skill deterministically stops.
- Under `ai-install-skills --dry-run`, the bootstrap gate must preview the installer/check or skip writes explicitly; it must never create launchers or change PATH. Test the chosen dry-run message and zero/nonzero contract.
- Do not use current-shell `command -v` alone on Windows. The Bash doctor reads persistent User PATH through PowerShell `[Environment]::GetEnvironmentVariable('PATH','User')`, checks expected files, and reports current-shell staleness separately. Final verification launches fresh shells and runs `hash -r` before same-shell retry where relevant.
- A final nonzero doctor blocks “sync complete.” No fallback.
- Preserve all Grok STEP 0 safety controls.

Open implementation judgment: none. Catalog format, rows, ownership, bootstrap behavior, and platform forms are locked above.

## 9. The plan — numbered, ordered steps

### Phase 1: Shared catalog and truth check

1. **Add the catalog and read-only doctor.**
   - Create `config/machine-tools.tsv` with the locked rows and a comment header defining every field/value.
   - Create executable `bin/ai-machine-tools-doctor`. It accepts test overrides for repo root, catalog, platform, Windows profile, and command/path probes. Defaults must derive from its own repo and `%USERPROFILE%` on Windows, never Git Bash `$HOME`.
   - Windows: require extensionless plus `.cmd` files for `bash+cmd`; require `.cmd` only for `cmd-only-external`; read persistent User PATH through PowerShell and require `%USERPROFILE%\.local\bin`; report current-process PATH as `INFO stale` rather than reinstall failure.
   - Ubuntu: require each catalog-marked link to resolve on PATH or at an explicit target used by tests; validate safe link/source relationships.
   - Report optional provider binaries as `INFO available` or `INFO unavailable`. Make no API calls.
   - Dependency: none.
   - Gate: fixture with all locked forms passes; each missing required form fails by exact name/form; GLM `.cmd`-only passes; missing `grok`/`kimi` providers remains zero.

2. **Add narrow platform installers that consume the catalog.**
   - Create ASCII-only `bin/install-machine-tools.ps1` with `-RepoPath`, optional `-CatalogPath`, optional `-UserProfilePath`, and testable no-provider behavior. It writes `bash+cmd` launchers only, ensures User PATH independently, and leaves `cmd-only-external` to its named owner.
   - Create executable `bin/install-machine-tools.sh` with `--repo-root`, `--catalog`, and `--target-dir` (default `/usr/local/bin`). It links Ubuntu-enabled rows using current safety: replace missing paths or repo-owned symlinks; refuse/leave unrelated real files loudly.
   - Neither installer may call secrets, providers, GLM service setup, memory, Git, package managers, or broad setup.
   - Dependency: step 1 catalog.
   - Gate: temporary Windows profile gets correct launchers/PATH without other files changing; temporary Ubuntu target gets correct links; repeated runs are unchanged; unrelated target files are preserved with nonzero/loud result as designed.

### Phase 2: Reuse from setup and sync

3. **Replace duplicate Windows setup ownership; keep Ubuntu fresh install unchanged.**
   - In `bin/setup-machine.ps1`, replace Kimi/Grok hard-coded shim blocks at current lines 580–668 with one call to `install-machine-tools.ps1`. Keep prerequisite reporting for missing Git Bash or source files. PATH handling moves into the narrow installer and no longer depends on Kimi existing.
   - Do not change `install.sh`'s generic executable loop at current lines 90–116. It remains the fresh-install owner of every executable `bin/*`, including catalog and non-catalog commands.
   - `bin/install-machine-tools.sh` exists only for sync repair and `--target-dir` unit tests. It is not called by `install.sh`.
   - In `bin/setup-opencode-glm.ps1`, retain `ai-glm.cmd` ownership. Do not duplicate it.
   - Dependencies: steps 1–2.
   - Gate: Windows setup calls one catalog-driven installer and duplicated Kimi/Grok lists are gone; `install.sh`'s generic loop remains unchanged and its existing command coverage stays proven.

4. **Wire both sync skills and the first-sync bootstrap gate.**
   - Update both sync tables and procedures to run repo-path doctor/repair immediately after pull and before `bin/ai-install-skills`. Fix the Codex skill's existing duplicate `4b` numbering while inserting the step.
   - On Windows failure, run only `install-machine-tools.ps1`; on Ubuntu failure, run only `install-machine-tools.sh` with default target and existing privilege rules. Then re-run doctor.
   - If only GLM is missing, route to the existing GLM installer and its existing `ai-glm doctor`; do not pretend the delegate installer owns GLM service setup.
   - After Windows repair, update process PATH for the current run, use `hash -r` in Git Bash where needed, and still verify from fresh PowerShell/Git Bash in final testing.
   - Add the explicit success report “Local AI commands already current” or name what was installed. Final failure stops the sync.
   - At the end of `bin/ai-install-skills`, implement the locked bootstrap behavior and exact `SYNC INCOMPLETE` message from §8. Route installer actions through the script's existing dry-run controls so `--dry-run` never writes. Document that first-run protection depends on the old agent honoring nonzero output; deterministic protection begins with the newly installed skill on the next run.
   - Dependencies: steps 1–3.
   - Gate: both current skills repair and re-check; a fixture representing the old skill still fails inside `ai-install-skills` instead of printing success; no broad setup command appears in wrapper repair.

### Phase 3: Tests, docs, and machine proof

5. **Add regression tests for original and future drift.**
   - Add `tests/test-ai-machine-tools.sh` covering catalog parse, doctor, both installers, bootstrap, skills, PATH, idempotence, conflicts, provider INFO, and GLM `.cmd`-only.
   - Replace/update `tests/test-windows-ai-kimi-shim.ps1` in the same change as the `setup-machine.ps1` refactor, or replace it with one catalog-driven PowerShell test. Render launchers in a temporary profile and execute syntax/path assertions. Preserve PowerShell here-string backtick escaping such as `` `$@ ``; `tests/test-windows-scripts.sh` rejects bash-style backslash-dollar escapes in any `.ps1`.
   - Add a catalog-consistency test: every required `bash+cmd` row must be handled by the Windows installer; every Ubuntu-enabled row by the shell installer; every `cmd-only-external` row must name and be verified against its owner. Adding a required catalog row must fail until platform behavior exists.
   - Add skill contract tests: both skills call the same doctor/installers before `ai-install-skills`, re-check, separate GLM, use unique numbering, and forbid false success.
   - Run existing `tests/test-windows-scripts.sh`, both Grok suites, `tests/test-ai-kimi.sh`, `tests/test-ai-deepseek-agent.sh`, and GLM tests affected by command handling.
   - Dependencies: steps 1–4.
   - Gate: deleting a catalog consumer, adding an unhandled required row, removing a shim form, requiring extensionless GLM, or making provider absence fatal each causes a focused test failure.

6. **Update durable docs and reconcile `al8960ofc`.**
   - Document catalog, doctor, narrow installers, required forms, optional providers, and bootstrap behavior in `docs/config-inventory.md`; its earlier note placement is already cleaned up in this planning revision.
   - Update `docs/deployment.md`, `AGENTS.md` installed-command/navigation rows, both sync skills, this plan, handoff, and memory pointer.
   - Run narrow Windows installer and doctor. Verify `%USERPROFILE%\.local\bin` contains correct Grok, Kimi, and DeepSeek forms and existing `ai-glm.cmd` remains owned by GLM setup.
   - Start fresh PowerShell and Git Bash processes. Require `Get-Command`/`command -v` for Grok and Kimi; verify DeepSeek command resolution without an API call; run installed `AI_GROK_CALLER=codex ai-grok-review doctor` and require lines matching `model *: grok-4.6` and `auth *: OK (grok models succeeded)`.
   - Dependencies: steps 1–5.
   - Gate: both shells resolve catalog-required commands according to their platform forms; doctor passes; installed Grok doctor reports 4.6 for free.

7. **Commit, push, and prove a clean sync.**
   - Update STATUS with exact test commands/artifacts. Retire the handoff only after every obligation is complete.
   - Verify Git identity is Albert’s noreply address. Stage only this work, never unrelated `.ai/` or the Claude hardening doc.
   - Commit on `main`, safely integrate later remote commits, push, and verify `main...origin/main`.
   - From fresh shells run a full sync dry/proof path, machine doctor, GLM doctor, and installed Grok doctor. Confirm a missing-wrapper fixture cannot produce a success report.
   - Dependencies: steps 1–6.
   - Gate: final SHA is on `origin/main`, all named suites pass, STATUS cites rerunnable evidence, and both old-skill bootstrap and current-skill repair cases are proven.

**Context cut:** one implementation session should finish this. If Windows catalog extraction reveals a larger launcher refactor than specified, stop after step 3, update STATUS and current-state text, write a new handoff, and continue steps 4–7 in a fresh session. Ubuntu's generic fresh-install loop remains out of that refactor.

## 10. Tests required

New `tests/test-ai-machine-tools.sh` cases:

- catalog parses in Bash and PowerShell without optional runtimes;
- locked rows and forms exist exactly as §8 states;
- full fixture passes; each required launcher/form missing fails by name;
- GLM `.cmd`-only passes on Windows and its missing owner is named;
- missing `grok` or `kimi` provider is INFO and exit zero;
- persisted User PATH missing fails; current-process PATH stale is INFO;
- doctor reads persistent Windows User PATH through PowerShell, not the current Bash environment alone;
- Windows installer creates both forms, pins Windows HOME, uses absolute Git Bash, and adds PATH without depending on Kimi;
- Ubuntu installer accepts a temporary target, creates safe links, is idempotent, and preserves unrelated files loudly;
- catalog consistency fails for an unhandled new required row;
- both skills check and repair before `ai-install-skills`, re-check, separate GLM, and use unique step numbers;
- old-skill path through `ai-install-skills` prints the exact `SYNC INCOMPLETE` message and exits nonzero with missing wrappers;
- `ai-install-skills --dry-run` creates no launcher and changes no PATH while giving a clear preview/skip result;
- neither narrow installer references secrets, MCP, provider auth, GLM service, package install, memory, or paid doctors.

Windows PowerShell test:

- Render real launchers into a temporary profile, parse changed `.ps1` files, confirm ASCII-only content, validate generated Bash syntax, and preserve PowerShell backtick escaping for literal Bash variables.
- Replace or extend `tests/test-windows-ai-kimi-shim.ps1` in the same change as the setup refactor; do not leave two conflicting sources of expected wrapper names.

Existing suites:

```bash
tests/test-windows-scripts.sh
tests/test-ai-grok-review.sh
tests/test-ai-grok-implement.sh
tests/test-ai-kimi.sh
tests/test-ai-deepseek-agent.sh
tests/test-ai-glm.sh
tests/test-ai-install-skills.sh
```

Also run `git diff --check`. No live Grok, Kimi, DeepSeek, or GLM model turn is needed for implementation tests. Provider-specific `doctor` commands may be used only where documented as free.

## 11. Constraints, standing rules, and gotchas in force

- Main-only repo. Verify Albert’s noreply Git identity before commit.
- Preserve unrelated concurrent files. Use `apply_patch`; keep PowerShell ASCII-only.
- Never hard-code `C:\repos\ai-devops`; derive paths.
- Never trust Git Bash `$HOME` on Windows; use `%USERPROFILE%` and an absolute Git Bash path.
- Never read provider credential files or call paid models for machine-tool checks.
- Do not alter Grok, Kimi, GLM, or DeepSeek runtime safety behavior.
- Do not make provider login a prerequisite for installing repo launchers.
- Narrow installers must not touch secrets, MCP, SSH, memory, Git identity, provider auth, packages, or services.
- Do not require extensionless GLM on Windows.
- Do not use current-shell PATH alone as installation proof.
- No silent fallback. Final doctor failure blocks sync success.
- Leave `install.sh`'s generic Ubuntu executable loop unchanged; the narrow shell installer is sync-repair/test only.
- No UI, database, container, cloud deployment, or production work applies.

## 12. Access and environment

- Repo: `C:\repos\ai-devops`; remote `https://github.com/u2giants/ai-devops`; branch `main`.
- Planning baseline: plan commit `9b6ccf3`, Grok pin commit `4731240`, plus later `origin/main` commits pulled before implementation.
- Shells: PowerShell 7 and `C:\Program Files\Git\bin\bash.exe`.
- Grok: `%USERPROFILE%\.grok\bin\grok`, observed version 1.0.3, authenticated. Never inspect its auth file.
- GLM: local OpenCode server pinned to GLM 5.2; use `ai-glm doctor` and existing setup only.
- Git/GitHub access is active; verify before claims.
- 1Password is not needed by the narrow installers. If broader setup is ever separately required, the service token lives in vault `vibe_coding`, item `vibe_coding-service-account`, field `op_service_account_token`; never record its value.
- Ubuntu `/usr/local/bin` may require existing `sudo` policy. Tests must use `--target-dir` and never need privilege.
- “Deployment” means installation on a computer. There is no hosted runtime.

## 13. Definition of done + risks and open questions

Done means:

- [ ] One catalog drives forms, doctor, installers, and consistency tests.
- [ ] Required rows are Grok review/implement, Kimi, DeepSeek, and GLM with locked platform forms.
- [ ] Small installers repair commands without broad setup side effects.
- [ ] Both sync skills narrowly repair, re-check, and fail loudly.
- [ ] Old loaded skills receive a loud nonzero `SYNC INCOMPLETE` gate; revised skills deterministically repair or stop on the next run.
- [ ] Windows and Ubuntu fixtures cover PATH, idempotence, conflicts, optional providers, GLM `.cmd`-only, and future rows.
- [ ] Existing Grok, Kimi, DeepSeek, GLM, and Windows suites stay green.
- [ ] This computer resolves required commands and installed Grok doctor reports 4.6.
- [ ] Durable docs, links, and STATUS are current.
- [ ] Commit uses Albert’s identity, is pushed to `origin/main`, and unrelated files remain unstaged.
- [ ] Handoff retires only after completion.

Risks and rollback:

- Catalog parsers in Bash and PowerShell can disagree. Keep the format ASCII and minimal; cross-parser fixtures are mandatory.
- Ubuntu fresh-install regression is avoided by leaving its generic executable loop unchanged; tests prove the narrow repair tool does not replace that owner.
- Current-shell PATH can be stale after correct repair. Doctor separates persisted state; final proof uses fresh shells.
- `ai-install-skills` gaining a fail-closed gate may stop a first sync on Ubuntu until rerun with the new skill. That is deliberate and safer than false success; its message must be exact.
- Rollback is reverting the implementation commit. Narrow installers touch only launchers/PATH, so rollback may leave harmless launchers pointing to reverted repo source; rerunning the prior setup restores prior state.

Open questions: none. GLM's blocking ownership choice and all earlier bounded choices are locked in §8.

## Mandatory self-audit — passed 2026-08-13

1. **Can a new session execute without questions? Yes.** §§2–6 define repo, symptom, current files, both root causes, and Grok’s rejected design. §§8–10 lock the catalog rows/forms, exact new files, consumers, order, and proof gates. §12 defines access.
2. **Does it carry the full reasoning? Yes.** §§6–8 preserve first-sync bootstrap limits, full-installer side effects, GLM's exception, PATH states, DeepSeek scope, both model critiques, rejected alternatives, and final locked choices.
3. **Is the goal clear enough for judgment calls? Yes.** §1 requires every skill-taught repo command and no false success. §§4, 8, 11, and 13 prevent broad repair or provider-login scope creep.

All 13 sections, explicit exclusions, rejected approaches, locked/open decisions, concrete file-level steps, named tests, per-step verification gates, constraints, access, rollback, definition of done, and two-way handoff link are present. The revised plan passes the checklist.
