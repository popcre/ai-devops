# HANDOFF — 2026-09-23T1856Z — edge-dev — mimo — mimo-client-integration

owner: mimo/client-integration
agent: mimo (MiMo Desktop / MiMoCode)
machine: edge-dev
worktree: `C:\repos\ai-devops-wt-mimo`
branch: `sandbox-mimo-client-integration`

## Plan

Implementation plan (read its STATUS table first — do not re-derive or re-plan):

- [`../../plan_mimo-windows-support.md`](../../plan_mimo-windows-support.md)

## What this session is for

Bring **Xiaomi MiMo Desktop / MiMoCode** to the same managed ai-devops client parity Claude, Codex, and ZCode already have: presence checks, governed `ai-mimo` wrapper, managed skills under `~/.config/mimocode/skills/`, seeded global instructions, MCP wiring via `mcp-launch.cmd`, transcript-backup skill, doctor, BlockerWatch keys, docs, offline tests, PR merge.

## Current state

- Plan written; STATUS rows start ⬜ (or N/A for hooks/reviewer).
- Worktree created from `origin/main` (`c8d4d8f2`).
- Live facts already recorded in plan §5–6 (Desktop present; standalone `mimo` CLI **absent** on edge-dev; `mimocode.jsonc` has hand-wired `1password`; `mimocode.db` present).

## Do not

- Do not edit the shared canonical checkout `C:\repos\ai-devops` for this work.
- Do not build a MiMo reviewer (plan D1).
- Do not write MiMo skills into `~/.agents/skills`.
- Do not register a completion-check hook (D6 N/A).
- Do not pass `--yolo` / `--dangerously-skip-permissions` from caller input.
- Do not start the Desktop GUI as a headless fallback.

## Next actions

1. Execute Phase A (Steps 1–3) in this worktree.
2. Continue Phase B–D per plan §9.
3. Update plan STATUS with artifact paths as each step lands.
4. PR from `sandbox-mimo-client-integration`, merge queue, confirm `origin/main`.
5. Live install proof on edge-dev **or** exactly one leftover-proof issue before the session ends.
