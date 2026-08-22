#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/etc" "$TMP/bin"
cp "$ROOT/config/models.env.example" "$TMP/etc/models.env"
cp "$ROOT/config/server.env.example" "$TMP/etc/server.env"
jq -n '{schema:1}' > "$TMP/etc/config-state.json"
ln -s "$ROOT/bin/ai-devops" "$TMP/bin/ai-devops"
fixed_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
manifest="$TMP/staged/install-manifest.tsv"
bash "$ROOT/bin/ai-install-manifest" --repo-root "$ROOT" --config-dir "$TMP/etc" --bin-target "$TMP/bin" \
  --home "$TMP/home" --source-sha "$fixed_sha" --output "$manifest" >/dev/null
[ ! -e "$TMP/etc/install-manifest.tsv" ] || { echo 'FAIL: staged output also published live'; exit 1; }
grep -q $'^meta\tsource_sha\t'"$fixed_sha"$'\t' "$manifest" || { echo 'FAIL: exact source SHA missing'; exit 1; }
grep -q $'^meta\tconfig_schema\t1\t' "$manifest" || { echo 'FAIL: schema missing'; exit 1; }
if [ -L "$TMP/bin/ai-devops" ]; then
  grep -q $'^symlink\t.*/ai-devops\t.*/bin/ai-devops\t[0-9a-f]\{64\}$' "$manifest" || { echo 'FAIL: symlink evidence missing'; exit 1; }
fi
grep -q $'^config\t.*/models.env\tmanaged\t[0-9a-f]\{64\}$' "$manifest" || { echo 'FAIL: config evidence missing'; exit 1; }
if bash "$ROOT/bin/ai-install-manifest" --repo-root "$ROOT" --config-dir "$TMP/etc" --source-sha unsafe --output "$TMP/unsafe" >/dev/null 2>&1; then
  echo 'FAIL: invalid explicit source SHA returned success'; exit 1
fi
echo 'PASS: install manifest records source, schema, owned symlinks, config, and hashes'
