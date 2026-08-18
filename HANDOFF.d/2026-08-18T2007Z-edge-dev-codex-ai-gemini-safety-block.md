---
issue: 38
status: BLOCKED
owner: codex/ai-gemini-safety-block
---

# HANDOFF — Gemini reviewer safety block (2026-08-18 20:07 UTC, edge-dev/codex)

Plan: [`../plan_ai-gemini-wrapper.md`](../plan_ai-gemini-wrapper.md)
Issue: [u2giants/ai-devops#38](https://github.com/u2giants/ai-devops/issues/38)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. The plan contains a technical stop rule, not a choice: do not weaken
Antigravity permissions, copy its Google login, or alter Albert's normal settings
to make `ai-gemini` work. Recommendation: leave issue #38 blocked until Google
documents an isolated reviewer profile that a command can select safely.

Already settled on 2026-08-18: Gemini's first release is review-only; it must use
the official Antigravity CLI, verify its exact model, and fail if it can write.

## 1. What this application is

`u2giants/ai-devops` is Albert's public toolbox for dependable AI coding work. It
contains shell commands, Windows setup, documentation, and tests. It has no web
site, database, or production service. Issue #38 would add a safe `ai-gemini`
code-review command using Google's Antigravity CLI.

## 2. What we set out to do this session, and why

Albert asked to implement the Gemini wrapper plan. The first plan step is to prove
that Antigravity can run with a dedicated no-write policy without changing the
normal interactive policy. This is required before any wrapper code may be built.

## 3. Current state — what is true right now

- `plan_ai-gemini-wrapper.md` now marks Step 1 blocked and names the exact resume
  condition near the STATUS table and current-state section.
- `docs/verification/ai-gemini/antigravity-contract-2026-08-18-windows.md`
  records the local and official-document evidence.
- `tests/test-ai-gemini.sh` and its redacted fixtures validate nine contract
  cases offline. Run it through Git Bash:
  `"C:\Program Files\Git\bin\bash.exe" -lc 'cd /c/repos/ai-devops && bash tests/test-ai-gemini.sh'`.
  It passed: 9 checks, 0 failures.
- Live, non-destructive checks on `edge-dev` found `agy` 1.1.14 at
  `%LOCALAPPDATA%\agy\bin\agy.exe`, the required `gemini-3.7-flash-high` model,
  and structured no-token allowance output.
- GitHub issue #38 remains open but has a blocking explanation at
  `https://github.com/u2giants/ai-devops/issues/38#issuecomment-5333437197`.
- No `bin/ai-gemini`, installer entry, shared skill, machine configuration, OAuth
  file, or Antigravity settings file was created or changed.
- The evidence package is committed and pushed on `main` as
  `d316216d30cc524df74904b7281c0afe156448e8` (`Record Gemini reviewer safety
  blocker`). The pre-existing untracked `.ai/` directory is unrelated and must
  remain unstaged.

## 4. Everything we tried that did NOT work

1. Looking for an isolated policy option in `agy --help` found no flag for a
   settings file, configuration directory, profile, permissions file, or data home.
   It only exposes `--project` and `--new-project`.
2. Treating a project as the isolation answer does not work. Google's current
   project documentation says a new project starts with read and write access to
   its folders, while its project permissions are persistent interactive settings.
   The wrapper cannot safely create or modify that policy programmatically.
3. `--mode plan` and Windows `--sandbox` do not solve this. The earlier live
   investigation proved plan mode is guidance rather than write prevention; the
   plan forbids a Windows sandbox claim without a hostile-write proof.
4. Running `bash tests/test-ai-gemini.sh` from PowerShell invoked the WSL shim and
   failed because no Linux distribution is installed. Git Bash at
   `C:\Program Files\Git\bin\bash.exe` ran the same test successfully.

## 5. Root causes and key findings

- Google documents fine-grained permissions in the shared persistent file
  `~/.gemini/antigravity-cli/settings.json`. Workspace writes are automatically
  allowed by default unless that file contains a deny rule.
- Google documents project-scoped settings, but neither the current command help
  nor the official CLI pages document a command-line way to pass a restricted
  project policy. The command must resume a named conversation in the same project,
  so a default or mutable project policy is unsafe.
- The required contract parsing is now repeatable without using an account:
  `tests/fixtures/ai-gemini/` includes success, empty-success, exact-model,
  mismatch, allowance, quota, authentication, and malformed-result fixtures.
- The plan's locked rule is correct: a disposable repository snapshot alone cannot
  prevent host writes. The missing permissions boundary is therefore a release
  blocker, not an implementation detail.

## 6. Exact next steps

1. Watch official Antigravity CLI release notes and permissions documentation for
   a documented per-process, OAuth-reusing configuration or permissions-profile
   selector. You will know this is actionable when the option is listed in the
   official CLI reference, not merely inferred from private file locations.
2. When that support exists, update the contract report and fixture tests with the
   exact option and precedence. You will know it worked when the offline test
   proves the option is required and accepts its structured output.
3. Run the Step 2 hostile Windows canary in an isolated disposable repository,
   checking the review copy, the original checkout, an outside sentinel, and
   provider scratch before and after. You will know it worked only when every
   forbidden write is denied and every protected target is byte-identical.
4. Only after that gate passes, change Step 1 and then start plan Step 2. Do not
   build `bin/ai-gemini` beforehand. You will know the workflow can proceed when
   the plan's STATUS table cites the redacted canary report.

## 7. Constraints and gotchas in force

- Target is `u2giants/ai-devops` `main`; do not create a branch. Stage only owned
  paths and never use `git add -A` in this shared checkout.
- Do not copy, print, parse, or commit Antigravity OAuth material. Do not rewrite
  and restore its normal settings file, and never use `--dangerously-skip-permissions`.
- Keep this wrapper review-only. A JSON `SUCCESS` response without text or a
  verdict is failure, and every accepted review must prove the exact model.
- The Git Bash path above is required on this Windows computer until WSL gains a
  Linux distribution. Git identity already verified as Albert Hazan's noreply
  identity.
- Do not edit root `HANDOFF.md` or any other handoff file.

## 8. Access and environment

- Windows computer: `edge-dev`; repository: `C:\repos\ai-devops`; current
  `origin/main` at investigation time: `f25c725765f779012c3fc6448b109de3e09a81a6`.
- `gh` is authenticated as `u2giants`; use it to update issue #38 once the external
  dependency changes. No 1Password access is needed.
- Antigravity is authenticated locally. Its executable is
  `%LOCALAPPDATA%\agy\bin\agy.exe`; its account state remains private under the
  user's profile and must not be inspected.
- Official sources used: Antigravity permissions, settings, and project pages,
  linked from the verification report.

## 9. Open questions and risks

- It is unknown whether Google will add the required command-line isolated-policy
  mechanism. Until then, Windows support is blocked; Ubuntu must not be attempted
  as a workaround.
- A future CLI version can change JSON shapes, model names, or allowance fields.
  Keep the fixtures versioned and fail closed on missing fields.
- The plan requires a paid live qualification only after the safety boundary is
  proven. Do not spend allowance on hostile canaries until the policy is known to
  be selected independently of Albert's normal settings.

## Handoff self-audit

1. **Could a new developer continue without questions? Yes.** Sections 1–3 name
   the product, issue, affected files, exact environment, test command, current
   GitHub state, and what was not changed; Section 6 gives the ordered resume path.
2. **Could they continue as effectively as this session? Yes.** Sections 4–5
   preserve the failed approaches, official-policy finding, command limitations,
   offline fixtures, and release reasoning.
3. **Are failed attempts included with reasons? Yes.** Section 4 records the
   absent profile option, unsafe project defaults, inadequate plan/sandbox modes,
   and Windows Bash-shim failure.
4. **Is every next step concrete and verifiable? Yes.** Section 6 names the
   official evidence, required canary, protected targets, plan update, and proof
   gate for each action.
5. **Are uncommon paths and terms explained? Yes.** Sections 3, 5, 7, and 8
   define Antigravity, the settings file, Git Bash, fixtures, issue, SHA, and OAuth
   handling.
6. **Was the owner-decision sweep run? Yes.** Sections 1–9 contain no pending
   owner choice. The only stop is an external product capability and it is stated
   in Section 0 with the recommendation to leave the issue blocked.

Final synthesis:

1. **Yes**, this handoff is comprehensive enough for a new developer to resume
   safely because it includes the concrete blocker, evidence, tests, state, and
   exact release condition.
2. **Yes**, it carries the session's relevant knowledge, including why tempting
   alternatives fail and why no wrapper was shipped.
3. **Yes**, the background, goal, outcome, failed attempts, constraints, risks,
   evidence, and next actions needed for correct continuation are present.
4. **Yes**, Section 0 contains every item that could need Albert's judgment; none
   does, because the plan already mandates the safe blocked outcome.
