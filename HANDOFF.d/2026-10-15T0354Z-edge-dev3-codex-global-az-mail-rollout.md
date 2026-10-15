---
issue: 1757
status: OPEN
owner: codex/az-mail-install-health-order
---

# HANDOFF — Global az-mail rollout (2026-10-15 03:54 UTC, edge-dev3/Codex)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None. No new business decision is required to continue. Already settled — do NOT re-ask: on 2026-10-14 Albert said tenant-wide Graph Explorer consent was intended; this `az-mail` app remains for the owner's mailbox, with the tenant's Exchange mailbox restriction as the authorization boundary. The next session should ask no questions unless live evidence changes that business scope.

## 1. What this application is

`popcre/ai-devops` is POP Creations' shared developer-toolkit repository. It installs commands on developer computers. `az-mail` is a separate Azure CLI profile that lets Albert read mail through Microsoft Graph without replacing his normal Azure CLI sign-in. Its certificate is read from the `vibe_coding` 1Password vault, and the Azure app is restricted to Albert's mailbox by the tenant's Exchange application access policy. The public toolkit supports Dev-class Ubuntu and Windows computers; networking-only machines are excluded by repository policy.

## 2. What we set out to do this session, and why

Albert needed the approved Graph mailbox access available globally through ai-devops, rather than as a one-computer setup. PR [#1757](https://github.com/popcre/ai-devops/pull/1757) added the `az-mail` option and merged. During rollout, the install health check ran before reviewer requalification and rolled back a valid install; a Windows exact-head review also found unrestricted Azure CLI passthrough, missing use-time ACL verification, and an unpinned PowerShell installer. PR [#1763](https://github.com/popcre/ai-devops/pull/1763) now carries the install-order repair and those three safeguards.

## 3. Current state — what is true right now

- PR #1757 merged to main at [de71d2a](https://github.com/popcre/ai-devops/commit/de71d2ae982c7ea9948854431cdfe599851a7b9a). The private config change merged separately in [private config PR #8](https://github.com/u2giants/ai-devops-private-config/pull/8).
- PR #1763 is open. Its latest pushed source before this handoff is [90a190b](https://github.com/popcre/ai-devops/commit/90a190bc40f6325d45d734d6ca73c1ba687cfd49); adding this handoff makes a new head, so its checks and exact-head review must be refreshed. Its security review approved 90a190b; report at [review artifact](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/.ai/reviews/muse-security-review-20261015T034326-2121478-29562.md). The previous waiter was stopped before this handoff was added; latest observed PR state was OPEN, checks PENDING. Earlier checks on 90a190b had not yet completed.
- The local focused tests passed on 90a190b: [test-az-mail.sh](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh) and [test-windows-muse-code-install.ps1](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-windows-muse-code-install.ps1). They cover read-only mail URL allowlisting, denial before sign-in, Windows ACL-check invocation, and rejecting a changed installer hash.
- edge-dev3's installed checkout advanced to de71d2a during the prior approved attempt, but the protected install manifest still identifies the old 8b73a99 source because the updater rolled back after `ai-devops doctor` ran before reviewer requalification. Muse reviewer health was subsequently restored. Do not call this a completed installation; re-read installed checkout, manifest and doctor state before another update.
- Windows 4837 (`al8960ofc`) has a clean installed checkout at 1dccff8, ancestor of de71d2a, but it has not been updated and has no az-mail local profile yet. A previous review of de71d2a was REJECT; it did not authorize installation. The fixes now in PR #1763 must merge and then receive a fresh review at the selected merged target.
- Windows 916 (`916-alien`) is safely blocked: its installed checkout is on `mimo/1562-deepseek-windows-cygpath` with two unique unmerged commits (`5dc158e8`, `ba6133b8`). Preserve both; do not move it to the release target.
- t16 remains inaccessible for SSH, RDP and WinRM; only Tailscale ping was available. Do not claim all developer computers have the tool.
- The order fix is at [install.sh](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/install.sh#L650). The read-only mailbox allowlist and Windows ACL call are at [bin/az-mail](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/az-mail#L1); recursive Windows ACL checking is at [bin/az-mail-windows-acl.ps1](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/az-mail-windows-acl.ps1). The Meta installer hash verification is at [bin/windows-muse-code-install.ps1](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/windows-muse-code-install.ps1#L24), with its pin in [config/muse-code/windows-installer-sha256](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/config/muse-code/windows-installer-sha256).

## 4. Everything we tried that did NOT work

- edge-dev3's pinned update initially stopped before installation because elevated access required a terminal. The protected 1Password-based terminal path was then used successfully; no password appeared in chat or command output.
- The update then failed its doctor stage because Muse was reported invalid before the install's reviewer-requalification stage ran. Rollback preserved the old manifest but left the checkout at de71d2a, so current checkout and manifest differ. Reordering the stages is in PR #1763; do not manually rewrite the manifest or bypass the install gate.
- The first Windows review rejected de71d2a for arbitrary `az` passthrough, missing use-time NTFS ACL checks, and execution of an unpinned Meta install script. PR #1763 fixes these; never reuse the old rejection or treat it as authorization.
- The earlier PR #1763 head cf1e9c3 had a failing Linux offline shard. That result predates the newer code and focused tests; do not assume it describes the new head. The newer head's hosted checks were still pending when this handoff was written.
- A push-and-cleanup shell call was rejected before execution; nothing was removed. The subsequent push succeeded. No unique work was lost.

## 5. Root causes and key findings

- On a fresh installation, reviewer providers can be temporarily unhealthy until requalified. The health check must run after requalification; both gates remain required.
- The old `az-mail` wrapper signed into the intended service principal but forwarded arbitrary Azure CLI arguments. The new wrapper accepts only GET requests to Microsoft Graph mailbox message/folder routes before login. The mailbox segment is not compared client-side to a configured UPN; containment still depends on the documented Exchange application access policy. The independent reviewer classified this residual as informational, not a blocker.
- Windows setup hardens ACLs, but future ACL relaxation was not detected at command use. The new PowerShell helper rechecks every item under the az-mail profile and rejects unexpected allow identities and reparse points.
- The Windows Muse installer is executed by the full installer when the pinned binary is absent. Its downloaded PowerShell bytes now have a repository hash pin checked before execution, and the installed binary is still checked against its version pin.
- `az-mail` remains a mailbox-scoped app; tenant-wide Graph Explorer consent is a separate delegated-consent goal. Onboarding guidance is at [docs/onboarding-secrets.md](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/docs/onboarding-secrets.md#L100).

## 6. Exact next steps

1. Commit only this handoff file on the existing PR branch and push it. Run a fresh Muse security review against the new exact HEAD and `origin/main`; verify APPROVE names that exact SHA and digest.
2. Run `ai-task-gates check --before pr-wait --reviewer-approval <fresh-report>` and the bounded `bin/ai-pr-wait 1763 --timeout-minutes 60`. If CI fails, diagnose the failing current-head job; if checks pass, let the merge queue merge it and verify PR #1763 is MERGED.
3. Fetch main and choose the exact merged target. For edge-dev3, inspect checkout/manifest/doctor, follow `docs/deployment.md`, create a fresh install candidate from the actual installed checkout, review the exact target, obtain the one-use authorization, then install through `update.sh`. Verify manifest source, doctor, and a live mailbox read; all must pass before calling the Linux rollout complete.
4. For 4837, fetch and confirm its installed checkout is clean and ancestor of the target; create install/review candidates; get exact-head approval; authorize and install using the supported Windows update path. Run machine setup, then verify profile ACLs and a live read of Albert's mailbox.
5. Reassess 916 only after its two unique commits are safely integrated or otherwise preserved by an explicit recovery path. Reassess t16 with supported access. Until each has live proof, report it as not installed; never force the target over unique work or infer reachability from ping.
6. Finish with a fresh main readback, installation receipt/doctor, and live mailbox-read proof for each reachable host. The rollout is complete only for machines with all three proofs.

## 7. Constraints and gotchas in force

- `ai-devops` is public: no secrets, private transcript data or private configuration values in this repository. Only 1Password vault name/location may be mentioned; use the `vibe_coding` vault and protected pipes/files.
- Main is protected. Use a branch and PR; no direct push to main. Exact-head independent security review is required for this reviewer-safety change. Re-review after adding this handoff because the commit changes the head.
- On every GitHub action use `bin/ai-gh`; use bounded `bin/ai-pr-wait` with an explicit timeout. Do not repeat a status probe without a state change.
- Toolkit installation is protected and writes outside the repository. Read [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md); use a reviewed merged target, fresh task declaration/authorization, `update.sh`, and proof. Never pull in the installed checkout.
- Windows networking-only hosts are not toolkit installation targets. Never overwrite or reset the 916 checkout while its unique commits remain.
- `az-mail` can read only GET Graph mail-folder/message routes; the tenant Exchange mailbox restriction remains authoritative. Windows use-time ACL validation is required.

## 8. Access and environment

- Current working repository: public `popcre/ai-devops`, branch `codex/az-mail-install-health-order`; PR #1763 is the active card. The source branch currently includes installer ordering, read-only mail restrictions, Windows ACL validation, and installer hash pinning.
- GitHub API access through repository `bin/ai-gh` worked. Muse exact-head review completed and approved 90a190b; rerun after adding this file.
- edge-dev3 Linux and Windows 4837 are remotely reachable. Windows 916 is reachable but unsafe to advance due to unique commits. t16 was not administratively reachable at last check.
- The mailbox certificate and service-account reference are in the `vibe_coding` 1Password vault. Never copy values into the handoff or terminal transcript. edge-dev3's protected sudo credential was used through the authorized 1Password PTY mechanism and was not exposed.
- No live mailbox read from the newly installed global command has been proved on Windows yet. The previous Linux install stopped before successful health closure; re-prove after the merged repair.

## 9. Open questions and risks

- The remaining uncertainty is machine access and live installation state, not business meaning. The current Exchange policy is documented as the mailbox boundary; if live Graph behavior contradicts it, stop and investigate policy/application configuration before loosening the command allowlist.
- The exact current install-manifest/doctor state on edge-dev3 must be re-read; prior observed state was manifest 8b73a99 versus checkout de71d2a after rollback. This mismatch can affect installation authorization.
- Windows ACL helper behavior has focused mocked invocation tests on Linux; the actual ACL walk must be verified on 4837 when its reviewed update runs.
- Handoff self-audit: (1) Yes — §§1–8 define the product, status and credentials boundary. (2) Yes — §§3–6 preserve exact evidence, failures and continuation gates. (3) Yes — §4 lists failed attempts and causes. (4) Yes — §6 gives ordered steps with explicit proof gates. (5) Yes — §§1, 5, 7 and 8 define identifiers, constraints and access. (6) Yes — all file and commit references are portable GitHub links; local checkout paths are omitted. (7) Yes — line-by-line sweep found no unresolved business decision outside §0; technical approvals, access and installation gates are assigned to the AI session/reviewer, never Albert.
- Final synthesis 1: Yes; see §§1–9 and numbered continuation in §6. 2: Yes; §§3–5 retain working state, evidence and dead ends. 3: Yes; §§3–8 include background, constraints, risks and verifiable actions. 4: Yes; §0 says None, and the §§1–9 sweep found no owner-only business choice; the 2026-10-14 mailbox scope is already settled.
