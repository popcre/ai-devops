# Context audit

This read-only tool measures the instruction and skill context owned by this
repository. It uses only the Python standard library. It does not install a
command or change machine configuration.

Run it from the repository root:

```powershell
python tools/context-audit/context-audit.py `
  --root . `
  --json .ai/context-audit/baseline.json `
  --summary .ai/context-audit/baseline.txt `
  --claude-home "$env:USERPROFILE\.claude" `
  --codex-home "$env:USERPROFILE\.codex"
```

Generated reports belong under `.ai/` and are not committed. The report labels
the bytes-divided-by-four value as an estimate. It is not a provider token
or billing claim.

Skill frontmatter is parsed without a YAML dependency. Single-line values and
YAML block scalars (`>`, `>-`, `|`, `|-`, and the `+` forms) are supported.
Folded values join a paragraph's lines with single spaces and keep one newline
between paragraphs; literal values keep every line break. Windows CRLF files
parse identically to LF files.

The audit gets tracked source paths from `git ls-files`. In a fixture without a
Git checkout, it uses a deterministic sorted file walk. It skips `.git`, `.ai`,
transcripts, chat archives, dependencies, generated output, worktrees, secret
file suffixes, and network roots. It never reads secret values.

## Warning budgets

`budgets.json` holds one warning budget per always-loaded or startup context
class. **Budgets only warn. They never change the exit status**, not even with
`--strict`. Each entry has two numbers:

- `budget` — the size measured at the last accepted baseline, so any growth
  warns immediately.
- `target` — the smaller number the reduction steps are aiming for.

Tighten `budget` toward `target` only after a measured reduction has actually
landed and its behavior tests still pass. Never raise a budget to silence a
warning. Point `--budgets <file>` at a different file to try other numbers.

## Enforcement checks

- **Safety markers.** Six locked categories (production mutation, shared
  database routing, secret handling, destructive actions, Git identity, the
  GPT-5.6 low/medium limit, and protection of operating-system binaries) must be present in the always-loaded and
  startup-routed files. A missing category is reported with a plain-English
  sentence saying what protection was lost.
- **Cross-client parity.** Rules that must hold for both clients are checked in
  both `CLAUDE-global.md` and `AGENTS-global-codex.md`. A rule present in only
  one is a mismatch. Genuinely client-specific text lives in the divergence
  allowlist; if an allowlisted entry shows up in both globals, the allowlist
  entry itself is reported as stale.
- **Global vs skill-description overlap.** Both are startup context, so a
  sentence repeated in an always-loaded global and a skill description is paid
  for twice. Shared ten-word phrases are reported with an example.

`--strict` exits 1 for a missing safety marker, a parity mismatch, or a stale
allowlist entry. Budget overruns stay warnings in every mode.

## Skill selection quality

Size is not trigger quality. Use the trigger evals for that:
`tools/skill-trigger-eval/skill-trigger-eval.py` (Claude) and
`tools/skill-trigger-eval/codex-trigger-eval.py` (Codex). Neither replaces this
audit, and this audit does not replace them.

Run the focused regression test with:

```powershell
pwsh -NoProfile -File tests/test-context-audit.ps1
```
