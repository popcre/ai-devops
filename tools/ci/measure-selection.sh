#!/usr/bin/env bash
# Measure how often pull-request suite selection falls back to every suite
# (issue #1563). For the last <n> first-parent commits on <ref> (default
# origin/main) prints commit, selected suite count, and whether it was
# select-all, then one summary line. Uses the current checkout's selector and
# manifest, so the same history can be measured before and after a mapping
# change. Read-only.
#   usage: tools/ci/measure-selection.sh <n> [ref]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/tests/lib-selection.sh"

n="${1:?usage: measure-selection.sh <n> [ref]}"
ref="${2:-origin/main}"
case "$n" in ''|*[!0-9]*) echo "n must be a positive integer" >&2; exit 2 ;; esac

mapfile -t suites < <(cd "$ROOT/tests" && ls test-*.sh)
total="${#suites[@]}"
all=0 none=0 narrowed=0 counted=0

printf 'commit\tselected\tselect_all\tsubject\n'
while IFS= read -r commit; do
  paths="$(git -C "$ROOT" diff --name-only "$commit^1" "$commit")"
  count="$(printf '%s\n' "$paths" | selection_affected_suites "$ROOT" "${suites[@]}" | grep -c .)"
  if [ "$count" -eq "$total" ]; then flag=yes; all=$((all + 1))
  elif [ "$count" -eq 0 ]; then flag=no; none=$((none + 1))
  else flag=no; narrowed=$((narrowed + 1))
  fi
  counted=$((counted + 1))
  printf '%s\t%s\t%s\t%s\n' "${commit:0:8}" "$count" "$flag" \
    "$(git -C "$ROOT" log -1 --format=%s "$commit" | cut -c1-70)"
done < <(git -C "$ROOT" rev-list --first-parent -n "$n" "$ref")

printf 'SUMMARY commits=%s suites=%s select_all=%s narrowed=%s none=%s\n' \
  "$counted" "$total" "$all" "$narrowed" "$none"
