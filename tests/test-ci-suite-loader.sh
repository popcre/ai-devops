#!/usr/bin/env bash
# Proves the per-suite manifest loader (#1001): it reassembles the legacy
# reader shape exactly, and every inconsistency is a configuration error that
# names the offending file instead of quietly losing coverage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="$ROOT/tools/ci-suites/load-manifest"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

# A miniature valid repository: two hosted sections, a reviewer-safety suite,
# a Linux-only suite, a PowerShell suite, and a suspension.
mkdir -p "$TMP/ci-suites"
printf '%s\n' '{"windows_offline_section_count":2,"windows_offline_powershell_shard":2,"suspended_bash":["test-slow.sh"],"affected_suite_rules":{"select_all_globs":["shared/**"]}}' >"$TMP/global.json"
printf '%s\n' '{"kind":"bash","linux_seconds":10,"windows":["offline"],"windows_section":1}' >"$TMP/ci-suites/test-alpha.sh.json"
printf '%s\n' '{"kind":"bash","windows":["offline","reviewer-safety"]}' >"$TMP/ci-suites/test-beta.sh.json"
printf '%s\n' '{"kind":"powershell"}' >"$TMP/ci-suites/test-gamma.ps1.json"
printf '%s\n' '{"kind":"bash"}' >"$TMP/ci-suites/test-delta.sh.json"

load() { AI_CI_SUITE_MANIFEST="$TMP/global.json" AI_CI_SUITE_DIR="$TMP/ci-suites" bash "$LOADER" "$@"; }
load_rc=0; load_out="$(load)" || load_rc=$?

printf '%s\n' '{
  "schema_version": 2,
  "linux_offline_suite_seconds": {"test-alpha.sh": 10},
  "bash": ["test-alpha.sh", "test-beta.sh", "test-delta.sh"],
  "powershell": ["test-gamma.ps1"],
  "windows_sensitive_bash": ["test-alpha.sh", "test-beta.sh"],
  "windows_reviewer_safety_bash": ["test-beta.sh"],
  "windows_offline_bash": ["test-alpha.sh", "test-beta.sh"],
  "windows_offline_shards": [["test-alpha.sh"], []],
  "windows_offline_powershell_shard": 2,
  "suspended_bash": ["test-slow.sh"],
  "affected_suite_rules": {"select_all_globs": ["shared/**"]}
}' >"$TMP/expected.json"

if [ "$load_rc" -eq 0 ] && printf '%s\n' "$load_out" | jq -S . | cmp -s - <(jq -S . "$TMP/expected.json"); then
  ok 'the loader matches the legacy golden output'
else
  bad 'the loader matches the legacy golden output'
  printf '%s\n' "$load_out" | jq -S . | diff - <(jq -S . "$TMP/expected.json") >&2 || true
fi
check 'the loader output is deterministic across runs' \
  '[ "$(load | jq -S . | sha256sum)" = "$(load | jq -S . | sha256sum)" ]'

broken_case() {
  local label="$1" file="$2" body="$3"
  printf '%s\n' "$body" >"$TMP/ci-suites/$file"
  local rc=0 err
  err="$(load 2>&1)" || rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$err" | grep -Fq "$file"; then
    ok "$label"
  else
    bad "$label"
    printf '       rc=%s err=%s\n' "$rc" "$err" >&2
  fi
  rm -f "$TMP/ci-suites/$file"
}

broken_case 'a malformed suite file fails naming that file' 'test-bad.sh.json' '{'
broken_case 'a duplicate membership tag fails naming that file' 'test-dup.sh.json' \
  '{"kind":"bash","windows":["offline","offline"],"windows_section":1}'
broken_case 'an offline suite in no section fails naming that file' 'test-orphan.sh.json' \
  '{"kind":"bash","windows":["offline"]}'
broken_case 'an out-of-range section number fails naming that file' 'test-range.sh.json' \
  '{"kind":"bash","windows":["offline"],"windows_section":3}'
broken_case 'an unknown kind fails naming that file' 'test-kind.sh.json' \
  '{"kind":"make"}'
broken_case 'a reviewer-safety suite outside the offline lane fails naming that file' 'test-lonely.sh.json' \
  '{"kind":"bash","windows":["reviewer-safety"]}'
broken_case 'a PowerShell suite with Linux seconds fails naming that file' 'test-mixed.ps1.json' \
  '{"kind":"powershell","linux_seconds":5}'
broken_case 'a non-integer Linux seconds value fails naming that file' 'test-frac.sh.json' \
  '{"kind":"bash","linux_seconds":1.5}'

# A declared section with no work at all is a configuration error.
printf '%s\n' '{"windows_offline_section_count":3,"windows_offline_powershell_shard":3}' >"$TMP/global.json"
empty_rc=0; load >/dev/null 2>&1 || empty_rc=$?
check 'an empty declared section fails naming the section' \
  '[ "$empty_rc" -eq 2 ]'

# The global manifest and the suite directory are both required.
printf '%s\n' '{"windows_offline_section_count":2,"windows_offline_powershell_shard":2}' >"$TMP/global.json"
missing_dir_rc=0; AI_CI_SUITE_MANIFEST="$TMP/global.json" AI_CI_SUITE_DIR="$TMP/no-such-dir" bash "$LOADER" >/dev/null 2>&1 || missing_dir_rc=$?
check 'a missing suite directory fails closed' '[ "$missing_dir_rc" -eq 2 ]'
missing_global_rc=0; AI_CI_SUITE_MANIFEST="$TMP/no-such.json" bash "$LOADER" >/dev/null 2>&1 || missing_global_rc=$?
check 'a missing global manifest fails closed' '[ "$missing_global_rc" -eq 2 ]'
stray_rc=0; printf 'notes\n' >"$TMP/ci-suites/README.md"; load >/dev/null 2>&1 || stray_rc=$?
check 'a non-JSON file in the suite directory fails closed' '[ "$stray_rc" -eq 2 ]'
rm -f "$TMP/ci-suites/README.md"

# The repository's own configuration must load and satisfy the same contract.
repo_rc=0; repo_out="$(bash "$LOADER")" || repo_rc=$?
if [ "$repo_rc" -eq 0 ]; then ok 'the repository manifest loads through the loader'; else bad 'the repository manifest loads through the loader'; fi
repo_inventory="$(printf '%s\n' "$repo_out" | jq -r '(.bash + .powershell)[]' | tr -d '\r' | LC_ALL=C sort)"
disk_inventory="$(ls "$ROOT/config/ci-suites" | sed 's/\.json$//' | LC_ALL=C sort)"
if [ -n "$repo_inventory" ] && [ "$repo_inventory" = "$disk_inventory" ]; then
  ok 'the repository inventory matches the checked-in per-suite files'
else
  bad 'the repository inventory matches the checked-in per-suite files'
fi
repo_sections="$(printf '%s\n' "$repo_out" | jq '.windows_offline_shards | length')"
declared_sections="$(jq -r '.windows_offline_section_count' "$ROOT/config/ci-suite-manifest.json")"
if [ -n "$repo_sections" ] && [ "$repo_sections" = "$declared_sections" ]; then
  ok 'the repository section count matches the declared sections'
else
  bad 'the repository section count matches the declared sections'
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
