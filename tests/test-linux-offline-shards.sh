#!/usr/bin/env bash
# Proves the sectioned Linux offline lane runs every suite exactly once and that
# its stable linux-offline aggregate fails closed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SUITES="$TMP/suites"; mkdir -p "$SUITES"
MANIFEST="$TMP/manifest.json"
pass=0; fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"
  else fail=$((fail + 1)); printf '  FAIL %s\n' "$1" >&2; fi
}
run() { AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" bash "$ROOT/tests/test-all.sh" "$@"; }
listed() { run "$@" --list 2>/dev/null | grep '^test-'; }

for name in heavy-a heavy-b heavy-c small-a small-b small-c small-d unmeasured; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$SUITES/test-$name.sh"
done
# Per-suite manifest files (#1001): the Linux timing lives in each suite's own
# file; the global manifest declares only the section-less slim shape here.
CONFIGS="$TMP/ci-suites"; mkdir -p "$CONFIGS"
printf '%s\n' '{"windows_offline_section_count":0}' >"$MANIFEST"
sj() { printf '{"kind":"bash"%s}\n' "${2:-}" >"$CONFIGS/$1.json"; }
sj test-heavy-a.sh ',"linux_seconds":300'
sj test-heavy-b.sh ',"linux_seconds":250'
sj test-heavy-c.sh ',"linux_seconds":200'
sj test-small-a.sh ',"linux_seconds":40'
sj test-small-b.sh ',"linux_seconds":30'
sj test-small-c.sh ',"linux_seconds":20'
sj test-small-d.sh ',"linux_seconds":10'
sj test-unmeasured.sh ''
sj test-retired.sh ',"linux_seconds":99'

all="$(listed | LC_ALL=C sort)"
union="$(for i in 1 2 3; do listed --balanced --shard "$i/3"; done | LC_ALL=C sort)"
check 'balanced sections run every discovered suite exactly once' '[ -n "$all" ] && [ "$union" = "$all" ]'
check 'an unmeasured suite is still placed in a section' 'printf "%s\n" "$union" | grep -qx test-unmeasured.sh'
check 'a measured name with no suite file is never run' '! printf "%s\n" "$union" | grep -q test-retired.sh'
owners=''
for heavy in heavy-a heavy-b heavy-c; do
  for i in 1 2 3; do listed --balanced --shard "$i/3" | grep -qx "test-$heavy.sh" && owners+="$i "; done
done
check 'the three heaviest suites land in three different sections' \
  '[ "$(printf "%s\n" $owners | LC_ALL=C sort -u | wc -l)" -eq 3 ]'
check 'balanced assignment is deterministic' \
  '[ "$(listed --balanced --shard 2/3)" = "$(listed --balanced --shard 2/3)" ]'
run --balanced --shard 1/3 >"$TMP/run.log" 2>&1; run_rc=$?
check 'a balanced section runs its suites and reports a section summary' \
  '[ "$run_rc" -eq 0 ] && grep -q "OFFLINE BASH SECTION SUMMARY section=1 of 3" "$TMP/run.log"'

run --balanced --list >/dev/null 2>&1; alone_rc=$?
check '--balanced without --shard is a configuration error' '[ "$alone_rc" -eq 2 ]'
run --windows-offline --exclude-reviewer-safety --balanced --shard 1/3 --list >/dev/null 2>&1; win_rc=$?
check '--balanced cannot rewrite the declared Windows sections' '[ "$win_rc" -eq 2 ]'
run --balanced --shard 9/9 --list >/dev/null 2>&1; over_rc=$?
check 'more sections than suites is a configuration error' '[ "$over_rc" -eq 2 ]'
cp "$MANIFEST" "$TMP/good.json"
sj test-heavy-a.sh ',"linux_seconds":"300"'   # a string measurement
run --balanced --shard 1/3 --list >/dev/null 2>&1; string_rc=$?
check 'a non-numeric measured-seconds value fails closed' '[ "$string_rc" -eq 2 ]'
sj test-heavy-a.sh ',"linux_seconds":-1'      # a negative measurement
run --balanced --shard 1/3 --list >/dev/null 2>&1; negative_rc=$?
check 'a negative measured-seconds value fails closed' '[ "$negative_rc" -eq 2 ]'
for f in "$CONFIGS"/*.json; do                  # nothing measured at all
  printf '{"kind":"bash"}\n' >"$f"
done
run --balanced --shard 1/3 --list >/dev/null 2>&1; empty_rc=$?
check 'an empty measured-seconds map fails closed' '[ "$empty_rc" -eq 2 ]'
sj test-heavy-a.sh ',"linux_seconds":300'
sj test-heavy-b.sh ',"linux_seconds":250'
sj test-heavy-c.sh ',"linux_seconds":200'
sj test-small-a.sh ',"linux_seconds":40'
sj test-small-b.sh ',"linux_seconds":30'
sj test-small-c.sh ',"linux_seconds":20'
sj test-small-d.sh ',"linux_seconds":10'
sj test-retired.sh ',"linux_seconds":99'
printf '%s\n' '{' >"$MANIFEST"                # a malformed global manifest
run --balanced --shard 1/3 --list >/dev/null 2>&1; malformed_rc=$?
check 'a malformed global manifest fails closed' '[ "$malformed_rc" -eq 2 ]'
rm -f "$MANIFEST"
run --balanced --shard 1/3 --list >/dev/null 2>&1; missing_rc=$?
check 'a missing manifest fails closed' '[ "$missing_rc" -eq 2 ]'
cp "$TMP/good.json" "$MANIFEST"

AGG="$ROOT/tools/ci/linux-offline-aggregate.sh"
agg() { AI_TEST_SUITE_DIR="$SUITES" AI_CI_SUITE_MANIFEST="$MANIFEST" bash "$AGG" "$@"; }
agg success 3 >/dev/null 2>&1; agg_ok=$?
check 'the aggregate passes when every section passed and coverage is exact' '[ "$agg_ok" -eq 0 ]'
for result in failure cancelled skipped '' neutral; do
  agg "$result" 3 >/dev/null 2>&1; agg_rc=$?
  check "the aggregate fails closed when sections report '${result}'" '[ "$agg_rc" -ne 0 ]'
done
for count in 0 x ''; do
  agg success "$count" >/dev/null 2>&1; count_rc=$?
  check "the aggregate refuses section count '${count}'" '[ "$count_rc" -ne 0 ]'
done
agg success >/dev/null 2>&1; argc_rc=$?
check 'the aggregate refuses a missing argument' '[ "$argc_rc" -eq 2 ]'

# A section runner that drops or duplicates a suite must fail the aggregate.
for defect in drop duplicate; do
  cat >"$TMP/stub-$defect.sh" <<STUB
#!/usr/bin/env bash
case " \$* " in
  *' --balanced '*) case " \$* " in
      *' 1/2 '*) printf 'BASH SELECTION\ntest-a.sh\n' ;;
      *) if [ '$defect' = drop ]; then printf 'BASH SELECTION\n'; else printf 'BASH SELECTION\ntest-a.sh\ntest-b.sh\n'; fi ;;
    esac ;;
  *) printf 'BASH SELECTION\ntest-a.sh\ntest-b.sh\n' ;;
esac
STUB
  AI_LINUX_OFFLINE_TEST_ALL="$TMP/stub-$defect.sh" bash "$AGG" success 2 >/dev/null 2>&1; defect_rc=$?
  check "the aggregate fails closed when a section would ${defect} a suite" '[ "$defect_rc" -eq 1 ]'
done
printf '#!/usr/bin/env bash\nexit 2\n' >"$TMP/stub-broken.sh"
AI_LINUX_OFFLINE_TEST_ALL="$TMP/stub-broken.sh" bash "$AGG" success 2 >/dev/null 2>&1; lister_rc=$?
check 'the aggregate fails closed when the section plan cannot be listed' '[ "$lister_rc" -eq 1 ]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
