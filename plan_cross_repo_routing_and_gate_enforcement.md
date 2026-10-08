# Cross-repository routing and task-gate enforcement plan

**Owner issue:** [popcre/ai-devops#335](https://github.com/popcre/ai-devops/issues/335)

**Parent outcome:** [popcre/ai-devops#159](https://github.com/popcre/ai-devops/issues/159)

**Active handoff:** `HANDOFF.d/2026-09-11T0001Z-edge-dev-codex-issue-335-phase5-boundary.md` (retired; see git history)

Phase 4 is closed; the active handoff preserves the Phase 5 boundary only. PR
#330 is an unrelated Qwen workstream; do not cancel, rerun, or diagnose it as
part of Issue #335.

**Decision date:** 2026-09-08

## STATUS

| Phase | Deliverable | Status | Fresh-session restart point |
|---|---|---|---|
| 0 | Freeze the canonical repository inventory and capture routing/gate baselines | DONE 2026-09-08 | `config/repository-coverage.json` (17 identities) and `tests/verification/task-gates/routing-baseline.{json,md}` are committed |
| 1 | Define the shared routing and gate-policy contracts | DONE 2026-09-08 | `config/task-gates.json`, `config/task-gates.schema.json`, `tools/ci/validate-task-gates.py`, lean-router content model in `docs/context-spec.md` |
| 2 | Implement and qualify the central `ai-devops` engine | DONE 2026-09-08 | `bin/ai-task-gates` plus enforcement in `bin/ai-review`, `bin/ai-pr-wait`, `bin/ai-review-lifecycle`; evidence under `tests/verification/task-gates/` |
| 3 | Pilot in `ai-devops`, `shared-db`, one DesignFlow service, and Oracle | DONE 2026-09-09 | `ai-devops` #352 (`4d83f9a5`), `shared-db` #2637 (`fe5fa74d`), Oracle #9 (`28e8eb75`), and DesignFlow `sandbox-albert` (`ea8f6029`, build `27721624-9702-4435-afea-fb41c6f6849b`) are landed and verified |
| 4 | Roll out thin policies and lean routers to all remaining repositories | DONE 2026-09-10 — 17/17 landed | All releases have direct proof and `tests/test-repository-coverage.sh` passes with 17 canonical rows; do not begin Phase 5 without a separate instruction |
| 5 | Install, exercise, measure, and close the cross-repository rollout | IN PROGRESS 2026-09-11 | Central repair #389 and Windows landed-source installation are complete; Ubuntu permission and private-memory health gates remain |
| 2026-10-08 bounded repair | Exact DesignFlow source-release gate | IN PROGRESS 2026-10-08; parent Codex owns #1490 | At 1:01 PM EDT, corrected frozen-base fixture proves changed reviewer-safety router and generic refusal; focused four assertions PASS. Earlier encoding-gap hypothesis is superseded: actual contributor storage contains tabs, and moving HEAD hid fixture changes. Current main reconciled; isolated full verification and exact independent review remain required. Installation and live shipment are separately unaccepted. |

Natural context cuts are after Phases 0, 2, 3, and 4. At each cut, use a fresh
session, read this STATUS table and the newest matching OPEN handoff, and resume
the first OPEN row without repeating completed work.

## 1. Ultimate goal in plain English

Every repository should tell an AI session only what it needs to start the
current task, and the tooling should prevent that task from accidentally
triggering a more expensive or riskier workflow. A documentation cleanup should
not become a code/configuration change, paid review, long CI wait, deployment,
database operation, or production action unless the work genuinely requires it
and the change is deliberately reclassified.

The result must preserve useful instructions. Root routing files become short
maps; stable project facts remain close to the repository; full procedures have
one maintained home in a topic document or shared skill; and stronger local
safety rules always override central defaults.

**If a step conflicts with this goal, the goal wins—stop and flag it.**

## 2. Application and repositories

`popcre/ai-devops` owns the shared schema, classifier, command, tests, installer,
templates, and cross-repository coverage evidence. Rollout targets are canonical
GitHub repositories, not every local clone or worktree.

| Group | Canonical repositories | Required local distinction |
|---|---|---|
| Shared tooling | `popcre/ai-devops` | Public toolkit; reviewer-safety paths retain exact-head independent review; documentation-only changes retain the immediate merge path |
| DesignFlow | `popcre/designflow-backend`, `designflow-bff`, `designflow-data-syncing`, `designflow-frontend`, `designflow-item-master`, `designflow-tracking` | Normal product delivery remains sandbox branch and PR to `develop`; for the #335 rollout Albert selected direct, live `sandbox-albert` acceptance without a `develop`/Uma wait. Frontend/UI work retains visual and authenticated workflow proof; shared schema changes route to `popcre/shared-db` |
| Shared database | `popcre/shared-db` | Structural changes keep orchestrator, claim, reviewer, preview, target-identity, and production-promotion gates |
| Oracle | `u2giants/theoracle` | Release, migration, licensed-fixture, and live production gates remain explicit; no production mutation without current authorization |
| Licensed/private evidence | `u2giants/licensor-source-data`, `u2giants/ai-devops-transcripts` | Licensed rows and raw transcripts remain private; the routing audit must not open raw transcript archives |
| Applications | `u2giants/popcrm-web`, `poppim-web`, `popdam3`, `backrest-wiz` | Each repo keeps its own tests, UI proof, deployment, and database ownership boundaries |
| Infrastructure | `popcre/infrastructure`, `u2giants/ansible` | Production infrastructure remains read-only by default; exact resource/action authorization is still required before apply |

The current inventory contains 17 unique remotes. Phase 0 must refresh it from
the saved-project list and Git remotes, record aliases such as `popdam3` versus
the saved `popdam` project, and fail if any current canonical repository is
unclassified. Additional worktrees consume the same policy by repository
identity and are not separate rollout rows.

## 3. Trigger and owner problem

On 2026-09-08 a simple `AGENTS.md` trim grew into an unrequested code/config
budget change. That changed the task class and caused full Windows CI and
reviewer work to dominate a documentation job. The eventual documentation-only
repair reduced the startup route from about 21.6 KB to 7.4 KB and merged quickly,
showing that the delay was selection failure, not an unavoidable repository
requirement.

This has recurred: instructions correctly describe many safety gates, but prose
does not reliably stop a session from selecting a stronger gate than its actual
diff requires. The repositories also duplicate procedures in always-loaded
routers, increasing context cost and making conflicting copies more likely.

## 4. Scope

### In scope

- Inventory `AGENTS.md`, `CLAUDE.md`, root handoff pointers, repository policy
  files, task routers, and other always-loaded instruction surfaces in all 17
  canonical repositories.
- Classify every instruction as universal behavior, repository fact, task route,
  procedure, machine fact, live operational fact, historical evidence, or
  duplicate/stale text.
- Keep lean repository routers and move full procedures to an existing owned
  document or shared skill; create a new destination only when no shared home
  exists and record its retirement/consolidation path.
- Define a versioned central policy schema with per-repository declarations for
  change classes and required gates.
- Add a local preflight that records task intent and compares it with the full
  current change set before review, CI waiting, shipping, deployment, database,
  or production actions.
- Integrate the decision once at common shared entry points rather than copying
  logic into every provider wrapper.
- Test deletion, rename, staged, unstaged, untracked, submodule, and mixed-change
  cases; fail closed when policy or repository identity cannot be resolved.
- Roll out, install, and verify the shared behavior on every canonical repo.

### Out of scope

- Weakening, deleting, or bypassing any existing safety gate.
- Changing application behavior, schemas, data, infrastructure, deployment, or
  production state as part of this program.
- Redesigning each repository's CI pipeline. The policy may select existing
  gates; separate owner issues remain responsible for changing those gates.
- Making `AGENTS.md` byte size a blocking rule. Size is a diagnostic; unique and
  safety-critical instructions win over a target.
- Treating a timer as the fix. A five-minute alert after the wrong work starts is
  too late; the preflight must prevent the wrong work from starting.
- Reading raw transcript `.jsonl` files or moving private evidence into public
  repositories.

## 5. Current code and documentation state

- `tools/ci/classify-changes.sh:8-37` already classifies PR paths and permits a
  prose-only fast path, but only at CI time and with coarse repository-local
  categories.
- `.github/workflows/fast-classifier.yml:25-52` obtains both sides of renames by
  disabling rename detection and feeds changed paths to that classifier.
- `tests/lib-selection.sh:58-68` reuses the same classifier for local
  `--changed-since` selection, proving that one classifier can serve multiple
  entry points.
- `docs/development.md:124-155` documents focused local suites and explicitly
  says narrowed selection is not the final shipping gate.
- `bin/ai-review-lifecycle:12-15,282-289` is the common lifecycle for Codex,
  Claude, and Grok formal reviews, but its `begin` contract has no task-class or
  repository gate-policy decision.
- `bin/ai-pr-wait:2-18,137-196` correctly bounds pull-request waiting and detects
  failures/ejections, but it does not decide whether waiting is appropriate for
  a documentation-only change.
- `config/repository-policy.json:1-34` currently resolves branch workflow and
  main branch by repository identity; it does not declare routing ownership,
  change classes, or required gates.
- `plan_repo-throughput-restructure.md:217-230,334-346` owns fast CI and targeted
  local selection, while its final required-check cutover remains open. This
  plan extends those completed primitives and must finish before #166 changes
  required contexts.
- `docs/implementation-plan-index.md:12-24,67-72` is the active plan registry and
  requires an open issue, STATUS, router/handoff path, and retirement path.
- `docs/task-router.md:34-37` routes throughput and wait work but has no route for
  task classification, scope drift, or cross-repository router hygiene.
- The 2026-09-08 live inventory found 17 canonical remotes: 14 currently expose
  a root `AGENTS.md`; `popcre/infrastructure`, `u2giants/licensor-source-data`,
  and `u2giants/ai-devops-transcripts` need their actual routing surfaces
  classified before deciding whether a compact root router is required.

Phase 0 must replace these planning observations with committed machine-readable
evidence containing repository identity, default branch, privacy class, routing
files and sizes, policy version, special gates, and last verified date.

## 6. Findings and root cause

1. **The existing classifier sees the diff too late.** It saves CI time after a
   PR exists, but it cannot stop a session from adding code to a prose task.
2. **Intent and observed work are not compared.** Nothing durable records
   “documentation-only” at task start and checks that claim before an expensive
   step.
3. **Gate descriptions and gate selection are mixed.** Repositories need rich
   safeguards, but copying procedures into root routers increases prompt cost
   without enforcing the decision.
4. **Selection is fragmented.** Local tests and CI share coarse classification,
   while reviewer and PR-wait entry points do not consult it.
5. **One universal policy would be unsafe.** A Markdown migration ledger, release
   marker, or operational handoff can carry more risk than ordinary prose. Local
   declarations must be able to strengthen, never silently weaken, defaults.
6. **“Every repo” is an identity problem.** Repeated clones and worktrees make a
   folder census misleading. Coverage must key on canonical remote identity and
   explicitly account for private and saved-project aliases.

## 7. Rejected approaches

| Approach | Why rejected |
|---|---|
| Add another large global instruction saying “do not over-test docs” | Repeats the failure mode: more prose and no enforcement |
| Put a separate script and rule set in every repository | Creates 17 drifting implementations and makes future repair expensive |
| Enforce a hard `AGENTS.md` byte ceiling | Encourages deletion or awkward compression of unique safety rules; size is not correctness |
| Classify only the committed PR diff | Misses scope drift before commit and misses untracked/staged/unstaged work |
| Trust file extensions alone | Operational Markdown, migration ledgers, policies, and generated artifacts can require stronger gates |
| Automatically downgrade a gate to save time | Central defaults cannot override a stronger repository rule or explicit owner request |
| Require Albert to approve every reclassification | Recreates approval loops for ordinary scoped work; only material business-scope decisions need him |
| Stop after `ai-devops` implementation | Leaves other repositories dependent on copied prose and does not satisfy repository-wide coverage |
| Use elapsed-time alarms as the primary control | Reports waste after it occurs instead of preventing it |

## 8. Decisions

### Locked on 2026-09-08

- `ai-devops` is the single implementation owner; consumer repositories contain
  only a versioned declarative policy and lean routing links.
- Policy resolution starts from safe central defaults, then applies a matching
  repository rule; a local rule may strengthen a gate but may not weaken a
  centrally mandatory safety class without an explicit, tested exception.
- Intent is recorded in an ignored machine-local state file keyed by canonical
  repository identity and worktree, never committed as project state.
- The observed change set includes committed branch changes plus staged,
  unstaged, untracked, deleted, renamed, and submodule changes.
- A mismatch stops before the expensive action and prints the exact files and
  class escalation. Routine in-scope escalation can be acknowledged with a
  reason; missing authority or a materially different outcome stops as `Blocked —` for an
  assigned AI reviewer (never an approval request to Albert).
- Explicit owner requests for a reviewer or full check remain valid, but the
  override and reason are recorded rather than inferred.
- Database, production, infrastructure, privacy, reviewer-safety, visual UI,
  and DesignFlow merge rules are non-downgradable.
- The rollout treats canonical remotes as targets. Clones, host checkouts, and
  worktrees inherit by repository identity.

### Open for Phase 1 evidence, not owner choice

- Whether to extend `config/repository-policy.json` or introduce a focused
  `config/task-gates.json`. Choose the format that gives one schema owner,
  backwards compatibility, and the smallest consumer declaration.
- Whether intent state belongs under Git common-dir metadata or the existing
  ai-devops user state root. Prove isolation across linked worktrees and cleanup.
- Which common shipping entry point can enforce the check without pretending
  every repository uses identical merge commands.
- Which operational Markdown paths require non-prose classes in each repository.

## 9. Ordered implementation steps

### Phase 0 — freeze inventory and baseline

#### Step 0.1 — canonical repository coverage manifest

**Files:** add `config/repository-coverage.json`; add schema validation under the
existing configuration-test home; add evidence under
`tests/verification/task-gates/`.

Resolve saved Codex projects and unique Git remotes. For every repository record
owner/name, local representative, default branch, privacy class, routing files,
workflow family, existing policy source, special gates, and whether raw content
may be inspected. Account for all 17 current remotes and fail on duplicates or
unclassified additions.

**Gate:** a generated/read-only audit reports exactly one coverage row per
canonical remote, no transcript contents are opened, and a fixture proves clones
and worktrees collapse to the same identity.

#### Step 0.2 — routing census and no-loss ledger

**Files:** add `tools/context-audit/audit-repository-routing.py` or extend the
existing audit only if ownership and output remain coherent; add
`tests/verification/task-gates/routing-baseline.json` and a human summary.

For each routing surface, measure bytes/lines and classify every section by
owner/destination. Record duplicates, stale live facts, embedded procedures,
missing routes, and safety statements that must survive. Establish before
figures for startup context and task-trigger precision.

**Gate:** every section in every discovered routing file is assigned once to
keep, move, consolidate, or remove-with-proof; missing files are intentional
and documented, not silently treated as clean.

**Fresh-session cut:** commit Phase 0 evidence and update STATUS before design.

### Phase 1 — define contracts

#### Step 1.1 — versioned gate policy schema

**Files:** chosen policy JSON, its JSON Schema, repository coverage manifest,
`docs/context-spec.md`, `docs/development.md`.

Define change classes at minimum for ordinary prose, code/configuration,
reviewer-safety, UI/live workflow, shared-database structure/data, deployment,
infrastructure, production, and private/licensed evidence. Declare required and
forbidden actions, precedence, path rules, explicit overrides, and fail-closed
behavior. Separate “what changed” from “which gates apply.”

**Gate:** table-driven fixtures cover every class, mixed changes choose the
strongest applicable class, and local rules cannot downgrade protected classes.

#### Step 1.2 — lean-router contract

**Files:** `docs/context-spec.md`, shared global templates, affected skill/router
templates; no consumer repo edits yet.

Define the root-router content model: repository purpose, invariant safety and
ownership boundaries, high-frequency task routes, and links to specialized
routes. Procedures, machine facts, volatile live facts, and history must live in
their owned homes. Define warning budgets and trigger tests without making size
alone a failure.

**Gate:** fixture routers prove that all no-loss-ledger safeguards remain
reachable from the right task trigger and that unrelated procedures are not
loaded for a documentation-only task.

### Phase 2 — central implementation

#### Step 2.1 — shared classifier library and command

**Files/functions:** refactor `tools/ci/classify-changes.sh` behind one stable
library/command (provisional name `bin/ai-task-gates`); preserve existing output
for `fast-classifier.yml` and `tests/lib-selection.sh`; add `start`, `check`, and
machine-readable `explain` operations.

`start` resolves repository identity, base SHA, worktree, requested class, and
reason. `check --before <action>` recomputes the complete working change set,
resolves policy, and returns allow, stronger-gate-required, explicit-override,
or cannot-classify. Output must be concise and actionable.

**Dependencies:** Phase 1 schema.

**Gate:** Bash and PowerShell-compatible tests cover spaces, no remote, linked
worktrees, new repos, detached HEAD, deletes, both sides of renames, untracked
files, submodules, mixed changes, corrupt state, stale base, and concurrent
tasks. Existing classifier and selection contracts remain green.

#### Step 2.2 — common enforcement points

**Files/functions:** `bin/ai-review-lifecycle begin`; `bin/ai-pr-wait` preflight;
the shared shipping/install entry point identified in Phase 1; relevant tests.

Enforce before formal reviewer launch, long PR wait, ship/merge orchestration,
deployment, database, infrastructure, and production helpers where a common
entry point exists. Do not duplicate policy interpretation in provider wrappers.
For a prose-only PR, `ai-pr-wait` should explain that the configured immediate
path applies unless the owner explicitly requested waiting.

**Gate:** injected tests prove the protected action never starts on mismatch,
owner-requested full gates still run, and existing reviewer lifecycle,
uncertainty, cancellation, and wait semantics are unchanged.

#### Step 2.3 — installation and client behavior

**Files:** lifecycle installer/manifests, both global behavior templates,
`bin/ai-adopt-globals`, shared skill/router documentation, restore docs.

Install the command on supported Windows and Linux machines and add one concise
global rule: declare task class, consult repository policy, and recheck before a
stronger gate. Keep procedure text in the shared skill/docs.

**Gate:** clean install and upgrade preserve machine-local configuration;
installed Claude and Codex routing parity passes; restore-from-zero makes the
command and policy available without manual copying.

#### Step 2.4 — central exact-head verification

Run focused unit/fixture suites, complete Bash and PowerShell offline suites, and
one independent exact-head final review because reviewer lifecycle and installed
routing are safety paths.

**Gate:** all protected assertion counts and injected-defect tests pass; no
provider review begins in the documentation-only refusal fixture; evidence is
committed under `tests/verification/task-gates/`.

**Fresh-session cut:** land the central implementation before consumer edits.

### Phase 3 — diverse pilots

#### Step 3.1 — pilot policy declarations and router migrations

Pilot one repository from each materially different risk family:

1. `popcre/ai-devops`: prose fast path plus reviewer-safety exact-head review.
2. `popcre/shared-db`: structure/data/orchestrator and target-proof rules.
3. `popcre/designflow-frontend`: DesignFlow branch ownership, no self-merge,
   shared-db boundary, UI visual/authenticated proof.
4. `u2giants/theoracle`: release, migration, licensed fixture, and production
   authorization gates.

**Files:** each repo's thin policy; root router and specialized task-router/topic
docs as identified by its ledger; repository-local policy fixtures where needed.

**Gate per repo:** before/after routing measurement; zero unassigned ledger
items; task-trigger evaluation for docs, normal code, and its highest-risk class;
local tests; PR workflow compliance; live `ai-task-gates explain` resolves the
correct identity and gates from both canonical checkout and a linked worktree.

Do not combine these four repos into one branch or PR. `shared-db` work here is
repository maintenance and authorizes no schema/data action. The DesignFlow
pilot was initially opened for Uma as #179; Albert redirected acceptance to the
live `sandbox-albert` branch on 2026-09-09, so #179 closed unmerged and the
verified pilot landed directly at `ea8f6029`.

#### Step 3.2 — pilot review and rollback rehearsal

Have an independent reviewer compare each trimmed router to its no-loss ledger,
then deliberately inject one scope escalation fixture in each family. Rehearse
rollback by restoring the previous router and policy without changing code or
production state.

**Gate:** all four mismatches stop before the protected action; all four valid
flows proceed; no unique instruction becomes unreachable.

**Fresh-session cut:** update policy/schema only through a new central version if
the pilots expose a common gap; never patch consumers inconsistently.

### Phase 4 — full repository rollout

**Completion update, 2026-09-10:** Phase 4 is complete. POP CRM #8 landed as
`acc367ff` and its production job proved the merged commit serving. PopDAM #122
landed as `562dc999` and deployment `6379307635` reported production success.
POP PIM #6 landed as `8ff0c71c`; its GET restart failed with HTTP 405, so the
small repair in #7 landed as `53e43c0a` and release `34521735944` verified
production successfully. Backrest Wiz #7 landed as `daf86a69`; its first deploy
failed because the production host could not pull from GHCR. Albert authorized
the protected credential replacement; rerun `34519554165` then succeeded. The
central coverage check reports 17 rows and 17 canonical remotes, with the two
private repositories intentionally metadata-only. Do not begin Phase 5 without
a separate instruction.

**Prior release update, 2026-09-10:** 13 of 17 repository policies were landed.
`u2giants/ansible#14` merged as `5e66e72c` after an exact authorization (recorded 2026-09, before the 2026-09-28 ruling) for its serialized Phase 1 apply to the `hetzner` production
target. Its production run `34502571521` completed successfully (`ok=59`,
`changed=1`, `unreachable=0`, `failed=0`). The four remaining green candidates
are deliberately unmerged: `u2giants/popcrm-web#8`, `u2giants/poppim-web#6`,
`u2giants/popdam3#122`, and `u2giants/backrest-wiz#7`. Each merge starts
existing production automation and requires an assigned AI reviewer's APPROVE
of that exact merge (never Albert's approval — owner ruling 2026-09-28).
Issue #335 was reopened after its premature closure. Backrest Wiz retains an
unresolved qualified exact-head review proof after bounded provider failures.
Do not update the 17-row coverage gate or start Phase 5 until all four land and
their live results are verified.

#### Step 4.1 — DesignFlow remainder

Roll out to backend, BFF, data-syncing, item-master, and tracking. Preserve the
same workflow family while declaring service-specific database, deployment, and
test gates. For this #335 rollout, land and verify each repository on its current
`sandbox-albert` branch as Albert directed on 2026-09-09; do not wait on
`develop` or Uma. This does not change the normal product-delivery rule outside
this rollout.

#### Step 4.2 — application and private-data repositories

Roll out to `popcrm-web`, `poppim-web`, `popdam3`, `backrest-wiz`,
`licensor-source-data`, and `ai-devops-transcripts`. For repositories without a
root router, add one only if Phase 0 proves a discoverability gap; otherwise the
thin policy and existing routing surface are sufficient. Never open transcript
archives or licensed source rows to perform the routing audit.

#### Step 4.3 — infrastructure repositories

Roll out to `popcre/infrastructure` and `u2giants/ansible`. Production mutation
classes must remain denied without an assigned AI reviewer's APPROVE of the exact
resource/action (never Albert's approval — owner ruling 2026-09-28).

**Gate for Steps 4.1-4.3:** every coverage-manifest row records policy version,
landed commit/PR, routing before/after, trigger-eval result, local verification,
and remaining exception. Mixed or missing coverage fails the phase. Re-run the
diverse pilot suite after any schema version change.

At the end of Phase 4, re-read every Phase 5 step through plan completion and
record any assumption, identifier, delivery path, or acceptance gate that Phase
4 changed or invalidated before writing the Phase 5 handoff.

**Fresh-session cut:** all 17 repositories must show landed coverage before
cross-machine installation or closure begins.

### Phase 5 — install, measure, and retire

#### Step 5.1 — supported-machine installation

Install through the normal `ai-devops` lifecycle on supported Windows and Linux
hosts. Verify repository identity and task-gate explanations in representative
canonical and linked worktree paths; do not hand-copy binaries or policies.

#### Step 5.2 — end-to-end acceptance battery

Run controlled scenarios for: documentation-only cleanup; docs-to-code drift;
ordinary code; reviewer-safety code; DesignFlow UI; shared-db structure;
licensed/private evidence; infrastructure; and Oracle production. Use dry-run or
fixtures for every protected external action.

**Gate:** wrong-class actions are prevented before launch, valid actions retain
their complete existing gates, explicit owner-request overrides are audited,
and no scenario needs duplicated procedure text in its root router.

#### Step 5.3 — measure the outcome

Compare startup bytes/tokens, task-trigger precision, unnecessary reviewer
starts, long-wait starts, time-to-first-useful-result, and landed-within-session
rate to Phase 0. The key acceptance measure is zero expensive gate launches in
the controlled documentation scenarios, not merely a smaller router.

#### Step 5.4 — close and retire

Update all coverage evidence, move this plan to Completed decision records,
close #335 with commit/PR/test evidence, update #159 and its STATUS with the
result, and only then allow #166's final required-check cutover. Delete this
plan's OPEN handoff in the completion commit. Retain the plan as the decision
record unless a future consolidated successor explicitly preserves every unique
decision.

## 10. Tests and acceptance evidence

| Test family | Required proof |
|---|---|
| Policy schema | Valid defaults/overrides; unknown fields and downgrade attempts fail closed |
| Git change discovery | Committed, staged, unstaged, untracked, delete, rename, submodule, detached, and linked-worktree fixtures |
| Intent lifecycle | Start, unchanged check, justified escalation, stale/corrupt state, concurrent worktrees, cleanup |
| Existing classifier compatibility | Current `fast-classifier` outputs and local suite selection remain byte/behavior compatible where promised |
| Reviewer enforcement | All formal reviewer entry points share one decision; mismatch starts no provider process and spends no call |
| PR wait/shipping | Docs-only immediate route, explicit requested wait, failure/ejection/deadline behavior unchanged |
| Router no-loss | Every baseline instruction is kept, moved with a valid trigger/link, consolidated with proof, or removed with evidence |
| Trigger quality | A docs task avoids deep procedures; DB/production/private/UI tasks load their exact stronger instructions |
| Cross-repo coverage | All canonical remotes classified once; clones/worktrees resolve identically; no private raw content read |
| Installation/restore | Windows and Linux install/upgrade/restore use the same policy version and preserve local settings |
| End to end | Nine Phase 5 scenarios prove prevention before action plus preservation of legitimate gates |

Green tests alone do not finish the program. Each repository needs a landed
commit/PR and current coverage row; each installed environment needs live
command proof; protected external actions use fixtures or read-only dry runs.

## 11. Constraints and non-negotiable safeguards

- Use isolated current-upstream worktrees and stage only task-owned files.
- Resolve live remote, default branch, branch policy, issue/PR state, and exact
  head before every repository write or merge decision.
- Do not merge DesignFlow PRs; all other authorized PRs are merged by the
  implementing session unless a current blocker exists.
- No database, application-data, infrastructure, deployment, or production
  mutation is authorized by this plan.
- Do not open raw transcript archives; keep licensed/private evidence private.
- Preserve reviewer read-only boundaries, exact-head requirements, uncertainty
  records, cancellation semantics, and provider-specific restrictions.
- Preserve UI visual/authenticated proof where a local repository requires it.
- Never reduce capability to satisfy context or timing measurements.
- Avoid long polling. Use bounded event-aware wait tooling only after the new
  preflight says waiting is an applicable gate.
- Coordinate protected Windows CI/reviewer lanes before local full suites.

## 12. Access and environment

- Git/GitHub read and write access to all 17 repositories; DesignFlow merge
  authority remains outside the implementing session.
- Current `popcre/ai-devops` installation and restore paths on Windows and Linux.
- Read-only Codex saved-project inventory plus Git remote metadata for coverage.
- No production credentials are needed for implementation or acceptance; all
  production/database/infrastructure cases use policy fixtures and read-only
  identity checks.
- 1Password access, if an existing installer test genuinely needs it, must use
  the serialized protected procedure and may not expose values.
- Before the first commit in every repo, verify
  `Albert Hazan <u2giants@users.noreply.github.com>`.

## 13. Done definition, risks, open questions, and rollback

### Done means all of the following

- All 17 current canonical repositories have a current coverage row, landed
  compatible policy, and verified routing surface.
- Every router-ledger item is accounted for; no safety rule was lost and no full
  procedure remains duplicated without a documented necessity.
- The central preflight blocks scope drift before reviewer, long wait, shipping,
  deployment, database, infrastructure, or production entry points.
- Valid stronger workflows still operate with their existing proof requirements.
- Supported installations and restore-from-zero deliver the same policy version.
- Phase 5 measurements and evidence are committed; #335 is closed; #159 is
  updated; #166 is no longer blocked by this dependency; the OPEN handoff is
  removed.

### Risks and controls

| Risk | Control | Rollback |
|---|---|---|
| False prose classification bypasses a real gate | Strongest-match resolution, protected path fixtures, fail closed | Revert policy version and restore prior required gate; keep incident fixture |
| Router trim loses a unique instruction | Section-level no-loss ledger and independent review | Restore prior router from Git, then remap before retrying |
| Central command blocks legitimate work | Concise explain output, audited owner-request override, diverse pilots | Pin previous policy/command version through installer |
| Consumer policies drift | Schema version and coverage audit; implementation remains central | Reject mismatched policy and use safe central defaults |
| Private repository leaks into public evidence | Metadata-only inventory and explicit privacy classification | Remove published artifact, report exposure, and follow incident process |
| DesignFlow or production authority is exceeded | Policy denial plus existing branch/authorization rules | Stop before action; no mutation means no operational rollback needed |
| Concurrent worktree state collides | State keyed by canonical identity plus worktree and task; concurrency tests | Remove only the exact stale task state after read-only inspection |

### Remaining questions

No owner decision blocks Phase 0. The schema file location, state directory, and
shipping integration point are engineering questions to settle with evidence in
Phase 1. If any repo's current routing files conflict about authority or if a
local gate appears to require weakening, stop that repository and report it `Blocked —` for an assigned AI reviewer
(never an approval request to Albert); continue safe work on the other inventory rows.

## Plan self-audit — 2026-09-08

1. **Could a fresh session execute this without the chat?** Yes. The STATUS
   table gives the restart point; the repository inventory, owner issue, files,
   dependencies, phase cuts, and per-step gates are explicit.
2. **Does every requested outcome have a delivery step and acceptance proof?**
   Yes. Lean routing is owned by Phases 0, 1, 3, and 4 with a no-loss ledger;
   durable gate enforcement is owned by Phases 1, 2, and 5; all-repository
   coverage is a blocking 17-row manifest gate.
3. **Does the plan preserve existing capabilities and name what it will not do?**
   Yes. Sections 4, 7, 8, and 11 reject size-only deletion, copied enforcement,
   timer-based fixes, gate downgrades, private-data inspection, and unauthorized
   external mutations; pilots deliberately cover the strongest risk families.

## 2026-10-08 bounded application-source release repair (#1490)

### 1. Ultimate goal

Allow Albert's independently approved DesignFlow sandbox source to reach its normal automatic release without weakening review or installing tool code through an application loophole. If a step conflicts with this goal, the goal wins: stop and flag it. Parent Codex owns the decision and installed/live acceptance on existing tools issue #1490; DesignFlow's complete outcome stays on backend #94. This additive repair does not reopen historical #335 work. No new competing plan or handoff is created; these existing issue cards remain the continuation records.

### 2. Application

`popcre/ai-devops` owns `bin/ai-task-gates`, central policy/schema and hermetic tests. Its protected `main` uses reviewed feature PRs and the merge queue; installation is a distinct exact-reviewed operation. Consumer `popcre/designflow-backend` releases `sandbox-albert` through regional Cloud Build to project `lithe-breaker-323913`, region `us-east4`, service `popcre-albert-core-sandbox`; Uma owns its `develop` merge. No other consumer or environment is admitted by this repair.

### 3. Trigger

At 6:48 AM EDT October 8, application head `9e03f180def4680b060056ca97946ccd330fae5b` received independent final APPROVE (182 suites/1957 tests PASS). Its `ship` check passed, while `deploy` refused verbatim: `Reviewer-safety changes cannot use the generic deploy action; use a separate reviewed installation task.` No application push or cloud mutation followed. The app's strengthened local policy classifies its plan/router as reviewer-safety; installation is a machine-tool route and cannot deploy this application. Frontier read-only audit found no documented supported exception.

### 4. Scope

Edit only `bin/ai-task-gates`, `config/task-gates.json`, `config/task-gates.schema.json`, existing `tests/test-ai-task-gates.sh`, relevant `docs/context-spec.md` and `docs/deployment.md`, this plan's additive repair/STATUS and its existing `docs/implementation-plan-index.md` row. Reuse `reviewer_approval_summary`, `state_record_override`, existing fixture/lifecycle proof helpers and JSON/schema validator. Do not add an alternate gate binary, weaken classes, narrow away contributors, change toolkit installation receipts, private policies, production/infrastructure/database actions, provider holds/budgets, memory, credentials or Cloud Build inputs. The later application consumer manifest is parent-owned, separately reviewed source work.

### 5. Current source

Owned repair worktree starts at merged main `7f7900082b29a5afeaa2b2cdd4ecc0c9b4af221a`; no implementation yet. `bin/ai-task-gates:1057-1065` sets reviewer_release from every contributor then refuses generic deploy unconditionally. `tests/test-ai-task-gates.sh:228-231` explicitly preserves refusal even with approval for toolkit reviewer-safety. That assertion MUST continue passing. App source remains frozen and unshipped. Prior tool installation failed required private-memory health (12404-byte outgoing index exceeds12288), user-bus setup environment and doctor classification/readability; PR1500's latter source repairs merged, but full installation is not accepted. No repeat of the known private-memory failure or unauthorized memory modification.

### 6. Root cause

A machine-installation prohibition is applied to an application source release solely because a stronger local router/plan gate contributes reviewer-safety. Merely using the ship check would knowingly cause the refused deployment and is not recovery. The fix needs explicit central admission plus a committed reviewed destination; generic deploy remains refused.

### 7. Rejected approaches

No class downgrade, changed comparison base to omit protected files, removed plan/router, copied/uninstalled candidate gate, generic ship-only push, manual gcloud deployment, toolkit installation masquerading as application release, weakened exact review, forged report, private-memory compression/edits, skipped installer stage or provider fallback. No broad all-application exception. No legacy raw hash acceptance/rehash/backfill: old incompatible evidence correctly abstains from learning while interactive history remains available.

### 8. Locked design

Add optional `check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval REPORT`. This is an explicit Cloud Build BRANCH SOURCE PUSH route, not permission for a manual Cloud Run mutation. It admits only effective class `deployment`, exact canonical GitHub identity `popcre/designflow-backend`, and the following committed manifest object with exactly these keys:

`{"schema_version":1,"repository":"popcre/designflow-backend","route":"cloud-build-branch-push","branch":"sandbox-albert","project":"lithe-breaker-323913","region":"us-east4","service":"popcre-albert-core-sandbox"}`

Central policy new `application_source_releases` is a CLOSED map containing only that repository, its fixed manifest path, exact expected target object, and required consumer-local deployment gate `cloud-build-release-review`. Schema uses existing supported `const`/properties/additionalProperties=false constructs, not unsupported enum/propertyNames or a new validator. The caller cannot supply arbitrary manifest locations: require the exact central relative path, a regular nonsymlink file contained by the actual repository, committed at HEAD and byte-identical to its HEAD blob. Reject malformed JSON, duplicate keys, extras, wrong types, any wrong target or route. Read admitted identity from existing canonical Git-origin resolution, never from the manifest alone; aliases/foreign hosts/toolkit identities do not inherit admission.

Admission MUST explicitly validate an existing independent lifecycle-recorded final-check/security-review APPROVE through `reviewer_approval_summary REPORT deploy CURRENT_HEAD ACTUAL_WORKTREE`, including its existing exact source digest and implementer independence. A plan review cannot open release. Do not assume symbolic required gates or the ordinary successful ship path perform this validation. Retain all contributor reviewer-safety proofs; record only the exact app release override after successful proof validation. Validate before returning success. Absent the explicit flag, the old generic deploy refusal remains unchanged. An application flag on any other action refuses. Private evidence/tooling, infrastructure, production, shared-db and toolkit installation cannot enter this route even with a target-shaped file. No central/local existing gate is removed.

Parent findings resolution at 7:05 AM EDT, following assigned plan APPROVE8fcbbc9d at7:02 AM EDT: the actual consumer declaration is ALREADY present at application9e03f180 `.ai-devops/task-gates.json`: deployment requires `[sandbox-branch-pr-to-develop,designflow-no-self-merge,cloud-build-release-review,owner-authorization]` and forbids no actions. Later parent re-proves and preserves this declaration; missing-gate fixtures refuse. Parent explicitly declares application class deployment before its release checks; current actual source includes deployment-class `cloudbuild.yaml`. A feature worktree is permitted: manifest branch is the PUSH DESTINATION, not the candidate checkout branch; only approved HEAD→sandbox-albert is authorized. Canonical same-repository HTTPS/SSH protocol variants stay accepted; namespace aliases and foreign hosts remain unadmitted.

Reuse justification: existing `reviewer_release` at gate1075-1095 governs forbidden EFFECTIVE-class actions. This actual deployment-class app does not forbid deploy; its refusal instead comes from mixed reviewer-safety contributors at1064. Do not add a broad deployment-class forbidden-action release or duplicate the approval engine. New closed target metadata only qualifies that preceding installation-only refusal, while existing forbidden-action logic and proof helper remain untouched. Root owns this bounded metadata; consolidate/retire it only if a separately reviewed future shared mechanism can bind the SAME repo/target/source route without granting any new consumer or forbidden action. Retain contributor required-gate union and explicitly validate final independent source approval before success; parent and reviewer execute required tests, rather than falsely claiming every printed gate already has machine enforcement.

Construction literals: strict manifest parsing uses Python `object_pairs_hook` to reject duplicate keys, including nested duplicates, and explicit type checks (schema_version is integer1, not bool/float; all remaining fields strings), followed by exact expected-object comparison. Reuse existing Python availability selection; do not extend the schema validator with unsupported keywords. Reject combining the application flag with toolkit target-head/installed-checkout/installed-launcher/first-install, small-owner-entry/row-count/owner-quote or acknowledge inputs BEFORE any toolkit early return. Keep every existing scope/private/forbidden-action check, validate source-bound approval and verify the recorded override succeeds before returning success. Extend the existing negative matrix for these combinations and failed state recording.

Final parent construction clarification after assigned f689cc1f plan APPROVE at7:11 AM EDT: NEVER suppress the generic refusal merely because a flag string is present; present-but-invalid target OR absent/stale/wrong approval must refuse and must not reach the ordinary unenforced success return. App success is possible only after explicit validated-target plus independent-final-proof plus persisted matching override, after all existing stronger/forbidden checks. Add named fixture proving this fail-closed fallthrough boundary. Schema validates closed metadata shape; positive fixtures and runtime enforce the exact actual consumer-local gate, not cross-repository schema inference. Add the new value-taking flag to the existing fail-fast missing-value loop. Reject application-target combined with explicit check `--base` (including HEAD) before classification; preserve existing other-action base behavior. Narrowly document this source-only exception in BOTH current context and deployment docs while preserving every toolkit installation rule. Existing historic #335 remains its historical rollout owner; the appended repair is exclusively #1490/root, not a reopened historical programme.

### 9. Ordered implementation

1. Add closed central policy/schema and CLI parse/help for the one optional target flag. Preserve closed validation and class ranks. Gate: existing schema validator validates central/local policies and rejects malformed admission configuration.
2. Add narrow admission validation using existing helpers. Run it only for deploy with explicit target; prove exact repository/class/consumer gate/committed target, then independent final approval. It releases only the application-specific reviewer-safety generic-deploy refusal. All other forbidden/private/scope gates stay sealed. Gate: actual positive fixture contains both changed protected router and deployment source and a committed exact manifest; its lifecycle-recorded exact approval succeeds and records matching source/target, while the old toolkit refusal still fails.
3. Add adversarial fixtures to the EXISTING gate suite, not a duplicate harness. Update only relevant current context documentation and this STATUS/evidence. Gate: full listed suites, syntax, schema and whitespace pass. Commit only owned files and freeze. Parent independently verifies actual behavior; one child correction retry per this phase, later failures parent-owned.
4. Parent obtains assigned exact-head final review, reconciles fresh main, creates/pushes PR and uses normal queue/checks; attach PR and confirm actual merge. Then installation is separately reviewed against current merged target with normal receipts/stages. A known required private-memory boundary means installation/live application deployment remains OPEN; never call candidate-source invocation installed acceptance or bypass the installed launcher.
5. After this exact manifest contract is accepted, parent may prepare the manifest in owned application source while the separate installation remains blocked. Re-prove/preserve its already-present consumer cloud-build-release-review declaration, explicitly start class deployment, bind the manifest to the existing executed-shell/contract test, and obtain fresh exact-source/release approval (old9e approval expires on source movement). Preparation remains unshipped. ONLY after supported installation succeeds, check ship AND the explicit application deploy route using the installed launcher, then push only approved HEAD to sandbox-albert through normal Cloud Build. Update existing open PR161 without destroying its TLS work and preserve Uma merge ownership. Prove each enabled revision's CPU/minimum, exact image/source and unchanged interactive capability. Native Luna access and complete genuine review-to-RAG live proof remain separate #94 boundaries.

### 10. Tests and adversarial matrix

All rows below belong in `tests/test-ai-task-gates.sh` using its existing `newrepo`, `appr`, lifecycle fixtures and rc/out helpers. Run that full suite plus `tests/test-ai-task-gates-bulk.sh`, `tests/test-task-gates-phase5-acceptance.sh`, `tests/test-ai-task-gates-linux-install.sh`, schema validation, `bash -n bin/ai-task-gates tests/test-ai-task-gates.sh`, and `git diff --check`. No provider/live cloud tests in child.

| Input | Hostile case | Existing-suite named assertion to add/retain |
|---|---|---|
| Target/repo/class | Exact approved app with protected contributor and deployment | application source release requires and accepts exact final approval |
| Action | Flag on ship/review/database/production | application target flag cannot open another action |
| Generic route | No explicit target / toolkit reviewer-safety with approval | generic reviewer-safety deploy remains forbidden |
| Repo/origin | Another app, toolkit, foreign host, namespace alias, no remote; same-repo protocol variants | unadmitted origins refuse while canonical protocol variants remain supported |
| Effective class | Private evidence/tooling/shared-db/production/infrastructure | stronger protected classes cannot use application release |
| Consumer gate | Missing cloud-build-release-review in local deployment requirements | central admission requires consumer opt-in |
| Manifest | Missing/untracked/dirty/symlink/path escape | destination must be exact committed regular source |
| JSON | Malformed/duplicate/extra/wrong-type keys | ambiguous application target refuses |
| Target fields | Wrong project/region/service/branch/route/repository | every target binding independently refuses |
| Approval | Missing/REJECT/plan/foreign repo/stale SHA/digest/source/implementer-self | application release retains independent final exact-source proof |
| State | Valid success then source/target movement | prior override never authorizes changed source |
| Installation | Old canonical toolkit test and receipt suites | installed routing and generic refusal are unchanged |

### 11. Constraints

Parent owns schema/security/merge/release decisions; this plan locks the new admission design before lower-tier mechanical execution. Source-only repair does not authorize current refused shipment, production mutation, new provider calls or private-note updates. Write only dedicated current-upstream worktrees. Keep GitHub calls through ai-gh, exact task class reviewer-safety, protected merge queue, standing signature and all human times EDT. No new handoff/memory update: user explicitly keeps continuation on existing issues.

### 12. Environment

Linux edge-dev3, normal authenticated ai-gh/GCP read-only; Bash/jq/Python are available. Toolkit source canonical checkout remains landing-only and its completed installation receipt remains old. Use owned `/home/ahazan/.codex/worktrees/hts-application-release-gate`. No secret value or 1Password operation is needed for source/fixtures/review. Full later installation needs separately scoped existing protected installer credentials and actual user bus; its private-note health boundary is not waived by this plan.

### 13. Done and risks

Source done means focused/full required tests, parent reproduction, exact independent final APPROVE, queued PR actually merged and docs accurate. Operational done additionally requires supported installed launcher/receipt/stages and live app release checks; it is BLOCKED on private-memory health until legitimately resolved without unauthorized edits. Rollback is normal reviewed Git revert/release, never an unreviewed live script replacement. The key risk is accidentally turning app admission into a toolkit/private/manual-production loophole; the negative matrix and closed central target prevent that. Genuine RAG proof is still open on missing native provider access; no source or CPU acceptance closes #94.

Self-audit: a fresh implementer can follow §§2,4,5,8–12 without chat; exact route/schema/target/proof/fixtures are specified. Failed and forbidden approaches plus current installation boundaries are preserved in §§3,5–7,13. Business intent and independent-review/preserve-capability decision criteria are explicit in §§1,8,13. All13 sections are present; existing issue/plan continuation overrides creation of a competing handoff or memory entry.

### Resumed verification correction — October 8, 1:10 PM EDT

The earlier generic-refusal/encoding diagnosis was incorrect. Byte inspection confirms actual tab-delimited contributor storage, not literal backslash-t encoding. The consumer fixture originally compared against moving HEAD; committing its source removed the changed reviewer-safety contributor from that comparison. The existing fixture now freezes its initial commit as APP_BASE and asserts the changed src/router.ts classification before admission checks. The actual focused block passes four assertions: changed reviewer-safety source, generic refusal, explicit reviewed admission, and refusal without approval. No contributor encoding or gate-engine change was made. This dated correction supersedes the earlier closeout hypothesis without rewriting its historical handoff.

Owned source was reconciled cleanly with current upstream main. Full prescribed suites are assigned to an isolated disposable source copy on an existing alternate host because local CI remains active. Root retains exact-head review, merge, and installation decisions. Fresh installation diagnosis is separate: current private indexes fit the existing cap and user bus exists; lock filenames and consuming authorizations alone do not establish an active installer. Current installed receipt and supported stage health must be verified before any retry.
