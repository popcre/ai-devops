# IMPLEMENTATION PLAN — collision-resistant ai-devops work claims (revised 2026-08-27)

**Tracking issue:** [popcre/ai-devops#131](https://github.com/popcre/ai-devops/issues/131)
**Registered handoff:** [`HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md`](HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md)

## STATUS — read this first

| Step | Status | Evidence |
|---|---|---|
| 0. Reconcile Grok, GLM, and two execution-session reviews | ✅ done 2026-08-27 | [`plan_must_address.md`](plan_must_address.md); [`docs/work-claims-plan-review-2026-08-27.md`](docs/work-claims-plan-review-2026-08-27.md); Grok 4.6 closing verdict `APPROVE` |
| 1. Stabilize and shorten the existing merge queue before adding claim checks | ⬜ prerequisite | [`plan_repo-throughput-restructure.md`](plan_repo-throughput-restructure.md) STATUS; evidence under `tests/verification/reviewer-flake-89/` |
| 2. Qualify the Git-ref primitive on Windows and Ubuntu | ⬜ open | §9.2; target `tests/verification/work-claims/<UTC>/ref-qualification.md` |
| 3. Build the task-only v1 command and owner-extensible paths | ⬜ open | Target: `bin/ai-work-claim`, `config/work-claim-policy.json` |
| 4. Add deterministic concurrency tests and an advisory PR guard | ⬜ open | Target: `tests/test-ai-work-claim.sh`, advisory workflow |
| 5. Route, document, install, and qualify v1 | ⬜ open | Target: globals, `docs/work-claims.md`, restore/install evidence |
| 6. Land v1 and measure its value for 30 days | ⬜ open | Target: exact-head review, merged SHA, baseline/follow-up measurement artifact |

**Fresh-session starting point:** Step 1. Do not start claim implementation while the throughput plan still marks reviewer-suite determinism or CI-cost reduction open. Before each phase, fetch `origin/main`, read this STATUS table and all downstream steps, recheck issues #89/#131 and ruleset `21564317`, and preserve unrelated dirty work.

## 1. The ultimate goal — what we are trying to achieve

Albert should be able to see that another AI session already owns an implementation task before a second session spends hours repeating it. The control must be materially cheaper and more reliable than the duplication it prevents, must not worsen the repository's already-expensive merge queue, and must not block reversible local work during GitHub throttling. Unrelated work, read-only investigation, and intentional reviewer fan-out remain concurrent.

Success means one atomic GitHub-backed owner exists for each implementation task; a second contender cannot believe it also won; stale ownership remains protective; advisory CI exposes publication mistakes without becoming a new merge gate; and the 30-day evidence meets the explicit keep/change/remove decision table. V1 is deliberately small enough to ship and evaluate before adding work-units, local hooks, automated takeover, or required checks.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is POP Creations’ public backup-and-restore toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell commands, Claude/Codex skills and global instructions, machine setup, reviewer wrappers, documentation, and offline verification. It is not a hosted application and has no application database or production service. Toolkit “deployment” is installation from the repository checkout.

The canonical repository is `popcre/ai-devops`; `main` is protected by active GitHub ruleset `21564317`. All changes use a feature branch, pull request, required Linux/Windows checks, and the merge queue. `AGENTS.md:20-27` and `config/repository-policy.json` are the repository contract. Organization administrators can technically bypass the ruleset, but that bypass is not the normal workflow and must not be used for this implementation.

The implementation must be portable between Ubuntu and Windows Git Bash. GitHub CLI authentication is already part of restore/setup (`docs/restore-from-zero.md:41-63`). `install.sh:201-206` installs executable Unix commands from `bin/`; Windows uses repository/setup-managed entrypoints.

## 3. What triggered this work

Albert asked whether `ai-devops` needs shared-db-style collision control. The reproducible evidence is intentionally separated from private transcript counts:

- Nine then-open PRs shared only three files: `AGENTS.md`, `docs/architecture.md`, and `tests/test-ai-kimi.sh`. Ordinary file conflicts were mild and usually cost minutes.
- Eight provider-specific repair plans addressed one copied reviewer problem class, and two live sessions nearly worked issue #89 simultaneously. The second case was prevented only by a peer-session message. These are the strongest examples of duplicated intent.
- In the issue #89 execution review, only one of six costly failures was cross-session duplication. Five were within one owner: live script mutation, shared stash state, orphaned background output, CRLF corruption, and the merge queue.
- `plan_must_address.md` measured the last 13 merge-queue runs at 7 success, 4 failure, and 2 canceled, with completed PR verification commonly taking roughly an hour. `tests/verification/reviewer-flake-89/2026-08-27-merge-queue-ejection.md` records an unrelated batch ejected by the reviewer flake.
- This plan's own PR #136 reproduced the dominant problem: `windows-offline` hung in the full suite for 66 minutes and a clean retry again ran long. Claims would not have shortened either run.

Therefore the queue is the first-order throughput problem charged against every change; duplicate implementation is a real but smaller tax. The work-claims implementation is sequenced behind `plan_repo-throughput-restructure.md` and must not add a required check until measured queue reliability supports it.

Earlier designs and reviews still matter. A committed claims file was rejected because branches/worktrees see stale copies. GitHub issue creation plus sleep was rejected because it is not atomic. Grok 4.6 and GLM 5.3 established the safer ref core: create-only admission, hashed owner tokens, exact lost-response recovery, force-with-lease mutation, and non-expiring protective ownership. The two execution-session reviews in `plan_must_address.md` then showed that exact-head binding and the larger publication machinery were throughput regressions. This revision keeps the proven core and removes those regressions from v1.

## 4. Scope — in and out

### In scope

- One portable `ai-work-claim` command using atomic GitHub Git-reference creation as admission authority.
- One exclusive v1 owner keyed only by canonical repository + task issue; no work-units or component refs.
- Optional intended-path declarations that the current owner may extend append-only as diagnosis discovers the correct scope. Paths improve diagnostics and advisory publication checks; they are not admission keys.
- GitHub task-issue comments/label for human visibility, while refs—not comments, search, or issue ordering—decide ownership.
- Non-expiring protective ownership with liveness timestamps; v1 `doctor` reports stale claims for manual reconciliation but provides no takeover command.
- Owner-token hashes in public metadata; raw owner tokens remain user-only outside Git.
- Commands `acquire`, `heartbeat`, `verify-owned`, `extend-paths`, `release`, `list`, `status`, and `doctor`.
- A fast advisory PR/merge-group guard in its own workflow file. V1 has no exact-head binding, push wrapper, commit/push hook, or shared-git-directory hook installation.
- Offline concurrency/crash/security tests, bounded live ref qualification, documentation, installation, client routing, exact-head review, PR/merge-queue landing, and installed smoke proof.
- A reproducible pre-launch baseline and 30-day follow-up measuring same-issue duplicate implementation, advisory-guard findings/ejections, and operating cost.

### NOT in this plan

- A permanent orchestrator session, work queue, author-lane manager, or repository-wide merge serialization.
- A committed `CLAIMS.md`, shared JSON index, GitHub Project, external database/service, or scheduled closer.
- Work-units, component refs, automatic or command-driven takeover, and required-check promotion in v1.
- Treating GitHub issue search, issue creation order, sleep duration, or first-page results as a mutex.
- Automatically refactoring copied reviewer implementations. That remains separate architecture work; claims only stop duplicate ownership.
- Blocking or exclusively claiming read-only analysis, transcript review, repository browsing, or independent reviewers. V1 may later add non-blocking intent visibility only if duplicate diagnosis remains measured.
- Preventing within-owner hazards: the shared stash stack, shared Git directory, concurrent processes inside one claim, script mutation during execution, CRLF corruption, or merge-queue flakiness.
- Local commit hooks or any network requirement for `git commit`; commits are reversible and do not publish work.
- Serializing ordinary `AGENTS.md` router-row edits in v1; Git remains responsible for those recoverable text conflicts.
- Preventing every possible Git merge conflict or malicious administrator bypass.
- Database, production, shared-db, or infrastructure mutation.

## 5. Current state of the code

- The first plan is published on `origin/main` at `ac72d40798d3867feef83b3d4de1bcc49acf045c` and linked from `AGENTS.md`. It is a planning artifact only; no claim tool exists. This revision is on `codex/revise-work-claims-plan-131` in PR #136 and must be refreshed after every review-driven edit.
- Issue #131 is open. No `work-claim` labels, refs, policy file, command, tests, hooks, or workflow have been implemented.
- `AGENTS.md:20-27` now requires feature branch + PR; `config/repository-policy.json` maps both old and new ai-devops owner names to `feature-branch-pr`.
- Active ruleset `21564317` requires pull requests, squash merging through the merge queue, and `linux-offline` + `windows-offline` checks. Organization admins have an always-bypass capability; the implementation must not use it.
- `HANDOFF.d/` avoids one shared handoff file but records continuation, not live edit ownership.
- Existing wrapper-local mutex patterns (`bin/ai-grok-review`, `bin/ai-glm`) protect particular paid/session work. They prove atomic local-directory locking patterns but are not cross-machine repository ownership.
- `bin/ai-completion-check-hook` documents that instruction wording alone did not reliably enforce completion behavior. This is direct evidence that claims need mechanical fencing, not only global prose.
- `tests/test-all.sh:6` discovers `tests/test-*.sh`, so a correctly named focused test joins the full suite.
- `install.sh:201-206` installs executable `bin/` entries generically on Ubuntu.
- `plan_repo-throughput-restructure.md` is the prerequisite throughput workstream. Its STATUS table is authoritative; this plan does not duplicate or silently absorb that implementation.
- `plan_must_address.md` contains Parts A, B, and C from two execution-heavy sessions and is required reading before claims work. The evidence it names under `tests/verification/reviewer-flake-89/` is now present on `origin/main`.
- PR #136's first `windows-offline` attempt was manually canceled after 66 minutes stuck inside the full suite; its retry also ran abnormally long. This is live confirmation that queue reliability precedes adding any claim check.

## 6. Key findings and root cause

1. **Duplicate work is an intent collision, not just a path collision.** Two clean worktrees can solve the same task with disjoint initial files. Default ownership must therefore be one writer per task issue.
2. **Issue creation/listing is not atomic admission.** If two candidates cannot see each other due to eventual consistency, both can proceed. A delay and lowest issue number are a tie-break, not a mutex.
3. **Create-only Git refs are the leading atomic-admission hypothesis, not yet a finding.** Phase 1 must prove on both Windows Git Bash and Ubuntu that one fully qualified task ref has one successful creator, a competing create cannot change it, lost-response readback is exact, and force-with-lease works in the selected namespace. Until that artifact exists, do not state the behavior as established.
4. **GitHub REST ref updates do not provide compare-and-swap.** Heartbeat, path extension, and release must use Git protocol `--force-with-lease=<ref>:<expected-oid>` plus exact post-operation readback. A plain REST PATCH is forbidden for ownership mutation.
5. **Automatic expiry creates split-brain.** A disconnected writer can keep editing after its lease expires. Therefore elapsed liveness marks a claim stale but does not free it. V1 admits no successor and reports exact evidence for manual reconciliation.
6. **Prompt-only enforcement is insufficient, but enforcement cost matters.** V1 uses a separate fast advisory PR workflow. It does not install shared hooks, intercept Git publication, or add a required queue check while the queue is unreliable.
7. **Work-units are unnecessary v1 complexity.** The only measured collision was same-issue work. One task key prevents that without scope-block modes or partial ownership.
8. **Debugging paths are not knowable up front.** Issue #89 named two files and correctly changed ten. The owner may append paths without surrendering ownership; another session cannot use path wording to create a second claim.
9. **Public metadata cannot contain bearer ownership.** Store only `sha256(raw_owner_token)` publicly. Raw random tokens stay in user-only state and authorize renew/release by hash proof.
10. **AGENTS.md is a measured hot file but mostly cheap conflict.** Freezing every router-row edit would serialize legitimate work and attack the wrong problem. V1 has no high-risk path policy or component locking.
11. **Stale branch guidance caused an actual process violation.** The plan must derive branch policy from live `origin/main` and policy/ruleset immediately before landing, not from an old working copy.
12. **Component refs are unnecessary v1 complexity.** Task-wide ownership addresses the measured expensive duplicate-work failure. Cross-task same-file edits remain visible Git conflicts; component refs add partial-acquisition, rollback, livelock, and orphan recovery before evidence shows that machinery is needed.
13. **The merge queue is the dominant measured tax.** It affects every change, while claims address a minority failure. Stabilize the existing queue first and keep the v1 guard advisory.
14. **Network loss must not block ordinary Git.** Acquire, heartbeat, extend-paths, verify-owned, release, and other claim commands fail closed; ordinary `git commit` and `git push` never call the claim command. Secondary rate limiting must produce a bounded message that says not to poll.
15. **Issue closure is not ownership revocation.** Merge commonly closes the issue before follow-up evidence is understood. The existing owner may continue under the same protective ref until explicit release; the audit records the closed state and follow-up purpose.

## 7. Approaches considered and REJECTED, and why

1. **Full shared-db-style orchestrator — rejected.** It would serialize intentional independent work and add a coordinator tax to recoverable Git changes.
2. **Committed claims file/index — rejected.** Branch-local, stale, and itself a shared mutable collision point.
3. **Local filesystem lock as authority — rejected.** It cannot coordinate machines/clones. Local state may prove token possession but never grant remote ownership.
4. **One GitHub issue per claim plus sleep/lowest-number winner — rejected.** Not atomic under delayed visibility, retry, pagination, or partial failure; adds tracker clutter.
5. **GitHub issue comments/body/labels as the lock — rejected.** Human-visible but not compare-and-swap admission. They remain audit/UI only.
6. **Automatic expiry admission — rejected.** Creates split-brain while an old session is still editing.
7. **Prompt-only verify/renew/release — rejected.** Existing completion enforcement shows wording alone does not hold.
8. **Session-chosen work-unit in every duplicate key — rejected.** Different wording permits accidental duplicate owners.
9. **Paths as admission keys — rejected.** The guard cannot safely turn evolving diagnostic paths into a second ownership key; v1 paths remain optional, append-only diagnostics.
10. **Public raw owner token — rejected.** Anyone with repository read access could replay it; publish only its hash.
11. **Protecting all `AGENTS.md` edits — rejected for v1.** It serializes cheap router conflicts rather than expensive duplicate implementation.
12. **Creating a candidate when a visible owner already exists — rejected.** Read existing exact refs first for a fast refusal; atomic create still decides races.
13. **Broad scheduled cleanup — rejected.** Stale claims are safety evidence and remain protective until bounded reconciliation.
14. **Custom ref namespace assumed without qualification — rejected.** Official GitHub docs accept fully qualified refs with at least two slashes, but API read/delete behavior and this repository’s ruleset must be proved with a disposable ref before choosing the production namespace.
15. **Direct push to `main` — rejected and prohibited.** Live repository contract requires branch + PR + merge queue; admin bypass is not normal workflow.
16. **Component refs in v1 — rejected after GLM review.** They do not address the primary same-task duplication better than the task ref and introduce partial-acquisition/livelock risk. Reconsider only from measured cross-issue contention evidence.

## 8. Design decisions already made (2026-08-27)

### LOCKED — do not relitigate

- No permanent orchestrator, committed claims registry, external service, or repository-wide serialization.
- GitHub Git refs are the only admission authority. Issue comments/labels are visibility/audit only; local files never grant ownership.
- V1 has exactly one task ref per `(canonical repository, task issue)`. It has no units or component refs.
- Intended paths are optional diagnostics and advisory-publication scope. The owner may append paths through exact force-with-lease mutation; paths may never create a second admission key.
- No successor is admitted merely because a claim is old. Stale/malformed claims remain protective. V1 reports them for manual reconciliation and has no takeover command.
- Public metadata contains the owner-token hash only. Raw token is random, user-only, outside the repository, and never logged or committed.
- Generate a new raw token for every acquisition. Persist token + intended synthetic object SHA locally in `candidate` state before remote creation, so a lost create response can be re-adopted only when exact readback matches both.
- REST is create-only after Phase 1 qualification. Later mutation/deletion uses Git `push --force-with-lease=<ref>:<expected-oid>` plus exact readback; plain REST PATCH/DELETE is forbidden for ownership mutation.
- Ref-layer mutation is cooperative accident prevention, not hostile-user security. Shared GitHub authority can bypass it; audit and advisory checks make ordinary mistakes visible.
- Owner heartbeat, extend-paths, verify, and release validate the exact previous object and token hash. No unconditional force update or unleased delete.
- Read-only investigation is non-blocking and does not require ownership. V1 prevents duplicate implementation, not duplicate diagnosis. A future non-blocking intent signal requires separate evidence.
- Claim commands fail closed on unavailable or ambiguous ownership, with a specific secondary-rate-limit message telling the session not to poll. Ordinary `git commit` and `git push` are not intercepted.
- Exact-head binding is deferred from v1 because no non-bypassable local mechanism remains after correctly removing shared hooks. Advisory CI checks task/ref ownership and declared-path diagnostics without claiming to prevent ordinary `git push` bypass.
- `work-claim-guard` is advisory in v1, including merge-group runs, and lives only in `.github/workflows/work-claim-advisory.yml` so its result is not hidden behind `windows-offline`. It is absent from `verify.yml` and ruleset `21564317`; advisory is a complete—not partial—v1 state.
- Issue closure does not stop the current owner. Ownership ends only by exact release or later manual reconciliation; closed state and follow-up purpose remain visible in audit metadata.
- Implementation lands through feature branch + PR + merge queue; admin bypass is forbidden.

### OPEN — resolve by the stated evidence gates, not preference

- **Ref namespace:** prefer `refs/ai-devops-claims/<key>` if live qualification proves REST create/read/list plus Git force-with-lease update/delete and ruleset compatibility. Otherwise use `refs/heads/ai-work-claims/<key>` and accept transient branch visibility. Do not use tags. Record the proof before coding.
- **Liveness interval:** warn after 8 hours and classify stale after 24 hours unless measurement proves a longer heartbeat-less session. Liveness never transfers ownership. Heartbeat adapters are optional convenience; absence of a Codex lifecycle hook is safe because ownership remains protective.
- **Post-v1 promotion:** after 30 days, consider units, takeover, hooks, or making the guard required only from measured need. Required-check promotion needs zero claim-guard-caused ejections, a stable queue pass rate target recorded by the throughput plan, and Albert's current-chat authorization naming ruleset `21564317` and the check.

No owner decision is needed to implement and ship advisory v1 after the throughput prerequisite passes. Any manual stale-ref mutation, future takeover mechanism, or required-check promotion is outside v1 and needs a separately authorized procedure.

## 9. The plan — numbered, ordered, executable steps

### Phase 0 — remove the repository-wide throughput blocker

#### 9.1 Complete the queue-reliability prerequisite

Follow `plan_repo-throughput-restructure.md`, not this plan, for implementation details. At minimum, replace the issue-#89 concurrency wait's frozen-baseline deadline with progress-sensitive hang detection, preserve the paid-work lock semantics, run the rate-derived ten-run series with deliberate defect injection, add path filtering for documentation-only changes, and stop Windows from repeating Linux-only Bash coverage. Never raise a multiplier, add retries, quarantine the check, or mark it allowed-to-fail.

Capture a fresh merge-queue baseline after the fix using the same derivation as `plan_must_address.md` Part 0. The prerequisite passes only when the throughput plan's STATUS says its determinism and CI-cost gates are done and cites rerunnable artifacts. One green run is insufficient.

Dependencies: none. This is owned by the throughput plan and issue #89 workstream.

**Verification gate:** `plan_repo-throughput-restructure.md` cites the progress-sensitive test, defect-injection proof, ten-run series, path-filter proof, Windows/Linux coverage split, and a post-fix queue sample produced with the exact `gh run list` command in §9.3. Until then, do not implement claims or add any new workflow check.

### Phase 1 — qualify authority and freeze the v1 contract

#### 9.2 Re-derive live policy and qualify the Git-ref primitive on both platforms

From a clean feature branch based on fetched `origin/main`, capture: canonical remote identity, `AGENTS.md` branch rule, `config/repository-policy.json` result, ruleset `21564317`, issue #131 state, and existing matching refs. Create one disposable ref pointing to a synthetic commit whose message contains harmless test metadata and a token hash. Prove: first REST create returns 201; same-name second create returns a non-success without changing the ref; a simulated lost response is resolved by exact ref/object/owner-hash readback; exact readback matches; Git `push --force-with-lease=<ref>:<expected-oid>` updates only from the expected object and rejects a stale expected object; lease-protected delete succeeds only from the expected object; and the selected namespace is discoverable without issue search. Delete the disposable ref and verify absence.

Use `gh api` only for create/read/list/object creation and Git protocol force-with-lease for update/delete. If a custom namespace is not fully supported by both paths, repeat using `refs/heads/ai-work-claims/qualification-<random>` and select the branch namespace. Do not test on `main`, use unconditional force, or leave the qualification ref behind.

Target evidence: `tests/verification/work-claims/<UTC>/ref-qualification.md`, containing status codes, ref names, object SHAs/hashes, ruleset result, cleanup proof, and no raw token.

Run the force-with-lease create/update/stale-update/delete qualification from both Windows Git Bash and Ubuntu against disposable refs in the same selected namespace. A platform-specific success does not establish portability.

Dependencies: 9.1. This is the authority gate.

**Verification gate:** evidence proves exactly one creator, lost-response re-adoption, force-with-lease stale-object refusal, lease-protected deletion, selected namespace, and zero surviving disposable refs. If it does not, stop; do not implement an issue/sleep fallback.

#### 9.3 Freeze the task-only schema and measurement baseline

Create `config/work-claim-policy.json` with schema version, canonical repository aliases, selected ref namespace, task-only key derivation, 8h warning/24h stale thresholds, per-acquisition owner-hash algorithm, optional append-only path rules, and output limits. Create strict fixtures under `tests/fixtures/work-claims/` for candidate, healthy, stale, malformed, lost-response, closed-task-follow-up, and owner-path-extension states. Do not add unit, takeover, exact-head, or high-risk-path schema.

Define one ref key as a deterministic lowercase hash over the versioned canonical repository/task tuple. Synthetic metadata includes schema, canonical repo, task issue, per-acquisition owner hash, client, machine nickname, append-only intended paths, base SHA, issue open/closed observation, follow-up purpose, created/heartbeat GitHub time, and previous object where applicable. No raw token or private absolute path.

`AGENTS.md`, ordinary docs, shared skills, tests, and memory remain ordinary Git conflict territory in v1. The task claim prevents same-task duplication; optional paths are descriptive only and do not classify or lock repository surfaces.

Before implementation, create `tests/verification/work-claims/baseline-<UTC>.md`. Run from the repository root in Git Bash and preserve raw JSON/TSV beside the Markdown:

1. Queue outcomes and timestamps: `gh run list --repo popcre/ai-devops --workflow verify --event merge_group --limit 30 --json databaseId,status,conclusion,createdAt,startedAt,updatedAt,headBranch > queue-runs.json`. Derive counts and durations with committed `jq` expressions copied into the artifact.
2. Open-PR overlap: `gh pr list --repo popcre/ai-devops --state open --limit 100 --json number,headRefOid > open-prs.json`; for each number, run `gh pr view "$n" --repo popcre/ai-devops --json files` and write sorted `PR<TAB>path` rows to `open-pr-files.tsv`; use `sort | uniq -c` to report paths present in more than one PR.
3. Historical same-issue near-miss: record exactly one known event, issue #89, citing `plan_must_address.md` C-0. Do not convert private transcript review into counts or hours.
4. After launch, every `acquire` success/refusal and advisory finding writes a bounded public audit marker `<!-- ai-work-claim-event:v1 -->` plus JSON fields `event`, `task`, `ref_key`, `owner_hash`, `timestamp`, and `reason_code` to the task issue. The follow-up command is `gh api --method GET --paginate repos/popcre/ai-devops/issues/comments -f per_page=100 | jq -c '.[] | select(.body | contains("<!-- ai-work-claim-event:v1 -->"))' > claim-events.jsonl`.

The expected benefit threshold is at least one genuine same-task duplicate implementation refusal in 30 days, with zero false-owner refusals, zero blocked commits, and zero queue ejections caused by claims. Copied-provider repair plans are architecture duplication and excluded from the claims benefit.

Dependencies: 9.2 selected namespace.

**Verification gate:** every fixture maps deterministically on Windows Git Bash and Ubuntu; the same task has one key regardless of purpose/path wording; only the owner can append paths; malformed/unknown policy fails closed for remote ownership actions; every baseline command runs as written; and independent recomputation matches the artifact without private transcripts.

### Phase 2 — command and lifecycle

#### 9.4 Implement read-only discovery first

Create executable `bin/ai-work-claim` following repository Bash conventions and verification-header style. Implement canonical remote discovery, `gh` authentication/repository preflight, strict policy/schema parsing, exact ref listing/readback, task-issue/scope validation, GitHub server-time extraction, local user-state path handling, and commands `list`, `status`, and `doctor`.

`status --task ISSUE [--path PATH...]` reports `clear`, `owned`, `blocked`, `stale-protective`, or `ambiguous`, with exact task/ref/issue evidence. `doctor` is read-only by default and reports orphan comments, refs without valid metadata, local tokens without refs, stale/malformed refs, and remote/local mismatches. The explicit `doctor --recover-owned` may repair only local state from exact candidate/ref/object/hash evidence; it never mutates remote refs or ownership.

Dependencies: 9.3.

**Verification gate:** mocked tests prove canonical old/new remote aliases, pagination/all-ref discovery where applicable, GitHub-time use, bounded redaction, strict schema, and no repository mutation.

#### 9.5 Implement atomic, retry-safe task acquisition and path extension

Add `acquire --task ISSUE --purpose TEXT [--path PATH...]`. Require an existing task issue but do not make later issue closure revoke ownership. Normalize/validate any supplied paths. Generate a new token, build the intended synthetic object, and atomically persist a user-only `candidate` record containing raw token, owner hash, ref key, intended object SHA, task, purpose, and paths before POSTing the ref.

On a lost/ambiguous create response or 422, read the exact ref. If object SHA and owner hash match the persisted candidate, re-adopt the successful earlier create; otherwise report the other owner and stop before implementation. Repeating acquire with the same candidate is idempotent; a fresh acquisition never reuses a token. If candidate persistence fails, do not call GitHub. If audit comment creation fails after ownership, keep the ref protective and report `audit-pending` rather than releasing silently.

Add `extend-paths --task ISSUE --path PATH...`. Only the exact current owner may append normalized paths using force-with-lease from its recorded object. Existing paths cannot be removed or rewritten in v1. A racing mutation fails closed without losing ownership.

Dependencies: 9.4.

**Verification gate:** simultaneous same-task acquisitions yield exactly one owner regardless of purpose/path wording; lost-response retry re-adopts only its exact object; competitor 422 never re-adopts; the owner can grow two paths to ten without reacquiring; non-owner/racing path changes fail; persistence failures preserve a truthful recoverable state.

#### 9.6 Implement heartbeat, verification, release, and exact manual reconciliation

Add `heartbeat`, `verify-owned`, and `release`. Heartbeat advances the task ref only through force-with-lease from the exact recorded object and updates audit without exposing the token. `verify-owned` checks current owner hash/object and warns after 8h/stale after 24h without surrendering ownership. It reports issue closure but does not block the owner; follow-up work records a bounded purpose in metadata.

Release uses force-with-lease deletion from the exact recorded object and confirms absence; failure leaves the ref protective. There is no takeover command. For stale/closed-owner recovery, `doctor` prints canonical repo, task, exact ref, current object SHA, owner hash, last GitHub timestamp, issue state, any open PR whose body contains both `Task-Issue: #N` and the current `Work-Claim` ref key, and a copyable request: `Authorize manual reconciliation of <ref> at <object> for task #N by <delete|replace>, reason: <text>.` Only Albert's current-chat response naming the same ref/object/action authorizes a one-off operator procedure. The operator re-reads the ref, refuses a changed object or such an open PR, performs Git force-with-lease from that exact object, reads back the result, and posts the authorization/result audit URL. This is manual recovery, not standing permission or a v1 command.

Remote claim operations fail closed on network ambiguity. A secondary-rate-limit response is bounded and explicitly says not to poll; no retry loop is built into the command. Ordinary `git commit` and `git push` remain Git operations in v1 and are not intercepted; advisory CI records missed ownership without claiming mandatory local enforcement.

Dependencies: 9.5.

**Verification gate:** wrong-token operations fail; stale claims block new acquire; force-with-lease rejects stale heartbeat/release/path-extension attempts; interruption preserves the ref; issue closure permits only the same owner; offline/403 conditions never block Git commit/push and claim commands produce one non-polling error; manual reconciliation rejects changed object/open PR and produces complete audit evidence after exact authorization.

**Natural context cut:** after 9.6 focused tests pass, use `fresh-session`; re-read Phases 3–4 before continuing.

### Phase 3 — mechanical enforcement and routing

#### 9.7 Define non-interactive path extension and publication diagnostics

`extend-paths` is explicit and non-interactive: the owner supplies paths; the command never prompts Albert and never silently derives or appends files. It sorts/deduplicates the union, builds one successor object, and force-with-lease updates from the exact recorded object. On a same-owner race it re-reads once: if the new remote object has the same owner/task and already contains the requested union, adopt it; otherwise report the newer object and require the session to rerun `extend-paths`. Never loop automatically. Tokens are machine-local in v1, so only the acquiring machine can mutate/release; document that portability limit.

Do not install `pre-commit`, `pre-push`, `core.hooksPath`, a dispatcher, or global Git configuration in v1. Linked worktrees share the common Git directory, so repository-wide hooks are deferred unless post-launch evidence shows advisory CI repeatedly reporting unclaimed publication.

PR metadata includes `Task-Issue: #N` and `Work-Claim: <ref-key>` for advisory lookup without a raw token. Documentation gives the exact values from `status`; ordinary Git publication is not wrapped or blocked in v1.

Dependencies: 9.6.

**Verification gate:** fixtures prove explicit path extension is owner-only, union-preserving, bounded under same-owner races, and non-interactive; unrelated dirty files are ignored; tokens are documented machine-local; Git commit/push work with GitHub offline; no Git hook/config is changed; heartbeat failure leaves the claim protective.

#### 9.8 Add the advisory PR and merge-group claim guard

Create `.github/workflows/work-claim-advisory.yml` as a separate fast workflow on pull requests and merge-group candidates; do not add its job to `.github/workflows/verify.yml`. Give it a five-minute job timeout and one bounded API-read attempt with no retry loop. It reads consistent `Task-Issue: #N` and `Work-Claim: <ref-key>` metadata, derives the immutable diff, and reports whether public metadata matches repository, task, owner, and append-only paths. It reports malformed, superseded, missing, undeclared-file, and closed/stale states. It does not claim exact-head enforcement, require the raw token, or mutate refs/issues.

The workflow must always conclude successfully in v1 while emitting a clear advisory result/artifact; it is not named in ruleset `21564317`. Measure every advisory finding and any workflow/API failure for 30 days. Trailers and public metadata remain cooperative, not hostile-user security.

Dependencies: 9.7.

**Verification gate:** PR and merge-group fixtures accurately flag no-claim, inconsistent/missing trailers, wrong task/ref key, undeclared files, malformed ref, and superseded owner; closed/stale exact ownership warns; every case leaves the workflow advisory; its result completes independently of a deliberately delayed `verify.yml`; live ruleset readback proves it is not required.

#### 9.9 Route sessions concisely

Update `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md` with one aligned router rule: read-only investigation is non-blocking; before editing for an implementation task, acquire its task claim; blocked/stale ownership is not bypassed by renaming purpose or paths; advisory CI reports publication misses. Procedure lives in `docs/work-claims.md`. Update `AGENTS.md` and relevant trigger/context tests without pasting the lifecycle into always-loaded globals.

Dependencies: 9.7–9.8.

**Verification gate:** alignment/trigger tests show equivalent Claude/Codex routing, investigation remains non-blocking, implementation editing claims, publication enforcement is not overstated, and global context growth stays within budget.

### Phase 4 — documentation, qualification, landing

#### 9.10 Document, install, and restore

Create `docs/work-claims.md` covering business purpose, command lifecycle, task-only authority, optional explicit append-only paths, machine-local token limitation, issue audit comments, heartbeat, exact manual stale reconciliation, secondary-rate-limit behavior, separate advisory CI, measurement, and why this is not an orchestrator. Update architecture/configuration/deployment/restore/config inventory only where required. Generic installation owns the executable but does not install a push wrapper, Git hooks, or Git configuration.

Dependencies: 9.9.

**Verification gate:** docs links pass; install/refresh/uninstall preserve user Git config/hooks and leave no repository-local token; fresh-machine instructions end with read-only `doctor` and a disposable acquire/extend/release proof.

#### 9.11 Run bounded live concurrency/crash qualification

On a temporary qualification issue, run: ten simultaneous same-task acquisitions; one lost-create-response re-adoption; one competitor 422 refusal; heartbeat/path-extension force-with-lease races; one stale claim that remains protective and is reported by `doctor`; one changed-object/open-PR manual-reconciliation refusal; one authorized disposable manual reconciliation; one issue-close continuation by the same owner; one GitHub-offline commit/push; and one secondary-rate-limit claim-command refusal. Use harmless paths and synthetic refs only.

Record scrubbed issue/ref/object/status evidence under `tests/verification/work-claims/<UTC>/`. Close the qualification issue, delete every disposable ref with exact readback, and prove no matching refs/local tokens remain.

Dependencies: 9.10.

**Verification gate:** expected winner counts and protective failures pass; zero disposable state remains; ten trials are smoke evidence, not a mathematical proof—the atomic API response is the correctness basis.

#### 9.12 Full tests and independent exact-head review

Freeze the intended tree. Derive the repetition count from the failure rate the concurrency tests must exclude; the default minimum is ten consecutive clean focused runs, including concurrent load. Inject stale-object, wrong-token, lost-response, secondary-limit, closed-issue, and undeclared-path defects and prove each guard goes red/advisory as designed. Then run affected policy/installer/global/workflow tests, `tests/test-all.sh` through explicit Git Bash, named PowerShell tests, docs links, and `git diff --check`. Run one read-only exact-head final review; fix material findings and repeat affected/full gates and review after changes.

Dependencies: 9.11.

**Verification gate:** all gates pass from one frozen head/tree and the independent report approves that exact head without unresolved material finding.

#### 9.13 PR, merge queue, installation, and launch

Verify `Albert Hazan <u2giants@users.noreply.github.com>`, stage only issue #131 files, commit on a `codex/` feature branch, push, and open a PR to `main`. Do not use admin bypass. Wait for required PR checks, enqueue through the merge queue, verify `state=MERGED`, record squash SHA, verify merge-group/`main` checks, and confirm the exact intended files on `origin/main`.

Install/adopt through the documented preview-first path and prove one real acquire/extend-paths/heartbeat/verify/release lifecycle. Keep issue #131 and the handoff open through the 30-day effectiveness gate; implementation completeness is not business success.

Dependencies: 9.12.

**Verification gate:** merged squash SHA on `origin/main`; existing required PR/merge-group checks green; ruleset readback excludes `work-claim-guard`; installed smoke passes; no disposable claim remains; #131 remains open for measurement.

#### 9.14 Measure 30-day effectiveness and decide whether v1 earned its cost

Thirty days after launch, rerun the exact baseline commands from 9.3 and write `tests/verification/work-claims/follow-up-<UTC>.md`. Report genuine competing acquisitions refused, known duplicate implementations missed, advisory findings and false positives, GitHub/API blocks, operator recovery time, and any queue ejection attributable to claims. Do not estimate private-session hours. Separate copied-provider architecture duplication because claims do not fix it.

Apply this decision table; do not substitute a favorable narrative:

- One or more genuine competing acquisitions refused, zero false-owner refusals, zero blocked commits, and zero claim-caused queue ejections: keep v1.
- Zero genuine competing acquisitions refused and any false refusal, operator recovery exceeding 30 minutes, blocked commit, or claim-caused queue ejection: remove v1 through rollback.
- Zero genuine competing acquisitions and zero material friction: benefit is unproven; observe one additional 30-day window but do not expand.
- Any duplicate implementation that v1 should have refused but missed: keep #131 open, diagnose the boundary, and decide change versus removal before expansion.

Units, takeover, hooks, exact-head binding, or required-check promotion each require their own measured incident and plan amendment; none is automatic.

Dependencies: 9.13 plus 30 elapsed days.

**Verification gate:** follow-up artifact uses the same commands and definitions as baseline, records costs and misses—not just tool uptime—and issue #131 closes only after Albert accepts the evidence-based keep/change/remove decision.

## 10. Tests required

`tests/test-ai-work-claim.sh` must name and prove:

1. canonical repository alias normalization;
2. selected ref namespace REST create/read/list plus Git force-with-lease update/delete contract on Windows Git Bash and Ubuntu;
3. first create succeeds and same-key concurrent create has exactly one winner;
4. GitHub API ambiguous/partial/network responses fail closed for claim acquire and mutation, while ordinary local commit and push remain unwrapped;
5. missing task issue refusal and closed-task continuation by the same exact owner;
6. default task-wide exclusivity even when purpose/path wording differs;
7. optional path validation plus escape/absolute/symlink-boundary refusal;
8. owner-only append from two declared files to ten, with no reacquisition;
9. non-owner, removal, rewrite, and stale-object path mutations refused;
10. unknown policy refusal without extra refs;
11. per-acquisition candidate persistence before remote create;
12. lost-create response exact own-object re-adoption and competitor refusal;
13. raw owner token absent from public/log/repository output;
14. wrong-token heartbeat/extend/release refusal;
15. force-with-lease heartbeat/extend success and stale-object refusal;
16. stale/malformed claim remaining protective and doctor-only manual escalation;
17. lease-protected release and failure-preserves-ref recovery;
18. local token persistence failure preserving remote protection;
19. list/status/doctor bounded redacted diagnostics;
20. separate advisory workflow evaluating the immutable PR/merge-group diff and ignoring unrelated dirty work;
21. ordinary `git push` remains unwrapped and advisory misses are reported quickly without overstating enforcement;
22. secondary rate-limit message is bounded, identifies throttling, and says not to poll;
23. existing user hooks and Git configuration remain byte-identical through install/uninstall;
24. advisory PR guard exact trailer/ref/task/path consistency and forged/inconsistent trailer findings;
25. advisory merge-group verification never becomes a required/failing queue gate;
26. read-only investigation and unrelated repository behavior;
27. stable help/exit-code contract;
28. zero remote mutation by read-only commands and local-only exact recovery by `doctor --recover-owned`;
29. deliberate defect injection proves each safety path can detect its target;
30. rate-derived repeated/concurrent run series, minimum ten clean runs;
31. baseline and 30-day follow-up derivations use identical definitions;
32. no work-unit, takeover, local-hook, or required-check surface exists in v1.

Existing suites required: `tests/test-all.sh`; repository-policy/workflow/merge-queue tests; installer parity/lifecycle tests; global template alignment/context/trigger tests; documentation link checks; PowerShell tests named by affected setup; and `git diff --check`. Use `C:\Program Files\Git\bin\bash.exe` explicitly on Windows.

## 11. Constraints, standing rules, and gotchas in force

- Feature branch + PR + merge queue only. Never push directly to `main` or use organization-admin bypass.
- Re-derive live `origin/main`, issue, policy, ruleset, PR, claim refs, and merge-group state immediately before acting; handoffs and this plan are context, not live proof.
- Preserve unrelated dirty work. Stage only issue #131 files; never broad-stage, reset, clean, force-push, or delete unverified refs/state.
- This repository is public. No transcript excerpts, secrets, raw owner tokens, private absolute paths, credentials, or environment dumps.
- Runtime code must be portable Bash for Git Bash/Ubuntu; no `flock`, no OS binary replacement, no repository-local authority.
- GitHub is the only admission authority. Local state proves token possession but cannot create ownership.
- Stale/malformed claims remain protective until explicit reconciliation; age alone never admits a successor.
- Every ref mutation uses Git force-with-lease for the expected object plus readback. No unconditional force, REST PATCH/DELETE ownership mutation, broad namespace delete, glob deletion, or cleanup based on local assumption.
- Fast refusal may read an existing exact ref, but atomic create—not a preflight read—decides races.
- Issue comments/labels are audit/UI only. Never infer ownership from search indexing or a comment.
- `git commit` and `git push` remain ordinary, reversible Git operations independent of claim-command availability. Only remote claim acquisition and mutation fail closed.
- V1 must not install or alter Git hooks, `core.hooksPath`, or global Git configuration, because linked worktrees share that state.
- The advisory guard is not a required status check and must not eject a merge-queue batch.
- The claim system coordinates work intent; it does not authorize destructive Git, production/cloud/ruleset, database, or shared-db actions.
- Ruleset mutation is outside v1. Future promotion needs measured evidence and Albert naming the exact action/resource in the current chat.
- Exact-head independent review is mandatory because this changes shared concurrency and routing safety.
- STATUS rows marked done cite rerunnable evidence/commit/CI artifacts, never unsourced counts or issue numbers alone.

## 12. Access and environment

- Canonical repository: `popcre/ai-devops`; target branch `main`; implementation branch prefix `codex/`.
- Planning branch: `codex/revise-work-claims-plan-131`. Worktree paths are machine-local and must be discovered, never copied from this plan.
- GitHub CLI is authenticated and can read issue #131, refs, rulesets, PRs, and checks. Recheck before live qualification.
- Active ruleset: `21564317`, “main: pull request + merge queue”. Its mutation is not authorized merely by this plan.
- Windows Bash: `C:\Program Files\Git\bin\bash.exe`.
- Runtime dependencies already installed by the toolkit: Bash, Git, GitHub CLI, and `jq`.
- No database, hosted application URL, test login, or new secret is required.
- Raw claim tokens live only under `${AI_WORK_CLAIM_STATE_DIR:-$HOME/.local/state/ai-devops/work-claims}` on both Ubuntu and Windows Git Bash, matching the existing reviewer-wrapper convention. Create the root with mode `0700`, token files with mode `0600`, and updates by same-directory temporary file plus atomic rename. Never write a raw token to the repository, task issue, logs, or command arguments; public records contain hashes only.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Throughput prerequisite is complete with deterministic reviewer tests, reduced CI duplication, and a rerunnable post-fix queue sample.
- [ ] Windows and Ubuntu evidence qualifies the selected ref namespace/atomic behavior and proves cleanup.
- [ ] Strict task-only policy/schema and owner-extensible path contract exists; no units/takeover/hooks are present.
- [ ] Atomic acquire, lost-response recovery, heartbeat, extend-paths, verify, release, status, doctor, and exact manual reconciliation work as specified.
- [ ] Stale/malformed ownership remains protective; no automatic expiry split-brain.
- [ ] Local commits and pushes remain unwrapped; advisory PR/merge-group diagnostics pass defect-injection and repeated concurrency tests.
- [ ] Ruleset `21564317` readback proves `work-claim-guard` is not required in v1.
- [ ] Claude/Codex routing is aligned, concise, installed, and within context budget.
- [ ] Operating/architecture/configuration/deployment/restore docs are accurate and linked.
- [ ] Bounded live concurrency/crash qualification passes with zero surviving disposable state.
- [ ] Exact-head independent review approves the frozen final tree.
- [ ] Correct Git identity proven; feature-branch PR passes required checks and merge queue without admin bypass.
- [ ] Exact squash commit and merge-group/`main` checks verified on `origin/main`.
- [ ] Installed smoke lifecycle succeeds; baseline artifact is published; issue #131 and handoff remain open during observation.
- [ ] Thirty-day follow-up measures prevented/missed duplication, friction, false positives, API blocks, and queue effects using the baseline definitions.
- [ ] Albert accepts the evidence-based keep/change/remove decision; only then issue #131 closes, handoff retires, and STATUS cites final artifacts.

### Risks and mitigations

- **Custom namespace unsupported/inconsistent.** Phase 1 proves it before coding; fallback is transient `refs/heads/ai-work-claims/*`, not issue settlement.
- **Crashed owner blocks work.** Deliberate v1 safety trade: stale remains protective and doctor supplies exact evidence for manual reconciliation. No automated takeover exists.
- **Models publish without a claim.** Advisory CI makes the miss visible but does not gate the queue. Measure misses for 30 days before deciding whether stronger enforcement is justified.
- **Task issue wording permits duplicate issues.** Default one-writer-per-task stops same-issue duplicates; `doctor` reports suspicious overlapping declared paths across issues. Human task triage remains necessary for truly duplicated issue records.
- **Ref clutter.** Successful release deletes exact refs; doctor reports stale/malformed refs. Branch namespace is accepted only if custom namespace is unsupported.
- **Admin bypass defeats guard.** It is technically possible but prohibited; audit can detect direct main pushes. No software inside the repo can prevent an organization admin from overriding GitHub.
- **GitHub unavailable or selectively throttled.** Investigation and ordinary `git commit`/`git push` continue; acquire and remote claim mutation stop once with a specific non-polling message.
- **Advisory check misfires.** It cannot eject the queue in v1; record false positives and fix them before any promotion discussion.
- **Claim machinery costs more than it saves.** The 30-day gate explicitly permits rollback/removal rather than declaring success from implementation completeness.

### Open questions with decision criteria

1. **Custom vs branch ref namespace:** decide only from Phase 1 live REST-create/read/list plus Git force-with-lease update/delete evidence. Prefer custom if fully supported; otherwise branch namespace.
2. **Publication enforcement:** v1 intentionally has none beyond advisory reporting. Revisit exact-head binding or push enforcement only if the 30-day evidence shows unclaimed publication, with a mechanism that does not install shared hooks or delay feedback behind the full verification workflow.
3. **Post-v1 expansion:** units, takeover, hooks, and required-check promotion remain separate future decisions. Each requires a measured incident, 30-day v1 evidence, and a plan amendment; do not infer approval from this plan.

### Rollback

Revert the merged implementation through a new feature-branch PR and merge queue. Preview uninstall, restore globals/config, and remove only manifest-owned command/wrapper integrations; v1 has no hooks or ruleset mutation to restore. Keep claim refs protective during rollback; release/delete each only after exact owner/object validation and record the rollback on its task issue. Preserve audit comments/history. There is no database or hosted-service rollback.

## Mandatory self-audit — final answers

1. **Could a brand-new session execute this without asking Albert anything? Yes through advisory-v1 launch and measurement.** Sections 1–8 provide purpose, reproducible evidence, current state, rejected designs, and locked/open decisions. Steps 9.1–9.14 name targets, dependencies, behavior, and gates; post-v1 escalation is explicitly excluded rather than left ambiguous.
2. **Does the plan carry the full background and nuance, including failures? Yes.** Sections 3–7 and `plan_must_address.md` preserve the measured queue failure, the one live same-issue collision, the five within-owner hazards, unciteable-evidence boundary, rejected orchestrator/claims-file/issue-lock designs, and the reasons units/hooks/takeover/required CI were cut from v1.
3. **Is the ultimate goal clear enough for correct judgment when a step is wrong? Yes.** Section 1 makes prevented duplicate implementation, non-regression of throughput, network-independent commits, and measured value the controlling outcomes. Section 8 locks the deliberately small v1; Section 13 supplies keep/change/remove and rollback criteria.

**Checklist result:** all 13 required sections are present; goal-first precedence, explicit exclusions, reproducible evidence, rejected attempts, locked/open decisions, concrete files/steps/gates, named defect-injection and rate-derived tests, access/secrets boundaries, branch/PR/merge-queue landing, 30-day business measurement, risks, rollback, reciprocal handoff links, and evidence-backed self-audit are included. PASS.
