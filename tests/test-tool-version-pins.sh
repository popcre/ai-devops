#!/usr/bin/env bash
# Recovery-critical tools and models must resolve to reviewed, reproducible versions.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/config/tool-versions.json"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

if jq -e '.schema_version == 1 and (.reviewed_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))' "$CATALOG" >/dev/null; then
  ok "version catalog has a dated schema"
else
  bad "version catalog is missing or malformed"
fi

while IFS=$'\t' read -r package version; do
  version="${version%$'\r'}"
  if grep -Fq "id: $package, source:" "$ROOT/.config/configuration.winget" &&
     grep -F "id: $package, source:" "$ROOT/.config/configuration.winget" | grep -Fq "version: $version"; then
    ok "WinGet pins $package $version"
  else
    bad "WinGet does not match catalog pin $package $version"
  fi
done < <(jq -r '.winget | to_entries[] | [.key,.value] | @tsv' "$CATALOG")

declare -A npm_files=(
  [vercel]="bin/reconcile-windows-package-exceptions.ps1 bin/setup_dev_computer_internal.ps1"
  [trigger.dev]="bin/reconcile-windows-package-exceptions.ps1 bin/setup_dev_computer_internal.ps1 bin/setup-secrets.sh"
  [@railway/cli]="bin/reconcile-windows-package-exceptions.ps1 bin/setup-machine.ps1"
  [@supabase/mcp-server-supabase]="bin/setup-secrets.sh"
  [@playwright/mcp]="bin/setup-secrets.sh"
  [chrome-devtools-mcp]="bin/configure-claude-desktop-chrome-devtools.ps1 bin/configure-codex-chrome-devtools.ps1"
)
while IFS=$'\t' read -r package version; do
  version="${version%$'\r'}"
  if [[ -z ${npm_files[$package]+x} ]]; then continue; fi
  missing=""
  for file in ${npm_files[$package]}; do
    grep -Fq "$package@$version" "$ROOT/$file" || missing="$missing $file"
  done
  if [ -z "$missing" ]; then ok "npm pin $package@$version is consistent"
  else bad "npm pin $package@$version is missing from:$missing"; fi
done < <(jq -r '.npm | to_entries[] | [.key,.value] | @tsv' "$CATALOG")

for package in trigger.dev @supabase/mcp-server-supabase @playwright/mcp chrome-devtools-mcp @u2giants/1password-mcp ag-mcp mcp-remote; do
  expected="$(jq -r --arg package "$package" '.npm[$package]' "$CATALOG")"
  actual="$(jq -r --arg package "$package" '.dependencies[$package]' "$ROOT/config/mcp-runtime/package.json")"
  if [ "$actual" = "$expected" ]; then ok "MCP runtime pins $package@$expected"
  else bad "MCP runtime pin for $package is $actual, expected $expected"; fi
done

if ! grep -R --exclude-dir=node_modules -n -E '(vercel|trigger\.dev|@railway/cli|@supabase/mcp-server-supabase|@playwright/mcp|chrome-devtools-mcp)@latest' \
  "$ROOT/bin" "$ROOT/config" "$ROOT/.config" >/dev/null; then
  ok "recovery paths contain no mutable npm latest specifiers"
else
  bad "a recovery path still contains a mutable npm latest specifier"
fi

codex_model="$(jq -r '.models.codex' "$CATALOG")"
codex_reasoning="$(jq -r '.models.codex_reasoning' "$CATALOG")"
claude_model="$(jq -r '.models.claude_review' "$CATALOG")"
if grep -Fq "model = \"$codex_model\"" "$ROOT/config/codex-portable.toml" &&
   grep -Fq "model_reasoning_effort = \"$codex_reasoning\"" "$ROOT/config/codex-portable.toml"; then
  ok "portable Codex model matches the catalog"
else
  bad "portable Codex model does not match the catalog"
fi
if grep -Fq -- "--model $claude_model" "$ROOT/config/models.env.example" &&
   grep -Fq -- "-m $codex_model" "$ROOT/config/models.env.example"; then
  ok "pipeline model commands match the catalog"
else
  bad "pipeline model commands do not match the catalog"
fi

# Jev decision policy (advisory plan §9.2 / review-waste plan Phase 2)
JEV_CFG="$ROOT/config/jev-decisions.json"
jev_catalog_pin="$(jq -r '.models.jev // empty' "$CATALOG")"
if [ -n "$jev_catalog_pin" ] && [ "$jev_catalog_pin" != null ]; then
  ok "catalog pins a Jev model"
else
  bad "catalog models.jev is missing"
fi
if [ -f "$JEV_CFG" ] && jq -e '.schema_version == 1 and (.model_pin|type=="string") and (.endpoint|type=="string")' "$JEV_CFG" >/dev/null; then
  ok "jev-decisions.json has a dated schema and model pin"
else
  bad "jev-decisions.json missing or malformed"
fi
jev_cfg_pin="$(jq -r '.model_pin // empty' "$JEV_CFG" 2>/dev/null)"
if [ -n "$jev_cfg_pin" ] && [ "$jev_cfg_pin" = "$jev_catalog_pin" ]; then
  ok "jev-decisions model pin matches tool-versions"
else
  bad "jev-decisions model pin $jev_cfg_pin != catalog $jev_catalog_pin"
fi
if jq -e '.decisions.value_level.type == "score"
    and (.decisions.value_level.level_labels|length == 5)
    and (.decisions.value_level.level_labels == ["negative","none","low","medium","highest"])
    and (.decisions.chunk_filter.type == "choice")
    and (.decisions.chunk_filter.allowed_labels|length >= 2)' "$JEV_CFG" >/dev/null 2>&1; then
  ok "jev-decisions label enums match the locked five-level Score scale"
else
  bad "jev-decisions label enums do not match the locked scale"
fi
if grep -R --exclude-dir=node_modules -n -F '"jev-latest"' "$ROOT/bin/ai-jev-review-waste" "$ROOT/tools/lib/jev-client.sh" >/dev/null 2>&1; then
  bad "calibration path still references jev-latest"
else
  ok "shared client and review-waste caller do not use jev-latest"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
