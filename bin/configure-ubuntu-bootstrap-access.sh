#!/usr/bin/env bash
# Configure the local prerequisites for the first AI SSH connection on a fresh
# Ubuntu machine: OpenSSH server, the protected bootstrap key, and the firewall.
# Ubuntu counterpart of bin/configure-windows-bootstrap-access.ps1.
set -euo pipefail

_ai_self="${BASH_SOURCE[0]}"
while [ -L "$_ai_self" ]; do
  _ai_target="$(readlink "$_ai_self")"
  case "$_ai_target" in /*) _ai_self="$_ai_target" ;; *) _ai_self="$(dirname "$_ai_self")/$_ai_target" ;; esac
done
REPO_ROOT="$(cd "$(dirname "$_ai_self")/.." && pwd)"

die(){ printf 'configure-ubuntu-bootstrap-access: error: %s\n' "$*" >&2; exit 1; }
usage(){
  cat <<'EOF'
usage: configure-ubuntu-bootstrap-access.sh [--test-only] [--public-key-file PATH]

Run as root via sudo on the machine being configured:

  sudo ./bin/configure-ubuntu-bootstrap-access.sh

Installs and starts the OpenSSH server, authorizes the protected bootstrap
public key for the sudo login user, and opens the firewall for SSH: Tailscale
only when the tailscale0 interface exists, otherwise port 22. --public-key-file
reads the key from a file instead of ai-private-config. --test-only reports
each check without changing the machine. Exit 0 when every check passes,
2 when any check fails, 1 on usage or environment errors.
EOF
}

TEST_ONLY=0
PUBLIC_KEY_FILE=''
while [ $# -gt 0 ]; do
  case "$1" in
    --test-only) TEST_ONLY=1; shift ;;
    --public-key-file)
      [ $# -ge 2 ] || die '--public-key-file needs a path.'
      PUBLIC_KEY_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

RESULTS=()
result(){ RESULTS+=("$1|$2|$3"); }

[ "$(id -u)" -eq 0 ] || die 'run with sudo as the login user (for example: sudo ./bin/configure-ubuntu-bootstrap-access.sh)'
TARGET_USER="${SUDO_USER:-}"
[ -n "$TARGET_USER" ] || die 'SUDO_USER is empty; run through sudo as the login user, not as root directly.'
passwd_line="$(getent passwd "$TARGET_USER" || true)"
TARGET_HOME="$(printf '%s' "$passwd_line" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME" ] || die "cannot resolve the home directory for $TARGET_USER"

resolve_public_key(){
  if [ -n "$PUBLIC_KEY_FILE" ]; then
    [ -f "$PUBLIC_KEY_FILE" ] || die "public key file not found: $PUBLIC_KEY_FILE"
    head -n 1 "$PUBLIC_KEY_FILE"
    return
  fi
  local resolver="$REPO_ROOT/bin/ai-private-config" key=''
  [ -x "$resolver" ] || die "ai-private-config is missing at $resolver"
  key="$("$resolver" path bootstrap_authorized_key 2>/dev/null || true)"
  if [ -z "$key" ]; then
    printf 'Protected configuration is not installed yet; running ai-private-config sync.\n' >&2
    "$resolver" sync >&2 || die 'ai-private-config sync failed; complete the GitHub CLI login first and retry.'
    key="$("$resolver" path bootstrap_authorized_key 2>/dev/null || true)"
  fi
  [ -n "$key" ] || die 'could not resolve bootstrap_authorized_key from the protected configuration.'
  printf '%s\n' "$key"
}

check_package(){
  if ! dpkg -s openssh-server >/dev/null 2>&1; then
    if [ "$TEST_ONLY" -eq 0 ]; then
      apt-get update -qq
      apt-get install -y -qq openssh-server
    fi
  fi
  if dpkg -s openssh-server >/dev/null 2>&1; then
    result 'OpenSSH package' OK 'installed'
  else
    result 'OpenSSH package' MISSING 'openssh-server is not installed'
  fi
}

check_service(){
  if ! systemctl is-active --quiet ssh && [ "$TEST_ONLY" -eq 0 ]; then
    systemctl enable --now ssh
  fi
  if systemctl is-active --quiet ssh; then
    result 'sshd service' OK 'active'
  else
    result 'sshd service' MISSING 'ssh service is not active'
  fi
}

check_key(){
  local public_key="$1" authorized_keys="$TARGET_HOME/.ssh/authorized_keys"
  if ! { [ -f "$authorized_keys" ] && grep -qxF "$public_key" "$authorized_keys"; } && [ "$TEST_ONLY" -eq 0 ]; then
    install -d -m 700 -o "$TARGET_USER" -g "$(id -g "$TARGET_USER")" "$TARGET_HOME/.ssh"
    touch "$authorized_keys"
    chown "$TARGET_USER:$(id -g "$TARGET_USER")" "$authorized_keys"
    chmod 600 "$authorized_keys"
    printf '%s\n' "$public_key" >> "$authorized_keys"
  fi
  if [ -f "$authorized_keys" ] && grep -qxF "$public_key" "$authorized_keys"; then
    result 'SSH public key' OK "$authorized_keys"
  else
    result 'SSH public key' MISSING "$authorized_keys does not contain the bootstrap key"
  fi
}

check_firewall(){
  if ! command -v ufw >/dev/null 2>&1 || ! ufw status 2>/dev/null | grep -q '^Status: active'; then
    result 'Firewall' OK 'ufw not active; SSH is not blocked by ufw'
    return
  fi
  local want
  if ip link show tailscale0 >/dev/null 2>&1; then
    want='ufw allows 22/tcp on tailscale0'
    if ! ufw status | grep -q '22/tcp on tailscale0' && [ "$TEST_ONLY" -eq 0 ]; then
      ufw allow in on tailscale0 to any port 22 proto tcp >/dev/null
    fi
    if ufw status | grep -q '22/tcp on tailscale0'; then
      result 'Firewall' OK "$want"
    else
      result 'Firewall' MISSING 'ufw is active but does not allow 22/tcp on tailscale0'
    fi
  else
    if ! ufw status | grep -Eq '^22/tcp[[:space:]]+ALLOW' && [ "$TEST_ONLY" -eq 0 ]; then
      ufw allow 22/tcp >/dev/null
    fi
    if ufw status | grep -Eq '^22/tcp[[:space:]]+ALLOW'; then
      result 'Firewall' OK 'ufw allows 22/tcp'
    else
      result 'Firewall' MISSING 'ufw is active but does not allow 22/tcp'
    fi
  fi
}

PUBLIC_KEY="$(resolve_public_key)"
check_package
check_service
check_key "$PUBLIC_KEY"
check_firewall

printf '%-18s %-8s %s\n' 'CHECK' 'STATUS' 'DETAIL'
printf '%-18s %-8s %s\n' '------------------' '--------' '----------------------------------------'
failed=0
for row in "${RESULTS[@]}"; do
  IFS='|' read -r name status detail <<<"$row"
  printf '%-18s %-8s %s\n' "$name" "$status" "$detail"
  [ "$status" = OK ] || failed=1
done
if [ "$failed" -ne 0 ]; then
  [ "$TEST_ONLY" -eq 1 ] || printf 'Applied changes where possible; failing checks remain above.\n' >&2
  exit 2
fi
exit 0
