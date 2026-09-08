# Issue #163 — targeted local test selection

Evidence for the acceptance criteria on
[#163](https://github.com/popcre/ai-devops/issues/163). All checks were run on
`edge-dev` (Windows, Git Bash) against branch `claude/issue-163-test-selection`.

## What shipped

- `tests/lib-selection.sh` — coarse selection logic. Reuses
  `tools/ci/classify-changes.sh` for the prose decision rather than
  re-implementing it, then derives `skills` / `workflow` / `powershell` / `code`
  categories. No per-suite dependency graph, by design.
- `tests/test-all.sh` — new `--only <pattern>`, `--changed-since <ref>` and
  `--list` options. No arguments behaves exactly as before.
- `tests/test-test-selection.sh` — nine assertions, added to the
  `fast-classifier` workflow so selection is proved on every change.
- `config/ci-suite-manifest.json` and `tests/test-workflow-policy.sh` — the new
  suite is declared; the exact-discovery assertion still passes.

## Acceptance evidence

| Criterion | Command | Result |
| --- | --- | --- |
| No arguments still runs everything | `bash tests/test-all.sh --list` | `BASH SELECTION every Bash suite selected=66 of 66` |
| `--only grok-review` runs one suite | `bash tests/test-all.sh --only grok-review --list` | `selected=1 of 66`, `test-ai-grok-review.sh` |
| Invalid selection fails loudly | `bash tests/test-all.sh --only zzznope --list` | exit `2`, `--only zzznope matched no suite of 66` |
| Invalid ref fails loudly | `bash tests/test-all.sh --changed-since nope123 --list` | exit `2`, `is not a commit in this repository` |
| Documentation-only range selects no long suite | `bash tests/test-all.sh --changed-since eb3a87bc^` at `eb3a87bc` (a HANDOFF.d-only commit) | `categories=prose selected=0 of 65`, `No Bash suite is relevant to these changes; skipping the long suite by design.`, exit `0` |
| `skills/` change selects the skills category | `tests/test-test-selection.sh` case 2 and 9 | `skills` → `test-ai-adopt-globals.sh test-ai-install-skills.sh test-markdown-links.sh` |
| Workflow change selects the workflow category | case 3 | `.github/workflows/verify.yml` → `workflow` |
| PowerShell change selects no Bash suite and is reported | case 4 and 8 | `tests/test-all.ps1` → `powershell`, zero Bash suites, `NOTE ... run tests/test-all.ps1` |
| `bin/` change selects everything | case 5 | `bin/ai-facts` → `code` |
| Mixed change keeps every category | case 6 | `skills workflow code` |
| Selection tests are fast and in the fast workflow | `bash tests/test-test-selection.sh` | `SELECTION SUMMARY tests=9 failures=0`, under one second; wired into `fast-classifier.yml` |
| Workflow policy still green | `bash tests/test-workflow-policy.sh` | `PASS: fast routing and both Windows lanes are preserved ...` |

## Guardrails honoured

No assertion was deleted, quarantined, made allowed-to-fail, or given a longer
timeout. The complete run remains the default and the authoritative gate;
selection only adds a faster first signal for local diagnosis.
