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

if command -v pwsh >/dev/null 2>&1; then
  powershell_guard_output="$(pwsh -NoProfile -File "$ROOT/tests/test-all.ps1" -ExcludeReviewerSafety 2>&1)"
  powershell_guard_rc=$?
  check 'PowerShell reviewer exclusion requires pull-request selection' \
    '[ "$powershell_guard_rc" -ne 0 ] && printf "%s" "$powershell_guard_output" | grep -Fq -- "-ExcludeReviewerSafety requires -WindowsPullRequest."'
else
  ok 'PowerShell reviewer exclusion guard skipped because pwsh is unavailable'
fi

# Sections divide the ordinary pull-request lane across independent machines
# (issue #210). The properties that matter are that the sections reconstitute
# the lane exactly, that a defect anywhere in the lane still fails the run that
# owns it, and that a bad declaration is a configuration error rather than quiet
# coverage loss.
printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-sec-a.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-sec-c.sh"
chmod +x "$SUITES"/*.sh
lane_manifest() {
  printf '%s\n' "{\"windows_offline_bash\":[\"test-sec-a.sh\",\"test-sec-c.sh\",\"test-windows-defect.sh\"],\"windows_reviewer_safety_bash\":[\"test-windows-defect.sh\"],\"windows_offline_powershell_shard\":1,\"windows_offline_shards\":$1}" >"$MANIFEST"
}

lane_manifest '[["test-sec-a.sh"],["test-sec-c.sh"]]'
first="$(run --windows-offline --exclude-reviewer-safety --shard 1/2 --list 2>/dev/null | grep '^test-')"
second="$(run --windows-offline --exclude-reviewer-safety --shard 2/2 --list 2>/dev/null | grep '^test-')"
check 'the declared sections partition the ordinary lane with nothing lost or repeated' \
  '[ "$first" = "test-sec-a.sh" ] && [ "$second" = "test-sec-c.sh" ]'

run --windows-offline --exclude-reviewer-safety --shard 1/2 >/dev/null 2>&1; sec_clean_rc=$?
run --windows-offline --exclude-reviewer-safety --shard 2/2 >/dev/null 2>&1; sec_clean2_rc=$?
check 'a clean lane passes in every section' '[ "$sec_clean_rc" -eq 0 ] && [ "$sec_clean2_rc" -eq 0 ]'

# An injected defect must fail the section that owns it, and only that section,
# so the aggregate goes red and the failure names where it happened.
printf '#!/usr/bin/env bash\nexit 19\n' >"$SUITES/test-sec-c.sh"; chmod +x "$SUITES/test-sec-c.sh"
run --windows-offline --exclude-reviewer-safety --shard 2/2 >/dev/null 2>&1; sec_defect_rc=$?
run --windows-offline --exclude-reviewer-safety --shard 1/2 >/dev/null 2>&1; sec_other_rc=$?
run --windows-offline --exclude-reviewer-safety >/dev/null 2>&1; sec_unsharded_rc=$?
check 'an injected defect fails its own section, leaving the others honest' \
  '[ "$sec_defect_rc" -ne 0 ] && [ "$sec_other_rc" -eq 0 ] && [ "$sec_unsharded_rc" -ne 0 ]'
run >/dev/null 2>&1; sec_complete_rc=$?
check 'the complete scheduled backstop still sees a defect no section could hide' \
  '[ "$sec_complete_rc" -ne 0 ]'
printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-sec-c.sh"; chmod +x "$SUITES/test-sec-c.sh"

lane_manifest '[["test-sec-a.sh"]]'
run --windows-offline --exclude-reviewer-safety --shard 1/1 --list >/dev/null 2>&1; sec_gap_rc=$?
check 'sections that do not cover the lane fail instead of dropping a suite' '[ "$sec_gap_rc" -eq 2 ]'

lane_manifest '[["test-sec-a.sh","test-sec-c.sh"],["test-sec-c.sh"]]'
run --windows-offline --exclude-reviewer-safety --shard 1/2 --list >/dev/null 2>&1; sec_dup_rc=$?
check 'a suite declared in two sections fails instead of running twice' '[ "$sec_dup_rc" -eq 2 ]'

lane_manifest '[["test-sec-a.sh"],["test-sec-c.sh"]]'
run --windows-offline --exclude-reviewer-safety --shard 1/3 --list >/dev/null 2>&1; sec_count_rc=$?
run --windows-offline --exclude-reviewer-safety --shard 0/2 --list >/dev/null 2>&1; sec_zero_rc=$?
run --windows-offline --shard 1/2 --list >/dev/null 2>&1; sec_context_rc=$?
check 'a section request that disagrees with the declaration fails closed' \
  '[ "$sec_count_rc" -eq 2 ] && [ "$sec_zero_rc" -eq 2 ] && [ "$sec_context_rc" -eq 2 ]'

# Splitting on the first and last slash independently would read `1/2/2` as
# section 1 of 2 and run a real but wrong selection instead of failing.
run --windows-offline --exclude-reviewer-safety --shard 1/2/2 --list >/dev/null 2>&1; sec_slash_rc=$?
run --windows-offline --exclude-reviewer-safety --shard /2 --list >/dev/null 2>&1; sec_head_rc=$?
run --windows-offline --exclude-reviewer-safety --shard 1/ --list >/dev/null 2>&1; sec_tail_rc=$?
check 'a section argument with anything but one <i>/<n> pair is refused' \
  '[ "$sec_slash_rc" -eq 2 ] && [ "$sec_head_rc" -eq 2 ] && [ "$sec_tail_rc" -eq 2 ]'

printf '%s\n' '{"windows_offline_bash":["test-sec-a.sh","test-sec-c.sh","test-windows-defect.sh"],"windows_reviewer_safety_bash":["test-windows-defect.sh"]}' >"$MANIFEST"
run --windows-offline --exclude-reviewer-safety --shard 1/2 --list >/dev/null 2>&1; sec_absent_rc=$?
check 'a manifest with no declared sections refuses to run one' '[ "$sec_absent_rc" -eq 2 ]'

# The PowerShell suites are not divisible by this mapping, so exactly one
# section owns them and every other section skips them by declaration.
if command -v pwsh >/dev/null 2>&1; then
  lane_manifest '[["test-sec-a.sh"],["test-sec-c.sh"]]'
  owner_out="$(AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" pwsh -NoProfile -File "$ROOT/tests/test-all.ps1" -WindowsPullRequest -ExcludeReviewerSafety -Shard 2/2 2>&1)"
  check 'a section that does not own the PowerShell suites says so and skips them' \
    'printf "%s" "$owner_out" | grep -Fq "POWERSHELL SUITES run in section 1 of 2"'
  guard_out="$(AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" pwsh -NoProfile -File "$ROOT/tests/test-all.ps1" -Shard 1/2 2>&1)"
  guard_rc=$?
  check 'PowerShell sectioning is refused outside the ordinary pull-request lane' \
    '[ "$guard_rc" -ne 0 ] && printf "%s" "$guard_out" | grep -Fq -- "-Shard requires -WindowsPullRequest -ExcludeReviewerSafety."'
else
  ok 'PowerShell section ownership skipped because pwsh is unavailable'
fi

printf '{' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; invalid_rc=$?
check 'invalid manifest JSON fails with a configuration error' '[ "$invalid_rc" -eq 2 ]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
