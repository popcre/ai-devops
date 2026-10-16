# IMPLEMENTATION PLAN — exact DesignFlow sandbox source releases (2026-10-16)

## STATUS

Issue: https://github.com/popcre/ai-devops/issues/1796. Owner: coordinator with delegated design author
codex/exact-sandbox-release.

| Step | State (2026-10-16) | Evidence / next gate |
|---|---|---|
| Independent design review | done | Native Muse ca14d6abd4bfb6438939ba9ff3e5a2e4a540d22b APPROVE; coordinator accepted and authorized exact scope |
| Strict implementation and tests | partial | tools/application_source_release.py, tests/test_application_source_release.py and tests/test-ai-task-gates.sh; final checks/review remain |
| Final review, PR, queue, protected installation | open | No PR/push/install authorized yet |
| Consumer adoption and live proof | open | Same issue retains live-proof checklist |

Fresh session starts at final implementation checks/review. Registered handoff: [design
handoff](HANDOFF.d/2026-10-16T0419Z-edge-dev3-codex-exact-sandbox-release.md).

## 1. Ultimate goal

Allow reviewed DesignFlow changes to reach four sandbox applications in total: retain the existing backend
capability and add tracking, frontend, and Item Master without weakening release protection. If any step below
conflicts with this goal, the goal wins — stop and flag it.

## 2. Application

popcre/ai-devops is the public Bash/Python/JSON recovery toolkit, not an application deployment platform.
Installed source on edge-dev3 is /home/ahazan/repos/ai-devops, exact b20da460df6b3c18410723a50899a7ed7c586413.
Source work belongs in a dedicated worktree, here
/home/ahazan/.codex/worktrees/exact-sandbox-release/ai-devops. DesignFlow consumers use Cloud Build regional
GitHub branch triggers and Cloud Run; this gate admits only their ordinary source push, never cloud API
mutation.

## 3. Trigger

Coordinator's reviewed tracking change was refused by native deploy admission because its plan contributes
reviewer-safety. Existing application-source-release path supports only backend. Reproduce with the ordinary
deploy gate on the complete actual consumer change set; do not reset its base or split protected files away.
This document records diagnosis, not a newly attempted deployment.

## 4. Scope

Extend the EXISTING source-release mechanism to exactly four central targets. Keep schema version 1, manifest
path, consumer gate, CLI interface, deployment intent, protected contributor collection and exact-head proof
semantics.

NOT included: production; BFF; data-sync; arbitrary repositories/targets; wildcard allowlists; manual cloud
mutations; application-workflow expansion; SQL; secrets; credential rotation; replay; changes to DesignFlow
merge authority; installation before normal review/merge. Preserve the separate private 4250 candidate
unchanged.

## 5. Current source

At b20: config/task-gates.json:67 central map has backend only; config/task-gates.schema.json:49 disallows
other keys. bin/ai-task-gates:637-777 validates exact backend policy/manifest/origin and records the
source-release receipt. Lines 1490-1514 retain reviewer-safety contributor requirements and generic deploy
refusal; lines 1655-1658 finish the explicit route. docs/context-spec.md:122 describes a single backend
target. tests/test-ai-task-gates.sh:1339-1460 contains closed-target admission/refusal/race coverage. No
implementation files changed for this proposal.

## 6. Findings

No equivalent route exists for the three consumers. application-workflow is separately limited to backend#94,
not a release substitute. Central schema AND runtime validation must change together; consumer declarations
alone cannot expand authority. Deployment rank60 exceeds reviewer-safety30/UI40, but strongest contributors'
required gates remain additive: explicit deployment declaration is required; no contributor
deletion/reclassification.

Read-only live Cloud Build trigger inventory on this date used project lithe-breaker-323913 / region us-east4.
Each listed trigger's push branch is exactly ^sandbox-albert$ and _SERVICE_NAME matches service below.
Repository connection leaves are pop-dflow-backend, pop-dflow-tracking, pop-dflow-frontend,
pop-dflow-item-master respectively. Do not use older deployment-doc service guesses.

Prospective final-check correction: offline next-release fixture reproduced generic deploy returning0
with an exact synthetic approval, an upstream closed-gate declaration, ordinary app/pipeline delta,
review-branch and absent origin/develop. Thus the generic path could omit the new proof after initial
adoption. Root authorized NEW-THREE-only refusal of generic deploy whenever the deployment consumer gate
requires cloud-build-release-review; every deploy must supply the exact target flag. Backend and other
actions remain unchanged. The approved3c6 review is retained as historical, not authority for changed code.

## 7. Rejected approaches

No generic reviewer_release.deploy exception: it would widen protected deployment beyond exact sandbox source
pushes. No arbitrary consumer-selected central targets. No new application-workflow. No base reset, narrower
successor to hide protected files, generic ship after refused deploy, manual cloud deploy, self-merge, or
human technical permission. No duplication of existing approval parsers/receipt writers.

## 8. Locked decisions (2026-10-16)

Coordinator selects exactly these schema_version=1, route=cloud-build-branch-push, branch=sandbox-albert,
project=lithe-breaker-323913, region=us-east4 entries:

| Repository | Service |
|---|---|
| popcre/designflow-backend | popcre-albert-core-sandbox |
| popcre/designflow-tracking | popcre-albert-tracking-sandbox |
| popcre/designflow-frontend | popcre-albert-frontend-sandbox |
| popcre/designflow-item-master | popcre-albert-item-sandbox |

NEW-THREE consumer scope nuance: fresh-fetch and merge actual current develop before release; classify against its true
current merge-base. Item Master inherited a shared-db subtree already byte-identical in upstream develop;
classification is the complete base-to-HEAD path delta plus staged/unstaged/untracked/deleted/rename
sides/submodule changes, never all historical files merely present in the tree. Excluding unchanged
already-upstream bytes through that honest comparison is legitimate, while resetting a base to hide owned
changes is forbidden. Any actual shared-db or stronger contributor keeps the native path refused. New
manifest/consumer declarations are deployment wiring; no generalized protected-class bypass.

LOCKED final coordinator decision supersedes earlier tightening proposals: preserve backend
source-release semantics/platforms EXACTLY as installed b20, including accepted local branch/base behavior.
Only the THREE newly admitted consumers receive fresh managed-ref, honest-base, local-context and Linux
executable-provenance proofs. No new backend network dependency or platform restriction. This preserves
existing protection; it is not a waiver of an existing guard.

All use .ai-devops/application-release-target.json and consumer required gate cloud-build-release-review.
Backend exact accepted target stays identical. OPEN: minimal factoring of shared validation without changing
behavior; no open authority/scope choice.

## 9. Ordered implementation, gated

1. PREWORK ONLY: publish signed issue1796 contract before code, commit this design/handoff/router
registration, obtain genuinely independent native Muse plan-review with implementing engine Codex. Gate:
explicit technical APPROVE bound to this design plus coordinator implementation authorization. A plan review
never admits deploy/install. No retrospective evidence.
2. AFTER authorization: immediately re-read live Cloud Build inventory using `gcloud builds triggers list
--project=lithe-breaker-323913 --region=us-east4 --format=json`, selecting the four named repository
connection leaves and exact ^sandbox-albert$ branch. Compare each _SERVICE_NAME, _REGION and project with §8;
any missing/duplicate/mismatched trigger STOPS before editing central policy and returns to coordinator.
Retain sanitized tuple evidence on issue1796. Then change config/task-gates.json to four exact entries,
config/task-gates.schema.json to exactly those four required properties with additionalProperties:false
throughout. Preserve reviewer_release.deploy.deployment == null. Gate: tools/ci/validate-task-gates.py
succeeds and rejects missing/extra/foreign target fixtures.
3. Audit `tools/lib/task-gates.sh` identity and `bin/ai-task-gates` repository/base/change-set resolution.
   Audit `tools/review_action_profile.py` and `config/review-action-profiles.json` backend-only references:
   these belong to the separate fixed #770 private rehearsal authority and MUST remain unchanged. Do not
   widen them. Audit task-router/context/architecture references; only correct source-release documentation.

   3a. Replace singleton target resolution with the closed four-entry central exact map in §8. Validate
   complete fixed policy keys and tuples, not mere lookup existence. Canonical raw AND effective origin must
   match the existing HTTPS/SCP/SSH forms for that validated repository. Preserve legitimate Git transport,
   proxy, credential helper and SSH settings: no NEW Git network calls inside admission. Backend
   dispatches its existing unchanged proof path and keeps original accepted branch/base/platform behavior.
   For new three, normal fetch
   remains outside admission. Manifest/consumer regular committed clean blob checks remain mandatory.

   A non-authorizing strict manifest discriminator can select NEW-THREE pre-Git confinement before
   discovery; final central target/origin/source binding remains mandatory. A manifest claiming backend
   never authorizes another repository's release. New-three module returns supplemental proof only; it
   cannot generate approval, publish receipts, execute source code or initiate deployments. Before/after
   bound source/manifest checks prevent target switching. Test forged backend manifest in each new repo; release-forged-backend-target-refused MUST prove no new-three identity/target/source receipt can result.

   3b. NEW THREE ONLY: before EVERY Git invocation, including initial discovery, refuse nonempty GIT_DIR,
GIT_WORK_TREE,
   GIT_COMMON_DIR, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY, GIT_ALTERNATE_OBJECT_DIRECTORIES, GIT_NAMESPACE,
   GIT_CEILING_DIRECTORIES, GIT_DISCOVERY_ACROSS_FILESYSTEM, GIT_CONFIG, GIT_CONFIG_SYSTEM, GIT_CONFIG_GLOBAL,
   GIT_CONFIG_NOSYSTEM, GIT_CONFIG_COUNT, GIT_CONFIG_PARAMETERS and every GIT_CONFIG_KEY_*/GIT_CONFIG_VALUE_*
   override, plus GIT_REPLACE_REF_BASE/GIT_GRAFT_FILE. Do not blanket refuse GIT_SSH/SSH_COMMAND/PROXY_COMMAND
   or existing proxy/auth settings: these are not used by local ancestry commands. Validate the physical
   source root and common directory; use -C that exact root for local commands; recheck both at finish.
   Refuse shallow repository, replacement refs and nonempty common-dir info/grafts. Trusted Git resolution
   follows existing native installed runtime policy; no caller-selected program or unverified PATH shim.

   3c. NEW THREE ONLY: root explicitly supersedes the first ls-remote design: reuse installed `bin/ai-gh`, the
existing
   managed authenticated GitHub helper. Exact fixed-host request is `api --hostname github.com --method GET
   repos/<validated-four-repository-identity>/git/ref/heads/develop`, no cache/pagination/template or caller
   endpoint. Capture response and errors privately and bound each helper process to 30 seconds, including
   its existing quota admission. Reject timeout, HTTP/admission/auth error, duplicate JSON keys, malformed
   response or noncommit. Require exact ref refs/heads/develop, object.type commit and 40-hex object.sha;
   validate response URL identity if present, never follow a caller-supplied URL. Compare SHA with local
   refs/remotes/origin/develop before approval and again immediately before receipt. Remote movement or
   network failure refuses without successful receipt. No cached preflight assertion is accepted.

   3d. NEW THREE ONLY: installed ai-gh must come from the validated current toolkit root and unchanged trusted
source
   closure. Validate/pin real gh before supplying its path to helper; arbitrary AI_GH_REAL_GH/PATH override
   cannot authorize release. Preserve legitimate GH_CONFIG_DIR, credential helpers, supported proxies and
   existing authentication. Do not resolve secrets through 1Password. Source audit confirms ai-gh,
   telemetry.sh and pr-status-context contain no task-gate/review/1Password calls; helper only manages
   authenticated quota reads and local protected accounting, so no recursive gate/admission cycle.
   Initial new-three qualification is Linux only; unsupported platforms refuse ONLY the new entries.
   Pin /usr/bin/gh after root-owned regular nonwritable executable and ancestor checks, following the
   existing tools/oracle_native_alternate_runtime.py public_origin verification pattern without importing
   Oracle operational authority. Reject arbitrary AI_GH_REAL_GH; validated module supplies the proven path
   internally to existing ai-gh. Validate the installed toolkit helper's exact closure/provenance against
   current trusted installation; no arbitrary PATH executable. Preserve existing backend Windows support.
   Implement these supplemental NEW-THREE-only proofs in tools/application_source_release.py with
   tests/test_application_source_release.py using unittest.mock subprocess boundaries; no production test
   override. Coordinator approved this module boundary; no alternate auth implementation. Native Bash
   route retains central target, manifest/consumer, approval/local-test and atomic receipt machinery.

   3e. NEW THREE ONLY: normal `git fetch origin develop` happens before admission. Require its local ref SHA
   equal the managed fresh API result. Require UNIQUE `git merge-base --all HEAD refs/remotes/origin/develop`, the
   recorded declaration base equals that commit, and develop is ancestor of HEAD. Classification is the
   entire base-to-HEAD path delta plus staged/unstaged/untracked/deleted/rename sides/submodules, never
   historical whole-tree paths. An unchanged mirror already in develop is excluded; any actual owned
   structural delta is not. For new-three admission explicitly refuse ANY shared-db contributor despite
   its rank50 being below deployment60, and retain infrastructure/production/private seals. Eligible reviewer/UI contributors
   retain all merged required proofs. Require deployment intent and actual branch sandbox-albert; admission
   runs in a serialized landing/owned clone on that branch with identical reviewed HEAD/digest, not the
   local review branch. Revalidate context/config/refs/base/branch/source/approval before finish.

   3f. Preserve native independent final-check/security-review exact repository/head/source/deploy seal,
   mandatory passing snapshot tests and atomic receipt. Preserve backend receipt behavior exactly; add exact
   repository/target provenance for new-three proof receipts only; backend record semantics stay unchanged.
   For new-three receipts, old or backend receipt is historical audit only, never current
   authorization: every admission revalidates fresh proof and creates a new bound receipt. No new action,
   generic reviewer_release, runtime test bypass or manual cloud permission. Gate: all positive and hostile
   cases in §10 pass; no forbidden contributor slips through deployment rank.

4. Expand tests/test-ai-task-gates.sh and tests/test_application_source_release.py; no new parallel gate
implementation. Update docs/context-spec.md and help/error strings from singleton to fixed-four.
tools/ci/validate-task-gates.py is schema-generic and should need no logic changes; prove this with existing
validator tests. Confirm AGENTS plan link is reachable under .doc-reachability.json roots, with
bin/ai-doc-reachability using its supported CLI. AGENTS pointer owner is codex/exact-sandbox-release and
retirement is tied to issue1796 closure, not an invented future date. Gate: focused tests and normal
repository-required local suite pass, exact-head independent final review records snapshot tests. No paid
repeat after unchanged success.
5. Coordinator separately owns normal branch PR/queue, merged-head reconciliation and protected installation
using reviewed exact merged toolkit source; never pull installed checkout. Gate: installation receipt/doctor
prove installed release. Design approval alone supplies no install authority.
6. AFTER installed repair: coordinator creates dedicated current-upstream worktrees for three consumers;
commits exact manifests plus additive `.ai-devops/task-gates.json` JSON
`{"gates":{"deployment":{"required":["cloud-build-release-review"]}}}` merged into the existing declaration,
never replacing other keys. Central deployment class rank60/protected=true and default deployment
required/forbidden posture continue unchanged; consumer gate union adds proof and never removes restrictions.
Preserve schema_version and existing paths/gates. This is the exact deployment.required addition, preserving
existing fields and stricter gates verbatim, specifically central no-self-merge, sandbox-branch-pr-to-develop
and route-to-shared-db-repository requirements and their forbidden actions (config/task-gates.json:503-531); deployment proof union/default posture is separately at280-291.
Do not replace those arrays with the new gate. Keep backend existing acceptance fixtures unchanged and
perform read-only serving-health proof; no new backend source push/redeploy/HTS retry is authorized. Immediately before each of the THREE newly supported source
pushes re-inventory
the same exact Cloud Build tuples from step2; drift/missing/duplicate mapping stops before push. Re-run
meaningful consumer tests/native exact-head review since
consumer commits move approved heads. Gate: explicit check --before deploy --application-release-target
.ai-devops/application-release-target.json --reviewer-approval REPORT admits exact final source. Then ordinary
sandbox branch push and automated deploy readback/live smoke. PR remains sandbox-albert→develop with existing
no-self-merge authority unchanged. Same issue retains live proof until three new consumer admission/deploy/
live proofs plus unchanged backend acceptance fixtures and read-only serving health pass.

### Adversarial inputs and required named tests

| Input | Hostile case | Test name/behavior in existing task-gates suite |
|---|---|---|
| Central policy | Fifth/missing entry, wrong tuple, generic reviewer_release | release-policy-exact-four rejects all |
| Manifest JSON | Duplicate key, unknown key, wrong schema type/version | release-manifest-strict-json refuses before approval |
| Target/origin | Cross-repo manifest, foreign origin, production service/project/region, other branch | release-cross-target-refusal parameterized across four |
| Worktree | Dirty/untracked manifest/consumer, symlink, traversal, wrong blob | release-committed-files-only retains and parameterizes existing refusals |
| Class/contributors | No deployment intent, stronger private/shared-db/infrastructure/production, reviewer-safety-only | release-class-contributor-seal refuses stronger or wrong effective intent; eligible deployment retains reviewer/UI requirements |
| Approval | Missing, REJECT, plan-only, stale/head/digest/repo/action/provider/implementer mismatch | release-native-exact-proof retains existing adversarial approval fixtures |
| Tests | Missing/failed/no SHA snapshot test evidence | release-tests-required refuses each |
| Concurrent movement | HEAD/blob/source/approval changes during verification | release-race-refusal retains double validation |
| Receipt write/replay | Atomic persistence failure or old backend receipt without new fields | release-receipt-failure and release-old-receipt-non-authorizing refuse admission without fresh full proof |
| Git context/API | Directory/config/discovery/ancestry injection, real-gh override, wrong API host/repo/SHA/type, duplicate JSON, timeout, moved ref | release-git-context-confined and release-managed-ref-proof reject each; release-auth-capability-preserved accepts supported proxy/SSH/auth settings without using Git network |
| Base provenance | Recorded HEAD/arbitrary reset, stale local develop, remote failure/moved ref, shallow history, replace/graft or multiple bases | release-honest-merge-base-admitted accepts exact inherited upstream mirror; release-base-reset-refused rejects hidden owned delta; release-fresh-develop-required refuses stale/missing/network and finish-race; release-ancestry-clean-required rejects shallow/replace/graft/multiple bases |
| Existing backend compatibility | New-three proofs accidentally affect backend local branch/base/Windows or force network | release-backend-b20-semantics-preserved keeps existing fixtures unchanged; no new-three helper invocation for backend |
| Consumer gates | New gate overwrites old security/merge requirements | release-consumer-gates-additive preserves existing arrays and forbids weaker declaration |
| CLI route | Future generic deploy with opted-in declaration already upstream and exact approval; wrong action, explicit base, acknowledgement/install/target-head combos | release-cli-no-alternate-route retains all existing refusals |

## 10. Required tests

Run python3 tools/ci/validate-task-gates.py config/task-gates.json; bash tests/test-ai-task-gates.sh; schema
acceptance/refusal cases at tests/test-ai-task-gates.sh:1309-1350 (same existing suite, no separate schema
suite guessed); native review records these passing in isolated snapshot. Run bin/ai-test-local
--check-collision before repository full-required suites and follow docs/development.md current suite, not
guessed old commands. Four positive fixtures must independently record correct identities/targets and reject
manifests from each of the other three. Existing backend fixtures remain UNCHANGED and passing, with NO new
network/platform/branch/base requirement. Actual schema tests are in
 tests/test-ai-task-gates.sh:1309-1350. No Git network mocks are needed in production. Deterministic helper
 proof tests must use unit-level subprocess mocking in a source-release-specific proof module, not a
 production environment bypass. Existing Bash fake-gh fixture at1565 uses AI_GH_REAL_GH and CANNOT stand in
 for trusted real-gh qualification; reject that injection at runtime. Existing lib-test-harness.sh and
 lib-reviewer-approval.sh remain the suite's offline reporting/native approval fixture infrastructure.
 Name pure boundary tests release-forged-backend-target-refused, release-managed-ref-proof, release-git-context-confined, release-old-receipt-
 non-authorizing, release-auth-capability-preserved plus all table cases; integration asserts validated
 helper is invoked twice and errors cannot produce a receipt. Coordinator selected the small proof module
boundary and Linux provenance for NEW THREE ONLY. No implementation until final technical APPROVE plus
coordinator GO.
 Verify inherited mirror exclusion AND actual structural delta refusal, backend original fixtures unchanged,
and NEW-THREE off-branch/base refusal, generic ship not deploy. Run bin/ai-doc-reachability with supported CLI
plus an explicit file-existence/relative-link check for both plan/handoff links; HANDOFF.d exclusion from the docs
 graph is intentional, not a reason to remove the required backlink. Require retained backend existing
acceptance fixtures and read-only serving health; do not redeploy it or replay spent HTS authority.

## 11. Constraints

Actual class reviewer-safety for toolkit implementation; redeclare before any stronger gate. No implementation
before design APPROVE+coordinator authorization. Current-upstream own worktree only, only owned staging;
required Git identity Albert Hazan <u2giants@users.noreply.github.com>. No push/PR/install currently
authorized. Review engine independent of implementer. Keep original failed refusals/evidence. No 1Password
during review. No private records in public artifacts. All clocks in America/New_York; machine filenames may
UTC. No DB work and no cloud writes. No removal of UI/role/security safeguards or recovery capabilities.

## 12. Access/environment

Existing authenticated gh and gcloud read-only metadata suffice. No new credentials or 1Password calls
required. Current source and tests are local Bash/Python/jq. Read AGENTS.md, task-router task-classification
row, docs/architecture.md and docs/development.md before implementation; docs/deployment.md/configuration.md
before later installation. Actual cloud inventory is read-only and contains no credential values.

## 13. Definition of done, risks and open gates

Design completion is only independent technical APPROVE delivered to coordinator. Full capability completion
needs strict implementation/tests; final native exact-head review; normal PR/queue merge; protected exact
merged-source install; three committed consumer declarations and refreshed exact-head reviews; successful
native admissions; automated sandbox deploy identity and live proof on same1796 card. Main risk is broadening
authority through a data-driven target lookup or lost contributor gates: exact-four runtime+schema validation
and refusal tests address it. Backend branch/base/platform/receipt semantics remain exactly b20; new-three
strict checks must not leak into backend dispatch. Verify backend existing fixtures unchanged and only
read-only serving health, never a new backend source push or spent HTS replay. Rollback uses normal
reviewed toolkit source release retaining original backend path; never remove consumer functionality or
overwrite installed tools by hand. No production authority is created. Actual production stage-catalog
delivery remains coordinator-owned separate work.

Prior native design review REJECT report is retained unchanged outside tracked source at this worktree's
ignored .ai/reviews/muse-plan-review-20261016T041946-3667877-13993.md; the revised review also remains at
.ai/reviews/muse-plan-review-20261016T042256-4061545-25028.md and third REJECT
.ai/reviews/muse-plan-review-20261016T042609-338138-13715.md. They are private local review artifacts, not
present in disposable source snapshots; coordinator has exact paths/hashes. Public issue1796 records verdict
summaries only. This revision addresses its findings prospectively; no verdict or test result is inferred from
the revision.

Self-audit: all13 sections, linked handoff, exact targets/files, ordered dependency gates, rejected
approaches, adversarial named tests, closure and access are present. A fresh session can execute authorized
phases without chat; it MUST stop at explicit coordinator/design gates because implementation has not been
authorized. Goal and locked decisions govern deviations. This is a prospective prework contract; no evidence
is backdated.

### Prospective CI registration correction — October16, after PR1797 failure

Root authorized this bounded correction after genuine CI `test-reviewer-ci-paths` refused three newly
transitive dependencies: `tools/github-requests/telemetry.sh`, `tools/github-requests/pr-status-context`,
and `tools/application_source_release.py`. No validator is disabled and no full-suite PASS is inferred.
Fresh main90b52dffb0b01c69b3c9e6377b6108e744ce1500 was merged normally before these edits, preserving
PR1790's frozen-provider CI changes and PR1795's carried questions. Earlier exacteac review remains
historical, not reused for changed source.

Before changing implementation: add `tools/application_source_release.py`, `bin/ai-gh` and the entire
managed `tools/github-requests/**` closure to `config/reviewer-ci-paths.txt`. The supplemental release
proof hashes that exact installed helper closure and invokes its launcher, so all of it now legitimately
selects reviewer CI. Adjust `tests/test-reviewer-ci-paths.sh` to stop declaring ai-gh unrelated/mention-only,
require these direct paths and verify a representative closure member; preserve actual transitive walking
and unrelated-path negatives. This is registration of real dependencies, not broader release authority.
Gate: unchanged transitive completeness test passes, targeted source-release16 tests pass, all own diff
checks pass and a FRESH native exact-head Muse final review APPROVEs before coordinator authorizes push.
Do not rerun unchanged439 focused assertions merely to repeat prior proof; fresh CI supplies full suite.
