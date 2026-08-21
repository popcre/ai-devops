# IMPLEMENTATION PLAN — Kimi reviewer completion repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Add normalized upstream lock | ⬜ open | clone fixtures in `tests/test-ai-kimi.sh` |
| 2 | Improve missing-job errors | ⬜ open | status/logs fixtures |
| 3 | Wait for and re-prove live completion | ⬜ blocked | issue #46 live artifact |
| 4 | Run installed canary matrix | ⬜ blocked on Step 3 | `tests/verification/kimi/<UTC>/` |
| 5 | Land/unquarantine/close #46 | ⬜ open | remote SHA and issue close |

Fresh session starts at Step 1. The merged artifact-recovery work remains governed
by `plan_kimi-review-failure-recovery.md`; do not redo its completed Steps 1–7.

## 1. The ultimate goal — what we are trying to achieve

Kimi must run at most one paid review per upstream repository and return either
one proven durable completion or an unmistakable failure; only then may it leave
quarantine. If any step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-kimi` runs Kimi K3 reviews/implementation in private workspaces with a
read-only review profile and durable jobs. It is part of public `ai-devops` on
`main`, used on Windows and Ubuntu; no service deployment exists.

## 3. What triggered this work

Issue #46 fixed artifact loss and partial-verdict handling, but repeated installed
live probes still return no required `session.resume_hint`. Audit finding 8 found
the same clone-based repository lock weakness as Grok; finding 26 found raw
missing-job errors.

## 4. Scope — in and out

In: upstream lock identity, friendly job lookup, free live retry, bounded canary
matrix, tests/docs/install/quarantine/#46. Out: redoing merged recovery code,
purchasing allowance without approval, relaxing review profile, quoting provider
metrics unavailable from Kimi, or changing implementation network policy.

## 5. Current state of the code

Completed recovery is on main per `plan_kimi-review-failure-recovery.md:11-18`.
Repo ID/lock are `bin/ai-kimi:349-378,1005-1014`; job lookup and raw status/logs
are `:1059-1070,1111-1112`. Offline evidence was 173/173 at merge. Kimi remains
quarantined and issue #46 open.

## 6. Key findings and root cause

Durability is repaired, availability is not proven. The repository lock uses
checkout path where cost serialization needs normalized upstream identity.
`job_for_name()` supplies a fallback path rather than a typed existence result.

## 7. Approaches considered and REJECTED

Auth success, assistant text, or exit zero cannot replace `session.resume_hint`.
Buying usage without Albert's approval is rejected. Banning clones is rejected.
Do not reopen or weaken merged recovery logic to make live checks pass.

## 8. Design decisions already made (2026-08-20/21)

LOCKED: quarantine until installed live matrix passes; incomplete means NO
VERDICT/nonzero; no paid purchase without approval; separate upstream cost lock
from session identity. OPEN: retry timing after free allowance refresh.

## 9. The plan — numbered, ordered steps

1. Add clone-equivalence/URL-normalization/unrelated-repo/stale-lock tests and a
   canonical upstream cost-lock identity without changing session retrieval.
   You'll know it worked when two clones serialize and moved-session tests pass.
2. Make `status`, `logs`, `result`, and `wait` share typed lookup and exact caller/
   repo matching. You'll know it worked when missing names print one actionable
   message and exit nonzero without raw `jq` output.
3. Run the free installed `AI_KIMI_CALLER=codex ai-kimi doctor --live`. If it
   lacks completion, record one dated #46 comment, keep quarantine, and stop.
   You'll know it worked only with the required terminal record.
4. On success, execute existing plan §9.8 complete/revise/waiter-death/private
   fallback/copy-deletion/resume/hostile-write canaries and save redacted proof.
   You'll know it worked when each run yields one complete or explicit incomplete
   artifact and sentinel stays unchanged.
5. Run full suites and exact-head review, install, commit/push, verify remote and
   installed hashes, update/close #46 and plans, then unquarantine. You'll know it
   worked when no Kimi handoff remains and every status source agrees.

## 10. Tests required

Extend `tests/test-ai-kimi.sh` with lock and missing-job cases; preserve all 173
existing cases and run Grok/Qwen/Gemini/shared helper suites named in the existing
plan. Live matrix is mandatory before unquarantine.

## 11. Constraints, standing rules, and gotchas in force

Read Kimi STEP-0 header and current failure-recovery plan first. Credentialed
calls only from full-access main task with caller set. Never use raw `kimi`,
broaden tools, quote unavailable usage figures, or purchase usage without approval.

## 12. Access and environment

Use `C:\repos\ai-devops`, Git Bash and private installed Kimi CLI state. `gh` is
authenticated. No 1Password read is needed for a normal free retry.

## 13. Definition of done + risks and open questions

Done: clone/job tests plus full suite pass; terminal live record and canary matrix
pass; exact-head review clears findings; Albert identity/scoped commit/main push/
remote-install hashes verified; #46 closed; quarantine removed; docs/plans/handoff
current. No deployment. Risk is provider allowance/contract; remain quarantined
and blocked rather than infer success. Rollback by commit and quarantine.

## Mandatory self-audit

1. Yes—Sections 3–10 distinguish completed work, new defect, blocker and gates.
2. Yes—Sections 6–8 preserve why auth/text/exit are insufficient and spending rule.
3. Yes—Section 1 makes one paid run plus proven completion the governing goal.
All checklist items pass.

