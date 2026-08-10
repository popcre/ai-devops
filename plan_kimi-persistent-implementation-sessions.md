# Plan: persistent Kimi implementation sessions with disposable workspaces

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Qualify Kimi resume behavior for implementation | ⬜ open | N/A | N/A |
| 2. Add durable implementation-session state and cumulative artifacts | ⬜ open | N/A | N/A |
| 3. Resume exact sessions in reconstructed disposable worktrees | ⬜ open | N/A | N/A |
| 4. Add failure recovery, controls, reconciliation, and migration | ⬜ open | N/A | N/A |
| 5. Verify, document, commit, and push | ⬜ open | N/A | N/A |

Fresh sessions start at the first open row. Update this table and section 5 after every
gate. This open plan is registered by
[`HANDOFF.d/2026-08-10T2314Z-AL8960OFC-codex-kimi-persistent-implementation.md`](HANDOFF.d/2026-08-10T2314Z-AL8960OFC-codex-kimi-persistent-implementation.md).
GLM 5.2's required-change review is incorporated and registered by
[`HANDOFF.d/2026-08-10T2338Z-AL8960OFC-codex-kimi-persistent-glm-amendments.md`](HANDOFF.d/2026-08-10T2338Z-AL8960OFC-codex-kimi-persistent-glm-amendments.md).
GLM 5.2 re-reviewed the amended file in the same named session on 2026-08-10,
marked R1-R9 and all three minor notes PASS, returned `APPROVE`, and confirmed a
brand-new session can execute it without questions.

## 1. The ultimate goal

Albert should be able to give Kimi a multi-turn implementation job without paying the
cost and losing the understanding created on every prior turn. The same named Kimi
implementation conversation must continue by exact session ID, while every turn still
runs in an isolated disposable workspace and returns a reviewable patch. A later turn
must see both Kimi's prior conversation and the exact code state produced by earlier
turns.

The real repository must remain untouched until Albert or the calling agent explicitly
reviews and applies the final patch. Failed work must remain clearly incomplete, never
be called success, and never disappear silently.

If any step below conflicts with this goal, the goal wins. Stop and flag the conflict.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for installing and restoring his
multi-model AI coding workflow. It contains Bash and PowerShell commands, configuration,
skills, tests, and documentation. It is not a hosted application and has no database,
CI workflow, or deployment.

`bin/ai-kimi` is the only supported headless Kimi Code wrapper. It provides named
read-only review sessions and isolated write-capable implementation runs. Kimi Code
0.32.0 is the currently qualified CLI. The repository is `C:\repos\ai-devops`, branch
`main`, remote `https://github.com/u2giants/ai-devops`.

Relevant files are `bin/ai-kimi`, `tests/test-ai-kimi.sh`,
`config/kimi/local-implement.md`, `config/kimi/readonly-review.md`,
`skills/shared/kimi-code-delegation/SKILL.md`, the completed predecessor
`plan_kimi-incomplete-implementation-recovery.md`, and `AGENTS.md`.

## 3. What triggered this work

On 2026-08-10 another session correctly reported that every
`ai-kimi implement <name>` call creates a new Kimi conversation. The temporary worktree
is deleted after the run. `ai-kimi ask <name>` explicitly rejects implementation
sessions. A later implementation run therefore rereads the plan and repository from
scratch instead of continuing the reasoning already paid for.

Reproduction today:

1. Run `ai-kimi implement persistent-demo --prompt "Create the first half of X"`.
2. The wrapper writes a patch, stores metadata with `mode:"implement"`, and removes the
   disposable worktree.
3. Run `ai-kimi ask persistent-demo --prompt "Continue the second half"`.
4. `bin/ai-kimi:cmd_ask` refuses because implementation sessions are one-shot.
5. Starting another implementation name creates a fresh Kimi session with no exact
   conversation continuity.

That is safe but wasteful. The requested change is persistent implementation context,
not a persistent dirty worktree.

## 4. Scope

In this plan:

- Continue named implementation conversations by exact Kimi session ID.
- Preserve code between turns as one durable cumulative binary patch based on the
  original immutable base commit.
- Reconstruct a new disposable worktree for each turn from that base plus the cumulative
  patch, then remove it after durable artifact export.
- Make both `ai-kimi implement <name>` and `ai-kimi ask <name>` continue an existing
  implementation session. A new name creates it.
- Add implementation state to `list`, `show`, `delete`, doctor, locks, and recovery.
- Preserve complete and incomplete artifact recovery on every turn.
- Qualify exact-session resume after a directory change and controlled failure.
- Add migration behavior for existing one-shot implementation records.
- Treat ignored and generated files as deliberately ephemeral. The cumulative patch
  preserves Git-visible source state, not `node_modules`, build output, ignored secrets,
  caches, or downloads. Every continuation prompt must remind Kimi that the workspace
  was reconstructed and ignored artifacts must be recreated and re-tested if needed.

Not in this plan:

- Keeping a worktree alive between commands.
- Writing into the real checkout, automatically applying a patch, committing, pushing,
  or merging application code.
- Replacing exact IDs with `--continue`, newest-session lookup, or directory guessing.
- Combining review and implementation into one session. Their agent profiles differ and
  Kimi fixes the profile at session creation.
- Weakening `session.resume_hint` as the only proven successful-turn marker.
- Inventing token, cost, cache, context-size, or returned-model figures.
- Changing GLM, Grok, the Kimi model pin, authentication, or production/cloud systems.
- Silently rebasing a session when the real repository advances.
- Claiming that ignored files or prior dependency/build state persist between turns.

## 5. Current state of the code

The current one-shot implementation code was last changed in commit
`52704f98549e23044e53da4c9190e48ca59e2757`. The original plan and all GLM amendments
are committed and pushed through `405afe4b948a2859e95b73f6418cef3c062d30aa` on
`main`. No persistent-session implementation has started.

Working and required to remain working:

- `bin/ai-kimi:has_resume_hint` and `session_id_from` prove success only through
  `session.resume_hint` and extract the exact ID.
- `bin/ai-kimi:run_turn` resumes an exact ID with `-r`; resume cannot combine with an
  agent file because Kimi fixes the agent at creation.
- `bin/ai-kimi:implementation_finalize` owns one lifecycle and safely distinguishes
  complete and incomplete artifacts.
- `bin/ai-kimi:start_session` creates a disposable detached worktree, runs Kimi, exports
  the artifact, writes metadata, and cleans up.
- `bin/ai-kimi:emit_implementation_artifact` writes binary complete or incomplete
  artifacts and preserves the exact worktree if durable export fails.
- `bin/ai-kimi:cmd_ask` resumes review sessions under two locks and contains the
  deliberate one-shot implementation rejection this plan replaces.
- `tests/test-ai-kimi.sh` section `implement sessions are one-shot` asserts that resume
  is refused. Replace it with positive exact-resume coverage.
- The completed predecessor records 99 offline and 105 authenticated passing tests for
  incomplete recovery.

Missing today: no cumulative implementation patch, immutable base, reconstruction path,
safe resume state, persistent artifact controls, or measured proof of cross-directory
and post-failure implementation resume.

Unrelated untracked `.ai/` and `docs/claude-remote-control-hardening-v2.md` already exist.
They belong to other work and must remain untouched and unstaged.

## 6. Key findings and root cause

1. Exact-ID persistence exists at the Kimi transport layer. The wrapper blocks it for
   implementation by policy.
2. Conversation continuity alone is insufficient. The next workspace must reconstruct
   the exact cumulative code state before Kimi resumes.
3. A permanent worktree is unnecessary. Durable state can be an immutable base SHA plus
   one atomic cumulative binary patch materialized into a fresh worktree per turn.
4. The canonical artifact must be the full diff from original base to current delegated
   state, not a fragile chain of turn patches.
5. A turn without a terminal hint remains incomplete. Reusing its session after an
   interruption must be measured, not assumed.
6. The session remains anchored to its base if the real repository advances. Silent
   rebasing would change Kimi's remembered world.
7. Existing one-shot records lack enough proven state for automatic continuation unless
   their base and saved patch can be identified uniquely and verified. Current version-1
   records store neither base SHA nor patch path/hash, so in practice they cannot be
   continued safely and must use archive/delete/restart guidance.
8. `git add -A` respects `.gitignore`. The cumulative patch does not preserve dependency
   installs, build output, ignored downloads, caches, or ignored secret files. These are
   non-authoritative environment state and must be recreated in later turns.
9. Kimi's conversation advances before the wrapper can durably save the post-turn patch
   and metadata. If either save fails, Kimi may remember code the canonical state lacks.
   This "conversation ahead of code" state requires a hard recovery lockout.
10. The generation counter is wrapper bookkeeping only. Kimi reports no internal turn
    counter, so generation cannot prove alignment. Only successful durable state capture
    plus the recovery lockout guards conversation/code drift.

## 7. Approaches considered and rejected

1. **Keep one worktree alive. Rejected.** It leaves dirty registered state, complicates
   crash cleanup, and discards the proven disposable-workspace model.
2. **Resume conversation without reconstructing files. Rejected.** Kimi would remember
   edits that are absent.
3. **Start fresh and paste the transcript. Rejected.** It is not exact continuity, grows
   prompts, and can omit tool state.
4. **Use `-c/--continue`. Rejected.** It selects newest by directory, possibly wrong.
5. **Apply earlier work to the real repo. Rejected.** It destroys isolation.
6. **Move the base to current HEAD automatically. Rejected.** Silent rebasing can corrupt
   meaning and patches.
7. **Store a patch chain. Rejected.** One cumulative patch is simpler to verify and own.
8. **Automatically resume after every failed turn. Rejected until measured.** A killed
   process may leave unresolved Kimi state.
9. **Treat incomplete code as accepted without labeling. Rejected.** It remains untrusted.
10. **Guess legacy migration from newest files. Rejected.** Missing or ambiguous evidence
    must fail loudly.
11. **Persist ignored dependency/build state. Rejected.** It may contain secrets, huge
    caches, machine-specific binaries, and disposable output. Recreate it per turn and
    never represent it as canonical source state.
12. **Use a private Git ref as canonical state by default. Rejected for now.** GLM 5.2
    correctly noted that a per-session ref could avoid patch application, but it adds ref
    ownership, garbage-collection, and deletion complexity. Keep the patch design unless
    Phase 1 proves binary/long-path round-tripping unreliable; then stop and revise the
    plan rather than silently switching formats.

## 8. Design decisions already made

Decisions dated 2026-08-10:

- **LOCKED:** Persistent means exact conversation plus exact cumulative code.
- **LOCKED:** Workspaces remain disposable per turn.
- **LOCKED:** Original base SHA is immutable for the named session.
- **LOCKED:** One atomic binary cumulative patch is canonical code state.
- **LOCKED:** `implement <existing-name>` and `ask <implementation-name>` continue the
  same exact session and never create a duplicate.
- **LOCKED:** Real repositories are unchanged and patches are never auto-applied.
- **LOCKED:** Complete and incomplete artifacts stay distinct; incomplete turns return
  nonzero and set explicit recovery state.
- **LOCKED:** Review and implementation remain separate profiles.
- **LOCKED:** Exact ID only. Never newest-by-directory continuation.
- **LOCKED:** Repository and session locks cover materialize, resume, export, metadata,
  cleanup, and failure finalization.
- **LOCKED:** Metadata and cumulative artifacts are atomic, private, and contain no
  prompts, responses, credentials, or invented usage data.
- **LOCKED:** Replace the cumulative patch only after `git apply --check` against the
  recorded base succeeds.
- **LOCKED:** Canonical state lives under
  `$AI_KIMI_STATE_DIR/sessions/<repo-id>/<caller>--<name>.d/`, separate from human-facing
  `.ai/reviews/`. That private directory contains an owner manifest, cumulative binary
  patch, and atomic metadata. `delete` removes only paths named in the validated manifest;
  it never removes `.ai/reviews/` artifacts.
- **LOCKED:** Continuation acquires the session-name lock first and the repository lock
  second, matching current `cmd_ask`. Both stay held from validation/materialization
  through Kimi, artifact export, canonical patch and metadata commit, worktree cleanup,
  and final lock release.
- **LOCKED:** After any turn where post-turn cumulative patch or metadata cannot be
  durably recorded, mark `recovery-required`, preserve exact recovery evidence, and
  refuse exact-session resume. The only next write action is an explicit context-reset
  recovery that reconstructs the best proven code state and visibly starts a new Kimi
  session generation.
- **LOCKED:** Generation counts wrapper-proven durable states, not Kimi-internal turns.
  It must never be presented as proof that Kimi's conversation is aligned.
- **LOCKED:** Ignored/generated files are ephemeral and absent on later turns. Metadata
  records this limit, and every resumed implementation prompt includes a stable notice
  that dependencies/build output may need recreation and tests must be rerun.
- **LOCKED:** Materialization on Windows enables `core.longpaths=true` for the worktree
  before patch checks/application and uses the validated long-path cleanup helper pattern.
- **LOCKED:** After apply, stage Git-visible state, regenerate `git diff --binary <base>`,
  hash it, and require equality with the canonical patch hash before Kimi starts.
- **LOCKED:** `ask <implementation-name>` is a write-capable continuation. Help, skill,
  docs, and runtime stderr must state `implementation continuation (write run)` before
  Kimi starts.
- **LOCKED:** Version-1 one-shot implementation records cannot be continued because they
  lack a recorded base and canonical patch identity. Offer archive/delete/restart only;
  never search timestamps or commits for a guessed match.
- **OPEN, measurement-gated:** Whether failed or cancelled turns can resume the same ID.
  If unproven, preserve code but require an explicit visible context-reset generation.
- **OPEN:** Exact field names and artifact layout may change if ownership and tests stay
  unambiguous.

## 9. The plan

### Phase 1: qualify transport behavior

1. Extend `tests/test-ai-kimi.sh` with a bounded live qualification. Prove an
   implementation session created in worktree A resumes by exact ID in reconstructed
   worktree B, recalls a turn-1 marker, reads cumulative file state in B, and changes
   only B. Measure provider failure, timeout, and cancellation separately. Also prove a
   binary cumulative patch with additions, deletion, executable/mode change, untracked
   source, and a path longer than 260 characters round-trips under Git Bash. Create one
   ignored dependency/build marker in turn 1 and prove it is deliberately absent in turn
   2 while the reconstructed-workspace notice makes Kimi recreate or disregard it.
   Record exact Kimi 0.32.0 behavior in the STEP 0 header and this plan.

   Dependency: none. Do not change production behavior first.

   You'll know it worked when exact conversation and file continuity are proven across
   two different paths, the real repo is unchanged, both worktrees are removed, and
   failed-turn policy has evidence or remains disabled; binary and long-path state hashes
   round-trip; and ignored state is absent by design, recorded, and never claimed durable.

### Phase 2: durable persistent state

2. Define a versioned implementation record in `bin/ai-kimi` with mode, exact session
   ID, repo/remote identity, immutable base SHA, canonical patch path/hash, wrapper
   generation, turns, timestamps, last terminal state, incomplete-state flag, continuity
   state, and lifecycle status. Store canonical state only inside the validated private
   directory `$AI_KIMI_STATE_DIR/sessions/<repo-id>/<caller>--<name>.d/`. Its owner
   manifest lists the exact wrapper-owned metadata and cumulative-patch paths. Human
   reports and per-turn patches remain under `.ai/reviews/` and are never owned by
   `delete`. Add atomic validation and strict owned-path checks. Store no prompts or
   responses. Record that ignored/generated environment state is ephemeral and that
   generation is wrapper bookkeeping, not Kimi-side truth.

   Dependency: step 1.

   You'll know it worked when tests reject missing or forged base, path, hash,
   generation, caller, repository, mode, private-directory ownership, and manifest paths
   before worktree or Kimi activity; canonical and human artifacts cannot be confused.

3. Refactor `start_session`, `emit_implementation_artifact`, and the finalizer so every
   first complete or partial turn writes the canonical cumulative patch before cleanup.
   Keep per-turn human-facing artifacts. Advance metadata only after durable verified
   patch storage. If patch or metadata storage fails after Kimi ran, atomically mark the
   record `recovery-required`, preserve exact recovery evidence, and forbid resume even
   if the old canonical patch remains valid. Never treat the wrapper generation as proof
   that Kimi did not advance.

   Dependency: step 2.

   You'll know it worked when complete and partial fixtures leave one valid canonical
   patch, truthful metadata, a review artifact, no real-repo change, and no normal
   worktree; injected failures never advertise an unproven generation and always block
   resume until explicit context-reset recovery.

### Phase 3: reconstruct and resume

4. Add a materialization helper. Under both locks, create a detached worktree at the
   recorded base, validate repo identity and patch hash, run `git apply --check`, apply
   the patch, and prove reconstructed diff state. On Windows, set `core.longpaths=true`
   in the worktree before checkout/apply and use the existing validated long-path cleanup
   pattern. After apply, run `git add -A`, regenerate `git diff --binary <base>`, hash the
   exact bytes, and require equality with the stored canonical hash. Refuse resume on any
   mismatch. Only then call `run_turn` with the exact session ID. Prefix every resumed
   prompt with one stable notice: the workspace was reconstructed from canonical source
   state; ignored dependencies, build output, downloads, caches, and secrets did not
   persist and must be recreated and re-tested when needed.

   Dependency: steps 2-3.

   You'll know it worked when turn 2 starts with all turn-1 text, binary, and untracked
   additions, deletion, mode changes, and long paths; the regenerated binary diff hash
   matches; ignored state is absent; `-r` uses the exact ID without agent file; and the
   real repo remains untouched.

5. Route `implement <new-name>` to creation, `implement <existing implementation>` to
   continuation, and `ask <implementation>` to the same continuation. Keep review ask
   unchanged. Reject mode collisions, concurrent turns, ambiguous moved checkouts, and
   recovery-required records without explicit recovery. Reuse current `find_meta`
   moved-checkout and remote-identity logic instead of reimplementing it. The continuation
   function must acquire `sess_lock` first, then `rid_lock`, matching current `cmd_ask`,
   and hold both from record validation and worktree creation through provider turn,
   export, canonical commit, metadata commit, cleanup, and release. Before an `ask`-routed
   implementation turn, print `implementation continuation (write run)` to stderr.

   Dependency: step 4.

   You'll know it worked when both commands increment one record/generation, use one
   exact ID, runtime output labels the write action, and duplicates create no second
   worktree or provider turn at any lifecycle point.

Natural context cut: update STATUS, section 5, and the handoff after step 5. Re-read
phases 4-5 before continuing in a fresh context if needed.

### Phase 4: failures, controls, migration, cleanup

6. Integrate complete, partial, no-change, usage-limit, timeout, and cancellation outcomes
   with persistent state. A failed turn may update cumulative code but never claim
   successful conversation advancement. Apply Phase 1's measured resume rule. Any
   post-turn patch/metadata persistence failure is always `recovery-required` because the
   Kimi conversation may be ahead of canonical code. If resume is unsafe or drift is
   possible, add an explicit recovery command that reconstructs the newest durably proven
   canonical state or exact preserved worktree, starts a new Kimi session generation,
   and announces that conversation context reset. Describe degraded mode honestly as
   code continuity without conversation continuity.

   Dependency: steps 1 and 5.

   You'll know it worked when every failure preserves truthful code, returns nonzero,
   records continuity availability; metadata-write failure refuses resume; and next action
   either resumes proven context or loudly requires documented context-reset recovery.

7. Extend `list`, `show`, `delete`, `transcript`, and doctor. Show mode, turn/generation,
   base, complete/incomplete state, and recovery need. Delete refuses active turns,
   validates the private owner manifest, and removes only the exact private metadata and
   cumulative patch named there. It never removes `.ai/reviews/` reports or review patches.
   Transcript exports the exact session. Doctor cleans stale worktrees without deleting
   durable persistent state. Every control labels generation as wrapper-proven state, not
   Kimi's internal turn number.

   Dependency: steps 2-6.

   You'll know it worked when tests prove exact controls, active-delete refusal,
   idempotent deletion, transcript accuracy, stale cleanup, and outside-path refusal.

8. Add migration handling for version-1 records while preserving review records. Current
   one-shot implementation JSON stores no base SHA and no canonical patch path/hash, so
   it is never eligible for continuation. `show` must label it legacy/non-resumable and
   give exact archive, delete, and persistent restart commands. Do not search commits,
   timestamps, filenames, or apply-compatible patches for a guessed migration.

   Dependency: step 7.

   You'll know it worked when review records still resume, every legacy implementation
   is blocked before Kimi/worktree activity, archive/delete/restart guidance is exact,
   and moved-checkout plus caller separation remain correct.

### Phase 5: verify and land

9. Update the STEP 0 header, help, shared Kimi skill, `AGENTS.md`,
   `docs/codex-skills-usage-guide.md`, `docs/skills-map.md`, and this plan. Explain
   persistent conversation plus disposable workspace, immutable base, cumulative patch,
   continuation, ignored-state limits, drift recovery, deletion, and missing usage
   metrics. Help and skill must say `ask` on an implementation session starts a
   write-capable continuation, and the implementation profile's no-cross-user rule must
   apply on every continuation, not only creation. Reinstall and hash-compare source,
   Claude, and Codex skills.

   Dependency: steps 1-8.

   You'll know it worked when no active doc calls implementation one-shot, examples match
   tests, and installed hashes match source.

10. Run syntax, full Kimi offline, routed Windows, doctor, secret scan, and bounded live
    tests for two successful turns and one failure recovery. Inspect the diff, verify
    Albert's identity, commit only owned files on `main`, push, and prove
    `HEAD == origin/main`. Complete STATUS and delete only this plan's handoff after proof.

    Dependency: steps 1-9.

    You'll know it worked when all tests pass, live evidence proves conversation and code
    continuity across disposable worktrees, no unrelated file is staged, and all STATUS
    rows have pushed evidence.

## 10. Tests required

Add these behaviors while preserving existing read-only, completion, recovery, ownership,
and lock tests:

- `implementation_turn_two_resumes_exact_session_id`
- `implementation_turn_two_reconstructs_cumulative_text_binary_and_untracked_state`
- `implementation_turn_two_uses_new_disposable_worktree_and_cleans_it`
- `implement_existing_name_and_ask_share_one_continuation_path`
- `implementation_base_sha_is_immutable_when_real_head_advances`
- `cumulative_patch_hash_and_apply_check_gate_resume`
- `reconstructed_binary_diff_hash_equals_canonical_hash`
- `ignored_dependency_state_is_absent_and_declared_ephemeral`
- `windows_long_path_round_trips_with_worktree_longpaths_enabled`
- `canonical_generation_advances_only_after_atomic_patch_and_metadata_success`
- `metadata_or_patch_persistence_failure_marks_recovery_required_and_refuses_resume`
- `generation_is_never_presented_as_kimi_internal_turn`
- `concurrent_same_name_creates_one_worktree_and_one_provider_turn`
- `continuation_lock_order_is_session_then_repository_for_full_lifecycle`
- `mode_collision_between_review_and_implementation_fails_before_turn`
- `ask_on_implementation_prints_write_run_warning`
- `failed_partial_turn_preserves_code_and_truthful_continuity_state`
- `failed_no_change_does_not_advance_patch_generation`
- `timeout_and_cancel_follow_measured_resume_policy`
- `explicit_context_reset_is_never_silent`
- `delete_refuses_active_and_removes_only_validated_session_state`
- `delete_keeps_all_human_facing_review_artifacts`
- `transcript_exports_exact_implementation_session`
- `doctor_cleans_stale_worktree_but_keeps_persistent_artifacts`
- `legacy_one_shot_implementation_is_never_guessed_or_resumed`
- `moved_checkout_and_caller_identity_remain_exact`
- Live turn 2 recalls a turn-1 marker, reads reconstructed code, and changes only its new
  disposable worktree.
- Live controlled failure preserves cumulative patch and follows measured recovery.

Required commands: `bash -n bin/ai-kimi`, `bash tests/test-ai-kimi.sh`, relevant routed
Bash and PowerShell suites, `ai-kimi doctor`, and bounded opt-in authenticated tests.

## 11. Constraints and gotchas

- Main-only; preserve concurrent work and stage only owned files.
- Verify commit identity is `Albert Hazan <u2giants@users.noreply.github.com>`.
- Kimi 0.32.0 tool names are case-sensitive; wrong case silently removes capabilities.
- Reviews remain structurally read-only and separate from implementation.
- `--agent-file` cannot combine with resume; the creation profile persists.
- `session.resume_hint` remains required; exit status proves nothing.
- Never use `-c/--continue`.
- Kimi has no max-turns or trustworthy usage/cache/cost/model output.
- Git Bash has no `flock`; keep atomic-directory locks.
- Materialization must set worktree-local `core.longpaths=true` before patch operations;
  cover binary, untracked, mode-change, deleted, and >260-character paths.
- Ignored files are deliberately not canonical. The wrapper and skill must warn that
  dependencies/build outputs are reconstructed per turn and tests must be rerun.
- Session lock is acquired before repository lock and both cover the full continuation.
- Any post-provider failure to save canonical patch or metadata blocks resume. A valid
  old patch does not prove conversation alignment.
- Implement continuations never borrow another user's Kimi credentials on shared hosts,
  matching the current creation rule.
- Store no prompts, responses, credentials, or secret-bearing logs in metadata.
- No band-aids, silent fallback, guessed migration, or automatic patch application.

## 12. Access and environment

- Repo: `C:\repos\ai-devops`, `main`, remote
  `https://github.com/u2giants/ai-devops`.
- Windows 11 host `AL8960OFC`; PowerShell 7 plus Git Bash.
- Ubuntu/Hetz shared-user behavior also matters: implementation creation and every
  continuation must run as the credential-owning current user and must never be silently
  delegated through `AI_KIMI_OWNER`, because writes would have the wrong ownership.
- Expected: Git, Bash, `jq`, authenticated `gh`, Kimi Code 0.32.0.
- Kimi OAuth is per-user under `~/.kimi-code`; never expose it.
- Other secrets stay in 1Password account `popcreations.1password.com`, vault
  `vibe_coding`; this work should need none.
- No application URL, database, CI workflow, or deployment applies.

## 13. Definition of done, risks, and open questions

Done means all STATUS rows have dated evidence; one name keeps exact conversation and
cumulative code across two disposable worktrees; complete/incomplete truth remains;
locks, controls, migration, cleanup, and deletion pass; review safety stays green;
installed skills match source; work is committed and pushed with Albert's identity; and
`HEAD == origin/main`. CI and deploy are N/A because this repo has neither.

Risks: Kimi may tie tool state to an old directory; interrupted sessions may not resume;
ignored environment state does not persist; the Kimi conversation can advance before a
canonical save fails; the real repo may diverge from the immutable base; binary/long-path
application may vary on Windows; and durable state may accumulate. Phase 1 measures
transport and round-trip facts. Stable prompts declare ignored state ephemeral. Any
post-turn save failure locks the record for explicit context-reset recovery. Immutable
base conflicts remain visible. Wrapper generation is not treated as Kimi truth. Exact
round-trip hashes, worktree long-path configuration, and safe manifest-based delete cover
the remaining risks.

Rollback is a normal Git revert. Existing records must remain readable or receive exact
archive guidance. Never roll back by applying hidden work or deleting ambiguous state.

Open questions are only the Phase 1 measurements: exact-ID behavior in a different
worktree, whether Kimi reads the new CWD rather than cached old paths, resumability after
each failure class, and binary/mode/deletion/long-path patch round-trip reliability. If
cross-directory resume or new-CWD visibility fails, stop before Phases 2-5. If patch
round-trip is unreliable, reconsider GLM's private Git-ref alternative through a revised
reviewed plan. Decide by pinned CLI evidence, never convenience.

## Mandatory self-audit

1. **Yes.** Sections 1-5 define outcome, toolkit, reproduction, scope, files, commit, and
   exact current behavior. Sections 9-10 give ordered function-level work and gates.
2. **Yes.** Sections 6-8 preserve root cause, conversation-plus-code requirement,
   ignored-state limit, conversation-ahead drift, rejected designs, exact storage and
   lock rules, legacy non-migration, and measurement questions. Sections 11-13 preserve
   platform traps, multi-user access, risks, rollback, and landing.
3. **Yes.** Section 1 makes exact multi-turn understanding without lost isolation or
   truth the deciding goal. Sections 4 and 8 bound all judgment calls.

All 13 sections are present, with exclusions, files, named tests, gates, locked/open
decisions, secret-safe access, commit/push proof, and bidirectional handoff registration.
GLM 5.2 required changes R1-R9 are incorporated: ephemeral ignored state, drift lockout,
wrapper-generation limits, exact lock order, private owned storage, no guessed legacy
migration, binary round-trip hash, write-run warning, and Windows long-path handling.
A fresh session needs no chat context. Self-audit re-passed on 2026-08-10.
