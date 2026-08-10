# Plan: preserve incomplete Kimi implementation work safely

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Freeze the failure with offline tests | ⬜ open | N/A | N/A |
| 2. Add truthful failure classification and incomplete artifact export | ⬜ open | N/A | N/A |
| 3. Make cleanup and reporting safe on every exit path | ⬜ open | N/A | N/A |
| 4. Verify live behavior, update docs, commit, and push | ⬜ open | N/A | N/A |

Fresh sessions start at the first open row. Update this table after every gate. This
plan is complete only when no row remains open and the evidence is dated.

## 1. The ultimate goal

When Kimi makes useful code changes but cannot finish because of a usage limit,
network failure, provider interruption, timeout, or user stop, Albert must receive a
clearly marked incomplete patch for inspection instead of losing all of that work.
The real repository must remain untouched, incomplete work must never be applied
automatically, and ordinary successful runs must behave exactly as they do today.

If any step below conflicts with this goal, the goal wins. Stop and flag the conflict.

## 2. What this application is

`u2giants/ai-devops` is a public, text-only backup and restore toolkit for Albert
Hazan's multi-model AI coding workflow. It installs Bash and PowerShell helpers used
by Claude and Codex. It is not a hosted service and has no database or deployment.

The target command is `bin/ai-kimi`, the only supported headless Kimi Code wrapper.
It provides named, persistent, read-only review sessions and one-shot implementation
runs. Implementation runs use a disposable Git worktree and return a patch under the
calling repository's ignored `.ai/reviews/` directory. The repository is
`C:\repos\ai-devops` on Windows machine `916-alien`, uses branch `main`, and pushes
to `https://github.com/u2giants/ai-devops`.

Relevant files:

- `bin/ai-kimi`: wrapper, lifecycle, completion check, worktree cleanup, patch export.
- `config/kimi/local-implement.md`: Kimi's implementation agent profile.
- `config/kimi/readonly-review.md`: structural read-only review profile. Do not weaken.
- `tests/test-ai-kimi.sh`: dependency-free offline tests plus opt-in live tests.
- `skills/shared/kimi-code-delegation/SKILL.md`: instructions installed for Claude
  and Codex.
- `AGENTS.md`: repository router and hard-won Kimi constraints.

## 3. What triggered this work

On 2026-08-10, a Kimi implementation run started correctly in a disposable worktree
and changed more than 15 files. It then returned `Usage limit reached for this billing
cycle` before emitting Kimi's required terminal `session.resume_hint` record.

`bin/ai-kimi:start_session` treated the turn as incomplete and exited nonzero. Its
EXIT trap then removed the worktree. Because patch export currently happens only after
the terminal completion record, none of the partial changes survived. The real
application repository remained safe and unchanged, but paid, potentially useful work
was lost.

Offline reproduction must use the existing stub Kimi binary in
`tests/test-ai-kimi.sh`: make the stub edit a file, emit a provider-error fixture
without a terminal record, and exit. The current wrapper should return nonzero, remove
the worktree, and produce no patch. That failing test freezes the defect before code
changes begin.

## 4. Scope

In this plan:

- Preserve changed files as an explicitly incomplete binary Git patch on failed or
  interrupted implementation runs.
- Classify the final state truthfully: completed, failed with partial changes, failed
  before changes, cancelled, timed out, or usage limit reached.
- Write a small incomplete report with safe evidence and recovery instructions.
- Keep cleanup deterministic and preserve the worktree only if safe artifact export
  itself fails.
- Add offline regression tests and one bounded live failure probe that does not spend
  a full implementation budget.
- Update the Kimi skill and repository documentation.

Not in this plan:

- Resuming an implementation session or keeping ordinary failed worktrees for later.
- Applying any complete or incomplete patch automatically.
- Changing Kimi's model pin, authentication, prompt transport, or session continuity.
- Adding invented token, cost, cache, context-size, or returned-model figures. Kimi
  headless output does not provide them.
- Weakening the exact `session.resume_hint` completion rule.
- Changing GLM, Grok, Codex, application repositories, cloud systems, or production.
- Adding a general live-progress dashboard. The wrapper may print final state and
  current elapsed-time messages only.

## 5. Current state of the code

What works now:

- `bin/ai-kimi:232-265` requires a terminal `session.resume_hint`; exit status alone
  never proves success.
- `bin/ai-kimi:480-506` creates an implementation worktree and owner record under
  `AI_KIMI_STATE_DIR`.
- `bin/ai-kimi:487-491` holds one per-repository lock, preventing concurrent Kimi runs
  in the same repository.
- `bin/ai-kimi:547-558` removes wrapper-owned worktrees and leaves ambiguous or
  explicitly preserved recovery state alone.
- `bin/ai-kimi:560-585` exports successful work as a binary patch and preserves the
  worktree if patch export cannot be made durable.
- `tests/test-ai-kimi.sh` proves structural read-only reviews, exact session resume,
  strict completion, successful patch export, cleanup, interruption cleanup, and locks.

What is broken:

- `bin/ai-kimi:515-520` exits immediately when `await_result` fails.
- `bin/ai-kimi:533-535` calls `emit_patch` only after proven completion, so the EXIT
  trap deletes all partial work on every incomplete turn.
- There is no durable failure report, no incomplete filename, and no distinction
  between failure before changes and failure after useful changes.
- The current interruption test asserts cleanup only; it does not assert preservation
  of changed work.

No source change for this fix existed when this plan was written. Unrelated untracked
files already exist in the checkout and must not be staged. This toolkit has no deploy
step or CI workflow; local tests plus pushed Git state are the landing evidence.

## 6. Key findings and root cause

1. The safety boundary worked. The real repository stayed unchanged because Kimi wrote
   only in a disposable worktree.
2. The completion rule worked. A billing error is not a successful implementation and
   must never produce a trusted complete patch.
3. The data-loss bug is lifecycle ordering. Failure exits at `bin/ai-kimi:517-520`,
   successful patch export begins at `bin/ai-kimi:533-535`, and cleanup always runs at
   `bin/ai-kimi:511`.
4. `emit_patch` already contains the hard part of safe artifact storage: binary diff,
   ignored `.ai/reviews/` preference, private state-directory fallback, atomic temp-file
   move, and preserved recovery state when export fails. Refactor and reuse this logic;
   do not create a second weaker exporter.
5. Kimi's output cannot support honest token, cache, context-size, cost, or actual-model
   claims. Failure reports must omit those values or say `unavailable`.
6. A partial patch can be useful but is never proof that the task is correct, complete,
   tested, or safe. Its filename and report must make that impossible to miss.
7. A Kimi session ID may be unavailable on a failed turn because the only proven ID
   source is the terminal resume hint. Record `unavailable`, not an empty or guessed ID.

## 7. Approaches considered and rejected

1. **Keep every failed worktree. Rejected.** This creates stale registered worktrees,
   name and disk clutter, uncertain ownership, and manual cleanup. A durable patch gives
   the useful recovery value without making temporary state permanent.
2. **Make implementation sessions resumable. Rejected.** The isolated worktree is
   deliberately one-shot. Resuming after it is removed would place the old conversation
   in a different filesystem state and could make Kimi believe unfinished edits still
   exist. `ai-kimi ask` must continue refusing implementation sessions.
3. **Treat a partial patch as success. Rejected.** Billing, timeout, cancellation, or
   provider failure means completion and test claims are unknown. The command must stay
   nonzero and the artifact must say `INCOMPLETE`.
4. **Trust Kimi's process exit status. Rejected.** Kimi can exit zero without the
   terminal record. The existing completion rule guards a measured failure and stays.
5. **Parse one exact English billing message as the only failure path. Rejected.** The
   message is useful for a specific `usage-limit` label, but any failed implementation
   that changed files deserves an incomplete artifact. Unknown provider text must use a
   generic safe state.
6. **Run Git commands directly inside an INT or TERM trap. Rejected.** Signal handling
   can interrupt commands at unsafe points. The signal trap should record the intended
   terminal state and exit; one idempotent EXIT finalizer should own export and cleanup.
7. **Put the failed work directly into the real checkout. Rejected.** That destroys the
   wrapper's isolation and makes an unfinished model run look like user work.
8. **Copy `node_modules` or other dependency trees into recovery artifacts. Rejected.**
   The patch exporter uses Git state and repository ignore rules; build output is not a
   source artifact.

## 8. Design decisions already made

Decisions dated 2026-08-10:

- **LOCKED:** Reviews remain structurally read-only through the exact case-sensitive
  Kimi agent tool names. No prompt-only substitute is acceptable.
- **LOCKED:** Successful completion still requires a terminal `session.resume_hint`.
- **LOCKED:** Implementation remains one-shot and isolated in a disposable worktree.
- **LOCKED:** The real repository is never changed and patches are never auto-applied.
- **LOCKED:** Failed runs return nonzero even when an incomplete patch is preserved.
- **LOCKED:** Partial artifacts use `.incomplete.patch` and an adjacent
  `.incomplete.md` report. Both visibly state `INCOMPLETE`.
- **LOCKED:** Export failure preserves the exact worktree using the existing
  `preserved-recovery` owner state and prints an exact recovery path.
- **LOCKED:** Unknown usage values are `unavailable`; zero is used only if Kimi one day
  supplies an official, final zero.
- **OPEN:** Exact helper and local variable names may change if the lifecycle stays
  single-owner and the tests prove every exit path.
- **OPEN:** Known failure-message matching may include additional measured Kimi strings,
  but it must be narrow, case-insensitive, tested, and fall back to `failed`.

## 9. The plan

### Phase 1: freeze the defect

1. Extend the stub in `tests/test-ai-kimi.sh` with modes for `usagepartial`,
   `networkpartial`, `failednochange`, `timeoutpartial`, and `interruptpartial`.
   Each partial mode must create one small tracked or untracked source file inside the
   disposable worktree, then end without `session.resume_hint`. The usage fixture must
   include the measured billing message. Add assertions that describe the desired
   behavior before changing `bin/ai-kimi`.

   Dependency: none.

   You'll know it worked when the new tests fail on current code specifically because
   no `.incomplete.patch` and report survive, while all old tests still reach their
   existing assertions.

### Phase 2: implement one truthful lifecycle

2. Refactor `bin/ai-kimi:start_session`, `cleanup_wt`, and `emit_patch` into a single
   implementation lifecycle with explicit state variables for mode, terminal state,
   worktree, owner file, base SHA, output files, and whether an artifact is already
   durable. Install one idempotent EXIT finalizer only after those exact paths exist.
   INT and TERM handlers may set `cancelled` and exit 130; they must not independently
   export or delete.

   The finalizer must:

   - do nothing special for reviews;
   - export the normal complete patch only after proven completion;
   - on incomplete implementation, check whether Git sees source changes relative to
     the captured base;
   - export an incomplete patch and report when changes exist;
   - report `failed before changes` and create no empty patch when none exist;
   - remove the worktree after a durable artifact or no-change result;
   - preserve `preserved-recovery` only if artifact export fails;
   - release locks and remove prompt/output temp files exactly once.

   Dependency: step 1.

   You'll know it worked when every stubbed failure returns nonzero, the real repo is
   unchanged, changed work survives as a patch, no-change failures leave no patch, and
   no ordinary worktree or owner record remains.

3. Add narrow helpers in `bin/ai-kimi` to classify the final state from facts already
   held by the wrapper. Use `usage-limit` only for measured usage or billing-limit text,
   `timed-out` only when `await_result` reached its configured deadline, `cancelled` only
   for INT/TERM, and `failed` for everything else. Never put the full provider error,
   prompt, environment, or secrets into metadata. Sanitize report detail to a short
   bounded message.

   The incomplete report must contain: literal `INCOMPLETE`; job name; repository;
   base SHA; requested model pin with the warning that returned model is unavailable;
   terminal state; command exit status if known; Kimi session ID or `unavailable`;
   changed-file summary; `tests: not confirmed complete`; patch path; and instructions
   to inspect with `git apply --stat`, verify with `git apply --check`, and never apply
   without review. It must not claim token, cache, cost, or context figures.

   Dependency: step 2.

   You'll know it worked when snapshot assertions in `tests/test-ai-kimi.sh` prove each
   field, secrets and prompts are absent, filenames end in `.incomplete.patch` and
   `.incomplete.md`, and stderr clearly distinguishes all terminal states.

### Phase 3: harden and document

4. Add failure-injection tests for artifact destination failure, atomic move failure,
   a forged or ambiguous owner path, repeated finalizer invocation, and cancellation
   during a run that has already edited files. Preserve the existing successful binary
   patch and structural read-only tests unchanged in meaning.

   Dependency: steps 2-3.

   You'll know it worked when export failures retain only the exact wrapper-owned
   worktree as `preserved-recovery`, `doctor` names it without deleting it, and all
   controlled exits leave no unexplained worktree, owner record, temp file, or lock.

5. Update `skills/shared/kimi-code-delegation/SKILL.md`, the Kimi row in `AGENTS.md`,
   and any directly conflicting Kimi wording in `docs/codex-skills-usage-guide.md` and
   `docs/skills-map.md`. Explain complete versus incomplete patches, nonzero failure,
   review-before-apply, no resume for implementation, and unavailable usage figures.
   Keep this plan's STATUS and current-state sections accurate as each step lands.

   Dependency: steps 2-4.

   You'll know it worked when repository search finds no claim that failed Kimi work is
   always deleted or that every emitted patch is complete, and installed-skill tests
   still identify the shared skill correctly.

Natural context cut: if Phase 1-2 consumes most of a session, update STATUS and the
implementing session's own `HANDOFF.d/` file. Start a fresh context before Phase 3 and
re-read this entire plan, especially sections 6-8, before continuing.

### Phase 4: verify and land

6. Run `bash tests/test-ai-kimi.sh` from the repo root. Then run the wider relevant Bash
and Windows script tests named by `docs/development.md`. Perform one bounded live probe
only if Kimi authentication is already available: instruct Kimi to make a harmless file
then stop the wrapper, and verify an incomplete patch survives without touching the real
repo. Do not intentionally consume the account to reproduce a billing limit.

   Dependency: steps 1-5.

   You'll know it worked when offline tests pass, the live cancellation probe returns
   nonzero with an incomplete patch, `git apply --check` accepts that patch against the
   captured base, and no disposable worktree remains.

7. Inspect the final diff for secrets and unrelated files. Verify author and committer
   with `git var GIT_COMMITTER_IDENT`; it must show
   `Albert Hazan <u2giants@users.noreply.github.com>`. Stage only this work, commit on
   `main`, push `origin main`, and verify local `HEAD` equals `origin/main`. Update or
   delete this plan only when every gate is proven. Create the implementing session's
   own write-once `HANDOFF.d/<UTC>-machine-agent-kimi-incomplete-recovery.md` while work
   is open; delete only that file when the work is proven complete.

   Dependency: step 6.

   You'll know it worked when the worktree contains no mystery files from this task,
   the commit uses Albert's identity, the push succeeds, local and remote SHAs match,
   and every STATUS row has dated evidence.

## 10. Tests required

Add or preserve these behaviors in `tests/test-ai-kimi.sh`:

- `usage_limit_with_changes_exports_incomplete_patch_and_returns_nonzero`
- `network_failure_with_changes_exports_generic_incomplete_patch`
- `failure_before_changes_creates_no_empty_patch`
- `timeout_with_changes_exports_incomplete_patch`
- `interrupt_with_changes_exports_incomplete_patch_and_cleans_worktree`
- `incomplete_patch_is_binary_and_applies_to_original_base`
- `incomplete_report_is_bounded_and_contains_no_prompt_or_secret`
- `incomplete_report_uses_unavailable_for_missing_session_and_usage`
- `complete_run_keeps_normal_patch_name_and_success_behavior`
- `failed_run_never_writes_real_repository`
- `artifact_export_failure_preserves_exact_recovery_worktree`
- `repeated_finalizer_is_idempotent`
- `forged_or_ambiguous_owner_path_is_never_deleted`
- Existing `await_requires_resume_hint` remains unchanged in meaning.
- Existing live structural read-only canary remains unchanged in meaning.

Required commands are `bash -n bin/ai-kimi`, `bash tests/test-ai-kimi.sh`, and the
relevant suite listed in `docs/development.md`. Live tests run only through the existing
opt-in environment flag and must be bounded.

## 11. Constraints and gotchas

- Main-only repository. Preserve concurrent work and stage only owned files.
- Before the first commit, verify Albert's exact author and committer identity.
- Do not weaken structural read-only profiles or case-sensitive Kimi tool names.
- Never replace `session.resume_hint` with process exit status as proof of completion.
- Kimi has no `--max-turns` and no trustworthy token, cost, cache, context, or returned
  model data. Never invent or infer figures.
- Do not add arbitrary CLI flag passthrough such as `--yolo`, `--auto`, or `--continue`.
- Implementation credentials are per-user. Do not silently run write work as another
  account and create wrongly owned files.
- Git Bash must remain supported. Do not use `flock` or Linux-only process behavior.
- File writes for metadata and artifacts must be atomic where the current wrapper makes
  them atomic. Diagnostics must be bounded and secret-safe.
- Do not traverse network drives or mutate production/shared cloud resources.
- Unit tests are required for created behavior. No band-aids and no silent fallback.

## 12. Access and environment

- Local repo: `C:\repos\ai-devops` on Windows 11 machine `916-alien`.
- Remote: `https://github.com/u2giants/ai-devops`, branch `main`.
- Shell: PowerShell 7 for orchestration and Git Bash for Bash tests.
- Expected tools: Git, Bash, `jq`, Kimi Code 0.32.0, and authenticated `gh` for remote
  verification. Confirm each with a real call before claiming it is unavailable.
- Kimi OAuth is per-user under `~/.kimi-code`; never print or copy its credentials.
- Other secrets, if needed for machine setup only, live in 1Password account
  `popcreations.1password.com`, vault `vibe_coding`. This change should need no secret.
- No application URL, server, database, CI workflow, or deploy environment applies.

## 13. Definition of done, risks, and open questions

Done means:

- Every STATUS row is complete with dated evidence.
- Failed Kimi implementations with changes always leave a clearly incomplete patch and
  report, while failures before changes leave no empty patch.
- Complete patches remain distinct and behavior-compatible.
- All failures remain nonzero and nothing is applied automatically.
- The real repository stays unchanged during delegated implementation.
- Successful export removes the disposable worktree; export failure preserves only the
  exact wrapper-owned recovery worktree and explains recovery.
- Offline and bounded live verification pass.
- Docs and shared skill match the implementation.
- No prompt, secret, provider credential, or invented usage figure enters artifacts.
- Changes are committed and pushed to `origin/main` using Albert's identity, and local
  `HEAD` equals `origin/main`. CI and deploy are N/A because this repo has neither.

Risks and decisions:

- Signal timing can race Kimi file writes. The EXIT finalizer must record what Git can
  prove after the child stops and must never label the work complete.
- Provider wording can change. Unknown failures remain safely generic; only measured
  narrow strings receive special labels.
- Patch export can fail because of disk, permission, or ignore-policy problems. Preserve
  the exact worktree rather than destroy the only copy.
- A partial patch can contain broken or unsafe code. The filename, report, nonzero exit,
  and manual review gate are the controls.
- Open question for measured implementation: whether Kimi 0.32.0 emits a usable session
  ID before its terminal hint on failure. If not proven by an official record, use
  `unavailable`; never scrape logs or guess.

Rollback is a normal Git revert of the wrapper, tests, skill, and docs commit. Reverting
restores today's safe but lossy behavior. Never roll back by weakening isolation or
copying an incomplete patch into a real checkout.

## Mandatory self-audit

1. **Yes.** Sections 1-5 define the business outcome, toolkit, exact incident,
   boundaries, current behavior, files, branch, and environment. Sections 9-10 give
   ordered file- and function-specific work with a verification gate for every step.
2. **Yes.** Sections 6-8 preserve the root cause, safety findings, rejected resumable
   worktrees and exit-status shortcuts, and every locked versus open decision. Sections
   11-13 preserve platform traps, access, landing rules, risks, rollback, and the one
   measurement still open.
3. **Yes.** Section 1 makes preservation without false success the deciding goal and
   explicitly says the goal wins over a conflicting step. Sections 4 and 8 define the
   safety boundaries an implementer must use for any judgment call.

All 13 required sections are present. The plan has an explicit out-of-scope list,
concrete tests, per-step verification, secret-safe access notes, commit/push evidence,
and no assumption that the implementing session can read this chat. Self-audit passed
on 2026-08-10.
