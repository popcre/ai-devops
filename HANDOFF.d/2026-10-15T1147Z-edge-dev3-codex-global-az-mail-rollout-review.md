---
issue: 1757
status: OPEN
owner: codex/az-mail-install-health-order
---

# HANDOFF — Global az-mail rollout review and fleet completion

## 0. Business decisions

None are pending. Albert already stated that tenant-wide Graph Explorer consent was intended. The `az-mail` command is a separate app-only path for Albert's mailbox; it is not the same permission as delegated Graph Explorer access. The tenant's Exchange application restriction remains authoritative. Do not ask Albert to repeat these choices.

## 1. Product and goal

`popcre/ai-devops` installs shared developer tools. The `az-mail` command uses its own Azure CLI profile and certificate so mailbox reads do not replace the developer's normal Azure CLI sign-in. The certificate is read from the `vibe_coding` 1Password vault. The intended outcome is a merged, installed, live-proven mailbox-reading option on each eligible developer computer. Networking-only machines are excluded by repository policy.

## 2. Current source and review state

- PR [#1757](https://github.com/popcre/ai-devops/pull/1757) added the global `az-mail` option and merged at [de71d2a](https://github.com/popcre/ai-devops/commit/de71d2ae982c7ea9948854431cdfe599851a7b9a). Private config PR [#8](https://github.com/u2giants/ai-devops-private-config/pull/8) also merged.
- PR [#1763](https://github.com/popcre/ai-devops/pull/1763) is open. Its current remote head is `7cd1b8602472f5815b5936611f6b2bb664e60c0a`; its base moved to `ac023d8f74248432ed0aef61db5d6c21ca3ebbc7`.
- The local branch includes current `origin/main` plus task commits and is at `6d822bd0547e2f12bec4ec49aa1137a37e6405f7`; this exact head has not yet been pushed. The final independent Muse review approved that exact head against base `ac023d8f74248432ed0aef61db5d6c21ca3ebbc7`, digest `2be40a52401b5a6caf97fcfa1d931b33fb7487d3f62102edaf37f1050968e317`, with no remaining findings. Muse session: `az-mail-global-rollout-20261015`; report basename: `muse-az-mail-global-rollout-20261015-20261015T114631Z-3328930-7107.md`.
- Focused `bash tests/test-az-mail.sh`, `pwsh -NoProfile -File tests/test-windows-muse-code-install.ps1`, and `git diff --check` pass on `6d822bd`. No hosted CI has run on this head yet.
- Recent changes repair the install order, remove arbitrary Azure CLI passthrough, recheck Windows ACLs at use, pin the downloaded Windows installer, fix Windows PowerShell module-path inheritance, compare every request's mailbox with the provisioned UPN before sign-in, and allow safe list/single-message paths. Message and folder IDs use the same constrained characters; traversal and cross-mailbox requests fail before `az` runs. README and onboarding now state this is Albert's mailbox.

## 3. Rejections and repairs

- Initial Windows review of `de71d2a` rejected arbitrary `az` passthrough, missing use-time ACL checks, and an unpinned PowerShell installer. PR #1763 fixed all three.
- A Windows CI run inherited PowerShell 7's incompatible `PSModulePath`, preventing Windows PowerShell from loading `Get-Acl`. The wrapper now clears that inherited variable; the focused Windows tests pass.
- Review at `7cd1b860` rejected stale-base changes that main had already corrected and identified missing client-side mailbox binding. The branch merged latest main, restoring main's unrelated safeguards, then added a configured-UPN comparison and regression test.
- Review at `81c41cb` found outdated README wording, mailbox substitution instructions, and no individual-message route. Documentation was corrected and single-message reads were added.
- Review at `f80afbb` suggested rejecting all-dot message IDs and accepting `=`-padded folder IDs. The current regex rejects dot and percent in all ID slots, allows `=` in folder/message IDs, and tests both cases. The current exact-head review approved with no remaining findings.

## 4. Last known machine state

- edge-dev3's previous update attempt advanced the checkout to `de71d2a` but rolled back the protected install manifest to `8b73a99` because doctor ran before reviewer requalification. Never call this installed. Re-read checkout, manifest, doctor, and reviewer health before a fresh update.
- Windows 4837 (`al8960ofc`) was last observed clean at installed head `1dccff8`, an ancestor of `de71d2a`; it had no local `az-mail` profile then. Its exact state must be re-read before updating.
- Windows 916 (`916-alien`) has two unique commits on `mimo/1562-deepseek-windows-cygpath` (`5dc158e88a97c4e0133355f067fca6289122974f`, `ba6133b8`). Preserve them; do not advance or reset that checkout without a verified recovery route.
- t16 was last observed inaccessible through SSH, RDP, and WinRM; Tailscale ping alone is not access proof.
- No live mailbox read from the newly installed global command has been proved on any host. Installation, health, and live mailbox proof remain distinct.

## 5. Exact continuation

1. Run `ai-task-gates check --before shipment --reviewer-approval <Muse report>` for the exact approved head. Push only task-owned commits to PR #1763 using the configured GitHub route; do not push to main.
2. Refresh PR state once after the push through `bin/ai-gh`. Run `ai-task-gates check --before pr-wait --reviewer-approval <Muse report>`, then `bin/ai-pr-wait 1763 --timeout-minutes 60`. Surface failed checks; if green, let the merge queue merge and verify the final main commit.
3. Follow [`docs/deployment.md`](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) for protected installs. On edge-dev3, inspect current checkout, manifest, doctor, and reviewer health before creating a candidate at the reviewed merged target. Review that exact target, meet the task gate, use the supported updater, and verify manifest, doctor, and a live mailbox read.
4. Re-read Windows 4837 state and perform the corresponding reviewed update and machine setup; verify ACLs and a live read. Do not reuse prior review authority for the merged target.
5. Preserve 916's unique commits while determining a safe route; reassess t16 only with supported access. Mark each machine complete only after source, installation, and live-read evidence.

## 6. Guardrails

- The repository is public; never commit secrets, private config, or transcript data. Keep 1Password values in protected pipes/files only.
- Use `bin/ai-gh` for GitHub API calls and bounded `bin/ai-pr-wait` with explicit timeout. Do not repeat probes without a state change.
- Exact-head independent review is required for this reviewer-safety change. Any source movement invalidates that review for the new head.
- Toolkit install writes outside the repository. Never pull in `/worksp/ai-devops`; use the reviewed install flow and preserve machine-local state.
- Networking-only hosts are not toolkit targets. Never overwrite the 916 unique commits.

## 7. Verification and risks

The exact source review and focused local tests are complete for `6d822bd`; hosted CI, merge, installation, and live Graph reads are still open. If CI exposes a new defect, fix it on the PR branch, rerun focused checks, and obtain a fresh exact-head review before shipment. The configured mailbox string is public by design; the certificate and app credentials remain private.

## 8. Access and ownership

The active owner is branch `codex/az-mail-install-health-order`; PR #1763 is the delivery card. edge-dev3 and 4837 were previously reachable, 916 is reachable but unsafe to advance, and t16 lacked administrative connectivity. Revalidate live access before acting. Do not ask Albert to run commands or perform machine setup.

## 9. Self-audit

Business decisions: none pending (§0). Scope, current reviewed source, rejected attempts, machine facts, safety boundaries, and ordered proof gates are in §§1–8. A successor can begin at step 1 of §5, without relying on chat context. Completion requires merged source and per-machine installation plus live-read proof; no source-only or CI-only result closes the fleet rollout.
