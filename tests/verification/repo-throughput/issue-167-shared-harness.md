# Issue #167 — shared offline test harness

## Outcome

`tests/lib-test-harness.sh` now owns the byte-equivalent `ok`, `bad`, `skip`,
and quiet `check` behavior used by 29 Bash suites. Existing human output,
counters, final summaries, exit conditions, and every assertion remain in the
suites. When `AI_TEST_REPORT_FILE` is set, the shared functions additionally
append stable tab-separated `suite`, `status`, and `check identity` fields, so
automation does not have to parse prose.

Suites with genuinely different contracts were not coerced into the shared
implementation: TAP output, lowercase counters, multi-value comparisons,
immediate-exit checks, and checks which deliberately expose command output stay
local. This is the bounded migration boundary.

## Assertion map

The change removes helper definitions only. No migrated assertion call or
suite-final exit condition changed. Counting the migrated suites' `check`
calls at `origin/main` and after migration gives `1563 -> 1563`; the three
manual-assertion suites in the batch likewise have no non-helper diff.

| Migrated scope | Suites | Before | After |
|---|---:|---:|---:|
| Shared-helper batch | 29 | 1,563 | 1,563 |

## Failure injection and focused proof

`tests/test-lib-test-harness.sh` injects a false command. It records that check
as failed, increments the failure counter, makes the fixture exit nonzero, and
then byte-compares the three expected TSV records for pass, fail, and skip.
Focused Windows Git Bash results:

- shared harness: PASS, including the injected nonzero case; under 1 second;
- `test-ai-codex-memories.sh`: 18 passed, 0 failed; 2 seconds;
- `test-ai-memory-index-hook.sh`: 23 passed, 0 failed; 6 seconds;
- custom-comparison preservation: 54 passed, 0 failed; 5 seconds;
- platform-policy preservation: 32 passed and 44 passed, 0 failed; 8 seconds.

An enabled-report run of `test-ai-codex-memories.sh` produced 18 records with
the exact suite identity and 18 existing check labels, while the suite still
returned zero.

## Mapping decision

#163 deliberately established coarse change categories, not a per-suite
dependency graph. Its evidence contains no measured unnecessary-work saving
that would justify the maintenance and false-omission risk of a finer graph.
Therefore #167 adds no per-suite path mapping. No-argument, scheduled, manual,
and qualification selections remain complete; pull-request Windows coverage
continues to use the stable aggregate check independently of section count.

## Landing evidence

The pull-request and complete scheduled/manual matrix run IDs are recorded here
after exact-head verification and merge.
