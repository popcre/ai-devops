# IMPLEMENTATION PLAN — DeepSeek reviewer safety repair (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Hostile path and concurrency fixtures | ✅ complete | `tests/test-ai-deepseek-agent.sh` (29 cases) |
| 2 | Contained session identity | ✅ complete | hostile name, outside sentinel, and link fixtures |
| 3 | Atomic locked conversation commits | ✅ complete | failed-call rollback and concurrent reply fixtures |
| 4 | Review completion/governance contract | 🟨 provider complete; shared integration pending | `--review` verdict + exact session/HEAD sidecar complete; shared preflight/scoreboard allowlists are owned by `plan_reviewer_shared_evidence_integrity.md` |
| 5 | Land and install | 🟨 delegated handoff pending | isolated commit and tests will be handed to the parent session; that session owns merge, push, install, and exact-head review |

Fresh session starts at Step 1.

## 1. The ultimate goal — what we are trying to achieve

DeepSeek must never read or change files outside its own session store, lose or
duplicate conversation turns, or approve without durable evidence. If any step
below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`bin/ai-deepseek-agent` is a Bash wrapper for persistent DeepSeek conversations
in the `u2giants/ai-devops` toolkit on `main`. It stores JSON history locally and
sends review diffs as text. It is not a hosted service.

## 3. What triggered this work

Audit findings 1 and 22: caller-controlled names reach filesystem paths at
`bin/ai-deepseek-agent:177-180,217-233`; history rewriting at `:146-157,231-232`
is unlocked, non-atomic, and commits the user turn before provider success.

## 4. Scope — in and out

In: session-name validation, canonical containment, locking, atomic history,
failed-turn behavior, tests, shared reviewer governance, docs/install. Out:
provider API redesign, credential rotation, model selection, other wrappers.

## 5. Current state of the code

Session files are derived directly from `$ID`; `show` and `reply` trust that
path. `append_and_save()` rewrites the live JSON and a failed API call leaves a
dangling user message. There is no dedicated hostile traversal/concurrency suite
or shared scoreboard integration. No fix is committed.

## 6. Key findings and root cause

The wrapper validates existence, not identity or containment. It treats a
multi-step conversation update as separate writes without one owner. User input
is therefore both a path component and prematurely durable state.

## 7. Approaches considered and REJECTED

Escaping `../` alone is rejected because absolute paths, separators, device
names, and encoded variants remain. PID-only locks are rejected because stale
PIDs can be reused. Appending an error assistant turn is rejected as a substitute
for transactional state; failed provider turns must be explicit attempts.

## 8. Design decisions already made (2026-08-21)

LOCKED: strict safe-name grammar plus resolved containment; atomic same-filesystem
replace; one session writer; provider failure does not silently advance canonical
conversation; nonzero on incomplete review. OPEN: preserve failed user prompts in
a separate recovery record or discard them, provided later calls never resend
them implicitly.

## 9. The plan — numbered, ordered steps

1. Add `tests/test-ai-deepseek-agent.sh` with `..`, separators, absolute paths,
   Windows drive/device forms, symlinked session folder, concurrent replies,
   provider failure, interrupted atomic write, and verdict cases. You'll know it
   worked when baseline traversal/concurrency tests expose the defects safely in
   a temporary tree.
2. Add `valid_name()` and `session_path()` that resolve and prove containment
   before every read/write/delete. You'll know it worked when every hostile name
   exits nonzero and outside sentinels remain byte-identical.
3. Add ownership-token locks and atomic temp-plus-replace updates. Build the
   candidate transcript, call the provider, then commit user+assistant together;
   record failed attempts separately. You'll know it worked when concurrent
   replies serialize and failure leaves canonical history unchanged.
4. Require a usable verdict for review mode and register DeepSeek in shared
   preflight/scoreboard with exact session/head identity. You'll know it worked
   when missing evidence is `unknown`/failed, never approval.
5. Update docs/skill, run full tests, independent exact-head security review,
   install, commit, push, and verify remote/install hashes. You'll know it worked
   when no hostile case changes or reveals an outside file.

## 10. Tests required

All Step-1 cases in the new suite, plus shared packet/preflight/scoreboard tests,
shell syntax, Windows path fixtures, and one bounded authenticated conversation
that proves exact-session continuation without printing credentials.

## 11. Constraints, standing rules, and gotchas in force

Do not read or print provider secrets; reference 1Password only by item title if
needed. Preserve text-diff boundary. Never use destructive cleanup against an
unresolved path. Main-only, recoverable edits, no broad staging/force-push.

## 12. Access and environment

Checkout `C:\repos\ai-devops`; Git Bash for tests; `gh` authenticated. Provider
credential remains in its existing private machine configuration/1Password
location—never copy its value into evidence. Offline stubs do most verification.

## 13. Definition of done + risks and open questions

Done: traversal/concurrency/failure/verdict tests pass; related suites pass;
exact-head security review has no unresolved finding; Albert identity verified;
owned files committed/pushed; remote SHA and installed hash match; docs and plan
current. No deployment. Risk: rejecting legacy unsafe names; provide a read-only
listing/migration path that never opens an uncontained file. Rollback by commit.

## Mandatory self-audit

1. Yes—Sections 3–10 define reproduction, targets, ordering, and exact gates.
2. Yes—Sections 6–8 retain the path and transaction reasoning and dead ends.
3. Yes—Section 1 makes containment and complete evidence the overriding goal.
All checklist items pass.

