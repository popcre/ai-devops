#!/usr/bin/env bash
# Trivial suite A for the merge-queue batching live proof (#1023, Step 5 of
# plan_split-ci-suite-manifest.md). Throwaway by design: this suite and its
# sibling test-queue-batch-b.sh are added by two independent PRs that touch
# only their own suite file and per-suite manifest entry, enter the merge
# queue together, and are retired by the evidence PR once the shared batch is
# recorded in tests/verification/repo-throughput/manifest-split-2026-09.md.
set -euo pipefail
printf 'PASS: queue-batch-a trivial suite ran\n'
