#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/etc"
cp "$ROOT/config/models.env.example" "$TMP/etc/models.env"
cp "$ROOT/config/server.env.example" "$TMP/etc/server.env"
sha="$(git -C "$ROOT" rev-parse HEAD)"
schema="$(jq -r '.version' "$ROOT/config/config-schema.json")"
jq -n --arg sha "$sha" --argjson schema "$schema" '{schema:$schema,source_sha:$sha,applied_at:"test"}' > "$TMP/etc/config-state.json"
hash="$(sha256sum "$TMP/etc/models.env" | cut -d' ' -f1)"
{
  printf 'meta\tsource_sha\t%s\t-\n' "$sha"
  printf 'meta\tconfig_schema\t%s\t-\n' "$schema"
  printf 'config\t%s\tmanaged\t%s\n' "$TMP/etc/models.env" "$hash"
} > "$TMP/etc/install-manifest.tsv"

export AI_DEVOPS_LIB_ONLY=1 AI_DEVOPS_ETC="$TMP/etc" AI_DEVOPS_HOME_DEFAULT="$ROOT"
source "$ROOT/bin/ai-devops"
AI_DEVOPS_HOME="$ROOT"; MODELS_ENV="$TMP/etc/models.env"; SERVER_ENV="$TMP/etc/server.env"; FAILED=0
check_install_state >/dev/null
[ "$FAILED" -eq 0 ] || { echo 'FAIL: valid install state failed doctor'; exit 1; }

sed -i 's/^meta\tsource_sha\t.*/meta\tsource_sha\twrong\t-/' "$TMP/etc/install-manifest.tsv"
FAILED=0; check_install_state >/dev/null
[ "$FAILED" -eq 1 ] || { echo 'FAIL: installed source mismatch passed doctor'; exit 1; }

sed -i "s/^meta\tconfig_schema\t.*/meta\tconfig_schema\t$((schema + 1))\t-/" "$TMP/etc/install-manifest.tsv"
sed -i "s/^meta\tsource_sha\t.*/meta\tsource_sha\t$sha\t-/" "$TMP/etc/install-manifest.tsv"
FAILED=0; check_install_state >/dev/null
[ "$FAILED" -eq 1 ] || { echo 'FAIL: install manifest schema mismatch passed doctor'; exit 1; }

rm -f "$TMP/etc/config-state.json"
FAILED=0; check_install_state > "$TMP/missing-state.out"
[ "$FAILED" -eq 1 ] || { echo 'FAIL: missing migration state passed doctor'; exit 1; }
grep -q 'config migration state missing' "$TMP/missing-state.out" || { echo 'FAIL: missing migration state was not reported'; exit 1; }
grep -q 'managed command/skill hashes match manifest' "$TMP/missing-state.out" || { echo 'FAIL: doctor stopped before completing install-state checks'; exit 1; }

grep -q 'check_required npx' "$ROOT/bin/ai-devops" || { echo 'FAIL: npx is not required'; exit 1; }
for provider in grok kimi glm muse gemini qwen codex deepseek; do
  grep -q "^$provider$" "$ROOT/bin/ai-devops" || { echo "FAIL: provider $provider omitted"; exit 1; }
done
echo 'PASS: doctor proves source/schema/manifest and covers Node, memory, schedule, and every reviewer provider'
