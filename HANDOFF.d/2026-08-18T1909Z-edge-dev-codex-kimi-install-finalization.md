---
issue: 31
status: BLOCKED
owner: codex/kimi-windows-execution-reliability
---

# HANDOFF — Kimi Windows installation finalization (2026-08-18 19:09 UTC, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Do not ask Albert to choose anything. The remaining step is blocked only by concurrent uncommitted work in the canonical checkout. Wait for that workstream to reconcile it, then follow §6 exactly.

Already settled, do not re-ask:

- 2026-08-18: preserve the protected Kimi credential boundary. Never grant sandboxed tasks write access to the Kimi home.
- 2026-08-18: durable detached jobs, structurally read-only reviews, exact saved sessions, and terminal-event proof are the approved design.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for installing and running several AI coding assistants. It is scripts and documentation, not a hosted application. On Windows, the installed `ai-kimi.cmd` launcher points to `C:\repos\ai-devops\bin\ai-kimi`.

## 2. What we set out to do this session, and why

Finish `plan_kimi-windows-execution-reliability.md` after Albert reported that the Kimi account quota had reset. The blocked work was to run the authenticated Windows checks, obtain exact-version independent approval, merge pull request 37, install from the canonical checkout, and close issue 31.

## 3. Current state — what is true right now

- Pull request [#37](https://github.com/u2giants/ai-devops/pull/37) is merged into `origin/main` as merge commit `dea3a30dfb72dcdb532cf45a9929462803de9bba`.
- Final reviewed branch commit is `92f8f8bd75d8ce936e24e0b8be00981bb157772b` on `codex/kimi-windows-execution-reliability`.
- Kimi CLI 0.36.1 passed `AI_KIMI_CALLER=codex bash bin/ai-kimi doctor --live`.
- `AI_KIMI_LIVE=1 bash tests/test-ai-kimi.sh` passed `174 passed, 0 failed`. It includes a real authenticated hostile-write refusal, cancellation/recovery, exact-session continuation, and termination of the actual foreground waiter while the detached worker finishes.
- `tests/test-kimi-windows-execution.ps1` passed.
- Redacted evidence is in `tests/verification/kimi-windows-2026-08-18/README.md`.
- Grok approved the main implementation at commit `51ccc905410dbe1c713af3a6b13bf16b4909079e`. A later Grok review found three live-evidence gaps, all fixed. GLM then approved exact final commit `92f8f8bd75d8ce936e24e0b8be00981bb157772b` against original base `27a1236`, with no unresolved Critical, High, or Medium finding.
- Installation is not done. `C:\Users\ahazan\.local\bin\ai-kimi.cmd` still points to `C:\repos\ai-devops\bin\ai-kimi`, whose committed blob is old (`33f21f2d099ad19a23e0fe7cd47bcf10f8770ffa`). GitHub's merged blob is `526ec66ed7b1880f3b2f457cdff3fc1c41353836`.
- The canonical checkout `C:\repos\ai-devops` is on `main` at `d529337b46a76495b5cf65bc31db05eb25435987` with overlapping modified and untracked files owned by another active shared-db task. It has diverged from `origin/main`; do not pull, merge, overwrite, or install from it until that task reconciles its work.
- Issue [#31](https://github.com/u2giants/ai-devops/issues/31) remains open. Plan STATUS step 8 remains open, correctly.

## 4. Everything we tried that did NOT work

1. The first resumed live suite retained the offline fake `KIMI_CODE_HOME`, so real calls could not save sessions and the hostile-write check could appear green merely because Kimi never ran. Fixed by unsetting the fake home before live calls.
2. The second live run retained the offline 15-second timeout. Healthy Kimi answers took about 30 seconds, causing false failures. Fixed with a bounded 300-second live ceiling.
3. The first hostile-write assertion watched only the source fixture. Reviews now run in a private snapshot, so source-only checking could miss a private-snapshot mutation. Fixed by requiring successful completion, explicit `CANNOT_WRITE`, and the wrapper's private-tree mutation guard.
4. Session continuity could falsely pass when two IDs were blank. Fixed by requiring nonblank IDs plus successful answer content.
5. The first authenticated waiter test killed a surrounding subshell rather than unambiguously killing the waiter. Fixed with `exec bash`, then rerun successfully.
6. Installing from the isolated linked worktree is deliberately refused because installed launchers would point at a disposable directory. Updating the canonical checkout was also unsafe because another task owns overlapping uncommitted files. No workaround was taken.

## 5. Root causes and key findings

- Offline test variables must be explicitly removed before authenticated calls. See the live block in `tests/test-ai-kimi.sh`.
- A green security check must prove the provider ran successfully, not merely that the source file stayed unchanged.
- Background-process tests must make `$!` identify the process being killed. The live waiter and cancellation paths now use `exec bash`.
- The durable worker is independent of the foreground waiter. The authenticated canary proved a killed waiter can be replaced and the result retrieved.
- Windows launchers contain absolute source paths. `bin/install-machine-tools.ps1` refuses linked worktrees by design, so installation must use the durable canonical checkout.

## 6. Exact next steps

1. Confirm the other task has finished reconciling `C:\repos\ai-devops`. Run `git -C C:\repos\ai-devops status --short` and `git -C C:\repos\ai-devops branch --show-current`. Do not continue while unrelated modified/untracked files remain unexplained. You'll know it worked when the owning task confirms its files are committed/pushed or the remaining changes are explicitly safe and non-overlapping.
2. Bring the canonical checkout safely to current `origin/main` without discarding work. Fetch first, reconcile any local commits through the normal GitHub path, and never use reset-hard or checkout-overwrite. You'll know it worked when `git -C C:\repos\ai-devops rev-parse HEAD` is an ancestor-equivalent current main and `git -C C:\repos\ai-devops rev-parse HEAD:bin/ai-kimi` equals `526ec66ed7b1880f3b2f457cdff3fc1c41353836`.
3. Run the normal Windows setup from the canonical checkout: `pwsh -ExecutionPolicy Bypass -File C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops`. You'll know it worked when setup finishes without error and `C:\Users\ahazan\.local\bin\ai-kimi.cmd` still points to the canonical checkout.
4. From `C:\repos\ai-devops`, run `$env:AI_KIMI_CALLER='codex'; ai-kimi doctor --live`. You'll know it worked when preflight, authentication, and live probe all report PASS/OK on Kimi 0.36.1.
5. Verify source identity: compare `git rev-parse HEAD:bin/ai-kimi`, `git rev-parse origin/main:bin/ai-kimi`, and the source used by the installed launcher. You'll know it worked when all refer to blob `526ec66ed7b1880f3b2f457cdff3fc1c41353836`.
6. Update plan STATUS step 8 to complete with the merged SHA, installed blob, and live result. Commit and push that documentation change through the normal main-only policy. Close issue 31 only after the pushed plan update is on `origin/main`. You'll know it worked when issue 31 is closed and GitHub main contains the completion evidence.
7. Apply the successor rule: delete this handoff and `HANDOFF.d/2026-08-17T0017Z-al8960ofc-codex-kimi-windows-execution-plan.md` in the same completion commit, after confirming all their remaining obligations are recorded in the completed plan. You'll know it worked when neither open handoff remains on `origin/main` and Git history preserves both.

## 7. Constraints and gotchas in force

- Never weaken Kimi-home permissions or copy OAuth material into a repository.
- Never run Kimi directly. Use `ai-kimi` with `AI_KIMI_CALLER=codex`.
- Never install durable launchers from a linked worktree.
- Preserve the other task's dirty canonical-checkout work. No reset-hard, checkout-overwrite, broad staging, or forced reconciliation.
- Do not close issue 31 or mark plan step 8 complete before canonical installation and the installed live check pass.
- Kimi exposes no returned model, tokens, or cost. Do not invent them.

## 8. Access and environment

- GitHub CLI is authenticated for `u2giants/ai-devops`.
- Kimi OAuth is valid in the protected default Kimi home; `doctor --live` passed on Kimi 0.36.1.
- GLM and Grok review wrappers are authenticated. Grok review cost accumulated before the final GLM approval; Kimi and GLM do not report money.
- Secrets remain only in their normal protected locations and the `vibe_coding` 1Password vault. No secret value was read or recorded.
- Implementation worktree: `C:\repos\ai-devops-kimi-reliability`. Canonical installed-source checkout: `C:\repos\ai-devops`.

## 9. Open questions and risks

- No product or owner decision is open.
- Timing risk: another active task must finish before the canonical checkout can safely advance. Do not guess ownership from filenames alone.
- The independent packet noted that unrelated `codex_chats` deletion content can enter review packets. That is outside issue 31 and was not changed here; it is an informational packet-hygiene risk, not a blocker to Kimi installation.

## Self-audit

1. Yes. Sections 1–3 establish the product, purpose, exact commits, tests, and blocker; §6 gives copy-ready continuation steps.
2. Yes. Sections 4–5 preserve every failed attempt and the non-obvious process, timeout, snapshot, and installation findings.
3. Yes. Sections 2–9 cover the intended outcome, current state, failures, decisions, constraints, access, risks, exact commands, and verification evidence.
4. Yes. A line-by-line sweep of §§1–9 found no decision requiring Albert. Section 0 states that plainly and records settled decisions that must not be reopened.
