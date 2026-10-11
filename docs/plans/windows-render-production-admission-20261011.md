# Windows render production admission and trusted reviewer transport

Status: PLAN ONLY; no policy change, admission, credential operation or production action is authorized by this document. Snapshot October 11, 2026, 4:04 PM EDT. Source baseline: ai-devops origin/main 4eb599475d78f36eedab3975529a09f4f5cfd320. Coordinator owns security decisions and landing; implementation is not started.

## 1. Ultimate goal

POP's Windows artwork renderer must start before anyone signs in, while retaining rendering, self-update and recovery. A technical reviewer must be able to authorize that one bounded Windows installation through the canonical host workflow without granting access to the production server or other cloud resources. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. Application and repositories

PopDAM stores and previews licensed artwork; its Windows render agent runs on EDGE-ALIEN. App source belongs to u2giants/popdam3; durable host settings belong to u2giants/ansible; shared admission belongs to u2giants/ai-devops. GitHub owner aliases must be resolved against authenticated repository identity, not guessed. Canonical target is EDGE-ALIEN, existing endpoint 100.112.207.98; SSH hostname proof is required immediately before action. Only a dedicated Windows inventory/playbook/role is eligible. Hetz, NAS, Supabase and cloud infrastructure are excluded.

## 3. Trigger and reproduction

PopDAM #162 lacks current boot-without-login proof. Its reviewed host draft cannot run: central task-gates.json maps Ansible roles/playbooks/inventory to protected infrastructure and forbids production; ai-task-gates' protected-forbidden branch refuses reviewer overrides. The workflow also needs review evidence generated on a qualified reviewer host, while the installed lifecycle validator accepts only its own local registered report. A downloaded Markdown report and regular-expression APPROVE extraction are not authorization.

## 4. Scope

Implement one typed Windows render action and authentic prospective transport of its independent review. Include replay protection, preview binding and exact-object recovery requirements. NOT in this plan: broad infrastructure release; removing protected production restrictions; Windows runner enrollment; other host provisioning; model changes; any database mutation; NAS/password rotation; PopDAM code changes; fake render jobs; unconditional reboot; installer execution before independent approval. Existing PopDAM #162 remains the application card.

## 5. Current code and reuse

* bin/ai-task-gates reviewer_approval_summary validates completed/nonstale independent lifecycle APPROVE against repository key, head, source digest, exact canonical report path/hash; live actions require final-check or security-review. Preserve it for all existing callers.
* config/task-gates.json reviewer_release contains only database/private-tooling. Ansible infrastructure production remains forbidden.
* bin/ai-review-lifecycle supports identity/begin/finish/fail/status, not authentic crossrunner artifact import. Never create local native lifecycle records retrospectively from downloaded JSON.
* tools/review_action_profile.py and config/review-action-profiles.json provide an installed bounded manifest/action profile, canonical descriptor digest, prospective binding and preaction revalidation for one isolated database rehearsal. Reuse its pattern, not its database allowance.
* Shared-db scripts/production_apply_review_evidence.py verifies run repository/path/attempt, unique artifact identity, exact SHA256 archive digest and bounded archive content. scripts/verify_preview_apply_artifact.py demonstrates strict archive/allowlist binding. production_business_risk_gate.py's executed producer closure pins are the reference for rejecting changed producer code. These remain owned by shared-db: implement a small ai-devops verifier using their contracts, do not copy an entire second migration engine or edit shared-db.
* bin/runner-github-admission.ps1 is paced runner REST transport, not production reviewer authorization. It cannot authorize this action.

## 6. History and rejected approaches

Generic --before production plus a review cannot override protected infrastructure. Local repository gates cannot weaken central policy. Reclassifying this host operation as code or calling --before infrastructure to conceal production is refused. Generic production reviewer_release would expose hetz and is rejected. Passing arbitrary CI report bytes to a custom YAML parser would trust forgeable declarations and is rejected. Installing review tooling on EDGE-ALIEN first is a separate bootstrap problem, not a prerequisite to qualified-host review. Central #1455 records EDGE-ALIEN’s missing local reviewer/toolkit and the need for a qualified-host review route. Root now owns its bounded transport/admission continuation. #933 is runner REST pacing and #335 is broader routing; do not create another capability ticket.

## 7. Locked decisions and ownership

Locked: only u2giants/ansible; only EDGE-ALIEN at the exact endpoint; only below allowlisted objects; independent engine; final-check/security-review; exact head/source/resource/action binding; immutable trusted producer; no arbitrary artifact import; no hetz/cloud weakening. Coordinator is the named capability owner until explicitly reassigned. Use existing central issue https://github.com/u2giants/ai-devops/issues/1455; root coordinator owns its scoped qualified-host immutable review transport and Windows-only admission continuation. Root records the exact claim before implementation. PopDAM https://github.com/u2giants/popdam3/issues/162 remains the application acceptance card. No duplicate capability issue. The qualified reviewer executes on an already supported host: no local EDGE-ALIEN reviewer/toolkit installation is required to produce evidence, avoiding the recorded bootstrap circularity.

## 8. Design and trust model

Add action `windows-render-production` as a dedicated typed admission, not a generic infrastructure/production exemption. Central installed policy has one closed target record. Admission requires an exact current source manifest, verified transported reviewer evidence, a fresh nonmutating host preview and an exclusive action lease. The generic production action stays forbidden.

The profile descriptor has a strict field set: schema/version, repository identity and numeric repository ID, source_head/source_digest, source dependency manifest digest, action_profile, target hostname/endpoint, inventory/playbook/role paths, bounded object descriptor, recovery/preview digest, review_nonce, producer policy digest, expiry. No secret values. Paths: inventory/windows.ini; playbooks/windows-render-agent.yml; roles/windows_render_agent/**; scripts/windows/** only exact named escrow/recovery scripts; ansible-windows.cfg and requirements-windows.yml; .github/workflows/windows-render-agent.yml. Reject symlink escapes, other playbooks, extra hosts, arbitrary scripts/commands and descriptors containing hetz/cloud targets.

Object descriptor covers only local account popdam-render, its Users membership and batch logon right, task “PopDAM Windows Render Agent”, explicitly named recovery task, install/config/recovery roots, explicit credential file ACLs and password-backed boot/limited identity. Hash complete reviewed executable closure, including dependency collection pins and invoked scripts. The action never permits changing existing credentials or privilege grants beyond this descriptor. Preview and recovery must checkpoint prior task XML AND security descriptor, explicit file/directory ACLs, account/group/right state, stopped/running state and executor-loss recovery. Existing active work refuses cutover. Account/vault escrow is a separate explicitly described step with no secret-bearing public artifact.

Producer is a new fixed ai-devops workflow `.github/workflows/windows-render-review-evidence.yml` on protected main, invoked for an exact Ansible head. Policy pins its immutable commit and full executed closure digest, allowed event and qualified runner labels. Review service configuration/engine is pinned and independently approved. A change to producer/policy requires its own reviewed bootstrap; producer cannot self-admit new bytes. Credentials only enter the established protected reviewer boundary.

Producer prospectively starts native lifecycle review, records actual independent provider/implementer and source identity, validates final-check/security-review completion through existing native verifier, and publishes only sanitized report + strict evidence JSON. It produces a GitHub artifact attestation for the archive digest. Consumer queries authenticated GitHub APIs via ai-gh; verifies numeric producer repo/run/attempt/artifact identity, successful job, protected-main producer commit, event, artifact immutability/digest, expiry and exact attested signer workflow identity. The ZIP is bounded to 8 files/1 MiB with exact names, no paths/symlinks/duplicates; report hash and strict schema must match attestation-bound envelope. GitHub attestation verification is primary-source proven during implementation, with pinned CLI/actions; no guessed claims or text-based verification.

Envelope additionally binds provider, implementer, native run ID, reviewed repository numeric ID/head/source digest, descriptor+preview digests, nonce, verdict and expiry. It is evidence of a validated producer, not a foreign native state import. Consumer stores a separate `transported-review/v1` receipt, including provenance digest, without touching local native review records. Receipt cannot authorize any other action. Admission consumes a nonce under an exclusive durable lock and binds consumer repo/run/attempt, exact manifest digest, target and action. Retry after interruption requires recovery reconciliation and fresh stage-specific authorization; replay cannot silently resume the forward mutation.

## 9. Ordered implementation and verification

1. Record the root-owned bounded claim on existing central #1455. Author config/windows-render-admission.json closed target/profile and tests for exact allowlist, leaving generic production forbidden. Gate: current hetz/cloud refusal tests still pass and no CLI can yet admit Windows mutation.
2. Add tools/windows_render_action.py descriptor canonicalization/profile verification, sharing reviewed helpers where practical with review_action_profile.py. Gate: strict-field/target/path/object/dependency-closure tests pass; changed inventory content or hostname fails.
3. Add prospective producer workflow and tools/windows_render_review_evidence.py publisher; use lifecycle-native verification, exact protected producer pin and pinned attestation support. Gate: offline workflow/provenance fixtures prove changed producer/dependency refusal; independent security review approves exact producer before bootstrap/installation. No production execution in this phase.
4. Add bin/ai-review-lifecycle command `verify-transported-windows-review` backed by that verifier, or a dedicated sibling if preserving lifecycle isolation is simpler. Either way do not add generic import. Gate: authentic fixture accepted into separate receipt only; native registry untouched; substitutions refused.
5. Extend bin/ai-task-gates only for typed windows-render-production and its target-manifest/transport receipt inputs. Revalidate source/preview/installed policy at admission, reserve exclusive action lease and consume nonce. Gate: replay/stale/wrong-target/wrong-engine tests pass, generic --before production remains forbidden for Ansible, tool returns no authority for caller-supplied receipt JSON.
6. Wire Ansible Windows workflow to installed pinned verifier, trusted receipt and exact reviewed manifest. Root owns integration: current host draft is separately reviewed; provide descriptor bytes and hashes, no raw secret/report regex. Gate: nonmutating consumer rehearsal passes with real trusted producer artifact; changed target or workflow refuses before credentials/mutation.
7. Root ships/installs toolkit through its existing reviewed installation route, then final exact host-action review and preview, and only then Windows host action. Gate: manifest/lifecycle/attestation/lease receipts match actual install; boot-without-login and original render/self-update functionality are proven on #162; no unrelated host changes.

Adversarial inputs:

| Input | Hostile case | Required test |
|---|---|---|
| source | new head/dirty tree after review | source_changed_refused |
| target | hetz, extra host, wrong endpoint/hostname | target_substitution_refused |
| closure | changed role/script/collection pin | dependency_changed_refused |
| producer | fork, PR workflow, modified executed closure | untrusted_producer_refused |
| run | wrong repo/run attempt/job/event, failed job | run_provenance_refused |
| archive | digest mismatch, duplicate member, symlink, traversal, oversized | archive_hostility_refused |
| report | substituted report, missing actual verdict, wrong source digest | report_substitution_refused |
| review identity | provider equals implementer, missing engine, plan-only mode | nonindependent_review_refused |
| envelope | unknown fields, unsigned claims, attestation wrong signer | envelope_forgery_refused |
| replay | reused nonce, foreign consumer run/attempt, concurrent apply | replay_and_collision_refused |
| freshness | expiry/changed preview/changed host state | stale_host_preview_refused |
| recovery | missing prior explicit ACL/task DACL or unreconciled interrupted action | incomplete_recovery_refused |

## 10. Required tests

Add tests/test-windows-render-action.py, tests/test-windows-render-review-evidence.py and targeted tests/test-ai-task-gates.sh cases named above. Extend lifecycle tests to demonstrate transported records cannot overwrite/import native review state. Maintain existing test-ai-review-action-profile.sh, test-ai-review-lifecycle.sh and task-gates suite. Tests are deterministic fake-GitHub/fake-host transport; no paid provider or credential access. One later root-authorized real producer/consumer nonmutating rehearsal proves GitHub provenance; a real boot/render receipt completes application acceptance.

## 11. Constraints and gotchas

Dedicated current-upstream worktrees per repository; no unrelated reviewer-repair edits. Start/check actual task class before reviews/shipping/production. Root makes review/merge/host decisions. GitHub branch/PR/normal checks and canonical toolkit installation mandatory. Reviewer engine differs from implementer. No direct protected-main pushes or direct host source edits. No secrets/raw authenticated traffic/license content in evidence, logs, Git or reviewer attachments. Times shown to people use New York EDT/EST. A signed report alone does not prove producer custody; SHA equality alone does not prove origin. Fail closed on unsupported attestation/runtime custody.

## 12. Access and environment

Planning required only authenticated GitHub CLI, local source and metadata. No vault or host mutation used. Host read-only SSH works with existing protected key; credentials remain vault vibe_coding references consumed via protected environment/stdin, never values in descriptor. Root serializes vault access. Existing app/host worker drafts are not production approval. Pinned producer commit/digest and claim receipt are intentionally not fabricated: coordinator must establish them at steps 1/3 before action can be implemented/admitted. No fallback producer allowed when unavailable.

## 13. Completion, risks and handoff

Done requires recorded root ownership on #1455; reviewed implementation merged; toolkit installed via existing authorized route; offline adversarial suites passed; immutable genuine producer/consumer rehearsal passed; exact host manifest admitted once; recovery/escrow acceptance and boot/render/self-update verified; #162 updated with receipts; hetz/cloud restrictions independently regression-tested. Highest risks are authentic-but-compromised producer, stale host state, overbroad dependency closure and crash between consumption/mutation; pin producer authority, reprove host immediately, strict allowlist, exclusive lease and recovery-fenced retry address them. Attestation support/runtime custody failure is a blocker, not permission to use uploaded JSON.

This is a finished planning artifact, not implementation delivery. Root's campaign handoff will link this plan if implementation remains unfinished; no parallel standalone handoff is created while root retains ownership. Self-audit: all thirteen sections present; scope/ownership/history/rejected approaches/current limitations and concrete steps included; every trust-boundary case has a named test; no secret/live write or misleading implementation claim.
