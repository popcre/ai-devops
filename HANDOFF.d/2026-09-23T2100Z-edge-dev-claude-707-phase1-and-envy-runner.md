# Handoff — #707 phase 1 closed; two deferred items (Desktop live proof, ENVY runner)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE
- None. Albert only needs to quit and reopen Claude Desktop once on edge-dev (a click, not a decision); that unblocks #731.

## 1. What this application is
`popcre/ai-devops`: Albert's machine setup, AI-client configuration, skills, reviewer wrappers and CI for all his machines.

## 2. What we set out to do this session, and why
Issue #707 (tool/skill scoping, parent issue) phase 1 = #703: stop installed Claude MCP servers and skills drifting from declared membership, because every extra server/skill costs context in every session.

## 3. Current state — what is true right now
- #718 merged as `8e22150c`: new `bin/sync-claude-desktop-mcp.ps1` (prunes undeclared managed servers; refuses to write while Claude Desktop runs, exit 3; `-WaitForDesktopExit` waiter), setup-machine.ps1 step 6 calls it and launches a hidden waiter on exit 3, new `bin/check-mcp-drift.ps1`, `tests/test-mcp-skill-drift.ps1` (15 pass, in the powershell manifest list), `disable-model-invocation: true` on designflow-human-qa and kimi-code-delegation.
- #732 merged as `95816b0b`: STATUS table in `plan_tool-and-skill-scoping.md` (1.1, 1.3, 1.4 done; 1.2 code merged, live proof open).
- #703 closed; #707 box ticked with comment "Phase 1 done (8e22150c)... Next: #704."
- `C:\repos\ai-devops` main checkout pulled to `8e22150c`.
- edge-dev drift check currently FAILS (extra: chrome-devtools, codex-cli, devops-mcp, supabase) — expected until Desktop is restarted.

## 4. Everything we tried that did NOT work
- Pruning the Desktop config while the app runs: the app rewrote its in-memory 10-server list over the file (setup backups show pruned to 7 on 2026-09-04T22:49Z, back to 10 by 2026-09-18T01:27Z).
- A first sed edit of the plan STATUS table mangled the file (CRLF + `#` delimiter); redone with exact edits before merge.

## 5. Root causes and key findings
- Claude Desktop owns `claude_desktop_config.json` while running; the MSIX and Roaming copies on edge-dev are the same file.
- Runner pool: 3 self-hosted Windows runners online. Only EDGE-RUNN-ENVY carries `ai-devops-windows-qualified` (verify.yml ~line 384). EDGE-ALIEN is labelled paused (slow, EDR). edge-dev-win is online but unqualified. On PR #718 ENVY did not take the reviewer suites; `reviewer-safety-start-deadline` set fallback_required and job `windows-reviewer-fallback` (job 107344814124) ran on GitHub-hosted windows-2025 for ~50 min (19:27–20:17Z), running test-ai-codex-review.sh and test-ai-grok-review.sh serially. Grok alone ~41 min hosted; Grok breaks under hosted concurrency, so splitting only saves ~9 min.

## 6. Exact next steps
1. After Albert restarts Claude Desktop: run `pwsh bin/check-mcp-drift.ps1` on edge-dev → expect PASS for the Desktop copies; reopen Desktop, re-run → still PASS. Record on #731, close it, set 1.2 ✅ in the plan STATUS table. (If the Claude Code set still reports extras, that is phase 3 scope, not #731.)
2. Then start #704 per #707.
3. ENVY investigation (not started, no issue yet) — give a new session this prompt: investigate why ENVY missed PR #718's reviewer suites so fallback ran; read the deadline job log; check how often fallback fired in the last 20 PR runs; assess qualifying edge-dev-win as a second fast runner; fix via PR, prove with a run where fallback is skipped; open one tracking issue with an `owner:` line first.

## 7. Constraints and gotchas in force
- Never write the Desktop config while the app runs. Quitting Desktop ends any Code-tab session inside it.
- Docs-only PRs admin-merge immediately; code PRs go through the merge queue (`bin/ai-pr-wait`).
- `gh pr checks` status column: filter on column 2 — grepping "fail" matches the job name `report-scheduled-failure`.

## 8. Access and environment
edge-dev (Windows 11), gh authenticated as u2giants, Git Bash + pwsh 7. Desktop config: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`. Waiter log: `%USERPROFILE%\.config\ai-devops\state\claude-desktop-mcp-sync.log`.

## 9. Open questions and risks
- Whether the hidden waiter survives a reboot before Desktop is quit (if not, re-run setup-machine.ps1).
- EDGE-ALIEN Desktop mcpServers is empty (app wipe) and ENVY has no Claude; neither blocks #731.
