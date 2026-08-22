#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CFG="$TMP/etc"; mkdir -p "$CFG"
cp "$ROOT/config/models.env.example" "$CFG/models.env"
cp "$ROOT/config/server.env.example" "$CFG/server.env"
sed -i '/^TESTER_CMD=/d' "$CFG/models.env"
sed -i 's#^OWNER_NAME=.*#OWNER_NAME="Custom Owner"#' "$CFG/server.env"

bash "$ROOT/bin/ai-config-migrate" --repo-root "$ROOT" --config-dir "$CFG" --dry-run >/dev/null
! grep -q '^TESTER_CMD=' "$CFG/models.env" || { echo 'FAIL: dry run changed config'; exit 1; }
bash "$ROOT/bin/ai-config-migrate" --repo-root "$ROOT" --config-dir "$CFG" >/dev/null
grep -q '^TESTER_CMD=' "$CFG/models.env" || { echo 'FAIL: missing default not added'; exit 1; }
grep -q '^OWNER_NAME="Custom Owner"' "$CFG/server.env" || { echo 'FAIL: user value overwritten'; exit 1; }
jq -e '.schema == 1 and .source_sha' "$CFG/config-state.json" >/dev/null || { echo 'FAIL: state missing'; exit 1; }
find "$CFG/backups" -type f -name models.env | grep -q . || { echo 'FAIL: backup missing'; exit 1; }

cp "$CFG/models.env" "$TMP/before"
sed -i '/^TESTER_CMD=/d' "$CFG/models.env"
if AI_CONFIG_TEST_FAIL_BACKUP=1 bash "$ROOT/bin/ai-config-migrate" --repo-root "$ROOT" --config-dir "$CFG" >/dev/null 2>&1; then
  echo 'FAIL: backup failure returned success'; exit 1
fi
! grep -q '^TESTER_CMD=' "$CFG/models.env" || { echo 'FAIL: backup failure changed live config'; exit 1; }

printf '\nOWNER_NAME="Duplicate"\n' >> "$CFG/server.env"
if bash "$ROOT/bin/ai-config-migrate" --repo-root "$ROOT" --config-dir "$CFG" >/dev/null 2>&1; then
  echo 'FAIL: duplicate config key returned success'; exit 1
fi
echo 'PASS: config migration previews, preserves values, backs up, merges defaults, validates, and records schema'
