---
issue: 1663
status: BLOCKED
owner: mimo/housekeeping-leftover-and-machine-classes
---
# HANDOFF — housekeeping leftover triage, machine classes, Railway remainder (2026-10-13T2037Z, edge-dev/mimo)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**BLOCKING** — none. The remaining work is a technical access problem (`Blocked —`), not a business question.

**RECOVERABLE** — none. Owner already chose every triage approach this workstream needed.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT**
- None discovered this session that still needs a ruling. ScreenConnect on Wayland is closed as impossible (owner already ruled). Machine classes are documented.

**Already settled — do NOT re-ask**
- 2026-10-13 (this session, Albert chat): unattributed handoffs first; then one real issue per live `issue: none` workstream and retire the rest with reviewer agreement; keep the 16 retained-record plans forever.
- 2026-10-13 (this session, Albert, verbatim): "ConnectWise ScreenConnect will never work with Wayland. close that out."
- 2026-10-13 (this session, Albert, verbatim): "edge-alien, edge-runn-envy, and edge-runn-xps are not dev machines and should not be getting any of the ai-devops toolkit aside from the networking stuff (ssh key, ssh config, hostnames, tailscale, etc.). document this in a conspicuous place in the documentation because this mistake keeps happening"
- 2026-08-13: no file-count cap on `HANDOFF.d/`; count SUCCESSOR REVIEW, not files.
- 2026-08-13 / plan R4: do not sweep root `plan_*.md` whose STATUS is all done.

Put any NEW business question to the owner in ONE message before starting work.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI workflow (Claude, Codex, MiMo, ZCode, reviewers). It is not an app or service. Housekeeping tooling is
https://github.com/popcre/ai-devops/blob/main/bin/ai-housekeeping
(documented in https://github.com/popcre/ai-devops/blob/main/docs/housekeeping.md).
Machine classes now live in
https://github.com/popcre/ai-devops/blob/main/docs/deployment.md
§ Machine classes and the README setup warning.

## 2. What we set out to do this session, and why

Resume housekeeping leftover triage after parent #1585 closed (handoff
https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-13T1126Z-edge-dev-mimo-housekeeping-leftover-triage.md ).
Then act on three owner rulings: close ScreenConnect, document networking-only machines, clear open items. Finally `wrap up` with this closeout.

Tracking issue for leftover triage batches: https://github.com/popcre/ai-devops/issues/1661 (now closed).

## 3. Current state — what is true right now

Verified on `origin/main` (tip was `ecb4ff76` at closeout time).

| Outcome | Evidence | State |
|---|---|---|
| Batch 1 — 8 UNATTRIBUTED handoffs got contract blocks | PR https://github.com/popcre/ai-devops/pull/1664 merge `0d97e9fe` | done |
| Batch 2 — UNPROVABLE 18→0 (8 retargeted, 10 retired after DeepSeek APPROVE) | PR https://github.com/popcre/ai-devops/pull/1694 merge `71a869d7` | done |
| ScreenConnect closed as Wayland-impossible; handoff retired | issue https://github.com/popcre/ai-devops/issues/1662 closed; PR https://github.com/popcre/ai-devops/pull/1670 merge `4ae0f464` | done |
| Machine-class docs (networking-only hosts) | PR https://github.com/popcre/ai-devops/pull/1690 merge `0f126411` | done |
| #1661 leftover branch/worktree checklist | already gone; ticked on #1661 | done |
| edge-alien Railway MCP | live probe: clean (no railway, no codex config, no toolkit) | done |
| t16 + 916 Railway MCP | **not done** — SSH port 22 times out | **BLOCKED** |
| issue https://github.com/popcre/ai-devops/issues/1663 | OPEN, evidence comment posted | open |

**Not started (intentionally, after owner picks):** implementing the six new live workstreams the batch-2 subagent filed (#1676–#1681). Those are ordinary next sessions, not this closeout's job.

**Machine-class rule now on main** (do not re-document):
- README.md warning block at "Set up a new machine"
- docs/deployment.md § Machine classes
- AGENTS.md repository-contract bullet
- templates/system/machine-atlas.md class table

## 4. Everything we tried that did NOT work

- **`bash` on PATH is WSL / PowerShell steals pipes.** `| tail` in a PowerShell-wrapped `& bash -lc '...'` runs `tail` on Windows and fails. Quote carefully or write a script file.
- **Git Bash MSYS path conversion breaks remote Windows commands.** `/tmp/foo` becomes `C:\tmp\foo` in `ssh`/`scp` arguments. Use `MSYS_NO_PATHCONV=1` or `C:/Users/...` paths explicitly when talking to Windows hosts.
- **`ssh ahazan@host "bash script"` failed with `'bash' is not recognized`** on edge-alien because that host is **Windows**, not Linux. Detect with `hostname`/`ver` first. `python` works there.
- **SSH to t16 and 916 times out** even from edge-alien (same Tailscale tailnet, ping 0). BatchMode, key `~/.ssh/916-alien`. Not a DNS problem: both names resolve on the tailnet. Hostname `916-alien` does not resolve; Tailscale calls that host `916`.
- **`bin/ai-gh` throttle lock hangs** under concurrent sessions (`sleep 0.25` killed / `mv` reclaim terminated). Retry with a longer timeout, `AI_GH_MIN_SPACING_SECONDS=0`, sometimes `AI_GH_NO_WAIT=1`. Never bare `gh` for routine calls.
- **`ai-task-gates` with `--base origin/main` is wrong** when origin/main has moved past your merge-base: it diffs main-tip→HEAD and invents other sessions' files into your change set. Use `--base $(git merge-base HEAD origin/main)`.
- **`ai-pr-wait` on a prose PR** refuses via task-gates and prints a hint to use `--admin`. Standing rules forbid `--admin`. Let auto-merge / merge queue land docs-only PRs instead.
- **linux-offline-shard (3) StepFun door test flake** (`FAIL StepFun door catalog follows an explicit Step model override` in `test-ai-review-engine.sh`) failed once on a docs-only PR; `bin/ai-gh run rerun <id> --failed` fixed it. Not caused by prose changes.
- **Fine-grained PAT / App tokens cannot merge** (handoff §4 of the prior closeout). Merge queue still needs classic OAuth `gho_`.

## 5. Root causes and key findings

- Owner machine classes are real product policy: `edge-alien`, `edge-runn-envy`, `edge-runn-xps` get networking only. Full toolkit installs on them are always mistakes.
- ScreenConnect cannot drive Plasma Wayland (Xwayland capture is black). RDP/KRDP is the supported remote path on edge-dev3. Decision is closed — do not reopen ConnectWise case #03766621.
- `ai-housekeeping` classifies a handoff as UNATTRIBUTED only when the first 30 lines have no `issue:`/`status:`/`owner:` line. Bare numeric `issue:` + closed GitHub issue → SUCCESSOR REVIEW (retirement candidate). `issue: none` / `issue: null` / non-bare text → UNPROVABLE.
- A finished `HANDOFF.d/` file is deleted under the successor rule (three proofs), never `status: DONE`.
- Git Bash + Windows OpenSSH + MSYS is a recurring trap when managing Windows fleet hosts from edge-dev.

## 6. Exact next steps

1. Open access to Windows OpenSSH (or another admin path) on **t16** and **916** (a.k.a. 916-alien). Evidence of the block: ping works, TCP/22 times out from edge-dev and edge-alien with the `916-alien` key. You'll know it worked when `ssh -i ~/.ssh/916-alien -o IdentitiesOnly=yes ahazan@t16 hostname` returns `t16` (same for 916).
2. On each host, inspect and clear Railway MCP if present:
   - Claude: `~/.claude.json` top-level `mcpServers.railway` and every `projects.*.mcpServers.railway`
   - Codex: `[mcp_servers."railway"]` in `~/.codex/config.toml`
   - Do **not** re-run `setup-machine.ps1` on networking-only hosts. Remove entries; keep popdam Railway only where popdam lives (not these hosts).
3. Verify: `claude mcp list` inside an ai-devops checkout shows no railway; popdam checkout (if any) keeps its entry. Comment the result on https://github.com/popcre/ai-devops/issues/1663 and close it when both hosts are clean.
4. Do **not** install the toolkit on `edge-alien`, `edge-runn-envy`, `edge-runn-xps` (rule is on main).
5. Optional follow-on (new sessions, not this closeout): implement the live workstreams filed as
   https://github.com/popcre/ai-devops/issues/1676
   through
   https://github.com/popcre/ai-devops/issues/1681
   .

You'll know the Railway remainder is done when #1663 is closed with live-clean evidence for both hosts.

## 7. Constraints and gotchas in force

- Branch policy: feature branch + PR + merge queue; never push `main` directly; never `--admin`.
- Stage only task-owned files. Identity must be `Albert Hazan <u2giants@users.noreply.github.com>` before commit.
- Every GitHub call through `bin/ai-gh`. `bin/ai-housekeeping` is report-only.
- Do not edit another session's `HANDOFF.d/` file. Do not rewrite root `HANDOFF.md`.
- Do not `git branch --merged` as merge proof (Finding 4 / D3).
- Networking-only hosts get SSH key, SSH config, hostnames, Tailscale — nothing else.
- Documentation-only PRs (all prose) may merge immediately via merge queue.
- Windows hosts: use Git Bash explicitly (`C:\Program Files\Git\bin\bash.exe`); `MSYS_NO_PATHCONV=1` when passing paths to `ssh`/`scp`.

## 8. Access and environment

- Repo: https://github.com/popcre/ai-devops on `origin/main`.
- Machine: `edge-dev`, Windows 11. Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- GitHub CLI: OAuth `u2giants` (classic `repo`) worked for merge queue this session.
- Fleet SSH key for alien/runner hosts: `~/.ssh/916-alien` (`IdentitiesOnly=yes`, user `ahazan`).
- Reachable this session: `edge-alien` (Windows, on the Tailscale tailnet) — Railway already clean.
- Unreachable over SSH: `t16`, `916` — ping yes, TCP/22 no. Resolve both on the tailnet first; addresses stay in the private machine atlas.
- Networking-only (do not install toolkit): `edge-alien`, `edge-runn-envy`, `edge-runn-xps`.
- Secrets live in 1Password vault `vibe_coding` only — never by value here.

## 9. Open questions and risks

- 2026-10-13: Windows OpenSSH on t16/916 may simply be off or firewalled; another admin path (ScreenConnect/RDP/console) may be required. Do not weaken host firewall blindly.
- 2026-10-13: `ai-gh` lock contention on edge-dev is frequent when multiple sessions run; plan for retries.
- 2026-10-13: one docs-only PR hit a StepFun reviewer-engine flake; treat a red `linux-offline-shard (3)` with that test name as flake-first, rerun before rewriting the change.

## Part (b) — sub-agent blocks this session

### general-1 — UNPROVABLE handoff batch 2
Asked: give still-relevant `issue: none` handoffs real issues and retire the rest if a reviewer agrees. Did: 8 retargeted, 10 retired after DeepSeek APPROVE (`.ai/reviews/deepseek-plan-review-20261013T165402-99732-9242.md`), PR #1694 merge `71a869d7`. Also found: plan-review works on Windows edge-dev; Grok out of credit; clean worktree required for `ai-review`; HTTPS `git push` hangs (use SSH remote); new markdown needs a README link for `ai-doc-reachability`.

---

## Self-audit (mandatory)

1. **Comprehensive for a brand-new developer?** Yes — §1–§9 cover product, goal, live PRs/SHAs, dead ends (MSYS/Windows SSH/ai-gh lock), exact next steps with gates, constraints, access, and the networking-only rule.
2. **As effective as this session?** Yes — owner rulings are quoted verbatim, Railway live-probe results are recorded, and the SSH block is named with the exact hosts and evidence.
3. **Every relevant detail?** Yes — what landed (four PRs), what is blocked (#1663 on t16/916), what must not be redone (docs on main), and how to verify.
4. **Section 0 has every owner decision and no technical approval?** Yes — three settled owner rulings listed with "do NOT re-ask"; remaining blocker is technical access (`Blocked —`), not an ask to Albert.
