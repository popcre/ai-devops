# IMPLEMENTATION PLAN — collision-resistant ai-devops work claims (revised 2026-08-27)

**Tracking issue:** [popcre/ai-devops#131](https://github.com/popcre/ai-devops/issues/131)
**Registered handoff:** [`HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md`](HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md)

## STATUS — read this first

| Step | Status | Evidence |
|---|---|---|
| 0. Reconcile the first plan and review findings | ✅ done 2026-08-27 | §6–8; live policy/ruleset/PR #104; [`docs/work-claims-plan-review-2026-08-27.md`](docs/work-claims-plan-review-2026-08-27.md) |
| 1. Qualify atomic ref creation and force-with-lease mutation; freeze the contract | ⬜ open | §9.1–9.2; target evidence under `tests/verification/work-claims/` |
| 2. Build atomic task claims and safe stale reconciliation | ⬜ open | Target: `bin/ai-work-claim`, `config/work-claim-policy.json` |
| 3. Add deterministic concurrency, crash, fencing, and policy tests | ⬜ open | Target: `tests/test-ai-work-claim.sh` and focused policy suites |
| 4. Add mechanical local/CI fencing and concise client routing | ⬜ open | Target: claim guard, hooks/integrations, workflow, both global templates |
| 5. Document, install, and qualify on Windows/Linux | ⬜ open | Target: `docs/work-claims.md`, installer/restore evidence |
| 6. Independent exact-head review, PR, merge queue, and installed proof | ⬜ open | Target: review artifact, PR checks, merge-group run, merged SHA |

**Fresh-session starting point:** Step 1. Before each phase, fetch `origin/main`, read this STATUS table and all downstream steps, recheck issue #131 and the active GitHub ruleset, and preserve unrelated dirty work.

## 1. The ultimate goal — what we are trying to achieve

Albert should be able to run many AI sessions against `ai-devops` without paying twice for the same implementation or having sessions unknowingly edit the same high-risk operating surface. Unrelated work, including intentional audit/reviewer fan-out, must remain concurrent. The solution must coordinate different machines and clones, recover safely after crashes, and remain materially lighter than a permanent orchestrator.

Success means one atomic GitHub-backed owner exists for each write task; a second contender cannot believe it also won; stale ownership remains protective until explicitly reconciled; unclaimed or superseded work is mechanically blocked before publication; and ordinary cross-task Git conflicts remain visible rather than being turned into a repository-wide queue.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is POP Creations’ public backup-and-restore toolkit for a multi-model AI coding workflow. It contains Bash and PowerShell commands, Claude/Codex skills and global instructions, machine setup, reviewer wrappers, documentation, and offline verification. It is not a hosted application and has no application database or production service. Toolkit “deployment” is installation from the repository checkout.

The canonical repository is `popcre/ai-devops`; `main` is protected by active GitHub ruleset `21564317`. All changes use a feature branch, pull request, required Linux/Windows checks, and the merge queue. `AGENTS.md:20-27` and `config/repository-policy.json` are the repository contract. Organization administrators can technically bypass the ruleset, but that bypass is not the normal workflow and must not be used for this implementation.

The implementation must be portable between Ubuntu and Windows Git Bash. GitHub CLI authentication is already part of restore/setup (`docs/restore-from-zero.md:41-63`). `install.sh:201-206` installs executable Unix commands from `bin/`; Windows uses repository/setup-managed entrypoints.

## 3. What triggered this work

Albert asked whether ai-devops needs a shared-db-style orchestrator because concurrent AI work has produced repeated collisions. A private transcript review of the recent ai-devops period found approximately 72 Claude and 103 Codex ai-devops sessions on edge-dev. Much of that concurrency was intentional audit/reviewer fan-out, so raw session count is not itself a defect.

The measured problems were:

1. merge/rebase conflicts concentrated in shared operating surfaces, including instruction templates, shared skills, memory/docs, and some tests;
2. separate sessions independently diagnosing or repairing the same flaky reviewer tests or wrapper behavior, wasting paid model work without necessarily creating a Git conflict;
3. similar defects being planned/fixed repeatedly across copied reviewer implementations;
4. shared checkouts routinely containing unrelated dirty work, requiring isolated publication to preserve ownership;
5. stale local instructions causing incorrect branch behavior after the repository moved to `popcre`.

Claude recommended a lightweight committed claims file. That was rejected because branches/worktrees see stale copies, simultaneous sessions can start before either commit becomes visible, and the claims file becomes a new contention point. The first version of this plan replaced it with GitHub claim issues plus a five-second settlement/tie-break. Grok 4.6 returned `REVISE`: issue creation plus delayed listing is not atomic, prompt-only renewal/fencing does not prevent split-brain after expiry, free-form work-unit/path wording can evade duplicate detection, public owner tokens are unsafe, and the plan’s direct-to-main rule was stale.

The branch finding was independently reproduced: live `origin/main`, `config/repository-policy.json`, merged PR #104, and active ruleset `21564317` all require feature branch + PR + merge queue. The earlier direct push succeeded only through an organization-admin bypass and is not precedent.

GLM 5.3 then reviewed the refs-based revision and returned `REVISE`. It confirmed create-only refs, stale-protective ownership, task-wide keys, hashed tokens, mechanical fencing, and corrected branch policy. It found four remaining must-fix defects: GitHub REST refs have no compare-and-swap; takeover authorization/threshold was undecided; lost create responses lacked exact re-adoption; and PR head binding was deferred. It also recommended dropping component refs from v1. This revision incorporates all five corrections through Git force-with-lease, 24h + exact Albert-authorized takeover, per-acquisition candidate/object recovery, `bind-head` + exact CI rules, and task-only refs.

## 4. Scope — in and out

### In scope

- One portable `ai-work-claim` command using atomic GitHub Git-reference creation as admission authority.
- Default exclusive ownership keyed by canonical repository + open task issue.
- Optional parallel work-units only when predeclared in the task issue’s machine-readable scope block.
- Required file declarations and a small configured set of high-risk paths used for changed-file fencing and diagnostics. V1 does not acquire component refs.
- GitHub task-issue comments/label for human visibility, while refs—not comments, search, or issue ordering—decide ownership.
- Non-expiring protective ownership with liveness timestamps; stale claims do not admit a successor until explicit, audited reconciliation.
- Owner-token hashes in public metadata; raw owner tokens remain user-only outside Git.
- Local verification/fencing integrations and a required PR check so unclaimed/superseded work cannot merge.
- Read-only diagnostics, list/status/doctor, owner renew/release, and explicit stale/malformed takeover procedure.
- Offline concurrency/crash/security tests, bounded live ref qualification, documentation, installation, client routing, exact-head review, PR/merge-queue landing, and installed smoke proof.

### NOT in this plan

- A permanent orchestrator session, work queue, author-lane manager, or repository-wide merge serialization.
- A committed `CLAIMS.md`, shared JSON index, GitHub Project, external database/service, or scheduled closer.
- Automatic takeover merely because a timeout elapsed.
- Treating GitHub issue search, issue creation order, sleep duration, or first-page results as a mutex.
- Automatically refactoring copied reviewer implementations. That remains separate architecture work; claims only stop duplicate ownership.
- Claiming read-only analysis, transcript review, repository browsing, or independent reviewers.
- Serializing ordinary `AGENTS.md` router-row edits in v1; Git remains responsible for those recoverable text conflicts.
- Preventing every possible Git merge conflict or malicious administrator bypass.
- Database, production, shared-db, or infrastructure mutation.

## 5. Current state of the code

- The first plan is published on `origin/main` at `ac72d40798d3867feef83b3d4de1bcc49acf045c` and linked from `AGENTS.md`. It is a planning artifact only; no claim tool exists.
- Issue #131 is open. No `work-claim` labels, refs, policy file, command, tests, hooks, or workflow have been implemented.
- `AGENTS.md:20-27` now requires feature branch + PR; `config/repository-policy.json` maps both old and new ai-devops owner names to `feature-branch-pr`.
- Active ruleset `21564317` requires pull requests, squash merging through the merge queue, and `linux-offline` + `windows-offline` checks. Organization admins have an always-bypass capability; the implementation must not use it.
- `HANDOFF.d/` avoids one shared handoff file but records continuation, not live edit ownership.
- Existing wrapper-local mutex patterns (`bin/ai-grok-review`, `bin/ai-glm`) protect particular paid/session work. They prove atomic local-directory locking patterns but are not cross-machine repository ownership.
- `bin/ai-completion-check-hook` documents that instruction wording alone did not reliably enforce completion behavior. This is direct evidence that claims need mechanical fencing, not only global prose.
- `tests/test-all.sh:6` discovers `tests/test-*.sh`, so a correctly named focused test joins the full suite.
- `install.sh:201-206` installs executable `bin/` entries generically on Ubuntu.
- The original shared checkout is stale and dirty with unrelated work. This revision is owned on branch `codex/revise-work-claims-plan-131` in an isolated worktree based on `origin/main`.

## 6. Key findings and root cause

1. **Duplicate work is an intent collision, not just a path collision.** Two clean worktrees can solve the same task with disjoint initial files. Default ownership must therefore be one writer per task issue.
2. **Issue creation/listing is not atomic admission.** If two candidates cannot see each other due to eventual consistency, both can proceed. A delay and lowest issue number are a tie-break, not a mutex.
3. **Create-only Git refs provide atomic admission.** A single fully qualified task-ref name has one successful creator; a competing create receives conflict/validation failure. A lost response is resolved by exact readback against the per-acquisition owner hash and intended object SHA.
4. **GitHub REST ref updates do not provide compare-and-swap.** Heartbeat, bind-head, release, and takeover must use Git protocol `--force-with-lease=<ref>:<expected-oid>` plus exact post-operation readback. A plain REST PATCH is forbidden for ownership mutation.
5. **Automatic expiry creates split-brain.** A disconnected writer can keep editing after its lease expires. Therefore elapsed liveness marks a claim stale but does not free it. A successor needs explicit reconciliation/takeover with audit evidence.
6. **Prompt-only enforcement repeats a measured failure.** Concise instructions remain necessary, but local Git fencing and a required PR check provide mechanical enforcement.
7. **Free-form work-units are an evasion path.** Default key is the task issue. Parallel units are valid only when the issue declares their exact slugs before acquisition; sessions may not invent them to bypass a blocker.
8. **Optional paths make publication fencing honor-system.** Write claims require intended paths. Before commit/push/PR, the guard compares changed files against the declared set; undeclared changes fail. High-risk mappings improve diagnostics but do not create additional v1 locks.
9. **Public metadata cannot contain bearer ownership.** Store only `sha256(raw_owner_token)` publicly. Raw random tokens stay in user-only state and authorize renew/release by hash proof.
10. **AGENTS.md is a measured hot file but mostly cheap conflict.** Freezing every router-row edit would serialize legitimate work and attack the wrong problem. It is excluded from v1 high-risk mappings.
11. **Stale branch guidance caused an actual process violation.** The plan must derive branch policy from live `origin/main` and policy/ruleset immediately before landing, not from an old working copy.
12. **Component refs are unnecessary v1 complexity.** Task-wide ownership addresses the measured expensive duplicate-work failure. Cross-task same-file edits remain visible Git conflicts; component refs add partial-acquisition, rollback, livelock, and orphan recovery before evidence shows that machinery is needed.

## 7. Approaches considered and REJECTED, and why

1. **Full shared-db-style orchestrator — rejected.** It would serialize intentional independent work and add a coordinator tax to recoverable Git changes.
2. **Committed claims file/index — rejected.** Branch-local, stale, and itself a shared mutable collision point.
3. **Local filesystem lock as authority — rejected.** It cannot coordinate machines/clones. Local state may prove token possession but never grant remote ownership.
4. **One GitHub issue per claim plus sleep/lowest-number winner — rejected.** Not atomic under delayed visibility, retry, pagination, or partial failure; adds tracker clutter.
5. **GitHub issue comments/body/labels as the lock — rejected.** Human-visible but not compare-and-swap admission. They remain audit/UI only.
6. **Automatic expiry admission — rejected.** Creates split-brain while an old session is still editing.
7. **Prompt-only verify/renew/release — rejected.** Existing completion enforcement shows wording alone does not hold.
8. **Session-chosen work-unit in every duplicate key — rejected.** Different wording permits accidental duplicate owners.
9. **Optional paths — rejected.** The guard cannot mechanically assess protected overlap or undeclared edits.
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
- One exclusive task ref exists per `(canonical repository, open task issue)` by default.
- Parallel work-units are allowed only when the task issue already contains a valid machine-readable scope block listing exact unit slugs and their non-overlapping responsibilities.
- Task-wide and work-unit modes are mutually exclusive. A valid scope block makes bare task acquisition invalid and permits only exact listed units; without a scope block, unit acquisition is invalid and only the bare task claim is permitted. The scope block must exist before the first acquisition.
- Every unit claim records the exact scope-block digest. Adding, removing, or changing the scope block while any claim ref for that task exists fails closed until all claims are released or explicitly reconciled.
- Every write claim declares intended repository-relative paths. Paths fence the work and drive high-risk diagnostics; only the task key is an admission ref in v1.
- No successor is admitted merely because a claim is old. Liveness timestamps mark `healthy`, `stale`, or `malformed`; stale/malformed overlapping claims remain protective until explicit reconciliation/takeover.
- Public metadata contains the owner-token hash only. Raw token is random, user-only, outside the repository, and never logged or committed.
- Generate a new raw token for every acquisition. Persist token + intended synthetic object SHA locally in `candidate` state before remote creation, so a lost create response can be re-adopted only when exact readback matches both.
- Create-only REST admission is atomic. All later ref mutation uses Git `push --force-with-lease=<ref>:<expected-oid>` (including lease-protected deletion) plus exact readback; plain REST PATCH/DELETE is not an ownership mutation path.
- Ref-layer mutation is cooperative accident prevention, not a hostile-user security boundary: all sessions share Albert’s GitHub authority and could bypass the tool. Local/CI fencing and audit make ordinary mistakes fail closed; repository-admin bypass remains technically possible.
- Owner release/heartbeat/bind-head/takeover operations validate remote ref object, repository, task, unit, token hash, and expected previous object. No unconditional force update or unleased/unverified delete.
- Read-only work is exempt. Editing/committing/pushing/opening a PR requires a claim.
- Mechanical fencing is required: local changed-file/ownership checks plus a required PR check. Before PR, `bind-head` advances the owned task ref with force-with-lease to metadata containing the exact branch head SHA; CI requires that exact task/ref/head binding. Global instructions alone are insufficient.
- `AGENTS.md` is not a high-risk mapping in v1. High-risk path mappings cover global templates, installer/update/uninstall paths, shared skill implementation, repository policy/workflows, shared reviewer plumbing, and exact tests for diagnostics/fencing only; they do not create additional locks.
- Network/API ambiguity fails closed for acquire, renew, verification, release, and takeover. No local fallback grants ownership.
- Implementation lands through feature branch + PR + merge queue; admin bypass is forbidden.

### OPEN — resolve by the stated evidence gates, not preference

- **Ref namespace:** prefer `refs/ai-devops-claims/<key>` if live qualification proves REST create/read/list plus Git force-with-lease update/delete and ruleset compatibility. Otherwise use `refs/heads/ai-work-claims/<key>` and accept transient branch visibility. Do not use tags. Record the proof before coding.
- **Local fencing installation:** select the fewest-moving-parts supported mechanism that works in Git Bash and Ubuntu and cannot silently disappear. Candidate: repository-managed hooks path plus wrapper command. It must preserve user hooks/config and pass install/rollback tests. If Codex/Claude offer different lifecycle hooks, keep procedure centralized in `ai-work-claim` and adapters thin.
- **Stale takeover authority (locked contract):** takeover requires age of at least 24 hours, exact ref/object evidence, no open PR for the bound branch/head, a typed reason, and Albert’s explicit current-chat authorization naming the exact claim ref/task. The command requires an audit comment URL recording that authorization context. Because all sessions share Albert’s GitHub credentials, this is a cooperative authorization boundary, not cryptographic proof of who typed the comment.
- **Liveness interval:** warn after 8 hours and classify stale after 24 hours unless measurement proves a longer heartbeat-less session. Liveness never transfers ownership. Heartbeat adapters are optional convenience; absence of a Codex lifecycle hook is safe because ownership remains protective.
- **Required status check:** add a dedicated `work-claim-guard` job to the existing workflow, then update ruleset `21564317` only with Albert’s current-chat authorization naming that exact ruleset/check if the implementation session does not already have it. Until the ruleset is updated, the guard is informative and the feature is not complete.

No owner decision is needed to write/test the command through local/live-disposable qualification. A real takeover requires Albert’s exact current-chat authorization for that claim. Adding `work-claim-guard` as a required GitHub ruleset check requires Albert to authorize that exact ruleset action in the implementing chat.

## 9. The plan — numbered, ordered, executable steps

### Phase 1 — qualify authority and freeze the contract

#### 9.1 Re-derive live policy and qualify the Git-ref primitive

From a clean feature branch based on fetched `origin/main`, capture: canonical remote identity, `AGENTS.md` branch rule, `config/repository-policy.json` result, ruleset `21564317`, issue #131 state, and existing matching refs. Create one disposable ref pointing to a synthetic commit whose message contains harmless test metadata and a token hash. Prove: first REST create returns 201; same-name second create returns a non-success without changing the ref; a simulated lost response is resolved by exact ref/object/owner-hash readback; exact readback matches; Git `push --force-with-lease=<ref>:<expected-oid>` updates only from the expected object and rejects a stale expected object; lease-protected delete succeeds only from the expected object; and the selected namespace is discoverable without issue search. Delete the disposable ref and verify absence.

Use `gh api` only for create/read/list/object creation and Git protocol force-with-lease for update/delete. If a custom namespace is not fully supported by both paths, repeat using `refs/heads/ai-work-claims/qualification-<random>` and select the branch namespace. Do not test on `main`, use unconditional force, or leave the qualification ref behind.

Target evidence: `tests/verification/work-claims/<UTC>/ref-qualification.md`, containing status codes, ref names, object SHAs/hashes, ruleset result, cleanup proof, and no raw token.

Dependencies: none. This is the authority gate.

**Verification gate:** evidence proves exactly one creator, lost-response re-adoption, force-with-lease stale-object refusal, lease-protected deletion, selected namespace, and zero surviving disposable refs. If it does not, stop; do not implement an issue/sleep fallback.

#### 9.2 Freeze schema, key derivation, scope modes, and high-risk mappings

Create `config/work-claim-policy.json` with schema version, canonical repository aliases, selected ref namespace, task/unit key derivation, 8h warning/24h stale thresholds, per-acquisition owner-hash algorithm, issue-scope marker format, high-risk path mappings, and output limits. Create strict fixtures under `tests/fixtures/work-claims/` for candidate, healthy, head-bound, stale, malformed, parallel-unit, lost-response, closed-task, and takeover states.

Define one ref key as a deterministic lowercase hash over the versioned canonical task/unit tuple, while public task comments show readable task/unit/paths. Synthetic claim commit metadata must include schema, canonical repo, task issue, optional predeclared unit, exact scope-block digest when unit mode is active, per-acquisition owner hash, client, machine nickname, declared paths/high-risk classifications, base SHA, optional bound branch/head SHA, created/heartbeat GitHub time, and previous claim object where applicable. No raw token or private absolute path.

Initial high-risk path mappings must be explicit and narrow: global templates; lifecycle installers/updaters; shared skills; repository policy/workflows; named shared reviewer plumbing; and exact declared test files. They drive diagnostics and stricter changed-file messages, not separate refs. `AGENTS.md`, ordinary docs, and memory remain Git conflict territory in v1 because their measured collisions are recoverable and task ownership already prevents same-task duplication.

Dependencies: 9.1 selected namespace.

**Verification gate:** every fixture maps deterministically to the same task key/path classification on Windows Git Bash and Ubuntu; bare acquisition is refused in unit mode, unit acquisition is refused in bare mode, two different units are accepted only when the issue scope block predeclares both, and any active-claim scope-digest change fails closed; malformed/unknown policy fails closed for the requested work.

### Phase 2 — command and lifecycle

#### 9.3 Implement read-only discovery first

Create executable `bin/ai-work-claim` following repository Bash conventions and verification-header style. Implement canonical remote discovery, `gh` authentication/repository preflight, strict policy/schema parsing, exact ref listing/readback, task-issue/scope validation, GitHub server-time extraction, local user-state path handling, and commands `list`, `status`, and `doctor`.

`status --task ISSUE [--unit SLUG] --path PATH...` reports `clear`, `owned`, `blocked`, `stale-protective`, or `ambiguous`, with exact task/ref/issue evidence. `doctor` is read-only by default and reports orphan comments, refs without valid metadata, local tokens without refs, stale/malformed refs, and remote/local mismatches. The explicit `doctor --recover-owned` may repair only local state from exact candidate/ref/object/hash evidence; it never mutates remote refs or closes/rewrites ownership.

Dependencies: 9.2.

**Verification gate:** mocked tests prove canonical old/new remote aliases, pagination/all-ref discovery where applicable, GitHub-time use, bounded redaction, strict schema, and no repository mutation.

#### 9.4 Implement atomic, retry-safe task acquisition

Add `acquire --task ISSUE [--unit SLUG] --purpose TEXT --path PATH...`. Require an existing open task issue and read its scope state before acquisition. When a valid scope block exists, refuse bare acquisition and require an exact listed `--unit`; when none exists, refuse unit acquisition and allow only the bare task claim. Normalize/validate every path inside the repository and classify high-risk paths. Generate a new token for this acquisition, build the intended synthetic object, and atomically persist a user-only `candidate` record containing raw token, owner hash, ref key, intended object SHA, task/unit, exact scope digest, and paths before POSTing the ref. Re-read the scope immediately before and after ref creation; any digest/mode change fails closed and leaves the ref protective for reconciliation rather than declaring success.

On a lost/ambiguous create response or 422, read the exact ref. If object SHA and owner hash match the persisted candidate, re-adopt the successful earlier create and transition local state to `owned`; if they do not, report the other owner and stop before editing. Repeating acquire with the same candidate is idempotent; a fresh acquisition never reuses another token. If candidate persistence fails, do not call GitHub. If audit comment creation fails after ownership, keep the ref protective and report an `audit-pending` recovery state rather than releasing silently. `doctor --recover-owned` may re-adopt only from exact candidate/object/hash evidence.

Dependencies: 9.3.

**Verification gate:** simultaneous same-task acquisitions yield exactly one owner; bare and unit modes cannot coexist; different predeclared units both succeed; an active-claim scope change fails closed; lost-response retry re-adopts only its own exact object; competitor 422 never re-adopts; candidate/audit persistence failures preserve a truthful recoverable state.

#### 9.5 Implement heartbeat, verification, release, and explicit takeover

Add `heartbeat`, `bind-head`, `verify-owned`, `release`, and `takeover`. Heartbeat creates a new synthetic claim object and advances the task ref only through Git force-with-lease from the exact locally recorded object; it updates the task audit comment without exposing the token. `bind-head` similarly advances the owned ref to metadata containing exact branch name and head SHA before PR/push verification. `verify-owned` requires the task ref to match current owner hash/object, task still open, declared unit still valid, and changed files contained by declared paths. It warns after 8h and reports stale after 24h but does not surrender ownership.

Release uses force-with-lease deletion from the exact recorded object and confirms absence; failure leaves the ref protective. Takeover never triggers from age alone: require at least 24h without heartbeat, exact target ref/object, typed reason, no open PR for the bound branch/head, Albert’s current-chat authorization naming the exact task/ref, and an audit comment URL recording that authorization. Takeover uses force-with-lease from the old object directly to the successor’s synthetic claim object, avoiding a delete/create gap. Any stale expected object, audit ambiguity, or missing authorization preserves the old claim.

If the task issue closes mid-work, `verify-owned` blocks further editing/publication. The owner must either release and stop, or obtain authority to reopen the same issue and re-verify before continuing; it may not silently switch to another issue. If a heartbeat adapter is unavailable, ownership remains healthy for 8h and protective indefinitely; no competitor may self-takeover.

Dependencies: 9.4.

**Verification gate:** wrong-token operations fail; stale claims still block ordinary acquire; force-with-lease rejects stale heartbeat/release/takeover attempts; interrupted operations preserve the task ref; closed tasks block; an exactly authorized takeover produces one successor object and complete audit history without a ref-absent window.

**Natural context cut:** after 9.5 focused tests pass, use `fresh-session`; re-read Phases 3–4 before continuing.

### Phase 3 — mechanical enforcement and routing

#### 9.6 Add changed-file fencing and client heartbeat adapters

Implement a central guard subcommand that calls `verify-owned` and evaluates only the files being published: the staged index at pre-commit, the exact outgoing commit range at pre-push, and the immutable PR/merge-group diff in CI. It must never fence the whole dirty worktree; unrelated unstaged files in a shared checkout are ignored. Compare that exact publication set with the owned claim’s declared paths/high-risk classifications. Integrate it into the repository’s supported local Git hook/setup mechanism without overwriting user hooks or global Git configuration. Add thin Claude/Codex adapters only where supported to heartbeat during active write sessions; no adapter may become a second ownership authority.

Account explicitly for linked worktrees sharing one common Git directory/config: hook install/uninstall is repository-wide, not worktree-local. Use one manifest-owned dispatcher installed once per logical repository, chain any pre-existing hook safely, make concurrent installs idempotent, and never let one worktree uninstall a dispatcher still owned/needed by others. The hook is fail-closed for claim verification; this intentionally differs from the fail-open completion-honesty hook and must be tested as such.

The guard must block commit/push when: claim missing, task/unit mismatch, owner superseded, ref ambiguous, task closed, any changed file undeclared, or network verification unavailable. It must allow read-only activity and unrelated repositories. Before push/PR it requires `bind-head` against the exact branch head. Commit/PR metadata must include `Task-Issue: #N` and `Work-Claim: <ref-key>` trailers sufficient for CI lookup without a raw token.

Dependencies: 9.5.

**Verification gate:** local fixtures prove a normal Git command cannot publish unclaimed or superseded claimed work, pre-commit checks only staged files, pre-push checks only the exact outgoing range, unrelated unstaged files do not block another session, existing user hooks/config survive install/uninstall, and heartbeat failure leaves the claim protective rather than silently releasing it.

#### 9.7 Add the PR claim guard

Add a `work-claim-guard` job/workflow that runs on pull requests and merge-group candidates. It requires exactly one consistent `Task-Issue: #N` and `Work-Claim: <ref-key>` identity from the PR/commit contract, derives changed files from immutable PR/head data, reads the task ref, and requires its public metadata to match repository, task, optional unit, scope digest, declared paths, branch, and exact PR head SHA bound by `bind-head`. It rejects malformed, superseded, closed-task, forged-key, undeclared-file, changed-scope, and changed-head states. Liveness age follows the locked rule below: stale-but-still-exact owner/head may pass with a warning. It must not require the raw token and must not mutate refs/issues.

The exact CI rule is locked: a claim older than 24h may still pass only when its current ref object is head-bound to this exact PR head and no successor object exists; liveness age is a warning, not rejection, because ownership never auto-expires. Any different head requires the owner to run `bind-head` again through force-with-lease. Trailers and public metadata are forgeable by another session sharing Albert’s credentials; this is acceptable only under the documented cooperative accident-prevention threat model, not presented as hostile-user security.

Adding this job to required ruleset checks is outside repository code. The implementation session must obtain Albert’s current-chat authorization naming ruleset `21564317` and the `work-claim-guard` check before mutating it. Without that required-check update, mark implementation partial and do not call the system enforced.

Dependencies: 9.6.

**Verification gate:** PR and merge-group fixtures reject no-claim, inconsistent/missing trailers, wrong task/unit/ref key, undeclared files, changed head, malformed ref, closed task, and superseded owner; accept exact bound owner/head including stale-but-still-owned state; existing Linux/Windows jobs remain unchanged. Live ruleset readback proves the check is required only after explicit authorization.

#### 9.8 Route sessions concisely

Update `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md` with one aligned router rule: read-only work is exempt; ai-devops writers use `ai-work-claim`; blocked/stale ownership is not bypassed by renaming tasks/units/paths; procedure lives in `docs/work-claims.md`. Update `AGENTS.md` and relevant trigger/context tests. Do not paste the lifecycle into always-loaded globals.

Dependencies: 9.6–9.7.

**Verification gate:** alignment/trigger tests show equivalent Claude/Codex routing, read-only prompts do not claim, write prompts do, and global context growth stays within the repository’s measured budget.

### Phase 4 — documentation, qualification, landing

#### 9.9 Document, install, and restore

Create `docs/work-claims.md` covering business purpose, command lifecycle, task scope blocks, protected policy, ref authority, issue audit comments, heartbeat, stale protection, takeover, failure messages, local/CI fencing, and why this is not an orchestrator. Update architecture/configuration/deployment/restore/config inventory only where required. Ensure generic installation owns the executable and hook/adapters with preview, backup, idempotency, and rollback.

Dependencies: 9.8.

**Verification gate:** docs links pass; install/refresh/uninstall preserve user config and leave no repository-local token; fresh-machine instructions end with read-only `doctor` and a disposable acquire/release proof.

#### 9.10 Run bounded live concurrency/crash qualification

On a temporary qualification task issue, run: ten simultaneous same-task acquisitions; two predeclared units; one lost-create-response re-adoption; one competitor 422 refusal; one heartbeat force-with-lease race; one stale claim that remains protective; one exactly authorized test takeover using the plan’s non-production contract; one closed-task refusal; and one changed-file/bind-head/PR-head qualification. Use harmless paths and synthetic refs only; do not edit real source as the race payload.

Record scrubbed issue/ref/object/status evidence under `tests/verification/work-claims/<UTC>/`. Close the qualification issue, delete every disposable ref with exact readback, and prove no matching refs/local tokens remain.

Dependencies: 9.9.

**Verification gate:** expected winner counts and protective failures pass; zero disposable state remains; ten trials are smoke evidence, not a mathematical proof—the atomic API response is the correctness basis.

#### 9.11 Full tests and independent exact-head review

Freeze the intended tree. Run focused tests twice where concurrency matters, all affected policy/installer/global/workflow tests, `tests/test-all.sh` through explicit Git Bash, PowerShell tests where named, docs links, and `git diff --check`. Run one read-only exact-head final review after all edits because this changes concurrency/routing safety. Fix material findings, rerun affected/full gates, and repeat review if the tree changes.

Dependencies: 9.10.

**Verification gate:** all gates pass from one frozen head/tree and the independent report approves that exact head without unresolved material finding.

#### 9.12 PR, merge queue, installation, and closeout

Verify `Albert Hazan <u2giants@users.noreply.github.com>`, stage only issue #131 files, commit on a `codex/` feature branch, push, and open a PR to `main`. Do not use admin bypass. Wait for required PR checks, enqueue through the merge queue, verify `state=MERGED`, record squash SHA, verify merge-group/`main` checks, and confirm the exact intended files on `origin/main`.

Install/adopt through the documented preview-first path, prove one real acquire/heartbeat/verify/release lifecycle, update STATUS with artifacts, close issue #131, and delete this handoff only when every obligation is complete. Retain the completed plan as a decision record.

Dependencies: 9.11 and, for enforced completion, explicit authorization + successful ruleset required-check update from 9.7.

**Verification gate:** merged squash SHA on `origin/main`; PR and merge-group checks green; required-check readback includes `work-claim-guard` if authorized; installed smoke passes; no active/stale workstream claim remains; #131 closed; handoff retired.

## 10. Tests required

`tests/test-ai-work-claim.sh` must name and prove:

1. canonical repository alias normalization;
2. selected ref namespace REST create/read/list plus Git force-with-lease update/delete contract;
3. first create succeeds and same-key concurrent create has exactly one winner;
4. GitHub API ambiguous/partial/network responses fail closed;
5. missing/closed task issue refusal;
6. default task-wide exclusivity even when purpose/path wording differs;
7. bare acquisition refusal when a valid scope block exists, and unit refusal when it does not;
8. distinct predeclared units proceeding concurrently with the exact recorded scope digest;
9. scope block addition, removal, or change during active claims failing closed;
10. required path validation, escape/absolute/symlink boundary refusal;
11. high-risk path classification and unknown policy refusal without extra refs;
12. per-acquisition candidate persistence before remote create;
13. lost-create response exact own-object re-adoption and competitor refusal;
14. raw owner token absent from all public/log/repository output;
15. wrong-token renew/release/takeover refusal;
16. force-with-lease heartbeat/bind-head success and stale-object refusal;
17. stale claim remaining protective to ordinary acquire;
18. malformed overlapping claim remaining protective;
19. takeover success only after 24h + exact Albert authorization/task/ref/audit evidence;
20. takeover ambiguity preserving old ownership;
21. lease-protected release and failure-preserves-ref recovery;
22. local token persistence failure preserving remote protection;
23. list/status/doctor bounded redacted diagnostics;
24. changed-file guard rejecting every undeclared published edit, ignoring unrelated unstaged files, and classifying high-risk edits;
25. local commit/push fencing for missing, stale, superseded, closed-task, or network-unknown ownership;
26. existing user hook/config preservation and rollback;
27. PR guard exact trailer/ref/head/task/unit/scope/path binding and forged/inconsistent trailer refusal;
28. merge-group claim verification;
29. read-only exemption and unrelated repository behavior;
30. stable help/exit-code contract;
31. zero remote mutation by read-only commands and local-only exact recovery by `doctor --recover-owned`;
32. task issue closed mid-work blocks until release or authorized reopen/reverify;
33. shared-gitdir hook dispatcher concurrent install/uninstall preserves existing hooks and other worktrees.

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
- The claim system coordinates work intent; it does not authorize destructive Git, production/cloud/ruleset, database, or shared-db actions.
- Ruleset mutation needs Albert to name the exact action/resource in the current chat. Code/workflow can be prepared and tested without that mutation.
- Exact-head independent review is mandatory because this changes shared concurrency and routing safety.
- STATUS rows marked done cite rerunnable evidence/commit/CI artifacts, never unsourced counts or issue numbers alone.

## 12. Access and environment

- Canonical repository: `popcre/ai-devops`; target branch `main`; implementation branch prefix `codex/`.
- Planning revision worktree: `C:\Users\ahazan\.codex\worktrees\ai-devops-work-claims-plan-revision`, branch `codex/revise-work-claims-plan-131`.
- GitHub CLI is authenticated and can read issue #131, refs, rulesets, PRs, and checks. Recheck before live qualification.
- Active ruleset: `21564317`, “main: pull request + merge queue”. Its mutation is not authorized merely by this plan.
- Windows Bash: `C:\Program Files\Git\bin\bash.exe`.
- Runtime dependencies already installed by the toolkit: Bash, Git, GitHub CLI, and `jq`.
- No database, hosted application URL, test login, or new secret is required.
- Raw claim tokens belong in the established user-only ai-devops state root selected from existing architecture conventions; never the repository or task issue. Public records contain hashes only.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Live evidence qualifies the selected ref namespace/atomic behavior and proves cleanup.
- [ ] Strict policy/schema/task-unit/path-fencing contract exists.
- [ ] Atomic task acquire, lost-response recovery, heartbeat, bind-head, verify, release, doctor, and explicit takeover work as specified.
- [ ] Stale/malformed ownership remains protective; no automatic expiry split-brain.
- [ ] Local changed-file/commit/push fencing and PR/merge-group guard pass all failure tests.
- [ ] Claude/Codex routing is aligned, concise, installed, and within context budget.
- [ ] Operating/architecture/configuration/deployment/restore docs are accurate and linked.
- [ ] Bounded live concurrency/crash qualification passes with zero surviving disposable state.
- [ ] Exact-head independent review approves the frozen final tree.
- [ ] Correct Git identity proven; feature-branch PR passes required checks and merge queue without admin bypass.
- [ ] Exact squash commit and merge-group/`main` checks verified on `origin/main`.
- [ ] If explicitly authorized, ruleset readback proves `work-claim-guard` is required; otherwise status remains partial and issue stays open.
- [ ] Installed smoke lifecycle succeeds; issue #131 closed; handoff deleted; plan STATUS cites artifacts.

### Risks and mitigations

- **Custom namespace unsupported/inconsistent.** Phase 1 proves it before coding; fallback is transient `refs/heads/ai-work-claims/*`, not issue settlement.
- **Crashed owner blocks work.** Deliberate safety trade: stale remains protective; explicit audited takeover restores progress without silent split-brain.
- **Old owner resumes after takeover.** Its ref/object no longer matches, so local and PR guards reject publication. Existing dirty edits remain visible and must be reconciled, never silently deleted.
- **Models skip the command.** Local Git fencing and required PR check mechanically block publication; concise routing makes the correct path discoverable.
- **Task issue wording permits duplicate issues.** Default one-writer-per-task stops same-issue duplicates; `doctor` reports suspicious overlapping declared/high-risk paths across issues. Human task triage remains necessary for truly duplicated issue records.
- **Ref clutter.** Successful release deletes exact refs; doctor reports stale/malformed refs. Branch namespace is accepted only if custom namespace is unsupported.
- **Admin bypass defeats guard.** It is technically possible but prohibited; audit can detect direct main pushes. No software inside the repo can prevent an organization admin from overriding GitHub.
- **GitHub unavailable.** Read-only work continues; new/renewed/published write work fails closed.
- **Ruleset change unauthorized.** Prepare/test the guard but do not mutate the ruleset; status remains partial and #131 stays open.

### Open questions with decision criteria

1. **Custom vs branch ref namespace:** decide only from Phase 1 live REST-create/read/list plus Git force-with-lease update/delete evidence. Prefer custom if fully supported; otherwise branch namespace.
2. **Local hook/adapter implementation details:** choose the supported manifest-owned dispatcher that preserves existing user configuration, shared-gitdir worktrees, and Windows/Ubuntu behavior. Reject silent hook/global-config replacement.
3. **Required GitHub check:** completion requires exact ruleset authorization and readback. Without it, do not downgrade the definition of done.

### Rollback

Revert the merged implementation through a new feature-branch PR and merge queue. Preview uninstall, restore backed-up hooks/globals/config, and remove only manifest-owned integrations. Keep claim refs protective during rollback; release/delete each only after exact owner/object validation and record the rollback on its task issue. Remove the required ruleset check only with Albert’s explicit authorization naming ruleset `21564317`. Preserve audit comments/history. There is no database or hosted service rollback.

## Mandatory self-audit — final answers

1. **Could a brand-new session execute this without asking Albert anything? Yes through code/test/live-disposable qualification.** Sections 1–8 provide purpose, history, current state, rejected designs, and locked/open decisions. Every Step 9.1–9.12 names targets, dependencies, behavior, and a verification gate. The one external mutation—the required ruleset check—is explicitly gated on exact owner authorization rather than guessed.
2. **Does the plan carry the full background and nuance, including failures? Yes.** Sections 3, 6, and 7 preserve the transcript-derived collision/duplication evidence, why a full orchestrator and claims file were rejected, why the first issue/sleep plan failed Grok review, why automatic expiry/prompt-only enforcement are unsafe, and why the stale direct-main rule was wrong.
3. **Is the ultimate goal clear enough for correct judgment when a step is wrong? Yes.** Section 1 makes one-owner safety, concurrency, crash recovery, and low overhead the controlling outcome. Section 8 separates locked safety invariants from evidence-driven choices; Section 13 supplies stop/rollback criteria.

**Checklist result:** all 13 required sections are present; goal-first precedence, explicit exclusions, current evidence, rejected attempts, locked/open decisions, concrete files/steps/gates, named tests, access/secrets boundaries, branch/PR/merge-queue landing, external authorization boundary, risks, rollback, reciprocal handoff links, and evidence-backed self-audit are included. PASS.
