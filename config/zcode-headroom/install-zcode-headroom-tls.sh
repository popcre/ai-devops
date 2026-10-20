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

DIR=/etc/ai-zcode-headroom
TLS="$DIR/tls"
UNIT=/etc/systemd/system/zcode-headroom-tls.service
SCRIPT_DST=/home/ai/zcode-headroom-tls/zcode_headroom_tls.py

mkdir -p "$TLS" /home/ai/zcode-headroom-tls
chmod 755 /home/ai/zcode-headroom-tls
chmod 700 "$TLS"

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
  chmod 600 "$TLS"/*.key
  chmod 644 "$TLS/ca.crt" "$TLS/server.crt"
fi

cp -f /tmp/zcode_headroom_tls.py "$SCRIPT_DST"
chmod 755 "$SCRIPT_DST"
chown ai:ai "$SCRIPT_DST"

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
ExecStart=/usr/bin/python3 $SCRIPT_DST
Restart=on-failure
RestartSec=5
StandardOutput=append:/home/ai/.headroom-zcode-home/.headroom/logs/tls-front.log
StandardError=append:/home/ai/.headroom-zcode-home/.headroom/logs/tls-front.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now zcode-headroom-tls.service
sleep 1
systemctl is-active zcode-headroom-tls.service
ss -lntp | grep 8443 || true
echo "CA_CERT_PATH=$TLS/ca.crt"
