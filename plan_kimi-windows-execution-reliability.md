# Plan: make Kimi execution reliable on Windows without exposing credentials

Planning issue: [u2giants/ai-devops#31](https://github.com/u2giants/ai-devops/issues/31)
Paired handoff: [`HANDOFF.d/2026-08-17T0017Z-al8960ofc-codex-kimi-windows-execution-plan.md`](HANDOFF.d/2026-08-17T0017Z-al8960ofc-codex-kimi-windows-execution-plan.md)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Freeze the Windows failure matrix | ⬜ open | 2026-08-17 | Required artifacts are specified in §9.1 and §10. |
| 2. Add security-preserving execution preflight | ⬜ open | 2026-08-17 | Required behavior and tests are specified in §9.2. |
| 3. Add durable detached Kimi jobs | ⬜ open | 2026-08-17 | Required job lifecycle is specified in §§8–10. |
| 4. Add progress, timeout, and recovery truth | ⬜ open | 2026-08-17 | Required states and tests are specified in §§9.4–9.5. |
| 4a. Isolate reviews from concurrent checkout edits and directory-bound resumes | ⬜ open | 2026-08-18 | Live failures and required regression tests are specified in §§6.8, 9.4a, and 10. |
| 4b. Separate analysis prompts from diff-review packets | ⬜ open | 2026-08-18 | The architecture-review anchoring failure and prompt-contract tests are specified in §§6.9, 9.4b, and 10. |
| 4c. Bound Kimi packet work and record real stage timing | ⬜ open | 2026-08-18 | The measured six-minute review audit, exact Kimi self-audit, and required corrections are in §§6.10, 9.4c, and 10. |
| 5. Enforce main-session routing for credentialed runs | ⬜ open | 2026-08-17 | Required skill/orchestrator changes are specified in §9.6. |
| 6. Qualify the complete Windows path live | ⬜ open | 2026-08-17 | Live canaries are specified in §9.7 and §10. |
| 7. Update model comparison and operating docs | ⬜ open | 2026-08-17 | Documentation targets are specified in §9.8. |
| 8. Review, land, install, and verify | ⬜ open | 2026-08-17 | Definition of done is §13. |

**Fresh-session starting point:** begin at the first open row. Re-read §§6–8 before changing code. After each completed row, update this table with a reproducible artifact, commit SHA, or exact test command. Do not cite a bare count.

## 1. Ultimate goal

Albert must be able to request a Kimi review from a Windows Codex task and receive one of two outcomes quickly and truthfully:

1. a durable, resumable review that continues even if the initiating tool call or Codex turn ends; or
2. an immediate explanation that the current task cannot securely run Kimi, plus an automatic route back to the Full Access main task.

No Kimi process may run silently for fifteen minutes when it never authenticated. No completed review may be lost because its caller ended. No restricted task may gain access to Albert's Kimi OAuth credentials merely to make the command work.

When Kimi actually runs, its current safety properties must remain: exact named session, pinned requested model, structurally read-only review tools, exact repository head, and no false success without Kimi's terminal `session.resume_hint` record.

**If a step conflicts with this goal, the goal wins. Stop and flag the conflict.**

## 2. What this application is

[`u2giants/ai-devops`](https://github.com/u2giants/ai-devops) is Albert Hazan's public toolkit for running and restoring a multi-model coding workflow. It contains Bash and PowerShell commands, tests, setup scripts, skills, and operating documentation. It is not a hosted application and has no database.

The target command is [`bin/ai-kimi`](bin/ai-kimi), the only supported headless Kimi launcher. It currently provides:

- named read-only review sessions through `new` and `ask`;
- persistent exact-session continuation;
- isolated implementation workspaces through `implement`;
- strict completion based on Kimi's terminal `session.resume_hint` event;
- wrapper-owned state under `AI_KIMI_STATE_DIR`;
- Kimi's own data under `KIMI_CODE_HOME`, or `C:\Users\ahazan2\.kimi-code` by default.

The affected machine is Windows 11 host `al8960ofc`. The installed Kimi CLI was measured as `0.32.0` on 2026-08-17. The repository path is `C:\repos\ai-devops`. The implementation target is `main`; use an isolated branch and pull request when another task has uncommitted work in the primary checkout.

Primary files:

- [`bin/ai-kimi`](bin/ai-kimi): wrapper, process lifecycle, state, completion, doctor, and CLI.
- [`tests/test-ai-kimi.sh`](tests/test-ai-kimi.sh): offline and opt-in live wrapper tests.
- [`tests/test-windows-ai-kimi-shim.ps1`](tests/test-windows-ai-kimi-shim.ps1): Windows installation/shim checks.
- [`bin/setup-machine.ps1`](bin/setup-machine.ps1): Windows machine setup and doctor wiring.
- [`config/kimi/readonly-review.md`](config/kimi/readonly-review.md): structurally read-only Kimi profile.
- [`skills/shared/kimi-code-delegation/SKILL.md`](skills/shared/kimi-code-delegation/SKILL.md): instructions used by Claude and Codex.
- [`models_comparison_grok_kim_glm.md`](models_comparison_grok_kim_glm.md): observed model-quality and transport evidence.
- [`AGENTS.md`](AGENTS.md): documentation router and hard-won constraints.

Official Kimi references, checked 2026-08-17:

- [Data locations](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/data-locations.html)
- [Environment variables](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/env-vars.html)
- [Sessions and context](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/sessions.html)
- [`kimi` command](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html)

## 3. What triggered this work

During the 2026-08-16 `shared-db` orchestrator session, several delegated reviewer tasks failed even though the main Codex task was in Full Access mode.

Observed failure classes:

1. A delegated task could start the workspace-local `ai-kimi` wrapper but Kimi itself failed with `EPERM: operation not permitted, mkdir 'C:\Users\ahazan2\.kimi-code\sessions\...'`.
2. Setting `AI_KIMI_STATE_DIR` inside the repository relocated only wrapper state. Kimi continued using its own fixed default home because `KIMI_CODE_HOME` was not set.
3. The wrapper then waited to its 900-second ceiling because no terminal Kimi event arrived, even though authentication or session initialization had already failed.
4. Earlier Kimi calls outlived a short initiating shell/tool boundary. The child eventually exited, but the wrapper process that should have saved the verdict was gone, so no durable session or review artifact existed.
5. Some Kimi runs were slow and silent while legitimately working. The supervisor could not reliably distinguish healthy work from pre-session failure without manually inspecting processes.

The practical result was paused database work and repeated reviewer restarts. These failures were transport and lifecycle failures. They are not evidence that Kimi K3 produces poor code. When Kimi ran successfully in the same programme, it returned useful exact-head reviews and historically produced the safest first-pass implementation among the compared models.

## 4. Scope

### In this plan

- Detect the effective Windows execution context before launching Kimi.
- Distinguish the main Full Access task from a restricted delegated task using an executable write/read canary, not a verbal mode claim.
- Use the officially supported `KIMI_CODE_HOME` explicitly and record its effective path without printing secrets.
- Refuse early when the current process cannot both read credentials and create session data securely.
- Add durable detached review jobs whose state survives the initiating shell, tool call, and Codex turn.
- Add `start`, `wait`, `status`, `logs`, `result`, and `cancel` behavior, or equivalent commands with those exact capabilities.
- Preserve exact session identity and terminal-event completion rules.
- Emit bounded progress heartbeats and distinguish preflight, starting, running, completed, failed, timed out, cancelled, and orphan-recovered states.
- Make the Kimi skill route credentialed execution to the main Full Access task. Delegated tasks may prepare briefs and inspect code but must not run Kimi when the preflight refuses.
- Add Windows, offline, and bounded authenticated live tests.
- Update the model comparison so Kimi model quality is not confused with wrapper reliability.

### NOT in this plan

- Granting `CodexSandboxUsers` Modify access to `C:\Users\ahazan2\.kimi-code`.
- Copying Kimi OAuth credentials into a repository, worktree, `.ai/` directory, prompt, log, test fixture, or committed file.
- Building a privileged local broker that accepts arbitrary commands from restricted tasks.
- Weakening `config/kimi/readonly-review.md` or adding Bash, Edit, Write, network, or shell tools to review mode.
- Trusting exit code alone as proof of a completed review.
- Automatically substituting Grok, GLM, Qwen, or another model when Kimi fails.
- Changing Kimi's requested model pin from `kimi-code/k3`.
- Inventing Kimi token, cache, cost, context-size, or returned-model figures. Kimi 0.32.0 headless output does not provide them.
- Modifying application repositories, `shared-db`, databases, production, or cloud infrastructure.
- Solving Codex's general collaboration-task sandbox policy. This plan integrates safely with the policy that exists.

## 5. Current state of the code

The line references below target `origin/main` commit `e075b309afb80fdd19469631c034ffca4dda767e` and must be refreshed before implementation if `main` advances.

### What already works

- `bin/ai-kimi:1-69` records the measured Kimi 0.32.0 contract and the structural read-only proof.
- `bin/ai-kimi:78-83` defines wrapper state, caller, model, and a fixed 900-second wait.
- `bin/ai-kimi:103-117` resolves the Kimi binary, including the default `~/.kimi-code/bin` location.
- `bin/ai-kimi:136-153` detects per-user credentials and supports borrowing the Linux `ai` user's credentials for read-only reviews.
- `bin/ai-kimi:180-185` separates wrapper metadata, locks, and stable implementation workspace paths.
- `bin/ai-kimi:253-261` correctly treats only `session.resume_hint` as successful completion.
- `bin/ai-kimi:264-293` waits for completion and reports a timeout, but cannot reliably classify early Windows startup/auth failures.
- `bin/ai-kimi:856-1005` owns new-session, continuation, implementation, locking, and lifecycle cleanup.
- `tests/test-ai-kimi.sh:23-26` already isolates wrapper state and shortens waits for tests.
- `tests/test-ai-kimi.sh:426-461` contains opt-in authenticated live tests.
- `skills/shared/kimi-code-delegation/SKILL.md:8-15` correctly requires `ai-kimi` instead of hand-built Kimi commands.
- `skills/shared/kimi-code-delegation/SKILL.md:179-200` documents current credentials and doctor behavior, but predates the official `KIMI_CODE_HOME` finding and the delegated Windows failure.

### What is half-done or inaccurate

- `AI_KIMI_STATE_DIR` controls wrapper files only. The wrapper does not set or report `KIMI_CODE_HOME`.
- The header and skill say Kimi has no configurable data directory. Current official Kimi documentation disproves that: `KIMI_CODE_HOME` relocates config, OAuth credentials, sessions, logs, and other Kimi-owned data together.
- The synchronous `new`/`ask` command owns both worker lifetime and result finalization. A caller disappearing can prevent durable finalization.
- The wait loop detects a vanished Kimi process, but on Windows the process discovery and provider/startup failure evidence are too weak to prevent a full 900-second wait.
- `doctor` proves the direct user's setup but does not prove that the current task context can create a Kimi session directory and persist a harmless live turn.
- There is no durable job record that a later main-task turn can wait on after the initial shell exits.

### Repository state at planning time

- Plan base: `origin/main` `e075b309afb80fdd19469631c034ffca4dda767e`.
- Planning branch: `codex/issue-31-kimi-windows-plan`.
- Planning issue: `u2giants/ai-devops#31`.
- Installed Kimi: `0.32.0`.
- The primary `C:\repos\ai-devops` checkout had unrelated untracked `.ai/` and documentation files. They must not be staged, moved, or deleted.
- No implementation has started. Every STATUS row is open.

## 6. Key findings and root cause

### 6.1 Full Access did not automatically flow into delegated tasks

The main Codex task had Full Access, but delegated collaboration tasks ran with a more restrictive Windows identity. A statement such as “this task is Full Access” is therefore not executable proof for a child process. The launcher must test its actual ability to use the selected Kimi home before starting a paid model call.

### 6.2 The Windows ACL protected credentials correctly

On 2026-08-17, `C:\Users\ahazan2\.kimi-code` was owned by Administrators. `ahazan2`, SYSTEM, and Administrators had Full Control; `CodexSandboxUsers` had only Read and Execute. Kimi needs to create and update session files, so a delegated task failed at `mkdir`. Windows was enforcing the intended boundary, not randomly denying a Full Access main task.

### 6.3 Wrapper state and Kimi state are separate

`AI_KIMI_STATE_DIR` moved wrapper locks and metadata but did nothing to Kimi's own session/auth directory. Current official documentation establishes that `KIMI_CODE_HOME` is the supported control for all Kimi data. Because it moves credentials and sessions together, it cannot safely point a restricted task at a broadly writable location containing Albert's OAuth credentials.

### 6.4 Broadening the ACL would weaken security

Granting the sandbox group write access to the default Kimi home would also expose or permit replacement of OAuth credential and configuration files. That turns a code-review sandbox into a credential-bearing process. The secure behavior is a fast refusal and main-task reroute.

### 6.5 Synchronous ownership caused lost verdicts

The wrapper currently finalizes the review in the same foreground process started by the caller. When a tool boundary ends that caller, the Kimi child can continue without a durable supervisor to record the terminal event. Durable job ownership must move into a detached wrapper process with atomic state updates.

### 6.6 Silence has two meanings today

A healthy Kimi review may legitimately take many minutes with no final verdict. A failed Kimi initialization may also produce no terminal event. The wrapper needs observable phases and bounded diagnostics so the supervisor does not treat both as “still reviewing.”

### 6.7 Model quality and execution reliability are separate measurements

The canonical comparison contains strong Kimi implementation evidence and older operational warnings, but not this complete Windows incident. The final documentation must score code quality separately from provider/wrapper availability.

### 6.8 The 2026-08-18 live review exposed three more wrapper failures

During the shared-db orchestrator architecture review, two valid read-only Kimi turns were discarded because unrelated sessions changed the primary checkout between `tree_state` snapshots. The wrapper reported that Kimi had changed the working tree even though the review profile had no write tools. The canary observes the whole shared checkout, so it cannot distinguish Kimi writes from concurrent-session writes.

Moving the review into a stable linked worktree then exposed a directory-binding failure. Kimi immediately returned `Session ... was created under a different directory`, but `run_turn` had already reaped the failed child before `await_result` began. `await_result` polls every machine process named `kimi`; when it never sees the exited child, or sees an unrelated Kimi process, it waits the full 900-second ceiling. The wrapper therefore turned an immediate deterministic failure into a fifteen-minute wait.

The permanent correction is a stable wrapper-owned review workspace per named session, used from the first turn and refreshed in place for later turns. Read-only verification must compare that private workspace, not a concurrently edited primary checkout. A directory mismatch, nonzero child exit, or terminal stderr record must fail immediately without global process polling.

### 6.9 Diff-review packaging distorted a non-diff architecture review

Every read-only `ai-kimi` request currently receives an evidence-packet preamble saying that commits and a patch are “under review.” The first shared-db architecture turn consequently led with approval of an unrelated Git patch and compressed nine operating-model questions into one paragraph. A fresh Kimi session in a stable workspace answered all nine questions in detail, which separates prompt anchoring from model capability.

`ai-kimi` needs explicit review kinds. Diff reviews keep the sealed patch packet and `APPROVE`/`REVISE` verdict contract. Plan, architecture, and analysis reviews receive a decision packet and conclusion contract that does not imply a Git patch is the subject. Callers must choose deliberately; no heuristic may silently reinterpret the task.

### 6.10 The slow mixed-provider Kimi review was mostly self-inflicted packet work

The 2026-08-18 review `reviewer-repair-kimi-d082c8d` looked like one very slow
provider call, but it was two different delays hidden behind one silent wrapper
call:

1. **Before Kimi started, the caller asked the packet builder to run six test
   suites, including the complete 136-check Kimi suite.** That full Kimi suite
   had separately taken about two and a half minutes on this machine. The packet
   builder runs `--tests` synchronously and prints no heartbeat while it runs.
   This was the caller's mistake, enabled by a wrapper contract that accepts an
   arbitrarily expensive test command without timing or progress evidence.
2. **Kimi itself then ran for an exactly measured 247 seconds.** Its private log
   spans `2026-08-18T13:49:04.791Z` through `13:53:11.925Z` and records nine
   sequential model steps. The wrapper did not add a second wait after provider
   completion: `run_turn` waited for the exact Kimi child, and the terminal
   `session.resume_hint` was already present when `await_result` checked it.

The exact saved session was resumed and asked to audit its own prior behavior.
Kimi reconstructed these nine steps from its conversation: read the manifest;
attempt a full patch read; follow the resulting overflow file and hit the same
limit again; page the patch; inspect Kimi wiring; inspect Grok guidance; confirm
review boundaries; then answer. Its directly observed findings were:

- `patch.diff` was about 68.8 KB / 1,219 lines, above Kimi's approximately 50 KB
  `Read` result limit. The current packet split threshold is 400 KB, so it does
  not protect Kimi. One failed read plus one nested retry were pure waste.
- The manifest contained roughly 200 lines of passing test output. Passing
  output was treated as hundreds of lines instead of one summarized fact.
- The comparison covered more than 25 heterogeneous files but every wrapper
  hard-coded packet class `small`. The brief named six separate safety areas and
  asked Kimi to confirm all review boundaries, so several source reads were a
  predictable consequence of the task shape.
- The read-only profile was not the main delay. It preserved the required safety
  boundary. The expensive interaction was between its bounded `Read` tool and an
  oversized unsplit packet.

The Kimi log also records `thinkingEffort=high`. The focused self-audit used no
tools and only one model step, yet that step still took 106 seconds to produce a
2,897-token answer. Current `kimi --help` exposes no thinking-effort control, so
payload and prompt corrections will reduce avoidable work but cannot guarantee a
short provider response. Do not invent or pass an unsupported effort flag.

The caller made two additional bookkeeping errors. It omitted
`AI_KIMI_CALLER=codex`, so the session was stored under `claude`; and it later
wrote an estimated 371-second elapsed value into the scoreboard because the
wrapper records no stage timestamps. Neither slowed the provider, but both make
the run harder to find and the latency claim less trustworthy. The permanent
fix is executable caller identity plus measured timestamps, not more careful
manual transcription.

**Root-cause ranking:** (1) an unnecessarily broad synchronous `--tests`
command before provider launch; (2) a 68.8 KB patch above Kimi's read limit but
below the packet's 400 KB split threshold; (3) a 25-file heterogeneous change
misclassified as `small`; (4) a confirm-everything prompt; (5) one avoidable
nested overflow read by Kimi; (6) inherently slow high-effort generation. The
wrapper's provider wait and structural read-only boundary were not the cause
after Kimi started, but the wrapper is responsible for hiding the two stages and
for handing Kimi a packet that violates its measured read limit.

## 7. Approaches considered and rejected

1. **Grant `CodexSandboxUsers` Modify access to the default Kimi home. Rejected.** It would let any restricted task read or replace OAuth/configuration material. The permission failure is protecting a real secret boundary.
2. **Copy the OAuth files into each repository's `.ai/` directory. Rejected.** `.gitignore` reduces accidental commits but does not make a repository working directory an acceptable credential store. `git add -A`, malware, or another tool could still expose it.
3. **Set only `AI_KIMI_STATE_DIR`. Rejected.** Already tried. It relocates wrapper state, not Kimi sessions or credentials.
4. **Set `HOME` to the repository. Rejected.** It changes unrelated tools, can hide normal Git/SSH configuration, and uses an indirect path when Kimi now provides the explicit `KIMI_CODE_HOME` control.
5. **Create a privileged local broker for restricted tasks. Rejected for this plan.** A broker would cross the sandbox boundary and require authentication, command allowlisting, lifecycle management, and a separate threat model. The main task can run the wrapper directly with fewer moving parts.
6. **Treat a live Kimi PID as proof of progress. Rejected.** A wrapper or shell PID may remain while no authenticated Kimi child exists. Progress must combine durable job phase, child identity, output growth, and terminal evidence.
7. **Kill and restart after a fixed short silence. Rejected.** Healthy complex reviews can be quiet. Restarting wastes provider work and may duplicate reviews. Use a wall deadline plus explicit startup deadline, heartbeats, and manual cancellation.
8. **Accept exit code 0 or the text `APPROVE` as completion. Rejected.** The existing terminal `session.resume_hint` rule prevents partial or transport-failed output from becoming review evidence.
9. **Automatically switch models after Kimi failure. Rejected.** Reviewer rotation and substitution are policy decisions outside this wrapper. The wrapper reports a typed failure; its caller decides the governed next step.
10. **Blame Kimi K3 for permission/auth/session failures. Rejected.** Those failures occurred before the model produced a verdict. Model quality must be judged only from completed, exact-head runs.
11. **Increase the 900-second ceiling for immediate child failures. Rejected.** The child had already exited with a deterministic directory error. A longer wait makes the defect worse.
12. **Keep using the shared primary checkout and weaken the read-only canary. Rejected.** Concurrent edits both invalidate evidence and create false accusations. Reviews need a stable private workspace; the structural read-only profile and canary both remain.
13. **Use one diff-oriented prompt contract for every read-only request. Rejected.** It anchored an architecture review on an unrelated patch. Review kind must be explicit.
14. **Raise Kimi's 900-second wall deadline to accommodate this review. Rejected.** The run completed far below the deadline; the avoidable delay was synchronous test work plus an oversized packet. A larger ceiling changes neither.
15. **Give read-only Kimi Bash so it can page large files itself. Rejected.** That weakens the proven safety boundary to compensate for packet construction that we control.
16. **Treat every passing test line as review evidence. Rejected.** The reviewer needs the command, exit status, duration, summary, and failures. Hundreds of repeated `ok` lines waste its bounded reads.

## 8. Design decisions

### Locked decisions, 2026-08-17

1. **Keep the credential boundary.** Do not broaden the default Kimi-home ACL for sandboxed tasks.
2. **Use `KIMI_CODE_HOME` explicitly.** The wrapper will resolve and report the effective Kimi home, without listing credential names or contents.
3. **Main task owns credentialed provider execution.** A delegated task may prepare a brief or inspect an exact clone. If preflight proves it cannot securely run Kimi, it must return control immediately to the Full Access main task.
4. **Detached worker owns the job.** The foreground CLI submits or attaches; the worker owns Kimi, output, finalization, and cleanup.
5. **Terminal evidence remains mandatory.** `session.resume_hint` is still the only Kimi success signal.
6. **Review remains structurally read-only.** No additional Kimi tools are granted.
7. **No hidden fallback.** Every reroute, retry, cancellation, timeout, or provider failure is explicit and durable.
8. **One job identity.** Repository identity, caller, session name, exact head, mode, and generation identify a run. Duplicate starts attach to or refuse the existing job; they never launch a second hidden reviewer.
9. **No unavailable metrics.** Do not invent returned model, tokens, cache, cost, or context size.

### Open implementation judgments

1. **Detached-process mechanism:** prefer the fewest-moving-parts native mechanism that survives the initiating shell on both Git Bash and PowerShell. Candidates are a hidden PowerShell `Start-Process` worker or a wrapper subcommand launched with redirected standard streams. Choose only after a live child-survival canary. Do not add a persistent Windows service.
2. **CLI compatibility:** preserve current synchronous commands as compatibility shims if this does not weaken durability. It is acceptable for `new` to call `start` then `wait`; the detached worker must still survive if `wait` disappears.
3. **Heartbeat interval:** default between 30 and 60 seconds. It must report phase, elapsed time, and last output growth without printing prompt or model text.
4. **Startup deadline:** choose a measured bound, initially 60 seconds, for “provider/session actually started.” Keep the existing configurable full wall deadline for legitimate long reviews.

These are engineering judgments. They do not need Albert unless live evidence shows that secure main-task routing cannot meet the ultimate goal.

## 9. Ordered implementation plan

### Phase A: freeze the failures and security boundary

#### 9.1 Add a reproducible Windows failure matrix

Change:

- Add `tests/test-kimi-windows-execution.ps1` for Windows-native path, ACL, process, and environment behavior.
- Extend `tests/test-ai-kimi.sh` with stubbed startup/auth/session failures and caller-disappearance fixtures.
- Add bounded, redacted fixtures under `tests/fixtures/kimi/` only when needed. Never copy real logs or credentials.

Required cases:

1. main user can read/write a harmless canary in the effective `KIMI_CODE_HOME`;
2. a simulated restricted identity or unwritable home fails before Kimi launch;
3. `AI_KIMI_STATE_DIR` alone does not count as Kimi-home readiness;
4. `KIMI_CODE_HOME` is passed through to the child;
5. a child emitting an immediate filesystem/auth failure becomes a typed startup failure, not a 900-second wait;
6. a healthy silent stub remains running until its normal completion or full wall deadline;
7. killing the foreground waiter leaves the detached worker alive and able to finalize;
8. duplicate start does not create a second Kimi child.

Dependencies: none. This phase must precede behavior changes.

**You'll know it worked when:** the new tests fail for the current wrapper for the expected reasons, and every failure names the missing behavior rather than merely timing out.

### Phase B: explicit secure preflight

#### 9.2 Resolve and verify Kimi's effective home before launch

Change `bin/ai-kimi` near current configuration, binary resolution, credential checks, and `cmd_doctor`:

- Add one resolver for `KIMI_CODE_HOME`, defaulting exactly as Kimi does.
- Export that resolved path into every Kimi child process, including Windows Git Bash launches and Linux `su` launches.
- Add `preflight_execution_context MODE` that checks:
  - Kimi binary exists and version is qualified;
  - wrapper state is writable;
  - effective Kimi home exists or its parent permits safe creation;
  - provider configuration is visible without printing it;
  - a private session/log subdirectory can be atomically created, written, read, and removed;
  - review profile exists and contains the exact case-sensitive read-only tools;
  - exact repository/worktree path is readable;
  - no credential file or content appears in output.
- Give failures stable classes such as `execution-context-denied`, `credentials-unavailable`, `kimi-home-unwritable`, `provider-unavailable`, and `profile-invalid`.
- Exit before acquiring a long-lived repo lock or launching Kimi when preflight fails.
- Update `doctor` to show PASS/FAIL for wrapper state, Kimi home, credentials, session write canary, review profile, and a bounded optional live turn.

Update `bin/setup-machine.ps1` only if the live qualification proves a setup change is required. Do not change ACLs to make a restricted task credential-capable.

Dependencies: §9.1 tests.

**You'll know it worked when:** the exact former `EPERM mkdir ...\.kimi-code\sessions` condition fails in under five seconds with `execution-context-denied` and the instruction “run this credentialed Kimi job from the Full Access main task”; a normal main task passes without exposing secret paths beyond the Kimi-home root.

### Phase C: durable detached job ownership

#### 9.3 Separate submission, supervision, and waiting

Change `bin/ai-kimi`:

- Introduce durable review-job metadata under `AI_KIMI_STATE_DIR/jobs/<repo-id>/<caller>--<name>/`.
- Store atomically: schema version, job ID, repository remote/path, exact head, caller, session name, mode, Kimi requested model, effective Kimi-home path hash, created/updated timestamps, worker PID, Kimi child PID when known, phase, last-output timestamp/size, terminal reason, Kimi session ID when proven, exit code, and artifact paths.
- Never store prompts, credential paths below the Kimi-home root, credential contents, or raw environment variables in metadata.
- Add commands or equivalent behavior:
  - `start`: preflight, create the job, launch the detached worker, and return the durable job ID promptly;
  - `wait`: attach to an existing job and return only when terminal or the caller's wait limit expires;
  - `status`: print bounded machine-readable and human-readable state;
  - `logs`: show bounded redacted wrapper diagnostics, not the full prompt/transcript by default;
  - `result`: emit the finalized review only after terminal proof;
  - `cancel`: target the exact active worker/child, finalize as cancelled, and release owned locks;
  - `recover`: reconcile a job whose worker died, using output and terminal evidence without inventing success.
- Keep `new` and `ask` compatible by making them submit/attach through this lifecycle. If their foreground waiter is killed, only the waiter ends.
- Give the worker exclusive ownership of final metadata, session record, transcript pointer, lock release, and cleanup.
- Use atomic temp-file replacement for every state transition.
- Prove PID identity before kill or stale recovery. A reused PID must never be killed.

Dependencies: §9.2 preflight.

**You'll know it worked when:** a test starts a review, kills the initiating `new`/`wait` process, observes the worker continue, and later retrieves one finalized exact-session verdict through `status`/`result`; no orphaned lock or duplicate Kimi child remains.

#### 9.4 Add truthful phases and heartbeats

Change `bin/ai-kimi` wait/supervision code:

- Persist and display these phases: `preflight`, `starting`, `running`, `finalizing`, `completed`, `failed`, `timed-out`, `cancelled`, `recovery-required`.
- Use a short startup deadline to require observable evidence that the real Kimi child/session has begun.
- During `running`, emit a heartbeat every configured interval containing only job ID, phase, elapsed time, child liveness, and whether output grew.
- Detect and classify known terminal provider/CLI records, including authentication, quota, filesystem permission, malformed output, and missing `session.resume_hint`.
- Keep the full wall deadline configurable. A quiet but live Kimi process is not a startup failure after it has crossed the startup gate.
- When the full wall deadline expires, terminate the exact owned child, finalize `timed-out`, preserve bounded diagnostics, and keep any proven session ID for governed continuation.

Dependencies: §9.3.

**You'll know it worked when:** supervisors can distinguish “not authenticated,” “could not create session storage,” “healthy and quiet,” “completed,” and “timed out” without inspecting Task Manager, and no case waits 900 seconds after a known startup failure.

#### 9.4a Give every named review a stable private workspace and fail exited children immediately

Change `bin/ai-kimi`, `bin/ai-review-sandbox`, and `tests/test-ai-kimi.sh`:

- Create one wrapper-owned self-contained review workspace at `new` time for ordinary clones and linked worktrees alike. Record its exact path in review metadata and reuse that same path for every `ask` turn because Kimi binds a session to its creation directory.
- Refresh the workspace in place from the current exact repository head before each turn. Refuse ambiguous uncommitted overlap; never point Kimi at a concurrently edited primary checkout.
- Run the read-only tree canary against the private workspace. If the primary checkout changes concurrently, report `source-checkout-changed` and mark evidence stale without accusing Kimi of writing.
- Replace `kimi_procs` global polling. `run_turn` already waits for and reaps its exact child. If that child exits without `session.resume_hint`, classify its exit and stderr immediately. A different machine-wide Kimi process is never evidence that this run remains alive.
- Detect `created under a different directory`, authentication, quota, filesystem, and malformed-session errors as typed immediate failures.
- Preserve terminal `session.resume_hint` as the only success proof.

Dependencies: §§9.3–9.4 durable worker ownership. This step may share the stable workspace primitive with implementation continuation, but review and implementation state must remain separately validated.

**You'll know it worked when:** a stub that exits immediately with a directory-binding error returns nonzero in under five seconds; an unrelated live Kimi process cannot extend that wait; concurrent edits in the primary checkout neither fail the read-only canary nor alter the private review workspace; and an exact named `ask` resumes in the same recorded directory.

#### 9.4b Add explicit diff, plan, architecture, and analysis review contracts

Change `bin/ai-kimi`, `bin/ai-review-packet`, the caller skills, and their tests:

- Add an explicit required review kind for non-default use: `diff`, `plan`, `architecture`, or `analysis`. Keep backwards-compatible `diff` only for callers whose command is explicitly a code review.
- For `diff`, retain the sealed patch packet and terminal `APPROVE`/`REVISE` contract.
- For `plan`, `architecture`, and `analysis`, generate a decision packet containing the named source documents, current commit identity, requested decisions, constraints, and evidence manifest without telling Kimi that an unrelated Git patch is the subject.
- Give each kind its own footer: code verdict for `diff`; decision-by-decision conclusion and unresolved-objection ledger for the other kinds.
- Make the Kimi skill require callers to select the kind and to keep large source material in readable files rather than pasting it into argv.
- Preserve exact-head identity and stable-workspace re-read requirements for every kind.

Dependencies: §9.4a stable review workspace.

**You'll know it worked when:** an architecture fixture containing an unrelated changed file never mentions approving that patch, answers every requested decision, and the diff fixture still produces the existing exact-head verdict and packet digest.

#### 9.4c Bound Kimi packet work and expose stage timing

Change `bin/ai-kimi`, `bin/ai-review-packet`, the Kimi caller skill, scoreboard
normalization, and their tests:

- Record monotonic start/end times for snapshot preparation, the optional test
  command, packet capture, provider execution, terminal verification, and total
  elapsed time. Persist those stage durations in session metadata and print a
  heartbeat at least every 30–60 seconds while tests or the provider are active.
- Record Kimi's observed model-step count from its private session log when it
  can be associated with the exact owned session without exposing prompts or
  private model text. If that cannot be done safely, record `unavailable`; never
  substitute wrapper-turn count.
- Make caller identity explicit. Codex and Claude launchers must set their
  caller value themselves; a credentialed call must not silently default to the
  other client.
- Give Kimi a packet split threshold below its measured `Read` result limit.
  Start at 40 KB, preserve the full patch across numbered files, and put an
  ordered file/line map in the manifest. Keep the provider-neutral packet's
  existing 400 KB safety ceiling only if a provider-specific view can be
  generated without changing the sealed source facts.
- Replace the fixed `small` class in `prepare_review()` with an explicit or
  measured class. A packet over 40 KB, ten changed files, or one subsystem must
  not claim to be a small review. Never silently narrow the requested scope.
- For passing tests, store command, exit status, measured duration, the final
  summary, and a short bounded tail. Preserve complete failure diagnostics.
  Default passing output must not consume 200 manifest lines.
- Reject or warn before provider launch when `--tests` names a broad/full suite
  for an ordinary review. The warning must state that tests run synchronously
  before Kimi and show their live elapsed time. A final-check review may opt in
  explicitly.
- Update the Kimi prompt contract to name only the decision-critical subsystems,
  distinguish files that require source confirmation from documents that can be
  judged from the sealed diff, and tell Kimi to page the original numbered patch
  after any `Read` overflow rather than reading an overflow artifact again.
- Do not add an unsupported thinking-effort flag. First qualify any future Kimi
  CLI/config control with an official-reference check and a live A/B that keeps
  finding quality and structural read-only enforcement unchanged.

Dependencies: §9.4 durable progress truth and §9.4b explicit review kinds.

**You'll know it worked when:** metadata separates pre-provider test time from
provider time; a simulated 68.8 KB patch is delivered in directly readable
numbered parts with no nested overflow retry; passing test evidence is bounded;
a broad test command produces visible pre-provider progress; caller identity is
correct without manual environment setup; and the same focused Kimi review
requires no packet-recovery step while preserving its substantive findings.

#### 9.5 Make recovery idempotent and fail closed

Change `bin/ai-kimi` recovery and lock code:

- Reconcile state after worker crash, machine restart, or killed waiter.
- Accept success only when the saved stream ends in a valid `session.resume_hint` and the exact session/repository identity matches.
- Mark a terminal provider or filesystem failure as failed with a stable reason.
- If neither completion nor failure can be proved, mark `recovery-required`; do not automatically restart or delete evidence.
- Ensure repeated `recover`, `wait`, `status`, and `cancel` calls are idempotent.
- Retain existing implementation-patch recovery behavior unchanged unless shared lifecycle code requires a reviewed refactor.

Dependencies: §§9.3–9.4.

**You'll know it worked when:** crash/restart tests converge to the same final job record on repeated runs, a partial stream is never APPROVE, and successor processes or unrelated locks are never killed or removed.

**Natural fresh-session cut:** after Phase C. Before Phase D, re-read this plan from §6 onward and update STATUS with exact test artifacts.

### Phase D: route Kimi correctly from Codex and shared-db

#### 9.6 Update the Kimi skill and caller contract

Change:

- `skills/shared/kimi-code-delegation/SKILL.md`
- installed copies only through the normal `ai-install-skills` flow, never by hand;
- `AGENTS.md` Kimi routing row;
- shared-db reviewer/orchestrator instructions only if their source lives in this repository and the change is necessary for automatic main-task routing.

Required policy:

1. A delegated task may prepare the exact-head clone, brief, test evidence, and review request.
2. Before it runs Kimi, it must execute the wrapper preflight.
3. If preflight returns `execution-context-denied`, it immediately sends the exact job request to the main Full Access task. It does not retry, alter ACLs, move credentials, or wait.
4. The main task submits the durable job, continues other work, and later retrieves the result.
5. Provider failure is not a review verdict. Governed reviewer replacement remains a separate caller policy.
6. The main task must not let a failed reviewer process become a workstream stopping point when safe unrelated work remains.

Add copy-paste examples for PowerShell and Git Bash. Use `AI_KIMI_CALLER=codex` explicitly.

Dependencies: durable commands must exist.

**You'll know it worked when:** a restricted-context test returns a structured hand-back request in under five seconds, while a Full Access main-task test submits the same request and receives a durable terminal result without granting new filesystem permissions.

### Phase E: live qualification and documentation

#### 9.7 Run bounded authenticated Windows canaries

Run on `al8960ofc` with Kimi 0.32.0 or the then-current explicitly re-qualified version:

1. `doctor` direct-user preflight.
2. New read-only review in a clean exact-head clone, proving Read succeeds and hostile Write cannot change a canary.
3. Exact-session `ask` continuation.
4. Kill only the foreground waiter, prove worker survival, then retrieve the result.
5. Simulate or safely reproduce an unwritable Kimi home, prove failure in under five seconds.
6. Run a healthy quiet fixture longer than the startup deadline and prove it is not killed.
7. Cancel an exact owned job and prove no Kimi child or lock remains.
8. Re-run after a Windows restart or use a fixture that reproduces worker death, then prove recovery.

Never use production repositories or secrets as canaries. The review profile may read only a disposable committed fixture repository.

Dependencies: Phases A–D.

**You'll know it worked when:** one evidence directory under `tests/verification/` records redacted commands, versions, job-state transitions, exact non-secret hashes, and pass/fail results for all eight canaries, with no raw OAuth/config/session contents.

#### 9.8 Correct documentation and model comparison

Change:

- `models_comparison_grok_kim_glm.md`: add a dated report separating Kimi's completed-work quality from Windows transport availability; document this incident and the fixed behavior.
- `docs/model-setup.md`: document `KIMI_CODE_HOME` and its security boundary.
- `docs/configuration.md`: document new wrapper settings and job-state location.
- `docs/development.md` and `docs/architecture.md`: document detached lifecycle, completion, recovery, and testing.
- `skills/shared/kimi-code-delegation/SKILL.md`: final operating procedure.
- `AGENTS.md`: route future Kimi execution work to this plan until complete, then to the permanent docs.
- This plan's STATUS table and paired handoff.

Dependencies: live evidence, because docs must describe measured behavior.

**You'll know it worked when:** a newcomer can answer “is Kimi bad or is the wrapper broken?” accurately, can run a review without guessing environment variables, and cannot mistake an authentication/permission failure for a model verdict.

### Phase F: independent review and landing

#### 9.9 Obtain independent review and land safely

- Run the full offline suite first.
- Use a different available model to review the exact head. Grok 4.6 is preferred for process-lifecycle and failure-path review; GLM 5.3 is an acceptable governed alternative.
- Require review of credential exposure, process ownership, PID reuse, atomic state, redaction, timeout behavior, exact-session identity, Windows quoting, and backwards compatibility.
- Fix every valid Critical/High/Medium finding and rerun tests.
- Commit as Albert, push, open a PR, require green CI if workflows exist at implementation time, merge, update/install the local toolkit through the normal setup command, and rerun the live canaries against the merged installed wrapper.

Dependencies: all earlier phases.

**You'll know it worked when:** `origin/main`, the installed `ai-kimi`, and source files hash-match; all required tests and canaries pass; the exact-head independent review has no unresolved Critical/High/Medium finding; issue #31 can be closed and this plan/handoff can be retired under the successor rule.

## 10. Tests required

### Offline Bash tests in `tests/test-ai-kimi.sh`

- `KIMI_CODE_HOME` is resolved once and exported to every new/resumed Kimi child.
- Wrapper state and Kimi home are not conflated.
- Unwritable Kimi home fails before provider launch and before long lock acquisition.
- Missing credentials and provider unavailable are distinct typed failures.
- Read-only profile validation remains case-sensitive and excludes all write/shell/network tools.
- Job metadata contains no prompt, token, credential filename, or raw environment dump.
- Job transitions follow the allowed state machine only.
- Atomic metadata write interruption preserves the prior valid record.
- Duplicate start attaches/refuses and creates only one worker/child.
- Foreground waiter death does not cancel worker.
- Worker death is recoverable and never becomes success without `session.resume_hint`.
- Immediate child error bypasses the full wall wait.
- Immediate nonzero child exit is classified before any polling loop, even when another `kimi` process is running.
- Review sessions retain one stable private workspace across exact-ID continuations and refuse a mismatched directory before provider launch.
- Concurrent primary-checkout edits do not trigger the Kimi-write canary; writes inside the private review workspace still fail hard.
- Diff packets and analysis/architecture decision packets have distinct preambles and terminal answer contracts.
- Architecture prompts are not anchored on unrelated Git patches and must answer every requested decision.
- Stage timing distinguishes tests, packet construction, provider work, and terminal verification; no operator-entered elapsed estimate is needed.
- A 40–70 KB Kimi patch is split below the measured `Read` limit and can be consumed without an overflow-artifact retry.
- Passing test output is summarized and broad synchronous test commands emit visible progress before provider launch.
- Codex-created Kimi sessions are recorded as `codex` without relying on the caller to remember an environment variable.
- Review class reflects measured patch size, changed-file count, and requested kind rather than always saying `small`.
- Healthy silent child survives the startup deadline after proving startup.
- Timeout and cancel target the exact owned process; PID reuse is refused.
- Repeated status/wait/cancel/recover are idempotent.
- Existing review continuation and implementation patch-recovery tests remain green.

### Windows PowerShell tests in `tests/test-kimi-windows-execution.ps1`

- Windows path quoting with spaces and backslashes.
- Effective `KIMI_CODE_HOME` path and write canary.
- ACL inspection reports the boundary without changing ACLs.
- Hidden detached worker survives parent/waiter exit.
- Redirected stdout/stderr files remain readable and bounded.
- Worker and Kimi child identity survive PowerShell/Git Bash process boundaries.
- Setup/doctor reports exact corrective action for restricted execution.
- No visible interactive console window is opened.

### Existing suites that must remain green

- `bash tests/test-ai-kimi.sh`
- `pwsh -NoProfile -File tests/test-windows-ai-kimi-shim.ps1`
- `bash tests/test-ai-install-skills.sh`
- the repository's normal broad test command documented in `docs/development.md` at implementation time.

### Bounded authenticated live tests

- New review, continuation, hostile-write canary, waiter-death survival, startup-denial, cancellation, and recovery from §9.7.
- Live tests must be opt-in, bounded, redacted, and run against a disposable fixture repository.
- Record Kimi version and requested model pin. Continue to report returned model/tokens/cost as unavailable unless Kimi's supported output begins supplying them and a new qualification proves it.

## 11. Constraints, standing rules, and gotchas

- Do not weaken Windows ACLs around OAuth credentials.
- Do not store secrets in this public repository. Reference paths and 1Password locations only; never values.
- Use `apply_patch` for edits and stage only this workstream's files.
- Verify `git var GIT_COMMITTER_IDENT` before the first commit. It must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Preserve the current structurally read-only Kimi review profile.
- Kimi tool names are case-sensitive. Lowercase names can silently produce a no-tools agent.
- `--agent-file` cannot be combined with session continuation. The profile is fixed at session creation.
- Never use `--continue`; resume the exact saved session ID.
- Kimi completion is the terminal `session.resume_hint`, not exit status, silence, PID existence, or verdict text.
- Kimi 0.32.0 exposes no trustworthy returned-model/token/cost metrics.
- `KIMI_CODE_HOME` moves credentials and sessions together. Treat it as a credential-bearing directory.
- The main Codex task and delegated tasks can have different Windows permissions. Always test the actual current process.
- Do not solve a wrapper timeout by increasing it. Startup failure and healthy long work need separate deadlines.
- Do not use machine-wide `pgrep kimi` as liveness for a specific job. Track the exact owned child and its terminal files.
- Kimi review sessions are directory-bound. Create them in their stable wrapper-owned workspace from turn one; never migrate a live review session by remote identity alone.
- Do not prepend a diff-review packet to plan, architecture, or analysis work.
- Do not create a Windows service or privileged broker without a new threat model and explicit owner approval.
- Do not edit the primary checkout's unrelated `.ai/` or documentation files.
- No database or production access is required.
- The plan is multi-phase. At the Phase C cut, start a fresh implementation session and re-read downstream steps before proceeding.

## 12. Access and environment

- Repository: `C:\repos\ai-devops`, remote `u2giants/ai-devops`.
- Planning worktree: `C:\repos\ai-devops-worktrees\issue-31-kimi-windows-plan`.
- Planning branch: `codex/issue-31-kimi-windows-plan`.
- Target branch: `main` through a reviewed PR because concurrent work exists.
- Machine: `al8960ofc`, Windows 11, PowerShell 7 and Git Bash.
- Kimi executable: `%USERPROFILE%\.kimi-code\bin\kimi.exe`, version `0.32.0` at planning time.
- Default Kimi home: `C:\Users\ahazan2\.kimi-code`.
- GitHub CLI is authenticated for `u2giants/ai-devops`.
- Kimi uses its existing per-user OAuth configuration. Do not copy or print it. If reauthentication is genuinely required, use Kimi's supported interactive login in the main user session; do not retrieve or manufacture OAuth files through 1Password.
- 1Password: no new secret is required by this plan. If implementation discovers a distinct API credential is necessary, stop and request approval before creating or rotating it; vault would be `vibe_coding`.
- No browser, Supabase, database, VPS, or cloud credentials are needed.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] Every STATUS row is complete with a reproducible artifact.
- [ ] Restricted execution fails in under five seconds with an automatic main-task hand-back.
- [ ] Main-task execution creates a durable job that survives waiter/caller death.
- [ ] Startup failures never wait to the full review deadline.
- [ ] An immediate directory-binding or provider failure returns in under five seconds even while another Kimi process is active.
- [ ] Concurrent repository edits cannot be misreported as Kimi writes or invalidate a private review workspace.
- [ ] Named review continuation always resumes from its original stable directory.
- [ ] Architecture and analysis reviews use decision packets and cannot approve an unrelated Git patch by prompt construction.
- [ ] Kimi metadata truthfully separates pre-provider test, packet, provider, and finalization elapsed time.
- [ ] A patch above 40 KB is paged for Kimi below its measured `Read` cap with a complete ordered map.
- [ ] Passing test output is bounded; broad test suites show progress and require explicit final-check intent.
- [ ] Codex and Claude sessions receive the correct caller identity automatically.
- [ ] Review class cannot remain `small` for a 25-file / 68 KB heterogeneous change.
- [ ] Healthy quiet reviews are not killed merely for silence.
- [ ] Exact completion still requires `session.resume_hint`.
- [ ] Review mode remains structurally read-only.
- [ ] No credential directory ACL is broadened and no credential is copied into a repo/worktree.
- [ ] Offline, Windows, installation, and bounded authenticated live tests pass.
- [ ] Independent exact-head review has no unresolved Critical/High/Medium finding.
- [ ] Documentation and model comparison separate model quality from execution reliability.
- [ ] Changes are committed as Albert, pushed, reviewed, CI-green where applicable, merged to `main`, installed, and verified from the installed command.
- [ ] Issue #31 closes only after merged installed live evidence.
- [ ] The plan and paired handoff are retired in the completion PR under the successor rule.

### Main risks and rollback

1. **Detached worker leaks or runs after cancellation.** Mitigation: exact PID identity, owned process tree, terminal cleanup, and live cancellation test. Rollback: disable detached mode through a documented fail-closed switch and revert to synchronous main-task execution while preserving preflight.
2. **Metadata says success too early.** Mitigation: only the worker finalizer can write `completed`, and only after terminal resume-hint validation. Rollback: treat all affected records as invalid and rerun reviews; never infer verdicts.
3. **Credential leakage through logs or metadata.** Mitigation: allowlisted fields, bounded redaction tests, and independent security review. Rollback: stop use, remove only wrapper-owned artifacts after evidence capture, and follow the secrets incident procedure. Do not rotate credentials without Albert's approval.
4. **Windows process detachment behaves differently under Codex.** Mitigation: live test in both direct PowerShell and the actual Codex execution path. If no safe detached primitive works, keep the preflight/main-task routing and use a foreground persistent terminal rather than a privileged service.
5. **Kimi CLI behavior changes after upgrade.** Mitigation: version gate and re-run the STEP 0 qualification on every version bump.

### Open questions for implementation evidence

- Which native detached-process primitive most reliably survives the initiating Codex tool boundary without opening a visible window? Decide from the §9.3 canary, not preference.
- Can Kimi's supported stream expose an earlier non-sensitive “session created” signal than output growth? If not, use process identity plus first valid stream record as startup proof.
- Does the then-current Kimi release still support `KIMI_CODE_HOME` exactly as documented? Recheck official docs and a disposable-home canary before code changes.

No owner decision is currently required. If implementation discovers that only a privileged broker or broader credential access can satisfy the goal, stop and ask Albert. Do not silently expand scope.

## Mandatory plan self-audit

1. **Could a brand-new AI session execute this plan without asking a question? Yes.** §§2, 5, 6, and 12 define the repository, files, exact current state, environment, version, issue, branch, and security boundary. §9 gives ordered file-level changes and a verification gate for every step.
2. **Does the plan carry all current background, nuance, and reasoning, including rejected approaches? Yes.** §§3 and 6 preserve the observed Windows failures and root causes. §7 records every attempted or tempting dead end, including wrapper-state relocation, ACL broadening, repo-local credentials, `HOME` replacement, a privileged broker, PID-only progress, and timeout/restart shortcuts.
3. **Is the ultimate goal clear enough to guide a correct judgment if a step is wrong? Yes.** §1 states the business outcome, the secure failure outcome, and the rule that the goal wins. §8 locks the credential, read-only, exact-session, durability, and no-fallback boundaries while leaving only evidence-driven implementation mechanics open.

Checklist result: all 13 required sections are present; scope exclusions, locked/open decisions, concrete tests, paths, identifiers, access, risks, rollback, landing, plan/handoff cross-links, and the self-audit are included. No secret value appears. The plan is ready for a zero-context implementation session.
