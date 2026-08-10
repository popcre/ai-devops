# Handoff: GLM amendments to persistent Kimi implementation plan

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public AI workflow toolkit. `bin/ai-kimi` is its
supported headless Kimi wrapper. The repo uses `main` and has no hosted service, database,
CI, or deployment.

## 2. What we set out to do, and why

GLM 5.2 reviewed the open persistent Kimi plan and returned `APPROVE WITH REQUIRED
CHANGES`. Albert asked to incorporate every improvement. The amended authoritative plan
is [`../plan_kimi-persistent-implementation-sessions.md`](../plan_kimi-persistent-implementation-sessions.md).

## 3. Current state

- No implementation has started. All STATUS rows remain open.
- The plan now contains GLM changes R1-R9.
- GLM re-reviewed the amended plan in the same session and returned `APPROVE`; every
  required and minor item passed, and it found no remaining blocking defect.
- The saved read-only GLM report is under ignored `.ai/reviews/` and is not committed.
- Current source behavior remains one-shot and safe.

## 4. Everything tried that did not work

The first plan passed its internal self-audit but GLM found real missing details: ignored
files vanished silently; conversation could advance beyond saved code; generation could
be misread as Kimi truth; lock order and owned storage were unspecified; legacy migration
was not actually possible; reconstruction and Windows long paths lacked exact checks;
and `ask` could silently become a write action.

## 5. Root causes and key findings

- Canonical patch state includes Git-visible source only, never ignored environment state.
- A failed post-provider save can leave Kimi memory ahead of canonical code, so resume
  must lock out until explicit context reset.
- Current legacy implementation JSON has neither base SHA nor linked patch, so it cannot
  be migrated safely.
- Exact binary diff re-hash and worktree-local long-path configuration are required.

## 6. Exact next steps

1. Read the amended plan in full and start at Phase 1. Gate: understand all R1-R9 rules.
2. Measure cross-directory resume, new-CWD visibility, failure resume, ignored state, and
   Windows binary/long-path round-trip before production changes.
3. Follow phases 2-5 and update STATUS/current state after every gate.
4. Delete this handoff only after all rows are proven, committed, and pushed.

## 7. Constraints and gotchas

- Do not weaken exact-ID, disposable worktree, review safety, incomplete recovery, or
  real-repo isolation.
- Do not guess legacy migration or conversation/code alignment.
- `ask` on an implementation must warn that it is a write run.
- Preserve unrelated untracked files and all other sessions' handoffs.

## 8. Access and environment

- `C:\repos\ai-devops`, `main`, Git Bash and PowerShell 7 on Windows `AL8960OFC`.
- Kimi 0.32.0 OAuth is per-user under `~/.kimi-code`; never expose it.
- No secret should be required. Other secrets stay in 1Password vault `vibe_coding`.

## 9. Open questions and risks

Only Phase 1 measurement questions remain open. If exact cross-directory context or
new-CWD visibility fails, stop the design. If patch round-trip is unreliable, revise the
plan and reconsider a private Git ref. Do not improvise either change.

## Mandatory self-audit

1. Yes. The linked amended plan gives a fresh session all files, decisions, steps, tests,
   and proof gates.
2. Yes. Sections 4-5 preserve every GLM objection and why it matters.
3. Yes. Sections 6-9 give exact next steps, constraints, access, and stop rules.

Self-audit passed on 2026-08-10.
