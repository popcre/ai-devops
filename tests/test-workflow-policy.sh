#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/verify.yml"

windows_timeout="$(sed -n '/^  windows-offline:/,/^  windows-reviewer-safety:/p' "$workflow" | sed -n 's/^[[:space:]]*timeout-minutes:[[:space:]]*//p' | tr -d '\r' | head -1)"
case "$windows_timeout" in
  ''|*[!0-9]*) printf 'FAIL: windows-offline timeout is missing or invalid\n' >&2; exit 1 ;;
esac
[ "$windows_timeout" -ge 75 ] || { printf 'FAIL: windows-offline needs at least 75 minutes of measured runtime headroom\n' >&2; exit 1; }

printf 'PASS: complete Windows suite keeps measured runtime headroom\n'
