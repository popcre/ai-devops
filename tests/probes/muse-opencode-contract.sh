#!/usr/bin/env bash
# Redacted, opt-in contract probe for Meta Model API. It prints structure and status
# only: never the key, authorization header, prompt text, completion text, or raw body.
set -euo pipefail

[ "${AI_MUSE_LIVE:-}" = 1 ] || { echo 'Set AI_MUSE_LIVE=1 to run paid Meta contract probes.' >&2; exit 2; }
[ -n "${MODEL_API_KEY:-}" ] || { echo 'MODEL_API_KEY is required.' >&2; exit 2; }
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 2; }
command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 2; }

BASE='https://api.meta.ai/v1'
MODEL='muse-spark-1.2-contributor'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

call() { # NAME METHOD PATH BODY AUTH
  local name="$1" method="$2" path="$3" body="$4" auth="$5" status
  if [ "$auth" = valid ]; then
    if [ -n "$body" ]; then
      status="$(curl -sS -o "$tmp/$name.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $MODEL_API_KEY" -H 'content-type: application/json' --data-binary "@$body")"
    else
      status="$(curl -sS -o "$tmp/$name.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $MODEL_API_KEY" -H 'content-type: application/json')"
    fi
  else
    status="$(curl -sS -o "$tmp/$name.json" -w '%{http_code}' -X "$method" "$BASE$path" -H 'Authorization: Bearer invalid-contract-probe' -H 'content-type: application/json')"
  fi
  printf '%s.status=%s\n' "$name" "$status"
  jq -r 'if .error then "error_fields=" + ([.error | keys[]] | sort | join(",")) else "response_fields=" + (keys | sort | join(",")) end' "$tmp/$name.json"
}

printf '{"model":"%s","messages":[{"role":"user","content":"contract probe"}],"max_tokens":64,"reasoning_effort":"low"}' "$MODEL" > "$tmp/completion.json"
printf '{"model":"invalid-contract-model","messages":[{"role":"user","content":"contract probe"}],"max_tokens":8}' > "$tmp/invalid-model.json"
call models GET /models '' valid
call completion POST /chat/completions "$tmp/completion.json" valid
call invalid-auth GET /models '' invalid
call invalid-model POST /chat/completions "$tmp/invalid-model.json" valid
printf 'models.include_required=%s\n' "$(jq -r --arg m "$MODEL" '[.data[].id] | index($m) != null' "$tmp/models.json")"
printf 'completion.model=%s\n' "$(jq -r '.model // "absent"' "$tmp/completion.json")"
printf 'completion.usage_fields=%s\n' "$(jq -r '.usage | keys | sort | join(",")' "$tmp/completion.json")"
printf 'completion.cache_fields=%s\n' "$(jq -r '.usage | keys | map(select(test("cache"; "i"))) | join(",")' "$tmp/completion.json")"
