---
issue: 262
status: BLOCKED
owner: codex/edge-dev-runner-wrapup
---

# EDGE-DEV Windows runner qualification and maintenance recovery

## 0. Decisions only Albert can make

**Blocking:** The documented local Administrator preflight requires Albert to approve a Windows consent prompt on EDGE-DEV. Albert wrote “you can do it now” on 2026-09-28, but the prompt received no approval during this session and fresh evidence was not produced. Ask once whether he is at the machine and can approve a new prompt; do not infer approval from elapsed time. This blocks the full qualification run.

**Already settled — do not re-ask:** Albert wants EDGE-DEV to take Windows CI work to reduce Blacksmith cost. Keep every test and existing qualified/hosted capacity. The security reviewer, rather than Albert, judges the technical maintenance-task repair. No approval exists for a rejected recovery command, weakening runner safety checks, or relabelling an unqualified host.

The next session should present any newly discovered owner decisions together before acting. There are no other known owner decisions.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public AI and CI recovery toolkit. GitHub Actions verification has six ordinary Windows sections. Idle qualified physical Windows hosts can take sections; remaining work runs on Blacksmith. EDGE-DEV is an interactive Windows 11 computer with one registered automatic GitHub runner service. It is a candidate, so ordinary jobs must not use it until its own full qualification is green. The local security preflight records TPM, Secure Boot, build, and runner-service evidence; the qualification workflow accepts that evidence for only 24 hours.

## 2. What this session set out to do

Albert moved Claude and ChatGPT work to a new machine and authorized qualifying EDGE-DEV now, hoping to lower Blacksmith cost. The intended single live outcome is an uninterrupted full qualification on `edge-dev-win`, followed by evidence-based admission to ordinary Windows work. Repairing the separate remote maintenance boundary belongs to issue #262 and must not be represented as completed by runner qualification.

## 3. Current state — verified, unfinished, and untouched

- The isolated worktree is `C:\Users\ahazan\.codex\worktrees\edge-dev-runner-qualification\ai-devops`, branch `codex/edge-dev-runner-wrapup`, initially based on `769901fed4b44654d6569625ef757ddc32a73453`. Re-resolve `origin/main` before further work. The canonical checkout at `C:\repos\ai-devops` has unrelated pre-existing changes; do not touch them.
- `edge-dev-win` was online and idle with `ai-devops-windows`, but without `ai-devops-windows-qualified`. One runner service was Running/Automatic. A sample on 2026-09-28 showed about 19 GB available RAM, but capacity is time-sensitive.
- Security evidence in `C:\ProgramData\ai-devops\windows-runner-security.json` still records 2026-09-04 and is too old. The last check during wrap-up found it about 581 hours old. No full qualification workflow was dispatched, no runner label was changed, and no runner service was stopped or reconfigured.
- The `\AiDevOps\WindowsRunnerMaintenance` task remains an incomplete earlier installation. A fixed unprivileged refresh request timed out after 180 seconds; Task Scheduler reported result 1 and no fresh evidence. Its action, principal, and owner were inspected read-only. The task was Ready and had no trigger. The timed-out request remains in its protected runtime directory.
- A documented local Administrator preflight was launched through Windows consent; no approval or refreshed evidence was observed. The consent process was gone at wrap-up. Do not assume the preflight ran.
- Draft changes to `bin/install-windows-runner-maintenance.ps1`, `tests/test-windows-runner-maintenance.ps1`, and `docs/independent-windows-runner-setup.md` are **uncommitted and rejected by independent security review**. They attempt to preserve runtime records and constrain partial-task identity, but still have an unresolved task-start race and a sealed-permission condition that may reject the actual partial task. Do not install or ship this draft. Focused maintenance tests reported 108 passed; Windows script tests reported 52 passed. Passing tests do not override the reviewer rejection.
- This handoff and a STATUS correction to `plan_windows-runner-maintenance-elevation.md` are session documentation. Check their Git/PR state before assuming they landed.

## 4. Everything tried that did not work

1. The unprivileged `refresh-qualification` client timed out. The protected task's last result was 1, its result directory had no new result, and evidence stayed old. Do not repeat the unchanged request.
2. `-Verify` from the filtered current token failed to read the protected runtime `temp` directory. That is expected for the non-elevated account and is not a reason to loosen its ACL.
3. A local Administrator preflight was requested through Windows consent. Consent was not received while the command was observed. No fresh evidence resulted; a later check showed the consent process had exited.
4. `ai-grok-review` could not start because reviewer event recording refused a linked state path. An independent read-only in-chat reviewer examined the exact proposed recovery instead and returned REJECT, with concrete evidence below. Do not treat a wrapper failure as an approval.
5. The first proposed recovery would remove request/result/audit/replay files even though its backup contains only task XML and payload. The draft changed recovery to retain runtime records. The second review found it could still unregister a task that started during backup. The latest draft added a final state check, but the reviewer found a race between that check and unregister, and its exact sealed-SDDL requirement may refuse the actual partial installation. Neither draft was approved or installed.

## 5. Root causes and key findings

- `bin/install-windows-runner-maintenance.ps1`'s landed `Backup-MaintenanceInstallation` backs up task XML and payload; landed `Recover-MaintenanceInstallation` removes owned runtime names, including the audit and replay ledgers. The live timed-out request makes that data-loss path concrete.
- The partial installation originated when the earlier install failed at `Set-MaintenanceTaskAcl`. The task's file ACL showed the local account with read access and Administrators/SYSTEM with control, but the Task Scheduler COM SDDL read through the filtered token returned empty. A safe recovery must inspect the effective elevated task descriptor; the draft's demand for the final sealed descriptor may therefore fail.
- The reviewer said, verbatim: “A GRGX operator can start the task during that window; recovery can unregister/delete its code while it runs, then reinstall a second task.” A simple check immediately before unregister still leaves a small start window. Closing that race needs a reviewed serialized maintenance approach and proof that the operator cannot re-enable or replace the task.
- Direct local Administrator preflight is documented in `docs/independent-windows-runner-setup.md` §4 and is separate from the remote maintenance task. It can provide fresh evidence without changing the runner service. It does not repair the remote task or authorize calling that repair complete.
- The qualification workflow selects any runner with `ai-devops-windows`; EDGE-RUNN-ENVY also carried that candidate label during this session. A green run proves EDGE-DEV only if the job names `edge-dev-win`.

## 6. Exact next steps and proof gates

1. Recheck the machine and GitHub runner state read-only, including memory, current evidence timestamp, task state, and whether Windows consent is pending. **You'll know it worked when** EDGE-DEV is idle, the one service is automatic/running, and there is no active task or qualification job.
2. If evidence is still stale, arrange an attended local Administrator preflight from the documented command and confirm Windows consent was accepted. Do not use the rejected remote recovery draft. **You'll know it worked when** the evidence records the current build and a timestamp less than 24 hours old, while the runner service remains unchanged.
3. Dispatch the canonical `qualify Windows runner` workflow only when EDGE-DEV is idle. Because the job may take 60–75 minutes, leave the issue/PR as the card and leave the machine unused (registration is OUT; #1183 child 3). **You'll know it worked when** one uninterrupted green job explicitly names `edge-dev-win` and proves the complete test matrix plus a clean reusable workspace.
4. Only after that exact-host green result, perform the documented admission checks and add `ai-devops-windows-qualified` to `edge-dev-win`; verify a representative ordinary job actually runs there. **You'll know it worked when** GitHub shows the host online and qualified, the ordinary job names this host, and the other Windows capacity remains usable.
5. Separately continue issue #262 in a new, single-outcome session. Start with the rejected draft in this worktree, preserve runtime records, inspect the task's elevated descriptor, close the start/unregister race, obtain independent exact-head security APPROVE, then ship the repair through a PR before any elevated recovery. **You'll know it worked when** reviewed code lands on `origin/main`, elevated `-Verify` passes, a non-elevated refresh returns bounded SUCCESS, and the task's negative/recovery checks pass without changing the runner service.

## 7. Constraints and gotchas

- Public repository: do not expose raw protected runtime records, credentials, transcripts, or private machine facts. Only aggregate status and safe timestamps belong in public evidence.
- Use isolated current-upstream worktrees, task gates, `bin/ai-gh`, and repository CI/merge rules. Do not push to protected `main` or stage another session's files.
- Do not relabel EDGE-DEV before exact-host qualification. Do not reduce tests, disable safety checks, change UAC/remote-token filtering, force-delete the partial task, or restart the runner service as a shortcut.
- The remote maintenance repair needs an independent read-only security APPROVE before live installation. Its draft is rejected; tests passing does not change that.
- The canonical checkout's modified housekeeping script and untracked Kimi/Grok handoff predate this work; preserve them untouched.

## 8. Access and environment

- Host: EDGE-DEV, Windows 11 build 26200. Repository: `https://github.com/popcre/ai-devops`; main is protected. GitHub was authenticated through `bin/ai-gh` during this session. Windows Administrator elevation was not obtained.
- Primary worktree/branch are in §3. The installed task and evidence paths are in §3. No secret, token value, or connection string appeared. If future work needs one, use 1Password vault `vibe_coding` and the secrets skill.
- The independent reviewer used a separate read-only agent, made no edits, and returned REJECT on the original command and the later draft. The Grok wrapper failed before a paid review began.

## 9. Open questions, risks, and freshness

- Albert must be present to approve a new local Windows Administrator prompt if evidence remains stale. His earlier authorization to do the work stands; only the physical consent action is missing.
- The remote maintenance task's effective elevated SDDL is unknown. The filtered read returning empty is not proof of safe permissions. The exact safe race closure is unresolved and belongs to a new reviewed repair session.
- Runner availability, memory, evidence freshness, current main SHA, workflow routing, and GitHub labels are snapshots from 2026-09-28. Recheck all before action. The plan's previous 2026-09-18 installation note was stale; the STATUS row now records the newer failure.
- The code/test/doc draft is not approved. Preserve its diff for diagnosis, but neither commit it as a fix nor use it as an elevated payload without a fresh independent APPROVE and required tests.

## Independent reviewer handoff

- Asked: read-only decision on the exact partial recovery and installation action, then review the isolated draft diff.
- Did: inspected the installer, task recovery order, and draft; made no changes and produced no PR or branch.
- Verdict: REJECT. First finding: backup omitted runtime records that recovery deletes. Second finding: recovery could unregister and delete payload while the task starts during backup. Third finding: the latest exact-SDDL check may reject the actual partial task, and the final check still leaves a start race. Resume this reviewer only with an updated exact-head packet; do not reinterpret any rejection as approval.

## Handoff self-audit

1. **Can a new developer continue without chat context? Yes.** §§1–3 identify the system, goal, worktree, host state, and unapproved draft; §6 gives the ordered continuation.
2. **Can they continue with the same knowledge? Yes.** §§4–5 preserve the failed refresh, filtered verification, unanswered consent, reviewer wrapper failure, and verbatim race finding.
3. **Are decisions, limits, and proof gates complete? Yes.** §0 isolates the only owner action; §§6–9 name exact-host success evidence, security review, protected data, and freshness checks.
