---
issue: 38
status: OPEN
owner: codex/ai-gemini-wrapper-plan
---

# HANDOFF — safe `ai-gemini` reviewer plan (2026-08-18 18:08Z, edge-dev/codex)

Implementation plan: [`../plan_ai-gemini-wrapper.md`](../plan_ai-gemini-wrapper.md)

Measured investigation: [`../docs/ai-gemini-wrapper-investigation.md`](../docs/ai-gemini-wrapper-investigation.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None now. Albert requested the plan. The implementation has one technical stop gate rather than an owner preference: if Antigravity cannot provide a supported isolated permission/configuration profile that reuses the existing login without copying credentials or changing global settings, issue #38 must be marked blocked and the wrapper must not ship.

Already settled on 2026-08-18: use official Antigravity, target Gemini 3.7 Flash High through configurable exact selection, keep the first release review-only, preserve exact-head/evidence-packet/read-only safeguards, do not use `--dangerously-skip-permissions`, and do not add automatic provider selection.

## 1. What this application is

`u2giants/ai-devops` is Albert’s public toolkit for installing and operating multi-model coding workflows. It contains Bash reviewer wrappers, Windows/Ubuntu setup, shared Claude/Codex skills, documentation, and dependency-free tests. It is not a hosted app and has no database, container, CI/CD, or production URL.

The relevant existing reviewers are Grok (`bin/ai-grok-review`), Kimi (`bin/ai-kimi`), and GLM (`bin/ai-glm`). Shared safety helpers create self-contained review directories, build exact-diff evidence packets, preflight providers, and record outcomes.

## 2. What we set out to do this session, and why

Albert asked for a zero-context implementation plan to add an `ai-gemini` wrapper after installing and authenticating Google’s Antigravity CLI. The business goal is to add Gemini 3.7 Flash High as another economical independent reviewer without allowing it to change code or silently use another model.

The plan was written under the `implementation-plan-writer` skill and links back to this handoff. Tracking issue [#38](https://github.com/u2giants/ai-devops/issues/38) was created so the plan and handoff can be retired when implementation is proven done.

## 3. Current state — what is true right now

- Plan is complete at `plan_ai-gemini-wrapper.md`; all ten STATUS rows are open and a fresh implementation session starts at Step 1.
- Durable measured findings are in `docs/ai-gemini-wrapper-investigation.md`.
- AGENTS routing and `memory/ai-devops` discovery point future sessions to the plan’s STATUS table.
- Antigravity CLI 1.1.14 is installed and Google-OAuth authenticated on Windows machine `edge-dev` at `%LOCALAPPDATA%\agy\bin\agy.exe`.
- Live marker, exact model, resume, usage, empty-success, command denial, and scratch-write behavior were measured. The exact scratch test artifact was deleted.
- No wrapper, permission profile, tests, installer integration, skill, or live repository review has been implemented.
- Planning used clean clone `C:\repos\ai-devops-plan-gemini` from `origin/main` SHA `dd2e3a547a88bb985e0f23f17606a0e3cb64b365` because the original `C:\repos\ai-devops` checkout contained unrelated concurrent work.
- There is no deployment beyond installing commands on machines. No account settings, repository behavior, database, or cloud state changed.

## 4. Everything we tried that did NOT work

1. Consumer OAuth through old Gemini CLI 0.35.2 and current 0.55.1 was rejected by Google as an unsupported client. Google moved personal terminal access to Antigravity.
2. Treating `--mode plan` as read-only failed conceptually and empirically. Google says it is a prompt prefix, and a native write still succeeded in Antigravity scratch state.
3. Treating `--sandbox` as Windows protection is invalid. Google says Windows support is still coming.
4. Treating process/JSON success as completion failed. A denied command returned `SUCCESS` with an empty answer.
5. Asking for a native write created a test file in provider scratch instead of the temporary workspace. It proved the tool remained write-capable; the exact artifact was removed.
6. Combining plan mode with disabled slash expansion caused Antigravity to warn that plan mode had no effect.
7. The newly installed `agy` was initially invisible to the already-running Codex PATH. Resolving `%LOCALAPPDATA%\agy\bin\agy.exe` worked; a fresh process should inherit PATH.

## 5. Root causes and key findings

- Antigravity is the correct direct-CLI architecture, like Grok/Kimi rather than GLM’s local server.
- Exact High selection works, but normal response JSON omits the model; zero-token `/model` returns structured exact-session proof.
- Named conversations resume by exact ID and retain context.
- `/usage` reports cost-weighted weekly and five-hour fractions, not a fixed request count.
- Hidden context is large: a trivial first response reported 15,438 tokens and the resumed conversation 32,018 total.
- Google auto-allows workspace writes unless explicit deny rules override them. A dedicated reviewer permission profile is mandatory.
- Global settings cannot be temporarily rewritten safely because concurrent runs and crashes can expose or strand the wrong policy.
- A self-contained review snapshot protects the real Git worktree but cannot alone prevent writes elsewhere on the host.

## 6. Exact next steps

1. Start at Step 1 of `plan_ai-gemini-wrapper.md` from current clean `origin/main`; quote the SHA. You’ll know it worked when the versioned contract fixtures/report exist and tests can reproduce every measured field.
2. Prove the dedicated permission/configuration boundary before wrapper construction. You’ll know it worked when hostile Windows/Ubuntu canaries leave every protected target byte-identical; otherwise mark #38 blocked.
3. Execute Steps 3–5, update STATUS/current state, then use `fresh-session`. You’ll know this phase worked when the named wrapper, helper integrations, and installed doctor pass offline and live gates.
4. Execute Steps 6–9, updating the plan after every phase. You’ll know it worked when the shared skill/docs/tests are complete and both supported platforms have redacted live qualification evidence.
5. Complete Step 10 with independent exact-head safety review, commit/push/install verification, plan de-staling, handoff retirement, and issue close. You’ll know it worked when `origin/main` and installed commands match the approved SHA and issue #38 is closed with evidence.

## 7. Constraints and gotchas in force

- GPT-5.6 reasoning stays low or medium.
- Work on `u2giants/ai-devops` `main`; no branch. Verify Albert’s noreply Git identity before committing.
- Preserve concurrent edits; stage only owned paths.
- No global Antigravity settings save/restore, OAuth copying, broad command grant, proxy, API billing, or `--dangerously-skip-permissions`.
- Plan mode is guidance, not enforcement. Windows sandbox claims require live proof.
- Always use `ai-review-sandbox` for linked worktrees and keep evidence packets additive.
- Empty success, wrong model, stale head, missing verdict, or any write is failure.
- Root `HANDOFF.md` and other sessions’ handoffs remain untouched.

## 8. Access and environment

- GitHub CLI is authenticated as `u2giants`.
- Repo: `https://github.com/u2giants/ai-devops`; clean planning clone `C:\repos\ai-devops-plan-gemini`.
- Windows: `edge-dev`, PowerShell 7 and Git Bash; Antigravity 1.1.14 installed/authenticated.
- Ubuntu target: `hetz`, normal toolkit path `/worksp/ai-devops`; Antigravity install/auth and safety are unproven.
- OAuth remains machine-local under `%USERPROFILE%\.gemini`; never print or copy it.
- No 1Password read is needed. If a new credential becomes necessary, stop; approved vault is `vibe_coding`, values never enter Git.

## 9. Open questions and risks

- The only blocking unknown is whether Antigravity supports a safe isolated permission/configuration profile while reusing login. The plan supplies the investigation and stop rule.
- Ubuntu support depends on official CLI availability and equivalent read-only proof.
- Official exact-conversation transcript export may not exist; the plan gives a safe fallback criterion.
- Upstream CLI JSON, model IDs, allowance fields, or sandbox behavior may drift; versioned fixtures and doctor must fail closed.
- Token overhead may make High less economical than expected; scoreboard records evidence but never auto-routes.

## Handoff self-audit

1. **Could a zero-context developer continue without questions? Yes.** §§1–3 define the repository, goal, artifacts, SHA, machine, and exact current state; §6 links the executable plan and gates.
2. **Could they continue as effectively as this session? Yes.** §§4–5 preserve every failed attempt and measured Antigravity finding; §§7–9 preserve safety, environment, and open risks.
3. **Are failed attempts included with reasons? Yes.** §4 records the retired CLI, plan/sandbox assumptions, empty success, scratch write, slash warning, and stale PATH.
4. **Is every next step executable and verifiable? Yes.** §6 maps directly to plan phases and gives a proof condition for each.
5. **Are uncommon terms, paths, IDs, and environments defined? Yes.** §§1, 3, 5, 7, and 8 define wrappers, provider, issue, SHA, paths, machines, OAuth location, and review helpers.
6. **Was the section-0 sweep run? Yes.** §§1–9 contain no owner decision. The technical safety unknown and its stop rule are promoted in §0, with settled choices listed so they are not re-asked.

Final synthesis:

1. **Yes**, this file is comprehensive enough for a brand-new developer; the complete forward build spec is directly linked and §§1–9 preserve the planning context.
2. **Yes**, they can continue as effectively as this session because every measured success, failure, constraint, path, and safety distinction is preserved.
3. **Yes**, every relevant background, goal, current state, dead end, decision, constraint, risk, action, and verification gate is present here or in the directly linked plan.
4. **Yes**, if Albert reads only §0 he sees that no decision is waiting and that the implementation must stop rather than weaken safety if isolated permissions are unavailable.
