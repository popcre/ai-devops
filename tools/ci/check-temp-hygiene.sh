#!/usr/bin/env bash
# check-temp-hygiene.sh — regression guard for plan_session-temp-cleanup.md step 6.
# Fails when a shell script under the given roots (default: bin tools)
#   * hard-codes a /tmp/ path (use $TMPDIR; a line may opt out with
#     "# temp-hygiene: allow" when /tmp itself is the subject), or
#   * calls mktemp without any trap in the file, unless the file is listed in
#     config/temp-hygiene-baseline.txt (legacy files that remove their own temps
#     explicitly and run inside a session-owned temp root).
# usage: check-temp-hygiene.sh [--baseline FILE] [ROOT...]
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
baseline="$repo/config/temp-hygiene-baseline.txt"
if [ "${1:-}" = --baseline ]; then baseline="$2"; shift 2; fi
[ $# -gt 0 ] || set -- "$repo/bin" "$repo/tools"
fail=0
is_shell() {
  case "$1" in *.sh) return 0 ;; *.ps1|*.cmd|*.bat|*.py|*.mjs|*.cjs|*.js|*.json|*.md) return 1 ;; esac
  head -1 "$1" 2>/dev/null | grep -q '^#!.*\(bash\|/sh\)'
}
while IFS= read -r -d '' f; do
  is_shell "$f" || continue
  rel="${f#"$repo"/}"
  hits="$(grep -nE "(^|[\"' =(:])/tmp/" "$f" | grep -v '^[0-9]*:[[:space:]]*#' | grep -v 'temp-hygiene: allow' || true)"
  if [ -n "$hits" ]; then
    printf 'temp-hygiene: %s hard-codes /tmp/ (use $TMPDIR):\n%s\n' "$rel" "$hits"; fail=1  # temp-hygiene: allow
  fi
  if grep -q 'mktemp' "$f" && ! grep -q 'trap' "$f"; then
    if ! grep -qxF "$rel" "$baseline" 2>/dev/null; then
      printf 'temp-hygiene: %s calls mktemp without a cleanup trap\n' "$rel"; fail=1
    fi
  fi
done < <(find "$@" -type f -print0 2>/dev/null)
[ "$fail" = 0 ] && echo "temp-hygiene: OK"
exit "$fail"
