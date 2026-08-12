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
the characters-divided-by-four value as an estimate. It is not a provider token
or billing claim.

The audit gets tracked source paths from `git ls-files`. In a fixture without a
Git checkout, it uses a deterministic sorted file walk. It skips `.git`, `.ai`,
transcripts, chat archives, dependencies, generated output, worktrees, secret
file suffixes, and network roots. It never reads secret values.

Run the focused regression test with:

```powershell
pwsh -NoProfile -File tests/test-context-audit.ps1
```
