---
issue: 31
status: OPEN
owner: codex/issue-31-kimi-windows-plan
---

# HANDOFF: implement reliable Kimi execution on Windows

Implementation plan: [`../plan_kimi-windows-execution-reliability.md`](../plan_kimi-windows-execution-reliability.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. The current plan needs no decision from Albert. The incoming session must implement the secure main-task routing and durable worker without asking Albert to alter Windows permissions.

If evidence shows that the goal is impossible without a privileged local broker or broader access to Kimi OAuth credentials, stop and ask Albert. Recommendation: preserve the credential boundary and accept main-task-only provider execution rather than building a broker.

Already settled on 2026-08-17: do not treat the Kimi startup failures as evidence that Kimi K3 does poor work; do not grant restricted tasks broader access to `C:\Users\ahazan2\.kimi-code`.

## 1. What this application is

`u2giants/ai-devops` is Albert's public multi-model workflow toolkit. `bin/ai-kimi` is its only supported headless Kimi launcher. It creates persistent read-only review sessions and isolated implementation sessions for Claude and Codex. The affected environment is Windows 11 host `al8960ofc`; installed Kimi was version 0.32.0 when this plan was written.

## 2. What we set out to do this session, and why

The request was to write a zero-context implementation plan that permanently fixes unreliable Kimi execution. Recent `shared-db` reviews failed because delegated tasks could not write Kimi's session directory, wrapper-state relocation did not move Kimi's own files, and synchronous callers disappeared before results were finalized.

The business goal is reliable reviews without exposing credentials: credentialed Kimi runs happen from the Full Access main task, survive the initiating caller, report useful progress, and fail quickly when the current task cannot securely run them.

## 3. Current state — what is true right now

- Planning issue [#31](https://github.com/u2giants/ai-devops/issues/31) is open.
- Complete plan exists at [`plan_kimi-windows-execution-reliability.md`](../plan_kimi-windows-execution-reliability.md).
- Every STATUS row is open. No implementation has started.
- Plan base is `origin/main` commit `e075b309afb80fdd19469631c034ffca4dda767e`.
- Planning branch is `codex/issue-31-kimi-windows-plan` in `C:\repos\ai-devops-worktrees\issue-31-kimi-windows-plan`.
- Current wrapper still waits up to 900 seconds and owns finalization synchronously.
- Current official Kimi docs support `KIMI_CODE_HOME`; the wrapper and skill still contain older wording saying Kimi has no data-directory override.
- Windows ACL evidence showed `CodexSandboxUsers` has Read and Execute on the default Kimi home, while the main user has Full Control. Kimi needs session-directory writes.
- The primary `C:\repos\ai-devops` checkout contains unrelated untracked files. Do not touch or stage them.
- Code is not deployed because this session writes the plan only. The plan/handoff registration PR must be merged before implementation begins.

## 4. Everything we tried that did NOT work

1. Moving only `AI_KIMI_STATE_DIR` into a workspace relocated wrapper state but not Kimi sessions or credentials.
2. Delegated tasks retried Kimi from restricted contexts and waited to the 900-second ceiling. Kimi failed before model execution with an `EPERM` session-directory error.
3. Long runs were launched from foreground shells subject to short tool boundaries. Some Kimi children continued after the caller ended, but no wrapper remained to save the verdict.
4. Process liveness was treated as progress even when no authenticated Kimi child existed.
5. Restarting reviewers consumed time without fixing the execution boundary.
6. Broadening the Kimi-home ACL was considered and rejected because credentials and sessions share the same Kimi data root.

## 5. Root causes and key findings

- Full Access on the main Codex task did not automatically apply to delegated collaboration tasks.
- `AI_KIMI_STATE_DIR` and `KIMI_CODE_HOME` govern different state.
- Kimi's official `KIMI_CODE_HOME` variable moves OAuth credentials and sessions together, so a sandbox-writable Kimi home would also be credential-bearing.
- Windows denied session creation because the restricted group lacked write access. This was a valid security boundary.
- Synchronous wrapper ownership coupled job completion to the initiating shell.
- Healthy quiet work and failed startup were not represented as different durable phases.
- Kimi's completed work remains high quality. Permission/auth/session failures are wrapper and execution failures, not model verdicts.

## 6. Exact next steps

1. Merge the plan-registration PR. You'll know it worked when `origin/main` contains this file, the plan, and their router links.
2. Start a fresh implementation session at STATUS row 1 and re-read §§6–8 of the plan. You'll know it worked when the session quotes the current `main` SHA and first open row.
3. Add failing Windows and Bash fixtures from plan §9.1 before changing behavior. You'll know it worked when current defects reproduce with named failure classes.
4. Implement explicit `KIMI_CODE_HOME` and execution-context preflight per §9.2. You'll know it worked when the former EPERM condition refuses in under five seconds and launches no provider call.
5. Implement the detached durable job lifecycle in §§9.3–9.5. You'll know it worked when killing the waiter does not kill or lose the review and later `result` returns exactly one finalized verdict.
6. Update caller routing and the shared Kimi skill per §9.6. You'll know it worked when a restricted task produces an immediate hand-back request and the main task completes the same job.
7. Run all live canaries in §9.7. You'll know it worked when redacted evidence proves read-only behavior, waiter survival, fast denial, cancellation, and recovery.
8. Update the comparison and permanent docs per §9.8. You'll know it worked when the model-quality and transport-reliability conclusions are explicitly separate.
9. Obtain exact-head independent review, merge, install, and re-prove the installed wrapper. You'll know it worked when issue #31 closes with merged installed evidence and this plan/handoff are retired.

## 7. Constraints and gotchas in force

- Never broaden the default Kimi-home ACL or copy OAuth files into a repo.
- Use `ai-kimi`, never a hand-built review command.
- Preserve the read-only profile and exact `session.resume_hint` completion rule.
- Never use `--continue`; resume exact session IDs.
- Kimi tool names are case-sensitive.
- Do not claim tokens, cost, cache, context size, or returned model.
- Do not increase the timeout as a substitute for startup classification.
- Do not build a privileged broker without a new threat model and Albert's approval.
- Stage only this workstream's files. The primary checkout has unrelated untracked work.
- No production, database, or cloud access is part of this work.

## 8. Access and environment

- Repo: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`.
- Plan worktree: `C:\repos\ai-devops-worktrees\issue-31-kimi-windows-plan`.
- Machine: `al8960ofc`, Windows 11, PowerShell 7 plus Git Bash.
- Kimi: `%USERPROFILE%\.kimi-code\bin\kimi.exe`, version 0.32.0 at planning time.
- Default Kimi home: `C:\Users\ahazan2\.kimi-code`.
- GitHub CLI is authenticated.
- Kimi already has per-user OAuth. Never print or copy it.
- No 1Password read is required. If a new credential becomes necessary, stop; do not create or rotate it without approval.

## 9. Open questions and risks

- The implementation must select the most reliable native detached-process mechanism through a live canary. A hidden PowerShell worker is the leading option; a Windows service is out of scope.
- The earliest reliable Kimi startup signal may be the first valid stream record rather than session creation. Measure it.
- A future Kimi upgrade may change completion or data-home behavior. Keep the version gate and requalification.
- The largest risks are a leaked child process, premature success, credential leakage in metadata, or destructive stale-PID cleanup. The plan requires explicit tests and rollback for each.
- If secure main-task routing cannot satisfy the goal, that becomes the only owner decision and must be raised before expanding privileges.

## Handoff self-audit

1. **Can a zero-context developer continue without asking a question? Yes.** §§1–3 define the system, trigger, paths, branch, commit, issue, version, and exact current state; §6 supplies ordered verified steps.
2. **Can they continue as effectively as this session? Yes.** §§4–5 preserve every failed approach and the model-versus-wrapper distinction; §7 preserves the non-negotiable security and completion rules.
3. **Are background, goal, state, failures, findings, decisions, constraints, access, risks, exact actions, and verification present? Yes.** They are covered by §§0–9, with the complete executable specification in the linked 13-section plan.
4. **Would Albert see every requested decision by reading only §0? Yes.** There is no current owner decision. The one conditional future decision, a privileged broker or broader credential access, is stated in §0 with the recommendation to reject it.
