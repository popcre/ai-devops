# IMPLEMENTATION PLAN — Codex reviewer trust repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Baseline failure fixtures | ✅ complete | `tests/test-ai-codex-review.sh` (22 cases) |
| 2 | Complete change capture | ✅ complete | text/binary untracked files are present in the digest-bound private snapshot |
| 3 | Fail-closed completion | ✅ complete | provider, empty, missing-verdict, snapshot-write, and stale-source fixtures |
| 4 | Collision-proof artifacts and shared governance | ✅ complete | concurrent atomic reports plus preflight/lifecycle/scoreboard evidence |
| 5 | Land and install | 🟨 integrated locally | focused suites pass; exact-head review, push, and installation remain |

Fresh session starts at Step 5.

## 1. The ultimate goal — what we are trying to achieve

Codex review may approve a change only after it actually reviewed every intended
file, produced a usable verdict, and saved a unique durable report. If any step
below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-codex-review` sends a text diff to a sandboxed Codex command and writes
reports under `.ai/reviews/`. It is part of the public `u2giants/ai-devops` Bash
toolkit on `main`; there is no service or deployment.

## 3. What triggered this work

Audit findings 12, 13, and 23 in `bugs.md`: command failure exits successfully,
new untracked files are omitted, and same-second reviews can collide.

## 4. Scope — in and out

In: `bin/ai-codex-review`, a dedicated test file, shared preflight/scoreboard
registration, docs and installed launcher. Out: Codex CLI internals, model
selection, provider login, and other wrappers.

## 5. Current state of the code

The wrapper now creates a complete disposable snapshot, seals a source-bound
packet, enforces Codex's read-only sandbox and allowed reasoning, rejects any
snapshot/source mutation, requires an exact verdict, publishes a unique atomic
report, and completes provider-neutral lifecycle and scoreboard accounting.
The dedicated 22-case hostile suite is the current evidence.

## 6. Key findings and root cause

The wrapper treats “a command was attempted” as completion and assumes tracked
diffs equal the full requested change. Output identity is time-based rather than
run-based. Those assumptions are false under new files, provider failure, and
concurrency.

## 7. Approaches considered and REJECTED

Warnings with exit zero are rejected because automation reads exit status. `git
add` before review is rejected because review must not mutate user work. A
longer timestamp alone is rejected because concurrency can still collide.

## 8. Design decisions already made (2026-08-21)

LOCKED: no mutation of the reviewed repo; nonzero on provider/report/verdict
failure; include untracked content without staging; unique run identity. OPEN:
reuse `ai-review-packet` or retain text transport, provided exact scope and
integrity are proven.

## 9. The plan — numbered, ordered steps

1. Create `tests/test-ai-codex-review.sh` with stubbed success, provider failure,
   missing report, missing verdict, untracked text/binary files, and concurrent
   same-second runs. You'll know it worked when unsafe baseline cases fail.
2. Replace `gather_diff()` with complete, bounded capture of committed,
   uncommitted, and untracked changes; make omissions explicit and fatal. You'll
   know it worked when new text and binary fixtures appear in exact review input.
3. Require provider exit success, nonempty artifact, and fixed `## Verdict`
   vocabulary; propagate failure nonzero. You'll know it worked when no stubbed
   failure can print or return approval.
4. Use a collision-proof run ID and atomic report write; integrate preflight and
   scoreboard using the shared plan's contract. You'll know it worked when two
   concurrent runs create two complete reports and two truthful ledger rows.
5. Update docs/skills/router, run all Codex/shared tests, independently review
   exact head, install, commit, push, and verify hashes. You'll know it worked
   when GitHub and installed source match and the unsafe fixtures stay green.

## 10. Tests required

The new suite must name every case in Step 1. Also run
`tests/test-ai-review-packet.sh`, `test-ai-review-preflight.sh`,
`test-ai-review-scoreboard.sh`, and Windows installer tests.

## 11. Constraints, standing rules, and gotchas in force

Never stage user files to create a diff. Never expose secrets from untracked
files in chat/logs. Preserve text-based handoff unless packet adoption is proven
compatible. Work main-only; no broad staging/force-push.

## 12. Access and environment

Use `C:\repos\ai-devops`, Git Bash, stubbed `codex` for offline tests, and the
authenticated installed Codex CLI only for one bounded final canary. No secret
values or production access are needed.

## 13. Definition of done + risks and open questions

Done: exact cases pass, full related suites pass, exact-head review approves,
commit identity is Albert's, owned files are committed/pushed to `main`, remote
SHA and installed hash match, docs/plan/handoff are current. No deployment. Risk:
large untracked binaries; fail loudly or represent by hash/path rather than
silently dropping. Rollback is the landed commit.

## Mandatory self-audit

1. Yes—Sections 3–10 give exact defects, files, cases, and gates.
2. Yes—Sections 6–8 preserve causes, rejected shortcuts, and locked decisions.
3. Yes—Section 1 makes actual complete review the deciding goal. Checklist passes.

