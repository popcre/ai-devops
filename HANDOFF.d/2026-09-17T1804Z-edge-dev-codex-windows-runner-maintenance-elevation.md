---
issue: 262
status: OPEN
owner: codex/issue-262-elevation-plan-0917
---

# Windows runner maintenance elevation — planning handoff

Implementation plan: [`../plan_windows-runner-maintenance-elevation.md`](../plan_windows-runner-maintenance-elevation.md)

## 0. Decisions only the owner can make

**None currently.** The requested business boundary is fully specified in issue #262 and locked in the plan: one qualification-refresh operation, no general elevation, and no weakening of Windows protections.

The next session must not ask Albert to choose technical ACL or execution-policy details. Per the repository rule, an independent read-only security reviewer must approve the exact minimal task permission and final protected-payload execution policy before merge and again before live installation. If anyone proposes another operation, operator, SYSTEM principal, stored credential, broader task ACL, or weakened Windows protection, stop and put that whole expansion to Albert in one message; none is authorized by this workstream.

Already settled — do not re-ask:

- 2026-09-17: UAC and remote-token filtering remain enabled.
- 2026-09-17: the initial allowlist contains only `refresh-qualification`.
- 2026-09-17: installation/live host proof is later protected work, not part of the prose planning PR.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public AI/CI recovery and governance toolkit. GitHub `main` is authoritative and uses feature-branch pull requests plus a merge queue. The affected systems are the dedicated Windows 11 CI hosts `edge-dev-win` and `EDGE-RUNN-ENVY`, reached through the private Tailscale network.

The current Administrator preflight, `bin/qualify-windows-runner.ps1`, checks Windows build, TPM, Secure Boot, one running automatic GitHub runner service, and machine-wide tools, then atomically refreshes `C:\ProgramData\ai-devops\windows-runner-security.json`. The new plan designs a narrow way for a filtered remote SSH token to request that one operation through an administrator-installed S4U scheduled task.

## 2. What we set out to do this session, and why

The session was assigned to create a standalone executable implementation plan for issue #262 only. It was explicitly forbidden to implement or install privileged behavior. Issue #262 exists because the `ahazan` SSH identity received a filtered, non-elevated Windows token, blocking the Administrator-only evidence refresh during #246. A temporary highest-privilege S4U task worked but was deleted and had none of the permanent safety/lifecycle controls now required.

The planning deliverables are the plan, this handoff, one `AGENTS.md` router row, and one implementation-plan-index entry, all in a prose-only PR that references but does not close #262.

## 3. Current state — what is true right now

- Planning started from `origin/main` `26bb4a2efdd9cd243df6d4fb7c0d901ba3fb2868` in worktree `C:\repos\ai-devops-issue262-plan-0917`, branch `codex/issue-262-elevation-plan-0917`.
- Task class `prose` was recorded before editing.
- Issue #262 is open. Live PR and worktree checks found no competing #262/elevation implementation owner.
- The plan is new and every STATUS row is open. Fresh work starts at Step 1.
- Existing implementation is limited to `bin/qualify-windows-runner.ps1` and its static test. No installer, worker, client, policy, audit schema, hostile test, or maintenance runbook exists.
- No privileged code was implemented. No task, ACL, service, registry setting, host, secret, or installed file was changed.
- This branch/PR is planning only. It does not authorize installation or live proof.

## 4. Everything we tried that did not work

- The first attempt to create the worktree and run its task gate in one command used the not-yet-created directory as the command working directory; process creation failed with `The directory name is invalid`. The worktree was then created from the canonical landing checkout and the task gate ran successfully inside it. No repository state was lost.
- A broad `rg` used PowerShell's literal `*.md` path form, which Windows rejected with `The filename, directory name, or volume label syntax is incorrect`. The search was rerun with repository paths and `--glob`; no evidence was missed.
- No implementation approach was attempted. Rejected design paths are preserved in plan section 7 so the next session does not retry Windows sudo, UAC prompts, `LocalAccountTokenFilterPolicy`, repository-executed elevation, a general broker, SYSTEM substitution, or one-off ungoverned tasks.

## 5. Root causes and key findings

- Root cause: Windows remote-token filtering leaves the authenticated local administrator without the elevated token required by `#Requires -RunAsAdministrator`.
- `bin/qualify-windows-runner.ps1:1` requires elevation; lines 8–25 perform the actual security and runner-service checks; lines 27–42 atomically write the evidence.
- `docs/independent-windows-runner-setup.md:204-210` confirms why the privileged preflight exists and why the restricted runner service is not a substitute.
- `bin/setup-opencode-glm.ps1:387-429` demonstrates task registration and `Schedule.Service.SetSecurityDescriptor`, but its Full Access user ACE is deliberately unsafe for this boundary.
- `docs/glm-opencode.md:488-500` records that `SetSecurityDescriptor($sddl, 0)` must use flag `0`; passing `4` fails.
- A privileged task must execute an administrator-owned copy under Program Files, never a mutable repository script. A strict request schema contains no path/argument/command. Audit identity comes from the request file owner SID, not a caller-supplied name.
- One host's success cannot establish Windows portability. `edge-dev-win` and `EDGE-RUNN-ENVY` require separate live sessions and evidence.

## 6. Exact next steps

1. Read the linked plan from the STATUS table through its self-audit; start at Step 1. **You'll know it worked when** no step relies on this handoff or the old chat for missing context.
2. Re-resolve `origin/main`, issue #262, open PRs/worktrees, and the two target hosts before touching code; create a fresh current-upstream worktree if this planning branch has already landed. **You'll know it worked when** no active owner or drift conflicts with the plan.
3. Implement Phase A exactly within the named files/functions and run every hostile offline test. Do not install anything. **You'll know it worked when** every section-10 command passes and the plan STATUS cites artifacts rather than counts.
4. Dispatch exact-head independent security review after `ai-task-gates check --before review`; repair anything short of explicit `APPROVE`. **You'll know it worked when** the verdict pins exact base/head SHAs and approves ACLs, request races, result/audit secrecy, rollback, and tests.
5. Land through the merge queue and verify `origin/main`. **You'll know it worked when** the intended merge commit contains the code and required checks are green.
6. Use one new protected session for `edge-dev-win`, then another for `EDGE-RUNN-ENVY`; each rechecks idleness and obtains task-gate plus independent-review authorization before install. **You'll know it worked when** each host has its own full positive/negative/recovery record and unchanged runner-service proof.
7. Reconcile both records, update the plan/index, retire this handoff under the successor rule, and close #262 only after both hosts pass. **You'll know it worked when** the issue links the merge, exact-head approval, two host proofs, and rollback evidence.

## 7. Constraints and gotchas in force

- UAC and remote-token filtering stay enabled. Never enable Windows sudo, set `LocalAccountTokenFilterPolicy=1`, automate UAC consent, store a password, or substitute SYSTEM.
- The only operation is `refresh-qualification`; no caller-supplied command, argument, path, environment, or working directory.
- The installed payload is protected and hash-verified; the task never executes repository content directly.
- The operator gets task read/run only, not change/delete/redefine rights.
- The result is at most 8 KiB and secret-safe; the audit records requester SID, host, operation, start/end, and result.
- Concurrent duplicates must get explicit rejection. `IgnoreNew` without a result is not sufficient.
- Installation and live proof are protected actions, one host/outcome per session, with independent review. A task-gate refusal stops work.
- Do not stop, restart, replace, relabel, or reconfigure the GitHub runner service.
- Every GitHub call uses `bin/ai-gh`; waits use `bin/ai-pr-wait`; all write work uses an isolated current-upstream worktree.
- The public repository must never contain private machine-atlas facts, credentials, raw environment, or security evidence contents.

## 8. Access and environment

- Repository: `popcre/ai-devops`; target `main`; current planning branch `codex/issue-262-elevation-plan-0917`.
- Current planning worktree: `C:\repos\ai-devops-issue262-plan-0917` on machine `edge-dev`.
- GitHub: authenticated through `bin/ai-gh`.
- Target aliases: `edge-dev-win` and `EDGE-RUNN-ENVY`; local operator identity `ahazan`. Resolve addresses/private paths from the private machine atlas at runtime.
- Required Windows tools are machine-wide PowerShell 7, Git Bash, Task Scheduler, TPM, Secure Boot, and one running automatic runner service.
- The maintenance operation needs no secret. If a secret unexpectedly becomes necessary, stop. Governed secrets belong only in 1Password vault `vibe_coding`, referenced by item title and never value.

## 9. Open questions and risks

The only open technical rulings are the effective minimal Task Scheduler read/run mask and `AllSigned` versus hash-verified protected `RemoteSigned`. The independent security reviewer owns those rulings. They may tighten the design but may not broaden it.

Primary risks are an overbroad task ACE, mutable elevated payload, lost/racing request, unsafe exception text, S4U behavior differing by host, and removal touching foreign state. The plan pairs each with fail-closed hashes/ACLs, UUID/result contracts, curated errors, separate host proofs, and manifest-verified rollback.

No owner question is active. Any proposal to add an operation/operator, use SYSTEM/stored credentials, widen permissions, or weaken Windows protections becomes a new Albert decision and must be consolidated in section 0 before work continues.

## Handoff self-audit

1. **Can a brand-new developer continue without skipping a beat? Yes.** Sections 1–6 define the system, incident, exact state, failed attempts, findings, and verified next sequence; the linked plan carries the complete build spec.
2. **Can they continue as effectively as this session? Yes.** Sections 3–5 preserve the exact base/branch/worktree, current file evidence, overlap result, errors recovered from, and non-obvious privilege findings.
3. **Is every execution detail represented? Yes.** Sections 6–9 cover actions, gates, constraints, access, risks, rollback ownership, landing, installation, and closure; the plan provides concrete files/functions/commands/tests.
4. **Would Albert see every decision in section 0? Yes.** A line-by-line sweep of sections 1–9 found no current owner decision. The only two open technical rulings are assigned to independent security review in sections 6 and 9 and repeated in section 0. The conditions that would require Albert are also repeated there with a recommendation to stop rather than assume.
