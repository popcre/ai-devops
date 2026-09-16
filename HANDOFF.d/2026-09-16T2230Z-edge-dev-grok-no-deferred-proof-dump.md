---
issue: 511
status: OPEN
owner: grok/511-no-deferred-proof-dump
---

# Handoff — do not defer live proof as a later dump

Paired plan: [`../plan_live-proof-session-sizing.md`](../plan_live-proof-session-sizing.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

**Already settled — do NOT re-ask**

- 2026-09-16: Albert wants a **global** source fix, not a cleanup of this week’s leftover-proof tickets.
- 2026-09-16: refuse-bundle last-line defense already landed as `837fe41d`. Do not revert it.
- 2026-09-16: do not weaken merge-safety; do not drop live proof.

## 1. What this application is

`popcre/ai-devops` owns the always-loaded Claude and Codex rules.

## 2. What we set out to do this session, and why

Albert rejected the first plan because it was about current tickets. The source is: leftover live proof is saved for later, then dumped on a later chat. Last-line defense (refuse a bundle) is already on main. This session adds the dump-prevention rule.

## 3. Current state — what is true right now

- #511 was closed by the refuse-bundle landing; it should be reopened until dump-prevention is on `origin/main`.
- Branch `grok/511-no-deferred-proof-dump` from `origin/main` `a4d83944` has the source-rule edits.
- PR #516 is stale/dirty and should be closed as superseded.
- Not yet merged or installed.

## 4. Everything we tried that did NOT work

- A plan whose steps split this week’s leftover-proof tickets. Albert: not the source.
- Implementing dump-prevention on a branch that was behind main (PR #516). Another session landed refuse-bundle first; rebase conflicted. Abandoned in favor of this clean branch.

## 5. Root causes and key findings

Creating the pile is the source. Refusing the pile later is not enough.

## 6. Exact next steps

1. Reopen #511. You’ll know it worked when the issue is OPEN.
2. Close PR #516 as superseded. You’ll know it worked when its state is CLOSED.
3. Commit, push, PR this branch. You’ll know it worked when the PR file list includes both globals and `Never save several unproven steps`.
4. `bin/ai-pr-wait`, merge. You’ll know it worked when `git grep -n "Never save several unproven steps" origin/main -- templates/system/` hits.
5. `bin/ai-adopt-globals`. You’ll know it worked when installed `CLAUDE.md` and `AGENTS.md` contain the phrase.
6. Comment SHA on #511, close #511, delete this handoff.

## 7. Constraints and gotchas

- Include the context-audit fixture phrase or Windows shard 3 fails at `test-context-audit.ps1:208`.
- Do not wrap the required phrase.
- Not documentation-only.

## 8. Access and environment

`popcre/ai-devops` as `u2giants`. No secrets.

## 9. Open questions and risks

None that block. No owner question.

---

## Self-audit

1. Newcomer can continue: yes — §6.
2. As effective as now: yes — §4 records the rejected incident plan and the dirty PR #516.
3. Execution detail: yes — fixture trap named.
4. §0 sweep: none new.
