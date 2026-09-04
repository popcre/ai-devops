# IMPLEMENTATION PLAN — Gemini reviewer safety repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Reconcile contradictory plan/docs and quarantine | ✅ done 2026-08-21 | `AGENTS.md`, `plan_ai-gemini-wrapper.md`, `skills/shared/gemini-code-delegation/SKILL.md` |
| 2 | Hostile write and conversation fixtures | ✅ done 2026-08-21 | 48 tests cover dirty/ignored/outside/model-call writes, wrong conversation, model drift, gitlinks, atomic stale-lock reclamation, private-copy tampering, private failure evidence, and protected tracked files inside runtime directories |
| 3 | Durable locked lifecycle | ✅ done 2026-08-21 | `bin/ai-gemini`; locks precede snapshot/state creation; concurrent-new, interruption, follow-up/delete, and recovery cases pass |
| 4 | Exact completion and report contract | ✅ done 2026-08-21 | empty/wrong-model/unsafe-report/stale-head cases in `tests/test-ai-gemini.sh` |
| 5 | Cross-platform live qualification | ✅ done 2026-08-24 | Both platforms passed the governed `qualify-live` canary on 2026-08-24 after the owner authenticated Antigravity on each: Windows `qualification-20260824T141942Z-52931` and Ubuntu `qual-20260824T144252Z-3062625`, each proving exact model, exact resume, mutation-request/no-change, unchanged outside sentinel, and durable reports. The Ubuntu run also exposed and fixed a 64-character sandbox tag overflow caused by wider Linux PIDs. Deterministic hostile mutation detection is offline-proven; the live result does not claim the model attempted a denied tool call. Evidence: `tests/verification/reviewer-production-completion/2026-08-24-gemini-tag-limit.md`. |
| 6 | Governed qualification record and production activation | ✅ done 2026-09-04 | Issue #261 completed the current release at merge `ed2c6180`: 64 Bash and 18 PowerShell suites passed, exact-head review approved `9b26bc68`, Antigravity 1.1.26 was qualified for exact model `gemini-3.8-flash-high`, verified `main` was installed on EDGE-DEV, installed preflight reported `available`, and governed review `issue261-proof` returned `APPROVE` with source unchanged. The named ten-minute `resume-reviewer-3-8-safely` heartbeat was absent when the automation inventory was audited at closeout; the only two installed automations were unrelated shared-database monitors, so there was no Gemini heartbeat left to retire. Qwen remains separately fail-closed under issue #259 evidence. |

Gemini 3.8 production activation is complete on the qualified EDGE-DEV reviewer
host. Any other host remains unavailable until its own exact wrapper/runtime/model
qualification passes; never copy EDGE-DEV's qualification record between hosts.
This plan supersedes conflicting current-state
text in `plan_ai-gemini-wrapper.md`; retain that file as investigation history.
The write-once `2026-08-21T1233Z` Gemini handoff is a pre-integration snapshot;
its old checkout and "uncommitted" statements are historical. This STATUS table
is the current route without rewriting another session's handoff.

## 1. The ultimate goal — what we are trying to achieve

Gemini may be offered as a reviewer only when it is proven read-only, resumes the
exact conversation, cannot lose paid work, and saves a trustworthy report before
claiming success. If any step below conflicts with this goal, the goal wins —
stop and flag it.

## 2. What this application is

`bin/ai-gemini` drives Antigravity's `agy` CLI in a disposable repository copy
for the public `u2giants/ai-devops` toolkit on `main`, on Windows and Ubuntu. It
uses model `Gemini 3.8 Flash`, evidence packets, and named conversations.

## 3. What triggered this work

Audit findings 3–6 and 25 in `bugs.md`: status-only write detection misses
content changes; returned conversation ID is not matched; no in-progress state
or lock exists; report refusal returns success; governing docs contradict code.
Issue #38 opened this repair. Its implementation and production proof are now
complete; its administrative closure is paired with issue #261 closeout.

## 4. Scope — in and out

In: Gemini review lifecycle, containment proof, report durability, exact
conversation/model/verdict checks, locks/recovery, tests/docs/installation and
issue #38. Out: implementation mode, global Antigravity setting changes,
permission bypass flags, other providers, databases/production.

## 5. Current state of the code

As of 2026-09-04, `bin/ai-gemini` records state before provider contact, uses
repository/session locks, inventories the disposable copy and protected source
before and after both review and model-verification calls, freezes the complete
source-file state across turns, matches resumed conversation IDs, and treats
report failure as fatal. A version-2 qualification record binds the exact wrapper
bytes, `agy` bytes/version, configured model, provider, and qualification epoch;
the wrapper validates local identity immediately before provider execution.
EDGE-DEV passed the current governed qualification for Antigravity 1.1.26 and
reports `available`; verified `main` completed a real read-only review with
unchanged source. Every other host remains fail-closed until it writes its own
current qualification record. `plan_ai-gemini-wrapper.md` is retained as dated
investigation history and points here for current status.

## 6. Key findings and root cause

The disposable copy limits damage but is not proof of read-only behavior. Git
status shape is not content identity, provider success is not completion, and a
conversation is not exact unless returned and stored IDs agree. Lifecycle state
must exist before the paid call.

## 7. Approaches considered and REJECTED

Global setting changes and `--dangerously-skip-permissions` remain forbidden.
Status-text comparison, exit/provider-success alone, warning-only report failure,
and implicit conversation acceptance are rejected by measured failures. Deleting
the disposable copy on uncertainty is rejected because it destroys evidence.

## 8. Design decisions already made (2026-08-21)

LOCKED: keep each machine quarantined until its own current qualification;
disposable self-contained copy; `--sandbox` and
plan mode; before/after byte identity including protected sentinels; exact model,
conversation, verdict and durable report; fail closed. A future dedicated
Antigravity permission profile is a separate improvement and cannot invalidate
the qualified containment already required here.

## 9. The plan — numbered, ordered steps

1. Update the old plan STATUS/current-state and `AGENTS.md` so all sources say
   Gemini is implemented but unsafe/quarantined and point here. You'll know it
   worked when no router says both “does not exist” and “available.”
2. Extend `tests/test-ai-gemini.sh` with already-dirty tracked-file mutation,
   ignored evidence mutation, outside sentinel, wrong returned conversation ID,
   concurrent asks, interrupted/timeout call, unwritable report, empty response,
   wrong model, and stale head. You'll know it worked when unsafe baseline cases
   fail and all sentinels are preserved.
3. Create metadata and ownership-token lock before provider contact; record
   preparation/running/terminal/recovery states atomically; refuse ask/delete
   races and preserve uncertain copies. You'll know it worked when every paid
   attempt is listable and recoverable after forced interruption.
4. Replace status-only proof with a deterministic inventory/hash of the entire
   review copy plus explicit outside sentinels; compare returned conversation ID
   to requested ID; make any report failure fatal and atomic. You'll know it
   worked when every hostile case is rejected without `PASS`.
5. Integrate shared preflight/scoreboard, run Windows and Ubuntu hostile live
   canaries with bounded spend, and save redacted evidence under
   `docs/verification/ai-gemini/<UTC>/`. You'll know it worked when both systems
   prove exact model/resume/read-only/report behavior.
6. COMPLETE 2026-09-04: PR #278 merged through the protected queue at `ed2c6180`;
   complete gates passed; Antigravity 1.1.26 was qualified on idle EDGE-DEV;
   installed preflight reported `available`; and real governed review
   `issue261-proof` returned `APPROVE` with unchanged source. The closeout commit
   removes stale assignment restrictions and handoffs, then closes issues #38 and
   #261 after the documentation-only merge lands.

## 10. Tests required

All Step-2 fixtures in `tests/test-ai-gemini.sh`; shared packet/sandbox/preflight/
scoreboard suites; Windows script suite; one governed qualification whenever a
host's bound identity changes; and one real review on each host before it enters
rotation. Never accept a plausible verdict if any safety or identity check fails.

## 11. Constraints, standing rules, and gotchas in force

Never change global Antigravity settings around a run, use permission bypass, or
trust `SUCCESS`/exit code alone. Preserve uncertain evidence. Model/config must
not be hard-coded beyond the governed configuration. Use a feature branch and
protected merge queue; no broad staging or force-push; paid calls stay bounded
and redacted.

## 12. Access and environment

Windows checkout `C:\repos\ai-devops`; the qualified reviewer host is EDGE-DEV.
`gh` and installed Antigravity login are available. No secret values enter files;
use existing CLI state/1Password item locations only. Git Bash runs offline tests.

## 13. Definition of done + risks and open questions

Done for a host only after hostile/offline/live gates pass, exact-head review
clears all material findings, Albert identity is verified, the protected merge
lands, installed hashes match, and a real unchanged-source review succeeds.
EDGE-DEV meets that bar. Other hosts remain quarantined independently. Rollback
is the merged commit plus quarantine; provider drift fails closed and requires
requalification.

## Mandatory self-audit

1. Yes—Sections 2–10 define the CLI, defects, exact cases, phases and gates.
2. Yes—Sections 6–8 preserve measured failures, rejected bypasses, and decisions.
3. Yes—Section 1 makes proven read-only durable review the governing outcome.
All checklist items pass.

