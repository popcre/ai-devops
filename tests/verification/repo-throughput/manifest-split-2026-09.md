# CI suite manifest split — implementation evidence (2026-09-28)

Owner issue: [#1001](https://github.com/popcre/ai-devops/issues/1001). Plan:
`plan_split-ci-suite-manifest.md` Steps 1–4. Collision proof:
[manifest-collision-2026-09.md](manifest-collision-2026-09.md).

## What changed

- `tools/ci-suites/load-manifest` (+ `load-manifest.jq`): assembles the legacy
  reader-shaped manifest (schema_version 2 contract) from the slim global file
  plus one JSON file per suite in `config/ci-suites/`. Fails closed naming the
  offending file on: malformed JSON, unknown kind, duplicate membership tags,
  reviewer-safety without offline, non-integer or bash-only `linux_seconds`,
  out-of-range `windows_section`, a section-less offline suite when sections
  are declared, and an empty declared section (other than the PowerShell
  owner).
- `config/ci-suites/<suite-file-name>.json`: 132 files generated 1:1 from the
  monolith (104 bash, 27 powershell, plus the new loader suite). Each holds
  `kind`, optional `linux_seconds`, `windows` membership tags, optional
  `windows_section`.
- `config/ci-suite-manifest.json` (schema_version 3) now carries only:
  `windows_offline_section_count`, `windows_offline_powershell_shard`,
  `suspended_bash`, `suspended_powershell`, `_comment_suspended`,
  `affected_suite_rules`. A policy check rejects any reintroduced per-suite
  array or map there and is proven on a mutated copy.
- Readers switched: `tests/test-all.sh` (cached loader snapshot for
  inventories/seconds/membership/sections; `suspended_bash` still read from the
  global file), `tests/test-workflow-policy.sh` (pins loader output),
  `tests/test-all.ps1` (a Bash suite's own `.sh.json` no longer forces the
  PowerShell run; the global file or a `.ps1.json` still does).
- `config/ci-suites/**` and `tools/ci-suites/*` added to the select-all globs
  and `config/reviewer-ci-paths.txt`; both trees pinned `eol=lf`.

## Gates and local results (2026-09-28, edge-dev worktree)

- Step 1/2 equality gate: `bash tools/ci-suites/load-manifest | jq -S .`
  equals `jq -S 'del(.windows_offline_section_count)'
  config/ci-suite-manifest.json` byte for byte, re-verified after migration
  and after registering the new loader suite (the one added global key is the
  section count the loader derives sections from).
- Step 3 membership gate: Windows sections 1–6 listed via
  `tests/test-all.sh --windows-offline --exclude-reviewer-safety --shard i/6
  --list` are identical to `git show 7f4a5f3d:config/ci-suite-manifest.json`
  shard arrays (diff empty after CR normalization; only intra-section run
  order is now canonical).
- Suites on this tree: `tests/test-workflow-policy.sh` PASS (incl. new
  slim-manifest checks); `tests/test-ci-suite-loader.sh` 17 passed, 0 failed;
  `tests/test-linux-offline-shards.sh` 27 passed; `tests/test-windows-bash-selection.sh`
  48 passed; `tests/test-test-selection.sh` 21 selected, 0 failures;
  `tests/test-reviewer-ci-paths.sh` PASS (48 dependencies).
- PowerShell platform gating proved per path class: `config/ci-suites/x.sh.json`
  skips the PowerShell run; `x.ps1.json` and the global manifest force it.

Exact-head GitHub verification and the Step 5 parallel-merge proof remain the
merge-time gates.
