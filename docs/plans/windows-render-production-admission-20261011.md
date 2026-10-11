# Windows render production admission in one qualified hosted job

Status: PLAN ONLY; no policy change, admission, credential operation or production action is authorized by this document. Snapshot October 11, 2026, 4:04 PM EDT. Source baseline: ai-devops origin/main 4eb599475d78f36eedab3975529a09f4f5cfd320. Coordinator owns security decisions and landing; implementation is not started.

## 1. Ultimate goal

POP's Windows artwork renderer must start before anyone signs in, while retaining rendering, self-update and recovery. A technical reviewer must be able to authorize that one bounded Windows installation through the canonical host workflow without granting access to the production server or other cloud resources. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Application and repositories

PopDAM stores and previews licensed artwork; its Windows render agent runs on EDGE-ALIEN. App source belongs to u2giants/popdam3; durable host settings belong to u2giants/ansible; shared admission belongs to u2giants/ai-devops. GitHub owner aliases must be resolved against authenticated repository identity, not guessed. Canonical target is EDGE-ALIEN, existing endpoint 100.112.207.98; SSH hostname proof is required immediately before action. Only a dedicated Windows inventory/playbook/role is eligible. Hetz, NAS, Supabase and cloud infrastructure are excluded.

## 3. Trigger and reproduction

PopDAM #162 lacks current boot-without-login proof. Its reviewed host draft cannot run: central task-gates.json maps Ansible roles/playbooks/inventory to protected infrastructure and forbids production; ai-task-gates' protected-forbidden branch refuses reviewer overrides. The workflow also needs review evidence generated on a qualified reviewer host, while the installed lifecycle validator accepts only its own local registered report. A downloaded Markdown report and regular-expression APPROVE extraction are not authorization.

## 4. Scope

Implement one typed Windows render action with native independent review and preview/apply in the SAME qualified GitHub-hosted job/workspace/lifecycle. Reviewer artifacts are informational only; no transported authority is needed on the primary route. Include replay protection, preview binding and exact-object recovery requirements. NOT in this plan: broad infrastructure release; removing protected production restrictions; Windows runner enrollment; other host provisioning; model changes; any database mutation; NAS/password rotation; PopDAM code changes; fake render jobs; unconditional reboot; installer execution before independent approval. Existing PopDAM #162 remains the application card.

## 5. Current code and reuse

* bin/ai-task-gates reviewer_approval_summary validates completed/nonstale independent lifecycle APPROVE against repository key, head, source digest, exact canonical report path/hash; live actions require final-check or security-review. Preserve it for all existing callers.
* config/task-gates.json reviewer_release contains only database/private-tooling. Ansible infrastructure production remains forbidden.
* bin/ai-review-lifecycle supports identity/begin/finish/fail/status, not authentic crossrunner artifact import. Never create local native lifecycle records retrospectively from downloaded JSON.
* tools/review_action_profile.py and config/review-action-profiles.json provide an installed bounded manifest/action profile, canonical descriptor digest, prospective binding and preaction revalidation for one isolated database rehearsal. Reuse its pattern, not its database allowance.
* Shared-db scripts/production_apply_review_evidence.py verifies run repository/path/attempt, unique artifact identity, exact SHA256 archive digest and bounded archive content. scripts/verify_preview_apply_artifact.py demonstrates strict archive/allowlist binding. production_business_risk_gate.py's executed producer closure pins are the reference for rejecting changed producer code. These remain owned by shared-db and are references ONLY for a separately chosen transport fallback; the primary same-job route needs no artifact-authority verifier.
* bin/runner-github-admission.ps1 is paced runner REST transport, not production reviewer authorization. It cannot authorize this action.

## 6. History and rejected approaches

Generic --before production plus a review cannot override protected infrastructure. Local repository gates cannot weaken central policy. Reclassifying this host operation as code or calling --before infrastructure to conceal production is refused. Generic production reviewer_release would expose hetz and is rejected. Passing arbitrary CI report bytes to a custom YAML parser would trust forgeable declarations and is rejected. Installing review tooling on EDGE-ALIEN first is a separate bootstrap problem, not a prerequisite to qualified-host review. Central #1455 records EDGE-ALIEN’s missing local reviewer/toolkit and the need for a qualified-host review route. Root now owns its bounded qualified-host review/admission continuation. #933 is runner REST pacing and #335 is broader routing; do not create another capability ticket.

## 7. Locked decisions and ownership

Locked: only u2giants/ansible; only EDGE-ALIEN at the exact endpoint; only below allowlisted objects; independent engine; final-check/security-review; exact head/source/resource/action binding; pinned canonical hosted workflow/runtime and SAME-job native custody; no arbitrary artifact import; no hetz/cloud weakening. Coordinator is the named capability owner until explicitly reassigned. Use existing central issue https://github.com/u2giants/ai-devops/issues/1455; root coordinator owns its scoped qualified-host native review and Windows-only admission continuation. Root records the exact claim before implementation. PopDAM https://github.com/u2giants/popdam3/issues/162 remains the application acceptance card. No duplicate capability issue. The reviewer executes on a GitHub-hosted Ubuntu runtime after supported qualification succeeds: no local EDGE-ALIEN reviewer/toolkit installation is required, avoiding the recorded bootstrap circularity.

## 8. Primary design and qualification requirements

Root selected the fewest-moving-parts route: one GitHub-hosted Ubuntu job runs qualified native independent review, exact preview and bounded Windows application in one unchanged workspace/lifecycle. Ansible already uses Ubuntu and ephemeral Tailscale access; EDGE-ALIEN has no registered self-hosted runner and needs no local reviewer. Report artifacts are informational: the consumer never parses their APPROVE text or imports foreign lifecycle state.

Add action `windows-render-production` as a dedicated typed admission, not a generic infrastructure/production exemption. Central installed policy has one closed target record. Existing generic Ansible production remains forbidden. Extend native lifecycle/action binding prospectively for this new full-source Windows profile: current `--action-profile` support is limited to code-only database rehearsal and must not be relabeled. Extend the established reviewer_approval_summary validator to consume its SAME-job native final-check/security-review report plus exact Windows profile binding. No second report-parser trust path.

Strict manifest: schema/version; repository numeric ID and identity u2giants/ansible; source_head/source_digest; executed dependency closure digest; action profile; hostname EDGE-ALIEN and endpoint100.112.207.98; exact paths; object descriptor; recovery/preview digest; action nonce; installed policy digest; expiry. No secret values. Allowed closure: inventory/windows.ini, playbooks/windows-render-agent.yml, roles/windows_render_agent/**, exact named scripts/windows escrow/recovery scripts, ansible-windows.cfg, requirements-windows.yml and .github/workflows/windows-render-agent.yml. Reject symlinks, extra hosts, arbitrary commands, other playbooks and hetz/cloud objects.

Bound objects: popdam-render local account, Users membership/batch-logon right; render scheduled task and exact recovery task; install/config/recovery roots and explicit credential-file ACLs; password-backed boot/limited identity; explicit escrow/recovery stages. Include dependency collection pins and every invoked script. Preview checkpoints prior task XML AND DACL, explicit file/directory ACLs, prior account/group/right state and executor-loss recovery; active work refuses cutover. Any password change requires its own exact descriptor, not implicit general rotation authority.

Hosted qualification is a PRECONDITION, currently UNPROVEN. Step zero of implementation is a non-production hosted qualification workflow using the canonical pinned toolkit and an in-rotation independent engine chosen by root. Use supported setup/qualification interfaces only: docs/deployment.md's Ubuntu installation contract, bin/setup-opencode-glm.sh if that selected harness requires it, and bin/ai-review-preflight's provider-specific requalify/check/status/usable interfaces. Do not assume `ai-review doctor` qualifies the selected provider: current command only checks Claude/Codex. The qualification job must prove the actual selected runtime, wrapper/profile pins, repository-tool sandbox custody, shell execution and exact lifecycle publication, followed by an isolated tiny fixture review with genuine provider result. Credential injection happens BEFORE review through the established protected GitHub/1Password setup step; wrappers never invoke 1Password. Host application credentials stay unavailable to the reviewer process and sandbox.

Do not blindly run full install.sh on a hosted job: its documented Ubuntu installer also seeds private configuration, memory and periodic tasks. Root must select and test the existing supported narrow runtime/toolkit bootstrap required by the chosen reviewer. If no supported ephemeral-host installation/qualification route exists, report that exact capability gap on #1455 with command/evidence; do not manufacture qualification records or use unsigned artifacts instead. A hosted runtime is admitted only after genuine supported checks pass; no invented claim that existing evidence already qualifies ubuntu-latest.

Within the qualified action job: pin all workflow/actions/toolkit/harness/collection bytes; checkout exact reviewed Ansible source; obtain nonmutating host preview through Tailscale and pinned SSH host key; compute manifest; revoke/delete host credentials from the reviewer process environment; run native independent final-check/security-review prospectively bound to manifest/head/source; re-prove host identity/state after review; consume exact native APPROVE via validator; take exclusive lock and single-use nonce; inject host credentials only into the guarded executor; apply exactly the admitted Windows objects. No source edits, git pull, runtime reinstallation or manifest recomputation to different bytes between review and action. Re-run preaction identity/digest validation immediately before each admitted stage. A source/preview/host change demands fresh review, not an override.

Serialize with dedicated apply-edge-alien concurrency and durable admission/recovery checkpoint. If executor dies, no automatic replay: reconcile actual remote checkpoint and issue a fresh stage-specific recovery authorization. The same-job lifecycle state/report stays on trusted local disk until consumed. Artifact upload afterward helps audit, never authorizes a different job or run attempt.

Fallback, separate proposed work ONLY: if supported hosted qualification genuinely cannot work, root may choose the earlier pinned trusted-producer/GitHub-attestation route. That is a separate security-reviewed implementation, not automatically built here. Reuse shared-db production_apply_review_evidence.py/verify_preview_apply_artifact.py provenance patterns: protected producer executed closure, numeric repository/run/attempt/artifact identities, exact immutable archive digest, verified signer identity, strict bounded archive/envelope and single-use target-bound receipt. Never import foreign records into native lifecycle registry. Root must approve a separate concrete design before that transport can carry authority.

## 9. Ordered implementation and verification

1. Root records exact bounded ownership on #1455 and supplies approved selected in-rotation independent reviewer engine. Build nonmutating hosted qualification fixture using EXISTING supported installer/runtime/preflight mechanisms. Gate: genuine supported setup, qualification, sandbox/tool execution, lifecycle verdict publication and cleanup PASS on actual hosted Ubuntu; otherwise STOP with exact missing capability, no live action policy introduced as substitute.
2. Add config/windows-render-admission.json closed target/profile and tools/windows_render_action.py canonical descriptor validator, reusing review_action_profile patterns without opening its database route. Gate: strict path/target/object/dependency tests pass; generic Ansible production and hetz/cloud actions still refused.
3. Extend bin/ai-review-lifecycle and native review runner's prospective manifest binding for this full-source profile; update reviewer_approval_summary to verify SAME-job native independent review against exact descriptor. Gate: changed manifest, stale source, wrong engine, wrong mode and foreign lifecycle receipts fail. Current database/code-only profile remains unchanged.
4. Extend ai-task-gates only with typed windows-render-production inputs, same-job current native report and installed manifest/profile validation, nonce/lease and stage-specific recovery admission. Gate: no arbitrary report or informational artifact accepted; exact tested profile admits one fixture action only; replay/concurrency refused.
5. Wire Ansible Windows workflow to pinned canonical qualified toolkit/reviewer, preview+manifest, native review and exact guarded executor in SAME job. Root integrates independently reviewed host draft. Gate: nonmutating preview/dummy action rehearsal retains exact head/source/manifest across review and consume; hosted process secret-isolation tests pass; root-reviewed workflow cannot invoke hetz roles or cloud operations.
6. Root ships toolkit policy through existing reviewed canonical installation route and host workflow through Ansible normal checks/PR. Perform fresh exact host-action native review and target preview in qualified job, then consume once. Gate: genuine boot-without-login, normal render, self-update and recovery/escrow acceptance on #162; no unrelated production changes.

Adversarial inputs:

| Input | Hostile case | Required test |
|---|---|---|
| hosted runtime | missing qualification, changed wrapper/runtime/profile | unqualified_hosted_reviewer_refused |
| credential boundary | host key/password visible to reviewer environment/sandbox | reviewer_host_secret_isolation |
| source | new head/dirty tree after review | source_changed_refused |
| target | hetz, extra host, wrong endpoint/hostname | target_substitution_refused |
| closure | changed role/script/collection pin | dependency_changed_refused |
| manifest | substituted preview/object allowlist | manifest_substitution_refused |
| native report | substituted file/hash/path; foreign job registry | report_substitution_refused |
| review identity | provider equals implementer, absent engine, plan mode | nonindependent_review_refused |
| artifacts | caller-supplied APPROVE or foreign lifecycle JSON | informational_artifact_no_authority |
| replay | reused nonce, different run attempt, concurrent apply | replay_and_collision_refused |
| freshness | expiry/changed host state after review | stale_host_preview_refused |
| recovery | absent explicit ACL/task DACL or interrupted forward action | incomplete_recovery_refused |
| policy | generic infrastructure production/hetz/cloud attempted | generic_production_stays_forbidden |

## 10. Required tests

Add tests/test-windows-render-action.py and targeted test-ai-task-gates.sh/native lifecycle cases named above. Add hosted qualification workflow contract tests ensuring no application mutation or installed qualification fake. Maintain test-ai-review-action-profile.sh, test-ai-review-lifecycle.sh and task-gates suites. Offline tests use fake host/provider transport; actual qualification uses one root-authorized isolated genuine provider review, never fake qualification claims. One nonmutating hosted native-review/consume rehearsal proves same-workspace custody. Actual boot/render/self-update completes #162. No transport-verifier or attestation code is required on primary route.

## 11. Constraints and gotchas

Dedicated current-upstream worktrees per repository; no unrelated reviewer-repair edits. Start/check actual task class before reviews/shipping/production. Root makes review/merge/host decisions. GitHub branch/PR/normal checks and canonical toolkit installation mandatory. Reviewer engine differs from implementer. No direct protected-main pushes or direct host source edits. No secrets/raw authenticated traffic/license content in evidence, logs, Git or reviewer attachments. Times shown to people use New York EDT/EST. An uploaded report never grants authority. A qualified provider on one persistent host does not qualify an ephemeral hosted runtime. Fail closed on unsupported hosted runtime custody.

## 12. Access and environment

Planning required only authenticated GitHub CLI, local source and metadata. No vault or host mutation used. Host read-only SSH works with existing protected key; credentials remain vault vibe_coding references consumed via protected environment/stdin, never values in descriptor. Root serializes vault access. Existing app/host worker drafts are not production approval. Hosted reviewer qualification receipt and installed toolkit/runtime pins are intentionally not fabricated: establish them at step 1 before production execution. Report exact missing bootstrap/qualification capability if supported mechanisms cannot run in the hosted runtime.

## 13. Completion, risks and handoff

Done requires recorded root ownership on #1455; reviewed implementation merged; toolkit installed via existing authorized route; offline adversarial suites passed; genuine qualified hosted same-job review/consume rehearsal passed; exact host manifest admitted once; recovery/escrow acceptance and boot/render/self-update verified; #162 updated with receipts; hetz/cloud restrictions independently regression-tested. Highest risks are unqualified hosted reviewer custody, secret inheritance, stale host state, overbroad closure and crash between consumption/mutation; supported qualification, reviewer secret isolation, immediate host reproof, strict allowlist and recovery-fenced retry address them. Hosted qualification failure is a blocker; attested transport remains separate proposed work, not permission to accept uploaded JSON.

This is a finished planning artifact, not implementation delivery. Root's campaign handoff will link this plan if implementation remains unfinished; no parallel standalone handoff is created while root retains ownership. Self-audit: all thirteen sections present; scope/ownership/history/rejected approaches/current limitations and concrete steps included; every trust-boundary case has a named test; no secret/live write or misleading implementation claim.
