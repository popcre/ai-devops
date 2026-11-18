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
mkdir "$TMP/bin"
cat > "$TMP/bin/gh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
case "${*: -1}" in
  */contents/.github/workflows)
    [ "$GH_TOKEN" = contents-fixture ]
    printf '%s\n' '[{"type":"file","name":"live.yml"}]'
    ;;
  */contents/.github/workflows/live.yml)
    [ "$GH_TOKEN" = contents-fixture ]
    printf '{"encoding":"base64","content":"%s"}\n' "$(printf '    runs-on: custom-fixture\n' | base64)"
    ;;
  */actions/runners\?per_page=100)
    [ "$GH_TOKEN" = inventory-fixture ]
    [ "$*" = "api --paginate --slurp repos/popcre/ai-devops/actions/runners?per_page=100" ]
    case "${INVENTORY_FIXTURE:-live}" in
      live) printf '%s\n' '[{"runners":[]},{"runners":[{"labels":[{"name":"CUSTOM-fixture"}]}]}]' ;;
      empty) printf '%s\n' '[{"runners":[]}]' ;;
      denied) printf '%s\n' 'gh: Resource not accessible (HTTP 403)' >&2; exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
BASH
chmod +x "$TMP/bin/gh"
scan_fixture() {
  PATH="$TMP/bin:$PATH" GH_TOKEN=contents-fixture RUNNER_POOL_READ_TOKEN=inventory-fixture \
    node "$TOOL" --repos popcre/ai-devops
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

echo "PASS test-check-runner-labels"
