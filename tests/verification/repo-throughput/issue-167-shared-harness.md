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

## Complete-matrix finalization allowance

The exact-head manual matrices on `c0199e8f` established a separate workflow
boundary: runs `34445127896` and `34445717137` completed the substantive full
Windows suite at 99m56s and 99m59s, respectively, but GitHub cancelled the job
at its 100-minute ceiling before finalization could publish a successful job
result. The stable aggregate therefore failed closed even though the suite had
passed. This was not an assertion failure and it is not addressed by narrowing
the complete backstop.

The complete-matrix ceiling is now exactly 105 minutes: the existing bounded
100-minute suite allowance plus five minutes for checkout cleanup and result
publication. `tests/test-workflow-policy.sh` rejects any other value, so this
is a measured finalization allowance rather than an open-ended timeout increase.
The focused policy test passed after the repair.

## Complete exact-head evidence

Manual run [34479418193](https://github.com/popcre/ai-devops/actions/runs/34479418193)
completed successfully on `3ec1af0a23ff4cccc882f0a335d04e80e48f9ddd`.
Its unsectioned `windows-offline-complete` backstop ran from 12:54:53Z to
14:36:26Z (101m33s), then the stable `windows-offline` aggregate published
success at 14:36:35Z. The same run also passed `linux-offline` and the qualified
`windows-reviewer-safety` lane; its conditional section and fallback jobs were
correctly skipped for the manual complete-matrix route.

This is the first complete-matrix result after the 105-minute guardrail. It
preserves the entire full Windows-and-Bash suite, proves result publication, and
leaves 3m27s inside the fixed job bound. A later documentation-only handoff
commit does not alter the tested workflow or harness source; final independent
approval and pull-request gates are bound to the current branch head before
merge.
