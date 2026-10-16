# IMPLEMENTATION PLAN — exact DesignFlow sandbox source releases (2026-10-16)

## STATUS

Issue: https://github.com/popcre/ai-devops/issues/1796. Owner: coordinator with delegated design author codex/exact-sandbox-release.

| Step | State (2026-10-16) | Evidence / next gate |
|---|---|---|
| Independent design review | open | This document; require explicit technical APPROVE and coordinator acceptance before implementation |
| Strict implementation and tests | open | No implementation authorized yet |
| Final review, PR, queue, protected installation | open | No PR/push/install authorized yet |
| Consumer adoption and live proof | open | Same issue retains live-proof checklist |

Fresh session starts at independent design review. Registered handoff: [design handoff](HANDOFF.d/2026-10-16T0419Z-edge-dev3-codex-exact-sandbox-release.md).

## 1. Ultimate goal

Allow reviewed DesignFlow changes to reach the three existing sandbox applications without weakening release protection. Retain the existing backend capability. If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. Application

popcre/ai-devops is the public Bash/Python/JSON recovery toolkit, not an application deployment platform. Installed source on edge-dev3 is /home/ahazan/repos/ai-devops, exact b20da460df6b3c18410723a50899a7ed7c586413. Source work belongs in a dedicated worktree, here /home/ahazan/.codex/worktrees/exact-sandbox-release/ai-devops. DesignFlow consumers use Cloud Build regional GitHub branch triggers and Cloud Run; this gate admits only their ordinary source push, never cloud API mutation.

## 3. Trigger

Coordinator's reviewed tracking change was refused by native deploy admission because its plan contributes reviewer-safety. Existing application-source-release path supports only backend. Reproduce with the ordinary deploy gate on the complete actual consumer change set; do not reset its base or split protected files away. This document records diagnosis, not a newly attempted deployment.

## 4. Scope

Extend the EXISTING source-release mechanism to exactly four central targets. Keep schema version 1, manifest path, consumer gate, CLI interface, deployment intent, protected contributor collection and exact-head proof semantics.

NOT included: production; BFF; data-sync; arbitrary repositories/targets; wildcard allowlists; manual cloud mutations; application-workflow expansion; SQL; secrets; credential rotation; replay; changes to DesignFlow merge authority; installation before normal review/merge. Preserve the separate private 4250 candidate unchanged.

## 5. Current source

At b20: config/task-gates.json:67 central map has backend only; config/task-gates.schema.json:49 disallows other keys. bin/ai-task-gates:637-777 validates exact backend policy/manifest/origin and records the source-release receipt. Lines 1490-1514 retain reviewer-safety contributor requirements and generic deploy refusal; lines 1655-1658 finish the explicit route. docs/context-spec.md:122 describes a single backend target. tests/test-ai-task-gates.sh:1339-1460 contains closed-target admission/refusal/race coverage. No implementation files changed for this proposal.

## 6. Findings

No equivalent route exists for the three consumers. application-workflow is separately limited to backend#94, not a release substitute. Central schema AND runtime validation must change together; consumer declarations alone cannot expand authority. Deployment rank60 exceeds reviewer-safety30/UI40, but strongest contributors' required gates remain additive: explicit deployment declaration is required; no contributor deletion/reclassification.

Read-only live Cloud Build trigger inventory on this date used project lithe-breaker-323913 / region us-east4. Each listed trigger's push branch is exactly ^sandbox-albert$ and _SERVICE_NAME matches service below. Repository connection leaves are pop-dflow-backend, pop-dflow-tracking, pop-dflow-frontend, pop-dflow-item-master respectively. Do not use older deployment-doc service guesses.

## 7. Rejected approaches

No generic reviewer_release.deploy exception: it would widen protected deployment beyond exact sandbox source pushes. No arbitrary consumer-selected central targets. No new application-workflow. No base reset, narrower successor to hide protected files, generic ship after refused deploy, manual cloud deploy, self-merge, or human technical permission. No duplication of existing approval parsers/receipt writers.

## 8. Locked decisions (2026-10-16)

Coordinator selects exactly these schema_version=1, route=cloud-build-branch-push, branch=sandbox-albert, project=lithe-breaker-323913, region=us-east4 entries:

| Repository | Service |
|---|---|
| popcre/designflow-backend | popcre-albert-core-sandbox |
| popcre/designflow-tracking | popcre-albert-tracking-sandbox |
| popcre/designflow-frontend | popcre-albert-frontend-sandbox |
| popcre/designflow-item-master | popcre-albert-item-sandbox |

All use .ai-devops/application-release-target.json and consumer required gate cloud-build-release-review. Backend exact accepted target stays identical. OPEN: minimal factoring of shared validation without changing behavior; no open authority/scope choice.

## 9. Ordered implementation, gated

1. PREWORK ONLY: publish signed issue1796 contract before code, commit this design/handoff/router registration, obtain genuinely independent native Muse plan-review with implementing engine Codex. Gate: explicit technical APPROVE bound to this design plus coordinator implementation authorization. A plan review never admits deploy/install. No retrospective evidence.
2. AFTER authorization: change config/task-gates.json to four exact entries, config/task-gates.schema.json to exactly those four required properties with additionalProperties:false throughout. Preserve reviewer_release.deploy.deployment == null. Gate: tools/ci/validate-task-gates.py succeeds and rejects missing/extra/foreign target fixtures.
3. In bin/ai-task-gates replace singleton expected target with CLOSED exact identity resolution validated against fixed four-entry policy. Validate policy's complete exact key set and exact per-repo tuples, not merely lookup existence; central policy cannot introduce fifth authority. Derive canonical-origin accepted forms from validated identity, retaining the currently accepted HTTPS/SCP/SSH forms only. Require effective deployment exactly, actual branch sandbox-albert, same committed manifest, clean contained nonsymlink ordinary blobs, consumer deployment-required cloud-build-release-review. Preserve full source/contributor classification, mandatory tests, native independent final-check/security-review exact repository/head/source/deploy seal, before/after checks and atomic receipt. Receipt includes identity and exact target in addition to existing head/manifest_blob/consumer_blob/approval binding; preserve existing backend receipt keys. Gate: tests below show only intended four source pushes can be admitted, generic deploy still refused.
4. Expand tests/test-ai-task-gates.sh and existing schema-validator tests; no new parallel gate implementation. Update docs/context-spec.md and help/error strings from singleton to fixed-four. Gate: focused tests and normal repository-required local suite pass, exact-head independent final review records snapshot tests. No paid repeat after unchanged success.
5. Coordinator separately owns normal branch PR/queue, merged-head reconciliation and protected installation using reviewed exact merged toolkit source; never pull installed checkout. Gate: installation receipt/doctor prove installed release. Design approval alone supplies no install authority.
6. AFTER installed repair: coordinator creates dedicated current-upstream worktrees for three consumers; commits exact manifests plus .ai-devops/task-gates.json deployment.required addition, preserving existing fields and stricter gates. Re-run meaningful consumer tests/native exact-head review since consumer commits move approved heads. Gate: explicit check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval REPORT admits exact final source. Then ordinary sandbox branch push and automated deploy readback/live smoke. PR remains sandbox-albert→develop with existing no-self-merge authority unchanged. Same issue retains live proof until all three verified.

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
| Receipt write | Atomic persistence failure | release-receipt-failure refuses no successful admission |
| CLI route | Generic deploy, wrong action, explicit base, acknowledgement/install/target-head combos | release-cli-no-alternate-route retains all existing refusals |

## 10. Required tests

Run python3 tools/ci/validate-task-gates.py config/task-gates.json; bash tests/test-ai-task-gates.sh; matching schema validation tests discovered via rg; native review records these passing in isolated snapshot. Run bin/ai-test-local --check-collision before repository full-required suites and follow docs/development.md current suite, not guessed old commands. Four positive fixtures must independently record correct identities/targets and reject manifests from each of the other three. Existing backend tests remain passing. Verify all negative rows above; verify generic ship cannot be treated as deploy admission. Recheck consumer branch and source identity immediately before normal push; source receipt is not live deployment proof.

## 11. Constraints

Actual class reviewer-safety for toolkit implementation; redeclare before any stronger gate. No implementation before design APPROVE+coordinator authorization. Current-upstream own worktree only, only owned staging; required Git identity Albert Hazan <u2giants@users.noreply.github.com>. No push/PR/install currently authorized. Review engine independent of implementer. Keep original failed refusals/evidence. No 1Password during review. No private records in public artifacts. All clocks in America/New_York; machine filenames may UTC. No DB work and no cloud writes. No removal of UI/role/security safeguards or recovery capabilities.

## 12. Access/environment

Existing authenticated gh and gcloud read-only metadata suffice. No new credentials or 1Password calls required. Current source and tests are local Bash/Python/jq. Read AGENTS.md, task-router task-classification row, docs/architecture.md and docs/development.md before implementation; docs/deployment.md/configuration.md before later installation. Actual cloud inventory is read-only and contains no credential values.

## 13. Definition of done, risks and open gates

Design completion is only independent technical APPROVE delivered to coordinator. Full capability completion needs strict implementation/tests; final native exact-head review; normal PR/queue merge; protected exact merged-source install; three committed consumer declarations and refreshed exact-head reviews; successful native admissions; automated sandbox deploy identity and live proof on same1796 card. Main risk is broadening authority through a data-driven target lookup or lost contributor gates: exact-four runtime+schema validation and refusal tests address it. Branch validation tightens existing backend behavior only to its already-locked declared branch; do not claim backend behavior unchanged for an off-branch invocation. Rollback uses normal reviewed toolkit source release retaining original backend path; never remove consumer functionality or overwrite installed tools by hand. No production authority is created. Actual production stage-catalog delivery remains coordinator-owned separate work.

Self-audit: all13 sections, linked handoff, exact targets/files, ordered dependency gates, rejected approaches, adversarial named tests, closure and access are present. A fresh session can execute authorized phases without chat; it MUST stop at explicit coordinator/design gates because implementation has not been authorized. Goal and locked decisions govern deviations. This is a prospective prework contract; no evidence is backdated.
