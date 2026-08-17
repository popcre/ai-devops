---
issue: 34
status: OPEN
owner: codex/reviewer-system-repair-analysis
---

# HANDOFF — delegated reviewer system repair (2026-08-17 21:15Z, al8960ofc/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Albert requested the detailed report and fixes. Already settled: Qwen stays
out of new rotation; #1113 is application-owned offline Item Master work; speed
must improve without weakening exact-head or fail-closed safeguards.

## 1. What this application is

`u2giants/ai-devops` installs and operates the Grok, GLM, Kimi, Qwen, Codex, and
related AI coding wrappers. Relevant commands are `bin/ai-grok-review`,
`bin/ai-glm`, `bin/ai-kimi`, and `bin/ai-review-sandbox`.

## 2. What we set out to do and why

Albert asked why small reviews took 15 minutes or longer during a 24-hour
shared-db session, why throughput was poor, how to prevent #1113 misrouting, and
for a durable repair proposal. The canonical result is
[`fix_reviewer_system.md`](../fix_reviewer_system.md).

## 3. Current state

- Analysis is complete in `fix_reviewer_system.md`.
- GitHub issue [#34](https://github.com/u2giants/ai-devops/issues/34) tracks code
  implementation.
- No wrapper behavior, machine configuration, credentials, or installed binaries
  changed.
- Root `HANDOFF.md` remains the required static pointer. This file is the active
  handoff link requested by Albert.
- Pre-existing untracked `.ai/` and
  `docs/claude-remote-control-hardening-v2.md` were not touched.

## 4. What failed

Routine reviews used 12/20 turns and 900-second waits. Several Grok runs consumed
2.5–3.0 million tokens and returned no verdict. Kimi reached its wait boundary
before reporting exhausted allowance. GLM failed on linked-worktree boundaries,
missing local refs, empty turns, and web-search attempts. Provider rotation then
repeated repository discovery. Reviews launched before main stabilized became
stale. Manually transcribed full SHAs also invalidated evidence.

Do not fix these by broadening filesystem/shell/web permissions, accepting
partial output, or weakening exact-head binding.

## 5. Root causes

- Grok defaults: 20 turns/900 seconds; Kimi: 900 seconds; GLM: 1,800 seconds.
- Reviewers receive repository access instead of a sealed exact-diff packet.
- Verdict is requested last, so turn exhaustion produces no decision.
- Provider health/quota is discovered after assignment.
- Final reviews start before exact-head stability.
- #1113 inherited #1097's repo instead of being reclassified.

Full evidence and remediation are in the canonical report.

## 6. Exact next steps

1. Implement hashed sealed review packets; verify every result records the hash.
2. Derive SHAs in the wrapper; verify incorrect caller SHAs cannot enter evidence.
3. Add provider preflight/quarantine; verify exhausted Kimi is skipped in seconds.
4. Add 6-turn/5-minute ordinary reviews and early provisional verdicts; verify a
   two-file fixture finishes inside the budget.
5. Add failure-specific rotation; verify turn exhaustion shrinks scope instead of
   doubling turns.
6. Add performance metrics and run the 30-review success trial.
7. Add shared-db scope enforcement and the #1097→#1113 regression; verify
   non-database successors consume no shared-db agent or lane.

## 7. Constraints and gotchas

Preserve terminal-result validation, read-only tools, exact-head binding,
per-repository locks, and fail-closed behavior. Read wrapper headers and
`docs/glm-opencode.md` before code changes. Qwen remains excluded. Do not edit
root `HANDOFF.md` or unrelated untracked files.

## 8. Access and environment

Repo: `C:\repos\ai-devops`, branch `main`. GitHub CLI is authenticated as
`u2giants`. Before commits, verify author is
`Albert Hazan <u2giants@users.noreply.github.com>`. No new secrets are needed.

## 9. Open questions and risks

Final defaults must be validated by the 30-review trial. Packets must include
relevant dependencies without reopening repository-wide wandering. Short
deadlines must produce explicit no-verdict, never accidental approval. Provider
metrics must allow unavailable token/cost data. #1113's private artifact must be
handed only to the private DesignFlow Item Master workflow.

## Mandatory self-audit

1. Yes: §§1–3 define the repo, goal, deliverable, issue, and unchanged runtime;
   §6 gives executable next steps.
2. Yes: §§4–5 preserve measured failures and root causes; the linked report
   contains full evidence.
3. Yes: §§6–9 include verification gates, constraints, environment, and risks.
4. Yes: the §0 sweep found no unresolved owner decision; settled rulings are
   listed so they are not re-asked.
