# shellcheck shell=bash
# Final gate proof uses installed bytes; callers cannot supply a pass flag.
mcp_install_windows_payload_ok() {
  local authority="$1" cfg before after temp hash script_native output
  cfg="$(mcp_install_cfg)" || return 1
  cmp -s "$ROOT/bin/mcp-secret-launch.ps1" "$cfg/mcp-secret-launch.ps1" || return 1
  cmp -s "$ROOT/bin/mcp-session-guard.mjs" "$cfg/mcp-session-guard.mjs" || return 1
  hash="$(sha256sum "$ROOT/bin/mcp-secret-launch.ps1" | cut -d' ' -f1)" || return 1
  temp="$(mktemp -d "$(dirname "$authority")/.windows-proof.XXXXXXXX")" || return 1
  chmod 700 "$temp" || return 1
  script_native="$(cygpath -w "$ROOT/bin/mcp-launcher-install-windows.ps1")" || return 1
  printf '%s\n' 'param([string]$Helper,[string]$Hash)' '. $Helper' '[Console]::Write((Get-McpNarrowRemoteLauncher $Hash))' > "$temp/render.ps1"
  if ! pwsh -NoProfile -File "$(cygpath -w "$temp/render.ps1")" "$script_native" "$hash" > "$temp/remote.cmd"; then
    rm -rf -- "$temp"; return 1
  fi
  if ! diff -q <(tr -d '\r' < "$temp/remote.cmd") <(tr -d '\r' < "$cfg/mcp-remote-launch.cmd") >/dev/null; then
    rm -rf -- "$temp"; return 1
  fi
  before="$(jq -r .before_inventory "$authority" | awk -F '\t' '$1 ~ /\/mcp-runtime$/ {print $2}')"
  after="$(mcp_install_hash_path "$cfg/mcp-runtime")" || { rm -rf -- "$temp"; return 1; }
  if [ "$before" = missing ]; then
    mkdir "$temp/runtime" || { rm -rf -- "$temp"; return 1; }
    cp "$ROOT/config/mcp-remote-runtime/package.json" "$ROOT/config/mcp-remote-runtime/package-lock.json" "$temp/runtime/" || { rm -rf -- "$temp"; return 1; }
    if ! npm.cmd ci --prefix "$(cygpath -w "$temp/runtime")" --cache "$(cygpath -w "$temp/cache")" --ignore-scripts --no-audit --no-fund --silent > "$temp/npm.log" 2>&1; then
      rm -rf -- "$temp"; return 1
    fi
    [ "$after" = "$(mcp_install_hash_path "$temp/runtime")" ] || { rm -rf -- "$temp"; return 1; }
  else
    [[ "$before" =~ ^[0-9a-f]{64}$ ]] && [ "$before" = "$after" ] || { rm -rf -- "$temp"; return 1; }
  fi
  # Disposable auth/argv suite never consults production vault values.
  if ! pwsh -NoProfile -File "$(cygpath -w "$ROOT/tests/test-mcp-env-launch.ps1")" > "$temp/probe.log" 2>&1; then
    rm -rf -- "$temp"; return 1
  fi
  if ! pwsh -NoProfile -File "$(cygpath -w "$ROOT/tests/test-mcp-launcher-synthetic-windows.ps1")" \
    -InstalledRoot "$(cygpath -w "$cfg")" -RuntimeRoot "$(cygpath -w "$cfg/mcp-runtime")" > "$temp/http-probe.log" 2>&1; then
    rm -rf -- "$temp"; return 1
  fi
  rm -rf -- "$temp"
}
