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
4. `bin/ai-kimi:808-810` refuses because implementation sessions are one-shot.
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

## 5. Current state of the code

Current `main` is commit `52704f98549e23044e53da4c9190e48ca59e2757`, pushed to
`origin/main` when this plan was written.

Working and required to remain working:

- `bin/ai-kimi:232-240` proves success only through `session.resume_hint` and extracts
  the exact ID.
- `bin/ai-kimi:287-295` resumes an exact ID with `-r`; resume cannot combine with an
  agent file because Kimi fixes the agent at creation.
- `bin/ai-kimi:519-698` owns one lifecycle and safely distinguishes complete and
  incomplete artifacts.
- `bin/ai-kimi:717-779` creates a disposable detached worktree, runs Kimi, exports the
  artifact, writes metadata, and cleans up.
- `bin/ai-kimi:604-667` writes binary complete or incomplete artifacts and preserves the
  exact worktree if durable export fails.
- `bin/ai-kimi:803-835` resumes review sessions under two locks.
- `bin/ai-kimi:808-810` is the deliberate one-shot rejection this plan replaces.
- `tests/test-ai-kimi.sh:141-149` asserts that implementation resume is refused. Replace
  it with positive exact-resume coverage.
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
   their base and saved patch can be identified uniquely and verified.

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
- **OPEN, measurement-gated:** Whether failed or cancelled turns can resume the same ID.
  If unproven, preserve code but require an explicit visible context-reset generation.
- **OPEN:** Exact field names and artifact layout may change if ownership and tests stay
  unambiguous.

## 9. The plan

### Phase 1: qualify transport behavior

1. Extend `tests/test-ai-kimi.sh` with a bounded live qualification. Prove an
   implementation session created in worktree A resumes by exact ID in reconstructed
   worktree B, recalls a turn-1 marker, reads cumulative file state in B, and changes
   only B. Measure provider failure, timeout, and cancellation separately. Record exact
   Kimi 0.32.0 behavior in the STEP 0 header and this plan.

   Dependency: none. Do not change production behavior first.

   You'll know it worked when exact conversation and file continuity are proven across
   two different paths, the real repo is unchanged, both worktrees are removed, and
   failed-turn policy has evidence or remains disabled.

### Phase 2: durable persistent state

2. Define a versioned implementation record in `bin/ai-kimi` with mode, exact session
   ID, repo/remote identity, immutable base SHA, canonical patch path/hash, generation,
   turns, timestamps, last terminal state, incomplete-state flag, and lifecycle status.
   Add atomic validation and strict owned-path checks. Store no prompts or responses.

   Dependency: step 1.

   You'll know it worked when tests reject missing or forged base, path, hash,
   generation, caller, repository, and mode before worktree or Kimi activity.

3. Refactor `start_session`, `emit_implementation_artifact`, and the finalizer so every
   first complete or partial turn writes the canonical cumulative patch before cleanup.
   Keep per-turn human-facing artifacts. Advance metadata only after durable verified
   patch storage. Preserve exact recovery evidence on patch or metadata failure.

   Dependency: step 2.

   You'll know it worked when complete and partial fixtures leave one valid canonical
   patch, truthful metadata, a review artifact, no real-repo change, and no normal
   worktree; injected failures never advertise an unproven generation.

### Phase 3: reconstruct and resume

4. Add a materialization helper. Under both locks, create a detached worktree at the
   recorded base, validate repo identity and patch hash, run `git apply --check`, apply
   the patch, and prove reconstructed diff state. Only then call `run_turn` with the exact
   session ID.

   Dependency: steps 2-3.

   You'll know it worked when turn 2 starts with all turn-1 text, binary, and untracked
   additions, passes `-r` exact ID without agent file, and never touches the real repo.

5. Route `implement <new-name>` to creation, `implement <existing implementation>` to
   continuation, and `ask <implementation>` to the same continuation. Keep review ask
   unchanged. Reject mode collisions, concurrent turns, ambiguous moved checkouts, and
   recovery-required records without explicit recovery.

   Dependency: step 4.

   You'll know it worked when both commands increment one record/generation, use one
   exact ID, and duplicates create no second worktree or provider turn.

Natural context cut: update STATUS, section 5, and the handoff after step 5. Re-read
phases 4-5 before continuing in a fresh context if needed.

### Phase 4: failures, controls, migration, cleanup

6. Integrate complete, partial, no-change, usage-limit, timeout, and cancellation outcomes
   with persistent state. A failed turn may update cumulative code but never claim
   successful conversation advancement. Apply Phase 1's measured resume rule. If resume
   is unsafe, add an explicit recovery command that reconstructs code, starts a new Kimi
   session generation, and announces the context reset.

   Dependency: steps 1 and 5.

   You'll know it worked when every failure preserves truthful code, returns nonzero,
   records continuity availability, and next action either resumes proven context or
   loudly requires documented recovery.

7. Extend `list`, `show`, `delete`, `transcript`, and doctor. Show mode, turn/generation,
   base, complete/incomplete state, and recovery need. Delete refuses active turns,
   removes only validated session state, and does not surprise-delete human review
   patches. Transcript exports the exact session. Doctor cleans stale worktrees without
   deleting durable persistent state.

   Dependency: steps 2-6.

   You'll know it worked when tests prove exact controls, active-delete refusal,
   idempotent deletion, transcript accuracy, stale cleanup, and outside-path refusal.

8. Add migration for version-1 one-shot implementation records while preserving review
   records. Continue legacy implementation only from a unique verified base and patch;
   otherwise give exact archive/delete/restart guidance. Never select newest timestamp.

   Dependency: step 7.

   You'll know it worked when fixtures cover exact match, missing patch, multiple
   candidates, moved checkout, and caller separation, with unsafe cases failing before
   Kimi or worktree actions.

### Phase 5: verify and land

9. Update the STEP 0 header, help, shared Kimi skill, `AGENTS.md`,
   `docs/codex-skills-usage-guide.md`, `docs/skills-map.md`, and this plan. Explain
   persistent conversation plus disposable workspace, immutable base, cumulative patch,
   continuation, failure recovery, deletion, and missing usage metrics. Reinstall and
   hash-compare source, Claude, and Codex skills.

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
- `canonical_generation_advances_only_after_atomic_patch_and_metadata_success`
- `concurrent_same_name_creates_one_worktree_and_one_provider_turn`
- `mode_collision_between_review_and_implementation_fails_before_turn`
- `failed_partial_turn_preserves_code_and_truthful_continuity_state`
- `failed_no_change_does_not_advance_patch_generation`
- `timeout_and_cancel_follow_measured_resume_policy`
- `explicit_context_reset_is_never_silent`
- `delete_refuses_active_and_removes_only_validated_session_state`
- `transcript_exports_exact_implementation_session`
- `doctor_cleans_stale_worktree_but_keeps_persistent_artifacts`
- `legacy_one_shot_record_migrates_only_from_unique_verified_evidence`
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
- Cover Windows long paths, binary and untracked files, moved checkouts, and callers.
- Store no prompts, responses, credentials, or secret-bearing logs in metadata.
- No band-aids, silent fallback, guessed migration, or automatic patch application.

## 12. Access and environment

- Repo: `C:\repos\ai-devops`, `main`, remote
  `https://github.com/u2giants/ai-devops`.
- Windows 11 host `AL8960OFC`; PowerShell 7 plus Git Bash.
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
the real repo may diverge from the immutable base; atomic patch/metadata writes may fail;
and durable state may accumulate. Phase 1 measures transport facts, explicit context
reset handles unresumable failures, immutable-base conflicts remain visible, generations
and hashes prove atomic truth, and safe delete manages accumulation.

Rollback is a normal Git revert. Existing records must remain readable or receive exact
archive guidance. Never roll back by applying hidden work or deleting ambiguous state.

Open questions are only the Phase 1 measurements: exact-ID behavior in a different
worktree and resumability after each failure class. Decide by pinned CLI evidence, never
convenience.

## Mandatory self-audit

1. **Yes.** Sections 1-5 define outcome, toolkit, reproduction, scope, files, commit, and
   exact current behavior. Sections 9-10 give ordered function-level work and gates.
2. **Yes.** Sections 6-8 preserve root cause, conversation-plus-code requirement,
   rejected designs, locked safety rules, and measurement questions. Sections 11-13
   preserve platform traps, access, risks, rollback, and landing.
3. **Yes.** Section 1 makes exact multi-turn understanding without lost isolation or
   truth the deciding goal. Sections 4 and 8 bound all judgment calls.

All 13 sections are present, with exclusions, files, named tests, gates, locked/open
decisions, secret-safe access, commit/push proof, and bidirectional handoff registration.
A fresh session needs no chat context. Self-audit passed on 2026-08-10.
