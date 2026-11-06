#!/usr/bin/env bash
# Step 3.1 (plan_ci-process-repair.md, #2367): the runner-label scan must flag
# a dead label and pass every live one. Fixtures only -- no network.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TOOL="$ROOT/tools/ci/check-runner-labels.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/repo/.github/workflows"
cat > "$TMP/config.json" <<'JSON'
{
  "schema_version": 2,
  "hosted_windows": "windows-2025",
  "qualified_label": "ai-devops-windows-qualified",
  "qualified_windows": ["self-hosted", "Windows", "X64", "ai-devops-windows-qualified"],
  "section_label": "ai-devops-windows-section",
  "hosted_linux": "ubuntu-24.04",
  "linux_self_hosted": ["self-hosted", "Linux", "X64", "edge-dev3"]
}
JSON

cat > "$TMP/repo/.github/workflows/good.yml" <<'YAML'
name: good
on: [push]
jobs:
  hosted:
    runs-on: ubuntu-24.04
    steps: [{run: echo hi}]
  hosted-array:
    runs-on: [self-hosted, Linux, X64, edge-dev3]
    steps: [{run: echo hi}]
  qualified:
    runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]
    steps: [{run: echo hi}]
  dynamic:
    runs-on: ${{ matrix.label }}
    steps: [{run: echo hi}]
YAML

# The Blacksmith class: a provider label that no longer has a runner anywhere.
cat > "$TMP/repo/.github/workflows/dead.yml" <<'YAML'
name: dead
on: [push]
jobs:
  gone:
    runs-on: blacksmith-4-core-windows
    steps: [{run: echo hi}]
YAML

echo "== clean fixture (no dead.yml)"
cp "$TMP/repo/.github/workflows/dead.yml" "$TMP/dead-kept.yml"
rm "$TMP/repo/.github/workflows/dead.yml"
node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/config.json" | grep -q "runner label scan clean"

echo "== dead-label fixture flags exactly the dead label"
mv "$TMP/dead-kept.yml" "$TMP/repo/.github/workflows/dead.yml"
set +e
OUT="$(node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/config.json")"
CODE=$?
set -e
[ "$CODE" -eq 1 ] || { echo "FAIL: expected exit 1 for a dead label, got $CODE" >&2; exit 1; }
echo "$OUT" | grep -q "DEAD-LABEL dead.yml: blacksmith-4-core-windows" || {
  echo "FAIL: dead label not named in output: $OUT" >&2; exit 1; }
echo "$OUT" | grep -vq "DEAD-LABEL dead.yml: ubuntu" || true

echo "== malformed config refuses with exit 2"
set +e
CODE=0
node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/missing.json" >/dev/null 2>&1 || CODE=$?
set -e
[ "$CODE" -eq 2 ] || { echo "FAIL: expected exit 2 for broken config, got $CODE" >&2; exit 1; }

echo "PASS test-check-runner-labels"
