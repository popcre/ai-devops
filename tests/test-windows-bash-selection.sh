#!/usr/bin/env bash
# Proves ordinary Windows selection is fail-closed and preserves suite failures.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SUITES="$TMP/suites"; mkdir -p "$SUITES"
MANIFEST="$TMP/manifest.json"
pass=0; fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
run() { AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" bash "$ROOT/tests/test-all.sh" "$@"; }

help="$(bash "$ROOT/tests/test-all.sh" --help)"
check 'help lists the guarded reviewer exclusion and list mode' \
  "printf '%s' \"\$help\" | grep -q -- '--exclude-reviewer-safety' && printf '%s' \"\$help\" | grep -q -- '--list'"

printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-linux-only.sh"
printf '#!/usr/bin/env bash\nexit 17\n' >"$SUITES/test-windows-defect.sh"
printf '%s\n' '{"windows_offline_bash":["test-linux-only.sh","test-windows-defect.sh"],"windows_reviewer_safety_bash":["test-windows-defect.sh"]}' >"$MANIFEST"
chmod +x "$SUITES"/*.sh

listed="$(run --windows-offline --list 2>"$TMP/list.err")"; list_rc=$?
if [ "$list_rc" -eq 0 ] && [ "$(printf '%s\n' "$listed" | grep -c '^test-')" -eq 2 ]; then
  ok 'ordinary Windows selection contains every declared suite'
else
  printf '       rc=%s got=%q error=%s\n' "$list_rc" "$listed" "$(cat "$TMP/list.err")" >&2
  bad 'ordinary Windows selection contains every declared suite'
fi
omitted="$(run --windows-offline --exclude-reviewer-safety --list 2>"$TMP/omit.err")"; omitted_rc=$?
if [ "$omitted_rc" -eq 0 ] && [ "$(printf '%s\n' "$omitted" | tail -1)" = 'test-linux-only.sh' ] &&
   ! printf '%s\n' "$omitted" | grep -q '^test-windows-defect.sh$'; then
  ok 'hosted split omits exactly the reviewer-owned suite'
else
  bad 'hosted split omits exactly the reviewer-owned suite'
fi
run --windows-offline >/dev/null 2>&1; selected_rc=$?
check 'an injected Windows-suite defect fails the selected run' '[ "$selected_rc" -ne 0 ]'
run --windows-offline --exclude-reviewer-safety >/dev/null 2>&1; split_rc=$?
check 'the hosted split passes only because fallback owns the injected reviewer defect' '[ "$split_rc" -eq 0 ]'
run >/dev/null 2>&1; complete_rc=$?
check 'the unchanged no-argument complete run still sees the defect' '[ "$complete_rc" -ne 0 ]'

printf '%s\n' '{"windows_offline_bash":["test-missing.sh"]}' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; stale_rc=$?
check 'a stale Windows mapping fails instead of dropping coverage' '[ "$stale_rc" -eq 2 ]'

printf '%s\n' '{"windows_offline_bash":["test-linux-only.sh","test-linux-only.sh"]}' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; duplicate_rc=$?
check 'a duplicate Windows assignment fails instead of repeating work' '[ "$duplicate_rc" -eq 2 ]'

printf '%s\n' '{"windows_offline_bash":["test-linux-only.sh"],"windows_reviewer_safety_bash":["test-windows-defect.sh"]}' >"$MANIFEST"
run --exclude-reviewer-safety --list >/dev/null 2>&1; unsafe_rc=$?
check 'reviewer exclusion without Windows lane context fails closed' '[ "$unsafe_rc" -eq 2 ]'

printf '%s\n' '{"windows_offline_bash":["test-linux-only.sh"]}' >"$MANIFEST"
run --windows-offline --exclude-reviewer-safety --list >/dev/null 2>&1; missing_reviewer_rc=$?
check 'missing reviewer assignment fails instead of creating a coverage gap' '[ "$missing_reviewer_rc" -eq 2 ]'

pwsh -NoProfile -File "$ROOT/tests/test-all.ps1" -ExcludeReviewerSafety >/dev/null 2>&1; powershell_guard_rc=$?
check 'PowerShell reviewer exclusion requires pull-request selection' '[ "$powershell_guard_rc" -ne 0 ]'

printf '{' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; invalid_rc=$?
check 'invalid manifest JSON fails with a configuration error' '[ "$invalid_rc" -eq 2 ]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
