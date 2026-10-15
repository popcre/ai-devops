---
issue: none
status: OPEN
owner: codex/az-mail-install-health-order
---

Issue note: this work is tracked by PR #1763; no separate GitHub issue exists.

# HANDOFF — Global az-mail Windows test and rollout

## 0. Business decisions

None pending. Albert already said tenant-wide Graph Explorer consent was intended, and asked for Azure CLI mailbox access and for `az-mail` to be global in `ai-devops`. Do not ask him to repeat those decisions. The shipped command is app-only and restricted to Albert's configured mailbox; it is separate from Graph Explorer's delegated access.

## 1. What this application is

`popcre/ai-devops` distributes shared developer tools. The global `az-mail` command uses an isolated Azure CLI profile and a certificate sourced from the private `vibe_coding` 1Password vault. It allows only read-only Microsoft Graph mail requests for the configured Albert mailbox and does not replace the developer's regular Azure CLI sign-in. Its source and onboarding documentation are in [PR #1763](https://github.com/popcre/ai-devops/pull/1763); the original command was merged in [PR #1757](https://github.com/popcre/ai-devops/pull/1757).

## 2. What we set out to do this session, and why

Complete the existing `az-mail` global rollout by resolving Windows CI's credential-ACL test failure, then merge the hardening PR and verify protected installation plus a real mailbox read on supported developer computers. The capability must remain private to the signed-in Windows user and SYSTEM; do not weaken the production ACL check to make a fixture pass.

## 3. Current state — what is true right now

- Repository: [popcre/ai-devops](https://github.com/popcre/ai-devops), branch `codex/az-mail-install-health-order`.
- PR [#1763](https://github.com/popcre/ai-devops/pull/1763) is open. Current pushed head is [965506a4](https://github.com/popcre/ai-devops/commit/965506a40483983f7b6fc0d3fa1162816f46323f). The latest workflow [38768605489](https://github.com/popcre/ai-devops/actions/runs/38768605489) was in progress at the last status read; its required checks have not completed. The latest completed failure used base [ac023d8f](https://github.com/popcre/ai-devops/commit/ac023d8f74248432ed0aef61db5d6c21ca3ebbc7); requalify the current base before the next review or merge.
- A Muse security review approved this exact head with the focused test command `bash tests/test-az-mail.sh`; the [test file](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh) is linked here. The recorded test output digest is `c5b08b2af10aaa070e581f6beb1f65dcbe6e82d42d4bd8de0b5996cebe1db9a8`.
- Latest workflow [38760173681](https://github.com/popcre/ai-devops/actions/runs/38760173681) finished with failure. Windows section 2 (job `116509873673`) and the aggregate Windows lane failed; the Windows fallback review also completed. Its section 2 ran for 2,016 seconds.
- The failed test output says `Credential tree grants access to an unexpected identity.` from the [Windows ACL checker](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/az-mail-windows-acl.ps1), then the command refused to read mail. The exact path and SID were not printed. The attempted test diagnostic emitted no `fixture ACL:` lines, so it did not expose the needed detail.
- Linux `bash tests/test-az-mail.sh` passed locally and was recorded by the formal review; the [test file](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh) does not reproduce real Windows ACL behavior.
- The branch was clean before this handoff was created; this handoff is the only intended additional file. No merge, installation, or live Graph mailbox read has been verified for this hardening change.

## 4. Everything we tried that did NOT work

- CI run [38741041528](https://github.com/popcre/ai-devops/actions/runs/38741041528) failed in the same Windows section because an unexpected allow identity remained in the temporary credential tree.
- Commit [f9a1da36](https://github.com/popcre/ai-devops/commit/f9a1da36d8c18842fbcbb8d570a4d6425ac8f278) changed the Windows test fixture to use real Windows path conversion and the private-file helper. It still failed with the generic ACL error.
- Commit [ca796d06](https://github.com/popcre/ai-devops/commit/ca796d067777931f29704c29e293e5e146a79fb8) added ACL output using `Write-Host`, but the Actions log contained no `fixture ACL:` lines. The failure therefore remains undiagnosed; do not assume the Windows diagnostic ran successfully.
- The [test fixture](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh) is the place to correct diagnostic capture after the next session resumes.
- The first formal review lacked the test evidence required by `ai-task-gates` for shipment. The review was rerun with `--tests 'bash tests/test-az-mail.sh'`; that exact-head review approved and the shipment gate passed. The test file is [here](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh).
- The first 30-minute PR wait expired while run 38760173681 was still active. A later PR waiter reported the failed Windows section while the fallback review kept the workflow open. A bounded run-completion wait eventually completed; logs then became available, but they contained no `fixture ACL:` diagnostic.

## 5. Root causes and key findings

- Proven: the production [Windows ACL checker](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/az-mail-windows-acl.ps1) rejects at least one Allow entry whose SID is neither the current user nor SYSTEM. This is the intended fail-closed behavior.
- Still UNKNOWN: which tree entry and SID caused the rejection. The test's ACL-preparation helper completed, but the later use-time check still rejected the tree.
- The second test attempt did not produce the added diagnostic in CI output. Replace the diagnostic with captured pipeline output or a protected temporary report and verify that the Actions log contains it before relying on it.
- Keep the production [Windows ACL checker](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/bin/az-mail-windows-acl.ps1) strict. Correct the fixture only after the offending identity and path are evidenced; change the production checker only if evidence shows its policy is wrong.
- Windows section 2 is slow: the latest complete run took 2,016 seconds for its full Bash suite. Keep every wait bounded and use the existing PR as the tracking card.

## 6. Exact next steps

1. Re-read current PR #1763, `origin/main`, and the current branch head through the repository's approved GitHub route. Do not assume the base or approval is still current.
2. Make the test's ACL diagnostics visible to the Actions log using captured output, recording each credential-tree path and allowed SID immediately before the use-time check. Keep secrets out of the output. Update the [Windows test fixture](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh).
3. Run `bash tests/test-az-mail.sh` locally. Then obtain a fresh exact-head Muse security review with `--tests 'bash tests/test-az-mail.sh'`; rerun the task gate before pushing. The [test file](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/tests/test-az-mail.sh) is linked here.
4. Push only the task branch, then run the required bounded CI wait. When the Windows section finishes, inspect run 38760173681's job log (or the new run's corresponding log) and confirm the diagnostic names the unexpected SID and path. Fix the fixture based on that evidence, preserving the production ACL boundary.
5. Repeat focused test, exact-head review with recorded tests, shipment gate, push, and bounded PR wait until required checks pass. Let the protected merge queue merge; verify the resulting main state once.
6. Follow [the protected installation procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md). Revalidate machine state first. On eligible reachable computers, install the reviewed merged commit, verify the install manifest and doctor, then perform a real read-only mail request and save the result. Keep source, installation, and live-read proof distinct.
7. Preserve the unique commits on Windows 916; do not overwrite that checkout. Reassess t16 only through supported access. Networking-only hosts are never toolkit installation targets.

Success means PR #1763 is merged with required checks passing, eligible installations are verified at the merged source, and each claimed live mailbox read has fresh evidence. Anything less remains open.

## 7. Constraints and gotchas in force

- Public repository: never commit certificate material, tokens, private configuration, or mailbox contents.
- Use the [GitHub API wrapper](https://github.com/popcre/ai-devops/blob/main/bin/ai-gh) for GitHub API calls and the [bounded PR waiter](https://github.com/popcre/ai-devops/blob/main/bin/ai-pr-wait) or [bounded run waiter](https://github.com/popcre/ai-devops/blob/main/bin/ai-gh-wait) with an explicit deadline. Do not use `gh run watch` or open polling loops.
- Exact-head independent review is required for reviewer-safety test changes. A new commit invalidates the prior review for shipment. Record focused test evidence through `ai-review --tests`.
- Never push directly to `main`; use PR #1763 and its protected merge queue. Do not merge until required checks pass.
- Machine installation writes outside the repository. Follow [the deployment procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md); never pull in the installed toolkit checkout or edit a live server.
- Networking-only machines `edge-alien`, `edge-runn-envy`, and `edge-runn-xps` are excluded from toolkit installs.
- Do not ask Albert to run commands, click through setup, or provide technical approval. His Graph Explorer intent and mailbox scope are already established.

## 8. Access and environment

- This run is on `edge-dev3` in a clean worktree on `codex/az-mail-install-health-order`; the current branch head and PR are listed in §3.
- The preceding handoff [from 11:47Z](https://github.com/popcre/ai-devops/blob/codex/az-mail-install-health-order/HANDOFF.d/2026-10-15T1147Z-edge-dev3-codex-global-az-mail-rollout-review.md) contains prior machine observations. They are stale and must be freshly checked: edge-dev3's previous install manifest rolled back; Windows 4837 was last seen before `az-mail` profile setup; Windows 916 contains unique commits; t16 lacked SSH, RDP, and WinRM access.
- No real mailbox read from the new global command has been proved on any host. Certificate contents and app credentials remain only in the private 1Password vault.
- The task is tracked by PR #1763. No separate issue exists; the contract uses `issue: none` rather than creating a new tracker during wrap-up.

## 9. Open questions and risks

- Which exact path and SID in the Windows test fixture caused the unexpected Allow ACE? Current evidence does not identify either.
- Why did the fixture's `Write-Host` output not appear in Actions? Verify with an explicit captured stream before another full run.
- Will the current `origin/main` still match the last reviewed base? Recheck before any new exact-head review or merge.
- Installation and live mailbox reads remain unverified. The prior machine observations in §8 are not current proof.
- No owner decision is waiting; the remaining work is technical and should be handled under the repository's review and task gates.

### Self-audit

- All ten sections (§0–§9) are present. §0 states that no owner decision is pending; the user decisions found in §1–§9 are the previously stated Graph Explorer intent, `az-mail` mailbox scope, and global rollout request, all repeated in §0.
- A new developer can continue from §6 without relying on chat context: it names the current PR, exact failing run, prior failed attempts, current review evidence, expected diagnosis, gates, and success conditions.
- Every file and commit reference is a portable GitHub URL. The credential is referenced only by vault location; no secret value or mailbox contents are included.
- Self-audit answers: (1) comprehensive enough — yes, §§0–§9; (2) enough to continue as effectively as this session — yes, §§3–§8; (3) all relevant facts, failures, risks, and gates included — yes, §§2–§9; (4) §0 includes every owner decision and no technical approval — yes, no business choice remains.
