#!/usr/bin/env bash
# Deterministic offline Bash suite. Live/paid probes live under tests/probes/.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0; count=0
timings=()
suite_started=$(date +%s)
mapfile -t tests < <(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)
for name in "${tests[@]}"; do
  count=$((count + 1)); printf '\n===== BASH %s =====\n' "$name"
  started=$(date +%s)
  bash "$ROOT/tests/$name" || failures=$((failures + 1))
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
