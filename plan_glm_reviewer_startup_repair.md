# IMPLEMENTATION PLAN — GLM reviewer startup repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Start-vs-health failure fixtures | ✅ complete | `tests/test-ai-glm.sh` 244/244 plus Windows structural tests, including already-healthy no-relaunch behavior, one shared deadline for the preliminary probe and startup, and streamed local-service authentication that never exposes the password in process arguments |
| 2 | Make start wait for readiness | ✅ complete | bounded Windows/Linux health fixtures |
| 3 | Align diagnostics/docs | ✅ complete | doctor/start artifacts and `docs/glm-opencode.md` |
| 4 | Live Windows/Ubuntu qualification | 🟨 pending installed revision | real open-issue review evidence |
| 5 | Land and install | 🟨 pending exact-head approval | remote SHA/installed hashes |

Current work starts at Step 4. Preserve completed reliability work in
`plan_glm-service-reliability.md` and all 33 hard-won constraints in
`docs/glm-opencode.md` §5.

## 1. The ultimate goal — what we are trying to achieve

When GLM says its local service started, the next review must be able to use it;
otherwise start must fail clearly with recovery guidance. If any step conflicts
with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-glm` drives a persistent local OpenCode GLM service and named read-only
review sessions for `u2giants/ai-devops` on Windows and Ubuntu. Windows uses Task
Scheduler; Ubuntu uses its installed service setup. Provider credentials are
injected privately through governed configuration.

## 3. What triggered this work

Audit finding 20 and incident evidence: `ai-glm server start` reported success,
then health remained unreachable for roughly 20 seconds. Windows start at
`bin/ai-glm:1551` and Linux start at `:1582` do not wait; restart at `:1569-1574`
already demonstrates the required bounded health behavior.

## 4. Scope — in and out

In: `server start` readiness, timeout/failure diagnostics, Windows/Ubuntu tests,
docs/install/live qualification. Out: session/review lifecycle, provider model,
permissions, service supervision redesign, secret launcher, other reviewers.

## 5. Current state of the code

The 2026-08-09 reliability plan is complete: supervision/retry/restart/doctor
were proven. Only direct `start` returns before readiness. `tests/test-ai-glm.sh`
and `tests/test-windows-scripts.sh` protect many measured constraints; no test
requires start to be healthy before success. No fix is committed.

## 6. Key findings and root cause

Start and restart use inconsistent success definitions. Scheduling/spawning a
service is not readiness. The existing `server_up()` and bounded restart loop are
the narrow proven mechanism; duplication risks Windows/Linux drift.

## 7. Approaches considered and REJECTED

Fixed sleep is rejected because startup time varies. Reporting “started” then
asking callers to retry is rejected as a silent operational failure. Replacing
the service supervisor or changing task retry semantics is rejected because the
completed plan measured those constraints. Raising timeouts unboundedly is rejected.

## 8. Design decisions already made (2026-08-09/21)

LOCKED: preserve supervision, exact service identity, retry semantics, permission
handling and all `docs/glm-opencode.md` §5 constraints; readiness is HTTP health;
bounded wait with truthful nonzero failure. OPEN: extract one shared helper or
reuse restart loop inline, choosing the least duplication without behavior drift.

## 9. The plan — numbered, ordered steps

1. Read the 33 constraints and add Windows/Linux stub tests for delayed healthy,
   never healthy, task/service launch failure, already healthy, and diagnostic
   output. You'll know it worked when current start fails the delayed-readiness
   expectation without touching live service.
2. Refactor a bounded `wait_for_server_health()` used by start and restart; emit
   success only after `server_up`, otherwise nonzero with task/service state and
   exact next command. You'll know it worked when delayed health passes and never-
   healthy fails inside the documented bound.
3. Update `docs/glm-opencode.md`, setup docs, skill and doctor/start help so all
   define start success identically. You'll know it worked when no doc tells
   automation to trust spawn alone.
4. Run controlled live stop/start on Windows and Ubuntu, proving one listener,
   bounded recovery, immediate next named review/resume, and no unrelated process
   termination. Save redacted proof. You'll know it worked when review succeeds
   immediately after start returns.
5. Run all GLM/Windows/shared suites, exact-head review, install, commit/push,
   prove remote/install hashes, update plan/handoff. You'll know it worked when
   both installed systems meet the same readiness contract.

## 10. Tests required

Extend `tests/test-ai-glm.sh` and `tests/test-windows-scripts.sh` with all Step-1
cases; preserve every existing constraint test and run shared packet/sandbox/
preflight/scoreboard suites. Live test must verify exact-session continuation,
not merely health endpoint response.

## 11. Constraints, standing rules, and gotchas in force

Read `docs/glm-opencode.md` §5 first; do not simplify lifecycle, completion,
remote-less clone, ASCII PowerShell, tools maps, permission handling, or linked-
worktree boundary. Serialize 1Password reads. Main-only; no force-push.

## 12. Access and environment

Windows checkout `C:\repos\ai-devops`; Ubuntu service host per machine atlas.
`gh` authenticated. GLM key stays in 1Password vault `vibe_coding`, item
`GLM z.ai API`, injected by existing launcher; never read/print its value in tests.

## 13. Definition of done + risks and open questions

Done: offline/live Windows+Ubuntu readiness and immediate-review gates pass;
exact-head review clears findings; Albert identity/scoped commit/main push/remote-
install hashes verified; docs/plan/handoff current. No deployment. Risk: service
may be slow under load; timeout remains bounded/configured and failure explicit.
Rollback by commit, preserving prior supervisor.

## Mandatory self-audit

1. Yes—Sections 3–10 identify the exact inconsistency and executable gates.
2. Yes—Sections 6–8 preserve completed reliability constraints and rejected redesigns.
3. Yes—Section 1 makes “usable when start returns” the governing outcome.
All checklist items pass.
