---
issue: 40
status: OPEN
owner: main / al8960ofc Codex / Muse OpenCode plan
---

# HANDOFF — Muse Spark 1.2 OpenCode plan (2026-08-18T1929Z, al8960ofc/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### BLOCKING

N/A now. Planning is complete. Implementation can begin at Step 1 without another design decision.

If the `Meta Model API` item or key does not exist in 1Password, implementation will need Albert to grant browser access to Meta Model API and approve storing the resulting key in `vibe_coding`. This blocks the paid contract probe, not the offline preparation.

### RECOVERABLE

N/A. The plan deliberately chooses Meta’s standard service tier. The cheaper Contributor tier is not an implementation option because it permits provider training on prompts and completions.

### ALREADY SETTLED

- Use a Muse-tailored OpenCode harness, not Muse Code through WSL, for the everyday Claude/Codex bridge.
- Keep `ai-muse` separate from `ai-glm` at the command, service, credential, port, state, and report levels.
- Share one provider-neutral safety implementation rather than copying the large GLM wrapper.
- Preserve the qualified OpenCode version unless Meta proves it cannot work. An upgrade requires a separate GLM requalification plan.
- Use the standard Muse service tier. Contributor is out of scope without new explicit owner approval.

## 1. What this application is

`u2giants/ai-devops` is Albert’s public toolkit for installing and operating a multi-model AI coding workflow on Windows and Ubuntu. It contains Bash commands, PowerShell setup, skills, documentation, and tests. It has no web application, database, container, or hosted deployment.

The open build specification is [`plan_muse-opencode-harness.md`](../plan_muse-opencode-harness.md). Read its STATUS table first and do not re-plan completed work.

Repository: `C:\repos\ai-devops`, remote `u2giants/ai-devops`, branch `main`. Ubuntu’s canonical checkout is `/worksp/ai-devops`.

## 2. What this session set out to do, and why

Albert asked for a comprehensive implementation plan to set up an OpenCode harness for Muse Spark 1.2 on Windows and Ubuntu. The plan must let a fresh implementation session build the complete system without relying on this chat.

The intended result is a dependable `ai-muse` command usable by Claude and Codex for persistent read-only reviews and isolated implementations, while keeping GLM stable.

## 3. Current state — what is true right now

- Planning is complete; implementation has not started.
- Tracking issue [#40](https://github.com/u2giants/ai-devops/issues/40) is open.
- The plan contains 11 open steps in four phases and passed the mandatory self-audit.
- The repository was fast-forwarded to `origin/main` commit `9188144` before writing.
- Existing unrelated untracked paths `.ai/` and `docs/claude-remote-control-hardening-v2.md` remain untouched.
- No Meta credential was read, created, changed, or stored.
- Existing GLM files were inspected only; no runtime behavior was changed.

## 4. Everything tried that did NOT work or was rejected

1. Driving Meta Muse Code in WSL from Windows Claude/Codex was rejected for this build because it introduces a second operating-system boundary and depends on an interactive terminal product rather than the established OpenCode service interface.
2. Reusing `ai-glm` by changing its model was rejected because its model/provider are deliberately immutable and its state and recovery records are GLM-specific.
3. One shared live OpenCode service was rejected because it would couple credentials, restarts, sessions, logs, and outages.
4. Copying and renaming the large GLM wrapper was rejected because two safety implementations would drift.
5. A one-step generic rewrite was rejected because it would put the working GLM harness at unnecessary risk. The plan requires characterization tests and live GLM parity before Muse work continues.
6. Contributor pricing was rejected as the default because it changes the data-use agreement and permits training on submitted content.

## 5. Root causes, findings, and decisions

- Meta officially documents OpenCode compatibility through Meta Model API, so the transport is supported.
- Compatibility does not prove identical tool, permission, cache, stop, or error behavior. The first implementation step freezes those contracts with sanitized live evidence.
- The existing GLM wrapper mixes provider-neutral lifecycle logic with GLM-specific identity. The permanent fix is one shared tested core plus thin immutable provider profiles.
- Review safety is the absence of writing and shell tools. OpenCode permission maps are not trusted.
- Implementation safety is a disposable clone with its Git remote removed.
- Linked Git worktrees must be converted to self-contained review snapshots before delegation.
- Muse and GLM use separate ports: GLM stays on 4096; Muse is planned for 4097.
- The exact standard Muse Spark 1.2 model ID remains intentionally open until authenticated Meta evidence proves it.

## 6. Exact next steps

1. Open [`plan_muse-opencode-harness.md`](../plan_muse-opencode-harness.md) and read its STATUS table, §§1, 8, 9 Step 1, 11, and 12.
2. Fetch `origin/main`, record the current SHA, inspect concurrent changes, and preserve unrelated work.
3. Confirm access to 1Password item `vibe_coding / Meta Model API / api key`. If absent, request browser access and storage approval once, then use the `secrets-to-1password` skill.
4. Execute plan Step 1 only. Save redacted contract evidence and stop if the standard Muse Spark 1.2 model, tool calling, or OpenCode 1.18.12 compatibility is not proven.
5. Update the plan STATUS and §5 in the same commit as the Step 1 evidence.
6. Continue in order. Use a fresh session after Steps 2, 6, and 10 as directed by the plan.

Each step has its own verification gate. Do not mark a step done with a bare claim or issue number.

## 7. Constraints and gotchas in force

- Read `docs/glm-opencode.md` §5 before changing shared OpenCode code.
- Work on `main`; stage only owned paths, never `git add -A`.
- Verify Albert’s noreply Git identity before the first commit.
- Never point a reviewer at a raw linked worktree.
- Never trust OpenCode permission maps as the safety boundary.
- Never give implementation a Git remote.
- Never share live state, credentials, ports, or service lifecycle between Muse and GLM.
- Never store or print the Meta key.
- PowerShell files must remain ASCII-only; Windows normal-user proof cannot be obtained over elevated SSH.
- Paid calls are sequential. Never replay an ambiguously delivered request.
- No database, production cloud, NAS, or UI work is involved.

## 8. Access and environment

- Machine: `al8960ofc`, Windows 11, PowerShell 7 primary.
- Repository: `C:\repos\ai-devops`; remote `u2giants/ai-devops`; branch `main`.
- `gh` is authenticated as `u2giants`; issue #40 was created successfully.
- Git identity was verified as `Albert Hazan <u2giants@users.noreply.github.com>`.
- Git Bash is used for Bash scripts; bare `bash` from Windows is WSL and does not inherit injected Windows environment values.
- Required future secret location: 1Password vault `vibe_coding`, item `Meta Model API`, field `api key`. No value belongs in Git.

## 9. Open questions and risks

- The exact standard Muse Spark 1.2 model ID must come from the authenticated Meta catalog.
- Meta’s cache, usage, permission, and error fields may differ from GLM and must be measured.
- Extracting a common core could regress GLM; the plan makes live GLM parity a hard stop before Muse proceeds.
- Meta may require a newer OpenCode version. If so, this plan stops and a separate OpenCode upgrade/requalification plan is required.
- Native Muse Code may later outperform OpenCode on long autonomous work. That comparison is explicitly outside issue #40.

## Mandatory self-audit

1. Yes, a new developer can continue without this chat. §§1–3 define the repository, goal, issue, plan, branch, baseline, and exact current state; §6 gives ordered next actions.
2. Yes, all current reasoning is preserved. §§4–5 record rejected architectures, privacy choice, safety controls, provider uncertainty, and why a shared core is required.
3. Yes, failed and rejected approaches are explicit in §4 with their failure mechanisms.
4. Yes, every next action in §6 names the actor, file, order, and proof source.
5. Yes, uncommon paths, ports, service roles, credential location, and operating-system traps are defined in §§5, 7, and 8.
6. Yes, the owner-decision sweep covered §§1–9. The only possible future access decision is consolidated in §0; no hidden approval remains.

Self-audit passed on 2026-08-18 UTC.
