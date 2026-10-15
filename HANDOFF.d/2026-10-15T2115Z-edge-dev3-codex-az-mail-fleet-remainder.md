---
issue: none
status: BLOCKED
owner: codex/az-mail-fleet-handoff
---

Tracking reason: the existing delivery card is [PR #1763](https://github.com/popcre/ai-devops/pull/1763); its comments retain remaining host-proof checkboxes. No parallel issue was created.

# Global az-mail — installed proof and two blocked computers

## 0. Business decisions only the owner can make

None. No business question or technical approval is being sent to Albert.

Already settled — do not re-ask: the predecessor records Albert's October 14 decision that tenant-wide Graph Explorer consent was intended. The global az-mail command is a separate app-only capability restricted to Albert's configured mailbox. Do not broaden mailbox scope, change Graph Explorer consent, or change Exchange policy as part of machine recovery. Installation, authentication repair, preservation, and reviewer admission are AI-owned technical work.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) installs developer tools on Dev-class Linux and Windows computers. Its [az-mail command](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/bin/az-mail) signs Azure CLI into an isolated certificate-backed profile and permits read-only Microsoft Graph mail requests for the configured mailbox. The normal Azure CLI user sign-in remains separate. The certificate and machine allowlist belong to protected configuration and the `vibe_coding` 1Password vault, never public source.

[Original PR #1757](https://github.com/popcre/ai-devops/pull/1757) shipped the command; [private configuration PR #8](https://github.com/u2giants/ai-devops-private-config/pull/8) supplied the protected configuration. This continuation completed [hardening PR #1763](https://github.com/popcre/ai-devops/pull/1763).

## 2. What this session set out to do

Resume `codex/az-mail-install-health-order`, inspect the newest failing Windows check, explain why its ACL fixture did not log the unexpected identity, retain strict production permission checks, pass focused tests and exact-head review, complete CI and merge, install through the protected procedure, and prove real read-only mailbox access.

The source repair, merge, Linux installation, Windows 4837 installation, and live reads are complete. Windows 916 and t16 remain blocked. This is not an all-computers rollout-complete claim.

## 3. Current state and decisive evidence

### Source and tests — complete

- [PR #1763](https://github.com/popcre/ai-devops/pull/1763) merged October 15 at **4:46 PM EDT**, at [82a4051d5c6c96997f92bac378badf803655e9f2](https://github.com/popcre/ai-devops/commit/82a4051d5c6c96997f92bac378badf803655e9f2). The reviewed PR head was [bd3a7c18a5bff11845aee3b6304aad0c57fb25df](https://github.com/popcre/ai-devops/commit/bd3a7c18a5bff11845aee3b6304aad0c57fb25df). Their file contents are identical; the merged commit has a different parent/history.
- The repair is [a992895c4b6bf7bcb010fdd4fecca74e0c60075e](https://github.com/popcre/ai-devops/commit/a992895c4b6bf7bcb010fdd4fecca74e0c60075e). The [fixture helper](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/tests/test-az-mail.sh#L52-L95) captures permission identities before and after protection and executes before the first mailbox call, and again after the second setup.
- Focused Bash mailbox tests and the PowerShell Windows installer tests passed. The focused mailbox test also passed on a real Windows developer computer. An additional synthetic Windows check proved that the production checker accepts a private tree and rejects added Users access.
- [PR CI run 38792161875](https://github.com/popcre/ai-devops/actions/runs/38792161875) passed required checks. Its [Windows section 2 log](https://github.com/popcre/ai-devops/actions/runs/38792161875/job/116620001851) contains the new diagnostics and passing mailbox assertions. [Merge queue run 38800179492](https://github.com/popcre/ai-devops/actions/runs/38800179492) verified the queued merged version; it reused Windows evidence and ran Linux verification. Do not repeat already passing checks without a new change or concrete concern.
- Muse approved the exact PR head with recorded focused tests. Separate Linux and Windows final reviews approved the exact installation target above. Original host-local report basenames: `muse-final-check-20261015T202141-1188161-31338.md` on Linux and `muse-final-check-20261015T202432-1309-23592.md` on Windows 4837. Reports are private host-local evidence, not published source files; do not invent public report URLs or copy reports to manufacture new authority.

### Linux edge-dev3 — complete

- Before this continuation the clean installed checkout and manifest both attested [bbd32e978c4db33fe7f4e506de05a88838ecd7ad](https://github.com/popcre/ai-devops/commit/bbd32e978c4db33fe7f4e506de05a88838ecd7ad). Older handoffs' checkout/manifest mismatch observations were stale.
- Separate linked installation and review candidates were prepared. The exact target review approved, the native gate issued one-use installation authority, and the target updater installed the merged source through the [protected update procedure](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/docs/deployment.md#update).
- A first attempt stopped at the required GLM user-service stage because the credential launcher did not inherit the desktop user-service environment. The authorization remained pending. After verifying the current user's actual runtime/socket ownership, the retry supplied its user-service environment. It resumed the pending transaction and completed all required stages. The native gate explicitly recorded and verified the Linux installation; the checkout and manifest now both attest the merged target above.
- Required doctor checks passed, the GLM user service is active, and the configured Muse doctor passed. The configured Linux Muse engine remains OpenCode; no engine switch was made. The optional native Muse Code bootstrap rejected an upstream installer that did not provide the repository-pinned version. No pin was weakened, and that optional bootstrap is not claimed complete.
- A pre-existing personal az-mail passthrough launcher shadowed the managed command. Its exact bytes were backed up privately and verified before replacing that entrypoint with a link to the managed installed command. Legacy launcher SHA-256: `c2b847f471714bf70953fcd7373d4344490f80971ec52f54e8040bf602c180a7`. No legacy Azure profile or normal Azure login was deleted.
- A fresh global command read one message identifier from Albert's inbox, using a one-item/select-id request. Only a success flag and count `1` were retained as proof; no mailbox content or identifier was published.

### Windows 4837 / al8960ofc — complete for az-mail

- The fresh pre-install checkout was clean at [e399cee7ca98b901255e116d6e03a57709d232e5](https://github.com/popcre/ai-devops/commit/e399cee7ca98b901255e116d6e03a57709d232e5). Its older launcher receipt was a valid ancestor; the existing protected route accepted that state without a migration bypass.
- Separate linked installation and review candidates, native Windows exact-target review, and one-use authorization preceded the target Windows installer. The protected installer returned `0` and refreshed managed launchers at the merged source above.
- Full machine setup initially failed protected-configuration synchronization: Windows GitHub authentication was unusable. A stored repository PAT returned HTTP 401 and was not rotated or reused. Current working authentication for the same account was transferred through an encrypted pipe into Windows' protected native credential store; the standard Git credential helper was repaired. No secret became an argument, public file, or chat output. The retry synchronized protected configuration successfully.
- Machine setup reached its final completion summary. Its transport retained an idle connection after the setup process had exited; two independent process checks found no setup process. Only the precisely identified owned idle SSH client was closed. The resulting SSH transport status `255` is not a claimed clean script exit code. The protected installer exit `0`, completion footer, installed receipts, live mailbox result, and live ACL result are the actual acceptance evidence. The cause of stream retention was not proved. Future nested native calls should close input explicitly rather than retain inherited input.
- The global Windows command read the real inbox folder successfully. The production recursive ACL checker passed on the real credential tree after that read. The managed launcher attests the exact merged source above. Both hosts' installed az-mail source SHA-256 is `1335f8aaa423945c3f956d53ac561db8cc09e28de5ab4c8ed4dca9ee2982557f`.
- Full setup logged an optional local GLM setup warning about an absent `Response` property. A subsequent correctly attributed `AI_GLM_CALLER=codex` GLM doctor passed all required checks. Do not treat the warning as proof of local scheduled-start acceptance or replace a functioning configured route to hide it. Mailbox proof does not establish optional provider startup or desktop-extension acceptance.

### Remaining machines — not installed or live-proved by this continuation

- **916 / 916-alien:** reachable; clean installed checkout remains on `mimo/1562-deepseek-windows-cygpath` at `5dc158e88a97c4e0133355f067fca6289122974f`, containing that commit plus `ba6133b8` outside the release. On October 15 at **4:42 PM EDT**, a fresh object fetch and ancestry check returned `1` for installed HEAD being an ancestor of the target, and the two commits were the only commits listed on the installed side. No checkout advancement, source edit, reset, or installation occurred. A fresh named-ref lookup did not advertise that branch on the public origin; do not assume a cached tracking name proves a remote backup. Those installed-side commits must be preserved before recovery; semantic incorporation elsewhere has not been established. Intended commit reference after governed publication: [5dc158e8](https://github.com/popcre/ai-devops/commit/5dc158e88a97c4e0133355f067fca6289122974f); publication of that local recovery head is not established here.
- **t16:** the protected machine inventory resolves the device, but SSH timed out and the known RDP/WinRM management ports were unavailable at **4:40 PM EDT**. No authenticated management session or installation was obtained. Whether this is host state, networking, or service configuration is UNKNOWN. Tailscale presence is not management access.

## 4. Failed attempts and dead ends to retain

1. Earlier reviews rejected unrestricted Azure CLI passthrough, missing use-time Windows ACL checks, an unpinned Windows Muse installer, and missing configured-mailbox binding. Those fixes are in the merged release; never revive the old behavior. Earlier passing or rejecting reports authorize no new head.
2. The older Windows failure inherited PowerShell 7's module search path when starting Windows PowerShell. Preserve the existing `PSModulePath` clearing at the ACL call; do not reintroduce module-path inheritance.
3. Earlier fixture changes hardened only a later test phase. `Write-Host` diagnostics were also placed there, so the first failing mailbox call exited before either diagnostic or protection ran. Capturing a different stream alone would not have fixed that ordering error.
4. The newest predecessor failure was [run 38768895216, Windows job 116540464135](https://github.com/popcre/ai-devops/actions/runs/38768895216/job/116540464135). Earlier failed runs recorded in the retired handoffs remain historical evidence, including [38760173681](https://github.com/popcre/ai-devops/actions/runs/38760173681) and [38741041528](https://github.com/popcre/ai-devops/actions/runs/38741041528). These are not current-head failures.
5. Several bounded PR waits expired while checks or the merge queue were active. They were waiter deadlines, not fabricated test failures. The final source merged normally; no required check or merge-group run was cancelled or bypassed.
6. A review begun before incorporating the refreshed main was superseded by a review of the combined head. The stronger reviewer-safety task class was explicitly declared when the gate required it. No acknowledgment or report was used to weaken a class.
7. Linux's first protected attempt failed its required user-service step for missing process environment; use the real user bus, not a replacement service or a disabled required stage. The same pending authorization was legitimately resumed before finalization.
8. The old public sudo note said the credential was stale. Current protected-vault metadata and a non-disclosing authentication check proved a current credential works. Do not reset the login password, use a root container, or ask Albert for technical approval. Use the documented supported credential/terminal procedure.
9. Windows' old GitHub authentication and the stored PAT were not usable. Authentication was repaired rather than replacing the protected-config sync with copied files. The protected configuration sync then passed. The initial full-setup transport inherited input; the idle transport was closed only after completion and absence of a setup process were established.
10. No successful live read, ping, clean status, remote-tracking name, or unrelated source review authorizes overwriting 916's divergent source or claiming t16 is installed.

## 5. Root causes and policy boundaries

The fixture failure was an ordering error. The [fixture now runs before the first mailbox call](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/tests/test-az-mail.sh#L91-L95), emits captured output, and fails if that diagnostic is absent.

CI's actual initial credential root allowed Authenticated Users (`S-1-5-11`), Administrators (`S-1-5-32-544`), Users (`S-1-5-32-545`), and SYSTEM. After protection, each entry allowed only the runner identity NETWORK SERVICE (`S-1-5-20`) and SYSTEM (`S-1-5-18`). Production [ACL enforcement](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/bin/az-mail-windows-acl.ps1) remained strict throughout: unexpected Allow identities and reparse points still refuse access.

The two remaining blockers are independent of that fixture: a divergent installed source on 916 and unavailable management access to t16. Neither is cured by loosening ACLs, mailbox boundaries, review, source ancestry, installation receipts, or machine eligibility.

## 6. Exact next steps and success gates

1. Refresh this existing PR card, current main, protected host inventory, each target's actual source, receipts, dirty state, and access. Route the new session from its own work and task declaration. Do not inherit an old approval or reuse a consumed installation authorization. **Pass:** exact current target and host facts are recorded before any action.
2. For 916, preserve both unique commits and all current work in a verified recoverable backup before considering any source change. Inspect the existing branch/workstream rather than taking ownership of unrelated reviewer changes or opening a duplicate application need. **Pass:** a self-contained verified recovery artifact plus fresh source/dirty-state evidence protects both commits; a cached remote-tracking ref alone does not pass.
3. Identify a supported, independently reviewed recovery/integration route that satisfies the protected installer. Ordinary update cannot fast-forward the observed divergent head. A squash merge containing similar code does not by itself prove the original commit is an ancestor. Do not reset the installed checkout, alter receipts, weaken the gate, or relabel the action to get past it. **Pass:** the actual current gate admits the exact proposed route and inputs; otherwise retain BLOCKED with the missing admission named.
4. For t16, restore supported authenticated management access through existing owned infrastructure and documented mechanisms. Do not infer access from discovery or ping, close an owner's applications, or invent a platform bypass. **Pass:** an authenticated identity/hostname read succeeds on the intended Dev computer.
5. Once either host is genuinely ready, use fresh exact-target review, distinct installation/review candidates, and that host's native one-use installation procedure. Use [deployment guidance](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/docs/deployment.md) and [mailbox onboarding](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/docs/onboarding-secrets.md#azure-cli-mailbox-access). **Pass:** installed source and receipts agree, managed command routing is verified, health checks pass, real credential permissions pass the strict production checker, and a real read-only configured-mailbox request succeeds without publishing contents.
6. Update the two host checkboxes on [PR #1763](https://github.com/popcre/ai-devops/pull/1763), preserving signatures. Complete any newly ready authorized host rather than stopping at one child. **Pass:** each claimed completed host has fresh source, installation, and live proof; retire this handoff only when its remaining obligations are satisfied or carried forward under the successor rule.

## 7. Constraints and gotchas

- Read [AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md), the matching router entry, and current [deployment procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md). Source policies may advance after this snapshot.
- Networking-only hosts remain excluded. No installation was performed on them.
- Main is protected; source changes use an owned current-upstream worktree, PR, required checks, and normal merge queue. Protected changes need their own exact-head AI review; prose-only handoff work does not need a paid review or a discretionary CI wait.
- Never pull or merge manually in the installed checkout. Native authorized installer advancement is a separate operation. No broad staging, force push, reset, secret replay, or deletion of a linked branch is authorized by this note.
- Keep source/synthetic tests, merged source, installed source, live mailbox reads, and optional provider/desktop acceptance distinct. No full-fleet, local GLM autostart, or desktop-extension completion is claimed here.
- Private configuration, certificates, tokens, OAuth material, and mailbox data stay private. Serialize 1Password access; values move through protected pipes/files, never command arguments or output.
- Use the repository GitHub wrapper and explicit-deadline waiters. Clock times in narrative use America/New_York; UTC filename keys are identifiers.

## 8. Access and environment

The current session ran on edge-dev3 as Codex. Public GitHub API access worked, and Windows 4837's private Git access was repaired and proved by synchronization. Discover current addresses, key routes, and host aliases through the protected machine inventory; no private addresses or credential values are copied here. The Windows Git origin's historical personal-namespace redirect is accepted by the existing protected policy and was not renamed.

The certificate and protected service-account material remain in `vibe_coding` and user-only runtime stores. The current Linux sudo credential worked through protected injection and a terminal; user-service environment must be supplied when the credential launcher lacks it. This authorizes no password rotation or privilege bypass.

Linked installation/review worktrees and host-local review evidence were retained for installation receipts. The main implementation branch remains a linked worktree; it was not deleted as housekeeping. No subagents were spawned. The installed source remains the exact pinned release above; a later prose-only handoff merge does not mean the runtime was reinstalled at that newer documentation commit.

## 9. Open questions, risks, and retirement audit

- Owner: the next AI session taking this work. **Blocked:** 916 has no admitted update route from the observed divergent source; the two local commits must remain recoverable. Their remote backup status is not established by a tracking name.
- Owner: the next AI session taking this work. **Blocked:** t16 lacks authenticated management access. Root cause is UNKNOWN; no source or live proof exists for it from this continuation.
- Optional provider/bootstrap and desktop acceptance are outside the completed mailbox claims. Linux's optional native Muse bootstrap pin mismatch and Windows' optional GLM startup warning are retained above; current configured Muse/GLM health checks passed. Do not turn mailbox proof into broader provider acceptance.
- Predecessor handoffs from [first predecessor](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/HANDOFF.d/2026-10-15T0354Z-edge-dev3-codex-global-az-mail-rollout.md), [second predecessor](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/HANDOFF.d/2026-10-15T1147Z-edge-dev3-codex-global-az-mail-rollout-review.md), and [third predecessor](https://github.com/popcre/ai-devops/blob/82a4051d5c6c96997f92bac378badf803655e9f2/HANDOFF.d/2026-10-15T1619Z-edge-dev3-codex-az-mail-ci-closeout.md) are retired under the successor rule. Their source is merged, their next source/install/live phase is now completed on both ready hosts, all outstanding machine obligations are carried here, and their material decisions/dead ends are retained above and in immutable history. These linked timestamps are filename identifiers, not current local activity times.

### Self-audit

1. **Yes — a newcomer can continue:** §§1–3 define the tool, exact merged release, separate host results, proofs, and blockers; §6 gives ordered next actions and observable pass gates.
2. **Yes — this session's relevant knowledge is retained:** §§4–5 retain rejected approaches, the ordering cause, exact CI identities, credential/environment repairs, and transport distinction; §§7–8 retain access, privacy, routing, and spent-authority limits.
3. **Yes — execution details and uncertainty are explicit:** §§3–9 distinguish verified installed/live hosts, uninstalled hosts, unknown access causes, unchanged policies, unverified remote recovery provenance, and optional unaccepted features.
4. **Yes — §0 is complete:** a line-by-line sweep of §§1–9 found no unresolved business-meaning choice. Source recovery, credentials, access, and technical approvals are assigned to the AI session/gates, never Albert. The already-settled mailbox/Graph Explorer distinction is recorded in §0.
