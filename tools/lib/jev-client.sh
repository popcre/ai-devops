#!/usr/bin/env bash
# jev-client.sh — the single bounded TypeSafe Jev transport (advisory plan §9.2).
#
# Consumers source this file. It is the only code allowed to resolve
# TYPESAFE_API_KEY, re-exec through op run, send HTTP, enforce timeouts and
# sizes, validate the response model/schema/probabilities, and return
# normalized Noul/Choice/Score values.
#
# Shell API (fixed):
#   jev_bootstrap "$0" ORIGINAL_ARGS...
#                               # before reading stdin; pass every original
#                               # argument (save them before option parsing).
#                               # Re-execs under op run; after the child starts
#                               # the unkeyed parent exits with its status
#   jev_request REQ_JSON RESP_JSON
#   jev_read_noul RESP_JSON QUESTION_ID
#   jev_read_choice RESP_JSON QUESTION_ID ALLOWED_LABELS_JSON
#   jev_read_score RESP_JSON QUESTION_ID
#   jev_cleanup
#
# Failure contract: never print a decision word. Nonzero exit only.
# Consumers convert nonzero to `unavailable`/`abstain`.
# Prints no headers, request bodies, keys, or raw responses on error.
#
# Offline tests: set AI_JEV_OFFLINE_TEST=1 and AI_JEV_ENDPOINT to a stub.

# shellcheck shell=bash

JEV_CLIENT_ROOT="${JEV_CLIENT_ROOT:-}"
if [ -z "$JEV_CLIENT_ROOT" ]; then
  _jev_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  JEV_CLIENT_ROOT="$(cd "$_jev_here/../.." && pwd)"
fi
JEV_CONFIG="${JEV_CONFIG:-$JEV_CLIENT_ROOT/config/jev-decisions.json}"
JEV_CFG_DIR="${AI_DEVOPS_CONFIG_DIR:-$HOME/.config/ai-devops}"
JEV_TOKEN_FILE="${JEV_TOKEN_FILE:-$JEV_CFG_DIR/op-service-account}"

# Populated by jev_load_config
JEV_MODEL_PIN=""
JEV_ENDPOINT=""
JEV_CONNECT_TIMEOUT=""
JEV_CALL_TIMEOUT=""
JEV_MAX_REQUEST_BYTES=""
JEV_MAX_RESPONSE_BYTES=""
JEV_MAX_CALLS=""
JEV_RATE_INTERVAL=""
JEV_CALLS_MADE=0
JEV_KEY=""
JEV_TMPFILES=()

jev_fail() {
  # Quiet by default so consumers own the observable FAIL/abstain message.
  # Set AI_JEV_DEBUG=1 for client diagnostics (never secrets, bodies, or keys).
  if [ "${AI_JEV_DEBUG:-}" = 1 ]; then
    printf 'jev-client: %s\n' "$*" >&2
  fi
  return 1
}

# Empty/missing key is always loud (advisory §9.2): fail closed, no quiet skip.
jev_fail_loud() {
  printf 'jev-client: %s\n' "$*" >&2
  return 1
}

jev_load_config() {
  [ -f "$JEV_CONFIG" ] || { jev_fail "config not found: jev-decisions.json"; return 1; }
  command -v jq >/dev/null 2>&1 || { jev_fail "jq is required"; return 1; }
  # One jq fork: Windows Git Bash hits fork limits on rapid repeated execs.
  local packed
  packed="$(jq -r '[.model_pin,.endpoint,(.connect_timeout_seconds|tostring),(.call_timeout_seconds|tostring),(.max_request_bytes|tostring),(.max_response_bytes|tostring),(.max_calls_per_run|tostring),(.rate_interval_seconds|tostring)]|@tsv' "$JEV_CONFIG")" || {
    jev_fail "config unreadable"
    return 1
  }
  IFS=$'\t' read -r JEV_MODEL_PIN JEV_ENDPOINT JEV_CONNECT_TIMEOUT JEV_CALL_TIMEOUT \
    JEV_MAX_REQUEST_BYTES JEV_MAX_RESPONSE_BYTES JEV_MAX_CALLS JEV_RATE_INTERVAL <<EOF
$packed
EOF
  [ -n "$JEV_MODEL_PIN" ] && [ -n "$JEV_ENDPOINT" ] || { jev_fail "config missing model_pin/endpoint"; return 1; }
  if [ -n "${AI_JEV_ENDPOINT:-}" ]; then
    [ "${AI_JEV_OFFLINE_TEST:-}" = 1 ] || { jev_fail "AI_JEV_ENDPOINT requires AI_JEV_OFFLINE_TEST=1"; return 1; }
    JEV_ENDPOINT="$AI_JEV_ENDPOINT"
  fi
  return 0
}

jev_cleanup() {
  local f
  for f in ${JEV_TMPFILES[@]+"${JEV_TMPFILES[@]}"}; do
    [ -n "$f" ] && rm -f "$f" 2>/dev/null || true
  done
  JEV_TMPFILES=()
  JEV_KEY=""
  unset TYPESAFE_API_KEY 2>/dev/null || true
  return 0
}

# jev_tmp VAR — create a mode-0600 temp file, store its path in VAR, and
# register it for jev_cleanup. Never call it in $(...): a subshell would lose
# the registration and leak the file.
jev_tmp() {
  local _jev_var="$1" t
  [[ "$_jev_var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  t="$(mktemp)" || return 1
  chmod 600 "$t" 2>/dev/null || true
  JEV_TMPFILES+=("$t")
  printf -v "$_jev_var" '%s' "$t"
}

# jev_bootstrap "$0" "$@"
# When the key is absent: spool stdin to a mode-0600 temporary file, resolve
# the one managed op:// reference, re-exec the consumer through op run, and
# return only in the keyed child. Once the child has started, the unkeyed
# parent never returns: it cleans up and exits with the child's status, so the
# consumer's work runs exactly once. If op run fails before starting the child
# (auth expiry, locked vault), bootstrap returns nonzero so the consumer's own
# failure output (abstain / FAIL:) still runs. Empty resolution is nonzero and
# loud without revealing the reference value.
jev_bootstrap() {
  local self="$1"; shift || true
  # Child side: tell the parent the keyed child started.
  if [ -n "${AI_JEV_REEXEC:-}" ] && [ -n "${AI_JEV_CHILD_MARK:-}" ]; then
    : > "$AI_JEV_CHILD_MARK" 2>/dev/null || true
    unset AI_JEV_CHILD_MARK
  fi
  jev_load_config || return 1
  trap 'jev_cleanup' EXIT INT TERM

  if [ -n "${TYPESAFE_API_KEY:-}" ]; then
    JEV_KEY="$TYPESAFE_API_KEY"
    unset TYPESAFE_API_KEY
    [ -n "$JEV_KEY" ] || { jev_fail_loud "empty key; refusing to send an unauthenticated request"; return 1; }
    return 0
  fi

  [ -z "${AI_JEV_REEXEC:-}" ] || { jev_fail_loud "TYPESAFE_API_KEY resolved EMPTY after op run"; return 1; }
  command -v op >/dev/null 2>&1 || { jev_fail "1Password CLI (op) is required"; return 1; }

  local input ref_line ref_file token_file
  jev_tmp input || return 1
  cat > "$input"
  ref_line=""
  local f
  for f in "$JEV_CFG_DIR/mcp.env" "$JEV_CLIENT_ROOT/config/mcp.env.example"; do
    [ -f "$f" ] || continue
    ref_line="$(grep '^TYPESAFE_API_KEY=op://' "$f" || true)"
    [ -z "$ref_line" ] || break
  done
  [ -n "$ref_line" ] || { jev_fail "no TYPESAFE_API_KEY op:// reference found"; return 1; }
  [ "$(printf '%s\n' "$ref_line" | wc -l)" -eq 1 ] || { jev_fail "more than one TYPESAFE_API_KEY reference"; return 1; }
  jev_tmp ref_file || return 1
  printf '%s\n' "$ref_line" > "$ref_file"

  token_file="$JEV_TOKEN_FILE"
  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -s "$token_file" ]; then
    OP_SERVICE_ACCOUNT_TOKEN="$(cat "$token_file")"
    export OP_SERVICE_ACCOUNT_TOKEN
  fi

  local rc mark
  jev_tmp mark || return 1
  rm -f "$mark"
  AI_JEV_REEXEC=1 AI_JEV_CHILD_MARK="$mark" \
    op run --env-file "$ref_file" -- /usr/bin/env bash "$self" "$@" < "$input" && rc=0 || rc=$?
  if [ ! -e "$mark" ]; then
    jev_fail_loud "op run failed before starting the keyed child (exit $rc)"
    return 1
  fi
  jev_cleanup
  exit "$rc"
}

# jev_request REQUEST_JSON RESPONSE_JSON
# Regular files only. Enforces byte limits before network I/O. One bounded
# request. Zero only for HTTP 200 plus the configured exact response model.
jev_request() {
  local req="$1" resp="$2"
  [ -f "$req" ] || { jev_fail "request file missing"; return 1; }
  [ -n "${JEV_KEY:-}" ] || { jev_fail "key not bootstrapped"; return 1; }
  command -v curl >/dev/null 2>&1 || { jev_fail "curl is required"; return 1; }
  command -v jq >/dev/null 2>&1 || { jev_fail "jq is required"; return 1; }

  if [ "$JEV_CALLS_MADE" -ge "$JEV_MAX_CALLS" ]; then
    jev_fail "per-run call cap reached ($JEV_MAX_CALLS)"
    return 1
  fi

  local req_size resp_size code rc
  req_size=$(wc -c < "$req" | tr -d '[:space:]')
  if [ "$req_size" -gt "$JEV_MAX_REQUEST_BYTES" ]; then
    jev_fail "request exceeds byte limit"
    return 1
  fi

  # Validate request shape before I/O: model pin, questions present.
  if ! jq -e --arg m "$JEV_MODEL_PIN" '.model == $m and (.questions|type=="object") and (.questions|length>0) and (.state != null)' \
      "$req" >/dev/null 2>&1; then
    jev_fail "request failed schema/model precheck"
    return 1
  fi

  sleep "$JEV_RATE_INTERVAL" 2>/dev/null || true

  set +e
  code="$(printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$JEV_KEY" \
    | curl -sS -o "$resp" -w '%{http_code}' \
        --connect-timeout "$JEV_CONNECT_TIMEOUT" --max-time "$JEV_CALL_TIMEOUT" \
        -H @- --data-binary @"$req" "$JEV_ENDPOINT" 2>/dev/null)"
  rc=$?
  set -e
  JEV_CALLS_MADE=$((JEV_CALLS_MADE + 1))

  [ "$rc" -eq 0 ] || { jev_fail "network error"; return 1; }
  [ "$code" = 200 ] || { jev_fail "HTTP error"; return 1; }

  resp_size=$(wc -c < "$resp" | tr -d '[:space:]')
  if [ "$resp_size" -gt "$JEV_MAX_RESPONSE_BYTES" ]; then
    jev_fail "response exceeds byte limit"
    return 1
  fi

  # Exact response model + answers object required. Do not dump body on failure.
  if ! jq -e --arg m "$JEV_MODEL_PIN" '.model == $m and (.answers|type=="object") and (.usage|type=="object")' \
      "$resp" >/dev/null 2>&1; then
    jev_fail "response failed schema/model precheck"
    return 1
  fi
  return 0
}

# jev_read_noul RESPONSE_JSON QUESTION_ID  -> prints probability in [0,1]
jev_read_noul() {
  local resp="$1" qid="$2"
  [ -f "$resp" ] || return 1
  jq -er --arg q "$qid" '
    .answers[$q] as $a
    | select($a.type == "noul")
    | select(($a.noul|type) == "number")
    | select($a.noul >= 0 and $a.noul <= 1)
    | $a.noul
  ' "$resp" 2>/dev/null
}

# jev_read_choice RESPONSE_JSON QUESTION_ID ALLOWED_LABELS_JSON
# Prints canonical JSON: label, confidence, probabilities limited to allowed labels.
jev_read_choice() {
  local resp="$1" qid="$2" allowed="$3"
  [ -f "$resp" ] || return 1
  jq -cer --arg q "$qid" --argjson allowed "$allowed" '
    .answers[$q] as $a
    | select($a.type == "choice")
    | select(($a.choice|type) == "string")
    | select(($a.confidence|type) == "number")
    | select(($a.probabilities|type) == "object")
    | ($a.probabilities | keys) as $keys
    | select(($keys - $allowed | length) == 0)
    | select(($allowed - $keys | length) == 0)
    | select($allowed | index($a.choice) != null)
    | {
        label: $a.choice,
        confidence: $a.confidence,
        probabilities: $a.probabilities
      }
  ' "$resp" 2>/dev/null
}

# jev_read_score RESPONSE_JSON QUESTION_ID
# Prints canonical JSON: score, level_index (argmax of probabilities),
# confidence, probabilities, legend. Abstains (nonzero) on shape mismatch.
jev_read_score() {
  local resp="$1" qid="$2"
  [ -f "$resp" ] || return 1
  jq -cer --arg q "$qid" '
    .answers[$q] as $a
    | select($a.type == "score")
    | select(($a.score|type) == "number")
    | select(($a.confidence|type) == "number")
    | select(($a.probabilities|type) == "object")
    | select(($a.legend|type) == "object")
    | ($a.probabilities | to_entries | max_by(.value) | .key) as $top
    | {
        score: $a.score,
        level_index: (if ($top|type) == "string" and ($top|test("^[0-9]+$")) then ($top|tonumber) else -1 end),
        level_key: $top,
        confidence: $a.confidence,
        probabilities: $a.probabilities,
        legend: $a.legend
      }
  ' "$resp" 2>/dev/null
}

jev_usage_json() {
  local resp="$1"
  [ -f "$resp" ] || return 1
  jq -c '.usage // {}' "$resp" 2>/dev/null
}
