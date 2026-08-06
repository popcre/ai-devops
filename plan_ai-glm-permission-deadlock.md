# Implementation plan: make `ai-glm` permission deadlocks fail safely and immediately

## STATUS

| Step | State | Last updated | Evidence / next action |
|---|---|---|---|
| 1. Establish testable permission-response boundaries | ✅ done | 2026-08-05 | `permission_http` retains transport status/body; pure helpers are sourceable under guarded `main`. |
| 2. Implement fail-closed permission classification | ✅ done | 2026-08-05 | Only validated in-session V2 `resources[]` for read-like requests are approved; the generic 500 path uses measured running-read `filePath`, not elapsed polls. |
| 3. Integrate mode and session-directory context into turn polling | ✅ done | 2026-08-05 | Both review call sites pass repository root; implementation passes its remote-less clone. |
| 4. Add offline regression coverage | ✅ done | 2026-08-05 | 123 offline checks cover V2 resources, `external_directory`, replies, redaction, repeated IDs, and deterministic running-read boundaries. |
| 5. Capture the real OpenCode 1.18.12 outside-directory schema | ✅ done | 2026-08-05 | Final bounded live reproduction failed in ~12s with HTTP 200 action `external_directory`, `resources:["C:/tmp/*"]`, safe guidance, and no marker leak. Earlier transient generic 500s were proven non-specific and are never used as a timer. |
| 6. Finalize messages, docs, and skill guidance | ✅ done | 2026-08-05 | Troubleshooting, limitations, constraint, skill wedge guidance, and optional live regression updated. |
| 7. Run complete verification and land the change | ✅ done | 2026-08-05 | Syntax, 123 offline checks, doctor, diff, secret scan, bounded outside-read, and normal two-turn read/memory probes pass. No CI/deploy exists. Final follow-up commit/push recorded in repository history. |

Fresh session start: read this entire file, then `AGENTS.md` and section 5 of
`docs/glm-opencode.md`; begin at the first open STATUS row. Update this table as work
lands. Do not re-plan the locked decisions below.

## 1. The ultimate goal

Albert must never lose 30 minutes because GLM is silently waiting for an OpenCode
permission that nobody can approve. A repository-scoped GLM review or implementation
turn must either continue normally or fail quickly with a safe, specific explanation and
the exact corrective action. It must not broaden GLM's filesystem or command access to
make the error disappear.

Technically, `ai-glm` must classify every observable permission response from the pinned
OpenCode 1.18.12 server, approve only explicitly safe requests within the session
directory, and fail closed on external, malformed, unknown, or ineffective permission
states. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`u2giants/ai-devops` is a public backup-and-restore toolkit for Albert Hazan's multi-model
AI coding workflow. It is not a hosted application. Its Bash and PowerShell scripts
install and operate CLI helpers on Windows and Ubuntu machines. The relevant helper is
`bin/ai-glm`, which manages named persistent GLM 5.2 conversations through a locally
hosted, loopback-only OpenCode server pinned to version 1.18.12.

- Repository: `https://github.com/u2giants/ai-devops`
- Working copy for this plan: `C:\repos\ai-devops`
- Target branch: `main` (this repo's standing main-only policy)
- Baseline when the plan was written: `ad18473`, clean and synchronized with
  `origin/main`
- Runtime: Bash client on Windows or Ubuntu; OpenCode local service on
  `http://127.0.0.1:4096`; Z.ai GLM 5.2 provider
- Primary user: Albert and AI coding sessions using `ai-glm`
- Secrets: Z.ai and service credentials are resolved through 1Password vault
  `vibe_coding`; never print, copy, or commit their values

Review sessions are structurally read-only because
`config/opencode/agent/glm-review.md` disables write, edit, patch, Bash, webfetch, and
task tools. Implementation sessions use a disposable remote-less clone and intentionally
have write and Bash tools enabled; therefore permission handling must never assume the
two modes have identical risk.

## 3. What triggered this work

A GLM review turn in `/worksp/monitor/app` was instructed to read an absolute file under
`/tmp`, outside its session directory. It produced no output for the full 1,800-second
limit and ended with:

```text
GLM turn did not complete within 1800s (last finish='none', tool still running: read)
```

The same brief succeeded on a later attempt, and `ai-glm doctor` passed, showing that
service health alone cannot detect this situational permission deadlock.

Codex reproduced the failure independently on Windows on 2026-08-05:

1. `ai-glm doctor` passed all checks against OpenCode 1.18.12.
2. A marker file was created at `C:/tmp/ai-glm-outside-read-repro.txt`, outside
   `C:/repos/ai-devops`.
3. A review session was asked to read that absolute file.
4. With `--timeout 120`, it failed after 120 seconds with `tool still running: read` and
   a blank GLM response.
5. The session was aborted/deleted and the marker removed.

This proves the outside-session-directory failure class. It does **not** prove the raw
permission-response schema because the current client neither records the HTTP status nor
surfaces unmatched response entries.

## 4. Scope — in and out

### In scope

- Fail-closed permission classification in `bin/ai-glm`.
- Explicit review/implementation mode and session-directory context in turn polling.
- Safe, bounded error diagnostics.
- Offline fixture/mocked-helper tests and an optional live outside-directory regression.
- Accurate troubleshooting and hard-won-constraint documentation.
- Updating this plan's STATUS/current-state information as each step completes.

### NOT in this plan

- Upgrading OpenCode beyond pinned 1.18.12.
- Changing the GLM model, provider, authentication, caching, or persistent-session model.
- Enabling new tools or weakening either agent's `tools:` map.
- Blanket approval of all review permissions.
- Automatically copying arbitrary files into a repository.
- Parsing natural-language prompts for Windows, Unix, UNC, or URL paths.
- Adding `--attachment` or another file-ingestion feature.
- Adding a generic silence/tool-duration watchdog.
- Persisting failure artifacts under `.ai/reviews/`.
- Changing the strict completion rule (`finish == "stop"` plus two idle polls).
- Database, server-host, deployment, or UI work.

## 5. Current state of the code

- `bin/ai-glm:151-169`, `approve_read_permissions`, fetches the permission endpoint body
  but does not retain its HTTP status. It recognizes `InvalidRequestError`, otherwise
  extracts only `.data[]` entries whose `.action` is exactly `read` or `list`. Unknown
  envelopes, entries, fields, and malformed bodies result in no IDs and no error.
- `bin/ai-glm:187-218`, `await_turn`, calls that helper on every five-second poll. It does
  not know whether the turn is review or implementation and does not know the OpenCode
  session directory. Only the special `InvalidRequestError` path fails early; everything
  else may wait for `TIMEOUT`, which defaults to 1,800 seconds.
- `bin/ai-glm:321`, `:345`, and `:406` call `await_turn` from new review, continued
  review, and implementation paths respectively. These sites already know the mode and
  directory and must pass them explicitly.
- `config/opencode/agent/glm-review.md:5-16` contains the structural review tool controls.
- `config/opencode/agent/glm-implement.md:5-16` enables write and Bash in a disposable
  clone. It must never receive blanket permission approval.
- `tests/test-ai-glm.sh:1-172` contains dependency-light offline checks; the present
  permission assertion at line 168 only greps for `InvalidRequestError`.
- `tests/test-ai-glm.sh:173-209` contains opt-in live tests gated by `AI_GLM_LIVE=1`.
- `docs/glm-opencode.md:175-181`, `:240-256`, and `:261-350` describe troubleshooting,
  limitations, and 23 hard-won constraints.
- `skills/shared/ask-glm/SKILL.md` tells an agent how to handle wedged turns and must
  reflect the new fail-fast behavior.

Implementation is complete in the working tree. `bin/ai-glm` now preserves HTTP status,
classifies every permission response, bounds and redacts diagnostics, detects ineffective
approvals, and receives explicit mode/directory context. Offline fixture tests and an
optional live outside-directory regression are present. The measured OpenCode 1.18.12
outside-read response is HTTP 200 with action `external_directory` and a V2
`resources:["C:/tmp/*"]` pattern. The client fails that unallowlisted action immediately.
Earlier transient HTTP 500 `UnknownError` responses were also seen with no permission and
ordinary tools, so they are explicitly not treated as a time-based deadlock signal. The
running read's measured `state.input.filePath` is the only deterministic fallback boundary.
Commit/push evidence is recorded in STATUS step 7.

## 6. Key findings and root cause

### Proven

1. An outside-session-directory `read` can remain running with no assistant output until
   the overall timeout.
2. The permission loop silently ignores anything not matching its one assumed envelope
   and two action values.
3. The HTTP 400 `InvalidRequestError` case already has a dedicated fail-fast guard, so
   the reproduced timeout followed a different observable path.
4. Review and implementation safety differ: only the agent-file `tools:` map has been
   measured as effective; implementation intentionally has powerful tools.
5. The local server is pinned to 1.18.12, so behavior must be measured against that
   version rather than inferred from newer OpenCode documentation.

### Still an inference until step 5

The outside-directory request may use an unexpected action such as
`external_directory`, a field other than `.action`, a bare-array envelope, an empty
permission endpoint while the request is represented elsewhere, or another 1.18.12
shape. The implementation must capture sanitized evidence before locking in aliases.

### Root cause statement

`ai-glm` treats unrecognized permission state as absence of permission state. Because
there is no human approval channel, an unmatched or ineffective request can never make
progress, yet the client waits as if GLM were still legitimately working.

## 7. Approaches considered and rejected

1. **Approve every pending request in review mode.** Rejected. A permission can widen
   the reach of an existing read tool into credential locations. Structural removal of
   write/Bash tools does not make unrestricted filesystem reads safe.
2. **Approve everything in all modes.** Rejected absolutely. Implementation sessions
   have write and Bash capabilities.
3. **Add a three-minute silence watchdog.** Rejected. Current endpoints do not expose a
   reliable progress signal, and legitimate reads/reasoning may be quiet. Observable
   permission failures can be classified directly without a timing heuristic.
4. **Dump the raw permission response.** Rejected as phrased. Paths and metadata may be
   sensitive. Diagnostics must be redacted first and then capped at 2 KB.
5. **Write failure reports under `.ai/reviews/`.** Rejected. That directory currently
   represents completed review artifacts; stderr is sufficient and avoids a new
   persisted sensitive-data surface.
6. **Detect absolute paths in prompt prose and copy/refuse before sending.** Rejected.
   Natural language and cross-platform path syntax make this unreliable. Automatic copy
   creates secret, size, and semantic risks.
7. **Add a Python fake HTTP server to offline tests.** Rejected. The repository's tests
   are deliberately dependency-light. Pure Bash classification fixtures and mocked HTTP
   helper functions cover the logic; an opt-in live test covers real integration.
8. **Use the existing 400 guard as proof of the cause.** Rejected. The reproduction hit
   the ordinary timeout, not the tailored 400 failure.

## 8. Locked and open design decisions (2026-08-05)

### Locked — do not relitigate

- Fail closed; never silently ignore nonempty, malformed, unknown, or unsafe permission
  state.
- No blanket approval in either mode.
- Approvals are limited to measured repo/session-directory-scoped read-like operations.
- Outside-session-directory access fails immediately with safe corrective guidance.
- Review/implementation mode and session directory are explicit inputs to the poller.
- No generic stall timer, prompt path parser, auto-copy, attachment feature, or failure
  artifact in this change.
- Diagnostics go to stderr, are redacted before truncation, and include no more than
  2 KB of response detail.
- Preserve the overall 1,800-second timeout and strict completion rule.
- Tests stay dependency-light; real API behavior is covered under `AI_GLM_LIVE=1`.

These decisions were debated with Kimi K3 in persistent session
`session_38cf315f-18cd-4cb3-af31-e3df6acaadfe`, which ended in explicit consensus.

### Open only where evidence is required

- The exact 1.18.12 envelope and field names for outside-directory requests.
- Whether a successfully replied permission disappears immediately or needs one poll to
  clear. Default safely to failure if the same ID survives two consecutive polls after
  approval; tighten to one only if the live measurement proves immediate clearing.
- Exact helper names and internal decomposition, provided behavior and tests remain as
  specified.

## 9. Ordered implementation plan

### Step 1 — create testable permission-response boundaries

Change `bin/ai-glm` around `api`, `approve_read_permissions`, and `await_turn` so the
permission GET and reply POST return both transport outcome and HTTP status without
printing credentials. Separate pure parsing/classification/redaction logic from the curl
wrapper so tests can feed fixtures without a server. Keep production execution behind
the existing top-level command dispatch; if sourcing functions for tests, add a guarded
main entry rather than a hidden production CLI option.

The classifier input must include: mode (`review` or `implement`), canonical session
directory, HTTP status, and response body. Normalize paths with an existing platform-safe
mechanism; do not compare raw strings when Windows path separators/case differ.

Verification gate: `bash -n bin/ai-glm` succeeds; existing offline CLI contract tests
still pass; pure helpers can be exercised by `tests/test-ai-glm.sh` without starting the
OpenCode service.

### Step 2 — implement fail-closed classification and diagnostics

Replace `approve_read_permissions` with behavior that:

1. Treats a valid empty response as no pending permission.
2. Preserves tailored handling for the measured `InvalidRequestError` response.
3. Parses only measured 1.18.12 schemas; accept both `{data:[...]}` and a bare array only
   if fixtures/live evidence support them.
4. Validates every nonempty entry, including its ID, permission/action/tool category,
   and path metadata where supplied.
5. Approves only safe `read`, `list`, `glob`, or `grep` requests whose target remains
   inside the canonical session directory. Mode remains part of classification even if
   the initial allowlist is identical, preventing future unsafe reuse.
6. Fails immediately for external paths, unknown/missing fields, malformed JSON,
   non-success HTTP responses, or non-success reply POSTs.
7. Tracks approved IDs; if an ID remains pending for two consecutive polls after a
   successful reply, fail as an ineffective approval. Do not wait three minutes.
8. Emits a one-line primary error plus a bounded diagnostic. Redact known secret/token/
   authorization/value fields and any file content before taking the first 2 KB. Include
   status, mode, tool/action category, path category (`inside`, `outside`, `missing`,
   `invalid`), and truncation notice. Never label sanitized output as raw.
9. Tells an outside-directory caller to place a safe copy under the session repository
   or provide a small safe excerpt, then run `ai-glm abort <name>` before retrying.

Verification gate: fixture tests prove every unknown or unsafe nonempty state exits
nonzero immediately, safe in-directory read-like entries return only validated IDs, and
diagnostics contain neither fixture secrets nor more than 2 KB of response detail.

### Step 3 — pass mode and session directory through turn execution

Update `await_turn` and its call sites:

- `cmd_new`: `review` plus `$root`.
- `cmd_ask`: `review` plus `$root`.
- `cmd_implement`: `implement` plus the disposable clone directory (`$sb` in the current
  code; use the actual local variable at implementation time, currently `sb`, not the
  parent repository root).

Keep session name available for abort guidance. Do not alter completion polling,
locking, model verification, disposable-clone cleanup, or review git-status tripwire.

Verification gate: static and behavioral tests prove all three call sites pass the
correct mode/directory; normal review and implementation live probes still finish.

### Step 4 — add comprehensive offline regression tests

Extend `tests/test-ai-glm.sh` with fixture-driven tests for:

- empty `{data:[]}` and empty bare array;
- known in-directory `read`, `list`, `glob`, and `grep` entries;
- review and implementation directory roots;
- Windows-style and Unix-style canonical paths where the helper supports them;
- outside-directory request;
- unknown action/tool;
- missing ID, missing path, malformed JSON, and unsupported envelope;
- `InvalidRequestError` and other non-success status;
- permission reply POST failure;
- an approved ID clearing normally;
- the same ID surviving two post-approval polls;
- redaction of fields named like token, authorization, secret, credential, password, and
  content/value;
- diagnostic truncation at 2 KB after redaction;
- existing 1,800-second default and strict completion rule remaining intact.

Mock the permission HTTP helper as a Bash function or fixture input. Do not require
Python, `nc`, network access, a live key, or OpenCode for the offline suite.

Verification gate: `bash tests/test-ai-glm.sh` reports zero failures on Windows Git Bash
and Ubuntu-compatible Bash.

### Step 5 — capture and encode the real 1.18.12 schema safely

With diagnostic code in place, create a temporary marker outside a temporary test repo
and run a new review session with a short explicit timeout. Ask it to read only that
marker. The expected result is now a fast, nonzero, outside-directory permission error,
not a timeout. Inspect only the sanitized diagnostic; do not call OpenCode directly and
do not print credential-bearing headers. Abort/delete the session and remove the marker.

Use the evidence to finalize exact field/envelope mappings and reply-clearing behavior.
Do not broaden aliases speculatively. Add the captured shape as a secret-free fixture.

Verification gate: the reproduction exits well below the overall timeout, names the
outside-directory boundary, suggests the safe correction, leaks no marker contents or
secrets, and its measured response fixture passes offline tests.

### Step 6 — add the optional live regression and update guidance

Under `AI_GLM_LIVE=1` in `tests/test-ai-glm.sh`, add a bounded outside-directory
regression with guaranteed cleanup. Give it its own unique session name and marker. It
must assert quick nonzero failure and the corrective message, then abort/delete the
session even when an assertion fails.

Update:

- `docs/glm-opencode.md` diagnosing table, known limitations, and hard-won constraints;
- `skills/shared/ask-glm/SKILL.md` wedge guidance;
- this plan's STATUS and current-state sections;
- the discoverability links in `AGENTS.md` and the GLM topic doc when the plan is
  complete (delete completed-plan links only if the plan itself is deleted after all
  work lands).

Verification gate: docs distinguish the proven failure behavior from the historical
400 case and never recommend blanket approval or automatic copying.

### Step 7 — complete verification and land

Run, in order:

1. `bash -n bin/ai-glm`
2. `bash tests/test-ai-glm.sh`
3. `AI_GLM_LIVE=1 bash tests/test-ai-glm.sh`
4. `ai-glm doctor`
5. A normal two-turn review session proving read, response, memory, and cleanup.
6. `git diff --check`
7. Secret-pattern review of the exact diff without printing real config values.
8. Verify commit and committer identity with `git var GIT_COMMITTER_IDENT`.
9. Commit only this plan's implementation and documentation, push `main`, and verify the
   remote SHA matches local. There is no CI workflow or deployment for this repo; record
   those gates as N/A with evidence rather than claiming they ran.

Verification gate: all applicable commands pass, the working tree is clean, local and
`origin/main` point to the same new commit, and the plan STATUS table accurately records
completion.

## 10. Tests required

The exact offline and live cases are enumerated in steps 4–7. Minimum acceptance:

- Existing offline tests remain green.
- Every nonempty permission response is either explicitly approved or explicitly failed;
  none can fall through silently.
- External-directory access fails quickly and safely.
- Safe session-directory reads continue working.
- Review and implementation live probes remain functional.
- The 400 wedge message, strict completion rule, model pin, review structural controls,
  disposable clone, and git-change tripwire retain regression coverage.
- Tests clean all sessions, markers, temporary repos, and `.ai` artifacts they create.

## 11. Constraints, standing rules, and gotchas

- Work on `main`; this repo's default policy is main-only.
- Before committing, verify author **and committer** are
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- GitHub is the source of truth. Do not edit installed runtime copies independently of
  the repository.
- OpenCode stays pinned at 1.18.12. Do not use newer-version schema documentation as
  evidence for this implementation.
- Use `ai-glm`; never call OpenCode or its HTTP API directly outside the client/test
  abstraction.
- The `tools:` maps are load-bearing safety controls. Do not weaken them.
- Implementation sessions use disposable **clones with the remote removed**, not Git
  worktrees. Preserve that design.
- No silent fallbacks. Unknown state must fail loudly.
- Windows paths, Git Bash paths, and Unix paths differ; canonicalization tests must cover
  the supported forms without hard-coded machine usernames.
- Real secrets stay in 1Password vault `vibe_coding`. Never read or log them for this
  work. Serialize any 1Password reads if unexpectedly needed.
- Do not modify PowerShell files for this change. If scope unexpectedly reaches one,
  preserve the repo rule that `.ps1` files are pure ASCII.
- Other agents may use this checkout concurrently. Recheck status before pull, commit,
  or push; preserve unrelated work and stage only owned files.
- This is not a UI task, database change, server-host change, or deployment.

## 12. Access and environment

- `gh`, Git, Kimi K3, `ai-glm`, and the local OpenCode scheduled service were available
  when planning.
- `ai-glm doctor` passed locally on 2026-08-05 after starting the existing scheduled
  service; no configuration mutation was needed.
- The OpenCode service is local and authenticated. The client owns the base URL,
  credentials, and API shapes.
- Windows invocation uses PowerShell for orchestration and Git Bash for Bash scripts.
- Live tests consume real GLM provider access and therefore remain opt-in through
  `AI_GLM_LIVE=1`.
- No browser clicks, production credentials, cloud mutations, database access, or test
  login is required.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] All STATUS rows are updated with dates and evidence.
- [ ] `bin/ai-glm` fails closed for every observable permission error class.
- [ ] Outside-session-directory reads fail quickly with safe guidance.
- [ ] Safe in-directory reviews and implementations still work.
- [ ] Offline and opt-in live tests pass.
- [ ] `ai-glm doctor` passes.
- [ ] Documentation and shared skill guidance are current.
- [ ] No secret values or temporary artifacts exist in the diff/worktree.
- [ ] Commit identity is correct.
- [ ] Changes are committed and pushed to `main`; remote SHA is verified.
- [ ] CI is recorded as N/A because this repository has no workflow.
- [ ] Deployment is recorded as N/A because this toolkit has no deployed application.
- [ ] This plan is either retained with a completed STATUS table or removed only after
      its durable findings have been incorporated into canonical docs.

### Risks and mitigations

- **False failure from schema assumptions:** capture the real 1.18.12 shape before
  finalizing mappings; fail unknown rather than guess.
- **Sensitive diagnostic leakage:** redact before truncation; test representative secret
  fields; never include headers or file contents.
- **Path-containment bypass:** canonicalize and test traversal, separators, and case;
  compare paths, not string prefixes.
- **Approval-clear race:** allow two consecutive post-reply polls until live evidence
  supports tightening.
- **Regression of long legitimate tools:** do not add a generic stall watchdog; retain
  the 1,800-second overall bound.
- **Live-test cleanup failure:** install cleanup traps that abort/delete sessions and
  remove markers on success, failure, or interrupt.

Rollback is a normal Git revert of the implementation commit because there is no schema,
host, or deployed state. If rollback is necessary, restore the previous client behavior
but keep a durable incident note; do not manually patch installed binaries.

Open questions are limited to the measured schema and reply-clearing timing described in
section 8. The evidence criteria in step 5 resolve both; they are not invitations to
redesign the locked safety policy.

## Mandatory self-audit

1. **Could a brand-new AI session execute this perfectly without questions? Yes.**
   Sections 2–6 explain the toolkit, environment, incident, current code, and root cause;
   sections 8–9 lock decisions and give file/function-specific ordered steps with a
   verification gate for every step; sections 10–13 supply exact tests, constraints,
   access, landing, and rollback requirements.
2. **Does the plan carry all current background, nuance, and rejected reasoning? Yes.**
   Section 3 records both incidents and the limit of the evidence; sections 6–8 separate
   proof from inference, document every debated rejection, and preserve the Kimi K3
   consensus and two measured open questions.
3. **Is the goal clear enough for correct judgment when a step is wrong? Yes.** Section 1
   states the business outcome, the safety boundary, and explicitly makes the goal
   override conflicting steps. Sections 4 and 8 define the scope and locked decisions.

Checklist result: all 13 required sections are present; the ultimate goal and override
rule lead the plan; scope exclusions, rejected approaches, locked/open decisions, exact
tests, access, risks, rollback, commit/push verification, and N/A CI/deploy gates are all
explicit. **Self-audit passed on 2026-08-05.**
