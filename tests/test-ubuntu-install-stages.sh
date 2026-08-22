#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

required=(dependencies directories config tools skills identity permissions memory doctor node-toolchain)
for stage in "${required[@]}"; do
  output="$(AI_INSTALL_TEST_FAIL_STAGE="$stage" bash "$ROOT/install.sh" --test-stage-runner 2>&1)" &&
    fail "required stage $stage returned success"
  grep -Fq "REQUIRED stage failed: $stage" <<<"$output" ||
    fail "required stage $stage was not named"
  grep -Fq 'Install stage summary' <<<"$output" ||
    fail "required stage $stage did not reach the summary"
done

output="$(AI_INSTALL_TEST_FAIL_STAGE=optional-provider bash "$ROOT/install.sh" --test-stage-runner 2>&1)" ||
  fail 'optional stage made install nonzero'
grep -Fq 'Optional stage failed: optional-provider' <<<"$output" ||
  fail 'optional failure was not named'

AI_INSTALL_TEST_NODE_MODE=present bash "$ROOT/install.sh" --test-stage-runner >/dev/null ||
  fail 'present node/npm/npx fixture failed'
if AI_INSTALL_TEST_NODE_MODE=missing bash "$ROOT/install.sh" --test-stage-runner >/dev/null 2>&1; then
  fail 'missing node/npm/npx fixture returned success'
fi

grep -Fq 'source SHA $source_sha' "$ROOT/update.sh" ||
  fail 'update.sh does not report the exact installed source SHA'

echo 'PASS: required stages fail truthfully, optional failures warn, and Node tools verify independently'
