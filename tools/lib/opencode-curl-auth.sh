#!/usr/bin/env bash
# Shared by the GLM client and installer: credentials travel only on curl stdin.
# Owner: the existing OpenCode GLM harness; keeps its two callers consistent.
opencode_curl_auth_config() {
  [ "$#" -eq 2 ] || return 2
  local auth="$1:$2"
  case "$auth" in *$'\n'*|*$'\r'*) return 1 ;; esac
  auth="${auth//\\/\\\\}"; auth="${auth//\"/\\\"}"
  printf 'user = "%s"\n' "$auth"
}
