# Plan: harden and align the GLM, Grok, and Kimi delegate wrappers

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Capture baselines and re-check every review claim | ✅ complete | 2026-08-10 | Base `77b4592`; baselines: Kimi 56, GLM 129, Grok 79, Windows 23; doctors confirmed Kimi 0.32.0, Grok 0.2.112, OpenCode 1.18.12. |
| 2. Make Kimi worktree cleanup unconditional | ✅ complete | 2026-08-10 | One exact lifecycle trap plus wrapper-owned records; interrupt test removes worktree and owner record; doctor skips preserved recovery. |
| 3. Make Kimi patch export preserve committed work | ✅ complete | 2026-08-10 | Patch diffs original base with binary support; committed-work fixture applies cleanly; private fallback and preserved-recovery state added. |
| 4. Remove Kimi prompt text from process arguments | ✅ complete | 2026-08-10 | Kimi 0.32.0 help exposes only `-p`; false stdin claim removed and argv visibility plus no-secrets rule documented for direct/delegated paths. |
| 5. Lock GLM session creation and document disposable implementation sessions | ✅ complete | 2026-08-10 | Full create/write sequence locked; failed metadata writes delete the server session; live same-name race returned one success and one already-exists result. |
| 6. Make Windows GLM restart wait for the port safely | ✅ complete | 2026-08-10 | Live restart found and fixed lingering native child; verified OpenCode-only stop, bounded port-free and health waits, one listener, exact-session resume. |
| 7. Measure and correct Grok resumed-cost accounting | ✅ complete | 2026-08-10 | Grok 0.2.112 live costs were $0.0651744 then $0.0109524; per-call semantics confirmed, addition retained, parent-only $1.50 ceiling documented. |
| 8. Align repository identity, cancellation messages, metadata permissions, and transcript output | ✅ complete | 2026-08-10 | Normalized path+origin IDs, legacy/moved lookup, 0600 metadata, distinct cancellation guidance, and private named Kimi ZIP export implemented. |
| 9. Decide and enforce Kimi implementation network policy | ✅ complete | 2026-08-10 | Kimi 0.32.0 profile can edit/test and removes named web/subagent tools, but live Bash `curl` reached example.com. Albert chose to keep implementation mode with this limit documented. |
| 10. Run full offline/live verification, install skills, document, commit, and push | ✅ complete | 2026-08-10 | Final offline: Kimi 65, GLM 131, Grok 79, Windows 25. Live GLM restart/resume/concurrency, Grok cost, and Kimi edit/test/network canaries passed. Shared skill hashes match Claude and Codex. Commit/push evidence recorded in Git history. |

Fresh sessions start at the first open row. Update this table after every completed gate. Before editing, pull `origin/main`, inspect concurrent work, and create one write-once `HANDOFF.d/<UTC>-<machine>-<agent>-delegate-wrapper-hardening.md` file cross-linked to this plan. Never rewrite `HANDOFF.md` or another session's handoff.

STATUS-to-build-step mapping: row 1 owns build step 1; row 2 owns step 2; row 3 owns step 3; row 4 owns step 4; row 5 owns step 5; row 6 owns step 6; row 7 owns step 7; row 8 owns steps 8, 9, 10, and 12; row 9 owns step 11; row 10 owns steps 13-15. Mark a row complete only when every mapped build step passes its gate.

Planning evidence: `.ai/reviews/glm-delegate-integrations-final-review-20260810T145010Z.md`. That report is local and Git-ignored. Its durable findings are copied into this plan so implementation never depends on the `.ai/` file.

Planning handoff: `HANDOFF.d/2026-08-10T1604Z-al8960ofc-codex-delegate-wrapper-hardening.md`. Read it with this plan; it records Kimi's rejected drafts, the final consensus session, and the one conditional owner decision.

## 1. Ultimate goal

Albert must be able to use GLM, Grok, and Kimi without losing work, leaking temporary worktrees, exposing full prompts to other local users, creating duplicate sessions, miscounting Grok cost, or racing a Windows service restart. The three wrappers should follow the same safety rules where their providers allow it, while keeping the controls already proven to work.

When this plan is done, interruptions and errors clean up safely, implementation patches always contain the delegate's work, session creation is serialized, cost guidance uses measured data, messages tell the truth, local metadata is private, and every deliberate provider difference is documented.

If a step conflicts with this goal, the goal wins. Stop and flag the conflict rather than weakening a proven safety control.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for restoring and operating a multi-model coding workflow. It is a collection of Bash and PowerShell commands, shared Claude/Codex skills, tests, and documentation. It is not a hosted application and has no normal CI or deployment service.

The affected commands are:

- `bin/ai-glm`: named GLM-5.2 review sessions through a loopback OpenCode 1.18.12 server, plus disposable implementation clones.
- `bin/ai-grok-review`: named, read-only Grok Build sessions with terminal-result, turn, cache, and cost reporting.
- `bin/ai-kimi`: named, read-only Kimi K3 reviews plus one-shot implementation runs in disposable Git worktrees.

Work is on `main` in `C:\repos\ai-devops`. GitHub repository `u2giants/ai-devops` is the source of truth. Windows runs GLM through Scheduled Task `AiDevOps-OpenCodeGlm` on loopback port 4096. Ubuntu/Hetz runs GLM through a user service. Kimi and Grok are local CLIs wrapped by repo-owned scripts.

## 3. What triggered this work

After the delegate-continuity plans shipped, Codex asked GLM-5.2 for a read-only final review. GLM approved the core safety design but found four concrete defects and seven verification or consistency items. Codex then checked the current files and confirmed that the Windows GLM restart warning is also real.

The defects matter because they can:

- leave hidden Kimi worktrees behind after an interrupt or credential error;
- delete Kimi-authored work when the delegate commits inside its temporary worktree;
- expose the full Kimi prompt in the operating-system process list while a comment falsely claims stdin is used;
- allow two matching `ai-glm new` calls to create two server sessions while keeping only one local record;
- restart GLM before port 4096 is free;
- double-count Grok cost if resumed output is cumulative rather than per-turn.

The review used GLM session `delegate-integrations-final-review`, OpenCode session ID `ses_013eb60f7ffeNqj0ja9QeWKTmK`, model `zai-coding-plan/glm-5.2`, and recorded 132,480 cached input tokens. GLM could read files but could not run commands by design. Therefore every claim must be reproduced with tests before code changes are accepted.

## 4. Scope

In scope:

- Fix every confirmed defect from the GLM review.
- Resolve every V1-V7 review item with code, measurement, or an explicit documented decision.
- Add regression tests for every behavior changed.
- Preserve current read-only controls, provider/model pins, exact-session behavior, bounded turn/restart policies, prompt-cache practices, and one-shot Kimi implementation sessions.
- Update canonical docs and shared skills where user-facing behavior changes.
- Install changed shared skills into Claude and Codex, then verify source and installed hashes match.

Not in this plan:

- Changing GLM, Grok, or Kimi models or providers.
- Upgrading OpenCode, Grok Build, or Kimi Code as part of these fixes.
- Weakening review permissions, enabling network access for reviews, or removing completion markers.
- Replacing the wrapper architecture or merging the three tools into one script.
- Changing production, shared cloud resources, databases, 1Password credentials, Claude configuration, or Codex configuration.
- Reworking the shared debate template unless a test proves a direct defect in it.
- Claiming Kimi token, cache, cost, context-size, or returned-model figures, because Kimi does not provide them.

## 5. Current state of the code

The delegate-continuity implementation is committed and pushed. The last locally verified implementation evidence commit was `24703f0cfeeec372513d12b90cae283d9e774d20`; `origin/main` advanced afterward, so the implementing session must pull and record the new base before editing.

What already works and must remain intact:

- GLM review removes Bash, write, edit, patch, web, and subagent tools through the OpenCode agent `tools:` map. The old permission array is not a safety control.
- GLM implementation runs in a remote-less clone, not a Git worktree.
- Windows GLM unexpected-child recovery is bounded to four total attempts with one-minute delays and 1 MiB log rotation.
- Grok requires terminal JSON with a recognized `stopReason`, pins model/permissions, bounds turns, refuses arbitrary flag forwarding, and uses per-repo locks.
- Kimi review uses the case-sensitive `Read, Grep, Glob, ReadMediaFile` profile, requires `session.resume_hint`, checks the tree before and after, and refuses to resume one-shot implementation sessions.
- All three skills use `templates/delegation/debate-turn.md` for evidence-backed, bounded debate.

Known defects and exact current locations from the GLM review and Codex confirmation:

- `bin/ai-kimi:start_session` installs an EXIT/INT/TERM trap that releases only the repository lock before creating an implementation worktree. `cleanup_wt` is called only on selected explicit paths. Interrupts and the delegated-credential `die` path can leak the worktree.
- `bin/ai-kimi:emit_patch` runs `git add -A` and `git diff --cached` without the original base commit. If Kimi commits, the exported patch can be empty and the worktree is then deleted.
- `bin/ai-kimi:run_turn` builds `-p "$(cat "$pf")"`; the prompt is in argv. The nearby delegated-user comment incorrectly says the prompt crosses on stdin.
- `bin/ai-glm:cmd_new` checks for existing metadata and creates the server session before acquiring any same-name or per-repo lock.
- `bin/ai-glm:cmd_server` on Windows ends the task, sleeps three seconds, and immediately runs it. It does not prove port 4096 is free.
- M5 in this plan is the Codex-confirmed Windows GLM restart race immediately above. The GLM report named only M1-M4; this plan adds M5 so later steps and tests have an unambiguous label.
- `bin/ai-grok-review:cmd_ask` adds each reported `total_cost_usd` to stored total cost without a recorded proof that resumed output is per-turn.
- Grok and Kimi derive repository IDs from the path only, while GLM uses path plus remote.
- Grok handles `cancelled` like a turn-limit result and recommends raising the turn limit.
- The Grok dollar ceiling is guidance in the skill, not a hard wrapper limit.
- Kimi implementation uses the default agent, whose current tool surface may include network and subagent tools.
- GLM disposable implementation sessions are not in local metadata and this is not clearly documented.
- Grok/Kimi metadata writers do not explicitly set file mode 0600.
- Kimi transcript export sends a ZIP-oriented command directly to stdout without a clear destination workflow.

The working tree also contains unrelated `.ai/` review artifacts and `docs/claude-remote-control-hardening-v2.md`. Preserve them and never stage them with this work.

## 6. Key findings and root causes

1. Kimi cleanup is path-based instead of lifecycle-based. The script cleans after known returns, but not through one trap that owns the full temporary-worktree lifetime. Any new early exit can repeat the leak.
2. Kimi patch export compares against the wrong reference. `git diff --cached` compares the index to current HEAD, not to the commit that existed before Kimi began. A delegate commit moves HEAD and makes completed work disappear from the patch.
3. Kimi's command surface accepts prompt text through `-p`; the wrapper currently expands the prompt into argv. The existing comment describes a design that was never implemented.
4. GLM session creation performs a check-then-create sequence without mutual exclusion. Two processes can pass the check before either writes metadata.
5. Windows process termination and TCP socket release are not synchronized by a fixed sleep. The setup script already has the correct proof-based `Wait-PortFree` idea, but the runtime command does not.
6. Grok cost enforcement depends on whether `total_cost_usd` is per-command or cumulative-session data. The existing name and live evidence do not prove which. This must be measured before choosing arithmetic.
7. Provider differences are sometimes necessary, but undocumented differences become future bugs. Repository identity, cancellation handling, metadata permissions, network policy, and disposable-session visibility need one deliberate rule each.

## 7. Approaches considered and rejected

1. Add more explicit cleanup calls to Kimi. Rejected because the next new `die`, signal, or exception can still bypass them. One lifecycle trap must own cleanup.
2. Delete all Kimi worktrees during doctor. Rejected as the primary fix because it treats symptoms and could touch a legitimate active worktree. Doctor may report or safely clean only positively identified stale wrapper-owned worktrees after lifecycle cleanup is fixed.
3. Export Kimi patches only from the working tree. Rejected because it still misses committed changes. Diff against the captured original base commit.
4. Tell Kimi not to commit. Rejected because prompt rules are not a reliable boundary and the implementation agent has Bash.
5. Correct only the Kimi stdin comment. Rejected because the process-list exposure would remain. First inspect current Kimi CLI support for prompt-file or stdin input, then use the safest supported path.
6. Put the prompt in a world-readable temporary file. Rejected. Any prompt file must be created with private permissions, deleted by a trap, and passed only if the installed CLI officially supports it.
7. Use one global lock for all GLM repositories. Rejected because unrelated repositories should not block each other. Lock by repository and session name, matching existing wrapper conventions.
8. Keep `sleep 3` and increase it. Rejected because a larger guess is still a race. Wait for port-free evidence with a bounded timeout and fail loudly.
9. Infer Grok cost semantics from the field name. Rejected. Run one bounded, real two-turn session and compare raw JSON values.
10. Add a hard Grok dollar kill switch before measuring semantics. Rejected because the wrong accounting could stop valid debates or fail to stop expensive ones. Measure first, then choose the smallest reliable control.
11. Force identical implementations across all providers. Rejected because OpenCode, Grok, and Kimi expose different session, prompt, cost, and tool controls. Align safety outcomes, not incompatible command shapes.
12. Enable network for Kimi by default because implementation was explicitly requested. Rejected as an assumption. Decide from the minimum tools needed, current Kimi agent-file support, and a live containment test.
13. Read or edit raw Kimi session files to improve transcript handling. Rejected because those files are sensitive and unsupported. Use the official `kimi export` surface only.

## 8. Design decisions

Locked on 2026-08-10:

- Review sessions remain structurally read-only. Never broaden GLM, Grok, or Kimi review permissions to solve a timeout or missing feature.
- Kimi implementation remains one-shot and isolated. It must never resume in the live repository.
- GLM implementation remains a remote-less clone. Do not replace it with a worktree.
- Grok retains terminal-result validation, fixed permissions, `--no-memory`, per-repo locking, and turn bounds.
- GLM retains OpenCode 1.18.12, GLM-5.2, loopback binding, HTTP authentication, bounded restart attempts, and runtime 1Password injection.
- Kimi retains the pinned request `kimi-code/k3`, exact-session review resume, case-sensitive read-only profile, and no unsupported metric claims.
- Cleanup, cost, and security failures must be loud. No silent fallback or discarded patch is acceptable.
- Existing unrelated files and other sessions' handoffs must not be staged or edited.

Open decisions, resolved only by evidence during implementation:

- Kimi prompt transport: use an official prompt-file or stdin option if current `kimi --help` and a harmless live test prove it; otherwise document argv exposure, restrict briefs from secrets, and add the strongest available process-privacy check. Do not invent a hidden flag.
- Kimi implementation network policy: prefer a dedicated repo-owned implementation agent file with only the tools required to edit and test. Keep network/subagents off unless a measured implementation task proves they are necessary and Albert explicitly accepts the risk.
- Grok cost storage: store either per-turn sum or latest cumulative value based on raw resumed JSON. The test fixture must match measured 0.2.118 behavior.
- Repository identity: use one documented cross-wrapper algorithm if migration can preserve or safely discover existing session records. If changing IDs would strand sessions, add backward-compatible lookup/migration rather than breaking continuity.
- Kimi transcript UX: choose a safe explicit output path using official CLI behavior. Never print ZIP bytes into a terminal or parse raw session files.

## 9. Ordered implementation plan

### Phase A: establish evidence and baselines

1. Pull `origin/main`, list and read every open handoff, verify Albert's commit identity, and record the exact base SHA. Run the current offline suites before editing: `bash tests/test-windows-scripts.sh`, `bash tests/test-ai-glm.sh`, `bash tests/test-ai-grok-review.sh`, and `bash tests/test-ai-kimi.sh`. Run `ai-glm doctor`, `ai-grok-review doctor`, and `ai-kimi doctor`. Capture only secret-free summaries. Reproduce M1-M5, where M5 is the Windows GLM restart race defined in section 5, with isolated fixtures or safe local controls before fixing them. **You'll know it worked when:** the plan STATUS row records the base SHA, exact pass counts, and a named regression test for each confirmed defect; no provider call was needed except the later cost measurement.

### Phase B: fix Kimi data-loss, cleanup, and prompt privacy

2. Refactor both `bin/ai-kimi:start_session` and `cmd_ask` so lifecycle traps own their repository/session locks and every prompt/output/error temp file through every exit. The implementation trap must also own the exact worktree it created through signals, credential refusal, failures, and normal completion. Make cleanup idempotent so explicit cleanup and the trap can both run safely. Create each implementation worktree under a wrapper-owned state location such as `$STATE_DIR/worktrees/<repo-id>/<run-id>/wt`, and write an atomic owner record containing the canonical parent repo, exact worktree path, wrapper PID, run label, creation time, and lifecycle state, but no prompt or secret. Lifecycle state is either `active` or `preserved-recovery`; only step 3 may atomically change it to `preserved-recovery`, and that state means the worktree is the only retained copy of delegate work. Doctor may call an `active` worktree stale only when all of these are true: its owner record parses; the canonical parent repo matches; `git worktree list --porcelain` registers that exact path; the path stays under the wrapper-owned worktree root after canonicalization; and the recorded PID is not alive. Doctor must never remove a `preserved-recovery` worktree automatically, even when its PID is dead; it must print the patch-recovery instructions and require explicit caller cleanup after the work is saved. If any check or state is missing or ambiguous, report it and do not remove anything. Extend `tests/test-ai-kimi.sh` with: interrupt after worktree creation; delegated-credential refusal after worktree creation; normal success; Kimi failure; no-session-id failure; `cmd_ask` changed-tree failure temp cleanup; stale active marker with dead PID; live PID; forged outside-root path; foreign worktree; preserved-recovery marker with dead PID; and no orphan in `git worktree list`. **You'll know it worked when:** ordinary owned exit paths leave no worktree, owner record, or temp file; doctor removes only a fully verified stale `active` wrapper-owned worktree; preserved-recovery worktrees remain registered with loud recovery instructions; and active, ambiguous, forged, or unrelated worktrees remain untouched.

3. Capture the original base commit before creating the Kimi worktree. Change `emit_patch` to stage the final tree and diff against that captured base, including committed, staged, unstaged, new, and deleted files. A non-empty result must never be discarded when `.ai/reviews/` is unavailable or not safely ignored. Prefer a private wrapper-owned fallback directory outside the repository, write the patch atomically with owner-only permissions, print its exact path, and keep it until the caller confirms or removes it. If no safe patch destination can be created, atomically change the owner record to lifecycle state `preserved-recovery`, leave the exact worktree registered, print recovery and explicit cleanup commands plus its path, and fail loudly; do not run cleanup that destroys the only copy of the work. Add fixtures where the delegate makes only working-tree edits, stages changes, creates one commit, creates multiple commits, makes no changes, deletes a file, runs without an ignored reviews directory, cannot create the fallback, marks and preserves the recovery worktree, and proves doctor skips that preserved record. Every emitted patch must apply cleanly to the original base with `git apply --check`. **You'll know it worked when:** every non-empty final tree produces an equivalent recoverable patch or a `preserved-recovery` worktree with loud instructions, no-change runs produce no patch, doctor cannot delete the preserved copy, and no error path deletes the only copy of delegate work.

4. Re-run current Kimi 0.32.0 help probes for prompt input. If official prompt-file or stdin support exists, change `run_turn` to pass prompt content without placing it in argv, using a private temp file or pipe and preserving the exact-session/agent rules. Prove both execution paths: the direct current-user path and the delegated `su - "$as"` review path, whose stdin is currently `/dev/null`. A private prompt file created by root must not be assumed readable by the credential-owning delegated user; either stream safely across `su`, create a delegated-user-owned 0600 file in a private directory, or use another officially supported transport that passes a two-user process inspection. If no safe supported transport exists, correct the false comment, add a loud skill/docs warning that briefs are argv-visible on shared hosts, prohibit secrets in briefs, and document the host `hidepid` limitation without claiming it is enforced. Add offline argv tests for both paths and safe live process-inspection tests on authenticated direct and delegated targets. **You'll know it worked when:** either neither live process command line contains prompt content, or the documented limitation and tests prove the best supported behavior without false claims on both paths.

Natural context cut: after Phase B. Before continuing in a fresh session, update this STATUS table and your own handoff, then re-read Phases C-F.

### Phase C: fix GLM concurrency and Windows restart

5. Add GLM lock ownership around the full `cmd_new` check/create/write sequence. Prefer repository-plus-session locking so matching names serialize while unrelated repositories remain independent. If a server session is created but local metadata cannot be written, attempt the safe server-session delete and fail loudly. Add tests with two concurrent same-name `new` calls proving only one OpenCode session is created and one receives an actionable already-exists result. Document that GLM implementation sessions are disposable and intentionally absent from `list/show`; on interruption, abort or delete the server session if the API safely supports it, while always removing the remote-less clone. **You'll know it worked when:** the concurrency fixture cannot orphan a server session and interrupted implementation leaves neither clone nor unexplained active server session.

6. Extract or add a bounded Windows port-free wait in `bin/ai-glm:cmd_server restart`, equivalent in intent to `Wait-PortFree` in `bin/setup-opencode-glm.ps1`. After ending the task, poll only loopback port 4096 until it is free or 30 seconds elapse. Start the task only after proof; on timeout, fail loudly and do not start a competing listener. Then wait for health and prove exactly one loopback listener. Extend `tests/test-windows-scripts.sh` with static/rendered assertions and run a controlled live restart. **You'll know it worked when:** a deliberately delayed old listener prevents premature start, a normal restart becomes healthy, and exactly one listener exists.

### Phase D: measure and correct Grok cost and result guidance

7. Use `AI_GROK_CALLER=codex` and `ai-grok-review`, never raw hand-built review commands. Reuse an existing matching test session if present or create one named `delegate-hardening-cost-semantics`. Keep the entire measurement below $0.50. Save the wrapper's raw `--json` result for the initial turn and one resumed turn under `.ai/reviews/`; do not read credentials. Determine whether `total_cost_usd` is per-call or cumulative. Amend this plan with the measured rule before changing arithmetic. Then update `bin/ai-grok-review`, metadata fields, `list/show` output, `skills/shared/grok-cli/SKILL.md`, and fixtures so stored total and next-turn estimates are mathematically correct. **You'll know it worked when:** a two-turn fixture based on real JSON yields the exact real total once, and the $1.50 guidance cannot double-count or undercount.

8. Separate `cancelled` from turn-limit results in `handle_stop_reason`. A cancellation must explain that the session may not resume cleanly and follow the measured 0.2.118 recovery rule; max-turn results may recommend a bounded higher turn count. Explicitly document that the $1.50 ceiling is enforced by the parent skill, while the wrapper enforces turn and permission bounds. Do not claim a hard dollar kill switch unless the wrapper can enforce it from proven per-turn data before spending the next turn. **You'll know it worked when:** cancellation and max-turn fixtures produce different, correct recovery messages and unknown stop reasons still fail closed.

### Phase E: align cross-wrapper safety where supported

9. Design one versioned repository-identity helper or identical algorithm for all three wrappers using normalized root path plus remote URL. Before changing IDs, implement backward-compatible lookup of existing path-only Grok/Kimi records and GLM records, then migrate metadata atomically on first successful access. Never lose a named session because a checkout moved or the algorithm changed. Add tests for same path/different remote, symlink/normalized path, moved checkout, old-record discovery, caller separation, and collision resistance. **You'll know it worked when:** existing sessions remain usable and new IDs follow one documented rule across GLM, Grok, and Kimi.

10. Make Grok and Kimi `write_meta` explicitly create/replace metadata with owner-only permissions on Unix and the existing user-private directory behavior on Windows. Do not store prompts or secrets in metadata. Add permission tests where the platform exposes modes. **You'll know it worked when:** Unix metadata is 0600, Windows tests do not claim Unix mode enforcement, and all existing records remain readable.

11. Create a dedicated Kimi implementation agent profile only if current Kimi 0.32.0 supports an implementation profile with `Read`, `Grep`, `Glob`, `Write`, `Edit`, and `Bash` while excluding `WebSearch`, `FetchURL`, `Agent`, and `AgentSwarm`. Re-run both directions: it must edit and test inside the disposable worktree, and it must fail a harmless network/subagent request. If Kimi cannot express that policy reliably, stop and document the unsupported boundary rather than claiming lockdown. Update the skill to say exactly what enforces containment. **You'll know it worked when:** live canaries prove required local implementation works and forbidden network/subagent tools are absent, or the plan records a clear unsupported limitation and owner decision.

12. Improve `ai-kimi transcript` through the official `kimi export` command. Require or generate an explicit archive destination under `.ai/reviews/`, print the path, and never stream binary ZIP bytes to the console. Add success, existing-file, export-failure, and path-safety tests. Do not inspect archive contents. **You'll know it worked when:** the command returns one private archive path, stdout remains readable text, and failures leave no partial archive.

Natural context cut: after Phase E. Update STATUS and handoff before a fresh session, then re-read Phase F.

### Phase F: integrate, document, and ship

13. Update `docs/architecture.md`, `docs/development.md`, `docs/glm-opencode.md`, `docs/skills-usage-guide.md`, and affected shared skills with only verified behavior. Preserve the completed historical reasoning in the three older delegate plans; link this new plan from `AGENTS.md` under the delegate-routing row and from the relevant topic docs. Add a short memory entry that future sessions must read this plan's STATUS table before re-planning. **You'll know it worked when:** a fresh reader can find the active plan from the router, and no doc claims a control that tests did not prove.

14. Run all offline suites, Bash syntax checks, PowerShell parsing, `git diff --check`, secret-pattern checks, metadata migration tests, and installed-skill validation. Then run the minimum live matrix: Windows GLM restart and exact-session resume; Grok two-turn cost/cancellation behavior within the stated budget; Kimi read/write/network/interrupt/committed-patch/transcript canaries. Install shared skills with `bash bin/ai-install-skills` and hash-compare repo, Claude, and Codex copies. **You'll know it worked when:** every named check is green, live sessions keep exact IDs, no worktree remains, no prompt/secret is exposed beyond any explicitly documented unsupported limit, and installed hashes match.

15. Update this STATUS table, record exact counts/cost/session IDs without secrets, and create or update only your own write-once handoff. Pull and reconcile concurrent work. Stage only this workstream's files. Verify `git var GIT_COMMITTER_IDENT` is `Albert Hazan <u2giants@users.noreply.github.com>`. Commit focused changes to `main`, push, fetch, and compare local/remote SHA. This repo has no CI or deployment, so record both as N/A. Delete your own handoff only when every row is proven complete. **You'll know it worked when:** `HEAD` equals `origin/main`, the worktree contains only known unrelated files, installed tools match source, and this plan has no open row.

## 10. Tests required

Kimi, in `tests/test-ai-kimi.sh`:

- `implement_interrupt_removes_worktree`
- `delegated_credentials_refusal_removes_worktree`
- `all_early_exits_remove_worktree_and_temp_files`
- `committed_changes_are_in_patch`
- `multiple_commits_are_in_patch`
- `staged_unstaged_new_deleted_files_are_in_patch`
- `no_change_produces_no_patch`
- `prompt_transport_is_not_falsely_described`
- `implementation_agent_can_edit_but_cannot_network_or_spawn` if the CLI supports that profile
- `transcript_writes_private_archive_not_binary_stdout`
- Existing 56 offline tests and 64 live tests remain green or higher.

GLM, in `tests/test-ai-glm.sh` and `tests/test-windows-scripts.sh`:

- `concurrent_same_name_new_creates_one_session`
- `failed_metadata_write_deletes_created_server_session`
- `interrupted_implement_removes_clone_and_handles_server_session`
- `windows_restart_waits_for_port_free`
- `windows_restart_timeout_fails_before_start`
- `windows_restart_returns_one_healthy_listener`
- Existing 129 offline GLM tests, 145 live GLM tests, and current Windows suite remain green or higher.

Grok, in `tests/test-ai-grok-review.sh`:

- `measured_resumed_cost_fixture_accounts_once`
- `next_turn_estimate_uses_measured_semantics`
- `cancelled_has_cancellation_recovery_message`
- `max_turns_has_bounded_turn_recovery_message`
- `unknown_stop_reason_still_fails_closed`
- `skill_states_dollar_ceiling_is_parent_enforced`
- Existing 79 offline tests and read-only live canary remain green or higher.

Cross-wrapper tests:

- one repository-ID algorithm with backward-compatible old-record discovery;
- caller separation remains intact;
- Unix metadata is 0600 without false Windows claims;
- no model pin, permission map, completion signal, turn bound, or exact-session rule changes accidentally;
- `git diff --check`, Bash `-n`, and PowerShell parser checks pass.

## 11. Constraints, standing rules, and gotchas

- Main-only repository. Pull before editing and before pushing. Preserve concurrent work.
- Verify Albert's author and committer identity before the first commit.
- Never stage `.ai/`, `docs/claude-remote-control-hardening-v2.md`, raw transcripts, credentials, or another session's handoff.
- Never read `~/.grok/auth.json`, raw Kimi session files, `.env` secrets, or resolved 1Password values.
- Serialize any required 1Password reads. No rotation is needed or authorized.
- Never call OpenCode directly; use `ai-glm`. Never hand-build Grok review flags; use `ai-grok-review`. Never hand-build Kimi commands; use `ai-kimi`.
- GLM review safety depends on the `tools:` map. Kimi review safety depends on exact case-sensitive tool names. Do not weaken either.
- Grok completion is terminal JSON, never exit status. Kimi completion is `session.resume_hint`, never exit status. GLM completion is the measured OpenCode finish/idle rule.
- Do not change models, broaden review permissions, remove locks, remove turn bounds, or replace the GLM remote-less clone.
- Kimi provides no headless token, cost, cache, context-size, or returned-model data. Never invent those figures.
- Windows PowerShell source must stay pure ASCII. Use loopback port 4096 only. A `Ready` Scheduled Task is not proof of a healthy listener.
- Use bounded live tests. Grok cost measurement must stay below $0.50. No production, shared cloud, database, browser, or deployment mutation is needed.
- No band-aids. Each fix must address the lifecycle or data model that caused the defect.

## 12. Access and environment

- Repository: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- Machine: Windows 11, user `ahazan2`; PowerShell 7 and Git Bash are available.
- Authenticated local tools: Git/GitHub CLI, GLM through `ai-glm`, Grok Build through `ai-grok-review`, and Kimi Code through `ai-kimi`. Re-run each doctor before live tests.
- Qualified GLM: OpenCode 1.18.12, provider `zai-coding-plan`, model `glm-5.2`, loopback `127.0.0.1:4096`, Windows task `AiDevOps-OpenCodeGlm`.
- Qualified Grok at the time of the earlier work: Grok Build 0.2.118, wrapper-requested model `grok-4.5`. Re-check installed version before relying on any flag or cost shape.
- Qualified Kimi at the time of the earlier work: Kimi Code 0.32.0, wrapper-requested model `kimi-code/k3`. Re-run STEP 0 probes before changing agent or prompt behavior.
- GLM secret source: 1Password account `popcreations.1password.com`, vault `vibe_coding`, item `GLM z.ai API`. Never retrieve its value into chat or files.
- Local review report: `.ai/reviews/glm-delegate-integrations-final-review-20260810T145010Z.md`. It is evidence only and must remain Git-ignored.
- No application URL, test login, database, production service, CI pipeline, or deploy target applies to this repo.

## 13. Definition of done, risks, and open questions

Done means all ten STATUS rows are complete and evidenced; every confirmed defect has a regression test; every V1-V7 item is fixed, measured, or closed by a documented decision; all offline and bounded live tests pass; no stale worktree, clone, session record, partial transcript, or duplicate listener remains; docs and installed skills match source; correct commits are pushed to `main`; and local/remote SHAs match. CI and deployment are N/A and must be recorded as such.

Main risks:

- A broad cleanup trap could delete another session's worktree. Mitigate by tracking the exact wrapper-created path and making cleanup idempotent.
- Repository-ID alignment could strand existing named sessions. Mitigate with backward-compatible discovery and atomic migration before changing new IDs.
- Kimi prompt privacy may be limited by the installed CLI. Never claim stdin or prompt-file safety until help and a live process check prove it.
- A Kimi implementation agent may not support the desired local-tools-only profile. Stop and document the unsupported boundary rather than silently allowing network tools.
- Grok cost semantics could change with a CLI update. Store the qualified version and keep fixtures based on measured raw JSON.
- GLM cleanup of a newly created but unrecorded session could fail during a server problem. Preserve the session ID in a loud diagnostic so it can be deleted later.
- Concurrent sessions can change the shared tree during long live reviews. Use an exact isolated copy for read-only delegate debates; never weaken mutation checks.

Rollback:

- Revert the focused implementation commit and reinstall repo-owned skills.
- Do not delete existing session state during rollback.
- For metadata-ID migration, keep legacy lookup until at least one full release cycle and provide a reversible backup of metadata filenames, never prompt contents.
- For Windows GLM restart changes, rerun the prior setup script only after reverting source; do not manually edit the registered task.

Open questions and decision gates:

- Does Kimi 0.32.0 support safe prompt-file or stdin input in headless mode? Decide only from current help and a live harmless test.
- Is Grok 0.2.118 `total_cost_usd` per-call or cumulative on resume? Decide only from the bounded two-turn raw JSON measurement.
- Can Kimi express and enforce a local-write/Bash but no-network/no-subagent implementation agent? Decide only from a two-direction live canary.
- Can repository IDs be aligned without breaking existing named sessions across moved checkouts? Decide from migration fixtures before changing production metadata.
- Can OpenCode safely delete an interrupted disposable implementation session? If not, document the session ID and provide an explicit cleanup command rather than hiding it.

## Mandatory self-audit

1. **Could a brand-new AI session execute this plan without asking Albert anything? Yes.** Sections 2-6 define the toolkit, exact defects, current state, and causes. Sections 8-12 lock the safety decisions, name every file/function, define the evidence-only open questions, and provide commands and gates.
2. **Does the plan carry all current background, nuance, and rejected reasoning? Yes.** Sections 3, 5, 6, and 7 preserve the GLM review, Codex's confirmation of the Windows restart race, every M1-M4 and V1-V7 item, the failed design assumptions, and why the obvious shortcuts are unsafe.
3. **Is the ultimate goal clear enough for correct judgment if a step is wrong? Yes.** Section 1 prioritizes no lost work, no leaked resources, truthful privacy/cost behavior, and preserved proven controls. Section 8 distinguishes locked decisions from evidence-driven choices, and Section 13 defines stop conditions and rollback.

All 13 sections are present. The plan has an explicit out-of-scope list, named tests, file/function targets, per-step verification gates, locked and open decisions, access rules, secret locations without values, commit/push verification, and N/A CI/deployment handling. The self-audit passed on 2026-08-10.
