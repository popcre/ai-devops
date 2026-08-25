#!/usr/bin/env bash
# Regression: copy_fact_union must never mint a second-generation machine
# suffix. Before this guard, a differing base--hetz.md was copied again as
# base--hetz--al8960ofc.md on the next machine, so every sync multiplied the
# memory folder and its MEMORY.md index (a 4.9 MB index was found 2026-08-24).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Load the sync functions without running the CLI.
eval "$(sed -n '/^copy_fact_union() {$/,/^}$/p' "$ROOT/bin/ai-sync-memory")"
DRY_RUN=""
FORGET_NAME=".forgotten"
run() { "$@"; }

mkdir -p "$work/src" "$work/dst"

# An unsuffixed fact that differs still gets one machine-suffixed copy.
printf 'local\n'  > "$work/src/fact.md"
printf 'remote\n' > "$work/dst/fact.md"

# An already-suffixed conflict artifact must NOT be suffixed again.
printf 'local\n'  > "$work/src/other--hetz.md"
printf 'remote\n' > "$work/dst/other--hetz.md"

copy_fact_union "$work/src" "$work/dst" "al8960ofc" 2>/dev/null

[[ -f "$work/dst/fact--al8960ofc.md" ]] ||
  { echo "FAIL: first-generation conflict copy was not created"; exit 1; }

extra="$(find "$work/dst" -name 'other--hetz--*' -o -name 'other--hetz-[0-9]*' | wc -l)"
if [[ "$extra" -ne 0 ]]; then
  echo "FAIL: second-generation suffix minted for an already-suffixed file:"
  find "$work/dst" -name 'other--hetz*'
  exit 1
fi

[[ "$(cat "$work/dst/other--hetz.md")" == "remote" ]] ||
  { echo "FAIL: destination copy of the suffixed conflict was overwritten"; exit 1; }

echo "PASS: memory sync does not fan out already-suffixed conflict copies"
