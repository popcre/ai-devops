# Plan: make the Windows GLM service reliably available

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Reproduce and classify the service exit | ⬜ open | 2026-08-09 | Not started |
| 2. Add durable service supervision | ⬜ open | 2026-08-09 | Not started |
| 3. Make setup and doctor prove recovery | ⬜ open | 2026-08-09 | Not started |
| 4. Add Windows regression tests | ⬜ open | 2026-08-09 | Not started |
| 5. Run live continuity and cache tests | ⬜ open | 2026-08-09 | Not started |
| 6. Document, install, commit, and push | ⬜ open | 2026-08-09 | Not started |

Fresh sessions start at the first open row and must update this table as work lands. This plan is independent of the Grok/Kimi plans and may land first. Before any edit or push, pull `origin/main`, inspect concurrent work, and create one write-once `HANDOFF.d/<UTC>-<machine>-<agent>-glm-service-reliability.md` file cross-linked to this plan. Never rewrite another session's handoff.

Planning record: `HANDOFF.d/2026-08-10T0000Z-albt16-codex-delegate-integration-plans.md`.

## 1. Ultimate goal

Claude and Codex must be able to call GLM on this Windows computer whenever they need a code or implementation-plan debate, without discovering that its local service silently stopped. Named GLM conversations, cache reuse, and read-only safety must survive the repair. If a step conflicts with this goal, the goal wins: stop and flag the conflict.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his multi-model coding workflow. It contains Bash and PowerShell tools, shared Claude/Codex skills, tests, and setup documentation. It is not a web application. Work is on `main` in `C:\repos\ai-devops`. GLM is reached through `bin/ai-glm`, a loopback OpenCode 1.18.12 server on `http://127.0.0.1:4096`, and Z.ai Coding Plan model `glm-5.2`. Windows runs the server through Scheduled Task `AiDevOps-OpenCodeGlm`.

## 3. What triggered this work

On 2026-08-09, `ai-glm doctor` passed every installed/configured check but failed `health endpoint answers`. The Scheduled Task was `Ready`, not running; port 4096 had no listener; `LastTaskResult` was decimal `3221225786` (`0xC000013A`, process interrupted); and the last log entry said the server had started without recording a clean exit or cause. Grok and Kimi were usable, but GLM was not.

Reproduce with:

```powershell
ai-glm doctor
Get-ScheduledTask -TaskName AiDevOps-OpenCodeGlm
Get-ScheduledTaskInfo -TaskName AiDevOps-OpenCodeGlm
Get-NetTCPConnection -LocalPort 4096 -ErrorAction SilentlyContinue
```

## 4. Scope

In scope: determine the real exit cause; keep one loopback-only server alive; recover after an unexpected process exit; make setup and doctor verify the recovery path; preserve sessions/cache; add Windows tests and operating guidance.

Not in scope: changing GLM model/provider; upgrading OpenCode; weakening tool permissions; adding a second server; moving GLM to a cloud host; changing Ubuntu systemd unless a shared launcher defect is proven; production/cloud/DB changes; redesigning `ai-glm` sessions.

## 5. Current code state

- `bin/setup-opencode-glm.ps1:194-209` generates the launcher and injects the Z.ai key at runtime.
- `bin/setup-opencode-glm.ps1:241-409` registers, starts, and health-checks the Windows Scheduled Task. Lines 339-341 already set `RestartCount 3`, a one-minute restart interval, and `MultipleInstances IgnoreNew`.
- `bin/ai-glm:637-643` controls the Windows task; `:675-818` runs doctor checks.
- `config/opencode/agent/glm-review.md` structurally removes write, edit, patch, Bash, web, and subagent tools.
- `tests/test-ai-glm.sh` produced 129 passed, 0 failed on 916-alien on 2026-08-09 with `bash tests/test-ai-glm.sh`; continuity and cache assertions are additionally available behind `AI_GLM_LIVE=1`.
- `docs/glm-opencode.md` is the canonical architecture and incident record.
- The repo was clean and synced to `00e1231fe9b2aae209764bb50ced2d4d844ff015` before this plan was written. No repair code exists yet.

## 6. Findings and root cause

The configuration and credentials are present; the immediate failure is service availability. The task already has a bounded native restart policy: three retries at one-minute intervals. That policy did not leave a replacement listener after the observed `0xC000013A` exit. The plan must explain why before changing supervision. Plausible causes include a manual/task stop or logoff interruption that Task Scheduler does not classify as a restartable failure, Bash masking the child's result, exhausted retries, or stale task settings. These are hypotheses, not conclusions. `ai-glm` fails loudly, which is correct, but the user loses GLM continuity until recovery.

`0xC000013A` proves interruption, not its source. Do not call Task Scheduler itself the root cause until Event Viewer/task history and a controlled run establish whether the process was stopped by logout, task replacement, terminal control, setup, Windows shutdown, or another actor.

## 7. Rejected approaches

1. Start the task once and call the problem fixed. Rejected because the same unobserved exit can recur.
2. Hide the doctor failure or silently fall back to a fresh remote GLM conversation. Rejected because that loses continuity and cache evidence.
3. Add a second watchdog service or third-party supervisor. Rejected unless the shipped three-retry Task Scheduler policy and a small repo-owned launcher correction are proven insufficient.
4. Replace the shipped bounded retry with an infinite blind restart. Rejected because a bad key/config could create a crash storm and 1Password/API load.
5. Upgrade OpenCode while repairing supervision. Rejected because it mixes two risk sources and invalidates the 1.18.12 safety measurements.
6. Copy the Z.ai key into the task or launcher. Rejected; 1Password runtime injection remains mandatory.

## 8. Design decisions

Locked on 2026-08-09: one loopback server; exact OpenCode/model pins; repo-owned setup; secret injected at runtime; named sessions unchanged; structural read-only tools unchanged; loud failure; bounded restart/backoff; no production mutation.

Open to evidence: why the existing three-retry policy did not restart this exit; whether Task Scheduler settings alone are reliable for the foreground Bash child; whether the repo-owned wrapper needs to preserve a different exit code or add a bounded loop. Keep the shipped three-at-one-minute policy unless evidence requires a change. Choose the fewest moving parts that survives controlled child failure and machine logoff/logon behavior.

## 9. Ordered implementation plan

1. Capture the cause before editing. Export the registered task XML, inspect `Get-ScheduledTaskInfo`, task settings, `server.log`, and controlled child/parent exits. The required gate is a secret-free incident note that explains why the existing `RestartCount 3` policy did not produce a listener after `0xC000013A`. Task Scheduler Operational history is optional: enabling it requires one explicit elevated command, `wevtutil sl Microsoft-Windows-TaskScheduler/Operational /e:true`; if elevation is not authorized, use the XML, last result, logs, and controlled reproduction and record that limitation. Never print environment variables.
2. Correct the smallest proven supervision defect in `bin/setup-opencode-glm.ps1`. If Bash masks the child failure, make the generated wrapper propagate it. If Task Scheduler does not restart the observed exit class, add only the smallest bounded wrapper behavior that covers it. Preserve the three-at-one-minute ceiling unless evidence justifies another bound. Add bounded log maintenance before append, such as rotating `server.log` at a documented size while retaining one prior log. Gate: killing the child causes one replacement listener on 127.0.0.1:4096 within the bound; repeated bad configuration stops at the ceiling; logs remain bounded and actionable.
3. Make installation idempotently replace stale task settings and verify them. Extend `ai-glm doctor` to report task state, last result, restart policy, and health without declaring `Ready` healthy. Do not add `server ensure`; supported recovery remains explicit `ai-glm server start/restart`. Gate: a stopped service is diagnosed precisely, and the supported recovery command restores health without setup reruns.
4. Extend `tests/test-windows-scripts.sh` only with feasible static/rendered assertions for task-policy source, generated-wrapper failure propagation, log rotation, and no secret literal. Extend `tests/test-ai-glm.sh` only for cross-platform client/doctor behavior. Gate: both Bash suites pass with no provider call; do not invent a separate Pester suite or pretend a static suite can register a Windows task.
5. Run the controlled Windows/live gate on 916-alien: run setup twice, export the registered task XML after each run, normalize volatile registration metadata, and prove action, trigger, principal, ACL, and settings are equivalent. Then create one named review, store a random marker from a repo file, stop only the server, prove automatic recovery, resume the exact session, recover the marker from memory, and verify the report records `cache.read`. Gate: idempotent task definition, same OpenCode session ID, correct marker, healthy doctor, one listener, and no worktree change.
6. Update `docs/glm-opencode.md`, `skills/shared/ask-glm/SKILL.md`, `docs/development.md`, this STATUS table, and the relevant hard-won constraint. Run the installer once to refresh both Claude and Codex skills. Gate: installed copies hash-match the repo; all tests pass; `git diff --check` passes; commit identity is Albert's noreply address; commit is pushed to `origin/main` and remote SHA matches.

Natural fresh-session cut: after step 1, once the cause and chosen supervision mechanism are recorded. Re-read steps 2-6 before continuing.

## 10. Tests required

- `tests/test-windows-scripts.sh`: source registers bounded restart interval/count and logon trigger.
- `tests/test-windows-scripts.sh`: rendered launcher and generated service wrapper have no secret, return the child status, and rotate logs.
- Controlled run on 916-alien: second setup produces equivalent normalized task XML and ACL/settings.
- Controlled run on 916-alien: child kill recovers with one listener; repeated failure stops at the ceiling with actionable, bounded logs.
- `tests/test-ai-glm.sh`: existing cross-platform suite remains 129/0 or higher.
- `AI_GLM_LIVE=1 bash tests/test-ai-glm.sh`: exact-session memory and cache reporting survive service recovery.

## 11. Constraints and gotchas

Main-only repo; verify author and committer as `Albert Hazan <u2giants@users.noreply.github.com>`; never expose 1Password values; do not edit Claude config; PowerShell source must remain ASCII; do not replace system binaries; no silent fallback; preserve unrelated work; Task Scheduler actions must use `-WindowStyle Hidden` only when `Start-Process` is involved; do not confuse `Ready` with healthy; do not treat `0xC000013A` as a complete cause; preserve loopback binding and HTTP authentication. The Grok debate plan also edits `skills/shared/ask-glm/SKILL.md`; confine this plan's changes there to service/supervision guidance and pull immediately before committing.

## 12. Access and environment

Windows 11 machine `916-alien`; PowerShell 7, Git Bash, `gh`, `op`, Kimi, Grok, and OpenCode are installed. Secrets live in 1Password vault `vibe_coding`, item `GLM z.ai API`; never retrieve the value into chat or files. Target is local port 4096 and task `AiDevOps-OpenCodeGlm`. No browser, production, database, or cloud mutation is required.

## 13. Definition of done, risks, and open questions

Done means: cause recorded; bounded automatic recovery proven; one listener only; exact GLM session resumes after recovery; cache data recorded; review remains read-only; setup is idempotent; offline and live tests pass; docs and installed skills match; plan STATUS is current; correct commit is pushed and remote-verified. This repo has no CI workflow or deployed application, so CI/deploy are N/A and must be recorded as such.

Main risks: restart storm, duplicate listeners, task settings ignored for a child process, interrupt during machine shutdown being misclassified, or loss of session state. Log growth must be mitigated in step 2, not merely accepted. Roll back by reverting the commit and rerunning the prior setup script; do not delete session state. Open question: why the shipped retry did not fire and whether a wrapper correction is needed, resolved only by step 1 evidence.

## Mandatory self-audit

1. Yes. Sections 2-6 establish the system, evidence, code, and failure; sections 8-10 provide locked decisions, exact steps, and gates.
2. Yes. Sections 6-8 preserve uncertainty around `0xC000013A`, all rejected shortcuts, and the safety boundaries.
3. Yes. Section 1 states the user outcome and goal-over-step rule; sections 4 and 8 bound judgment.

All 13 sections, scope exclusions, rejected approaches, locked/open decisions, named tests, access, rollback, commit/push, and N/A CI/deploy gates are present. Self-audit passed on 2026-08-09.
