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
  if "$@" >/dev/null 2>"$TMP/check.err"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name"; cat "$TMP/check.err" >&2
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

# Installer: run it offline against a scratch root with systemctl/chown stubbed
# (never touches /etc, systemd or the live lane).
INSTALLER="$ROOT/config/zcode-headroom/install-zcode-headroom-tls.sh"
check 'installer has no /tmp proxy source' bash -c "! grep -q '/tmp/zcode_headroom_tls.py' '$INSTALLER'"
check 'proxy loads server-chain.crt' grep -q 'server-chain.crt' "$ROOT/config/zcode-headroom/zcode_headroom_tls.py"
# The installer is Linux-only (hetz, systemd); Git Bash mangles openssl -subj.
if [ "$(uname -s)" = Linux ]; then
STUB="$TMP/stub"; FAKE="$TMP/root"; mkdir -p "$STUB"
for c in systemctl ss sleep; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done
printf '#!/bin/sh\necho "$@" >> "%s/chown.log"\n' "$TMP" > "$STUB/chown"; chmod +x "$STUB/chown"
run_installer() {
  PATH="$STUB:$PATH" ZCODE_HEADROOM_TEST_ROOT="$FAKE" HEADROOM_TAILNET_IP=192.0.2.10 \
    bash "$INSTALLER" >"$TMP/install.out" 2>&1 || { cat "$TMP/install.out" >&2; return 1; }
}
check 'installer runs offline' run_installer
T="$FAKE/etc/ai-zcode-headroom/tls"
check 'installer creates server-chain.crt' test -s "$T/server-chain.crt"
check 'chain is leaf then CA' bash -c "cat '$T/server.crt' '$T/ca.crt' | cmp -s - '$T/server-chain.crt'"
check 'chain verifies against CA' openssl verify -CAfile "$T/ca.crt" "$T/server.crt"
check 'chain+key load in python ssl' python3 -c "import ssl;ssl.create_default_context(ssl.Purpose.CLIENT_AUTH).load_cert_chain('$T/server-chain.crt','$T/server.key')"
check 'key is 0600' test "$(stat -c %a "$T/server.key")" = 600
check 'tls dir chowned to service user' grep -q "^-R ai:ai $T\$" "$TMP/chown.log"
check 'log dir created' test -d "$FAKE/home/ai/.headroom-zcode-home/.headroom/logs"
check 'log dir chowned to service user' grep -q "^-R ai:ai $FAKE/home/ai/.headroom-zcode-home/.headroom\$" "$TMP/chown.log"
check 'proxy copied from repo' cmp -s "$ROOT/config/zcode-headroom/zcode_headroom_tls.py" "$FAKE/home/ai/zcode-headroom-tls/zcode_headroom_tls.py"
U="$FAKE/etc/systemd/system/zcode-headroom-tls.service"
check 'unit runs as ai' grep -q '^User=ai$' "$U"
check 'unit uses real host paths' grep -q '^ExecStart=/usr/bin/python3 /home/ai/zcode-headroom-tls/zcode_headroom_tls.py$' "$U"
check 'unit log path matches created dir' grep -q '^StandardOutput=append:/home/ai/.headroom-zcode-home/.headroom/logs/tls-front.log$' "$U"
# Upgrade: an older install with server.crt but no chain gets the chain built.
rm -f "$T/server-chain.crt"
check 'rerun on older install' run_installer
check 'rerun builds missing chain' bash -c "cat '$T/server.crt' '$T/ca.crt' | cmp -s - '$T/server-chain.crt'"
else
  printf 'ok - installer behavioral checks skipped (not Linux)\n'
fi

printf 'ok - all ai-zcode-headroom checks\n'

