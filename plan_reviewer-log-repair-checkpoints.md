# IMPLEMENTATION PLAN — Reviewer log repair checkpoints (2026-09-07)

## STATUS

| Step | Status | Updated | Evidence |
|---|---|---|---|
| 1. Define the checkpoint and maintenance-round schemas | Complete | 2026-09-08 | Versioned validation in `tools/reviewer_maintenance.py`; schema and refusal fixtures passed |
| 2. Add safe source discovery and bounded interval reading | Complete | 2026-09-08 | Exact boundaries, prefix/file identity checks, nine-provider durable journal and scoreboard cross-check |
| 3. Add maintenance-round start, inspect, and complete commands | Complete | 2026-09-08 | Installed two-round proof passed; immutable records, exact inherited boundary and parent chain |
| 4. Join discovered failures to the incident ledger | Complete | 2026-09-08 | Exact joins, explicit classification and carry-forward tested; original evidence preserved |
| 5. Add tests for normal, concurrent, rotated, truncated, and failed rounds | Complete | 2026-09-08 | All three CI suites passed in run `34173126280`; exact merge queue passed in `34178027688` |
| 6. Update operating instructions and install the finished tool | Complete | 2026-09-08 | Canonical EDGE-DEV installation and both shared skill copies verified; configuration preserved |
| 7. Independently review, merge, install, and prove the first live round | Complete | 2026-09-08 | PR #314 merged as `f1facf60189670b43e07b95399a769eedb493cf1`; exact-head APPROVE and [redacted installed proof](tests/verification/reviewer-reliability/issue-308-checkpoints.md) |

**Fresh-session start:** This checkpoint implementation and EDGE-DEV rollout are
complete. Read the [verification record](tests/verification/reviewer-reliability/issue-308-checkpoints.md)
for exact source, tests, review, installation and controlled two-round evidence.
The real backlog was not cleared; its first maintenance round still requires a
private legacy audit. The separate default Qwen fast-check limitation is tracked
in [issue #322](https://github.com/popcre/ai-devops/issues/322), not unfinished
checkpoint implementation.

**Handoff retired:** The [predecessor planning handoff](https://github.com/popcre/ai-devops/blob/15d696cdf5b3c90e1d1b9df9dd52dddffba5ffab/HANDOFF.d/2026-09-07T1647Z-edge-dev-codex-reviewer-log-checkpoints.md)
is preserved in Git history. Its commit is on main, its obligations are fulfilled,
and its unique decisions and rejected approaches remain in this plan.

## 1. The ultimate goal — what we are trying to achieve

After a reviewer-repair round is fully completed, the next maintenance session must be able to prove exactly where the previous round stopped and inspect only reviewer activity that happened after that point. It must be impossible to advance the boundary while a discovered failure is unrecorded, incompletely repaired, or unsupported by closure evidence. Albert should receive a truthful answer to “what is new since the last completed repair round?” without rereading old logs or trusting a date remembered by a person.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is a public backup-and-restore toolkit for Albert Hazan's multi-model reviewer workflow. It contains shell and PowerShell commands, reviewer wrappers, tests, skills, and operating documentation. It is not a hosted application and has no application deployment or database.

The affected command is `bin/ai-reviewer-issue`, a Bash tool installed as `ai-reviewer-issue` on Windows and Linux machines. It stores private, machine-local incident packages below `.ai/reviewer-issues/` in the installed toolkit checkout. Provider lifecycle state and logs normally live below the machine-local state base (`AI_REVIEWER_STATE_BASE`, defaulting to `~/.local/state/ai-devops`). The performance ledger defaults to `review-scoreboard/reviews.jsonl` below that state base.

Repository work uses a feature branch and pull request to protected `main`. GitHub Actions is the deployment-quality gate. Installation onto each relevant machine is the operational deployment mechanism.

## 3. What triggered this work

On 2026-09-07 Albert asked whether completed reviewer repairs establish a boundary so the next repair begins only with problems occurring since the last fix. Inspection showed that the incident lifecycle tracks creation and resolution, but no durable log-scan high-water mark exists.

The gap is reproduced conceptually as follows:

1. Record and resolve all currently known incidents.
2. Run `ai-reviewer-issue list`; it correctly reports each incident's latest status.
3. Ask which provider log records were examined during that repair round and where the next scan must start.
4. No command or state file can answer. A new failure that was written to a provider log but never recorded as an incident can therefore be missed.

GitHub issue [#308](https://github.com/popcre/ai-devops/issues/308) owns the implementation and closure.

## 4. Scope — in and out

### In scope

- Add an append-only, machine-readable maintenance-round ledger to the existing private reviewer-issue storage.
- Record a lower boundary inherited from the last completed round and a frozen upper boundary captured when a new round starts.
- Discover and inspect only the closed interval between those boundaries.
- Detect log rotation, replacement, truncation, or disappearance and fail closed rather than skipping unknown content.
- Join every discovered reviewer failure to an existing or newly recorded incident.
- Refuse to complete a round until each discovered failure has exactly one accountable outcome and every repair claim satisfies the existing resolution-evidence rules.
- Make the current completed boundary and unfinished rounds easy to show.
- Preserve all existing incident packages and resolution records in place.
- Update tests, documentation, installed skills, and repository routing.

### NOT in this plan

- Moving resolved incident packages to a `resolved.md` file or any archive directory.
- Committing private reviewer logs, incident evidence, prompts, credentials, or machine-local checkpoints.
- Automatically diagnosing or repairing reviewer code.
- Treating expected provider refusals, quota exhaustion, user cancellations, or unrelated application failures as reviewer defects without classification.
- Changing provider-specific reviewer safety boundaries, formal approval rules, reviewer assignment, merge policy, or the performance-scoreboard contract.
- Creating a centralized cross-machine cloud service. Version 1 is machine-local because its evidence sources are machine-local.
- Deleting or compacting old incident packages. Retention policy may be designed separately only if privacy or disk usage later requires it.

## 5. Current state of the code

The merged implementation and installed evidence are described in STATUS and the
verification record above. The following is the **historical planning baseline**;
its line references and missing-capability descriptions are retained as context.

- `bin/ai-reviewer-issue:22` selects the private incident directory; `:158-168` reads the reviewer scoreboard; `:170-287` records one immutable incident package.
- `bin/ai-reviewer-issue:268-281` writes `issue.json` schema version 3 with `created_at`, exact join identifiers, repository identity, machine identity, and captured evidence counts.
- `bin/ai-reviewer-issue:290-302` lists all incidents and derives `open`, `partially-resolved`, or `resolved` from the newest append-only resolution.
- `bin/ai-reviewer-issue:305-318` displays an incident joined to its latest resolution.
- `bin/ai-reviewer-issue:320-388` validates a repair commit and evidence, then appends a resolution containing `resolved_at` rather than altering original evidence.
- `docs/reviewer-issues.md:96-120` defines the closure audit: every affected local incident must be resolved or explicitly left partial/open before a repair is claimed complete.
- `tests/test-ai-reviewer-issue.sh` covers recording, exact evidence joins, missing/ambiguous evidence, path-containment protection, resolution validation, and concurrent resolution writers.
- There is no scan/audit/maintenance-round command, no checkpoint schema, no frozen scan interval, and no test proving rotation/truncation safety.
- Planning artifacts are on branch `codex/reviewer-log-checkpoint-plan` from `origin/main` commit `ab87112c`. The plan is documentation only; no runtime change is committed, pushed, installed, or live-proven yet.

## 6. Key findings and root cause

1. **Incident closure is not log coverage.** `list_issues` derives status solely from incident folders (`bin/ai-reviewer-issue:290-302`). It cannot detect a failure that exists only in a provider log.
2. **Timestamps alone are not a safe boundary.** Several records can share a timestamp, clocks can differ, and a log can rotate or be truncated. A timestamp-only “since” filter can silently skip records.
3. **Moving resolved items would damage the current design.** `docs/reviewer-issues.md:113-116` deliberately makes the original incident and its resolution an append-only unit. Moving it to Markdown would create a second, non-machine-readable source of truth and could separate private evidence from its status.
4. **The boundary must be transactional.** If the tool writes a new checkpoint before all findings are classified and repaired, a later session will start too late and lose work. A started round and a completed checkpoint must therefore be distinct states.
5. **The upper boundary must be frozen at round start.** Logs can continue changing during maintenance. Freezing the upper bound prevents an endless moving target; later entries belong to the next round.
6. **Existing exact joins should be reused.** `bin/ai-reviewer-issue:190-245` already protects evidence capture with provider, repository, head, run/session, caller, and source digest. The new reconciliation must refer to these durable identities when available rather than guessing by proximity.
7. **Private state must stay local.** Incident packages and raw logs can expose private repositories and provider sessions. Checkpoint records belong beside `.ai/reviewer-issues/`, not in Git.

## 7. Approaches considered and REJECTED, and why

1. **Move completed issues into `resolved.md`. Rejected and LOCKED.** It duplicates status, loses structured joins, creates a shared mutable file, complicates concurrent writers, and encourages private evidence summaries to enter a public repository. Resolved incidents remain where they are with append-only resolution JSON.
2. **Move resolved incident directories into a separate archive. Rejected and LOCKED.** Directory presence currently has no status meaning; `list` derives status safely. Moving folders would break stable paths and add race-prone migration/lookup logic without solving log coverage.
3. **Use only `resolved_at` as the next lower boundary. Rejected.** Resolution time describes repair evidence, not which log bytes or records were inspected.
4. **Use only file modification time. Rejected.** Modification time has coarse resolution and does not prove file identity or content continuity.
5. **Use only byte offset. Rejected.** An offset is unsafe after rotation, replacement, or truncation and ambiguous for mutable non-line-oriented artifacts.
6. **Mark each old log entry as processed in place. Rejected.** Provider logs are evidence and may be owned by other tools; mutating them violates immutability and can corrupt diagnostics.
7. **Advance the checkpoint when fixes are coded or tests pass. Rejected.** Completion requires incident reconciliation plus repair commit, required tests, independent review where applicable, installation, and live evidence for the affected behavior.
8. **Scan indefinitely until logs stop changing. Rejected.** Reviewer activity may be continuous. Each round uses a frozen upper bound; later activity is intentionally deferred.

## 8. Design decisions already made (2026-09-07)

### Owner-authorized source prerequisite, 2026-09-07

Inventory proved that the seven advisory wrappers do not preserve a complete
append-only history in their reusable session metadata. Albert explicitly
authorized including durable recording in this task. All nine registered
wrappers therefore share a start/terminal invocation journal; existing wrapper
permissions, provider calls, credential boundaries, report gates, and cancellation
remain owned by the original wrappers. The scoreboard remains a separate required
cross-check. Supporting metadata and raw transcripts are not mistaken for an
append-only event ledger.

The journal establishes forward coverage from installation. It cannot recover
overwritten earlier turns. The first checkpoint requires a private `legacy_audit`
of existing evidence, and includes every existing unresolved incident; any unknown
historical gap prevents a truthful real-world completion. A controlled fixture
proof demonstrates installation and resumption without asserting a real backlog
clear. Only the current EDGE-DEV installation is in this task's host scope;
Windows and Linux CI both remain required, and no fleet-wide checkpoint is claimed.

An unfinished invocation may be explicitly classified `in-progress` with current
worker evidence. It is carried until its exact terminal event arrives, so freezing
the interval does not require all reviewers to become idle. Unconfirmed dead
workers remain findings requiring investigation. Partial incident repairs use a
separate immutable carry-forward record. Python 3 is reused from the existing
installer dependency set; the shared helpers stay under `tools/`, owned by #308.

### LOCKED — do not relitigate

- The incident directory remains the single source of truth. Original evidence and append-only resolutions stay together.
- No `resolved.md` archive will be created.
- Checkpoint state is private, local, machine-readable, append-only, and stored below the existing reviewer-issue directory.
- A round has `started` and `completed` records. Only a completed record becomes the next lower boundary.
- Round start freezes an upper boundary for every discovered source. Writes after it belong to the next round.
- Each source boundary must combine stable record identity where available with continuity evidence. For JSONL ledgers, use the last complete line's digest plus byte offset and size. For referenced log files, record canonical path, file size, modification time, and a digest of content through the boundary; record platform file identity when available but do not rely on it alone.
- Rotation, replacement, truncation, an unterminated final line, unreadable source, invalid JSONL, or continuity mismatch blocks completion and names the exact source. It never silently resets to zero or skips forward.
- Every newly observed candidate has one outcome: linked existing incident, newly recorded incident, or explicitly classified non-defect with reason and evidence. No candidate may disappear from the round.
- A round cannot complete while a linked incident remains open. `partially-resolved` is allowed only when the round completion explicitly carries the remaining problem forward as a candidate in the next round; otherwise completion is refused.
- Checkpoint completion is written atomically only after the reconciliation audit passes.
- Existing closure proof requirements remain unchanged and cannot be weakened to make a round pass.

### OPEN — implementer's bounded judgment

- Exact command naming may be `maintenance start/show/complete` or `audit start/show/complete`. Choose the form that keeps help text unambiguous and avoids breaking existing commands.
- The schema may use one JSON file per immutable round plus a small atomically replaced `latest-completed.json` pointer, or derive latest completion by sorted immutable filenames. Prefer derivation unless measured performance justifies a pointer.
- Provider-specific lifecycle metadata may be the primary scan source, with the scoreboard as a required cross-check. The implementer must inventory actual wrapper state first and document any provider lacking a durable structured source; no provider may be silently omitted.

## 9. The plan — numbered, ordered steps

### Phase 1 — Contract and source inventory

1. **Define versioned schemas and invariants.** Add documented JSON schema examples under `config/` or validation functions within `bin/ai-reviewer-issue`, covering round ID, host, tool version, start/completion timestamps, lower and upper boundaries per source, continuity fingerprints, candidate outcomes, linked issue IDs, proof references, and completion status. Update the tool usage text. Dependency: none. **You'll know it worked when** a schema-validation test accepts a complete fixture and rejects missing boundaries, duplicate candidate outcomes, unknown statuses, and a completion without proof.

2. **Inventory every structured reviewer evidence source before coding readers.** Read the current reviewer registry, lifecycle command, provider adapters, metadata locations, and scoreboard contract. Record the inventory in `docs/reviewer-issues.md`, including which sources are authoritative for event discovery versus supporting evidence. Dependency: Step 1's conceptual schema, but this investigation can begin in parallel. **You'll know it worked when** every registered reviewer has an explicit source classification and the test fixtures cover each source shape; “not discoverable” must be an explicit blocking classification, never omission.

**Context cut 1:** If a new session begins here, re-read Sections 6–8 and all remaining phases before editing.

### Phase 2 — Safe bounded reader

3. **Implement source snapshots and continuity checks in `bin/ai-reviewer-issue`.** Add contained-path helpers and atomic-write helpers. At round start, capture the last complete record/byte for each source and retain a digest that proves the next reader starts from the same content. Never follow symlinks outside approved state roots. Dependency: Steps 1–2. **You'll know it worked when** focused tests prove unchanged append-only files resume correctly; same-timestamp records are not lost; writes after the frozen upper bound are excluded; and rotated, replaced, truncated, linked, malformed, or unreadable sources block with a precise error.

4. **Implement candidate extraction without making diagnosis decisions.** Read only the verified interval and produce immutable candidate records containing source identity, durable event/run/session identifiers, timestamp, provider, caller, repository/source identity when known, failure classification, and a redacted evidence reference. Do not copy secrets or raw prompts. Dependency: Step 3. **You'll know it worked when** fixtures containing old events, new failures, new successes, duplicates, and post-snapshot writes yield exactly the expected candidate set with stable IDs across repeated reads.

### Phase 3 — Maintenance-round lifecycle

5. **Add the start/show commands.** `start` must refuse a second live round unless the operator explicitly resumes the same round; capture lower/upper boundaries and candidates into an immutable started-round record. `show` must report the last completed boundary, the active round if any, counts by outcome, and exact blockers without exposing private content. Dependency: Steps 3–4. **You'll know it worked when** a test starts a round, reruns safely without duplication, reports its fixed interval, and shows a failure written after start as deferred rather than included.

6. **Join candidates to incident records.** Extend recording or add a narrow link command so every defect candidate can reference exactly one incident ID. Refuse nonexistent incident IDs, provider mismatches, incompatible exact run/session joins, and duplicate/conflicting links. Allow an explicit non-defect classification only with a controlled reason and evidence reference. Dependency: Step 5 and the existing `record` contract. **You'll know it worked when** tests prove every candidate has exactly one outcome, exact joins succeed, guessed proximity joins fail, and non-defect classifications remain auditable.

7. **Add atomic completion.** The completion command must audit all candidates, validate linked issue status and repair evidence, require a carry-forward record for any partially resolved incident, and write a completed-round record atomically. A failed completion leaves the previous checkpoint unchanged and preserves the active round. Dependency: Steps 5–6. **You'll know it worked when** tests prove unclassified/open candidates, missing commits/evidence, source continuity changes, or write failure cannot advance the checkpoint, while a fully reconciled round advances exactly once.

**Context cut 2:** Before continuing in another session, update this STATUS table and current-state section, then re-read Sections 10–13.

### Phase 4 — Qualification and operations

8. **Expand `tests/test-ai-reviewer-issue.sh` and CI registration if needed.** Add named cases for first-ever round, empty interval, normal append, equal timestamps, active-round resume, concurrent starters/completers, crash before completion, idempotent completion, late writes, rotation, truncation, replacement, malformed final record, symlink escape, redaction, duplicate events, exact incident join, partially resolved carry-forward, and rollback after write failure. Dependency: implemented commands. **You'll know it worked when** the focused suite passes on Git Bash/Windows and Linux, with all new assertions counted by the test harness and no existing assertion removed.

9. **Update `docs/reviewer-issues.md`, `skills/shared/log-reviewer-issue/SKILL.md`, tool help, and `AGENTS.md`.** The repair workflow must begin by showing/resuming the last round, inspect only the bounded interval, and complete the round only after the existing closure audit. State plainly that resolved incidents remain in place and no Markdown archive exists. Dependency: behavior and command names finalized. **You'll know it worked when** documentation parity/context audits pass and a fresh operator can follow the documented commands without this plan.

10. **Run repository verification, exact-head independent review, and PR landing.** Because this changes reviewer evidence tooling and safety tests, obtain one read-only exact-head final review before merge. Verify Git identity before committing; stage only task-owned files; push a feature branch; open the PR; use `bin/ai-pr-wait <pr>` for bounded CI/merge-queue waiting; fix failures; merge through the queue; confirm the exact commit on `origin/main`. Dependency: Steps 1–9. **You'll know it worked when** all required checks and exact-head review are green, the PR is merged, and `origin/main` contains the merge commit.

11. **Install and live-prove the first round.** Use the documented repository installer on each in-scope reviewer host, preserve machine-local configuration, start a round against a controlled fixture or a safely observable real interval, classify every candidate, complete it, append one new event, and prove the next round begins after the prior boundary while still detecting the new event. Save redacted verification evidence under `tests/verification/`. Dependency: merged main. **You'll know it worked when** the installed command reports the completed checkpoint, the second round excludes old records and includes the new record, and the original incident packages remain unchanged.

12. **Close the workstream.** Update this STATUS table with artifact-backed evidence, update issue #308 with the merged commit and live proof, close it only after all gates pass, and delete the linked handoff in the finishing commit according to the successor rule. Dependency: Step 11. **You'll know it worked when** issue #308 is closed, no open obligation remains, the handoff is retired, and current `origin/main` contains the final documentation state.

## 10. Tests required

Extend `tests/test-ai-reviewer-issue.sh` with explicit assertions for:

- schema acceptance and rejection;
- first round with no prior checkpoint;
- empty round completion;
- append-only resumption from an exact lower boundary;
- two records with the same timestamp;
- a partial final line that is completed later;
- events appended after the frozen upper boundary;
- rotation, replacement, truncation, deletion, unreadable file, invalid JSONL, and continuity-digest mismatch;
- symlink/path traversal refusal for sources and checkpoint destinations;
- deterministic candidate IDs and duplicate suppression;
- active-round resume and conflicting second-start refusal;
- concurrent start and completion writers;
- exact incident link validation;
- mandatory classification for every candidate;
- controlled non-defect classifications with evidence;
- refusal to complete with open incidents;
- partially resolved carry-forward behavior;
- repair commit and evidence validation inherited from existing closure rules;
- atomic failure leaving the prior checkpoint unchanged;
- idempotent repeated completion;
- private/redacted output and no raw prompt, credential, or command leakage;
- resolved incident directories remaining in their original locations.

Keep the existing `tests/test-ai-reviewer-issue.sh` assertions green. Run the repository's quiet verification workflow named in `docs/development.md`, the context/skill parity checks affected by documentation changes, and both Git Bash/Windows and Linux executions required by CI. Do not run a local full reviewer suite on `edge-dev` while its Windows CI runner is active.

## 11. Constraints, standing rules, and gotchas in force

- Preserve capability: do not disable evidence capture, relax exact joins, skip malformed logs, or redefine failures away.
- This public repository must never receive raw provider logs, prompts, transcripts, incident packages, credentials, or private repository details.
- Checkpoint state is machine-local and private. Test fixtures must be synthetic and secret-free.
- Original incident evidence is immutable. Resolutions and maintenance rounds are append-only.
- Never advance a checkpoint on partial work, a failed test, an unmerged commit, an uninstalled repair, or missing live proof.
- Freeze each round's upper boundary. Do not wait for continuously changing logs to become quiet.
- Do not trust timestamps alone. Preserve record/byte continuity and fail closed on ambiguity.
- Keep cross-platform Bash behavior compatible with Git Bash and Linux. Avoid platform-specific file identity as the sole correctness guard.
- Keep canonical checkout landing-only. Implementation uses its own current-upstream worktree and feature branch.
- Verify `git var GIT_COMMITTER_IDENT` before the first commit.
- Reviewer safety-path changes require one independent read-only exact-head final review.
- Use `bin/ai-pr-wait <pr>`; do not hand-roll CI polling.
- Installation changes require reading `docs/deployment.md` before modifying or invoking deployment behavior.
- No application database or shared-database change belongs in this work.
- Do not add a generated archive/index that concurrent sessions must rewrite.

## 12. Access and environment

- Repository: `https://github.com/popcre/ai-devops`, protected target branch `main`.
- Planning issue: `popcre/ai-devops#308`.
- Planning branch/worktree: `codex/reviewer-log-checkpoint-plan` in `C:\Users\ahazan\.codex\worktrees\reviewer-log-checkpoint\ai-devops`; the implementer should use a new current-`origin/main` worktree if this branch has already landed.
- Required local tools: Git, GitHub CLI, Git Bash, Bash, `jq`, and the repository test dependencies documented in `docs/development.md`.
- Machine-local state defaults: incident storage `.ai/reviewer-issues/` in the installed toolkit and reviewer state below `~/.local/state/ai-devops`; environment overrides already supported by tests must remain supported.
- Authentication: GitHub CLI is expected to be authenticated. No provider credential should be needed for unit tests. If live reviewer qualification requires a provider, use the existing wrapper and its established 1Password reference in vault `vibe_coding`; never print or copy the value.
- No web URL or application login is involved. Operational deployment is installation of the merged toolkit followed by the live command proof.

## 13. Definition of done + risks and open questions

### Definition of done

- [x] Versioned started/completed maintenance-round schemas exist and validate.
- [x] The installed command shows the last completed boundary and any active round.
- [x] A new round reads only the proven interval between the prior completion and its frozen upper boundary.
- [x] Rotation, truncation, replacement, corruption, and concurrent writers fail safely without checkpoint advancement.
- [x] Every candidate is linked to an incident or explicitly classified with evidence.
- [x] Completion refuses open/unaccounted work and preserves partially resolved carry-forward.
- [x] Existing issue evidence remains in place; no `resolved.md` or archive is created.
- [x] Focused and full required tests pass on Windows/Git Bash and Linux.
- [x] Exact-head independent reviewer approval exists for the final code.
- [x] The PR is merged through protected `main`; the exact commit is confirmed on `origin/main`.
- [x] The merged toolkit is installed on the in-scope host(s), and a two-round live proof demonstrates correct resumption.
- [x] Redacted proof is committed under `tests/verification/`; issue #308 is closed; plan STATUS is current; the handoff is retired when all work is truly complete.

### Risks and rollback

- **False advancement is the highest risk.** Mitigation: immutable started rounds, frozen upper bounds, continuity digests, complete candidate accounting, and atomic completion. Rollback: keep the previous completed record authoritative and ignore/delete only an uncommitted temporary file; never rewrite completed history.
- **Log formats differ by provider.** Mitigation: inventory every registered provider and explicitly block unsupported sources. Do not write a generic parser that silently drops unknown records.
- **Large logs could make full-prefix hashing expensive.** Start with correctness. Optimize only with measured evidence, for example chained segment digests or structured lifecycle IDs, while preserving equivalent continuity proof.
- **Machine-local checkpoints do not create fleet-wide truth.** Version 1 reports its hostname and covered sources explicitly. A future fleet aggregator is separate work and must not be implied.
- **A success record might be mistaken for a defect or vice versa.** Candidate extraction should be conservative; classification remains explicit and auditable.

### Decisions taken

- **Command naming:** `maintenance` groups the round lifecycle without changing the existing incident commands.
- **Latest-completed lookup:** derive it from immutable completed records and their validated parent chain; no mutable cache pointer is required.
- **Provider coverage gaps:** Albert authorized durable recording as part of this implementation. All nine registered wrappers now share that journal; missing recorder coverage blocks a round, and raw-text heuristics are not treated as complete history.

## Mandatory plan self-audit

1. **Could a brand-new AI session execute this plan without asking anything? Yes.** Sections 2–6 define the repository, trigger, current code, exact gap, and evidence. Sections 9–12 name files, dependencies, commands, environments, and a verification gate for every step.
2. **Does the plan carry the background, nuance, and rejected approaches? Yes.** Sections 6–8 distinguish incident closure from log coverage, lock the append-only design, explain why a `resolved.md` archive is wrong, and preserve every safety constraint.
3. **Is the ultimate goal clear enough for correct judgment when a step is wrong? Yes.** Section 1 defines the business outcome and makes the goal controlling; Sections 8 and 13 provide locked decisions, bounded judgment criteria, risks, rollback, and completion evidence.

All 13 required sections are present; scope exclusions, tests, secrets handling, branch/CI/install gates, direct handoff backlink, and artifact-based completion criteria are explicit. Self-audit result: **PASS**.
