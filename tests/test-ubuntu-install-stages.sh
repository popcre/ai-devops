#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

required=(dependencies directories config config-migration tools skills identity permissions memory manifest doctor node-toolchain)
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

grep -Fq '$SUDO "$REPO_ROOT/bin/ai-config-migrate"' "$ROOT/install.sh" ||
  fail 'configuration migration does not use the installer privilege boundary'
grep -Fq -- '--source-sha "$source_sha"' "$ROOT/install.sh" ||
  fail 'privileged configuration tools do not retain the unprivileged source identity'
grep -Fq '$SUDO install -o "$owner" -g "$group" -m 600' "$ROOT/install.sh" ||
  fail 'managed manifest is not published owner-readably through the privilege boundary'
grep -Fq -- '--home "$HOME" --source-sha "$source_sha" --output "$staged"' "$ROOT/install.sh" ||
  fail 'staged manifest does not retain the installing user home and source identity'

echo 'PASS: required stages fail truthfully, privileged config artifacts publish safely, optional failures warn, and Node tools verify independently'
