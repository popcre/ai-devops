# Issue #161 verification baseline

Captured 2026-09-01 from the GitHub Actions API before the fast classifier
landed. Durations are wall-clock job durations, including setup and teardown.

| Evidence | Event / source | Linux | Windows complete | Windows reviewer | Result |
|---|---|---:|---:|---:|---|
| Run 32967607403 | pull request, `39a8785d` | 9m 1s | 64m 47s | 14m 32s | success |
| PR 102 | merged as `1eede15d` | API does not retain a change-type label | API limitation | API limitation | merged |

The pre-change workflow had no independent classifier timing, so classifier
p50/p90 and prose-only completion could not be measured before implementation.
Record those from live #161 runs after merge; do not infer them from the long
job totals. At this baseline the repository discovers 61 Bash suites and 17
PowerShell suites, recorded exactly in `config/ci-suite-manifest.json`.

Fresh queue evidence on 2026-09-01 showed many pull-request, push, and
merge-group runs queued or cancelled while two logical runner registrations
shared EDGE-DEV. That evidence supports serialization here but does not prove
independent capacity; issue #209 retains that ownership.

GitHub Actions concurrency groups retain at most one pending job, so a shared
job-level group would cancel older queued required checks even with active-job
cancellation disabled. The interim EDGE-DEV control therefore uses one
machine-wide named mutex inside both jobs; it serializes execution without
discarding queued workflow jobs.

Merge groups deliberately retain the complete matrix at this phase. Issues
#162 and #164 own the measurement and proof needed before replacing it with a
short compatibility gate; #161 does not guess or weaken that coverage early.
