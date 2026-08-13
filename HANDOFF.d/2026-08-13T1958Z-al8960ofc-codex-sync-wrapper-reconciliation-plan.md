# HANDOFF — Dotfiles sync wrapper reconciliation plan (2026-08-13 19:58Z, al8960ofc/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None. Albert already asked for this fix plan. Two small engineering choices in the plan have decision criteria and do not require owner input.

Already settled, do not re-ask:

- 2026-08-13: “sync my dotfiles” must leave repo-owned Grok commands usable on the computer.
- 2026-08-13: both Grok wrappers are pinned to Grok 4.6 in commit `4731240`.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan’s public toolkit for restoring and syncing a multi-model AI coding setup across Windows and Ubuntu. It contains setup scripts, safe AI wrappers, skills, docs, and tests. It is not a hosted service. The local repo is `C:\repos\ai-devops`, branch `main`; GitHub is the source of truth.

## 2. What we set out to do this session, and why

Albert asked for a plan to fix a dotfiles-sync bug. A sync was reported successful even though normal `ai-grok-review` and `ai-grok-implement` commands were absent on this Windows computer. This session produced a fresh-session-ready plan covering the whole false-success class across Claude, Codex, Windows, and Ubuntu.

Read [plan_sync-machine-wrapper-reconciliation.md](../plan_sync-machine-wrapper-reconciliation.md).

## 3. Current state — what is true right now

- Planning is complete; implementation has not started.
- Grok 4.6 rejected the first plan after reading the repo. GLM 5.2 found one blocker in the first revision: it unnecessarily changed Ubuntu's already-correct generic installer loop. The current plan keeps that loop unchanged and uses the narrow Ubuntu installer only for sync repair/tests.
- The revised plan has seven open implementation rows and names §9.1 as the start.
- Windows setup already installs Grok shims at `bin/setup-machine.ps1:633-668`.
- Ubuntu `install.sh:90-116` owns `/usr/local/bin` symlinks.
- Both sync skills check Phase 2 and GLM, but neither checks Grok or Kimi command availability.
- Repo-path Grok doctor works and reports 4.6; plain PowerShell and Git Bash lookups for both Grok wrappers fail on `al8960ofc`.
- The revised plan locks DeepSeek into scope and treats Windows GLM as `.cmd` only.
- GLM 5.2 re-read the corrected plan and approved it with no blockers. Its final small notes about `ai-install-skills` tests and dry-run behavior are included.
- The plan and this handoff are not committed or pushed until this planning session lands them.
- Existing unrelated `.ai/` and `docs/claude-remote-control-hardening-v2.md` must remain untouched.

## 4. Everything we tried that did NOT work

1. The earlier sync treated current secret/MCP/SSH wiring as complete machine state, skipped `setup-machine.ps1`, and missed newly added Grok shims.
2. The earlier verification called `bin/ai-grok-review doctor` by repo path. It proved source used 4.6, not that the installed command existed.
3. Adding Grok names separately to both skill checklists was rejected because duplicate lists drift.
4. Always running full setup was rejected because it has broad effects and should not run on a healthy machine.
5. Grok rejected conditional full setup too: it remains broad, Ubuntu lacked the promised test target, and a doctor alone left a second hard-coded Windows list.
6. GLM rejected refactoring `install.sh`: its generic `bin/*` loop already handles future commands and changing it could drop non-catalog tools. The current plan now leaves it untouched.

## 5. Root causes and key findings

- Root cause: `skills/claude/sync-dotfiles/SKILL.md:51-86` and `skills/codex/codex-sync-dotfiles/SKILL.md:46-75` gate setup on Phase 2, not all local AI commands.
- The Windows installer is already capable; sync never checks whether its Grok step needs to run.
- Source existence is not installed-command proof.
- Windows must verify PowerShell and Git Bash. Ubuntu must retain `install.sh` as symlink owner.
- One reusable read-only doctor must own the command list so Claude and Codex cannot drift.
- Catalog, doctor, both narrow installers, and consistency tests must share one source of truth.
- `bin/ai-install-skills` is the old-skill bootstrap gate because an in-progress sync keeps following the old loaded skill after pulling a newer file.
- Windows GLM `.cmd` only is valid. Missing optional `grok` and `kimi` provider programs is informational.
- Windows bootstrap is locked to unprivileged repair then doctor. Ubuntu bootstrap fails closed without hidden `sudo`. The first old-skill run is a loud soft gate; the next revised-skill run is deterministic.

## 6. Exact next steps

1. Read the plan in full, especially STATUS and §§1–8. Gate: you can state the root cause and locked decisions without this chat.
2. Start at plan §9.1 and add `config/machine-tools.tsv` plus the doctor. Gate: missing forms fail, GLM `.cmd` only passes, and missing providers stay informational.
3. Follow §§9.2–9.4 for narrow installers, Windows setup reuse, both skills, and the bootstrap gate. Leave `install.sh`'s generic loop unchanged. Gate: no full setup command repairs missing wrappers.
4. Follow §9.5 for consistency and platform tests. Gate: adding an unhandled required catalog row makes tests fail.
5. Follow §9.6 on `al8960ofc`. Gate: fresh shells resolve required commands and installed Grok doctor reports 4.6.
6. Update STATUS/docs and follow §9.7. Gate: final SHA is on `origin/main`, tests pass, and unrelated files remain unstaged.
7. Retire this handoff only after all obligations are proven complete and captured in the plan.

## 7. Constraints and gotchas in force

- Main-only. Verify Albert’s noreply Git identity before committing.
- Never stage `.ai/` or `docs/claude-remote-control-hardening-v2.md`.
- Keep PowerShell ASCII-only. Never hard-code a drive or trust Git Bash `$HOME`.
- Never read `~/.grok/auth.json` or spend money on a live Grok turn.
- Do not change Grok permissions, completion, locks, worktrees, turns, or 4.6 pin.
- Provider login and wrapper installation are separate.
- Final machine-tool failure blocks “sync complete.”
- Never require an extensionless Windows GLM launcher.
- Narrow installers must not touch secrets, MCP, packages, memory, services, or provider APIs.
- Do not refactor or replace Ubuntu `install.sh`'s generic executable loop.

## 8. Access and environment

- Machine: `al8960ofc`, Windows 11.
- Repo: `C:\repos\ai-devops`, branch `main`.
- Shells: PowerShell 7 and `C:\Program Files\Git\bin\bash.exe`.
- Grok CLI: `%USERPROFILE%\.grok\bin`, observed version 1.0.3, authenticated. Never inspect its auth file.
- Git and GitHub access are active; re-verify before landing.
- If setup lacks its token file: 1Password vault `vibe_coding`, item `vibe_coding-service-account`, field `op_service_account_token`. Never record the value.
- No database, cloud deploy, or production access is involved.

## 9. Open questions and risks

- Required rows are locked in plan §8: Grok review/implement, Kimi, DeepSeek, and GLM with explicit forms.
- PATH may remain stale in the current shell after repair; verify fresh PowerShell and Git Bash processes.
- Bash and PowerShell must parse the same simple catalog; cross-parser fixtures are mandatory.
- First-run protection under an old loaded skill depends on honoring the nonzero `SYNC INCOMPLETE` message; deterministic protection begins on the next run with the revised skill.
- `ai-install-skills --dry-run` must remain write-free when the bootstrap gate is added.
- No owner-blocking question exists.

## Handoff self-audit — passed

All 10 sections are present. §0 completed the owner-decision sweep. §§1–3 define the repo, goal, exact state, branch, and symptom. §§4–5 preserve failures and root cause. §6 gives executable steps with gates. §§7–9 define constraints, access, risks, secret location, and decisions. Commit/push state is explicit and no secret value appears. A fresh developer can continue without this chat.
