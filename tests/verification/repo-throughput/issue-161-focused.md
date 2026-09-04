# Issue #161 focused verification

Verified on EDGE-DEV on 2026-09-03 against the candidate source immediately
before this evidence-only file was updated, after merging `origin/main` at
`baa3ac1b`.

| Gate | Result |
|---|---|
| `bash -n tools/ci/classify-changes.sh tests/test-workflow-policy.sh` | pass |
| `bash tests/test-workflow-policy.sh` | pass; 26 assertions covering routing, fail-closed dependency, both Windows lanes, and the 63+18 manifest |
| Parse `verify.yml` and `fast-classifier.yml` as YAML | pass |
| `git diff --check` | pass |

The complete 63 Bash plus 18 PowerShell proof remains a required pull-request
CI gate. It was not run locally while EDGE-DEV was serving active Actions work;
queued, partial, or overlapping local execution is not accepted as evidence.

## EDGE-DEV serialization removed on 2026-09-03

The original candidate carried `tools/ci/edge-dev-serialization.ps1` and a
behavioral fixture for it, to stop two Windows jobs colliding while both ran on
the single EDGE-DEV desktop. Issue #209 closed that gap in the runner
architecture instead: the long `windows-offline` matrix moved to GitHub's
hosted `windows-2025` lane, and `windows-reviewer-safety` runs on the qualified
self-hosted pool where each physical host registers exactly one runner. Issue
#161's own scope makes the mutex conditional on that — "Until #209 qualifies
independent hosts" — so with #209 closed the wrapper was unreferenced by any
workflow. Unwired safety machinery is worse than none, because it reads as
protection that is not in force. Removed rather than left dormant; git history
preserves it if a future single-host arrangement ever needs it back.
