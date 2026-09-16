---
issue: 511
status: OPEN
owner: grok/511-global-session-sizing
---

# Handoff — never dump leftover live proofs on a later chat

Paired plan: [`../plan_live-proof-session-sizing.md`](../plan_live-proof-session-sizing.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

**Already settled — do NOT re-ask**

- 2026-09-16: Albert wanted a **global** prevention, not a cleanup of this week’s leftover-proof tickets.
- 2026-09-16: do not weaken merge-safety; do not drop live proof.
- 2026-09-16: production approvals go to an independent reviewer, not Albert.
- 2026-09-16: proofs never go to the shared-db orchestrator.

## 1. What this application is

`popcre/ai-devops` owns the always-loaded Claude and Codex rules. Those rules apply to every future session on every machine that installs them.

## 2. What we set out to do this session, and why

Albert rejected the first plan because it was about this week’s tickets. He wants the source fixed so future sessions cannot be handed a pile of leftover live proofs.

## 3. Current state — what is true right now

- Issue #511 OPEN.
- Plan rewritten as standing behavior (not incident cleanup).
- Both globals, phrase test, parity rules, plan-writer standard, implementation-plan-writer skill, and handover skill are edited on branch `grok/511-global-session-sizing`. Phrase test PASSed locally.
- Not yet pushed, merged, or installed.
- Worktree: `C:\repos\ai-devops-worktrees\live-proof-session-sizing`.

## 4. Everything we tried that did NOT work

- A plan whose steps split or babysit this week’s leftover-proof tickets. Albert: that is not the source. Future programmes would still dump a pile.

## 5. Root causes and key findings

Source: leftover live proof is deferred, then bundled onto a later chat. Last-line defense (refuse a bundle) is not enough. The session that lands the code must file exactly one leftover-proof issue for that step, or prove it live, before it ends.

## 6. Exact next steps

1. Commit, push, PR (not documentation-only). You’ll know it worked when the PR file list includes both globals, the phrase test, `context-audit.py`, and the two skills.
2. `bin/ai-pr-wait`, merge through the queue. You’ll know it worked when `origin/main` contains `Never save several unproven steps`.
3. `bin/ai-adopt-globals` on this machine. You’ll know it worked when installed `CLAUDE.md` and `AGENTS.md` contain both phrases.
4. Comment the SHA on #511, close #511, delete this handoff. You’ll know it worked when this file is gone from `HANDOFF.d/` on `origin/main`.

## 7. Constraints and gotchas in force

- Do not wrap the required phrases.
- Do not `--admin` skip checks (globals + test + Python + skills).
- Do not touch current leftover-proof tickets as part of #511.
- Stage only owned files.

## 8. Access and environment

- `popcre/ai-devops` as `u2giants`. No secrets. Git Bash for the phrase test.

## 9. Open questions and risks

- Global byte budget may warn; do not delete other safety rules to fit.
- No owner question is open.

---

## Self-audit

1. Newcomer can continue: yes — §6 is the remaining ship/install/close list; the plan has the exact sentences.
2. As effective as now: yes — §4 records Albert’s rejection of incident-specific cleanup; §5 is the source.
3. Execution detail: yes — merge class, install, phrases.
4. Owner decisions in §0: sweep of §1–§9 found none new. Albert’s global-vs-incident ruling is in already-settled.
