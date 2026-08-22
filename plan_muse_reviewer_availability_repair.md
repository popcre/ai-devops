# IMPLEMENTATION PLAN — Muse reviewer availability repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Baseline shared-db and stalled-turn fixtures | ✅ complete | `tests/test-ai-muse.sh` 105/105, including an exact FINDINGS/NO FINDINGS verdict vocabulary, private report storage with per-run Windows ACL enforcement, exclusive non-following staging reservation, no-clobber publication, caller-correct shared guidance, a bounded provider-contacting live doctor, a private file-to-child credential handoff with process-chain inspection proving the key stays out of arguments and the heartbeat parent, a minimal provider-child environment with no writable report descriptor, descriptor-bound pre-turn report staging, pre/post-open substitution refusal, pre- and post-delay destination validation, exact-identity cleanup, pre-state heartbeat validation, child-reaping HUP handling, and late-publication interruption coverage |
| 2 | Exact report-destination safety | ✅ complete | tracked-history and exact-destination fixtures |
| 3 | Pre-provider durable state/progress | ✅ complete | interruption, slow-turn, heartbeat, and uncertainty fixtures |
| 4 | Caller identity and central governance | ✅ complete | caller, preflight, and scoreboard fixtures |
| 5 | Windows/Ubuntu qualification and landing | 🟨 pending exact-head approval | installed open-issue evidence and remote SHA |

Current work starts at Step 5. Reconcile with `plan_muse-opencode-harness.md` and
issues #40/#45/#51; this plan governs the audit defects.

## 1. The ultimate goal — what we are trying to achieve

Muse must start in every valid repository, immediately expose whether a paid turn
is active, preserve uncertain work, and remain findable by the caller that began
it. If any step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-muse` runs Muse Spark 1.2 Contributor through a pinned OpenCode setup in a
private self-contained copy. It provides persistent named review conversations in
the public `ai-devops` toolkit on Windows and Ubuntu.

## 3. What triggered this work

Audit findings 10, 11, 21 and 24: Muse rejects shared-db because historic review
reports are tracked; two turns stalled 17 minutes with no state/output; omitted
caller defaults to Codex; preflight/scoreboard omit Muse. Issues #45/#51 contain
reproduced evidence.

## 4. Scope — in and out

In: destination check, pre-provider metadata, progress/reconciliation, caller
identity, shared governance, tests/docs/install and live qualification. Out:
changing the pinned model/provider, replacing direct persistence with the failed
server design, broadening permissions, GLM service changes, application repos.

## 5. Current state of the code

Caller default is `bin/ai-muse:11`; destination checks at `:93-99` reject any
tracked `.ai/reviews` entry; prepare/run/meta order is `:136-146`, so no metadata
exists during the call. Current Muse suite passes 71 existing cases. The harness
plan still has partial/open Ubuntu, failure-matrix, preflight and landing work.

## 6. Key findings and root cause

Safety checks inspect the whole history folder instead of the exact new
destination. Lifecycle state begins after the longest failure window. Caller
identity is an implicit environment convention rather than an enforced input.

## 7. Approaches considered and REJECTED

Rejecting all tracked historic reports is rejected; only the exact new report
path matters. Waiting silently until completion is rejected. Defaulting everyone
to Codex is rejected. Reintroducing the Meta/server route is rejected because
authorization failed and direct exact-session resume already provides persistence.

## 8. Design decisions already made (2026-08-18/21)

LOCKED: exact pinned Contributor model; direct named sessions; private copy;
read-only profile; exact-destination safety; durable state before provider contact;
no false remote cancellation. OPEN: require explicit caller or derive it from a
trusted launcher—either must prevent cross-caller loss.

## 9. The plan — numbered, ordered steps

1. Extend `tests/test-ai-muse.sh` with a repository containing valid tracked
   historic reports, exact destination tracked/ignored cases, slow provider,
   interruption before first output, vanished child, and Claude/Codex callers.
   You'll know it worked when baseline failures reproduce without live spend.
2. Refactor `ensure_report_destination()` to validate only the exact proposed
   unique destination plus physical containment and ignore/tracked state. You'll
   know it worked when historic reports are allowed but an unsafe new path fails.
3. Before `run_turn()`, atomically write status, caller, repo, session name,
   sandbox, start time and process ownership; emit bounded heartbeat; preserve
   `provider_outcome_uncertain` for interrupted/vanished calls. You'll know it
   worked when another shell can list/reconcile every slow or killed run.
4. Enforce correct caller identity and integrate Muse into preflight/quarantine/
   scoreboard. You'll know it worked when Claude can resume its own run and not
   Codex's, with truthful outcome records.
5. Complete Windows/Ubuntu failure and live matrix, exact-head review, install,
   commit/push, verify remote/install hashes, update/close applicable issues and
   plan statuses. You'll know it worked when shared-db starts one visible,
   terminal, durable Muse review on both systems.

Natural cut after Step 3; use `fresh-session` and re-read Steps 4–5.

## 10. Tests required

All Step-1 cases; existing 71 Muse cases; shared sandbox/packet/preflight/
scoreboard/incident suites; Windows installer tests; live exact-session resume,
slow progress, uncertain recovery, hostile write and shared-db destination cases.

## 11. Constraints, standing rules, and gotchas in force

Use the `ask-muse` skill and exact Contributor model. Never fall back to another
Muse/model, broaden tools, claim remote cancellation, or delete uncertain copies.
Serialize 1Password access. Main-only, scoped staging, no force-push.

## 12. Access and environment

Windows checkout `C:\repos\ai-devops`; Ubuntu host per machine atlas. Muse key is
in 1Password vault `vibe_coding` at its existing Muse item—reference only, never
value; serialize reads. `gh` authenticated; Git Bash runs tests.

## 13. Definition of done + risks and open questions

Done: offline/live cross-platform matrix green; shared-db case proven; exact-head
review clears findings; Albert identity/scoped commit/main push/remote-install
hashes verified; issues/plans/docs/handoff current. No deployment. Risk: provider
can still stall; bounded visible uncertainty is acceptable, silent disappearance
is not. Rollback by commit and quarantine.

## Mandatory self-audit

1. Yes—Sections 3–10 give reproductions, source targets, phases and proof gates.
2. Yes—Sections 6–8 preserve why broad-history rejection/server fallback fail.
3. Yes—Section 1 makes availability, visibility and caller ownership decisive.
All checklist items pass.
