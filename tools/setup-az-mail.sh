#!/usr/bin/env bash
# Provision the scoped Azure CLI profile on supported development computers.
set -euo pipefail

die() { printf 'az-mail setup: %s\n' "$1" >&2; exit 1; }
info() { printf 'az-mail setup: %s\n' "$1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
private_value() { "$REPO_ROOT/bin/ai-private-config" value "$1"; }

os_name="$(uname -s)"
case "$os_name" in
  MINGW*|MSYS*|CYGWIN*) on_windows=1 ;;
  *) on_windows=0 ;;
esac

if [ "$on_windows" -eq 1 ]; then
  host="$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')"
  allowed_hosts=",$(private_value azure_cli_mail_windows_hosts | tr '[:upper:]' '[:lower:]'),"
else
  host="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  allowed_hosts=",$(private_value azure_cli_mail_linux_hosts | tr '[:upper:]' '[:lower:]'),"
fi
case "$allowed_hosts" in
  *,"$host",*) ;;
  *) info "not enabled for this development host ($host); no mailbox credential was copied."; exit 0 ;;
esac

for tool in jq openssl op az; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool is unavailable: $tool."
done
if [ "$on_windows" -eq 0 ]; then
  command -v flock >/dev/null 2>&1 || die 'required tool is unavailable: flock.'
fi

application_id="$(private_value azure_cli_mail_application_id)"
tenant_id="$(private_value azure_cli_mail_tenant_id)"
certificate_ref="$(private_value azure_cli_mail_certificate_ref)"
expected_fingerprint="$(private_value azure_cli_mail_certificate_sha256 | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
[[ "$application_id" =~ ^[[:xdigit:]-]{36}$ && "$tenant_id" =~ ^[[:xdigit:]-]{36}$ ]] || die 'private mailbox identity is invalid.'
[[ "$certificate_ref" == op://vibe_coding/* && "$expected_fingerprint" =~ ^[0-9A-F]{64}$ ]] || die 'private certificate reference is invalid.'

if [ "$on_windows" -eq 1 ]; then
  command -v cygpath >/dev/null 2>&1 || die 'Git for Windows path conversion is unavailable.'
  [ -n "${USERPROFILE:-}" ] || die 'the Windows user profile is unavailable.'
  config_root="$(cygpath -u "$USERPROFILE")/.config/ai-devops"
else
  config_root="${XDG_CONFIG_HOME:-${HOME:?HOME is unavailable}/.config}/ai-devops"
fi
config_dir="$config_root/az-mail"
azure_config="$config_dir/azure"
token_file="$config_root/op-service-account"
lock_file="$config_root/op-refresh.lock"
windows_lock_dir="$config_dir/op-refresh.lock.d"
windows_lock_owner="$windows_lock_dir/pid"
windows_lock_owned=0
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  [ -s "$token_file" ] || die 'the protected 1Password service-account token is unavailable.'
  OP_SERVICE_ACCOUNT_TOKEN="$(tr -d '\r\n' < "$token_file")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

mkdir -p -- "$config_root" "$config_dir" "$azure_config"
[ ! -L "$config_root" ] && [ ! -L "$config_dir" ] && [ ! -L "$azure_config" ] || die 'refusing a symlinked credential directory.'
chmod 700 -- "$config_root" "$config_dir" "$azure_config"
stage_cert="$(mktemp "$config_dir/.certificate.XXXXXXXX")" || die 'cannot create a protected staging file.'
stage_config="$(mktemp "$config_dir/.config.XXXXXXXX")" || { rm -f -- "$stage_cert"; die 'cannot create a protected staging file.'; }
release_windows_lock() {
  [ "$windows_lock_owned" -eq 1 ] || return 0
  if [ -f "$windows_lock_owner" ] && [ "$(cat "$windows_lock_owner" 2>/dev/null)" = "$$" ]; then
    rm -f -- "$windows_lock_owner"
    rmdir -- "$windows_lock_dir" 2>/dev/null || true
  fi
  windows_lock_owned=0
}
cleanup() {
  rm -f -- "$stage_cert" "$stage_config"
  release_windows_lock
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
chmod 600 -- "$stage_cert" "$stage_config"

if [ "$on_windows" -eq 1 ]; then
  if ! mkdir -- "$windows_lock_dir" 2>/dev/null; then
    die 'another mailbox setup holds the 1Password read lock; if its process ended unexpectedly, reconcile the stale lock before retrying.'
  fi
  windows_lock_owned=1
  printf '%s\n' "$$" > "$windows_lock_owner" || die 'cannot record the 1Password read lock owner.'
  if ! op read "$certificate_ref" > "$stage_cert" 2>/dev/null; then
    release_windows_lock
    die '1Password could not provide the protected mailbox certificate.'
  fi
  release_windows_lock
elif ! flock --close -E 87 -w 90 "$lock_file" op read "$certificate_ref" > "$stage_cert" 2>/dev/null; then
  die '1Password could not provide the protected mailbox certificate.'
fi
chmod 600 -- "$stage_cert"
openssl x509 -in "$stage_cert" -checkend 0 -noout >/dev/null 2>&1 || die 'the mailbox certificate is invalid or expired.'
openssl pkey -in "$stage_cert" -noout -check >/dev/null 2>&1 || die 'the mailbox certificate has no usable private key.'
actual_fingerprint="$(openssl x509 -in "$stage_cert" -noout -fingerprint -sha256 2>/dev/null | sed 's/^[^=]*=//' | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')" || die 'cannot verify the mailbox certificate.'
[[ "$actual_fingerprint" == "$expected_fingerprint" ]] || die 'the certificate does not match the approved mailbox profile.'
certificate_public_key="$(openssl x509 -in "$stage_cert" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" || die 'cannot verify the mailbox certificate key pair.'
private_key_public_key="$(openssl pkey -in "$stage_cert" -pubout -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)" || die 'cannot verify the mailbox certificate key pair.'
[[ -n "$certificate_public_key" && "$certificate_public_key" == "$private_key_public_key" ]] || die 'the mailbox certificate and private key do not match.'

jq -n -c --arg app "$application_id" --arg tenant "$tenant_id" --arg fingerprint "$expected_fingerprint" \
  '{application_id:$app,tenant_id:$tenant,certificate_sha256:$fingerprint}' > "$stage_config" || die 'cannot prepare the mailbox profile.'
chmod 600 -- "$stage_cert" "$stage_config"
mv -f -- "$stage_cert" "$config_dir/certificate.pem" || die 'cannot install the protected mailbox certificate.'
mv -f -- "$stage_config" "$config_dir/config.json" || die 'cannot install the mailbox profile.'
chmod 600 -- "$config_dir/certificate.pem" "$config_dir/config.json"

unset OP_SERVICE_ACCOUNT_TOKEN
info 'scoped mailbox profile installed with user-only credential files.'
