---
issue: 632
status: OPEN
owner: codex/blocker-watch-reliability-plan-20260920
---

# HANDOFF — BlockerWatch reliability plan (2026-09-20T1847Z, 916/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Start from the plan's locked decisions. If new evidence conflicts with the
business goal, record it on #632 rather than asking Albert for a technical choice.

Already settled — do not re-ask: the name is BlockerWatch (2026-09-18); automatic
parked-work continuation must be preserved; GitHub issues/dependency links remain
the visible durable record (2026-09-20).

## 1. What this application is

`popcre/ai-devops` holds Albert's AI-machine setup and shared agent rules.
BlockerWatch (`bin/ai-blocker-watch`) is a scheduled Bash tool for Claude, Codex,
and ZCode. It records work waiting on GitHub and resumes or freshly restarts it
when the blocker resolves. Its config is `config/blocker-watch.json`; its main
offline suite is `tests/test-ai-blocker-watch.sh`.

## 2. What we set out to do this session, and why

Albert asked for a comprehensive repair plan after the HTS classifier dependency
on `popcre/shared-db#2995` was found unregistered. The result is
[`plan_blockerwatch-reliability-repair.md`](../plan_blockerwatch-reliability-repair.md).

## 3. Current state — what is true right now

PR #653 is on main at `eb92356e2ebbe2b05d353cbd9e9b26e1678ceb9e`.
The existing offline suite passes `94 passed, 0 failed`, but does not cover the
live failures. #632 owns this plan; #617 and #655 remain open predecessor proof
issues. No repair implementation, migration, installation, or live proof has
started. The plan was written on branch
`codex/blocker-watch-reliability-plan-20260920` from current upstream.

## 4. Everything we tried that did NOT work

- Manual-only registration missed historical/local-plan work such as #2995.
- Global transcript matching resumed Claude from the wrong project folder and
  repeated `No conversation found`.
- #655 used an isolated state home invisible to the production schedule, then
  failed with OAuth 401.
- Generic retries repeated deterministic failures.
- #632's transferred dependency is refused forever; an interrupted ZCode
  `waking` record repeated 45-minute timeouts while the tick lock could be stolen.
- Installed globals retained old `--note` instructions after source changed.

## 5. Root causes and key findings

Registration is not enforced/reconciled (`bin/ai-blocker-watch:147-246`); IDs
collide and are not deduplicated (`:237`); list hides repair information
(`:249-253`); search/comments are incompletely paginated (`:286-374`); wake uses
the wrong identity/error model (`:376-508`); link maintenance is same-repo,
add-only, and cannot quarantine permanent defects (`:698-830`); lock ownership is
age-only (`:841-850`); tick revisits only `waiting` and can starve local wakes
(`:869-881`); scheduling is installed but not live-proven (`:885-921`). Static
central ownership lacks heartbeat/failover, and public diagnostics expose too much.

## 6. Exact next steps

1. Start at plan STATUS step 0 in a new current-upstream worktree and declare the
   task gate. Success is a redacted complete baseline inventory.
2. Execute phases 1–5 one natural session at a time, updating STATUS after every
   landed step. Each phase succeeds only at its named test/gate.
3. Run exact-head review, CI, backed-up staged rollout, and separate live proofs
   in phase 6. Each unproven outcome gets one session and one issue.
4. Complete phase 7 reconciliation. Success means GitHub, main, installed clients,
   plans/index/router, and handoffs agree and #632 can close.

## 7. Constraints and gotchas in force

Use a dedicated worktree, task gates, branch/PR, `bin/ai-gh`, signed GitHub posts,
verified committer identity, and owned staging. Do not mutate shared-db: #2995 is
orchestrator work; the application return issue is non-orchestrator work. Do not
publish raw transcripts, wait JSON, local paths, session IDs, or secrets. Explicit
versioned metadata—not prose—is authority. Remove only ledger-owned dependencies.
Do not edit another session's handoff; retire only under the successor rule.

## 8. Access and environment

Target protected `main` through PR; use authenticated `bin/ai-gh`. Current host is
`916-alien`; load only the relevant machine-atlas section during rollout. Windows
uses `\ai-devops\blocker-watch`; Unix uses user cron. Credentials remain local;
use the approved 1Password `vibe_coding` flow if needed, never values in output.

## 9. Open questions and risks

Three bounded engineering choices remain: repeatable JSON migration, the exact
GitHub-visible renewable lease, and log rotation limits. The plan supplies test
criteria. Risks are duplicate execution, migration loss, wrong edge removal,
duplicate posts, privacy leaks, and stranded legacy records. Back up state first;
rollback preserves GitHub evidence and leaves degradation visible.

## Handoff self-audit

All required answers are **yes**: §§1–3 define the system, goal, owners, and exact
state; §§4–5 preserve failures and root causes; §6 gives verified next steps;
§§7–9 cover constraints, access, risks, and decisions. The §0 sweep found no owner
decision in §§1–9. A new developer can continue as effectively as this session,
every relevant detail category is present through the linked comprehensive plan,
and Albert can read §0 alone without missing an ask. No gap remained.
