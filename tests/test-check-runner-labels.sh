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
  "warpbuild_windows": "warp-custom-warpbuild-win2022-canary",
  "reserve_qualified_for_reviewer_events": ["workflow_dispatch"],
  "linux_unfit_suites": ["test-ai-lock-doctor.sh"],
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
  hosted-slim:
    runs-on: ubuntu-slim
    steps: [{run: echo hi}]
  qualified:
    runs-on: [self-hosted, wInDoWs, X64, AI-DEVOPS-WINDOWS-QUALIFIED] # case-insensitive
    steps: [{run: echo hi}]
  dynamic:
    runs-on: [self-hosted, ${{ format('{0}-{1}', matrix.os, matrix.job) }}]
    steps: [{run: echo hi}]
  warpbuild:
    runs-on: warp-custom-warpbuild-win2022-canary
    steps: [{run: echo hi}]
YAML

# The Blacksmith class: a provider label that no longer has a runner anywhere.
cat > "$TMP/repo/.github/workflows/dead.yml" <<'YAML'
name: dead
on: [push]
jobs:
  gone:
    runs-on:
      - self-hosted
      - blacksmith-4-core-windows # provider retired
    steps: [{run: echo hi}]
  event-name-is-not-a-label:
    runs-on: workflow_dispatch
    steps: [{run: echo hi}]
  suite-name-is-not-a-label:
    runs-on: test-ai-lock-doctor.sh
    steps: [{run: echo hi}]
  bare-hosted-image:
    runs-on: windows
    steps: [{run: echo hi}]
YAML

echo "== clean fixture (no dead.yml)"
cp "$TMP/repo/.github/workflows/dead.yml" "$TMP/dead-kept.yml"
rm "$TMP/repo/.github/workflows/dead.yml"
node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/config.json" | grep -q "runner label scan clean"

echo "== dead-label fixture flags unknown labels only"
mv "$TMP/dead-kept.yml" "$TMP/repo/.github/workflows/dead.yml"
set +e
OUT="$(node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/config.json")"
CODE=$?
set -e
[ "$CODE" -eq 1 ] || { echo "FAIL: expected exit 1 for a dead label, got $CODE" >&2; exit 1; }
EXPECTED="$(printf 'DEAD-LABEL dead.yml: %s\n' blacksmith-4-core-windows workflow_dispatch test-ai-lock-doctor.sh windows)"
[ "$(grep '^DEAD-LABEL ' <<< "$OUT")" = "$EXPECTED" ] || {
  echo "FAIL: unexpected dead labels: $OUT" >&2; exit 1; }

echo "== repository workflows are clean with the default directory and real config"
node "$TOOL" --offline | grep -q "runner label scan clean"

echo "== malformed config refuses with exit 2"
set +e
CODE=0
node "$TOOL" --offline --dir "$TMP/repo" --config "$TMP/missing.json" >/dev/null 2>&1 || CODE=$?
set -e
[ "$CODE" -eq 2 ] || { echo "FAIL: expected exit 2 for broken config, got $CODE" >&2; exit 1; }

echo "== live path fixture uses its scoped inventory token and all runner pages"
# Native Windows Node resolves gh.exe instead of extensionless PATH shims.
cat > "$TMP/mock-gh.cjs" <<'JS'
const assert = require('node:assert/strict')
const childProcess = require('node:child_process')
const { syncBuiltinESMExports } = require('node:module')

childProcess.execFileSync = (command, args, { env }) => {
  assert.equal(command, 'gh')
  const prefix = 'repos/popcre/ai-devops'
  const empty = 'repos/u2giants/empty-fixture'
  switch (args.at(-1)) {
    case `${empty}/contents/.github/workflows`:
    case `${empty}/contents`:
      assert.equal(env.GH_TOKEN, 'contents-fixture')
      throw Object.assign(new Error('gh failed'), { stderr: 'gh: Not Found (HTTP 404)' })
    case `${empty}/branches?per_page=1`:
      assert.equal(env.GH_TOKEN, 'contents-fixture')
      switch (env.BRANCH_FIXTURE ?? 'empty') {
        case 'empty':
          return '[]'
        case 'has-branch':
          return '[{"name":"main"}]'
        case 'denied':
          throw Object.assign(new Error('gh failed'), { stderr: 'gh: Not Found (HTTP 404)' })
      }
      break
    case `${prefix}/contents/.github/workflows`:
      assert.equal(env.GH_TOKEN, 'contents-fixture')
      return JSON.stringify([{ type: 'file', name: 'live.yml' }])
    case `${prefix}/contents/.github/workflows/live.yml`:
      assert.equal(env.GH_TOKEN, 'contents-fixture')
      return JSON.stringify({
        encoding: 'base64',
        content: Buffer.from('    runs-on: custom-fixture\n').toString('base64'),
      })
    case `${prefix}/actions/runners?per_page=100`:
      assert.equal(env.GH_TOKEN, 'inventory-fixture')
      assert.deepEqual(args.slice(0, -1), ['api', '--paginate', '--slurp'])
      switch (env.INVENTORY_FIXTURE ?? 'live') {
        case 'live':
          return JSON.stringify([{ runners: [] }, { runners: [{ labels: [{ name: 'CUSTOM-fixture' }] }] }])
        case 'empty':
          return JSON.stringify([{ runners: [] }])
        case 'denied':
          throw Object.assign(new Error('gh failed'), { stderr: 'gh: Resource not accessible (HTTP 403)' })
      }
      break
  }
  throw new Error('unexpected gh request')
}
syncBuiltinESMExports()
JS
scan_fixture() {
  GH_TOKEN=contents-fixture RUNNER_POOL_READ_TOKEN=inventory-fixture \
    node --require "$TMP/mock-gh.cjs" "$TOOL" --repos "${1:-popcre/ai-devops}"
}
scan_fixture | grep -q "runner label scan clean"
CODE=0
OUT="$(INVENTORY_FIXTURE=empty scan_fixture)" || CODE=$?
[ "$CODE" -eq 1 ]
grep -qx 'DEAD-LABEL popcre/ai-devops/live.yml: custom-fixture' <<< "$OUT"
CODE=0
OUT="$(INVENTORY_FIXTURE=denied scan_fixture)" || CODE=$?
[ "$CODE" -eq 2 ]
grep -q 'UNVERIFIED popcre/ai-devops: runner inventory unavailable' <<< "$OUT"
if grep -q '^DEAD-LABEL ' <<< "$OUT"; then
  echo "FAIL: unverified label reported dead: $OUT" >&2; exit 1
fi

echo "== only a successful empty branch list proves a repository has no contents"
repos="popcre/ai-devops,u2giants/empty-fixture"
scan_fixture "$repos" | grep -q "runner label scan clean"
CODE=0
OUT="$(BRANCH_FIXTURE=has-branch scan_fixture "$repos")" || CODE=$?
[ "$CODE" -eq 2 ]
grep -q 'UNVERIFIED u2giants/empty-fixture: workflow listing unavailable' <<< "$OUT"
CODE=0
OUT="$(BRANCH_FIXTURE=denied scan_fixture "$repos")" || CODE=$?
[ "$CODE" -eq 2 ]
grep -q 'UNVERIFIED u2giants/empty-fixture: workflow listing unavailable' <<< "$OUT"

echo "PASS test-check-runner-labels"
