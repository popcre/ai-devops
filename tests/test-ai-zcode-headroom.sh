#!/usr/bin/env bash
# Offline checks for bin/ai-zcode-headroom.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bin/ai-zcode-headroom"
TMP="${TMPDIR:-/tmp}/ai-zcode-headroom-test-$$"
mkdir -p "$TMP/zcode/v2"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name"
    exit 1
  fi
}

check 'tool is executable' test -x "$TOOL"
check 'cmd launcher exists' test -f "$ROOT/bin/ai-zcode-headroom.cmd"
check 'direct template exists' test -f "$ROOT/config/zcode-headroom/provider_config.direct.json"
check 'headroom template exists' test -f "$ROOT/config/zcode-headroom/provider_config.headroom.json"
check 'TLS front template exists' test -f "$ROOT/config/zcode-headroom/zcode_headroom_tls.py"
check 'VPS installer template exists' test -f "$ROOT/config/zcode-headroom/install-zcode-headroom-tls.sh"
check 'registered in machine-tools.tsv' grep -q '^ai-zcode-headroom	' "$ROOT/config/machine-tools.tsv"
check 'headroom template uses https' grep -q '"baseUrl": "https://' "$ROOT/config/zcode-headroom/provider_config.headroom.json"
check 'direct template clears providerRules' grep -q '"providerRules": \[\]' "$ROOT/config/zcode-headroom/provider_config.direct.json"

# off must write direct config without network
ZCODE_HOME="$TMP/zcode" AI_ZCODE_HEADROOM_BASE_URL='https://127.0.0.1:8443/v1' \
  "$TOOL" off
check 'off writes provider config' test -f "$TMP/zcode/v2/provider_config.json"
check 'off leaves empty providerRules' grep -q '"providerRules": \[\]' "$TMP/zcode/v2/provider_config.json"

# on must refuse http:// base URLs (Z.ai signing)
if ZCODE_HOME="$TMP/zcode" AI_ZCODE_HEADROOM_BASE_URL='http://127.0.0.1:8443/v1' \
  "$TOOL" on >/dev/null 2>&1; then
  printf 'not ok - on accepted http baseUrl\n'
  exit 1
fi
printf 'ok - on refuses http baseUrl\n'

# on must refuse when the lane is not healthy (no CA / not listening)
if ZCODE_HOME="$TMP/zcode" AI_ZCODE_HEADROOM_BASE_URL='https://127.0.0.1:8443/v1' \
  AI_ZCODE_HEADROOM_CA_BUNDLE="$TMP/missing-ca.pem" \
  "$TOOL" on >/dev/null 2>&1; then
  printf 'not ok - on accepted missing CA\n'
  exit 1
fi
printf 'ok - on refuses missing CA\n'

printf 'ok - all ai-zcode-headroom checks\n'
