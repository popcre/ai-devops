---
issue: 335
status: OPEN
owner: codex/issue-335-closeout
---

# HANDOFF — Issue #335 Phase 4 continuation (2026-09-09T2352Z, edge-dev/Codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — Phase 4 can begin without an owner decision. The next session must not
re-ask settled decisions: all 17 canonical repositories are in scope; central
enforcement stays in `popcre/ai-devops`; consumer declarations may strengthen
but never weaken a gate; raw transcripts and licensed rows stay unread; Issue
#335 remains open until Phase 5 acceptance. If a genuinely new decision appears,
collect every decision in one message before asking Albert.

## 1. What this application is

`popcre/ai-devops` is POP Creations' shared engineering-governance toolkit. Issue
#335 makes task scope and protected actions checkable across its 17 repositories
so routine documentation work does not accidentally start costly or risky flows.

## 2. What we set out to do this session, and why

This session repaired the Issue #335 plan's retired-handoff link after it caused
a Linux verification failure elsewhere, then closed out so a fresh session can
continue the remaining rollout without rediscovery.

## 3. Current state — what is true now

The repair merged through PR #348 as `13b0ae2c027689313e14daa3076c0fa51450119e`.
At its exact head, all 299 tracked Markdown links passed. Subsequent main-line
work advanced Issue #335 through Phase 3: `plan_cross_repo_routing_and_gate_enforcement.md`
now names `HANDOFF.d/2026-09-09T1949Z-edge-dev-codex-issue-335-phase-four-rollout.md`
as the active handoff, marks Phases 0-3 DONE, and leaves Phase 4 OPEN. PR #343,
the earlier duplicate contract work, is CLOSED unmerged. No uncommitted work
belongs to this session.

## 4. Everything we tried that did NOT work

The plan initially pointed to the 2026-09-08 Phase 0 handoff after that file had
been deliberately retired. Restoring that old file would have created two
competing restart points, so the repair pointed to the successor. Later Phase 3
completion correctly replaced that successor with the Phase 4 handoff; do not
revert either progression. A local Codex review was started for an earlier
contract branch but produced no review record before its bounded run ended; that
branch was later superseded and closed.

## 5. Root causes and key findings

Handoff links are live routing dependencies, not historical prose: the missing
target caused the Linux Markdown-link check to fail after its suite had run.
The current source of truth is the plan STATUS table plus the newest named
handoff, not old branches or old local worktrees. PR #330 is a separate Qwen
workstream: its Linux and reviewer checks passed, while its full Windows job was
cancelled after 1 hour 41 minutes; it is not a blocker for Phase 4.

## 6. Exact next steps

1. Start from a fresh `origin/main` worktree, read the plan STATUS and the active
   Phase 4 handoff named in Section 3, then resolve Issue #335 and current
   repository/worktree ownership. You'll know this is correct when Phase 4 is
   the first OPEN plan row and no work from Phases 0-3 is repeated.
2. Execute Phase 4 in the order and with the per-repository proof gates recorded
   in that Phase 4 handoff. Keep every consumer declaration thin and preserve
   its stronger local rules. You'll know each rollout is ready only when its
   landed commit/PR, policy version, routing result, and verification result are
   recorded in the coverage evidence.
3. Do not begin Phase 5 until all 17 coverage rows are landed. You'll know the
   rollout is ready for installation only when the manifest has no missing or
   mixed coverage.

## 7. Constraints and gotchas in force

Use an isolated current-upstream worktree for every write. Never inspect raw
transcript archives or licensed rows. Do not mutate database, deployment,
infrastructure, or production state for this program. DesignFlow acceptance for
this issue is the live `sandbox-albert` capability, not a wait for `develop` or
Uma. Do not cancel, rerun, or diagnose PR #330's Windows job as part of #335.

## 8. Access and environment

This session used authenticated Git and GitHub CLI access on `edge-dev`; no
secrets were read or created. Bash tests on this Windows host use
`C:\Program Files\Git\bin\bash.exe` because WSL has no installed distribution.
Secrets, if a later installer task needs them, belong only in the `vibe_coding`
1Password vault.

## 9. Open questions and risks

Phase 4 has not started in this session. The active Phase 4 handoff may have a
live owner; inspect it and GitHub before creating a competing branch. The stale
shared checkout must not be fast-forwarded casually while its MCP launchers are
active; the supported-machine update belongs to Phase 5. This handoff's only
owner decision sweep found none beyond the settled decisions in Section 0.

## Self-audit

Yes. Sections 1-3 give a newcomer the purpose and verified current state;
Section 4 preserves failed paths; Sections 5-8 provide the evidence, constraints,
environment, and executable gates; Section 9 names residual risks. The Section
0 sweep found no new Albert decision, and all settled decisions are listed there.
