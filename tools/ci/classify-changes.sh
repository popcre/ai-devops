#!/usr/bin/env bash
# Classify newline-delimited repository paths for coarse CI routing.
set -uo pipefail

event="${1:-}"
[ -n "$event" ] || { printf 'usage: classify-changes.sh <event-name>\n' >&2; exit 2; }

prose_only=true
skills=false
code=false
workflow=false
powershell=false
test_fixtures=false
count=0

while IFS= read -r path; do
  [ -n "$path" ] || continue
  count=$((count + 1))
  case "$path" in skills/*) skills=true ;; esac
  case "$path" in .github/workflows/*) workflow=true ;; esac
  case "$path" in *.ps1|*.psm1|*.psd1) powershell=true ;; esac
  case "$path" in tests/fixtures/*) test_fixtures=true ;; esac
  case "$path" in
    README.md|AGENTS.md|bugs.md|plan_*.md|HANDOFF.d/*.md|docs/*.md|docs/**/*.md|tests/verification/*.md|tests/verification/**/*.md) ;;
    *) prose_only=false; code=true ;;
  esac
done

# Only pull requests may use the prose bypass. All other events stay complete.
if [ "$event" != pull_request ] || [ "$count" -eq 0 ]; then prose_only=false; fi
run_long=true
[ "$prose_only" = true ] && run_long=false

printf 'changed_count=%s\n' "$count"
printf 'prose_only=%s\n' "$prose_only"
printf 'skills=%s\n' "$skills"
printf 'code=%s\n' "$code"
printf 'workflow=%s\n' "$workflow"
printf 'powershell=%s\n' "$powershell"
printf 'test_fixtures=%s\n' "$test_fixtures"
printf 'run_long=%s\n' "$run_long"
