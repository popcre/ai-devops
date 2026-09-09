#!/usr/bin/env bash
# Deterministic offline Bash suite. Live/paid probes live under tests/probes/.
#
# Usage:
#   test-all.sh                        run every Bash suite (unchanged default)
#   test-all.sh --only <pattern>       run only suites whose name contains <pattern>
#   test-all.sh --changed-since <ref>  select by coarse change category vs <ref>
#   test-all.sh --windows-offline      run the manifest's ordinary Windows set
#   test-all.sh --windows-qwen        run the manifest's Qwen Windows set
#   test-all.sh --list                 print the selection and exit without running
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib-selection.sh
. "$ROOT/tests/lib-selection.sh"
SUITE_DIR="${AI_TEST_SUITE_DIR:-$ROOT/tests}"
MANIFEST="${AI_CI_SUITE_MANIFEST:-$ROOT/config/ci-suite-manifest.json}"

only=''; changed_since=''; list_only=false; windows_offline=false; windows_qwen=false
while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      [ $# -ge 2 ] || { printf 'test-all.sh: --only needs a pattern\n' >&2; exit 2; }
      only="$2"; shift 2 ;;
    --changed-since)
      [ $# -ge 2 ] || { printf 'test-all.sh: --changed-since needs a git ref\n' >&2; exit 2; }
      changed_since="$2"; shift 2 ;;
    --windows-offline) windows_offline=true; shift ;;
    --windows-qwen) windows_qwen=true; shift ;;
    --list) list_only=true; shift ;;
    -h|--help) sed -n '2,9p' "$ROOT/tests/test-all.sh"; exit 0 ;;
    *) printf 'test-all.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
selection_modes=0
[ -n "$only" ] && selection_modes=$((selection_modes + 1))
[ -n "$changed_since" ] && selection_modes=$((selection_modes + 1))
[ "$windows_offline" = true ] && selection_modes=$((selection_modes + 1))
[ "$windows_qwen" = true ] && selection_modes=$((selection_modes + 1))
if [ "$selection_modes" -gt 1 ]; then
  printf 'test-all.sh: selection modes are mutually exclusive\n' >&2; exit 2
fi

mapfile -t all_tests < <(find "$SUITE_DIR" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)

reason='every Bash suite'
if [ -n "$only" ]; then
  mapfile -t tests < <(selection_filter "$only" "${all_tests[@]}")
  reason="--only $only"
  if [ "${#tests[@]}" -eq 0 ]; then
    printf 'test-all.sh: --only %s matched no suite of %s\n' "$only" "${#all_tests[@]}" >&2
    exit 2
  fi
elif [ -n "$changed_since" ]; then
  if ! git -C "$ROOT" rev-parse --verify --quiet "$changed_since^{commit}" >/dev/null; then
    printf 'test-all.sh: --changed-since %s is not a commit in this repository\n' "$changed_since" >&2
    exit 2
  fi
  categories="$(git -C "$ROOT" diff --no-renames --name-only "$changed_since"...HEAD | selection_categories_for_paths "$ROOT")" || {
    printf 'test-all.sh: could not classify changes since %s\n' "$changed_since" >&2; exit 2; }
  mapfile -t tests < <(selection_by_categories "$categories" "${all_tests[@]}")
  reason="--changed-since $changed_since categories=${categories:-none}"
  case " $categories " in
    *' powershell '*) printf 'NOTE PowerShell changes are not covered by this runner; run tests/test-all.ps1\n' ;;
  esac
  if [ "${#tests[@]}" -eq 0 ]; then
    printf 'BASH SELECTION %s selected=0 of %s\n' "$reason" "${#all_tests[@]}"
    printf 'No Bash suite is relevant to these changes; skipping the long suite by design.\n'
    printf '\nOFFLINE BASH SUMMARY tests=0 failures=0\n'
    exit 0
  fi
elif [ "$windows_offline" = true ]; then
  [ -f "$MANIFEST" ] || { printf 'test-all.sh: Windows suite manifest is missing: %s\n' "$MANIFEST" >&2; exit 2; }
  jq -e '.windows_offline_bash | type == "array" and length > 0 and all(.[]; type == "string")' "$MANIFEST" >/dev/null 2>&1 || {
    printf 'test-all.sh: Windows suite manifest has no valid windows_offline_bash group\n' >&2; exit 2; }
  mapfile -t tests < <(jq -r '.windows_offline_bash[]' "$MANIFEST" | tr -d '\r')
  [ "$(printf '%s\n' "${tests[@]}" | LC_ALL=C sort -u | wc -l)" -eq "${#tests[@]}" ] || {
    printf 'test-all.sh: windows_offline_bash contains a duplicate suite\n' >&2; exit 2; }
  for name in "${tests[@]}"; do
    printf '%s\n' "${all_tests[@]}" | grep -Fxq "$name" || {
      printf 'test-all.sh: windows_offline_bash names an undiscovered suite: %s\n' "$name" >&2; exit 2; }
  done
  reason='Windows-sensitive Bash set'
elif [ "$windows_qwen" = true ]; then
  [ -f "$MANIFEST" ] || { printf 'test-all.sh: Windows suite manifest is missing: %s\n' "$MANIFEST" >&2; exit 2; }
  jq -e '.windows_qwen_bash | type == "array" and length > 0 and all(.[]; type == "string")' "$MANIFEST" >/dev/null 2>&1 || {
    printf 'test-all.sh: Windows suite manifest has no valid windows_qwen_bash group\n' >&2; exit 2; }
  mapfile -t tests < <(jq -r '.windows_qwen_bash[]' "$MANIFEST" | tr -d '\r')
  [ "$(printf '%s\n' "${tests[@]}" | LC_ALL=C sort -u | wc -l)" -eq "${#tests[@]}" ] || {
    printf 'test-all.sh: windows_qwen_bash contains a duplicate suite\n' >&2; exit 2; }
  for name in "${tests[@]}"; do
    printf '%s\n' "${all_tests[@]}" | grep -Fxq "$name" || {
      printf 'test-all.sh: windows_qwen_bash names an undiscovered suite: %s\n' "$name" >&2; exit 2; }
  done
  reason='Qwen-affected Windows Bash set'
else
  tests=("${all_tests[@]}")
fi

printf 'BASH SELECTION %s selected=%s of %s\n' "$reason" "${#tests[@]}" "${#all_tests[@]}"
if [ "$list_only" = true ]; then
  printf '%s\n' "${tests[@]}"
  exit 0
fi

failures=0; count=0
timings=()
suite_started=$(date +%s)
for name in "${tests[@]}"; do
  count=$((count + 1)); printf '\n===== BASH %s =====\n' "$name"
  # stdout is block-buffered when redirected, so a killed run can lose the
  # marker for the suite it was actually in. stderr is unbuffered and reaches
  # the CI progress reader immediately.
  printf '===== BASH %s =====\n' "$name" >&2
  started=$(date +%s)
  bash "$SUITE_DIR/$name" || failures=$((failures + 1))
  elapsed=$(( $(date +%s) - started ))
  timings+=("$(printf '%6d %s' "$elapsed" "$name")")
  printf -- '----- BASH %s took %ss -----\n' "$name" "$elapsed"
done
total=$(( $(date +%s) - suite_started ))
printf '\nBASH SUITE TIMINGS seconds=%s slowest-first\n' "$total"
if [ "${#timings[@]}" -gt 0 ]; then
  printf '%s\n' "${timings[@]}" | LC_ALL=C sort -rn
fi

printf '\nOFFLINE BASH SUMMARY tests=%s failures=%s\n' "$count" "$failures"
[ "$failures" -eq 0 ]
