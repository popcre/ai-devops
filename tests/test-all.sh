#!/usr/bin/env bash
# Deterministic offline Bash suite. Live/paid probes live under tests/probes/.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0; count=0
mapfile -t tests < <(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.sh' ! -name 'test-all.sh' -printf '%f\n' | LC_ALL=C sort)
for name in "${tests[@]}"; do
  count=$((count + 1)); printf '\n===== BASH %s =====\n' "$name"
  bash "$ROOT/tests/$name" || failures=$((failures + 1))
done
printf '\nOFFLINE BASH SUMMARY tests=%s failures=%s\n' "$count" "$failures"
[ "$failures" -eq 0 ]
