#!/usr/bin/env bash
# Shared counters and reporting for offline Bash suites.
# Suites keep their existing human output. Set AI_TEST_REPORT_FILE to also
# receive stable TSV records: suite, check status, and check identity.

: "${PASS:=0}" "${FAIL:=0}" "${SKIP:=0}"
AI_TEST_SUITE="${AI_TEST_SUITE:-$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" .sh)}"

ai_test_record() {
  [ -n "${AI_TEST_REPORT_FILE:-}" ] || return 0
  case "$AI_TEST_SUITE$2" in
    *$'\t'*|*$'\n'*) printf 'lib-test-harness: report fields cannot contain tabs or newlines\n' >&2; return 2 ;;
  esac
  printf '%s\t%s\t%s\n' "$AI_TEST_SUITE" "$1" "$2" >> "$AI_TEST_REPORT_FILE"
}

ok() {
  PASS=$((PASS + 1))
  printf '  ok   %s\n' "$1"
  ai_test_record pass "$1"
}

bad() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n' "$1"
  ai_test_record fail "$1"
}

skip() {
  SKIP=$((SKIP + 1))
  printf '  skip %s\n' "$1"
  ai_test_record skip "$1"
}

check() {
  if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi
}
