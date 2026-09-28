#!/usr/bin/env bash
# Deterministic offline Bash suite. Live/paid probes live under tests/probes/.
#
# Usage:
#   test-all.sh                        run every Bash suite (unchanged default)
#   test-all.sh --only <pattern>       run only suites whose name contains <pattern>
#   test-all.sh --changed-since <ref>  select suites affected by changes vs <ref>
#   test-all.sh --changed-since <ref> --shard <i>/<n>
#                                      run only the selected suites that land
#                                      in section <i> of <n> (issue #805)
#   test-all.sh --windows-offline      run the manifest's ordinary Windows set
#   test-all.sh --windows-offline --exclude-reviewer-safety
#                                      omit suites assigned to the reviewer lane
#   test-all.sh --windows-offline --exclude-reviewer-safety --shard <i>/<n>
#                                      run only declared section <i> of <n> (#210)
#   test-all.sh --windows-offline --changed-since <ref>
#                                      narrow the Windows lane to affected suites
#   test-all.sh --list                 print the selection and exit without running
#   test-all.sh --shard <i>/<n>         partition every discovered suite round-robin
#   test-all.sh --shard <i>/<n> --balanced
#                                      partition every discovered suite by the
#                                      manifest's measured Linux suite seconds
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib-selection.sh
. "$ROOT/tests/lib-selection.sh"
SUITE_DIR="${AI_TEST_SUITE_DIR:-$ROOT/tests}"
MANIFEST="${AI_CI_SUITE_MANIFEST:-$ROOT/config/ci-suite-manifest.json}"
SHARED_RUNTIME_LOCK="${AI_TEST_SHARED_RUNTIME_LOCK:-}"
SHARED_RUNTIME_LOCK_HELD=0

release_shared_runtime_lock() {
  [ "$SHARED_RUNTIME_LOCK_HELD" -eq 1 ] || return 0
  rmdir -- "$SHARED_RUNTIME_LOCK" 2>/dev/null || true
  SHARED_RUNTIME_LOCK_HELD=0
}
release_shared_runtime_lock_on_signal() {
  local rc="$1"
  release_shared_runtime_lock
  trap - EXIT INT TERM
  exit "$rc"
}
if [ -n "$SHARED_RUNTIME_LOCK" ]; then
  mkdir -- "$SHARED_RUNTIME_LOCK" 2>/dev/null || {
    [ -d "$SHARED_RUNTIME_LOCK" ] && printf 'test-all.sh: shared installed runtime is already in use: %s\n' "$SHARED_RUNTIME_LOCK" >&2 && exit 3
    printf 'test-all.sh: shared-runtime lock cannot be created safely: %s\n' "$SHARED_RUNTIME_LOCK" >&2
    exit 4
  }
  SHARED_RUNTIME_LOCK_HELD=1
  trap release_shared_runtime_lock EXIT
  trap 'release_shared_runtime_lock_on_signal 130' INT
  trap 'release_shared_runtime_lock_on_signal 143' TERM
  unset AI_TEST_SHARED_RUNTIME_LOCK
fi

only=''; changed_since=''; list_only=false; windows_offline=false; exclude_reviewer_safety=false
shard=''; shard_requested=false; balanced=false
while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      [ $# -ge 2 ] || { printf 'test-all.sh: --only needs a pattern\n' >&2; exit 2; }
      only="$2"; shift 2 ;;
    --changed-since)
      [ $# -ge 2 ] || { printf 'test-all.sh: --changed-since needs a git ref\n' >&2; exit 2; }
      changed_since="$2"; shift 2 ;;
    --windows-offline) windows_offline=true; shift ;;
    --exclude-reviewer-safety) exclude_reviewer_safety=true; shift ;;
    --shard)
      [ $# -ge 2 ] || { printf 'test-all.sh: --shard needs <i>/<n>\n' >&2; exit 2; }
      [ "$shard_requested" = false ] || { printf 'test-all.sh: duplicate --shard\n' >&2; exit 2; }
      shard_requested=true
      shard="$2"; shift 2 ;;
    --balanced) balanced=true; shift ;;
    --list) list_only=true; shift ;;
    -h|--help) sed -n '2,22p' "$ROOT/tests/test-all.sh"; exit 0 ;;
    *) printf 'test-all.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$exclude_reviewer_safety" = false ] || [ "$windows_offline" = true ] || {
  printf 'test-all.sh: --exclude-reviewer-safety requires --windows-offline\n' >&2; exit 2; }
[ "$balanced" = false ] || { [ "$shard_requested" = true ] && [ "$windows_offline" = false ]; } || {
  printf 'test-all.sh: --balanced requires --shard without --windows-offline\n' >&2; exit 2; }
# PR sections retain their declared assignment. Complete sections partition
# every discovered suite; no-argument runs retain the complete serial backstop.
shard_index=''; shard_total=''
if [ "$shard_requested" = true ]; then
  [ "$windows_offline" = false ] || [ "$exclude_reviewer_safety" = true ] || {
    printf 'test-all.sh: Windows --shard requires --exclude-reviewer-safety\n' >&2; exit 2; }
  [ -z "$only" ] || {
    printf 'test-all.sh: --shard cannot be combined with --only\n' >&2; exit 2; }
  # --changed-since may share a section with --shard: the section still owns a
  # complete balanced assignment, and the change filter narrows inside it.
  # Exactly one slash. Splitting on the first and last slash independently
  # would read `1/2/4` as section 1 of 4 and run a real, wrong selection.
  [[ "$shard" =~ ^[0-9]+/[0-9]+$ ]] || {
    printf 'test-all.sh: --shard must be <i>/<n>, got %s\n' "$shard" >&2; exit 2; }
  shard_index="${shard%%/*}"; shard_total="${shard#*/}"
  case "$shard_index" in *[!0-9]*|'') shard_index='' ;; esac
  case "$shard_total" in *[!0-9]*|'') shard_total='' ;; esac
  [ -n "$shard_index" ] && [ -n "$shard_total" ] || {
    printf 'test-all.sh: --shard must be <i>/<n>, got %s\n' "$shard" >&2; exit 2; }
  [ "${#shard_index}" -le 9 ] && [ "${#shard_total}" -le 9 ] || {
    printf 'test-all.sh: --shard values exceed the supported integer range\n' >&2; exit 2; }
  shard_index=$((10#$shard_index)); shard_total=$((10#$shard_total))
  [ "$shard_total" -ge 1 ] || {
    printf 'test-all.sh: --shard count must be at least 1, got %s\n' "$shard_total" >&2; exit 2; }
  [ "$shard_index" -ge 1 ] && [ "$shard_index" -le "$shard_total" ] || {
    printf 'test-all.sh: --shard index %s is outside 1..%s\n' "$shard_index" "$shard_total" >&2; exit 2; }
fi
if [ -n "$only" ] && [ -n "$changed_since" ]; then
  printf 'test-all.sh: --only and --changed-since are mutually exclusive\n' >&2; exit 2
fi
if [ -n "$only" ] && [ "$windows_offline" = true ]; then
  printf 'test-all.sh: --only and --windows-offline are mutually exclusive\n' >&2; exit 2
fi
# --changed-since composes with --windows-offline and with --shard (issue #805).

mapfile -t all_tests < <(find "$SUITE_DIR" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)

# Suspended suites drop out of every lane before selection (issue: Kimi CI
# suspension, 2026-09-17). Suspension is declared in the manifest, never by
# deleting the file: a suspended suite stays runnable directly by file name
# (bash tests/test-ai-kimi.sh) and returns to the lanes when its manifest
# entry is removed.
if [ -f "$MANIFEST" ] && jq -e 'has("suspended_bash")' "$MANIFEST" >/dev/null 2>&1; then
  jq -e '.suspended_bash | type == "array" and all(.[]; type == "string")' "$MANIFEST" >/dev/null 2>&1 || {
    printf 'test-all.sh: suite manifest has an invalid suspended_bash group\n' >&2; exit 2; }
  mapfile -t suspended_tests < <(jq -r '.suspended_bash[]' "$MANIFEST" | tr -d '\r')
  for suspended in "${suspended_tests[@]}"; do
    if printf '%s\n' "${all_tests[@]}" | grep -Fx "$suspended" >/dev/null; then
      mapfile -t all_tests < <(printf '%s\n' "${all_tests[@]}" | grep -Fxv "$suspended")
      printf 'test-all.sh: suspended suite skipped: %s\n' "$suspended" >&2
    else
      printf 'test-all.sh: WARNING suspended_bash names a suite not on disk: %s\n' "$suspended" >&2
    fi
  done
fi

# Affected-suite filter (issue #805). When --changed-since is set, only the
# suites a change can break stay in the run. Fail-closed: an unknown path keeps
# every suite. An empty filter result is a justified empty set, not a gap.
affected_filter=false
mapfile -t affected_tests < <(:)
if [ -n "$changed_since" ]; then
  if ! git -C "$ROOT" rev-parse --verify --quiet "$changed_since^{commit}" >/dev/null; then
    printf 'test-all.sh: --changed-since %s is not a commit in this repository\n' "$changed_since" >&2
    exit 2
  fi
  changed_paths="$(git -C "$ROOT" diff --no-renames --name-only "$changed_since"...HEAD)" || {
    printf 'test-all.sh: could not list changes since %s\n' "$changed_since" >&2; exit 2; }
  selected_out="$(printf '%s\n' "$changed_paths" | selection_affected_suites "$ROOT" "${all_tests[@]}")" || {
    printf 'test-all.sh: could not map changes since %s to suites\n' "$changed_since" >&2
    exit 2
  }
  affected_tests=()
  while IFS= read -r line; do
    case "$line" in test-*) affected_tests+=("$line") ;; esac
  done <<<"${selected_out:-}"
  affected_filter=true
fi

# selection_intersect <suite>...
# Prints only suites kept by the active affected filter (or all when inactive).
selection_intersect() {
  local suite
  if [ "$affected_filter" = false ]; then
    printf '%s\n' "$@"
    return 0
  fi
  [ "${#affected_tests[@]}" -gt 0 ] || return 0
  for suite in "$@"; do
    printf '%s\n' "${affected_tests[@]}" | grep -Fx "$suite" >/dev/null && printf '%s\n' "$suite"
  done
  return 0
}

reason='every Bash suite'
if [ -n "$only" ]; then
  mapfile -t tests < <(selection_filter "$only" "${all_tests[@]}")
  reason="--only $only"
  if [ "${#tests[@]}" -eq 0 ]; then
    printf 'test-all.sh: --only %s matched no suite of %s\n' "$only" "${#all_tests[@]}" >&2
    exit 2
  fi
elif [ "$windows_offline" = true ]; then
  [ -f "$MANIFEST" ] || { printf 'test-all.sh: Windows suite manifest is missing: %s\n' "$MANIFEST" >&2; exit 2; }
  jq -e '.windows_offline_bash | type == "array" and length > 0 and all(.[]; type == "string")' "$MANIFEST" >/dev/null 2>&1 || {
    printf 'test-all.sh: Windows suite manifest has no valid windows_offline_bash group\n' >&2; exit 2; }
  mapfile -t tests < <(jq -r '.windows_offline_bash[]' "$MANIFEST" | tr -d '\r')
  [ "$(printf '%s\n' "${tests[@]}" | LC_ALL=C sort -u | wc -l)" -eq "${#tests[@]}" ] || {
    printf 'test-all.sh: windows_offline_bash contains a duplicate suite\n' >&2; exit 2; }
  if [ "$exclude_reviewer_safety" = true ]; then
    jq -e '.windows_reviewer_safety_bash | type == "array" and length > 0 and all(.[]; type == "string")' "$MANIFEST" >/dev/null 2>&1 || {
      printf 'test-all.sh: Windows suite manifest has no valid windows_reviewer_safety_bash group\n' >&2; exit 2; }
    mapfile -t reviewer_tests < <(jq -r '.windows_reviewer_safety_bash[]' "$MANIFEST" | tr -d '\r')
    mapfile -t tests < <(comm -23 \
      <(printf '%s\n' "${tests[@]}" | LC_ALL=C sort) \
      <(printf '%s\n' "${reviewer_tests[@]}" | LC_ALL=C sort))
  fi
  for name in "${tests[@]}"; do
    printf '%s\n' "${all_tests[@]}" | grep -Fx "$name" >/dev/null || {
      printf 'test-all.sh: windows_offline_bash names an undiscovered suite: %s\n' "$name" >&2; exit 2; }
  done
  if [ "$exclude_reviewer_safety" = true ]; then
    reason='Windows-sensitive Bash set excluding reviewer-safety fallback suites'
  else
    reason='Windows-sensitive Bash set'
  fi
  if [ -n "$shard" ]; then
    # Sections are an explicit declared assignment, not a computed split, so a
    # reviewer can read which section proves what. The union check below is the
    # real guarantee: the declared sections must reconstitute this lane exactly,
    # or the run is a configuration error rather than quiet coverage loss.
    jq -e '.windows_offline_shards | type == "array" and length > 0 and all(.[]; type == "array" and length > 0 and all(.[]; type == "string"))' "$MANIFEST" >/dev/null 2>&1 || {
      printf 'test-all.sh: Windows suite manifest has no valid windows_offline_shards group\n' >&2; exit 2; }
    declared_total="$(jq '.windows_offline_shards | length' "$MANIFEST")"
    [ "$declared_total" -eq "$shard_total" ] || {
      printf 'test-all.sh: --shard count %s does not match the %s declared sections\n' "$shard_total" "$declared_total" >&2; exit 2; }
    mapfile -t shard_union < <(jq -r '.windows_offline_shards[][]' "$MANIFEST" | tr -d '\r')
    [ "$(printf '%s\n' "${shard_union[@]}" | LC_ALL=C sort -u | wc -l)" -eq "${#shard_union[@]}" ] || {
      printf 'test-all.sh: a suite is assigned to more than one section\n' >&2; exit 2; }
    [ "$(printf '%s\n' "${shard_union[@]}" | LC_ALL=C sort)" = "$(printf '%s\n' "${tests[@]}" | LC_ALL=C sort)" ] || {
      printf 'test-all.sh: declared sections do not cover the Windows lane exactly\n' >&2; exit 2; }
    mapfile -t tests < <(jq -r --argjson i "$((shard_index - 1))" '.windows_offline_shards[$i][]' "$MANIFEST" | tr -d '\r')
    reason="$reason section $shard_index of $shard_total"
  fi
  if [ "$affected_filter" = true ]; then
    mapfile -t tests < <(selection_intersect ${tests[@]+"${tests[@]}"})
    reason="$reason affected-since $changed_since"
    if [ "${#tests[@]}" -eq 0 ]; then
      printf 'BASH SELECTION %s selected=0 of %s\n' "$reason" "${#all_tests[@]}"
      printf 'No Windows-sensitive Bash suite is affected; justifying an empty section.\n'
      printf '\nOFFLINE BASH SUMMARY tests=0 failures=0\n'
      exit 0
    fi
  fi
  if [ -n "$shard" ] && [ "${#tests[@]}" -eq 0 ] && [ "$affected_filter" = false ]; then
    printf 'test-all.sh: section %s of %s is empty\n' "$shard_index" "$shard_total" >&2
    exit 2
  fi
else
  tests=("${all_tests[@]}")
  if [ -n "$shard" ]; then
    [ "$shard_total" -le "${#all_tests[@]}" ] || {
      printf 'test-all.sh: complete section count exceeds discovered suites\n' >&2; exit 2; }
    tests=()
    if [ "$balanced" = true ]; then
      # Greedy longest-first packing by measured seconds (#533 speedup 2).
      # Every discovered suite is placed in exactly one section; a suite with
      # no measurement is still placed, at a default weight, so a new suite
      # can never fall out of the lane.
      [ -f "$MANIFEST" ] || { printf 'test-all.sh: suite manifest is missing: %s\n' "$MANIFEST" >&2; exit 2; }
      jq -e '.linux_offline_suite_seconds | type == "object" and length > 0 and all(.[]; type == "number" and . >= 0 and floor == .)' "$MANIFEST" >/dev/null 2>&1 || {
        printf 'test-all.sh: suite manifest has no valid linux_offline_suite_seconds map\n' >&2; exit 2; }
      default_seconds=30
      declare -A suite_seconds=()
      while read -r w name; do
        [ -n "$name" ] && suite_seconds["$name"]="$w"
      done < <(jq -r '.linux_offline_suite_seconds | to_entries[] | "\(.value) \(.key)"' "$MANIFEST" | tr -d '\r')
      mapfile -t weighted < <(
        for name in "${all_tests[@]}"; do
          printf '%s %s\n' "${suite_seconds[$name]:-$default_seconds}" "$name"
        done | LC_ALL=C sort -k1,1nr -k2,2
      )
      loads=()
      for ((b=0; b<shard_total; b++)); do loads[b]=0; done
      for entry in "${weighted[@]}"; do
        w="${entry%% *}"; name="${entry#* }"; best=0
        for ((b=1; b<shard_total; b++)); do
          [ "${loads[b]}" -lt "${loads[best]}" ] && best=$b
        done
        loads[best]=$((loads[best] + w))
        [ "$((best + 1))" -ne "$shard_index" ] || tests+=("$name")
      done
      mapfile -t tests < <(printf '%s\n' "${tests[@]}" | LC_ALL=C sort)
      reason="every Bash suite, balanced section $shard_index of $shard_total (~${loads[shard_index-1]}s measured)"
    else
      for ((i=0; i<${#all_tests[@]}; i++)); do
        [ "$((i % shard_total + 1))" -ne "$shard_index" ] || tests+=("${all_tests[i]}")
      done
      reason="every Bash suite, complete section $shard_index of $shard_total"
    fi
    if [ "${#tests[@]}" -eq 0 ] && [ "$affected_filter" = false ]; then
      printf 'test-all.sh: section %s of %s is empty\n' "$shard_index" "$shard_total" >&2
      exit 2
    fi
  fi
  if [ "$affected_filter" = true ]; then
    mapfile -t tests < <(selection_intersect ${tests[@]+"${tests[@]}"})
    reason="changes since $changed_since, ${reason}"
    if [ "${#tests[@]}" -eq 0 ]; then
      printf 'BASH SELECTION %s selected=0 of %s\n' "$reason" "${#all_tests[@]}"
      printf 'No Bash suite is affected by these changes; skipping the long suite by design.\n'
      printf '\nOFFLINE BASH SUMMARY tests=0 failures=0\n'
      exit 0
    fi
  fi
fi

printf 'BASH SELECTION %s selected=%s of %s\n' "$reason" "${#tests[@]}" "${#all_tests[@]}"
if [ "$list_only" = true ]; then
  printf '%s\n' "${tests[@]}"
  exit 0
fi

failures=0; count=0
timings=()
suite_started=$(date +%s)
section_tag=''
[ -z "$shard" ] || section_tag="[section $shard_index/$shard_total] "
# A section announces its plan and its position before it starts, so a
# stalled section reads as "section 2 stopped inside suite 7 of 9" rather
# than as an anonymous job that died at its ceiling (issue #210).
if [ -n "$shard" ]; then
  printf 'BASH SECTION %s of %s suites=%s\n' "$shard_index" "$shard_total" "${#tests[@]}"
  printf 'BASH SECTION %s of %s suites=%s\n' "$shard_index" "$shard_total" "${#tests[@]}" >&2
fi
for name in "${tests[@]}"; do
  count=$((count + 1)); printf '\n===== BASH %s%s (%s of %s) =====\n' "$section_tag" "$name" "$count" "${#tests[@]}"
  # stdout is block-buffered when redirected, so a killed run can lose the
  # marker for the suite it was actually in. stderr is unbuffered and reaches
  # the CI progress reader immediately.
  printf '===== BASH %s%s (%s of %s) =====\n' "$section_tag" "$name" "$count" "${#tests[@]}" >&2
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

if [ -n "$shard" ]; then
  printf '\nOFFLINE BASH SECTION SUMMARY section=%s of %s tests=%s failures=%s seconds=%s\n' \
    "$shard_index" "$shard_total" "$count" "$failures" "$total"
fi
printf '\nOFFLINE BASH SUMMARY tests=%s failures=%s\n' "$count" "$failures"
[ "$failures" -eq 0 ]
