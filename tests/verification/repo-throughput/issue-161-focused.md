# Issue #161 focused verification

Verified on EDGE-DEV on 2026-09-01 against the candidate source immediately
before this evidence-only file was added.

| Gate | Result |
|---|---|
| `bash -n tools/ci/classify-changes.sh tests/test-workflow-policy.sh` | pass |
| `bash tests/test-workflow-policy.sh` | pass; routing, fail-closed dependency, 61+17 manifest, and behavioral Windows lock assertions |
| `pwsh -NoProfile -File tests/fixtures/ci/test-edge-dev-serialization.ps1` | pass; two processes serialized, wait/body bounds enforced, descendant killed, mutex reacquired |
| Parse `verify.yml` and `fast-classifier.yml` as YAML | pass |
| `git diff --check` | pass |

The complete 61 Bash plus 17 PowerShell proof remains a required pull-request
CI gate. It was not run locally while EDGE-DEV was serving active Actions work;
queued, partial, or overlapping local execution is not accepted as evidence.
