# Handoff: step 1 correction implemented, step 2 is now the open work

## 0. Decisions only the owner can make

None. Everything in this session was an authorized, local, testable correction
already specified in the plan's step-1 correction brief.

Already settled, do not re-ask:

- Safety and correctness outrank token reduction.
- Work proceeds phase by phase. Step 1 is now closed; step 2 is next.
- Kimi's review was advisory. Its parser finding was independently confirmed
  against source before being accepted, and is now fixed.
- Folded YAML descriptions join a paragraph's lines with single spaces; literal
  descriptions keep every line break. This whitespace choice is documented in
  the audit README and asserted in the test.

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

The prior session
([`2026-08-12T1431Z-al8960ofc-codex-kimi-baseline-correction.md`](2026-08-12T1431Z-al8960ofc-codex-kimi-baseline-correction.md))
recorded a confirmed measurement bug in the step-1 context audit but did not
implement the fix. It marked step 1 `correction open` and listed a six-part
correction with a verification gate. Albert asked this session to execute that
correction. This session implemented all six parts and closed step 1.

## 3. Current state, what is true right now

Code and tests:

- `tools/context-audit/context-audit.py` now parses YAML block scalars. New
  helpers `dedent_block()` and `block_scalar()` plus a rewritten `frontmatter()`
  handle `>`, `>-`, `>+`, `|`, `|-`, and `|+` with no new dependency. Nested
  (indented) frontmatter keys are now skipped rather than flattened into the
  same dictionary, which is a small behavior improvement; only `name` and
  `description` are consumed downstream.
- `tests/test-context-audit.ps1` adds two fixtures: a Claude-only skill with a
  folded (`>-`) multi-paragraph description written with LF endings, and a
  Codex-only skill with a literal (`|-`) description written with CRLF endings.
  It asserts three tracked skills, two skills per client manifest, exact folded
  and literal description strings, that no skill description is a bare scalar
  marker, and that neither manifest falls below 100 bytes.

Verification actually run, all on `al8960ofc`:

- The new test **fails** against the pre-fix parser (`git checkout` of the old
  file) with `Skill 'folded' recorded a block-scalar marker instead of its
  description.`, and **passes** after the fix.
- Two real audits of `C:\repos\ai-devops` with `--generated-at fixed-run` are
  byte-identical.
- `tests/test-ai-install-skills.sh`, `tests/test-ai-memory-sync.sh`,
  `tests/test-install-ai-devops-windows.ps1`, `tests/test-mcp-env-launch.ps1`,
  and `tests/test-memory-sync-scheduled-task.ps1` all pass.

Corrected real measurements (from the rerun of the fixed tool):

| Client | Skills | Old bytes | Corrected bytes | Corrected tokens |
|---|---:|---:|---:|---:|
| Claude | 35 | 18,448 | 21,521 | about 5,381 |
| Codex | 30 | 10,593 | 14,015 | about 3,504 |

The other summary values are unchanged: always-loaded 2 files / 33,311 bytes;
startup-routed 2 files / 49,401 bytes; task-triggered 48 files / 405,271 bytes;
0 duplicate skill names; 12 duplicate paragraph groups; 0 broken links; 6
installed-source drifts (4 skills plus 2 globals); 0 installer parity
differences; 0 missing safety markers.

Docs updated: `docs/context-engineering.md` (corrected totals, a paragraph
recording the superseded values and why, duplicate-count reconciliation, and
installer language changed to static capability matching);
`docs/development.md` (lists `pwsh -NoProfile -File tests/test-context-audit.ps1`);
`tools/context-audit/README.md` (bytes not characters, plus the block-scalar
and CRLF parsing contract); `plan_context-engineering-consolidation.md` (step 1
marked done with evidence, fresh-session start now points at step 2, correction
brief marked closed, duplicate-count row and finding corrected).

Unrelated untracked paths `.ai/` and
`docs/claude-remote-control-hardening-v2.md` were not touched.

## 4. Everything we tried that did not work

1. The first version of the manifest-size assertion compared the Claude and
   Codex manifest byte totals against each other. That was fragile and
   fixture-order dependent. It was replaced with a simple per-client floor of
   100 bytes, which the old marker-only parser could not reach for these
   fixtures.
2. Attempts to reproduce the earlier manual count of fourteen duplicate
   paragraph groups all failed. Lowering the minimum normalized paragraph length
   to 120 and then 100 characters still returns 12 over skill files. Widening
   the scope to all tracked Markdown returns 92, not 14. Counting duplicate
   instances gives 24, distinct file pairs gives 3, and files involved gives 6.
   No metric yields 14, so 14 is recorded as a superseded manual estimate rather
   than a method difference or a detector bug.
3. Carried forward from the prior session, still true: the persistent GLM
   session `context-engineering-consolidation-review` accepted the
   implementation-review prompt but never returned an answer, across three
   attempts including a service restart. Do not report a GLM verdict on this
   work.

## 5. Root causes and key findings

- The original parser was a deliberate dependency-free `key: value` splitter. It
  had no concept of continuation lines, so any YAML block scalar collapsed to
  its marker. Seven tracked skills use `description: >-`.
- CRLF was never the root cause. Python text-mode reads normalize line endings,
  so a CRLF fixture is a regression guard, not a fix. The new CRLF fixture
  passes for exactly that reason.
- Kimi's rough estimate was that the totals were low by about 19 percent
  (Claude) and 37 percent (Codex). The measured corrections are about 16.7
  percent and 32.3 percent. Use the measured numbers, never the estimates.
- The lesson that generalizes: a two-run byte-equality gate proves determinism,
  not semantic correctness. Step 1 originally passed its stability gate while
  publishing wrong numbers, because the fixture used only a one-line
  description.

## 6. Exact next steps

1. Read `AGENTS.md`, this handoff, and the full active plan, re-reading plan
   sections 1, 4, 8, 11, and 13. You will know this worked when you can state
   that step 1 is done and step 2 is the first open row.
2. Begin step 2, the context ownership map, as written in plan sections 8 and 9.
   You will know this worked when every fact class has exactly one named
   canonical owner file and the documentation maps in `AGENTS.md`,
   `docs/skills-usage-guide.md`, and `docs/codex-skills-usage-guide.md` agree.
3. Do not re-trim anything in step 2. Step 2 is a map, not an edit of global or
   repo instructions. Trimming belongs to steps 4 and 5.
4. If you change the audit tool again, run
   `pwsh -NoProfile -File tests/test-context-audit.ps1` first and confirm it
   still passes. You will know this worked when the command exits zero.

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
- The real audit must be run with `--root C:/repos/ai-devops`, not the worktree,
  if you want numbers comparable to the published baseline. In practice both
  give the same totals because `tools/` and `tests/` are not measured classes.

## 8. Access and environment

- Repo: `C:\repos\ai-devops`. This session worked in the git worktree
  `C:\repos\ai-devops-worktrees\codex-kimi-baseline-correction-784c58` on branch
  `claude/codex-kimi-baseline-correction-784c58`, which is merged to `main`.
- Remote: `https://github.com/u2giants/ai-devops`.
- Reproduce the audit:
  `python tools/context-audit/context-audit.py --root C:/repos/ai-devops --generated-at fixed-run --claude-home "$env:USERPROFILE\.claude" --codex-home "$env:USERPROFILE\.codex"`
- Kimi review session from the prior session: `context-engineering-step1-review`,
  id `session_387932ad-2236-47f4-ba77-599d389c4dbf`. Its saved review is
  untracked at
  `.ai/reviews/kimi-context-engineering-step1-review-20260812T142135Z.md`.
- No secret or 1Password access is needed. If an unrelated need appears, secrets
  live only in 1Password vault `vibe_coding`, never in source or prompts.
- There is no hosted deployment or CI service to verify.

## 9. Open questions and risks

- The `+` chomping variants (`>+`, `|+`) are normalized to a single trailing
  newline rather than preserving every trailing blank line. This is a deliberate
  determinism choice, documented in the README, and no tracked skill uses them.
  If a skill ever needs true keep-chomping, change the parser and the test
  together.
- The parser now ignores indented frontmatter keys such as `metadata: type:`.
  Nothing downstream reads them today. If a future step needs nested metadata,
  the parser must be extended rather than reverted.
- Drift detection is byte-hash based and therefore line-ending sensitive. Run
  from `C:\repos\ai-devops` the real audit reports 6 drifts (4 skills, 2
  globals), matching the published baseline. Run from this session's worktree at
  the same commit it reports 12, because that working copy normalized CRLF
  differently for `ask-glm`, `deepseek-second-opinion`, and
  `implementation-plan-writer`. The content is identical; only the bytes differ.
  This is now documented in `docs/context-engineering.md`. If a future step
  wants drift to be checkout-independent, hash normalized text rather than raw
  bytes, and update the test with it.
- Installer parity is still only a static capability check over both installer
  texts. It is not behavioral proof. Do not upgrade the claim without a real
  behavioral test.
- GLM's implementation review remains unavailable. Do not block anything on it,
  and do not pretend it approved or rejected the work.

## Mandatory self-audit

1. Yes. Sections 1-3 explain the toolkit, the goal inherited from the prior
   session, exactly what changed, the corrected numbers, and the verification
   evidence, so a newcomer can continue without chat context.
2. Yes. Section 4 preserves the fragile assertion that was replaced, every
   failed attempt to reproduce the fourteen-group count with the metrics tried,
   and the still-unavailable GLM review.
3. Yes. Section 6 gives ordered next actions with verification gates. Sections
   7-9 preserve constraints, access, whitespace and chomping decisions,
   remaining uncertainties, and the no-secrets boundary.
4. Yes. A line-by-line sweep of sections 1-9 found no decision requiring Albert.
   Section 0 says so explicitly and records the already-settled choices.

All ten required sections are present. No secret values are included. The
handoff self-audit passed on 2026-08-12.
