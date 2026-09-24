---
issue: 731
status: BLOCKED
owner: mimo/edge-dev-707-phase2-wrapup
---

# Handoff — #707 phase 2 shipped; #731 Desktop proof + ENVY + #705 next

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking (put the whole list to the owner in ONE message before starting work):**

1. **Quit and reopen Claude Desktop once on edge-dev.** A click, not a decision. It ends any Code-tab session inside Desktop. That is the only gate on #731. *Blocks step 6.1.*
2. **Nothing else is waiting on a ruling.** No schema, security, spend, or product choice is open in this workstream.

**Already settled — do NOT re-ask:**

- 2026-08-26: MCP ownership map (`trigger`/`recall-ai` → oracle; `ag-grid` → designflow-frontend; etc.) — locked in `plan_tool-and-skill-scoping.md` §8.
- 2026-09-23: DesignFlow skills stay global (used from non-git `dflow_plm` parent) — phase 2 decision, recorded in `docs/context-engineering.md`.
- 2026-09-24: Protected skills must never appear in `config/skill-scope.json` — installer refuses.

**Not part of this work, nobody is on it (still needs the owner eventually):**

- ENVY runner missed PR #718’s reviewer suites so `windows-reviewer-fallback` ran ~50 min on GitHub-hosted Windows (see §6.3). Recommendation: open one tracking issue and let a later session fix it; do not block #705 on it.

## 1. What this application is

`popcre/ai-devops` (also `u2giants/ai-devops`): Albert’s machine-setup and AI-tooling repository for every Windows/Linux machine. Not a running service. Holds `bin/setup-machine.ps1`, `bin/ai-install-skills`, skills under `skills/`, reviewer wrappers, CI (`verify.yml`), and the plans that track cross-machine work. edge-dev is Albert’s main Windows 11 machine.

This workstream is **tool and skill scoping** (parent issue #707): every chat should start with only the tools and skills its repository needs.

## 2. What we set out to do this session, and why

Albert said: work on #707 via the handoff `HANDOFF.d/2026-09-23T2100Z-edge-dev-claude-707-phase1-and-envy-runner.md`; if Claude Desktop has been restarted, finish #731, then start #704.

- #731 could **not** finish: Claude Desktop has been running since 1:18 PM ET on 2026-09-23 and was never quit/reopened. Drift check still FAILS (extra chrome-devtools, codex-cli, devops-mcp, supabase).
- #704 (phase 2 — repo-scoped skills) **was** taken and finished in this session.

## 3. Current state — what is true right now

**Done and on `origin/main`:**

- Phase 2 merged as **`62e68fa3`** (PR [#747](https://github.com/popcre/ai-devops/pull/747), MERGED 2026-09-24T02:46:36Z).
- `config/skill-scope.json` maps 8 licensor scraper skills → `licensor-source-data`.
- `bin/ai-install-skills` installs scoped skills into each cloned owning repo’s `.claude/skills/` (Claude Code) and `.agents/skills/` (Codex), and quarantines global copies (never deletes).
- Protected skills in the scope file are rejected.
- Live proof on edge-dev: `claude -p` in `C:\repos\licensor-source-data` lists all 8 scoped skills; global Claude/Codex skill dirs no longer carry them (Claude installed 48→40; recoverable copies under `~/.claude/skills-quarantine/` and `~/.codex/skills-quarantine/`).
- Tests: `test-ai-install-skills.sh` 13/13 PASS; `test-ai-install-manifest.sh` PASS; `test-context-audit.ps1` PASS; `test-mcp-skill-drift.ps1` 15 passed.
- #704 closed; #707 box for #704 ticked with comment “Phase 2 done (62e68fa3). Next: #705.”
- Plan STATUS rows 2.1–2.3 marked done in `plan_tool-and-skill-scoping.md`.
- Measurements in `docs/context-engineering.md` § “Repository-scoped skills on 2026-09-24”.

**Still open:**

- **#731** (status OPEN/BLOCKED): leftover live proof for #703 step 1.2. Needs Desktop quit/reopen, then `bin/check-mcp-drift.ps1` PASS twice.
- Plan row 1.2 still “code merged; live proof open” until #731 closes.
- ENVY runner investigation (no issue yet).
- #705 / #706 not started (next #707 phases).

**Not started:** nothing else.

## 4. Everything we tried that did NOT work

1. **Assuming Desktop had been restarted.** Process list showed `Claude.exe` under WindowsApps still at StartTime 1:18 PM on 2026-09-23. Drift check confirmed FAIL. Correctly deferred #731 instead of faking the proof.
2. **Python one-shot JSON parse in `ai-install-skills`.** Worked but added startup cost; replaced with a pure-bash parser of the controlled `skill-scope.json` shape (tests still green).
3. **Full-tree `hash_tree` per destination.** 8 skills × ~22 `licensor-source-data` worktrees × 2 client folders exhausted Git Bash forks (`fork: retry: Resource temporarily unavailable`) and ran past 10 minutes. Fix: cache source hashes per skill, `cp -a` for absent destinations, cache `git worktree list` per repo key.
4. **Quarantine only marker-bearing globals.** Live global copies of some scrapers lacked `.ai-devops-managed`, so prune skipped them. Fix: a name listed in `skill-scope.json` is ours and is quarantined even without a marker.
5. **`git rev-parse --git-path info/exclude` used as a relative path.** `mkdir -p .git/info` then failed in a worktree where `.git` is a file. Fix: resolve exclude paths absolute against the clone.
6. **First CI run of PR #747:** `windows-offline-section (4)` failed with “undiscovered suite: test-ai-adopt-globals.sh” in 24s. Local discovery finds the file; `tests/test-ai-adopt-globals.sh` passes. **Re-run of the failed job went green.** Treat as a flake; if it repeats, open a new issue — do not “fix” test discovery blindly.

## 5. Root causes and key findings

- **Claude Code repository skills live at `<repo>/.claude/skills/`.** Proven by existing `dflow_plm/designflow-frontend/.claude/skills/designflow-e2e-tester` and by `claude -p` listing a throwaway skill in a scratch repo (`C:\repos\scratch-skill-proof`, disposable).
- **Codex repository skills live at `<repo>/.agents/skills/`** (OpenAI “Build skills” docs: `$REPO_ROOT/.agents/skills`). User-level Codex skills we install remain `~/.codex/skills`.
- **`dflow_plm` is not a Git repo.** DesignFlow skills (dflow-session-start, dflow-ship, designflow-human-qa) stay global because sessions run from that parent folder (plan §8 open-decision criterion).
- **`licensor-source-data` has many worktrees** (including `D:/product-reader-worktrees/*`). Those are real worktrees of the same remote (`github.com/u2giants/licensor-source-data`). Installing into every worktree is correct for Claude/Codex project skill loading.
- **Repo identities** for scoping come from `config/repo-identities.tsv` (`licensor-source-data` added). Fail closed if the origin remote is not in that table.
- **Windows Git Bash is process-starved** under bulk `find|xargs sha256sum`. Cache and `cp -a`.
- **ai-task-gates** was started `--class code` at session start; `check --before ship` allowed ship after local-tests acknowledgment (four suites green).

## 6. Exact next steps

1. **After Albert restarts Claude Desktop on edge-dev:**  
   `pwsh bin/check-mcp-drift.ps1` → expect PASS for the Desktop copies. Reopen Desktop, re-run → still PASS. Comment on #731 with the two PASS lines, close #731, set plan row **1.2 ✅** with evidence.  
   *You'll know it worked when* the drift check exits 0 twice (before and after reopen) and #731 is closed.  
   (If the Claude Code set still reports extras, that is phase 3 / #705 scope, not #731.)

2. **Then start #704’s successor on #707: phase 3 = #705 (repo-scoped MCP servers).** Follow #707’s body: take only that phase, assign the child, finish it, tick, comment next child, stop. Read `plan_tool-and-skill-scoping.md` STATUS first.  
   *You'll know it worked when* a session opened in `oracle` has `trigger` and one opened in ai-devops does not (plan step 3.2 done-when).

3. **ENVY runner (separate issue first).** Open **one** tracking issue with an `owner:` line, then investigate: why ENVY skipped PR #718’s reviewer suites so `reviewer-safety-start-deadline` set fallback and job `windows-reviewer-fallback` (107344814124) ran on GitHub-hosted windows-2025 ~19:27–20:17Z; how often fallback fired in the last 20 PR runs; whether edge-dev-win can be qualified as a second fast runner (`ai-devops-windows-qualified`). Fix via PR; prove with a run where fallback is skipped.  
   *You'll know it worked when* a PR’s reviewer suites run on a self-hosted qualified runner and the fallback job stays skipped.

## 7. Constraints and gotchas in force

- Never write `claude_desktop_config.json` while Claude Desktop is running (the app rewrites its in-memory list over the file). Quitting Desktop ends Code-tab sessions inside it.
- Docs-only PRs admin-merge immediately (`gh pr merge --squash --admin`). Code PRs go through the merge queue (`bin/ai-pr-wait`). Merge queue rejects `--delete-branch` and `--squash` flags — plain `gh pr merge <n>`.
- `gh pr checks` status column: filter on column 2 — grepping "fail" matches the job name `report-scheduled-failure`.
- CRLF: scripts stay LF (`git ls-files --eol`).
- Never push to `main`. Branch + PR + merge queue.
- Protected skills (`config/skill-trigger-policy.json`) stay global and auto-invocable.
- Do not remove a constrained MCP server to save tokens.
- One #707 phase per session.
- Time quotes in EST (America/New_York).

## 8. Access and environment

- Machine: **edge-dev** (Windows 11). `gh` authenticated as `u2giants`.
- Landing checkout: `C:\repos\ai-devops` (landing-only). Write work uses worktrees.
- Desktop config: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json` (same file as `%APPDATA%\Claude\...`).
- Waiter log (if setup was re-run): `%USERPROFILE%\.config\ai-devops\state\claude-desktop-mcp-sync.log`.
- Git Bash: `C:\Program Files\Git\bin\bash.exe` (not WSL; WSL has no distro here).
- Claude CLI: `C:\Users\ahazan\.local\bin\claude.exe`.
- Secrets: 1Password vault `vibe_coding` only (none needed this session).
- Owning repo clone: `C:\repos\licensor-source-data` (origin `github.com/u2giants/licensor-source-data.git`).

## 9. Open questions and risks

- Whether the hidden Desktop MCP waiter survives a reboot before Desktop is quit (if not, re-run `setup-machine.ps1`). (2026-09-23)
- CI flake: `windows-offline-section (4)` “undiscovered suite: test-ai-adopt-globals.sh” — one occurrence, re-run green. Track only if it repeats. (2026-09-24)
- Plugin-duplicated skills (`anthropic-skills:` copies of grok-cli, kimi-code-delegation, synology-sharesync-triage) are outside this repo — measure in #706 phase 4.1. (2026-09-23)
- EDGE-ALIEN Desktop mcpServers empty; ENVY has no Claude — neither blocks #731. (2026-09-23)
- `licensor-source-data` worktree count is large (~22); scoped installs are slower on Windows than global ones. Acceptable; do not “optimize” by skipping worktrees without an owner ruling.

---

## Self-audit (handoff-writer gate)

1. **Comprehensive for a brand-new developer?** Yes — §1 app, §3 exact state with SHAs/PR, §6 numbered next steps with done-when gates, §8 access.
2. **As effective as the writer right now?** Yes — §4 dead ends (fork exhaustion, quarantine-without-marker, relative exclude path, CI flake), §5 locations and identity rules, §7 merge-queue and Desktop-write traps.
3. **Every relevant detail?** Yes — background (§2), goals (§2), outcome (§3), failures (§4), decisions (§0 + §5), constraints (§7), risks (§9), next actions (§6), evidence (§3 tests + live `claude -p`).
4. **Section 0 alone complete?** Yes — Desktop restart is the only blocking owner action; ENVY is listed as a non-blocking owner-visible item with a recommendation; settled list prevents re-asking. Sweep of §1–§9 found no other owner-only decision.

**Retired predecessor on write:** `HANDOFF.d/2026-09-23T2100Z-edge-dev-claude-707-phase1-and-envy-runner.md` — its phase 1 work is on `main` (`8e22150c` / `95816b0b` / `6a6b2ca3`); #731 and ENVY are carried forward in §3 and §6 of this file; no decision is lost (§0).
