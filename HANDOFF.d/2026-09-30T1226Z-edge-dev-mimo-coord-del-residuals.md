---
issue: 1061
status: OPEN
owner: mimo/coord-del-parent-1061
---

# HANDOFF — coord-del residuals after parent #1061 closed

Machine: edge-dev · Agent: mimo · Written: 2026-09-30T12:26Z
Signature line used on GitHub this session: `Posted by MiMo chat ses_ffe5f11088f5cffeSHgdXquBqY on edge-dev`

## 0. BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- Whether to re-adopt globals on **Hetz** (`ssh vps2-direct`) and **t16** when reachable. Production host is read-only by default; adopt is an install action, not a deploy.
- Whether to open a small code fix for `config/machine-tools.tsv` duplicate rows now or wait (it breaks `bin/ai-adopt-globals` launcher sync on every machine).
- Whether mid-work sessions must be manually poked with the claim-first blurb, or only new/restarted sessions matter.

## 1. What this application is

`popcre/ai-devops` is Albert's public AI workflow toolkit (rules, skills, task gates, plans). Parent workstream: delete the shared-db **coordination** layer (C by deletion) while keeping the claim/lease/review/live-proof **safety engine** in `popcre/shared-db`. Plan: `plan_shared-db-coordination-deletion.md`. Background: `docs/shared-db-delivery-failure-background-2026-09-29.md`.

## 2. What we set out to do this session, and why

Implement every child of parent issue **#1061** until the parent could close: rename `orchestrator-claim` → `claim-admission`, delete leftover-proof ticket milling, demote orchestrator role to claim-first, stop chat merge conductors, re-point stuck-work watchdog, SHRINK BlockerWatch registration, no path filters on required checks, supersede old plan STATUS rows, fleet re-adopt globals, start the 14d/30d measure. Coordination-only session: all implementation was done by subagents.

## 3. Current state — what is true right now

**Parent #1061 CLOSED** 2026-09-30T05:43Z. All children closed (#1062–#1077 including dups).

| PR | What landed | Merge |
|---|---|---|
| #1107 | PR-A steps 1+2 (#1065 #1066) | `10587d46` |
| #1132 | Fix broken Markdown links that blocked every merge-group | `cc387b9f` |
| #1105 | PR-D step 8 plan STATUS supersessions (#1075) | `a56f53c3` |
| #1138 | PR-B steps 3+5 (#1067 #1071) | `37773789` |
| #1151 | PR-C steps 4+4B+6 (#1069 #1070 #1073) | `1283d37b` |
| #1157 | STATUS citations for PR-C | `eb8d7dd2` |
| #1158 | Step 10 measurement record started (#1077) | `4a2d7a64` |
| #1159 | Step 9 adopt edge-dev proof (#1076) | `1ba63562` |
| #1160 | Step 9 adopt edge-dev3 proof | `8706242c` |
| #1161 | Step 9 adopt al8960ofc + t16 unreachable proof | `5b64015e` |

Plan STATUS on `origin/main` marks steps 0–8 done, 9 proven edge-dev/edge-dev3/al8960ofc with t16 residual, 10 started.

**Fleet adopt of new claim-first globals:** edge-dev ✅ · edge-dev3 ✅ · al8960ofc/4837 ✅ (Claude+Codex; ZCode/MiMo not installed there) · **t16 unreachable** · **Hetz NOT done**.

**Hetz fact (checked 2026-09-30 via `ssh vps2-direct`):** host reachable as `hetz`; `/worksp/ai-devops` is **detached at `c5f1c39`** (pre-coord-del); installed globals do **not** carry claim-first / no-leftover-proof wording. `bin/ai-adopt-globals` exists in that stale checkout. Earlier attempt used `ssh -i ~/.ssh/916-alien ai@178.156.180.212` and timed out — wrong path; **use `ssh vps2-direct`**.

**New rules brand-new sessions see** (once their machine's globals are adopted): in each installed global — “Shared-db structural work is claim-first. Claim exact objects on the existing issue and start; no orchestrator chat or marker is required.” Plus `shared-db-orchestrator` skill is optional reference; `shared-db-change` is the full procedure. Mid-work sessions only pick this up after restart/reload of their global.

## 4. Everything we tried that did NOT work

- Direct SSH to Hetz IP with `916-alien` key → connection timeout. Working path is `ssh vps2-direct`.
- PR-A merge-group kept ejecting: `tests/test-markdown-links.sh` failed on **pre-existing** broken links from #1119 (`docs/reviewer-failure-full-writeup.md` → missing `reviewer-failure-evidence/`; `plan_reviewer-pipeline-core.md` → missing handoff). Fixed in #1132; do not re-add the private evidence folder link.
- First PR-B CI red: Step 3 rewrite dropped Codex task-profile diagnosis text (`Access is denied` / `task-profile`) that `tests/test-codex-github-cli-access.ps1` requires in **both** SKILL.md and operating-manual.md. Restored as reference troubleshooting.
- `test-ai-qwen.sh` late-signal finalize tests are timing-flaky on Windows blacksmith — rerun, do not “fix” product code.
- PR-C fixer deletion broke `tests/test-ai-blocker-watch.sh` fixture (`config-fixer.json` gone). Fixed by building `config-sw.json` from `config.json` with `fixer_enabled=false`.
- `bin/ai-adopt-globals` from a linked worktree dies at `install-machine-tools.ps1` (durable launchers refuse disposable worktrees). Completing globals is safe with `AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1` when launchers must keep pointing at the canonical checkout; verify with `ai-machine-tools-doctor`.
- `bin/ai-task-gates start` defaults base to old merge-base; after rebase pass `--base origin/main` or it wrongly escalates to reviewer-safety.

## 5. Root causes and key findings

- Safety engine (claims/versions/leases/review/live proof) was never the failure; coordination volume was. C-by-deletion shipped that split.
- Merge queue is the only merge path for code; docs-only can `--squash --admin`. A red `test-markdown-links` on main blocks **every** PR.
- `config/machine-tools.tsv` has **duplicate rows** for `ai-blocker-watch` and `ai-reap-shared-db-worktrees`. `bin/install-machine-tools.ps1:74` throws `Machine-tools catalog has an unsafe or duplicate command name` → `SYNC INCOMPLETE` on adopt. Residual code fix.

## 6. Exact next steps

1. **machine-tools.tsv fix** (small code PR): remove the second `ai-blocker-watch` and `ai-reap-shared-db-worktrees` rows in `config/machine-tools.tsv` only. Gate: the machine-tools install tests named in `config/ci-suite-manifest.json` / `tests/test-install-ai-provider-clis.sh` / Windows install tests. Then re-run `bin/ai-adopt-globals` on a host to prove launcher sync.
2. **Hetz re-adopt:** `ssh vps2-direct`, update `/worksp/ai-devops` to `origin/main` tip (currently detached `c5f1c39` — check for local changes first), then `bash bin/ai-adopt-globals`. Record proof under `tests/verification/shared-db-coordination-deletion/`. Production host — install of toolkit rules is not a deploy; still treat as carefully as install allows.
3. **t16 re-adopt** when online (atlas: no SSH alias from edge-dev; Tailscale was down).
4. **14d measure** due **2026-10-14** (open/close ratio query already documented in `tests/verification/shared-db-coordination-deletion/2026-09-30T045654Z.md`). **30d** due **2026-10-30** (collisions + duplicate-need). Stop rule: named assignee on that issue — never rebuild an orchestrator.
5. Tell mid-work sessions (if Albert wants them nudged): claim-first blurb in §3.

## 7. Constraints and gotchas in force

- Do **not** reopen #401. Do **not** add orchestrator role, leftover-proof ticket mill, chat merge conductor, BlockerWatch registration, or path-filtered required checks.
- Do **not** drop shared-db freshness until #2530.
- Route string `shared-db-orchestrator` stays; only required-ness is gone.
- Stage only named files; worktrees from `origin/main`; `git var GIT_COMMITTER_IDENT` = Albert before commit; never push `main`.
- Signature: `Posted by MiMo chat ses_ffe5f11088f5cffeSHgdXquBqY on edge-dev`.
- Canonical checkout `C:\repos\ai-devops` is landing-only and currently has other sessions' dirty files — do not tidy them.

## 8. Access and environment

- GitHub: `bin/ai-gh` via Git Bash (`"C:\Program Files\Git\bin\bash.exe"`); plain `bash` on this host is WSL and fails.
- Hetz: `ssh vps2-direct` (user context on that host is `ai` under `/worksp/ai-devops`).
- edge-dev3: `ssh -i ~/.ssh/916-alien ahazan@edge-dev3`.
- al8960ofc/4837: Tailscale often down; LAN `192.168.2.131` as user **`ahazan2`** with 916-alien; remote default shell is cmd.exe.
- Machine atlas (private): `bin/ai-private-config path machine_atlas`.

## 9. Open questions and risks

- Hetz stale checkout may have local work before any force-update — inspect before reset.
- Mixed-rule fleet window until Hetz/t16 adopt (a session there may still mint leftover-proof issues or wait on an orchestrator).
- `machine-tools.tsv` duplicates will keep `SYNC INCOMPLETE` on every adopt until fixed.
- Residual duplicate-need tickets at 3×4 harnesses accepted; measured in step 10.

---

## Self-audit

1. **Could a brand-new developer continue cold?** Yes — PR/merge table, Hetz SSH fact, exact next steps, gates, constraints.
2. **Tried-and-failed included?** Yes — §4 (wrong SSH, link failures, Codex diagnosis text, Qwen flake, fixture break, worktree adopt, task-gates base).
3. **Business-only decisions separated?** Yes — §0.
4. **Issue named?** #1061 (parent, closed); residuals listed for next session to open as needed.
5. **Secrets:** none appeared this session (SSH keys pre-existed; no tokens pasted). Secrets sweep: swept, nothing new.
6. **Docs:** plan STATUS on `origin/main` is the durable record; this file is residual handoff. Nothing outside is stale except items named in §6.

**Self-audit passed.**
