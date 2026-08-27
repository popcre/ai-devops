# IMPLEMENTATION PLAN — collision-resistant ai-devops work claims (2026-08-27)

**Tracking issue:** [popcre/ai-devops#131](https://github.com/popcre/ai-devops/issues/131)
**Registered handoff:** [`HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md`](HANDOFF.d/2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md)

## STATUS — read this first

| Step | Status | Evidence |
|---|---|---|
| 1. Freeze the claim contract and protected-surface policy | ⬜ open | This plan, §9.1 |
| 2. Build the GitHub-backed claim command | ⬜ open | Target: `bin/ai-work-claim` and `config/work-claim-policy.json` |
| 3. Add deterministic concurrency and failure tests | ⬜ open | Target: `tests/test-ai-work-claim.sh` |
| 4. Route Claude and Codex sessions through the preflight | ⬜ open | Target: both global templates and repository router |
| 5. Document, install, and validate on Windows and Linux | ⬜ open | Target: deployment/configuration docs and install tests |
| 6. Independent final review, landing, and live proof | ⬜ open | Target: exact-head review, CI run, and issue #131 evidence |

**Fresh-session starting point:** Step 1. Re-read all downstream phases before beginning each phase because concurrent work may change the named files.

## 1. The ultimate goal — what we are trying to achieve

Albert should be able to run many AI sessions against `ai-devops` without paying twice for the same implementation or having sessions unknowingly edit the same high-contention operating surfaces. Unrelated work must remain concurrent and ordinary Git conflicts must remain visible and recoverable. The control must be cheap enough that sessions actually use it, must recover safely after a crashed session, and must not require a permanent orchestrator session.

Success means every write-capable ai-devops session can make one quick, live GitHub-backed claim before editing; simultaneous claims deterministically produce one winner; expired ownership does not block forever; and malformed or ambiguous ownership fails safely on protected surfaces. If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is POP Creations' public backup-and-restore toolkit for a multi-model AI coding workflow. It contains command-line tools, shared Claude/Codex skills, global instruction templates, machine setup, and offline verification. It is not a hosted application and has no database or production service. GitHub `main` is the source of truth; toolkit “deployment” is local installation from the checkout.

The repository is currently at `C:\repos\ai-devops` on Windows `edge-dev`. Finished work goes directly to `main`, is tested locally, committed as Albert Hazan, pushed without force, and verified on `origin/main`. `install.sh:201-206` installs executable Unix commands from `bin/`; Windows uses the repository checkout and its setup paths. GitHub CLI authentication is part of restore/setup (`docs/restore-from-zero.md:41-63`).

## 3. What triggered this work

Albert asked whether ai-devops needs a shared-db-style orchestrator because concurrent work has produced many collisions. A review of the private ai-devops transcript archive found real merge conflicts concentrated in shared instructions, skills, and memory, but the larger cost was duplicate diagnosis and implementation—especially parallel reviewer/test repairs. Much of the apparent concurrency was intentional audit fan-out, so a repository-wide single orchestrator would serialize useful independent work.

Claude recommended a light claims file. The accepted direction is lighter than an orchestrator but stronger than a committed file: a live GitHub-backed lease with deterministic winner selection. A mutable file in the repository would itself contend, would be stale on branches/worktrees, and could not prevent two sessions from both starting before either commit was visible.

Issue [#131](https://github.com/popcre/ai-devops/issues/131) tracks implementation. No claim tooling has been implemented yet.

## 4. Scope — in and out

### In scope

- One cross-platform `ai-work-claim` command implemented in portable Bash for Git Bash and Linux.
- GitHub Issues as the live registry; claims are short-lived issues with machine-readable bodies and append-only renewal/release comments.
- Duplicate-work protection keyed by repository + task issue + work-unit.
- Collision protection for configured high-contention path prefixes.
- A two-phase acquire protocol that resolves simultaneous contenders deterministically before either may edit.
- Lease renewal, release, list/status, stale reconciliation, and diagnostics.
- Claude and Codex instructions that require the preflight for ai-devops writes but exempt read-only review and analysis.
- Offline mocked tests, focused live proof in `popcre/ai-devops`, installation/docs updates, and an exact-head independent safety review.

### NOT in this plan

- A permanent orchestrator session, queue manager, author lanes, or serialized repository-wide merge process.
- Database-style object claims, production locks, or any reuse of shared-db’s preview/production governance.
- Preventing all possible Git merge conflicts. Git remains the final merge safety layer.
- Automatically refactoring the eight reviewer implementations. That architectural consolidation is separate work; claims prevent duplicate ownership but cannot remove copied code.
- Claiming read-only analysis, reviewer runs, transcript review, or documentation browsing.
- A committed `CLAIMS.md`, generated claim index, local-only lock as source of truth, GitHub Project, external service, scheduled automation, or database.
- Automatic deletion of another live session’s worktree, branch, files, or metadata.

## 5. Current state of the code

- `AGENTS.md:20-27` already requires direct-to-main work, GitHub truth, and preservation of concurrent dirty changes, but it has no live ownership preflight.
- `AGENTS.md:65` routes continuation through matching handoffs, and `AGENTS.md:120` says active work appears in issues/plans/handoffs. These improve discovery but do not provide atomic ownership.
- `HANDOFF.d/` prevents sessions from overwriting one shared handoff, but handoffs describe continuation rather than current short-lived edit ownership.
- Reviewer wrappers already contain local mutex patterns, for example `bin/ai-grok-review:288-353` and `bin/ai-glm:259-284`. Those locks protect one machine/process family and are not a cross-machine repository claim service.
- `install.sh:201-206` automatically installs executable `bin/` entries on Ubuntu. No new install list is needed if `bin/ai-work-claim` is executable.
- `tests/test-all.sh:6` discovers `tests/test-*.sh`, so a correctly named test joins the full suite automatically.
- GitHub issue #131 is open. The repository has no `work-claim` labels, policy file, command, or tests.
- The checkout is dirty with unrelated reviewer-cache and taxonomy work. An implementing session must not stage, overwrite, reformat, or “clean up” those files.
- This plan and its handoff are planning artifacts only. Until committed and pushed, they are not yet on `origin/main`.

## 6. Key findings and root cause

1. **The expensive failure is not just textual merge conflict.** Sessions can independently diagnose or fix the same issue in clean worktrees, producing no Git conflict while duplicating paid work. Therefore the primary identity is the task/work-unit, not merely a filename.
2. **A committed claims file cannot be authoritative.** Concurrent branches and worktrees see different bytes, and the shared file becomes a new hot spot. Live GitHub state is required.
3. **A check-then-create registry has a race.** Two sessions can both observe no claim and both create one. The protocol therefore needs a settlement phase and deterministic winner using GitHub’s server-assigned issue number; only the oldest eligible contender may proceed.
4. **Repository-wide serialization is disproportionate.** Most transcript concurrency was intentional, independent audit/reviewer work. Only identical task/work-unit claims and configured protected-path overlap should block.
5. **Leases must survive crashes without permanent blockage.** Ownership expires unless renewed. Expired claims are ignored for admission but preserved until a bounded reconciliation command closes them, leaving audit history.
6. **Local clocks are not trustworthy for cross-machine ownership.** Lease age must use timestamps returned by GitHub and a GitHub response `Date` header, never one workstation’s clock.
7. **A path claim alone is too easy to game accidentally.** Every write claim requires an existing open task issue and a stable work-unit slug. Protected path prefixes add collision protection; the task identity prevents duplicate work across disjoint-looking files.
8. **Malformed ownership is dangerous only where it overlaps.** A malformed active claim that could overlap the requested task or protected surface must fail closed and name the issue. An unrelated malformed claim must be reported by `doctor` without freezing the entire repository.

## 7. Approaches considered and REJECTED, and why

1. **Full shared-db-style orchestrator — rejected.** Git work is branchable, conflicts are recoverable, and intentional fan-out is valuable. A sole coordinator would impose repository-wide latency without addressing copied reviewer architecture.
2. **Committed `CLAIMS.md` or JSON registry — rejected.** It is branch-local, stale, and itself a shared mutable collision point.
3. **Local filesystem locks — rejected as authority.** They cannot coordinate edge-dev, Linux hosts, remote machines, or independent clones. A local cache may improve messages but may never grant ownership.
4. **Simple “query then create” GitHub issue — rejected.** Simultaneous sessions can both pass the query. Deterministic post-create settlement is mandatory.
5. **One permanent registry issue with editable body — rejected.** It recreates a shared mutable document, has update races, and makes individual ownership/release history hard to audit.
6. **One permanent registry issue with comments only — rejected.** Append-only comments preserve history but require expensive whole-thread reconstruction and still need a tie-break protocol. One issue per short-lived claim gives native open/closed state and indexed queries.
7. **Git branches/refs as locks — rejected for v1.** They can provide atomic ref creation but require custom commit/ref metadata, pollute ref discovery, and complicate safe stale reconciliation. GitHub issue numbering plus settlement provides deterministic admission with substantially less machinery.
8. **Path-only claims — rejected.** Duplicate implementation often touches different files initially; task issue + work-unit is the duplicate-work key.
9. **Automatic scheduled closer — rejected for v1.** Expired claims can be ignored safely without a mutating bot. Manual/CI `doctor --reconcile-expired` is auditable and avoids introducing credentials or scheduled infrastructure.
10. **Broad freeze on any malformed claim — rejected.** One bad historical record must not stop unrelated work. Fail closed only for a potentially overlapping task or protected path, while surfacing all malformed records through diagnostics.

## 8. Design decisions already made (2026-08-27)

### LOCKED — do not relitigate

- No permanent orchestrator and no repository-wide serialization.
- GitHub is the only ownership authority; local state never grants a claim.
- Claims are separate short-lived GitHub issues labeled `work-claim` and `work-claim-active`; closing the issue releases it.
- Every write claim identifies an existing open task issue and a lowercase work-unit slug matching `[a-z0-9][a-z0-9-]{0,62}`.
- Duplicate identity is `(canonical repository, task issue number, work-unit)`.
- Protected collision identity comes from normalized path-prefix claims governed by `config/work-claim-policy.json`.
- Acquisition is two phase: create candidate, wait five seconds, re-query, and select the lowest GitHub issue number among all valid, unexpired contenders. A loser closes its own candidate and exits nonzero before editing.
- Default lease is 120 minutes; renew when fewer than 30 minutes remain. Bounds are 15–480 minutes. Lease time uses GitHub timestamps/server time.
- Read-only work is exempt. Any session that will edit, commit, push, or open a PR must claim first.
- Expired claims do not block acquisition. They remain visible until reconciliation closes them with an explanatory comment.
- The command prints no secret/token/environment values and never writes claim state into the repository.
- Protected surfaces initially include: `AGENTS.md`; `templates/system/`; `skills/shared/`; `install.sh`; `update.sh`; `uninstall.sh`; `bin/setup-machine.ps1`; `bin/bootstrap-windows-dev.ps1`; `config/machine-tools.tsv`; shared reviewer plumbing named by policy; and any test file explicitly claimed by another active session. Exact final prefixes are reviewed in Step 1, but coverage may not be weakened without transcript/Git evidence.

### OPEN — implementer judgment within stated criteria

- The exact JSON field names and shell function layout may change if the schema remains versioned, strict, and fully tested.
- The five-second settlement may be raised only if a repeated live race test proves GitHub search indexing is slower; choose the smallest value that passes ten simultaneous acquisition trials.
- Policy may use explicit prefixes plus named components if that produces clearer diagnostics. It must remain reviewable, secret-free, and deterministic.
- Whether expired reconciliation runs in ordinary `doctor` as read-only reporting or behind an explicit mutating flag. Closing claims must always require the explicit flag.

No owner decision is required before implementation. If live GitHub behavior disproves the issue-number settlement design, stop before substituting another authority and raise that evidence on issue #131.

## 9. The plan — numbered, ordered, executable steps

### Phase 1 — contract and command

#### 9.1 Freeze the schema and policy

Create `config/work-claim-policy.json` with schema version, repository identity, lease bounds, settlement seconds, label names, and protected path prefixes/components. Add a header comment block to the future `bin/ai-work-claim` documenting the protocol and threats it does and does not cover. Update this plan’s STATUS if live evidence changes a locked decision.

The claim issue body must be bounded and machine-readable between `<!-- ai-work-claim:v1 -->` markers and contain: canonical repository, task issue URL/number, work-unit, purpose summary, owner token, client (`claude`/`codex`), machine nickname, source checkout head, claimed normalized paths/components, requested lease minutes, candidate creation timestamp returned by GitHub, and schema version. The owner token is a random non-secret identifier stored under the user state directory, never the repository.

Dependencies: none. Do not begin code until the contract can represent duplicate work, protected overlap, expiry, renewal, release, and malformed-record handling.

**Verification gate:** a fixture in `tests/fixtures/work-claims/` can represent one valid active claim, one expired claim, one released claim, one duplicate-task contender, one protected-path contender, and one malformed potentially overlapping claim without ambiguous interpretation.

#### 9.2 Implement read-only discovery and validation first

Create executable `bin/ai-work-claim` following repository Bash conventions and verification-header style. Implement: canonical repository discovery from `git remote get-url origin`; `gh auth status`/repository access preflight; strict policy parsing; paginated issue retrieval by label; strict body/comment parsing; GitHub server-time retrieval; overlap normalization; and commands `list`, `status`, and `doctor`.

`list` prints bounded non-sensitive summaries. `status --task ISSUE --work-unit SLUG --path PATH...` returns: `clear`, `owned`, `blocked`, or `ambiguous`, with exact blocking issue URLs. `doctor` reports malformed, expired, multiply-owned, or policy-unknown records but makes no mutations.

Dependencies: 9.1. Use `gh api`, not scraping `gh issue list` tables. Paginate every collection query. Never trust titles or free text as schema.

**Verification gate:** mocked API tests prove pagination, canonical remote normalization (`u2giants` redirects to `popcre`), server-time use, malformed isolation, and exact/prefix overlap behavior.

#### 9.3 Implement two-phase acquisition

Add `acquire --task ISSUE --work-unit SLUG --purpose TEXT [--path PATH]... [--component NAME]... [--lease-minutes N]`. Preflight requires the task issue to exist and be open, validates every requested path relative to repository root, and identifies all policy-protected prefixes touched. It creates a candidate claim issue, records its server-issued number/timestamps, waits the configured settlement interval, then re-queries all active candidates.

The winner is the lowest issue number among unexpired valid claims with either the same duplicate identity or overlapping protected paths/components. The candidate must re-read its own issue and verify labels/body after settlement. A loser comments with the winning issue URL, closes only its own candidate, deletes only its own local token, and exits nonzero. A winner writes its issue number and owner token to user-only state, prints the exact claim URL and expiry, and exits zero. No repository file changes are allowed before this success.

Dependencies: 9.2. Signal/timeout cleanup may close only a candidate whose owner token matches and that has not been reported as acquired.

**Verification gate:** two concurrent mocked acquisitions for the same work-unit yield exactly one success; two protected-overlap acquisitions yield exactly one success; and unrelated task/path claims both succeed.

#### 9.4 Implement renewal, release, and reconciliation

Add `renew`, `release`, and `doctor --reconcile-expired`. Each mutating command must re-read the claim, validate the owner token, validate task/repository identity, and append a machine-readable comment before changing labels or closing. Renewal uses the comment’s GitHub timestamp as the new lease anchor. Release closes only the owned claim. Reconciliation closes only claims proven expired from GitHub time and records that no ownership assertion was made about local work.

Add `verify-owned` for use immediately before first edit and before commit/push. It must fail if ownership expired, changed, became ambiguous, the task closed, or a lower-number overlapping contender appeared.

Dependencies: 9.3.

**Verification gate:** tests prove wrong-owner release/renew refusal, expired-ignore behavior, explicit reconciliation, interrupted-candidate safety, and `verify-owned` failure after lease expiry or claim tampering.

**Natural context cut:** after 9.4 and its focused tests pass, use `fresh-session`; the next session must re-read Phases 2–3 before proceeding.

### Phase 2 — tests, routing, and installation

#### 9.5 Build the full deterministic test harness

Create `tests/test-ai-work-claim.sh` with a fake `gh` executable and isolated Git fixtures. Do not call live GitHub from the offline suite. Cover the specific cases in §10 plus command usage, output bounds, exit codes, no token leakage, and cleanup ownership. Add fixture files only under `tests/fixtures/work-claims/` if inline setup becomes unreadable.

Dependencies: 9.1–9.4.

**Verification gate:** through explicit Git Bash on Windows, `tests/test-ai-work-claim.sh` passes twice consecutively and leaves the repository unchanged.

#### 9.6 Route ai-devops writers through claims

Update both `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md` with aligned ai-devops-specific rules: read-only work is exempt; before any ai-devops edit, acquire a claim tied to an open task issue; run `verify-owned` before first edit and before commit/push; renew long work; release only after work is committed/pushed or deliberately abandoned; and never bypass a blocker by changing work-unit/path wording.

Update `AGENTS.md` routing with a concise “Concurrent ai-devops write” row linking this plan while open and, after implementation, the operating documentation. Do not paste the full procedure into global files. Update any context-size/trigger evaluation fixtures that assert the global templates.

Dependencies: 9.4 and 9.5. Back up installed globals before adoption as required by repository policy.

**Verification gate:** global-alignment/trigger tests show Claude and Codex receive equivalent instructions, a read-only prompt does not trigger a claim, and a write prompt does. `bin/ai-adopt-globals` preview shows only intended instruction changes before installation.

#### 9.7 Document and install

Create `docs/work-claims.md` as the operating guide: purpose, quick start, command reference, claim schema, protected policy, lifecycle, crash recovery, failure messages, and why this is not an orchestrator. Update `docs/architecture.md`, `docs/configuration.md`, `docs/deployment.md`, `docs/restore-from-zero.md`, and `docs/config-inventory.md` only where the new command changes their inventories or recovery proof. Ensure `bin/ai-work-claim` is executable so `install.sh`’s generic loop owns Linux installation; document Windows invocation through Git Bash.

Add repository labels `work-claim`, `work-claim-active`, and `work-claim-expired` through an idempotent setup subcommand or documented one-time `gh api` operation. Labels are metadata only; never put owner identity solely in a label.

Dependencies: 9.6.

**Verification gate:** install tests prove the executable is included without a special-case installer edit; restore documentation contains an authenticated `ai-work-claim doctor` proof; docs links pass; and no runtime claim/token file appears in Git status.

### Phase 3 — live qualification and landing

#### 9.8 Run focused live race qualification

On `popcre/ai-devops`, create a temporary open qualification issue and run ten pairs of simultaneous claims using distinct temporary work-unit slugs. For same-work pairs, exactly one must win every time. Run one protected-overlap pair and one unrelated pair. Release/close all temporary claims and the qualification issue after recording only issue URLs and outcomes in a scrubbed artifact under `tests/evidence/` or `docs/`.

Do not test by touching repository files. Do not expose owner tokens. If GitHub indexing misses a candidate within five seconds, increase only the policy settlement value to the smallest duration that passes ten consecutive trials, update this plan, and rerun from zero.

Dependencies: 9.7 and authenticated `gh`.

**Verification gate:** the committed qualification artifact identifies ten same-work trials with one winner each, one protected overlap with one winner, and one unrelated pair with two winners; a final `doctor` reports no active qualification claims.

#### 9.9 Full verification and independent review

Freeze the intended tree. Run the focused tests, relevant global/installer/context tests, and `tests/test-all.sh` through `C:\Program Files\Git\bin\bash.exe`. Because this changes global routing and concurrency safety, run one read-only exact-head final review with `ai-reviewer` after all edits and before commit. Fix material findings and rerun affected tests; if the tree changes, repeat the exact-head final review.

Dependencies: 9.8.

**Verification gate:** all suites pass from the frozen tree, the independent report approves the exact reviewed head/tree, and `git diff --check` is clean.

#### 9.10 Commit, push, install, and close

Run `git var GIT_COMMITTER_IDENT` and require `Albert Hazan <u2giants@users.noreply.github.com>`. Recheck concurrent changes, stage only files owned by issue #131, commit directly to `main`, reconcile a concurrent `origin/main` advance without force, push, and confirm the exact commit exists on `origin/main`. Verify the GitHub Actions run for that commit. Install/adopt the changed command and globals using the documented preview-first process, then perform one real acquire/verify/release smoke test.

Update this STATUS table with commit/CI/evidence artifacts, delete this handoff when issue #131 is genuinely complete, close #131 with the proof, and retain this completed plan as a decision record.

Dependencies: 9.9.

**Verification gate:** exact commit on `origin/main`; CI green for that SHA; installed `ai-work-claim doctor` succeeds; one live claim lifecycle succeeds; issue #131 is closed; and no open/stale claim or handoff from this workstream remains.

## 10. Tests required

`tests/test-ai-work-claim.sh` must include named assertions for:

1. canonical repository identity, including redirected owner remotes;
2. missing/closed task issue refusal;
3. invalid work-unit, path escape, absolute path, unknown component, lease bound, and malformed policy refusal;
4. paginated claim discovery;
5. GitHub server time rather than local clock;
6. valid, expired, released, renewed, and malformed schema parsing;
7. duplicate `(repo, task, work-unit)` blocking even when file lists differ;
8. protected exact-path and ancestor/descendant-prefix overlap;
9. unrelated tasks and unprotected paths proceeding concurrently;
10. simultaneous candidate tie-break with exactly one success;
11. delayed/lower-number contender detection during settlement;
12. candidate self-verification after creation;
13. loser closes only itself and names the winner;
14. wrong-owner renew/release refusal;
15. interrupted candidate versus acquired-owner cleanup distinction;
16. expired claim ignored for admission but reported by doctor;
17. explicit expired reconciliation with audit comment;
18. potentially overlapping malformed claim failing closed while unrelated malformed history does not freeze the repo;
19. task closure, tampering, expiry, and ambiguity causing `verify-owned` failure;
20. bounded redacted output with no owner-token leakage;
21. no repository mutation by any claim command;
22. help/usage and stable exit-code contract.

Existing suites required: `tests/test-all.sh`; global-template alignment and context/trigger tests discovered by that suite; installer/deployment tests affected by executable discovery; documentation link checks; `git diff --check`. Run Bash through `C:\Program Files\Git\bin\bash.exe` on Windows, not PowerShell’s ambiguous `bash` resolution.

## 11. Constraints, standing rules, and gotchas in force

- Work directly on `main`; do not create a feature branch for ai-devops.
- Before the first commit, verify the committer identity exactly. Stage only issue #131 files; never use broad staging or destructive reset/checkout.
- Preserve the existing dirty reviewer-cache and taxonomy work. Another session owns it.
- This repository is public. Claim bodies, fixtures, logs, and evidence must contain no secrets, private transcript text, local usernames beyond approved machine/client identifiers, or private filesystem details.
- Use `apply_patch` for edits. Keep the Bash command portable across Git Bash and Ubuntu; do not depend on `flock`.
- GitHub network failures must fail closed for acquisition/verification, with a bounded actionable message. They must not silently degrade to local-only ownership.
- Never close, renew, or release a claim without exact owner-token and repository/task validation. Expired reconciliation is the only non-owner close path and must prove expiry from GitHub time.
- GitHub search/query results must be paginated. A first page is never complete proof.
- The claim tool coordinates intent; it does not authorize destructive Git actions, production changes, shared-db work, or edits outside the user’s task.
- Changes to global behavior must stay aligned between Claude and Codex and be installed through preview/backups with `bin/ai-adopt-globals`.
- This is a concurrency-safety path. Freeze the tree before one exact-head independent final review and rerun review if the reviewed tree changes.
- Do not add scheduled infrastructure, service credentials, or broaden GitHub permissions. Existing authenticated `gh` access is sufficient.
- Do not count an issue URL, PR number, or plan statement as verification. STATUS “done” rows cite rerunnable artifacts, commit SHAs, or CI run IDs.

## 12. Access and environment

- Repository: `C:\repos\ai-devops`; canonical live GitHub repository currently resolves to `popcre/ai-devops`; default branch `main`.
- GitHub CLI is authenticated now and can read/write issue #131. Re-verify with `gh auth status` and `gh repo view --json nameWithOwner,url,defaultBranchRef` before live qualification.
- Windows Bash: `C:\Program Files\Git\bin\bash.exe`.
- Node/Python are not required for the planned runtime. Bash, `git`, `gh`, and `jq` are standard installer dependencies.
- No database, hosted URL, production environment, test login, or new secret is involved.
- Existing GitHub credentials remain in GitHub CLI’s managed authentication store. Never print or relocate them; 1Password is not needed for this work.
- Local claim owner state belongs under the platform’s existing ai-devops state root (Linux `/var/lib` or user-state convention must follow `docs/architecture.md`; Windows under the established user-local ai-devops state directory). The implementing session must select the existing documented state-root helper/convention, not invent a repository-local directory.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Strict versioned policy and claim schema exist.
- [ ] Acquire, verify, renew, release, list/status, doctor, and expired reconciliation work as specified.
- [ ] Offline concurrency/failure tests and the full suite pass twice where nondeterminism matters.
- [ ] Claude/Codex instructions are aligned and installed with preview/backups.
- [ ] Operating, architecture, configuration, deployment, restore, and router documentation is accurate and linked.
- [ ] Ten live same-work races, one protected-overlap race, and one unrelated race meet the expected winner counts.
- [ ] Exact-head independent review approves the frozen final tree.
- [ ] Correct Git identity is proven; only owned files are committed directly to `main` and pushed without force.
- [ ] Exact commit is on `origin/main`; GitHub Actions is green for that SHA.
- [ ] Installed live smoke test passes without leaking tokens or leaving stale claims.
- [ ] Plan STATUS cites artifacts; issue #131 is closed; this workstream’s handoff is deleted; no claim remains active.

### Risks and mitigations

- **GitHub indexing delay produces two temporary candidates.** Neither may edit during settlement; lowest issue number wins after re-query. Live qualification calibrates the minimum safe window.
- **Session crashes after acquiring.** Lease expires; others can proceed after expiry, while doctor preserves and later closes audit history.
- **Session keeps editing after expiry.** Global rules require renewal and `verify-owned` before commit/push. Git cannot prevent all human bypasses; diagnostics make it visible.
- **Claims become administrative clutter.** Claims close on release and are searchable by labels; no mutable index is added. Expired reconciliation is explicit and bounded.
- **Overbroad policy serializes unrelated work.** Start only with measured hot surfaces and exact prefix overlap; review policy changes like code.
- **Underbroad policy misses architectural duplication.** Task/work-unit identity still blocks duplicate work even when paths differ. Shared-code refactoring remains separate.
- **Malicious or accidental body edits.** Strict re-read/self-verification fails closed for the affected scope and points to the exact issue.
- **GitHub unavailable.** New write work waits; read-only diagnosis can continue. No local bypass is allowed.

### Open questions with decision criteria

1. **Is five seconds enough for GitHub issue discovery?** Decide from ten consecutive live simultaneous trials. Raise only to the smallest passing value; if no bounded value is reliable, stop and revisit the authority design on issue #131.
2. **Which existing user-state root should store owner tokens on both platforms?** Follow the established helper/convention found during implementation. It must be user-only, outside Git, recoverable, and tested; do not create a new global configuration class.
3. **Should ordinary `doctor` close expired claims?** No by default. It remains read-only; only `doctor --reconcile-expired` mutates. Change only if a later measured operational problem justifies automation.

### Rollback

Revert the exact implementation commit on `main`, rerun installation to remove/restore the command through manifest-owned behavior, and adopt the previous global templates from their backups. Close any active claim issues created by the feature with a rollback explanation. Do not delete audit history. Because there is no hosted service or database, rollback is repository + installed-tool restoration only.

## Mandatory self-audit — final answers

1. **Could a brand-new AI session execute this without asking Albert anything? Yes.** Sections 1–4 establish purpose/scope; Sections 5–8 carry current evidence, rejected approaches, and locked/open decisions; Section 9 names files, order, dependencies, and a verification gate for every step; Sections 10–13 define tests, environment, landing, rollback, and decision criteria.
2. **Does the plan carry the relevant background, nuance, and rejected alternatives? Yes.** Sections 3, 6, and 7 distinguish merge conflicts from duplicate work, explain the check/create race, and record why an orchestrator, committed file, local lock, shared issue, refs, and scheduled closer were rejected.
3. **Is the goal clear enough for a correct judgment call if a step is wrong? Yes.** Section 1 states the business outcome and precedence rule; Section 8 identifies locked boundaries and the one condition requiring a stop; Section 13 gives open-question criteria rather than leaving redesign choices implicit.

**Checklist result:** all 13 required sections are present; goal-first wording, explicit exclusions, concrete file targets and gates, named tests, locked/open decisions, access, secrets boundary, commit/push/CI/install proof, reciprocal handoff links, risks, rollback, and final self-audit are all included. PASS.
