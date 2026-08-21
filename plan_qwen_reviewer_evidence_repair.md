# IMPLEMENTATION PLAN — Qwen reviewer evidence repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Cross-version continuation fixtures | ⬜ open | `tests/test-ai-qwen.sh` |
| 2 | Bind session to exact evidence | ⬜ open | metadata/packet fixtures |
| 3 | Explicit refresh/restart behavior | ⬜ open | stale-tree fixtures |
| 4 | Shared governance integration | ⬜ open | preflight/scoreboard fixtures |
| 5 | Live qualification and landing | ⬜ open | verification bundle/remote SHA |

Fresh session starts at Step 1.

## 1. The ultimate goal — what we are trying to achieve

A Qwen conversation must never silently carry reasoning from one code version
into another; every verdict must name and prove its exact evidence. If any step
conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-qwen` runs persistent Qwen Code review and implementation conversations
in private review copies for the public `ai-devops` toolkit on `main`. Review
mode is read-only because of wrapper controls and snapshot boundaries.

## 3. What triggered this work

Audit finding 16: session metadata at `bin/ai-qwen:894-899` lacks base/head/tree/
packet identity; continuation at `:930-949` refreshes the stable snapshot to
current code and resumes old reasoning. Shared health/evidence tools omit Qwen.

## 4. Scope — in and out

In: review-session evidence identity, stale detection, explicit refresh/restart,
packet/preflight/scoreboard integration, tests/docs/install/live qualification.
Out: implementation-session behavior except shared regressions, model/profile
changes, broad permissions, other providers.

## 5. Current state of the code

`start_session()` writes conversation/workspace metadata but not exact review
identity. `cmd_ask()` obtains the current boundary, which can refresh a linked
worktree snapshot. Existing Qwen suite passed 23 cases during the Kimi landing;
none covers code changing between new and ask. No fix is committed.

## 6. Key findings and root cause

Stable conversation name was mistaken for stable evidence. Snapshot refresh is
useful for implementation but unsafe for review unless the caller explicitly
starts a new evidence generation and the model is told exactly what changed.

## 7. Approaches considered and REJECTED

Silently refreshing and continuing is rejected. Comparing HEAD alone is rejected
because dirty/untracked changes matter. Keeping old snapshots forever without
stale warning is rejected. Automatically summarizing old reasoning into a new
review is rejected unless clearly non-approving and explicitly requested.

## 8. Design decisions already made (2026-08-21)

LOCKED: review metadata binds base, head, complete tree/packet hash and generation;
changed evidence blocks ordinary `ask`; missing identity fails closed. OPEN:
offer an explicit `refresh` command that starts a new generation in the same
provider conversation, or require a new named review—the safer default is new.

## 9. The plan — numbered, ordered steps

1. Extend `tests/test-ai-qwen.sh` with committed, dirty, untracked, linked-
   worktree and packet changes between `new`/`ask`, plus unchanged continuation.
   You'll know it worked when baseline silently crosses versions only in hostile
   fixtures and sentinels stay safe.
2. At new, build/verify packet and store base/head/tree/packet/generation in
   atomic metadata; at ask, rederive and compare before provider contact. You'll
   know it worked when any drift fails with old/new identity and no paid call.
3. Add explicit recovery: recommend new session by default; if `refresh` exists,
   create a new generation, preserve old evidence, and force a clear delta prompt.
   You'll know it worked when no verdict can be attributed across generations.
4. Register Qwen in shared preflight/scoreboard/incident contract and update the
   shared skill/docs. You'll know it worked when valid/stale/unknown fixtures are
   represented truthfully.
5. Run offline/live hostile canaries and exact-head review, install, verify
   hashes, commit/push main, update plans/handoff. You'll know it worked when one
   unchanged resume succeeds and every changed resume stops before billing.

## 10. Tests required

All Step-1 cases in `tests/test-ai-qwen.sh`; packet/sandbox/preflight/scoreboard/
incident suites; Kimi implementation regressions where code is shared; one
bounded live unchanged resume and one pre-provider stale refusal.

## 11. Constraints, standing rules, and gotchas in force

Use `ai-qwen`, never raw Qwen for governed review. Preserve read-only profile,
private snapshots and exact caller identity. Do not conflate implementation
continuity with review evidence. Main-only; no broad staging/force-push.

## 12. Access and environment

Use `C:\repos\ai-devops`, Git Bash, private installed Qwen login state and `gh`.
Offline stubs should prove most behavior. No secret values or production access.

## 13. Definition of done + risks and open questions

Done: all version-drift cases and related suites pass; live bounded proof and
exact-head independent review clear; Albert identity/scoped commit/main push/
remote/install hashes verified; docs/plan/handoff current. No deployment. Risk:
legacy sessions lack identity—refuse review continuation with clear restart
guidance; never infer. Rollback by commit/quarantine.

## Mandatory self-audit

1. Yes—Sections 3–10 define the exact version-crossing scenario and build gates.
2. Yes—Sections 6–8 preserve why HEAD-only/silent refresh/legacy inference fail.
3. Yes—Section 1 makes exact evidence continuity the overriding decision rule.
All checklist items pass.

