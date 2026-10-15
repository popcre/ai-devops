#!/usr/bin/env bash
# Shared by the GLM client and installer: credentials travel only on curl stdin.
# Owner: the existing OpenCode GLM harness; keeps its two callers consistent.
opencode_curl_auth_config() {
  [ "$#" -eq 2 ] || return 2
  local auth="$1:$2"
  case "$auth" in *$'\n'*|*$'\r'*) return 1 ;; esac
  auth="${auth//\\/\\\\}"; auth="${auth//\"/\\\"}"
  # Both callers have a fixed loopback URL. Never send its auth to a proxy.
  printf 'noproxy = "*"\nuser = "%s"\n' "$auth"
}

# Never place curl behind the formatter in one pipeline: a failed formatter
# would still launch curl with no credentials and no loopback proxy bypass.
opencode_curl_with_auth_config() {
  [ "$#" -ge 1 ] || return 2
  local config="$1"; shift
  [ -n "$config" ] || return 2
  printf '%s\n' "$config" | curl --config - "$@"
}

opencode_curl_auth_request() {
  [ "$#" -ge 3 ] || return 2
  local user="$1" password="$2" config
  shift 2
  config="$(opencode_curl_auth_config "$user" "$password")" || return 1
  opencode_curl_with_auth_config "$config" "$@"
}

opencode_curl_auth_health_request() {
  [ "$#" -eq 4 ] || return 2
  local user="$1" password="$2" url="$3" timeout="$4" config
  config="$(opencode_curl_auth_config "$user" "$password")" || return 2
  opencode_curl_with_auth_config "$config" -fsS -m "$timeout" "$url" >/dev/null || return 1
}
