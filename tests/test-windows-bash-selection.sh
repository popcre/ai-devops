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
  guard_out="$(AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" pwsh -NoProfile -File "$ROOT/tests/test-all.ps1" -WindowsPullRequest -Shard 1/2 2>&1)"
  guard_rc=$?
  check 'PowerShell ordinary Windows sectioning still requires the reviewer split' \
    '[ "$guard_rc" -ne 0 ] && printf "%s" "$guard_out" | grep -Fq -- "Windows -Shard requires -ExcludeReviewerSafety."'
else
  ok 'PowerShell section ownership skipped because pwsh is unavailable'
fi

# Complete sections discover all names independently of the PR manifest.
lane_manifest '[["test-sec-a.sh"],["test-sec-c.sh"]]'
printf '#!/usr/bin/env bash\nexit 0\n' > "$SUITES/test-000-future.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SUITES/test-z-nonwindows.sh"
complete_all="$(run --list | grep '^test-' | LC_ALL=C sort)"
complete_one="$(run --shard 1/3 --list | grep '^test-')"
complete_two="$(run --shard 2/3 --list | grep '^test-')"
complete_three="$(run --shard 3/3 --list | grep '^test-')"
complete_union="$(printf '%s\n' "$complete_one" "$complete_two" "$complete_three" | LC_ALL=C sort)"
check 'complete sections cover every dynamic suite exactly once' \
  '[ "$complete_union" = "$complete_all" ] && [ "$(printf "%s\n" "$complete_union" | sort -u)" = "$complete_union" ]'
check 'complete sections retain reviewer, non-Windows and future suite names' \
  'printf "%s\n" "$complete_union" | grep -Fxq test-windows-defect.sh && printf "%s\n" "$complete_union" | grep -Fxq test-z-nonwindows.sh && printf "%s\n" "$complete_union" | grep -Fxq test-000-future.sh'
check 'complete assignment is sorted round-robin and deterministic' \
  '[ "$complete_one" = "$(printf "test-000-future.sh\ntest-sec-c.sh")" ] && [ "$complete_two" = "$(printf "test-linux-only.sh\ntest-windows-defect.sh")" ] && [ "$complete_three" = "$(printf "test-sec-a.sh\ntest-z-nonwindows.sh")" ] && [ "$complete_one" = "$(run --shard 1/3 --list | grep "^test-")" ]'
run --shard 1/3 > "$TMP/complete-one.log" 2>&1; complete_rc1=$?
run --shard 2/3 > "$TMP/complete-two.log" 2>&1; complete_rc2=$?
run --shard 3/3 > "$TMP/complete-three.log" 2>&1; complete_rc3=$?
check 'a complete-section defect fails exactly its owning section' \
  '[ "$complete_rc1" -eq 0 ] && [ "$complete_rc2" -ne 0 ] && [ "$complete_rc3" -eq 0 ] && grep -q "tests=2 failures=1" "$TMP/complete-two.log"'
for invalid_shard in '' 1 1/2/3 /2 1/ 0/2 3/2 1/0 1/7 999999999999999999999/2; do
  run --shard "$invalid_shard" --list >/dev/null 2>&1; invalid_complete_rc=$?
  check "complete section refuses malformed or empty assignment: $invalid_shard" '[ "$invalid_complete_rc" -eq 2 ]'
done
run --shard 1/3 --only sec --list >/dev/null 2>&1; complete_only_rc=$?
run --shard 1/3 --changed-since HEAD --list >/dev/null 2>&1; complete_changed_rc=$?
run --shard 1/3 --shard 2/3 --list >/dev/null 2>&1; complete_duplicate_rc=$?
check 'complete sectioning rejects filtered and duplicate selections' \
  '[ "$complete_only_rc" -eq 2 ] && [ "$complete_changed_rc" -eq 2 ] && [ "$complete_duplicate_rc" -eq 2 ]'
check 'complete sections leave ordinary declared PR sections unchanged' \
  '[ "$(run --windows-offline --exclude-reviewer-safety --shard 1/2 --list | grep "^test-")" = test-sec-a.sh ]'

if command -v pwsh >/dev/null 2>&1; then
  # Copy only the existing entry points into an isolated miniature repository.
  # Its PowerShell discovery must never invoke this repository's real suites.
  ps_fixture="$TMP/ps-fixture/tests"; mkdir -p "$ps_fixture"
  cp "$ROOT/tests/test-all.ps1" "$ROOT/tests/test-all.sh" "$ROOT/tests/lib-selection.sh" "$ps_fixture/"
  cat > "$ps_fixture/test-alpha.ps1" <<'PS'
Add-Content -LiteralPath $env:AI_TEST_EXEC_TRACE -Value 'POWERSHELL-alpha'
exit 0
PS
  cat > "$ps_fixture/test-beta.ps1" <<'PS'
Add-Content -LiteralPath $env:AI_TEST_EXEC_TRACE -Value 'POWERSHELL-beta'
exit 0
PS
  cat > "$SUITES/test-000-future.sh" <<'BASH'
printf 'BASH\n' >> "$AI_TEST_EXEC_TRACE"
exit 0
BASH
  export AI_TEST_EXEC_TRACE="$TMP/ps-execution.log"
  if command -v cygpath >/dev/null 2>&1; then AI_TEST_EXEC_TRACE="$(cygpath -m "$AI_TEST_EXEC_TRACE")"; fi
  ps_run(){ AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" pwsh -NoProfile -File "$ps_fixture/test-all.ps1" "$@"; }
  : > "$AI_TEST_EXEC_TRACE"
  ps_run -Shard 1/3 > "$TMP/ps-complete-1.log" 2>&1; ps_complete1=$?
  ps_run -Shard 2/3 > "$TMP/ps-complete-2.log" 2>&1; ps_complete2=$?
  ps_run -Shard 3/3 > "$TMP/ps-complete-3.log" 2>&1; ps_complete3=$?
  check 'complete PowerShell sections run every PowerShell suite exactly once' \
    '[ "$ps_complete1" -eq 0 ] && [ "$ps_complete2" -ne 0 ] && [ "$ps_complete3" -eq 0 ] && [ "$(grep -c POWERSHELL-alpha "$AI_TEST_EXEC_TRACE")" -eq 1 ] && [ "$(grep -c POWERSHELL-beta "$AI_TEST_EXEC_TRACE")" -eq 1 ]'
  printf '\nexit 9\n' >> "$ps_fixture/test-beta.ps1"
  # Replace the fixture's terminal status; the original earlier exit must not hide it.
  sed -i '/^exit 0$/d' "$ps_fixture/test-beta.ps1"
  ps_run -Shard 1/3 > "$TMP/ps-complete-failed.log" 2>&1; ps_failure_rc=$?
  check 'complete PowerShell owner propagates an injected PowerShell failure' \
    '[ "$ps_failure_rc" -ne 0 ] && grep -q "powershell=2 failures=1" "$TMP/ps-complete-failed.log"'
  for owner in null 0 4 1.5 '"bad"'; do
    jq --argjson owner "$owner" '.windows_offline_powershell_shard=$owner' "$MANIFEST" > "$TMP/bad-owner.json"
    : > "$AI_TEST_EXEC_TRACE"
    AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$TMP/bad-owner.json" pwsh -NoProfile -File "$ps_fixture/test-all.ps1" -Shard 1/3 > "$TMP/ps-invalid-owner.log" 2>&1; ps_invalid_owner_rc=$?
    check "invalid PowerShell owner refuses before any suite: $owner" '[ "$ps_invalid_owner_rc" -ne 0 ] && [ ! -s "$AI_TEST_EXEC_TRACE" ]'
  done
  : > "$AI_TEST_EXEC_TRACE"
  ps_run -Shard 1/999 > "$TMP/ps-oversized-selection.log" 2>&1; ps_oversized_rc=$?
  check 'oversized complete selection refuses before either language executes a suite' \
    '[ "$ps_oversized_rc" -ne 0 ] && [ ! -s "$AI_TEST_EXEC_TRACE" ] && grep -q "complete section count exceeds discovered suites" "$TMP/ps-oversized-selection.log"'
  jq '.windows_offline_shards=[["test-sec-a.sh"]]' "$MANIFEST" > "$TMP/incomplete-pr-selection.json"
  : > "$AI_TEST_EXEC_TRACE"
  AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$TMP/incomplete-pr-selection.json" pwsh -NoProfile -File "$ps_fixture/test-all.ps1" -WindowsPullRequest -ExcludeReviewerSafety -Shard 1/1 > "$TMP/ps-incomplete-pr.log" 2>&1; ps_incomplete_pr_rc=$?
  check 'incomplete PR selection refuses before either language executes a suite' \
    '[ "$ps_incomplete_pr_rc" -ne 0 ] && [ ! -s "$AI_TEST_EXEC_TRACE" ] && grep -q "do not cover the Windows lane exactly" "$TMP/ps-incomplete-pr.log"'
  unset AI_TEST_EXEC_TRACE
fi

printf '{' >"$MANIFEST"
run --windows-offline --list >/dev/null 2>&1; invalid_rc=$?
check 'invalid manifest JSON fails with a configuration error' '[ "$invalid_rc" -eq 2 ]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
