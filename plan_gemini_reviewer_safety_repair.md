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
| 6 | Governed qualification record, unquarantine, and close issue #38 | 🟨 implementation landed; production closeout pending | The hash-bound qualification record, fail-closed runtime checks, and true live-preflight path are on `origin/main` at `f26d5eb`. Targeted suites passed (62 Gemini + 51 preflight), exact-source review returned APPROVE, and the one full master gate passed (53 Bash suites + 16 PowerShell suites, zero failures). Exact-head CI run `32891794146` completed successfully across Linux offline, Windows reviewer-safety, and Windows offline. Windows is qualified and reports `available`. Ubuntu remains safely `quarantined` on older source until current `main` is installed and independently qualified, followed by one real issue #38 review and final issue/docs/handoff closeout. Evidence: `tests/verification/reviewer-production-completion/2026-08-25-gemini-governed-qualification-progress.md`. |

Fresh session resumes Step 6 with exact-head CI run `32891794146` already green;
do not rerun the full master gate. Install current `main` on Ubuntu as `ai`,
qualify that machine, and run the real issue #38 review. Preserve
Ubuntu quarantine until its own exact wrapper/runtime/model qualification passes.
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
Issue #38 remains open. A denied command previously returned provider `SUCCESS`
with an empty response.

## 4. Scope — in and out

In: Gemini review lifecycle, containment proof, report durability, exact
conversation/model/verdict checks, locks/recovery, tests/docs/installation and
issue #38. Out: implementation mode, global Antigravity setting changes,
permission bypass flags, other providers, databases/production.

## 5. Current state of the code

As of 2026-08-25, `bin/ai-gemini` records state before provider contact, uses
repository/session locks, inventories the disposable copy and protected source
before and after both review and model-verification calls, freezes the complete
source-file state across turns, matches resumed conversation IDs, and treats
report failure as fatal. A version-2 qualification record binds the exact wrapper
bytes, `agy` bytes/version, configured model, provider, and qualification epoch;
the wrapper validates local identity immediately before provider execution.
Windows passed the governed qualification and reports `available`. Ubuntu passed
the earlier containment canary but remains `quarantined` until the current
`f26d5eb` source passes exact-head CI, is installed, and writes its own current
qualification record. `plan_ai-gemini-wrapper.md` is retained as dated
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
conversation, verdict and durable report; fail closed. OPEN: whether installed
Antigravity now exposes a safer dedicated permission profile—adopt only after
hostile canaries prove it on both operating systems.

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
6. The implementation, targeted tests, exact-head APPROVE, one full master gate,
   push, and Windows qualification are complete at `f26d5eb`. Finish exact-head
   CI run `32891794146`; install current `main` on Ubuntu as `ai`; prove installed
   hashes; qualify Ubuntu; run one real open-issue review; then close #38 and
   retire superseded Gemini handoffs only after their obligations are retained.
   You'll know it worked when both machines report `available`, issue #38 has a
   durable exact-head Gemini report, the final documentation commit is green on
   GitHub, and no stale Gemini continuation handoff remains.

Current cut point is within Step 6: exact-head CI is green; continue with Ubuntu
installation and qualification. Do not repeat the already-passed master gate.

## 10. Tests required

All Step-2 fixtures in `tests/test-ai-gemini.sh`; shared packet/sandbox/preflight/
scoreboard suites; Windows script suite; one complete and one deliberately denied
live turn on each platform. Never accept a plausible verdict if any safety or
identity check fails.

## 11. Constraints, standing rules, and gotchas in force

Never change global Antigravity settings around a run, use permission bypass, or
trust `SUCCESS`/exit code alone. Preserve uncertain evidence. Model/config must
not be hard-coded beyond the governed configuration. Main-only; no broad staging
or force-push; paid calls bounded and redacted.

## 12. Access and environment

Windows checkout `C:\repos\ai-devops`; Ubuntu qualification host per
`templates/system/machine-atlas.md`. `gh` and installed Antigravity login are
available. No secret values enter files; use existing CLI state/1Password item
locations only. Git Bash runs offline tests.

## 13. Definition of done + risks and open questions

Done only after all hostile/offline/live gates pass on both systems, exact-head
review clears all material findings, Albert identity is verified, scoped commit
is pushed to `main`, remote/install hashes match, #38 closes with artifacts, and
all contradictory docs are reconciled. No deployment. Rollback is commit plus
quarantine. Risk: provider CLI contract changes; fail closed and requalify.

## Mandatory self-audit

1. Yes—Sections 2–10 define the CLI, defects, exact cases, phases and gates.
2. Yes—Sections 6–8 preserve measured failures, rejected bypasses, and decisions.
3. Yes—Section 1 makes proven read-only durable review the governing outcome.
All checklist items pass.

