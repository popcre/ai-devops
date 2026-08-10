# Plan: make GLM implementation jobs visible, exclusive, abortable, and recoverable

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Reproduce and freeze the failure | ⬜ open | N/A | N/A |
| 2. Add one-shot implementation job records | ⬜ open | N/A | N/A |
| 3. Lock implementation names for the full run | ⬜ open | N/A | N/A |
| 4. Add list, show, abort, delete, and safe reconciliation | ⬜ open | N/A | N/A |
| 5. Verify, document, commit, and push | ⬜ open | N/A | N/A |

Fresh sessions start at the first open row. Before editing, pull `origin/main`, inspect
concurrent work, list `HANDOFF.d/`, and read every open handoff newest-first. Update this
table after every gate. The implementing session must create its own write-once
`HANDOFF.d/<UTC>-<machine>-<agent>-glm-implementation-job-tracking.md` and link it here.

## 1. The ultimate goal

Albert must be able to start a GLM implementation once, see that it is running, stop it
by name, and retry safely. A missing entry in `ai-glm list` must never trick an AI
session into starting a duplicate implementation job.

Done means each active implementation name has exactly one wrapper-owned record, one
lock, at most one OpenCode session, and one remote-less clone. Completion exports one
patch and removes disposable resources. Failure or abort leaves a truthful final record
and no unexplained live job.

If a step conflicts with this goal, the goal wins. Stop and flag the conflict rather
than hiding a job, weakening isolation, or risking the real repository.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for a multi-model AI coding
workflow. It contains Bash, PowerShell, Markdown, and dependency-free tests. It is not a
hosted application and has no application deployment.

The affected command is `bin/ai-glm`. It talks to an authenticated local OpenCode
1.18.12 server running GLM-5.2. Reviews are named, persistent, and read-only.
Implementation is an explicit one-shot write run in a temporary Git clone whose `origin`
remote is removed. GLM edits and tests only in that clone. The wrapper exports a patch
under `.ai/reviews/`, then deletes the clone.

Work is in `C:\repos\ai-devops`, branch `main`. GitHub repository
`u2giants/ai-devops` is the source of truth. Windows uses Scheduled Task
`AiDevOps-OpenCodeGlm` on authenticated loopback port 4096. Ubuntu uses a user service.
The fix must work on both.

## 3. What triggered this work

On 2026-08-10 another Codex session called `ai-glm implement`. The first command did not
immediately return a patch. `ai-glm list` showed no implementation entry, so the session
concluded that no job existed and retried. The retry created a second isolated job while
the first was still active.

The GLM service was healthy. `ai-glm doctor` passed, the scheduled task was running, and
the health endpoint reported OpenCode 1.18.12. This is a wrapper tracking and concurrency
bug, not a provider outage.

Reproduce it offline in `tests/test-ai-glm.sh`: pause the first same-name implementation
after resource creation, run `list`, then start a second same-name call. Prove the current
wrapper hides the first job, cannot abort it by name, and permits the second. Do not start
two paid live turns to reproduce the defect.

## 4. Scope

In scope:

- Durable, private metadata for active and recently finished one-shot implementations.
- A repository-plus-caller-plus-name lock held for the whole implementation lifecycle.
- Truthful implementation output from `list` and `show`.
- Exact name-based `abort` and safe `delete` behavior.
- Conservative reconciliation of dead owners, stale records, clones, and server sessions.
- Offline concurrency, abort, crash, cleanup, and migration tests plus one bounded live
  canary.
- Updates to canonical GLM docs and the shared `ask-glm` skill.

Not in this plan:

- Making implementation jobs resumable or valid targets for `ai-glm ask`.
- Applying a GLM patch automatically to the real repository.
- Writing in the real checkout, pushing to GitHub, or restoring the clone's remote.
- Replacing the remote-less clone with a Git worktree.
- Changing OpenCode 1.18.12, GLM-5.2, provider, port, authentication, or agent tool maps.
- Weakening review safety, the completion rule, or permission checks.
- Calling OpenCode outside `bin/ai-glm`, adding a server, or deleting ambiguous resources.
- Production, shared-cloud, database, credential, Claude-config, or Codex-config changes.

## 5. Current state of the code

Planning state:

- Branch `main`; pre-plan base `fadfe451752e8eebde3376a5a2c10e347023f5f2`.
- Correct identity: `Albert Hazan <u2giants@users.noreply.github.com>`.
- Unrelated untracked paths: `.ai/` and `docs/claude-remote-control-hardening-v2.md`.
  Preserve them and never stage them with this work.
- The open handoff `HANDOFF.d/2026-08-10T1138Z-albt16-codex-916-rollout.md` is unrelated.

What works and must remain:

- `cmd_new` and `cmd_ask` use persistent metadata and locks for review sessions.
- `cmd_implement` clones the exact base, removes `origin`, carries tracked local changes,
  runs GLM, exports a patch, and removes the clone with an EXIT trap.
- Completion requires `finish == "stop"` plus two consecutive idle polls.
- Unsafe, unknown, external, malformed, or ineffective permission requests fail closed.
- A review server session is deleted if its metadata creation fails.

Exact defect:

- `bin/ai-glm:530` starts `cmd_implement` without a metadata path or name lock.
- `bin/ai-glm:549` removes only the clone. It does not own a job record lifecycle.
- `bin/ai-glm:576` creates the OpenCode session, whose ID remains process-local.
- `bin/ai-glm:599` lists only JSON under `$STATE_DIR/sessions`; implementations write none.
- `bin/ai-glm:632` aborts through `find_meta`, so it cannot target an unrecorded job.
- `bin/ai-glm:909` finds scratch directories, but a directory alone cannot prove owner,
  liveness, server state, or whether deletion is safe.
- `plan_delegate-wrapper-hardening.md` intentionally accepted invisible implementation
  jobs. That completed plan is historical. This plan corrects that disproven decision.

## 6. Key findings and root cause

1. Reviews and implementations use different lifecycle models. Reviews record and lock
   identity before work. Implementations keep identity only in local Bash variables.
2. `ai-glm list` is a metadata list, not a complete view of server activity. An absent
   implementation entry proves nothing about whether a job is alive.
3. A terminal tool may return a host-side command session ID while Bash continues. That
   ID is not an `ai-glm` named record and is not proof of GLM failure.
4. Documentation alone cannot prevent duplicates. Mutual exclusion must happen before
   clone creation, server-session creation, or a paid provider turn.
5. Safe abort has two actors. The control call requests abort for the exact OpenCode
   session. The original job process records the result and cleans its exact clone. A
   second process must not delete a clone that may still be active.
6. Metadata does not make implementation resumable. `ask` must still reject it.
7. Existing old scratch directories prove cleanup evidence is incomplete, but do not
   prove ownership. Legacy directories must default to warning, not deletion.

## 7. Approaches considered and rejected

1. Keep jobs invisible and tell agents to wait. Rejected because duplicates remain
   possible and the same mistake will recur.
2. Make `list` query only raw server status. Rejected because server sessions lack the
   wrapper's repository, caller, lock, clone ownership, and cleanup state.
3. Reuse the review schema without a distinct type. Rejected because that falsely implies
   implementation can continue with `ask`.
4. Lock only creation. Rejected because a retry could begin after creation while the
   first paid turn still runs. Hold the lock for the whole lifecycle.
5. Let `abort` immediately delete the clone. Rejected because the owner may still be
   writing, testing, or exporting. Abort the server turn; let the owner clean up.
6. Kill the owner PID normally. Rejected because PID reuse and abrupt termination can
   corrupt state. PID is only one stale-owner check.
7. Delete everything below `$STATE_DIR/wt`. Rejected because active, foreign, or ambiguous
   work could be destroyed.
8. Make implementation a persistent conversation. Rejected because its clone disappears,
   so later turns would refer to files that no longer exist.
9. Use a Git worktree. Rejected because it shares the real repository's remotes; the
   remote-less clone is the push-safety boundary.
10. Treat missing patch output as proof no job started. Rejected because patch export
    occurs only after terminal GLM completion.

## 8. Design decisions

Locked on 2026-08-10:

- Implementation stays explicit, one-shot, disposable, and remote-less.
- Record the job before clone creation and keep it visible through a terminal state.
- Lock by repository ID, caller, and name for the full run.
- Use explicit `type:"implementation"`; `ask` rejects that type.
- Metadata contains no prompt, response, token, secret, or credential.
- Normal `abort <name>` calls the exact recorded server session and never deletes a live
  clone from the control process.
- Cleanup fails closed. Preserve and report ambiguous state.
- Review controls, model/provider pins, permission handling, and completion stay unchanged.
- Do not rewrite the completed earlier plan. This plan owns the correction.

Open choices, bounded by tests:

- Prefer the existing sessions directory if type-aware lookup stays simple. A separate
  jobs directory is acceptable only if it prevents duplicated lookup and migration logic.
- Use a small state set such as `starting`, `running`, `abort-requested`, `completed`,
  `failed`, and `aborted`. Exact names may vary, but transitions must be atomic and tested.
- Keep terminal evidence long enough to explain the last result and patch/report paths.
  Choose explicit deletion or a conservative retention rule that does not block names
  forever and never silently erases the only failure evidence.
- If completion races abort, record the observed terminal truth. Do not relabel a valid
  completed patch merely because an abort was requested.

## 9. Ordered implementation plan

### Phase A: freeze the defect and add identity

1. Pull `origin/main`; read this STATUS table and open handoffs; record the exact base and
   unrelated files. Run `bash -n bin/ai-glm`, `bash tests/test-ai-glm.sh`,
   `bash tests/test-windows-scripts.sh`, and `ai-glm doctor`. Add the controlled offline
   duplicate fixture described in section 3. **You'll know it worked when:** the new test
   fails on current code because the first job is invisible and abortless and the second
   creates another resource, while existing baseline tests stay green.

2. In `bin/ai-glm`, add versioned implementation metadata using existing atomic writing,
   repository identity, caller separation, and private-file rules. Write the initial
   record before clone creation with name, type, repository, caller, base SHA, owner PID,
   timestamps, and state. Add canonical clone path and server session ID only after each
   exists. Test allowed transitions and malformed-record refusal. **You'll know it worked
   when:** a paused job is visible before expensive work, resources appear atomically,
   metadata is private and secret-free, and malformed/out-of-root paths fail closed.

3. Acquire the repository/caller/name lock at the start of `cmd_implement` and hold it
   through terminal state and cleanup. Active same-name records return their current
   state without creating anything. Terminal same-name records give the exact safe reuse
   action. Different names and repositories remain independent. **You'll know it worked
   when:** two same-name calls create exactly one clone, one server session, and one turn;
   the loser exits before resource creation; different names still run in parallel.

Natural context cut: update STATUS and the implementing handoff. A fresh session must
re-read sections 5-10 before Phase B.

### Phase B: control, terminal state, and cleanup

4. Extend `cmd_list`, `cmd_show`, `find_meta`, `cmd_abort`, and `cmd_delete` for both record
   types. List type, state, caller, repository, and useful age. Show only safe metadata.
   Reject `ask` for implementation. Abort must mark `abort-requested`, call the exact
   authenticated server abort, and leave clone cleanup to the owner. Delete must refuse
   an active job. **You'll know it worked when:** another shell can list, show, and abort
   the exact paused fixture; `ask` cannot resume it; and a different caller/repo is safe.

5. Refactor `cmd_implement` so one idempotent lifecycle cleanup path owns prompt temp
   files, the exact clone, server-session disposition, metadata state, and lock. Cover
   normal/no-change completion, provider or permission failure, signal, metadata failure,
   patch failure, abort, and shell-crash recovery. Export a patch only after proven
   completion. Record patch/report paths only after successful writes. Doctor may
   reconcile a dead owner only after validating record schema, canonical roots, dead PID,
   lock state, and exact server state. Preserve ambiguity. **You'll know it worked when:**
   all controlled exits leave no unexplained live clone/session, retain a truthful final
   record, never delete live/foreign/forged paths, and abort cannot emit false success.

### Phase C: document, verify, and ship

6. Update `docs/glm-opencode.md`, `docs/development.md`,
   `skills/shared/ask-glm/SKILL.md`, `AGENTS.md`, and this plan. Remove the invisible-job
   claim. Explain one-shot records, locking, commands, retention, and why missing patch
   output does not prove termination. Run the GLM and Windows suites, Bash syntax,
   `git diff --check`, Windows ASCII checks, and `ai-glm doctor`. Then run one harmless,
   bounded live canary proving list visibility, duplicate rejection before a second
   session, exact abort, terminal state, and cleanup. Install the shared skill and compare
   repo/Claude/Codex hashes. Update STATUS and only the implementing session's handoff.
   Verify identity, stage only this work, commit `main`, push, fetch, and compare SHAs.
   CI and deployment are N/A. **You'll know it worked when:** offline and live evidence
   proves visibility, exclusivity, exact abort, and cleanup; `HEAD == origin/main`; and no
   STATUS row is open.

## 10. Tests required

Add named behavior coverage in `tests/test-ai-glm.sh`:

- `implement_record_exists_before_clone_creation`
- `implement_record_adds_clone_and_session_atomically`
- `implement_record_is_private_and_contains_no_prompt_or_secret`
- `implement_list_and_show_are_type_and_state_aware`
- `implement_ask_is_rejected_as_one_shot`
- `concurrent_same_name_implement_creates_one_job_and_session`
- `different_implementation_names_run_independently`
- `abort_targets_exact_active_implementation_session`
- `abort_never_deletes_live_clone_from_control_process`
- `delete_refuses_active_implementation_job`
- `abort_completion_race_records_observed_truth`
- `normal_and_no_change_completion_clean_resources`
- `provider_and_permission_failures_record_failure_and_clean`
- `interrupt_records_terminal_state_and_cleans`
- `metadata_failure_cleans_new_server_session`
- `patch_failure_preserves_recovery_evidence`
- `dead_owner_reconciliation_requires_all_safety_checks`
- `live_owner_and_forged_or_outside_paths_are_never_swept`
- `ambiguous_server_state_is_reported_not_deleted`
- `terminal_record_can_be_cleared_for_safe_name_reuse`
- Existing review locks, exact continuity, permissions, model validation, completion
  polling, caller separation, and Windows service tests remain green.

Live canary:

- Use `AI_GLM_CALLER=codex` and only `ai-glm` in a harmless temporary Git repo.
- Use a unique name `implementation-job-tracking-live-<UTC>`.
- Prove visibility, duplicate rejection, exact abort, terminal state, no clone, and no
  unexplained server session. Delete the test record only after saving secret-free proof.
- Never call OpenCode or its API by hand.

## 11. Constraints, standing rules, and gotchas

- Main only. Pull before editing/pushing. Preserve concurrent work.
- Before committing, identity must be Albert's noreply Git identity.
- Never stage `.ai/`, the unrelated remote-control doc, transcripts, credentials, or
  another session's handoff.
- Use only `ai-glm`; never run OpenCode or curl its API directly.
- Keep the remote-less clone, review tool map, strict completion rule, and fail-closed
  permission handling.
- Do not edit `bin/ai-glm` while a copy is running. Its installed command is a symlink to
  the main checkout.
- Cross-platform locking must remain atomic-directory based; Git Bash has no `flock`.
- Do not hard-code paths, users, or machine-specific values.
- Never store prompts, responses, tokens, or secrets in metadata.
- Serialize 1Password reads. No secret read or rotation is needed.
- No band-aids or silent deletion. Ambiguous cleanup remains visible.
- Windows PowerShell stays ASCII; GPT-5.6 effort stays low or medium.
- No production, shared-cloud, database, or deployment mutation is needed.

## 12. Access and environment

- Repo: `C:\repos\ai-devops`; GitHub `u2giants/ai-devops`; branch `main`.
- Planning host: Windows 11 `AL8960OFC`, user `ahazan2`, PowerShell 7 and Git Bash.
- GLM: `ai-glm`; authenticated `127.0.0.1:4096`; OpenCode 1.18.12; provider
  `zai-coding-plan`; model `glm-5.2`; task `AiDevOps-OpenCodeGlm`.
- Credentials live in 1Password account `popcreations.1password.com`, vault
  `vibe_coding`, item `GLM z.ai API`. Never retrieve the value for this work.
- Source: `bin/ai-glm`; tests: `tests/test-ai-glm.sh`, `tests/test-windows-scripts.sh`.
- Docs: `docs/glm-opencode.md`, `docs/development.md`, `skills/shared/ask-glm/SKILL.md`,
  `AGENTS.md`, and historical `plan_delegate-wrapper-hardening.md`.
- There is no app URL, login, database, CI service, deploy target, or production host.

## 13. Definition of done, risks, rollback, and open questions

Done means all STATUS rows have dated evidence; active jobs are visible before resource
creation; duplicates cannot create a second clone/session/turn; list/show/abort/delete
are truthful; `ask` rejects implementation; every exit cleans safely and records truth;
offline tests, live canary, and doctor pass; docs and installed skills match; the
implementing handoff is current; and local `HEAD` equals pushed `origin/main`. CI and
deployment are N/A.

Risks and controls:

- Abort may race completion. Record observed terminal truth and preserve a valid patch.
- PID reuse means PID alone never authorizes cleanup. Require record, canonical paths,
  repository, lock, and server evidence.
- Metadata failure can orphan a session. Record before creation and delete any later
  session when metadata update fails.
- Terminal records can block names. Provide explicit safe clearing or conservative
  retention, never silent overwrite.
- Old unrecorded sandboxes predate ownership metadata. Warn; do not auto-delete them.
- Concurrent edits can change the symlinked running script. Never edit during a live run.

Rollback is a focused Git revert plus shared-skill reinstall. Do not delete job metadata
or server sessions during rollback without exact ownership proof. Keep backward reading
of any new record schema for at least one release cycle if rollback could strand it.

Open evidence questions:

- Should terminal records require explicit `delete`, or use a conservative archive rule?
- Does OpenCode expose a stable difference between user abort and other cancellation?
- Can the exact disposable server session always be deleted after abort? If not, retain
  its ID and give a safe recovery command.
- Can legacy scratch ownership ever be proven? Default to warning only.

## Mandatory self-audit

1. **Could a brand-new session execute this without questions? Yes.** Sections 2-6 define
   the toolkit, incident, exact functions, state, and root cause. Sections 8-12 give locked
   rules, files, commands, ordered work, tests, and gates.
2. **Does it carry all current background and rejected reasoning? Yes.** Sections 3, 5,
   6, and 7 preserve the duplicate event, healthy service, invisible metadata, host-side
   session confusion, prior wrong choice, old scratch evidence, and rejected shortcuts.
3. **Is the goal clear enough for judgment when a step is wrong? Yes.** Section 1 makes
   visibility, exclusivity, exact abort, isolation, and truthful cleanup decisive.
   Sections 8 and 13 separate locked choices, risks, rollback, and evidence questions.

All 13 sections are present. The plan has a STATUS table, explicit exclusions, concrete
files and functions, per-step verification, named tests, locked/open decisions, secret
locations without values, commit/push handling, and N/A CI/deployment. A fresh session
does not need this chat. The self-audit passed on 2026-08-10.
