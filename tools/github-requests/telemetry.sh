#!/usr/bin/env bash
# P1 collector owned by #658. No request/response text reaches this file.
# Sourced by ai-gh; opaque CLI executions are estimates, never HTTP counts.
gh_measure_init(){
  gh_measure_clock
  GH_MEASURE_START="$GH_MEASURE_CLOCK"
  GH_MEASURE_OPERATION=unknown
  case "${1:-} ${2:-}" in
    'api graphql') GH_MEASURE_OPERATION=api.graphql ;;
    'api rate_limit') GH_MEASURE_OPERATION=api.quota ;;
    'pr view'|'pr checks'|'pr list'|'pr merge'|'pr create'|'pr comment'|'pr edit'|'pr diff'|\
    'issue view'|'issue list'|'issue create'|'issue comment'|'issue edit'|'issue close'|'issue reopen'|\
    'run view'|'run list'|'run cancel'|'workflow run'|'repo view')
      GH_MEASURE_OPERATION="$1.$2" ;;
    api\ *) GH_MEASURE_OPERATION=api.unknown ;;
  esac
  GH_MEASURE_CALLER=unknown
  case "${AI_GH_CALLER:-}" in
    ai-pr-wait|ai-gh-wait|ai-blocker-watch|ai-verify-run|ai-memory-sync|ai-test-local|interactive)
      GH_MEASURE_CALLER="$AI_GH_CALLER" ;;
  esac
  GH_MEASURE_EXECUTED=0
}

gh_measure_clock(){
  # Bash 5's own clock avoids subprocess overhead and caller clock-test shims.
  local stamp="${EPOCHREALTIME:-}"
  stamp="${stamp/./}"
  if [[ "$stamp" =~ ^[0-9]{16}$ ]]; then
    GH_MEASURE_CLOCK="${stamp:0:13}"
  else
    GH_MEASURE_CLOCK=$(date +%s%3N)
  fi
}

gh_measure_finish(){
  local status="$1" elapsed bucket=unknown result=failed record dir file count
  # Fixed allowlists and integers only: never persist argv, bodies, URLs,
  # arbitrary environment labels, machine names or authentication material.
  [[ "$status" =~ ^[0-9]{1,3}$ ]] || status=1
  [[ "${GH_MEASURE_START:-}" =~ ^[0-9]{13}$ ]] || return 1
  gh_measure_clock
  [[ "$GH_MEASURE_CLOCK" =~ ^[0-9]{13}$ ]] || return 1
  elapsed=$(( GH_MEASURE_CLOCK - GH_MEASURE_START ))
  (( elapsed >= 0 )) || elapsed=0
  [ "$GH_MEASURE_OPERATION" = api.graphql ] && bucket=graphql
  [ "$status" = 0 ] && result=success
  [ "$status" = 75 ] && result=deferred
  dir="$STATE/measurements"
  # Completion must not hold up other callers. Use an
  # independent non-waiting lock; contention is a visible missing sample.
  [ ! -L "$dir" ] || return 1
  ( umask 077; mkdir -p "$dir" ) || return 1
  mkdir "$dir/write.lock" 2>/dev/null || return 1
  local utc day
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  day="${utc:0:10}"
  file="$dir/$day.jsonl"
  # Seven daily files, <= 4 MiB each. Never follow a pre-existing symlink.
  if [ -L "$dir" ] || [ -L "$file" ]; then rmdir "$dir/write.lock"; return 1; fi
  count=$(wc -c 2>/dev/null < "$file") || count=0
  if [ "$count" -ge 4193280 ]; then rmdir "$dir/write.lock"; return 1; fi
  record=$(printf '{"schema":1,"utc":"%s","operation":"%s","caller":"%s","api_host":"unknown","principal":"unknown","machine":"local","repository":"redacted","request_class":"unknown","bucket":"%s","cli_executions":%s,"http_requests":null,"graphql_points":null,"measurement":"opaque_cli_estimate","cache_hit":false,"latency_ms":%s,"result":"%s","exit_status":%s,"reset":null}' \
    "$utc" "$GH_MEASURE_OPERATION" "$GH_MEASURE_CALLER" "$bucket" "$GH_MEASURE_EXECUTED" "$elapsed" "$result" "$status")
  ( umask 077; printf '%s\n' "$record" >> "$file" )
  local write_rc=$?
  # Retention only touches our fixed date-shaped regular files.
  local old cutoff seconds
  printf -v seconds '%(%s)T' -1
  TZ=UTC printf -v cutoff '%(%F)T' "$(( seconds - 6 * 86400 ))"
  for old in "$dir"/????-??-??.jsonl; do
    [ -f "$old" ] && [ ! -L "$old" ] || continue
    [[ "${old##*/}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.jsonl$ ]] || continue
    [[ "${old##*/}" < "$cutoff.jsonl" ]] && rm -f -- "$old"
  done
  rmdir "$dir/write.lock" || return 1
  return "$write_rc"
}

# Existing admission probe supplies these observations: no extra request and
# no change to its core-only admission semantics (P2 owns that repair).
gh_measure_quota(){
  local bucket record=''; local remaining limit reset
  for bucket in core graphql search; do
    remaining="${1:-unknown}"; limit="${2:-unknown}"; reset="${3:-unknown}"
    if [[ "$remaining" =~ ^[0-9]{1,10}$ && "$limit" =~ ^[0-9]{1,10}$ && "$reset" =~ ^[0-9]{1,10}$ ]]; then
      remaining=$((10#$remaining)); limit=$((10#$limit)); reset=$((10#$reset))
      record+="${record:+,}\"$bucket\":{\"remaining\":$remaining,\"limit\":$limit,\"reset\":$reset}"
    else
      record+="${record:+,}\"$bucket\":null"
    fi
    [ "$#" -lt 3 ] || shift 3
  done
  local dest="$STATE/quota-observation.json" temp="$STATE/quota-observation.$$.$RANDOM.tmp" utc
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  [ ! -L "$dest" ] || return 1
  # One fixed-size latest snapshot; consumers must archive independent bounded
  # samples for reset windows. Never infer a principal from a token label.
  ( umask 077; set -o noclobber; printf '{"schema":1,"utc":"%s","principal":"unknown","measurement":"server_bucket_snapshot","buckets":{%s}}\n' "$utc" "$record" > "$temp" ) || return 1
  mv -f -- "$temp" "$dest" || { rm -f -- "$temp"; return 1; }
}
