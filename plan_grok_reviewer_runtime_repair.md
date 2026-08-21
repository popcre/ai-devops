# IMPLEMENTATION PLAN — Grok reviewer runtime repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Baseline and upstream identity | ⬜ open | issue-56 verification folder |
| 2 | Cross-clone paid-turn lock/activity | ⬜ open | `tests/test-ai-grok-review.sh` |
| 3 | Truthful interruption/deletion | ⬜ open | signal/delete fixtures |
| 4 | Mid-turn progress | ⬜ open | slow-turn fixture |
| 5 | Exact incident correlation | ⬜ open | shared evidence plan/tests |
| 6 | Live qualification and landing | ⬜ open | remote SHA, issue #56 close |

Fresh session starts at Step 1. This is the provider-facing companion to the more
detailed existing `plan_grok-review-concurrency-cancellation-observability.md`;
that plan remains the authoritative engineering detail where it is stricter.

## 1. The ultimate goal — what we are trying to achieve

Only one paid Grok review may run per upstream repository, everyone must see its
real state, and local interruption must never be misreported as remote
cancellation. If any step conflicts with this goal, the goal wins — stop and
flag it.

## 2. What this application is

`bin/ai-grok-review` runs fixed-model, read-only Grok reviews through Grok Build
on Windows/Ubuntu for `u2giants/ai-devops`. It uses named sessions, private
snapshots, evidence packets, fixed permissions and bounded turns.

## 3. What triggered this work

Six concurrent shared-db reviews proved the paid lock was checkout-scoped. Audit
findings 7, 18 and 19 confirmed wrong identity, uncertain cancellation/deletion,
and no cross-clone activity/progress. Issue #56 is open and its nine-step plan is
unimplemented.

## 4. Scope — in and out

In: normalized upstream cost lock, path-bound session identity, active state,
signals/delete, progress, exact incident join, tests/docs/install/#56. Out:
broader permissions, arbitrary flags, more turns, model changes, implementation
mode, provider billing policy.

## 5. Current state of the code

Identity/locks are `bin/ai-grok-review:202-248,597-665`; wait is silent at
`:303-330`; list sees current checkout records at `:730-743`; delete ignores
remote uncertainty at `:762-767`. Current Grok suite passes 106 existing cases.
All steps in `plan_grok-review-concurrency-cancellation-observability.md` are open.

## 6. Key findings and root cause

Session identity and cost-lock identity were incorrectly combined. Sessions are
checkout/caller-bound; paid serialization must normalize GitHub HTTPS/SSH, case,
`.git`, and clone paths to one upstream identity. Local process death proves
nothing about provider cancellation.

## 7. Approaches considered and REJECTED

Banning clones is rejected because private snapshots prevent wrong-head review.
Using raw remote text is rejected because equivalent URLs differ. Releasing a
lock on local death and claiming cancellation is rejected. Streaming is rejected
unless installed-version evidence proves terminal JSON remains reliable; elapsed
heartbeat is the safe default. Never raise turns as recovery.

## 8. Design decisions already made (2026-08-20/21)

LOCKED: preserve every STEP-0 safety control, separate session and upstream-lock
identity, factual heartbeat, explicit remote-uncertain state, exact incident join.
OPEN: confirmed remote abort only if installed Grok exposes verifiable support.

## 9. The plan — numbered, ordered steps

1. Execute existing plan Step 1 and save baseline/dirty exclusions. You'll know
   it worked when the exact base and command output are durable.
2. Implement canonical upstream identity and shared active records while keeping
   session lookup path-bound. You'll know it worked when HTTPS/SSH/local clones
   serialize, unrelated repos do not, and a second clone lists the active run.
3. Record local-stop and provider-stop separately; block/delete or preserve
   uncertain work until reconciled. You'll know it worked when no signal/delete
   test claims remote cancellation without confirmation.
4. Emit bounded elapsed heartbeats without weakening terminal `stopReason`.
   You'll know it worked when a slow fixture shows progress before final JSON.
5. Implement exact incident correlation through the shared plan. You'll know it
   worked when unrelated newer evidence is excluded and absence is labelled.
6. Run all offline/live gates and exact-head independent review; install, commit,
   push, prove remote/install SHA, close #56 with artifacts, and retire superseded
   handoffs only after completion. You'll know it worked when one bounded live
   review is visible, terminal, and uniquely billed/recorded.

## 10. Tests required

All tests in existing issue-56 plan §10, plus shared incident tests. Preserve
the 106 current Grok tests, packet/sandbox/preflight/scoreboard suites, terminal
`stopReason`, permission, model, turn, and exact-head regressions.

## 11. Constraints, standing rules, and gotchas in force

Read the STEP-0 header first. Never broaden permissions, remove max turns, trust
exit status, add flag passthrough, restore worktree/auto permission, or publish
private state. Main-only; no force-push; paid qualification bounded.

## 12. Access and environment

Use `C:\repos\ai-devops`, Git Bash, authenticated Grok private CLI state, `gh`,
and temporary stubs for offline work. No secret value or production access.

## 13. Definition of done + risks and open questions

Done matches existing issue-56 plan §13: tests/live proof/exact-head review green,
scoped main commit pushed, remote/install hash matched, #56 closed, plans/docs/
handoff current. No deployment. Risk: malformed global lock can block work; fail
safe and provide explicit reconciliation. Rollback by commit without weakening
safety.

## Mandatory self-audit

1. Yes—Sections 3–10 plus the linked authoritative issue-56 plan fully specify execution.
2. Yes—Sections 6–8 retain identity split, failed approaches and locked controls.
3. Yes—Section 1 makes single, visible, truthful paid work the governing goal.
All checklist items pass.

