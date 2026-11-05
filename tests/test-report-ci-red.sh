#!/usr/bin/env bash
# test-report-ci-red.sh — per-test reporter mode (step 1.4).
# One ci-red issue per failing test, capacity excluded, auto-close after 3 greens.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$ROOT/tools/ci/report-scheduled-failure.sh"
MOCK="$ROOT/tests/fixtures/mock-gh-ci-red.sh"
pass=0; fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; pass=$(( pass + 1 ))
  else printf '  FAIL %s\n' "$1"; fail=$(( fail + 1 )); fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/gh.log"
cp "$MOCK" "$TMP/gh"
chmod +x "$TMP/gh"
export PATH="$TMP:$PATH" GH_LOG="$LOG"

check "reporter exists and is executable" "test -x '$CMD'"
check "reporter parses as valid bash" "bash -n '$CMD'"

# One issue per failing result test.
: > "$LOG"
GH_FIXTURE_ISSUE='' bash "$CMD" --run-url 'https://example/run/1' --repo o/r \
  --per-test --results 'linux-offline=failure doc-safety=failure' \
  --pr-number 7 --head-sha aaaa --event pull_request >"$TMP/out1" 2>&1
check "two result failures open two issues" \
  "test \"\$(grep -c 'opened' '$TMP/out1')\" = 2"
check "issue title is ci-red: <job>" \
  "grep -q 'ci-red: linux-offline' '$LOG' && grep -q 'ci-red: doc-safety' '$LOG'"
check "issue body includes PR and Head SHA" \
  "grep -q 'Head SHA' '$LOG' && grep -q 'pull/7' '$LOG'"

# Capacity failures produce none.
: > "$LOG"
GH_FIXTURE_ISSUE='' bash "$CMD" --run-url 'https://example/run/2' --repo o/r \
  --per-test --results 'windows-offline-complete=cancelled' \
  --pr-number 7 --head-sha aaaa --event pull_request >"$TMP/out2" 2>&1
check "capacity failure opens no ci-red issue" \
  "! grep -q 'opened' '$TMP/out2' && ! grep -q 'issue create' '$LOG'"
check "capacity failure is reported as skipped" \
  "grep -q 'no ci-red issue' '$TMP/out2'"

# Result + capacity mix: result gets an issue, capacity does not.
: > "$LOG"
GH_FIXTURE_ISSUE='' bash "$CMD" --run-url 'https://example/run/3' --repo o/r \
  --per-test --results 'linux-offline=failure windows-offline-complete=timed_out' \
  --pr-number 7 --head-sha aaaa --event pull_request >"$TMP/out3" 2>&1
check "mixed run: result gets one issue, capacity none" \
  "test \"\$(grep -c 'opened' '$TMP/out3')\" = 1"

# Existing issue is updated, not duplicated.
: > "$LOG"
GH_FIXTURE_ISSUE='42' bash "$CMD" --run-url 'https://example/run/4' --repo o/r \
  --per-test --results 'linux-offline=failure' \
  --pr-number 7 --head-sha aaaa --event pull_request >"$TMP/out4" 2>&1
check "existing ci-red issue is updated" \
  "grep -q 'updated issue #42' '$TMP/out4'"
check "update does not create a second issue" \
  "! grep -q 'opened' '$TMP/out4'"

# Green tracking: one green run adds a marker comment.
: > "$LOG"
GH_FIXTURE_ISSUE='42' GH_FIXTURE_GREEN_COUNT='1' \
  bash "$CMD" --run-url 'https://example/run/5' --repo o/r \
  --per-test --results 'linux-offline=success' --event pull_request >"$TMP/out5" 2>&1
check "green run comments on the open issue" \
  "grep -q 'issue comment 42' '$LOG' && grep -q 'ci-red-green' '$LOG'"

# Three green runs close the issue.
: > "$LOG"
GH_FIXTURE_ISSUE='42' GH_FIXTURE_GREEN_COUNT='3' \
  bash "$CMD" --run-url 'https://example/run/6' --repo o/r \
  --per-test --results 'linux-offline=success' --event pull_request >"$TMP/out6" 2>&1
check "three green runs close the issue" \
  "grep -q 'issue close 42' '$LOG' && grep -q 'closed #42' '$TMP/out6'"

# Two green runs do NOT close.
: > "$LOG"
GH_FIXTURE_ISSUE='42' GH_FIXTURE_GREEN_COUNT='2' \
  bash "$CMD" --run-url 'https://example/run/7' --repo o/r \
  --per-test --results 'linux-offline=success' --event pull_request >"$TMP/out7" 2>&1
check "two green runs do not close" \
  "! grep -q 'issue close' '$LOG'"

# Cap per run: override cap to 5; 8 result failures cap at 5.
: > "$LOG"
many=""
for i in $(seq 1 8); do many="$many job$i=failure"; done
GH_FIXTURE_ISSUE='' CI_RED_CAP=5 bash "$CMD" --run-url 'https://example/run/8' --repo o/r \
  --per-test --results "$many" --pr-number 7 --head-sha aaaa --event pull_request \
  >"$TMP/out8" 2>&1
check "cap limits issues per run to 5" \
  "test \"\$(grep -c 'opened' '$TMP/out8')\" = 5"
check "cap message appears for overflow" \
  "grep -q 'cap 5 reached' '$TMP/out8'"

# ci-red label is created before attach.
: > "$LOG"
GH_FIXTURE_ISSUE='' bash "$CMD" --run-url 'https://example/run/9' --repo o/r \
  --per-test --results 'linux-offline=failure' \
  --pr-number 7 --head-sha aaaa --event pull_request >"$TMP/out9" 2>&1
check "ci-red label is created before attach" \
  "grep -q 'label create ci-red' '$LOG'"

printf 'report-ci-red: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
