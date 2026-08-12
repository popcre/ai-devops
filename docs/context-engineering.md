# Context engineering

This document records the measured baseline for reducing repeated Claude and
Codex context safely. The active implementation and decisions remain in
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

## Baseline frozen on 2026-08-12

The dependency-free audit at
[`../tools/context-audit/context-audit.py`](../tools/context-audit/context-audit.py)
measures four context classes:

| Class | Meaning | Current measured source |
|---|---|---:|
| Always loaded | User-level Claude and Codex global templates | 2 files, 33,311 bytes, about 8,329 estimated tokens |
| Startup routed | This repo's `AGENTS.md` and `CLAUDE.md` entry files | 2 files, 49,401 bytes, about 12,351 estimated tokens |
| Task triggered | Skill bodies read only when selected | 48 files, 405,271 bytes, about 101,333 estimated tokens |
| Archive or ignored | Transcripts, chats, `.ai`, dependencies, generated output, worktrees, secrets, and network roots | excluded and never opened |

The estimate is bytes divided by four, rounded up per file. It is useful for
comparison only. It is not an exact model-token count and is not a billing
claim. The 48 skill bodies are not startup context.

Skill selection metadata is measured separately because clients need names and
descriptions before they can choose a skill:

| Client | Available skills | Name and description bytes | Estimated tokens |
|---|---:|---:|---:|
| Claude | 35 | 21,521 | about 5,381 |
| Codex | 30 | 14,015 | about 3,504 |

These manifest totals were corrected on 2026-08-12. The first published values
(Claude 18,448 bytes, Codex 10,593 bytes) were understated because the audit's
frontmatter parser read only single-line values and recorded the bare marker
`>-` for the seven skills that use folded YAML descriptions. The parser now
handles YAML block scalars, a regression test covers folded and CRLF
frontmatter, and the numbers above come from a rerun of the corrected tool.
Do not reuse the superseded values.

The first real-machine report found:

- no duplicate skill names;
- 12 exact normalized paragraph groups shared by two or more skill files,
  spanning 6 skill files and 3 distinct file pairs. An earlier manual estimate
  of 14 groups is superseded: it is not reproducible at any tested minimum
  paragraph length (100, 120, or 180 normalized characters), all of which
  return 12 over skill files. The tool's 12 is the measured number;
- no broken relative Markdown links in the audited router, plan, handoff
  pointer, global files, or skill files;
- no static capability difference between the current Bash and PowerShell
  installers for managed markers, collision refusal, orphan quarantine,
  non-clobbering global installation, and dry-run support. This is text pattern
  matching over both installers, not proof of full behavioral parity;
- all six required safety categories present;
- four installed skill files different from tracked source on `al8960ofc`;
- both installed global files different from source, as expected because local
  machine facts were appended under the current non-clobber policy.

The four drifted installed skills are Claude `shared-db-handover`, Claude
`shared-db-orchestrator`, Claude `kimi-code-delegation`, and Codex
`kimi-code-delegation`. This baseline only reports drift. It does not overwrite
or reconcile anything.

Drift is a SHA-256 comparison of raw bytes, so it is sensitive to line endings.
Running the audit from a different working copy of the same commit, such as a
Git worktree checked out with different CRLF normalization, can report extra
drifted skills that have identical content. Always measure drift from
`C:\repos\ai-devops` for comparability with this baseline.

## Reproduce the baseline

From `C:\repos\ai-devops` on Windows:

```powershell
python tools/context-audit/context-audit.py `
  --root . `
  --json .ai/context-audit/baseline.json `
  --summary .ai/context-audit/baseline.txt `
  --claude-home "$env:USERPROFILE\.claude" `
  --codex-home "$env:USERPROFILE\.codex"

pwsh -NoProfile -File tests/test-context-audit.ps1
```

Two runs with the same `--generated-at` value must produce byte-identical JSON.
The fixture test proves that `.env`, `.ai`, transcript, and dependency content
does not enter the report.

## Current boundary

This is phase A, step 1 only. No global, repo instruction, skill, installer, or
machine file has been trimmed or changed. The ownership map and warning budgets
belong to later plan steps.
