#!/usr/bin/env bash
# Focused bulk classifier regression. Also runs from test-ai-task-gates.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
command -v jq >/dev/null
command -v timeout >/dev/null
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"
export AI_TASK_GATES_DIR="$TMP/state"

mkdir -p "$TMP/repo"
git init -q --initial-branch=main "$TMP/repo"
git -C "$TMP/repo" config user.name T
git -C "$TMP/repo" config user.email t@e
git -C "$TMP/repo" remote add origin https://github.com/popcre/ai-devops.git
printf 'base\n' > "$TMP/repo/README.md"
git -C "$TMP/repo" add README.md
git -C "$TMP/repo" commit -qm init

# The former per-match process spawning took over six minutes for 100 paths on
# Windows; compiled rules finished the same sample in under 15 seconds.
for ((n=1; n<=100; n++)); do printf 'docs/bulk-%03d.md\n' "$n"; done > "$TMP/paths.txt"
printf 'bin/ai-review-lifecycle\nrandom/bulk.bin\n' >> "$TMP/paths.txt"
result="$(cd "$TMP/repo" && timeout 180 "$ROOT/bin/ai-task-gates" explain --json --paths-from "$TMP/paths.txt")"
jq -e '.changed_count==102 and .observed_class=="reviewer-safety" and
  ([.changes[]|select(.path|startswith("docs/bulk-"))]|length)==100 and
  ([.changes[]|select(.path|startswith("docs/bulk-"))]|all(.class=="prose")) and
  ([.changes[]|select(.path=="bin/ai-review-lifecycle")][0].class)=="reviewer-safety" and
  ([.changes[]|select(.path=="random/bulk.bin")][0].class)=="code"' <<< "$result" >/dev/null
printf 'bulk classifier: 1 passed, 0 failed\n'
