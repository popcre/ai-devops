# Handoff: Kimi review requires a baseline parser correction

## 0. Decisions only the owner can make

None. The next correction is small, local, testable, and already authorized by
Albert's request to integrate Kimi's improvement into the plan.

Already settled, do not re-ask:

- Safety and correctness outrank token reduction.
- Work proceeds phase by phase. Fix the step-1 measurement before step 2 and do
  not skip to instruction trimming.
- Kimi's review is advisory. Codex independently confirmed its parser finding
  against the current source before accepting it.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for restoring and managing
Claude Code, Codex, shared skills, machine instructions, memory, and multi-model
development workflows. It is Bash, PowerShell, Python standard-library tooling,
and Markdown. It is not hosted and has no database, container, production
service, deployment URL, or GitHub Actions workflow.

The repo is `C:\repos\ai-devops` on Windows machine `al8960ofc`. It uses `main`
only. The active plan is
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

## 2. What we set out to do this session, and why

Step 1 previously added a read-only context audit and froze a baseline at commit
`f20ea6b98bc62e9d6b9c434fa3811fb96d2ec981`. Albert then asked GLM 5.2 and Kimi
K3 to check the work. GLM's existing persistent session accepted the request but
returned no answer after three attempts, including one service restart. Kimi's
protected read-only review completed and found one material measurement bug.

Albert asked to integrate Kimi's improvement into the plan and wrap up. This
session updated the plan only. It did not implement the parser correction.

## 3. Current state, what is true right now

The active plan now marks step 1 `correction open`. The fresh-session start says
to repair step 1 before beginning step 2. It includes an exact six-part
correction and a verification gate.

Confirmed defect:

- `tools/context-audit/context-audit.py:77-88` parses simple `key: value`
  frontmatter only.
- Seven tracked skills use YAML folded descriptions beginning with
  `description: >-`.
- The audit records only the literal text `>-` instead of the indented
  description lines.
- Therefore the Claude and Codex manifest totals in
  `docs/context-engineering.md:29-30` are understated and must not be used for
  warning budgets or before/after claims.

Kimi also found four accepted cleanup items: list the new audit test in
`docs/development.md`, say bytes rather than characters in the audit README,
describe the installer comparison as static capability matching rather than full
behavioral parity, and explain or fix the earlier fourteen-versus-current-twelve
duplicate-paragraph count.

Kimi confirmed the Windows automatic-quarantine test correction, secret
exclusions, stable tracked-path discovery, drift reporting, and the earlier
handoff were otherwise sound.

The full untracked review is
`.ai/reviews/kimi-context-engineering-step1-review-20260812T142135Z.md`. The
wrapper requested `kimi-code/k3`, but Kimi headless output does not report the
returned model, token use, cache, or cost. Do not invent those values.

Unrelated untracked paths `.ai/` and
`docs/claude-remote-control-hardening-v2.md` remain untouched by tracked work.

## 4. Everything we tried that did not work

1. The existing persistent GLM session
   `context-engineering-consolidation-review` accepted the implementation-review
   prompt but returned no model response twice. `ai-glm doctor` passed every
   check. The local GLM service was restarted and the exact session resumed a
   third time, but it still returned no answer. Do not report a GLM verdict for
   this implementation review.
2. The original step-1 fixture used only a one-line skill description. That was
   adequate for basic frontmatter but did not exercise folded YAML, allowing the
   false manifest totals to pass stable-output checks.
3. A stable wrong report is still wrong. The two-run equality gate proved
   determinism, not semantic correctness of multi-line frontmatter parsing.

## 5. Root causes and key findings

- The custom frontmatter parser is intentionally dependency-free but implements
  only single-line values. YAML block scalar markers require continuation-line
  handling.
- This is a material step-1 defect because per-client skill descriptions were a
  new headline baseline metric, not a minor detail.
- Kimi estimated the published totals were low by roughly 19 percent for Claude
  and 37 percent for Codex. Treat those percentages as review estimates, not the
  corrected source of truth. Regenerate the tool output after the fix.
- CRLF itself is not the root cause because Python text reading normalizes line
  endings. A CRLF fixture is still required to prevent a future regression.
- The ownership-map work in step 2 does not depend on the totals, but the plan
  intentionally orders the small correction first so no future session treats
  the wrong numbers as frozen truth.

## 6. Exact next steps

1. Read `AGENTS.md`, this handoff, the earlier step-1 handoff, and the full active
   plan. Re-read plan sections 1, 4, 8, 11, 13, and the step-1 correction. You
   will know this worked when you can state why step 1 is correction-open and why
   step 2 has not started.
2. Update `frontmatter()` in `tools/context-audit/context-audit.py` to handle
   single-line values plus YAML folded/literal markers `>-`, `>`, `|-`, and `|`
   without adding a dependency. Fold `>` forms deterministically and preserve
   literal `|` line breaks consistently. You will know this worked when no real
   skill's parsed description equals a scalar marker.
3. Extend `tests/test-context-audit.ps1` with folded-description and CRLF skill
   fixtures. Assert real continuation text appears in both client manifests and
   `>-` does not. First prove the new fixture fails against the old behavior.
   You will know this worked when the regression test fails before the fix and
   passes after it.
4. Run the real audit twice with a fixed `--generated-at`, compare hashes, and
   regenerate the manifest totals. Correct `docs/context-engineering.md:29-30`.
   You will know this worked when both reports are byte-identical and the totals
   match the documented values.
5. Add `pwsh -NoProfile -File tests/test-context-audit.ps1` to
   `docs/development.md`. Change the audit README to say bytes divided by four.
   Change the baseline doc's installer language to static capability matching.
   Reconcile the manual fourteen-versus-tool twelve duplicate count. You will
   know this worked when no document overstates what the tool measured.
6. Run the focused audit test and the existing Bash/PowerShell installer and
   memory suites named in the plan. You will know this worked when every command
   exits zero and no test is skipped silently.
7. Mark step 1 done again, set the plan fresh-session start to step 2, and update
   its evidence with corrected totals and test results. You will know this worked
   when step 2 is the first open row and no stale manifest total remains in
   current docs.
8. Verify Git identity, commit only this workstream to `main`, rebase safely if
   memory sync moves the remote, push, and prepare the next natural-cut handoff.
   You will know this worked when local `HEAD` equals `origin/main`, unrelated
   untracked files remain, and a fresh session can start step 2 without chat.

## 7. Constraints and gotchas in force

- Work on `main`. Preserve unrelated `.ai/` and
  `docs/claude-remote-control-hardening-v2.md`.
- Do not trim global or repo instructions yet.
- Never read or expose secrets, `.env` values, transcript contents, chat
  archives, auth files, or licensed private data.
- No production, shared-cloud, database, NAS, Coolify, Supabase, or Terraform
  mutation is in scope.
- GPT-5.6 must remain at low or medium reasoning effort.
- Before every commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Use `C:\Program Files\Git\bin\bash.exe` for Bash tests on this machine. A bare
  `bash` is WSL.
- Do not claim Kimi token, cache, cost, or returned-model data. None is exposed.
- Never rewrite root `HANDOFF.md` or edit another session's handoff.

## 8. Access and environment

- Repo: `C:\repos\ai-devops`.
- Remote: `https://github.com/u2giants/ai-devops`.
- Branch: `main`.
- Last pushed baseline and handoff commit before this plan update: `605156d`.
- Kimi review session: `context-engineering-step1-review`, explicit session id
  `session_387932ad-2236-47f4-ba77-599d389c4dbf`.
- GLM review session that failed to answer:
  `context-engineering-consolidation-review`.
- No secret or 1Password access is needed. If an unrelated need appears,
  secrets live only in 1Password vault `vibe_coding`, never in source or prompts.
- There is no hosted deployment or CI service to verify.

## 9. Open questions and risks

- Decide the exact whitespace semantics for folded versus literal descriptions
  in the parser implementation. The test should document that choice. This is an
  engineering choice with a reversible local impact, not an owner decision.
- The corrected real manifest totals are unknown until the audit is rerun. Do
  not copy Kimi's rough percentages into the baseline as final measurements.
- The duplicate-paragraph discrepancy may be a documented method difference or
  a detector bug. Compare the original audit method before changing code.
- GLM's implementation review remains unavailable. Do not block the parser fix
  on it, and do not pretend it approved or rejected the work.

## Mandatory self-audit

1. Yes. Sections 1-3 explain the toolkit, goal, exact defect, current plan state,
   and unchanged scope so a newcomer can continue without chat context.
2. Yes. Sections 4-5 preserve the failed GLM attempts, missing fixture, stable
   but wrong measurement lesson, and all accepted Kimi findings.
3. Yes. Section 6 gives ordered file-specific actions with a verification gate
   for each. Sections 7-9 preserve constraints, access, uncertainties, and the
   no-secrets boundary.
4. Yes. A line-by-line sweep of sections 1-9 found no decision requiring Albert.
   Section 0 says so explicitly and records the already-settled choices.

All ten required sections are present. No secret values are included. The
handoff self-audit passed on 2026-08-12.
