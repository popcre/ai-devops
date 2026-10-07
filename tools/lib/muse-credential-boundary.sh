#!/usr/bin/env bash
# Shared Muse credential boundary; owned by reviewer-safety.
MUSE_CREDENTIAL_BOUNDARY='
secret_file="${AI_MUSE_SECRET_FILE:-}"
[ -n "$secret_file" ] && [ -f "$secret_file" ] && [ ! -L "$secret_file" ] || exit 86
IFS= read -r MODEL_API_KEY < "$secret_file" || exit 87
rm -f -- "$secret_file" || exit 88
unset AI_MUSE_SECRET_FILE
case "${AI_MUSE_KEY_ENV:-MODEL_API_KEY}" in
  MODEL_API_KEY) export MODEL_API_KEY;;
  META_API_KEY) export META_API_KEY="$MODEL_API_KEY"; unset MODEL_API_KEY;;
  *) exit 89;;
esac
unset AI_MUSE_KEY_ENV
exec "$@"
'

muse_clean_environment() {
  local env_bin="${3:-/usr/bin/env}" safe_name system_drive
  clean_env=("$env_bin" -i "PATH=$PATH" "HOME=$1" "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" "XDG_DATA_HOME=$XDG_DATA_HOME" "XDG_STATE_HOME=$XDG_STATE_HOME" "XDG_CACHE_HOME=$XDG_CACHE_HOME")
  [ "$2" != muse-code ] || clean_env+=("AI_MUSE_KEY_ENV=META_API_KEY")
  clean_env+=("PSModuleAnalysisCachePath=${TEMP:-${TMPDIR:-/tmp}}/ai-muse-ps-module-cache") # #754: never into the checkout
  for safe_name in USERPROFILE TEMP TMP TMPDIR SYSTEMROOT COMSPEC PATHEXT USER USERNAME LOGNAME LANG LC_ALL TERM SSL_CERT_FILE SSL_CERT_DIR NODE_EXTRA_CA_CERTS; do
    [ -z "${!safe_name:-}" ] || clean_env+=("$safe_name=${!safe_name}")
  done
  if declare -F muse_system_drive_env >/dev/null && system_drive="$(muse_system_drive_env)"; then clean_env+=("$system_drive"); fi
  if [ "${4:-1}" = 1 ] && [ -n "${AI_MUSE_TEST_DIR:-}" ]; then
    clean_env+=("AI_MUSE_TEST_DIR=$AI_MUSE_TEST_DIR")
    while IFS='=' read -r safe_name _; do case "$safe_name" in AI_MUSE_TEST_*|MUSE_STUB_*) clean_env+=("$safe_name=${!safe_name}");; esac; done < <(env)
  fi
}

muse_system_drive_env(){
  # PowerShell exports SystemDrive; Git Bash exposes the same Windows value as
  # SYSTEMDRIVE. Pass only a drive letter through the clean provider boundary.
  local drive="${SystemDrive:-${SYSTEMDRIVE:-}}"
  [[ "$drive" =~ ^[A-Za-z]:$ ]] || return 1
  printf 'SystemDrive=%s\n' "$drive"
}
