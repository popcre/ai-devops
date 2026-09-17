---
issue: 558
status: OPEN
owner: zcode/plan-zcode-windows-support-558
---

# HANDOFF — ZCode for Windows parity plan (2026-09-17 ~19:55Z, edge-dev/zcode)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Settled by the owner on 2026-09-17 (plan review, later the same day) — do not
relitigate:** (1) NO ZCode-based reviewer, ever — "I never want GLM reviewing GLM
code," and ZCode's engine is GLM-5.3; the drafted Step 9 was removed permanently.
(2) The `zcode-config-repair` skill is killed — ZCode's own `zcode-guide` plugin
documents that content. (3) No ported Claude memory-index hook. (4) Transcript mining
is wanted, and is designed ZCode-natively (SQL over the copied session DB) rather than
copying the Claude/Codex JSONL approach.

Still open, none blocking Steps 1–8: the final ZCode MCP membership set; the
`~/.agents/skills` junction disposition; and — now filed as
[u2giants/shared-db#3232](https://github.com/u2giants/shared-db/issues/3232) — enforcing
glm-reviewer exclusion for ZCode-orchestrated structural work (see §5 below). **ZCode
native memory: the owner enabled it himself on 2026-09-17** — recorded in plan §13.
Do not treat this open handoff as authorization to run paid/live qualifications or
touch any machine other than edge-dev.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI workflow:
Bash/PowerShell commands, tests, machine setup, skills, and docs. Installing the toolkit
is deployment; there is no app UI or database. This session ran **inside ZCode itself**
(the third interactive client, alongside Claude Code and Codex) on Windows machine
`edge-dev`. The complete executable specification for the work is
[plan_zcode-windows-support.md](../plan_zcode-windows-support.md) — this handoff is its
discovery and continuation record, not a competing plan.

## 2. What we set out to do this session, and why

Albert asked (2026-09-17) to extend what ai-devops does for Claude for Windows and Codex
for Windows to **ZCode for Windows**, using the implementation-plan-writer skill. ZCode
is in daily use on edge-dev but receives no managed treatment: its only integration is
the blocker-watch wake harness. The machine also carries hand-made, unmanaged ZCode
state (an `~/.zcode/skills` junction to `~/.claude/skills`, an `~/.agents/skills`
junction to `~/.codex/skills`, and no `~/.zcode/cli/config.json` at all). The deliverable
this session is the plan, its planning issue (#558), and this handoff — not
implementation.

## 3. Current state — what is true right now

- Planning issue [#558](https://github.com/popcre/ai-devops/issues/558) is open.
- `plan_zcode-windows-support.md` is committed at the repo root with a 12-step STATUS
  table, all rows ⬜ open, on branch `plan/zcode-windows-support-558` (worktree
  `/c/repos/ai-devops-worktrees/zcode-plan-558`, cut from `origin/main` `c9a92ce9`).
- Task gates declared: class `prose` for the plan PR (recorded by `ai-task-gates start`).
- ZCode on edge-dev: desktop `3.12.3.7463`, CLI core `0.16.5`, authenticated (Z.AI OAuth,
  GLM-5.3), `~/.zcode/cli/config.json` absent, junctions as above. Facts verified
  2026-09-17 and recorded in the plan §5–§6.
- Open branch `feat/blocker-watch-coverage-549` (zcode wake notes) may land while this
  plan is open; the plan tells implementers to rebase onto main first.

## 4. Everything we tried that did NOT work

- Background research agents are not available in this ZCode session's mode — the two
  research sweeps (ai-devops integration inventory; ZCode config surface) had to run as
  foreground agents. No work was lost; noted so the next session does not retry the
  background dispatch and assume failure.
- `.zcode-install-manifest` under `C:\Program Files\ZCode` was reported by an inventory
  pass but could not be read back directly (the file listing came from the app directory
  walk). The plan therefore routes install-source discovery through registry + winget
  search in Step 1 rather than trusting that filename.

## 5. Root causes and key findings

There is no defect — ZCode was never onboarded. It arrived as a desktop app and skipped
the provider-onboarding pattern (version policy, installer, wrapper, TSV row, skill,
tests, doctor) that Kimi (#31) and Grok (#251) went through. The load-bearing ZCode
facts, each verified and sourced in the plan §6: full headless CLI surface (`-p`,
`--mode plan`, `--allowed-tools`, `--max-turns`, `--json`, `--resume`, `doctor`,
`login --no-browser`) with a dangerous `--prompt` default of `yolo`; strict MCP schema
in `~/.zcode/cli/config.json` → `mcp.servers` (one unknown key silently drops the
server; no `${...}` expansion — absolute paths); hooks mirror Claude's seven events but
need `hooks.enabled: true`; `~/.zcode/AGENTS.md` is the global-instruction analog;
sessions live in SQLite + rollout JSONL; two version numbers and electron self-update
make presence-only version policy correct.

**Finding from the 2026-09-17 owner review (cross-repo, unfiled):** the owner's rule
"GLM never reviews GLM code" is NOT enforced for ZCode orchestrators in
`u2giants/shared-db`. `scripts/manage-migration-author-lanes.mjs`
(`reviewersForOrchestrator`, ~:553) excludes only reviewers whose `orchestratorEngine`
matches the orchestrator marker's declared engine; the `glm-5.3` reviewer row (~:274)
declares no `orchestratorEngine`, and the marker vocabulary has no `zcode`. So a
ZCode-orchestrated structural change could today draw the glm reviewer. Fix belongs in
shared-db (give glm rows `orchestratorEngine: 'glm'`; map a zcode orchestrator marker
to engine `glm`) — plan §13 open question 2 records it; no shared-db issue filed yet.

## 6. Exact next steps

1. A fresh session opens [plan_zcode-windows-support.md](../plan_zcode-windows-support.md),
   reads its STATUS table, and starts at Step 1 (freeze the ZCode Windows baseline into
   `tests/verification/zcode-windows-2026-09-17/README.md`).
2. Follow the plan's phases A→D in order; declare the honest task-gate class per PR
   (`installation` for installer/setup/machine-tools hunks — the only protected class
   left; the reviewer-safety step was removed permanently on 2026-09-17).
3. After each completed step, update the plan's STATUS table with a reproducible
   artifact; after the plan's PR merges, retire nothing until implementation ends —
   this handoff stays OPEN while any STATUS row is open.

## 7. Constraints and gotchas in force

Branch + PR + merge queue; never push `main`; verify the pinned git committer identity;
work only in isolated worktrees; all `gh` calls via `bin/ai-gh`; CI waits via
`bin/ai-pr-wait`; check `bin/ai-test-local --check-collision` before local suites;
public repo — no secrets/transcripts/personal data; 1Password by location only. ZCode
traps: strict MCP schema, `hooks.enabled` default-off, `--prompt` defaults to yolo,
junction deletion must be non-recursive, SQLite store copy-before-read, never edit
anything under `C:\Program Files\ZCode`, credentials checked by existence only. Full
list in the plan §11.

## 8. Access and environment

Machine `edge-dev`, user `ahazan`. Repo checkout `C:\repos\ai-devops` (landing-only);
plan worktree `/c/repos/ai-devops-worktrees/zcode-plan-558` (branch
`plan/zcode-windows-support-558`). ZCode app `C:\Program Files\ZCode\ZCode.exe`; headless
probe pattern and all paths in the plan §12. 1Password service-account location: vault
`vibe_coding`, item `vibe_coding-service-account`, field `op_service_account_token`
(location only). Private destinations: `u2giants/ai-devops-transcripts`,
`u2giants/ai-devops-private-config`. `gh`, `op`, `git` authenticated on edge-dev.

## 9. Open questions and risks

The four owner decisions in §0 above; plus the plan §13 risk register — ZCode
self-update breaking the CLI contract (wrapper fails closed and is re-qualified), the
junction migration on a real profile (fixture-tested first; non-recursive), silent
strict-schema drift across ZCode releases (doctor checks managed entries), and hooks
misbehaving in daily sessions (fail-open design + writer backups restore the
pre-hooks file). Nothing in the plan touches vendor bytes or other clients' config, so
the blast radius is confined to `~/.zcode` and `~/.local/bin`.
