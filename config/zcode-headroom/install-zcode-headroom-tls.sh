#!/bin/bash
# One-shot on hetz: TLS certs + systemd unit for the Z-code Headroom HTTPS front.
#
# Usage:
#   sudo HEADROOM_TAILNET_IP=$(tailscale ip -4) \
#     bash install-zcode-headroom-tls.sh
#
# Concrete tailnet addresses stay out of the public toolkit; pass them in.
set -euo pipefail

: "${HEADROOM_TAILNET_IP:?set HEADROOM_TAILNET_IP to the VPS tailnet address}"

# ZCODE_HEADROOM_TEST_ROOT is only for the offline test; it must be empty on hosts.
R="${ZCODE_HEADROOM_TEST_ROOT:-}"
DIR=$R/etc/ai-zcode-headroom
TLS="$DIR/tls"
UNIT=$R/etc/systemd/system/zcode-headroom-tls.service
SCRIPT_DST=$R/home/ai/zcode-headroom-tls/zcode_headroom_tls.py
# The proxy ships next to this installer in the repo; never copy root-run
# service code from a world-writable directory.
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/zcode_headroom_tls.py"
LOG_DIR=$R/home/ai/.headroom-zcode-home/.headroom/logs
SERVICE_USER="${ZCODE_HEADROOM_SERVICE_USER:-ai}"

[[ -f "$SCRIPT_SRC" && ! -L "$SCRIPT_SRC" ]] || { echo "missing proxy source: $SCRIPT_SRC" >&2; exit 1; }

mkdir -p "$TLS" "$R/home/ai/zcode-headroom-tls" "$LOG_DIR" "$(dirname "$UNIT")"
chmod 755 "$R/home/ai/zcode-headroom-tls"
chown "$SERVICE_USER:$SERVICE_USER" "$R/home/ai/zcode-headroom-tls"
chown -R "$SERVICE_USER:$SERVICE_USER" "$R/home/ai/.headroom-zcode-home/.headroom"

if [[ ! -f "$TLS/server.crt" ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TLS/ca.key" -out "$TLS/ca.crt" -days 3650 \
    -subj "/CN=ai-devops-zcode-headroom-ca" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
  openssl req -newkey rsa:2048 -nodes \
    -keyout "$TLS/server.key" -out "$TLS/server.csr" \
    -subj "/CN=hetz.coho-banded.ts.net"
  cat > "$TLS/server.ext" <<EOF
subjectAltName=DNS:hetz.coho-banded.ts.net,IP:${HEADROOM_TAILNET_IP}
EOF
  openssl x509 -req -in "$TLS/server.csr" -CA "$TLS/ca.crt" -CAkey "$TLS/ca.key" \
    -CAcreateserial -out "$TLS/server.crt" -days 825 -extfile "$TLS/server.ext"
fi

# The front loads server-chain.crt (leaf + CA); build it whenever missing,
# including on a host that already has server.crt from an older install.
if [[ ! -f "$TLS/server-chain.crt" ]]; then
  cat "$TLS/server.crt" "$TLS/ca.crt" > "$TLS/server-chain.crt"
fi

# The unit runs as the service user, so it must be able to read the key.
chown -R "$SERVICE_USER:$SERVICE_USER" "$TLS"
chmod 700 "$TLS"
chmod 600 "$TLS"/*.key
chmod 644 "$TLS/ca.crt" "$TLS/server.crt" "$TLS/server-chain.crt"

cp -f "$SCRIPT_SRC" "$SCRIPT_DST"
chmod 755 "$SCRIPT_DST"
chown "$SERVICE_USER:$SERVICE_USER" "$SCRIPT_DST"

cat > "$UNIT" <<EOF
[Unit]
Description=TLS front for Z-code Headroom lane (tailnet)
After=network-online.target tailscaled.service headroom-zcode.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=ai
Group=ai
Environment=ZCODE_HEADROOM_TLS_HOST=${HEADROOM_TAILNET_IP}
Environment=ZCODE_HEADROOM_HTTP_HOST=${HEADROOM_TAILNET_IP}
ExecStart=/usr/bin/python3 ${SCRIPT_DST#"$R"}
Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_DIR#"$R"}/tls-front.log
StandardError=append:${LOG_DIR#"$R"}/tls-front.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now zcode-headroom-tls.service
sleep 1
systemctl is-active zcode-headroom-tls.service
ss -lntp | grep 8443 || true
echo "CA_CERT_PATH=$TLS/ca.crt"
