# Documentation health (`ai-doc-health`)

`bin/ai-doc-health` measures the documentation rules that used to live only in
prose: router size, document size, document headers, a generated index, stray
root files, old handoffs and duplicates. It is **advisory** — it never blocks a
merge (owner ruling 2026-10-30). Its teeth are a pull-request comment, a weekly
run that keeps one rolling `Documentation health` issue per repository, and the
session-end skills, which run it and fix what the session caused.

Origin and reasoning: popcre/designflow-backend issue 391 and that repo's
`plan_docs-lookup-cleanup-and-upkeep.md`. Reachability itself stays with
[`ai-doc-reachability`](doc-reachability.md); this tool calls it.

## Use

```bash
python3 bin/ai-doc-health --repo <path>              # list faults; exit 0 clean, 1 faults, 2 config error
python3 bin/ai-doc-health --repo <path> --fix-index  # rewrite the index from document headers
python3 bin/ai-doc-health --repo <path> --json
python3 bin/ai-doc-health --repo <path> --siblings ../other-repo ...   # cross-repo duplicates
```

Only files listed by `git ls-files` are judged. Each fault is one line:
`<check-id> <path> <plain reason>`.

## Config: `.doc-health.json` at the repository root

```json
{
  "exclude": ["shared-db/**", "node_modules/**", ".claude/**", "docs/archive/**"],
  "router": "AGENTS.md",
  "router_max_bytes": 30000,
  "living_max_bytes": 60000,
  "handoff_dir": "HANDOFF.d",
  "handoff_max_age_days": 30,
  "index": "docs/INDEX.md",
  "header_exempt": ["AGENTS.md", "CLAUDE.md", "README.md", "HANDOFF.md", "HANDOFF.d/**"],
  "root_markdown_allow": ["AGENTS.md", "CLAUDE.md", "README.md", "HANDOFF.md", "plan_*.md"],
  "status_stale_days": 120
}
```

Every key is optional and defaults to the value shown, except `exclude`, which
defaults to empty. A missing file or a wrong type is exit 2.

## Document header

Every Markdown file that is not exempt opens with this front matter, closed
within the first 2 KB. Other keys may sit beside these four.

```yaml
---
summary: One sentence, at most 160 characters, saying what is in here.
kind: living | ops | plan | spec | proof | archive
status: current | open | done | stale
read-when: Short phrase naming the task that needs this file.
---
```

The index file is built from these headers: one section per kind, one row per
document. Never edit the index by hand; edit the header and run `--fix-index`.

## Checks

| id | Fault |
|---|---|
| `router-size` | router file larger than `router_max_bytes` |
| `living-size` | a document over `living_max_bytes` whose kind is not plan, proof or archive |
| `header-missing` | a non-exempt document without a valid header |
| `index-stale` | the committed index differs from what the headers produce |
| `unreachable` | no chain of links from a root reaches the file; runs only when `.doc-reachability.json` exists |
| `root-stray` | a root Markdown file that `root_markdown_allow` does not name |
| `handoff-old` | a handoff whose file-name date is older than `handoff_max_age_days`, or has no date |
| `dup-in-repo` | two tracked documents with identical bytes |
| `dup-across` | with `--siblings`, a document identical to one in a sibling repository; files under 600 bytes are pointers and are skipped, as are header-exempt files |
| `status-stale` | status is open or current but no commit touched the file in `status_stale_days`; skipped in a shallow clone |

## Tests

```bash
python3 tests/test-ai-doc-health.py
```

Retirement path: if `ai-doc-safety` absorbs these checks, this command becomes
a thin alias and is then removed.
