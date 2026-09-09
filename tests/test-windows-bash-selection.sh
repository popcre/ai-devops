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

printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-linux-only.sh"
printf '#!/usr/bin/env bash\nexit 17\n' >"$SUITES/test-windows-defect.sh"
printf '%s\n' '{"windows_offline_bash":["test-windows-defect.sh"]}' >"$MANIFEST"
chmod +x "$SUITES"/*.sh

listed="$(run --windows-offline --list 2>"$TMP/list.err")"; list_rc=$?
if [ "$list_rc" -eq 0 ] && [ "$(printf '%s\n' "$listed" | tail -1)" = 'test-windows-defect.sh' ] &&
   [ "$(printf '%s\n' "$listed" | grep -c '^test-')" -eq 1 ]; then
  ok 'ordinary Windows selection contains only the declared suite'
else
  printf '       rc=%s got=%q error=%s\n' "$list_rc" "$listed" "$(cat "$TMP/list.err")" >&2
  bad 'ordinary Windows selection contains only the declared suite'
fi
run --windows-offline >/dev/null 2>&1; selected_rc=$?
check 'an injected Windows-suite defect fails the selected run' '[ "$selected_rc" -ne 0 ]'
run >/dev/null 2>&1; complete_rc=$?
check 'the unchanged no-argument complete run still sees the defect' '[ "$complete_rc" -ne 0 ]'

printf '%s\n' '{"windows_offline_bash":["test-missing.sh"]}' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; stale_rc=$?
check 'a stale Windows mapping fails instead of dropping coverage' '[ "$stale_rc" -eq 2 ]'

printf '%s\n' '{"windows_offline_bash":["test-linux-only.sh","test-linux-only.sh"]}' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; duplicate_rc=$?
check 'a duplicate Windows assignment fails instead of repeating work' '[ "$duplicate_rc" -eq 2 ]'

printf '{' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; invalid_rc=$?
check 'invalid manifest JSON fails with a configuration error' '[ "$invalid_rc" -eq 2 ]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
