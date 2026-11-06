#!/usr/bin/env bash
# Step 3.5 (plan_ci-process-repair.md, #2367): the required-list compare must
# flag a reversed or extended list and pass the ruling's exact list. Fixtures
# only -- no network, no ruleset writes.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TOOL="$ROOT/tools/ci/check-required-lists.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/expected.json" <<'JSON'
{
  "schema_version": 1,
  "repos": {
    "scratch/test": {
      "ruleset_name": "main merge queue",
      "required_contexts": ["verification-closure"]
    }
  }
}
JSON

# A live shape as the single-ruleset GET returns it: the ruling's list.
cat > "$TMP/matching-ruleset.json" <<'JSON'
[{ "id": 1, "name": "main merge queue", "rules": [
  { "type": "merge_queue", "parameters": {} },
  { "type": "required_status_checks", "parameters": { "required_status_checks": [
    { "context": "verification-closure", "integration_id": 15368 }
  ] } }
] }]
JSON

# The 2026-10-30 reversal shape: the required list replaced wholesale.
cat > "$TMP/reversed-ruleset.json" <<'JSON'
[{ "id": 1, "name": "main merge queue", "rules": [
  { "type": "merge_queue", "parameters": {} },
  { "type": "required_status_checks", "parameters": { "required_status_checks": [
    { "context": "someone-added-a-required-review", "integration_id": 15368 }
  ] } }
] }]
JSON

run_compare() {
  local ruleset="$1"
  node --input-type=module - "$TOOL" "$TMP/expected.json" "$ruleset" <<'NODE'
import { pathToFileURL } from 'node:url'
import { readFileSync } from 'node:fs'
const { compareRepo, loadExpected } = await import(pathToFileURL(process.argv[2]).href)
const expected = loadExpected(process.argv[3])
const rulesets = JSON.parse(readFileSync(process.argv[4], 'utf8'))
const report = compareRepo('scratch/test', expected['scratch/test'], rulesets)
console.log(report.differences.join('\n') || 'clean')
process.exitCode = report.differences.length ? 1 : 0
NODE
}

echo "== the ruling's exact list passes"
OUT="$(run_compare "$TMP/matching-ruleset.json")" && [ "$OUT" = "clean" ]

echo "== a reversed list names the missing check"
set +e
OUT="$(run_compare "$TMP/reversed-ruleset.json")"; CODE=$?
set -e
[ "$CODE" -eq 1 ] || { echo "FAIL: expected drift exit 1, got $CODE ($OUT)" >&2; exit 1; }
echo "$OUT" | grep -q "missing required check: verification-closure" || { echo "FAIL: missing check not named: $OUT" >&2; exit 1; }
echo "$OUT" | grep -q "required check beyond the ruling's list: someone-added-a-required-review" || { echo "FAIL: extra check not named: $OUT" >&2; exit 1; }

echo "== a missing ruleset is named, not silent"
set +e
OUT="$(node --input-type=module - "$TOOL" "$TMP/expected.json" <<'NODE'
import { pathToFileURL } from 'node:url'
const { compareRepo, loadExpected } = await import(pathToFileURL(process.argv[2]).href)
const expected = loadExpected(process.argv[3])
const report = compareRepo('scratch/test', expected['scratch/test'], [])
console.log(report.differences.join('\n'))
process.exitCode = report.differences.length ? 1 : 0
NODE
)"; CODE=$?
set -e
[ "$CODE" -eq 1 ] || { echo "FAIL: expected drift exit 1, got $CODE" >&2; exit 1; }
echo "$OUT" | grep -q 'ruleset "main merge queue" not found' || { echo "FAIL: missing ruleset not named: $OUT" >&2; exit 1; }

echo "PASS test-check-required-lists"
