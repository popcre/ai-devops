# IMPLEMENTATION PLAN — restore trustworthy Kimi reviews (2026-08-20)

Paired handoff: [`HANDOFF.d/2026-08-20T0213Z-edge-dev-codex-kimi-review-recovery-plan.md`](HANDOFF.d/2026-08-20T0213Z-edge-dev-codex-kimi-review-recovery-plan.md)

Tracking issue: [u2giants/ai-devops#46](https://github.com/u2giants/ai-devops/issues/46)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Reconcile concurrent reviewer-wrapper work and freeze the failure matrix | ✅ complete | 2026-08-20 | `docs/kimi-review-failure-analysis-2026-08-19.md` and committed fixtures |
| 2. Make the durable worker the single owner of every review artifact | ✅ complete | 2026-08-20 | Canonical artifact is written and hashed before terminal job state |
| 3. Correct ignored-folder detection across affected wrappers and add protected fallback storage | ✅ complete | 2026-08-20 | Exact-destination checks in Kimi, Grok, Gemini, and Qwen |
| 4. Preserve failed partial reviews without turning them into verdicts | ✅ complete | 2026-08-20 | Incomplete artifacts state `NO VERDICT` and commands remain nonzero |
| 5. Present exact typed failures and preserve diagnostic evidence | ✅ complete | 2026-08-20 | Typed guidance plus raw stream/stderr paths in the artifact |
| 6. Make temporary-copy provenance and retrieval unambiguous | ✅ complete | 2026-08-20 | Artifact records launch repository, reviewed head, private canonical path, and optional mirror |
| 7. Run the complete offline regression and hostile safety suite | ✅ complete | 2026-08-20 | Kimi 171/171, Grok 106/106, Qwen 23/23, Gemini 17/17 |
| 8. Requalify Kimi live, independently review the exact head, and land | 🟨 in progress | 2026-08-20 | Auth/preflight pass; live Kimi returned no terminal record, so quarantine remains. Grok review pending. |

**Fresh-session starting point:** Step 1. Read the entire plan before editing. The
checkout had concurrent uncommitted changes to `bin/ai-kimi` and
`tests/test-ai-kimi.sh` when this plan was written; never overwrite them.

## 1. The ultimate goal — what we are trying to achieve

Albert must be able to assign a Kimi review and receive one truthful outcome:

1. a complete review whose full findings and verdict are durably recoverable; or
2. a clearly named failure whose partial work and diagnostic evidence are preserved.

A failed, quota-limited, timed-out, or incomplete Kimi run must never look like an
approval. A successful run must never lose its findings because a temporary folder
was removed or a folder-safety check was wrong. Kimi remains quarantined until the
merged, installed wrapper passes a bounded authenticated qualification.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for dependable multi-model
AI coding work. It contains Bash commands under `bin/`, PowerShell setup, tests,
documentation, prompt templates, and shared Claude/Codex skills. It is not a web
application, database, container, or hosted service.

The affected command is `bin/ai-kimi`. It drives the locally authenticated Kimi
Code CLI through a structurally read-only review profile, creates a private
self-contained repository snapshot, starts a durable hidden worker, and records
job state under the user's private ai-devops state directory. Reviewers cannot
write, run shell commands, or use the network. Those controls remain unchanged.

Repository and landing target:

- Local checkout: `C:\repos\ai-devops`
- GitHub: `u2giants/ai-devops`
- Branch policy: work directly on `main`; no feature branch
- Tracking issue: `#46`
- Runtime installation: the installed launcher points at the canonical checkout;
  there is no server deployment for this change

## 3. What triggered this work

Two local evidence packages recorded Kimi review failures from 2026-08-19:

- `.ai/reviewer-issues/20260819T205606Z-edge-dev-ai-kimi-359392/`
- `.ai/reviewer-issues/20260820T004602Z-edge-dev-kimi-k3-385556/`

The reports initially described Kimi as broadly unusable. Re-reading the raw job
records separated four categories that had been conflated:

1. Historical wrapper defects that were already fixed by commit
   `f65cc77315e4b119d918ae3a4fb12f463f04c430`.
2. Active wrapper defects that still lose or strand durable evidence.
3. Provider/account quota exhaustion, which code cannot repair.
4. One unexplained exit `127`, for which the surviving evidence is insufficient
   to claim a root cause.

Direct inspection on `edge-dev` during planning found that the measured failure
set was not “nine exit-127 deaths.” Across sequences 214, 216, 218, 220, 222,
224, 228, 230, 232, and 234, nine surviving job records identified an explicit
usage limit with exit `1`; only sequence 216 recorded exit `127`. This count is
**provisional until Step 9.1 re-derives and records every row**, because the
original narrative evidence package states the opposite for sequences 218–234.
Sequence 202's raw stream contains its complete findings and `VERDICT: REVISE`.

An independent Gemini 3.7 Flash High review agreed that Kimi must remain
quarantined and confirmed the active ignored-folder, persistence, partial-output,
and typed-diagnostic gaps. Its machine-local report is
`.ai/reviews/gemini-kimi-wrapper-diagnosis-2-20260820T020029Z.md`; this plan carries
all load-bearing conclusions because `.ai/` is intentionally not source truth.

## 4. Scope — in and out

### In this plan

- Correct durable storage for complete and incomplete Kimi review output.
- Correct `.ai/reviews/` ignored-folder detection for directory-style rules.
- Sweep and correct the identical ignored-folder probe in `ai-grok-review`,
  `ai-gemini`, and `ai-qwen`, or record an explicit governed follow-up if live
  concurrent work makes the shared repair unsafe in issue #46.
- Make the durable worker the only writer of the canonical review artifact.
- Preserve partial assistant analysis on quota, timeout, cancellation, startup,
  malformed-output, and generic provider failure, clearly labeled incomplete.
- Present the exact typed failure and safe diagnostic paths to the caller.
- Ensure reviews launched inside disposable caller copies remain retrievable after
  those copies disappear.
- Correct durable documentation of the 2026-08-19 evidence without rewriting the
  original local evidence package.
- Extend offline and authenticated Windows qualification tests.
- Independently review, commit, push, install, and verify the merged result.

### NOT in this plan

- Buying Kimi allowance, changing billing tiers, or rotating Kimi OAuth.
- Changing the Kimi model pin or claiming returned model, token, cache, or cost
  data that Kimi does not expose.
- Weakening the read-only agent profile, adding Bash, web, write, or edit tools.
- Changing `ai-review-sandbox` to accept a raw linked worktree or a second folder.
- Automatically accepting a partial review as a verdict or approval.
- Automatically selecting or replacing reviewers. Caller governance owns rotation.
- Reworking Kimi implementation-mode patch recovery except shared helper changes
  strictly required to avoid regressions.
- Modifying shared-db, production infrastructure, databases, or application code.

## 5. Current state of the code

### Already fixed and committed

Commit `f65cc77` repaired two dangerous historical defects:

- `extract_answer()` in `bin/ai-kimi` now prints the complete assistant body
  instead of using `sed -n '/^## Verdict/,$p'`, which discarded findings above
  the verdict.
- A turn with no answer or no `## Verdict` now returns a wrapper failure rather
  than exit `0`.

The corresponding tests are in `tests/test-ai-kimi.sh`. Preserve them.

### Active defects in committed source

- `reviews_dir()` near `bin/ai-kimi:765` checks
  `git check-ignore -q .ai/reviews`. A rule such as `.ai/reviews/` matches a child
  file but can fail this directory-path probe. The false negative causes
  `write_review_file()` to skip persistence.
- The same directory-path probe exists in `bin/ai-grok-review`, `bin/ai-gemini`,
  and `bin/ai-qwen`. The 2026-08-19 evidence observed the false warning in Grok
  too. “Fix everything” therefore includes a same-pattern sweep rather than a
  Kimi-only patch unless a named follow-up issue is created and linked.
- `review_worker()` near `bin/ai-kimi:885` writes a completed report, then
  `cmd_wait_job()` calls `finish_turn()` near line 977, which can write it again.
  Persistence ownership is duplicated and depends on which process is present.
- Failed review jobs record the raw stream but do not produce a human-readable,
  explicitly incomplete review artifact.
- `cmd_wait_job()` near `bin/ai-kimi:967` gives special text for only a subset of
  terminal reasons. Usage limit, timeout, startup failure, directory mismatch,
  malformed output, and generic failure fall into a misleading generic message.
- Review artifacts are written relative to the repository from which the wrapper
  was invoked. If that repository is itself a caller-created disposable copy,
  its `.ai/reviews/` artifact can disappear with the copy.

### Concurrent work that must be reconciled first

At plan creation, `main` and `origin/main` both pointed to
`ed30a42bb18d98fdb1fc45b029b0b538db72353a`, but the shared checkout contained
uncommitted changes owned by another session in every reviewer wrapper and test.
The Kimi delta renamed a missing local runtime from the ambiguous
`provider-unavailable` class to `local_dependency_unavailable` and added tests.
That change landed in commit `5154d2a490123450940eda48f9a01b66b69adbab`
while GLM reviewed this plan. Preserve it. The uncommitted routing changes to
`AGENTS.md`, `docs/reviewer-issues.md`, and the shared Kimi skill, plus this
untracked plan, handoff, and memory file, are this planning workstream's own
output and belong in the first issue-46 commit. All other dirty reviewer-wrapper
and test files belong to concurrent work and must not be staged or overwritten.

### Documentation and deployment state

- `plan_kimi-windows-execution-reliability.md` is complete and issue #31 is
  closed. Its security and durable-worker decisions remain binding history.
- `plan_reviewer-system-repair.md` completed provider preflight, typed guidance,
  and the scoreboard. This plan extends Kimi-specific terminal presentation; it
  does not create automatic provider selection.
- No code for issue #46 has been committed, pushed, installed, or live-qualified.
- There is no hosted deployment. “Deployed” means the installed `ai-kimi`
  launcher resolves to the merged canonical source and passes live qualification.

## 6. Key findings and root cause

### 6.1 The provider and wrapper failures were mixed together

Planning-time inspection found sequence 214 and eight later sequences ending with
Kimi's explicit HTTP `403` usage-limit response and exit `1`. That is account
exhaustion. Because the original evidence narrative contradicts this count, Step
9.1 must re-read each surviving `job.json` and freeze the matrix before code.
The wrapper must report and preserve quota correctly, but code cannot replenish
the allowance.

Sequence 216 emitted only a `system.version` record, no stderr, and exit `127`.
Because Kimi itself launched far enough to emit its version, “Kimi binary was not
found” is not proven. Treat it as `provider-process-failed` or another truthful
generic class unless future captured evidence identifies the internal child.

### 6.2 Findings truncation is historical, not current

The current `extract_answer()` prints every assistant message. Sequence 202's raw
stream contains its full findings. Do not reintroduce verdict-tail extraction and
do not claim that sequence 202 proves current extraction loss.

### 6.3 Persistence has no single owner

The hidden worker survives caller/waiter death, so it must own canonical artifact
creation. A foreground waiter is optional and cannot be responsible for durable
evidence. Today both worker and waiter can call the report writer. This makes
duplicate writes, inconsistent paths, and caller-lifetime dependence possible.

Permanent design: every terminal worker path writes exactly one canonical report
under private wrapper state before publishing terminal job state. A successful
report may also be mirrored into the repository's ignored `.ai/reviews/` folder.
The waiter prints the recorded artifact and answer; it never creates another one.

### 6.4 Repository storage cannot be the only copy

The wrapper accepts ordinary repositories, linked worktrees converted to private
snapshots, and caller-created temporary clones. It cannot reliably infer a
different “real checkout” from an arbitrary local remote. Therefore the private
state directory is the stable storage authority. A repository report is a useful
copy, not the sole evidence.

### 6.5 Partial output has value but never approval authority

Large failed streams contained leads that later became confirmed findings. They
should be readable without manually parsing JSONL. However, a partial report must
carry an unmistakable `INCOMPLETE — NO VERDICT` heading, terminal reason, exit
code, exact reviewed head, raw-stream path, and warning that it cannot approve a
change. Fail-closed behavior remains locked.

## 7. Approaches considered and REJECTED

| Rejected approach | Why it is rejected |
|---|---|
| Restore the old `sed` verdict-tail extractor | It caused the proven findings-loss defect fixed by `f65cc77`. Findings can appear above the verdict. |
| Treat exit `0`, a session ID, or any assistant text as approval | Completion and a usable verdict are separate requirements. Silence or narration must fail. |
| Treat partial findings as a valid review | Partial work is recovery evidence only. It cannot approve or satisfy a merge gate. |
| Save only under the caller's `.ai/reviews/` | Caller-created disposable copies can vanish. The wrapper needs private durable storage independent of caller lifetime. |
| Save only under private state and remove repository reports | Repository reports are the normal human-facing workflow and an intentional design decision. Keep them as safe mirrors. |
| Make the waiter write the report | The waiter can be killed while the durable worker continues. The worker must own persistence. |
| Retry quota failures until one succeeds | This burns allowance, obscures one governed reviewer assignment, and can turn replacement into approval shopping. |
| Label every exit `127` as “command not found” | Sequence 216 proves the Kimi executable started. The missing command, if any, could be an internal child; root cause is unproven. |
| Fix quota exhaustion in code | Quota is an account state. Code can preflight, classify, quarantine, and report it, not replenish it. |
| Increase the 900-second deadline | Earlier reviewer work established that larger limits multiply cost and delay. This plan improves evidence and diagnosis, not budgets. |
| Broaden reviewer tools or folders | Read-only and single-directory containment are locked safety controls. The evidence packet and self-contained snapshot already solve discovery. |
| Rewrite the original `.ai/reviewer-issues` evidence | Evidence packages are historical records. Add a durable reconciliation document; never alter the source evidence. |

## 8. Design decisions already made

### LOCKED — do not relitigate

- **2026-08-20: Kimi remains quarantined until Step 8 passes.** Strong model
  quality does not compensate for an untrustworthy delivery path.
- **2026-08-20: the durable worker owns canonical artifacts.** Foreground waiters
  only retrieve and display them.
- **2026-08-20: private wrapper state is the durable authority.** An ignored
  repository report is a convenience mirror.
- **2026-08-20: incomplete output is preserved but never accepted as a verdict.**
- **PROVISIONAL 2026-08-20: planning-time job-record inspection found nine
  usage-limit exits and one exit `127` in the named ten-sequence set.** Step 9.1
  must re-derive every row because the narrative evidence package contradicts it.
  Do not lock or publish the corrected count until that artifact exists.
- Preserve the structurally read-only agent, exact session ID, exact-head binding,
  private review workspace, model pin, terminal resume-hint rule, and absence of
  invented Kimi usage metrics.
- Preserve the concurrent session's `local_dependency_unavailable` work if it is
  still valid when Step 1 begins.

### OPEN — implementation judgment within stated criteria

- The exact private report layout under `AI_KIMI_STATE_DIR`. Prefer
  `reports/<repo-id>/<caller>--<name>/<job-id>.md`; require restrictive permissions,
  ownership validation, collision refusal, and a path recorded in `job.json`.
- Whether the repository mirror is a copy or an atomic write from the same
  rendered temporary file. Choose the design that guarantees identical content
  without leaving partial files.
- The new generic class name for unexplained provider child exits. It must not
  claim a missing local executable when Kimi already emitted valid stream data.

## 9. The plan — numbered, ordered, executable steps

### Phase A — reconcile truth and freeze tests

#### 9.1 Reconcile concurrent work and freeze the measured failure matrix

Targets:

- `bin/ai-kimi`
- `tests/test-ai-kimi.sh`
- issue #46
- the local evidence packages named in §3
- new durable report `docs/kimi-review-failure-analysis-2026-08-19.md`

Actions:

1. Run `git status --short`, `git diff -- bin/ai-kimi tests/test-ai-kimi.sh`, and
   `git log -5 --oneline -- bin/ai-kimi`. The issue-46 plan, handoff, memory, and
   routing edits named in §5 are owned by this workstream and should be committed;
   do not wait for a departed planning-session owner. Preserve every other
   concurrent hunk.
2. Re-read the STEP 0 header in `bin/ai-kimi`, the STATUS table of
   `plan_kimi-windows-execution-reliability.md`, and the newest DRIFT block of
   `plan_reviewer-system-repair.md`.
3. Re-read every surviving `job.json` for sequences 214, 216, 218, 220, 222, 224,
   228, 230, 232, and 234. Record a redacted row per sequence with exact
   `exit_code`, `terminal_reason`, provider seconds, output size, and source path.
   Record a purged/missing job explicitly as `missing`; any missing row leaves the
   corrected count unproven and blocks proceeding on the planning-time count.
   If any of 218–234 is exit `127`, stop before Step 9.2: repeated post-quota
   exit-127 behavior is a candidate active regression and issue #46's scope and
   fixtures must be revised before implementation.
4. Create redacted fixtures representing sequence 202 complete output, sequence
   214 partial output plus usage-limit stderr, every distinct exit-127 shape the
   matrix proves, and the directory-ignore patterns. Fixtures must contain no
   private repository source, prompt, OAuth material, or user identifiers.
5. Write the durable incident reconciliation document. It must distinguish fixed
   history, active wrapper defects, provider/account failures, and unproven claims.

Dependency: none. This step blocks all code edits.

**You'll know it worked when:** the new fixture-driven tests reproduce every
active defect against the pre-fix wrapper, the durable report cites re-runnable
fixture commands, and no concurrent hunk was lost.

#### 9.2 Make the durable worker the single artifact owner

Targets: `review_worker()`, `finish_turn()`, `cmd_wait_job()`, `cmd_result_job()`,
`write_review_file()` and job schema creation in `bin/ai-kimi`.

Actions:

1. Add one rendering function that converts the raw stream plus job metadata into
   a complete or incomplete Markdown report without writing it.
2. In every worker terminal path, atomically write the canonical private report
   before atomically publishing the terminal `job.json` state.
3. Record `canonical_review_artifact`, optional `repository_review_artifact`,
   artifact kind (`complete` or `incomplete`), SHA-256, and write status in the
   job record. Do not place prompt text or credentials in metadata.
4. Remove report creation from the foreground waiter/result path. Retrieval must
   validate the recorded artifact path and hash, print the full answer, print the
   saved paths, and return the worker's truthful success/failure status.
5. Repeated `wait` and `result` calls must be idempotent and create no new files.
6. Extend `recover` and `result` for the existing
   `terminal-stream-needs-worker-finalization` state: when the raw stream carries
   valid terminal proof but the worker died before report creation, run the same
   renderer once, record the recovered artifact and hash, and never relabel a job
   successful unless every original completion and verdict condition is proven.

Dependency: Step 9.1.

**You'll know it worked when:** killing the waiter does not prevent the worker
from creating exactly one canonical report, and three later `result` calls return
the same validated artifact path and hash without creating duplicates.

### Phase B — persistence and failure recovery

#### 9.3 Correct ignored-folder detection across wrappers and add protected fallback storage

Targets: `reviews_dir()`, artifact path validation, and related test helpers in
`bin/ai-kimi` and `tests/test-ai-kimi.sh`.

Actions:

1. Compute the real collision-proof destination filename first, then probe that
   **exact destination path** with `git check-ignore --no-index`, not the
   directory name or a generic sibling. This prevents a name-scoped negation from
   approving the probe while leaving the real `kimi-*.md` committable. The probe
   must work before the directory exists and must not create a file.
2. Test exact directory, parent-directory, wildcard, negation, and not-ignored
   rules. A negated child that would be committable must fail closed.
   A destination returned by `git ls-files` is also unsafe even when
   `check-ignore --no-index` reports it ignored.
3. Always write the canonical report under wrapper-owned private state with
   restrictive permissions. Mirror it to `.ai/reviews/` only when the child-path
   probe proves the destination file is ignored.
4. Use atomic temporary-file plus rename writes, collision refusal, canonical
   path validation, and SHA verification. Never overwrite an existing report.
5. If the repository mirror is unsafe or unwritable, complete the private write,
   record the mirror failure, warn loudly, and preserve the correct process exit.
6. Apply the same exact-destination probe repair to `bin/ai-grok-review`,
   `bin/ai-gemini`, and `bin/ai-qwen` with focused regressions. If concurrent
   ownership prevents safely landing all four in issue #46, create and link one
   explicit follow-up issue and record the remaining affected functions in the
   incident reconciliation document. Do not silently leave the known copies.
   Before editing each sibling, read its STEP 0 verification header and preserve
   every provider-specific completion and permission invariant.
7. Reuse or explicitly supersede the existing private `recovery-patches`
   mechanism used by `artifact_dir()`; do not create a competing private artifact
   hierarchy without one documented ownership model.

Dependency: Step 9.2.

**You'll know it worked when:** `.ai/reviews/` patterns produce a repository
mirror, an unsafe repository produces only the protected private artifact plus a
loud warning, and neither case loses the review.

#### 9.4 Preserve failed partial reviews without granting verdict authority

Targets: worker failure finalization, report renderer, `job.json`, `cmd_wait_job()`,
and `cmd_result_job()`.

Actions:

1. Extract every assistant message from the raw stream on failure. Do not use the
   verdict-tail extractor.
2. When assistant text exists, create an `INCOMPLETE — NO VERDICT` report carrying
   job ID, repository identity, base/head, terminal reason, exit code, timing,
   safe stderr tail, full assistant text, raw stream/log paths, and an explicit
   statement that it cannot approve a change.
3. When no assistant text exists, still create a small diagnostic report for a
   terminal provider attempt, except a preflight failure that never launched Kimi.
4. Bound stderr/log excerpts, redact known credential/query patterns, and retain
   the full local raw files at their protected paths. Never copy raw OAuth/config.
5. Keep the command nonzero for every incomplete artifact.

Dependency: Step 9.3.

**You'll know it worked when:** the sequence-214 fixture produces a readable
incomplete report containing its partial analysis and usage-limit reason while
returning nonzero, and sequence 216 produces a truthful diagnostic report without
inventing “command not found.”

#### 9.5 Present exact typed failures and evidence paths

Targets: terminal-reason classifier, `cmd_wait_job()`, `cmd_status_job()`,
`cmd_result_job()`, `cmd_logs_job()`, and `ai-review-preflight` integration.

Actions:

1. Add explicit user-facing cases for `usage-limit`, `timed-out`,
   `startup-timeout`, `directory-mismatch`, `credentials-unavailable`,
   `local_dependency_unavailable`, `malformed-output`, `readonly-tree-changed`,
   cancellation, and unexplained provider-process failure.
2. Include terminal reason, exit code, reviewed head, canonical report path, raw
   stream path, and safe stderr/log path in status/result output.
3. Preserve the concurrent `local_dependency_unavailable` distinction: a missing
   local binary is not a provider failure. Conversely, do not apply it to sequence
   216 because Kimi emitted a valid version record.
4. Ensure preflight/quarantine consumes the same stable failure vocabulary or an
   explicit mapping. Do not add automatic reviewer selection.
5. Update `docs/reviewer-issues.md`, the Kimi skill, architecture/development docs,
   and model comparison only where behavior changed.
6. Include `worker-start-failed` and `recovery-required` in the typed presentation
   vocabulary.

Dependency: Steps 9.1 and 9.4.

**You'll know it worked when:** each fixture prints one specific plain-English
failure and the correct recovery action, never the generic resume-hint message,
and `ai-review-preflight explain` remains consistent.

#### 9.6 Make temporary-copy provenance and retrieval unambiguous

Targets: job schema, canonical artifact layout, repository identity helpers,
`list`, `show`, `status`, and `result`.

Actions:

1. Store the invocation repository path, normalized remote, exact head, private
   review workspace, and stable repository ID separately. Do not guess that a
   local-path remote points to the user's canonical checkout.
2. Store canonical reports outside every review snapshot under private state.
3. Make `list/show/result` find jobs by validated stable identity and recorded
   name even after the invocation directory has been removed. If two records are
   ambiguous, refuse and print both safe identifiers.
4. Add a fixture that launches from a disposable clone, completes the worker,
   deletes that clone, and then retrieves the same canonical artifact from the
   original repository context.
5. State and test implementation-mode behavior explicitly: keep implementation
   patch/report export governed by `artifact_dir()` and its lifecycle finalizer.
   The corrected `reviews_dir()` intentionally allows ignored repository
   placement where it previously false-negative-fell back to private
   `recovery-patches`; all complete and incomplete implementation recovery tests
   must remain green. Removing waiter report writes must not remove any
   implementation-mode human-facing report required by that path.

Dependency: Steps 9.2–9.5.

**You'll know it worked when:** deleting the caller-created clone cannot delete
the canonical report, and retrieval returns the original validated hash without
guessing another checkout.

**Fresh-session cut:** after Step 9.6, update this STATUS table and current-state
section in the same commit, then start a fresh session. Re-read Steps 9.7–9.8
before running broad or authenticated tests.

### Phase C — regression, live qualification, and landing

#### 9.7 Run the complete offline regression and hostile safety suite

Targets: all changed code/tests and the commands in §10.7.

Actions:

1. Run syntax checks and focused Kimi tests first.
2. Run review-sandbox, review-packet, preflight, scoreboard, installer, and
   Windows script suites because artifact identity crosses those boundaries.
3. Add hostile tests for forged job paths, symlink/junction escape, existing-file
   overwrite, artifact-hash mismatch, interrupted atomic write, concurrent result
   calls, killed waiter, killed worker, malicious ignore negation, and raw output
   containing credential-shaped text.
4. Confirm the read-only hostile-write canary remains byte-identical.
5. Update the plan STATUS only with exact commands and durable artifacts, never a
   bare check count.

Dependency: Steps 9.1–9.6.

**You'll know it worked when:** every named suite finishes green, each hostile
case fails closed, and the original checkout plus outside sentinel remain
byte-identical.

#### 9.8 Requalify live, independently review, and land

Actions:

1. Wait for the existing Kimi billing cycle to refresh. Recommendation: do not
   purchase extra usage solely for this qualification. If Albert wants immediate
   qualification, he must explicitly approve the account spend.
2. Run `AI_KIMI_CALLER=codex ai-kimi doctor --live` from the Full Access main task.
3. In a disposable fixture repository, run bounded canaries for complete review,
   `VERDICT: REVISE`, waiter death, private-only fallback, temporary-copy deletion,
   exact-session continuation, and hostile write refusal. Do not use production
   or private application content.
4. Capture redacted evidence under a new dated directory in `tests/verification/`.
5. Run an independent exact-head review with GLM 5.3 or another healthy governed
   reviewer. Fix every valid Critical/High/Medium finding and rerun affected tests.
6. Verify Git identity, commit only issue-46 files, push `main`, confirm any GitHub
   checks, run the canonical installer, and confirm installed/source hashes match.
7. Re-run the live canaries through the installed command. Update issue #46, this
   plan, routing docs, and paired handoff. Delete the handoff only when every
   obligation is durably complete.

Dependency: all prior steps and available Kimi allowance.

**You'll know it worked when:** the merged installed command returns one durable
complete artifact or one durable typed incomplete artifact for every bounded
case; no result is lost, duplicated, or mistaken for approval; exact-head
independent review has no unresolved Critical/High/Medium finding; and issue #46
is closed with linked evidence.

## 10. Tests required

### 10.1 Historical guards that must remain

- Full findings above `## Verdict` are printed and persisted.
- Empty assistant output fails.
- Assistant narration without `## Verdict` fails.
- Read-only review cannot write.
- Completion still requires the terminal `session.resume_hint` record.
- Exact-head and stable private-workspace continuation remain enforced.

### 10.2 Single artifact ownership

- Worker completion creates one canonical report before terminal state.
- Waiter death does not prevent report creation.
- Repeated `wait` and `result` calls create no additional report.
- Recorded artifact hash must match before display.
- Interrupted report write cannot publish completed job state.
- A worker killed after terminal proof but before report write is recoverable
  through the single renderer without inventing success.

### 10.3 Ignored-folder and fallback behavior

- `.ai/reviews/`, `.ai/`, `.ai/reviews/*`, and equivalent valid rules accept an
  ignored child report path.
- Negated or unignored report files refuse the repository mirror.
- Name-scoped negation of the real `kimi-*.md` destination refuses the mirror
  even when a generic sibling would be ignored.
- The probe works before `.ai/reviews/` exists and creates nothing.
- Unsafe/unwritable repository storage still produces protected private storage.
- Existing artifacts are never overwritten.

### 10.4 Partial-review recovery

- Usage-limit with assistant text writes an incomplete report and exits nonzero.
- Timeout/context denial with assistant text preserves all assistant messages.
- Exit 127 with only version metadata produces a diagnostic report without an
  invented root cause.
- Cancellation remains cancellation and cannot publish a verdict.
- No-output preflight failure does not create a fake provider review.
- Every incomplete report says `INCOMPLETE — NO VERDICT` and cannot be parsed as
  `APPROVE`.

### 10.5 Typed diagnostics

- Every terminal reason named in Step 9.5 prints distinct guidance.
- Usage-limit output names the account limit and does not blame local runtime.
- Missing local runtime prints `local_dependency_unavailable` and says Kimi was
  not contacted.
- Raw stream, safe log, canonical report, exact head, and exit code are reported.
- `ai-review-preflight explain` and Kimi terminal vocabulary remain aligned.

### 10.6 Temporary-copy retrieval and path safety

- Canonical artifact survives deletion of the invocation clone and review snapshot.
- Moved canonical checkout can retrieve by stable validated identity.
- Ambiguous same-name records refuse rather than guess.
- Forged paths, symlinks, junctions, traversal, hash mismatch, and ownership
  mismatch fail closed.

### 10.7 Commands that must finish green

Use Git Bash for Bash suites on Windows:

```bash
bash -n bin/ai-kimi
bash tests/test-ai-kimi.sh
bash tests/test-ai-review-sandbox.sh
bash tests/test-ai-review-packet.sh
bash tests/test-ai-review-preflight.sh
bash tests/test-ai-review-scoreboard.sh
bash tests/test-ai-install-skills.sh
bash tests/test-windows-scripts.sh
bash tests/test-ai-grok-review.sh
bash tests/test-ai-gemini.sh
bash tests/test-ai-qwen.sh
bash tests/test-ai-glm.sh
bash tests/test-ai-muse.sh
```

Also run the current Windows-native Kimi suite documented by
`plan_kimi-windows-execution-reliability.md` and the repository's broad test
command in `docs/development.md` at implementation time. Record full commands and
artifacts; do not copy old pass counts into the STATUS table.

## 11. Constraints, standing rules, and gotchas

- Work on `main`; no branch. Fetch before every commit because multiple machines
  update this repository.
- Preserve concurrent work. Never use `git add -A`, reset-hard, checkout-overwrite,
  or clean in this shared checkout.
- Before the first commit run `git var GIT_COMMITTER_IDENT`; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Read the full STEP 0 verification header in `bin/ai-kimi` before changing it.
- Review safety is structural. Never add Bash, Write, Edit, web, network, or
  sub-agent tools to the read-only profile.
- Kimi tool names are case-sensitive and can fail silently to no tools.
- Kimi reviews are directory-bound; resume only the exact saved session ID in the
  same wrapper-owned workspace.
- Do not point a reviewer at a raw linked Git worktree. Keep
  `ai-review-sandbox`'s self-contained snapshot.
- Do not increase timeouts as a repair.
- Never infer success from process exit alone. Preserve terminal resume-hint and
  usable-verdict checks.
- Partial output is evidence, never approval.
- Kimi reports no trustworthy returned model, tokens, cache, or cost. Never invent
  or quote them.
- `KIMI_CODE_HOME` contains OAuth and writable session state. Never broaden its
  permissions, copy it into a repository, or record its contents.
- This public repository must contain no prompts, private source, raw provider
  logs, OAuth data, or reviewer evidence that reveals private repositories.
- PowerShell files must remain ASCII-only.
- Do not edit root `HANDOFF.md` or another session's handoff.
- No database, production infrastructure, NAS, browser, or cloud mutation is
  required.

## 12. Access and environment

- Machine at planning time: `edge-dev`, Windows 11, PowerShell 7 and Git Bash.
- Repository: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- GitHub CLI is authenticated as `u2giants`.
- Git identity was verified at planning time as
  `Albert Hazan <u2giants@users.noreply.github.com>`; verify again before commit.
- Kimi CLI was version 0.36.1 in the recorded jobs and uses existing machine-local
  OAuth under the protected Kimi home. Never inspect or copy the OAuth files.
- No new secret is required. If a future provider credential is genuinely needed,
  stop and request approval; approved vault is 1Password `vibe_coding`, values
  never enter Git.
- Run credentialed Kimi calls from the Full Access main task with
  `AI_KIMI_CALLER=codex`. Restricted tasks may prepare evidence but must hand the
  call back rather than changing permissions.
- There is no hosted deployment. Installation/verification uses the canonical
  machine setup path documented in `docs/deployment.md` and the completed Windows
  reliability plan.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Every STATUS row is complete with a re-runnable artifact, commit, or test path.
- [ ] Concurrent reviewer-wrapper changes were preserved and reconciled.
- [ ] Worker owns one canonical report; wait/result are idempotent retrieval.
- [ ] Complete findings and verdict are always durably recoverable.
- [ ] Every failed provider attempt produces a typed failure and, where useful,
      an explicitly incomplete durable report.
- [ ] Repository ignore detection is correct for directory rules and negations.
- [ ] Private fallback storage works and resists path/overwrite attacks.
- [ ] Temporary caller-copy deletion cannot destroy canonical evidence.
- [ ] Historical `f65cc77` findings/no-verdict guards remain green.
- [ ] Full offline, Windows, installation, and hostile safety suites pass.
- [ ] Bounded authenticated live qualification passes after allowance is available.
- [ ] Independent exact-head review has no unresolved Critical/High/Medium finding.
- [ ] Durable incident documentation corrects unsupported claims without altering
      original evidence.
- [ ] Every identical ignored-folder probe is repaired or assigned to one linked
      governed follow-up issue; none is silently left known-broken.
- [ ] Source is committed as Albert, pushed to `main`, GitHub checks are green if
      present, installed source hash matches merged source, and installed live
      canaries pass.
- [ ] Issue #46 is closed with evidence; this plan is marked complete and the
      paired handoff is retired under the successor rule.

### Main risks and rollback

1. **A failed artifact write could strand a job before terminal state.** Write
   atomically, keep raw stream/job evidence, and expose `recovery-required`. Roll
   back by reverting issue-46 commits; never relabel affected jobs successful.
2. **Private reports could leak sensitive review content.** Use user-only
   permissions, safe metadata, bounded redacted excerpts, and never commit the
   state directory. On suspected exposure, stop use and follow the secrets
   incident process; do not rotate credentials without Albert's approval.
3. **Retrieval could select the wrong same-name job.** Validate repository ID,
   caller, job ID, exact head, and artifact hash; ambiguity must refuse.
4. **Mirroring could create duplicates or overwrite evidence.** One worker owns
   rendering; use collision-proof names, atomic writes, and idempotent retrieval.
5. **Quota could block live proof after code is ready.** Offline work may land only
   if the plan remains explicitly quarantined. Do not restore rotation or close
   issue #46 until authenticated qualification passes.
6. **Concurrent work could conflict with this plan.** Stop at Step 1 and preserve
   the active owner's changes. Do not solve the conflict by overwriting them.

### Open questions

- When will the Kimi billing cycle refresh? This controls Step 9.8 timing, not
  offline implementation.
- Does Kimi 0.36.1 expose any safe deeper cause for sequence-216-style exit 127 in
  its own log? Investigate only through bounded redacted diagnostics. Until proven,
  keep the reason generic.
- Should Albert purchase extra Kimi allowance for immediate qualification?
  Recommendation: no; wait for the normal refresh unless business urgency changes.
- Does the Step 9.1 per-sequence matrix confirm the planning-time nine-quota/one-127
  count or the original narrative's repeated exit-127 claim? This is a mandatory
  evidence gate, not an implementer's guess.

## Mandatory plan self-audit

1. **Could a brand-new AI session with no project knowledge execute this plan
   without asking a question? Yes.** §§2–6 define the toolkit, exact repository,
   affected command, incident evidence, current commit/worktree state, fixed and
   active defects, and root causes. §9 names every function and ordered action;
   §10 gives exact behavior tests and commands; §12 gives the environment.
2. **Does the plan carry every piece of background, nuance, and reasoning held by
   this planning session, including rejected approaches? Yes.** §§3, 5, and 6
   preserve the corrected failure counts, sequence-202 evidence, `f65cc77` history,
   duplicated artifact ownership, temporary-copy loss, quota distinction, and
   unexplained exit 127. §7 records every tempting dead end and why it fails.
3. **Is the ultimate goal clear enough to guide a correct judgment if a step is
   wrong? Yes.** §1 defines the two acceptable business outcomes and says the goal
   wins. §8 locks fail-closed review authority, durable worker ownership, private
   canonical storage, and quarantine while leaving only safe mechanics open.

Checklist result: all 13 required sections are present; scope exclusions,
locked/open decisions, concrete file/function targets, per-step verification,
specific tests, access, secrets handling, risks, rollback, landing, status table,
and plan/handoff cross-links are included. A zero-context implementing session
can execute this plan without the planning chat. Self-audit passed.
