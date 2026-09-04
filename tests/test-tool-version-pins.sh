#!/usr/bin/env bash
# Recovery-critical tools and models must resolve to reviewed, reproducible versions.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/config/tool-versions.json"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

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
  [@ast-grep/cli]="bin/reconcile-windows-package-exceptions.ps1"
  [vercel]="bin/reconcile-windows-package-exceptions.ps1 bin/setup_dev_computer_internal.ps1"
  [trigger.dev]="bin/reconcile-windows-package-exceptions.ps1 bin/setup_dev_computer_internal.ps1 bin/setup-machine.ps1 bin/setup-secrets.sh"
  [@railway/cli]="bin/reconcile-windows-package-exceptions.ps1"
  [@supabase/mcp-server-supabase]="bin/setup-machine.ps1 bin/setup-secrets.sh"
  [@playwright/mcp]="bin/setup-machine.ps1 bin/setup-secrets.sh"
  [chrome-devtools-mcp]="bin/setup-machine.ps1 bin/configure-claude-desktop-chrome-devtools.ps1 bin/configure-codex-chrome-devtools.ps1"
)
while IFS=$'\t' read -r package version; do
  version="${version%$'\r'}"
  if [ -z "${npm_files[$package]+x}" ] || [ -z "${npm_files[$package]}" ]; then
    bad "npm catalog key $package has no owner-file mapping"
    continue
  fi
  missing=""
  for file in ${npm_files[$package]}; do
    grep -Fq "$package@$version" "$ROOT/$file" || missing="$missing $file"
  done
  if [ -z "$missing" ]; then ok "npm pin $package@$version is consistent"
  else bad "npm pin $package@$version is missing from:$missing"; fi
done < <(jq -r '.npm | to_entries[] | [.key,.value] | @tsv' "$CATALOG")

if ! grep -R -n -E '(vercel|trigger\.dev|@railway/cli|@ast-grep/cli|@supabase/mcp-server-supabase|@playwright/mcp|chrome-devtools-mcp)@latest' \
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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
