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
    ai-pr-wait|ai-gh-wait|ai-blocker-watch|ai-verify-run|ai-memory-sync|ai-test-local|ai-merge-group-evidence|interactive)
      GH_MEASURE_CALLER="$AI_GH_CALLER" ;;
  esac
  if [ "$GH_MEASURE_CALLER" = ai-blocker-watch ]; then
    case "${AI_GH_OPERATION:-}" in
      bw.snapshot|bw.dependents|bw.wake_miss|bw.alarm_issue|bw.link_issue)
        GH_MEASURE_OPERATION="$AI_GH_OPERATION" ;;
    esac
  fi
  GH_MEASURE_EXECUTED=0
  GH_MEASURE_PRINCIPAL=unknown
  GH_MEASURE_REQUEST_CLASS=unknown
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
  local status="$1" elapsed bucket=unknown result=failed record utc
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
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":1,"utc":"%s","operation":"%s","caller":"%s","api_host":"unknown","principal":"%s","machine":"local","repository":"redacted","request_class":"%s","bucket":"%s","cli_executions":%s,"http_requests":null,"graphql_points":null,"measurement":"opaque_cli_estimate","cache_hit":false,"latency_ms":%s,"result":"%s","exit_status":%s,"reset":null}' \
    "$utc" "$GH_MEASURE_OPERATION" "$GH_MEASURE_CALLER" "$GH_MEASURE_PRINCIPAL" "$GH_MEASURE_REQUEST_CLASS" "$bucket" "$GH_MEASURE_EXECUTED" "$elapsed" "$result" "$status")
  gh_measure_append "$STATE/measurements" "$record"
}

# A verified-principal lookup is an extra, bounded CLI/API operation. Count it
# separately from the user's requested command. The CLI may redirect or retry,
# so even a successful lookup has unknown exact HTTP request count.
gh_measure_identity_lookup(){
  local status="$1" principal="${2:-}" result=failed utc record
  [[ "$status" =~ ^[0-9]{1,3}$ ]] || status=1
  if [ "$status" = 0 ]; then result=success; fi
  if [ "$status" = 0 ]; then gh_measure_set_principal "$principal"; fi
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":1,"utc":"%s","operation":"api.identity","caller":"%s","api_host":"unknown","principal":"%s","machine":"local","repository":"redacted","request_class":"identity_probe","bucket":"core","cli_executions":1,"http_requests":null,"graphql_points":null,"measurement":"direct_api_invocation_estimate","cache_hit":false,"latency_ms":null,"result":"%s","exit_status":%s,"reset":null}' \
    "$utc" "$GH_MEASURE_CALLER" "$GH_MEASURE_PRINCIPAL" "$result" "$status")
  gh_measure_append "$STATE/measurements" "$record"
}

gh_measure_set_principal(){
  GH_MEASURE_PRINCIPAL=unknown
  [[ "${1:-}" =~ ^[0-9]{1,20}$ ]] || return 0
  # Numeric GitHub IDs are enumerable, so plain hashing is reversible. Mix a
  # private, machine-local random salt before hashing. Labels intentionally
  # cannot be correlated across hosts; P6 must use governed local metadata.
  local salt_file="$STATE/principal-salt" temp salt digest
  if [ -L "$salt_file" ] || { [ -e "$salt_file" ] && [ ! -f "$salt_file" ]; }; then return 0; fi
  if [ ! -s "$salt_file" ]; then
    temp=$(umask 077; mktemp "$STATE/principal-salt.XXXXXX") || return 0
    if ! head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$temp"; then
      rm -f -- "$temp"; return 0
    fi
    if [ ! -e "$salt_file" ]; then mv -f -- "$temp" "$salt_file"; else rm -f -- "$temp"; fi
  fi
  if [ -L "$salt_file" ] || [ ! -f "$salt_file" ]; then return 0; fi
  salt=$(cat "$salt_file" 2>/dev/null) || return 0
  [[ "$salt" =~ ^[0-9a-f]{64}$ ]] || return 0
  digest=$(printf '%s:%s' "$salt" "$1" | sha256sum | awk '{print $1}')
  GH_MEASURE_PRINCIPAL="local-sha256:$digest"
}

# A random ID binds costs to a completed wait or tick without recording a PR,
# repository, URL, token, or response body.
gh_measure_workflow_id(){
  local id
  id="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')" || return 1
  [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 1
  printf '%s' "$id"
}

gh_measure_workflow_outcome(){
  local caller="${1:-}" workflow="${2:-}" id="${3:-}" outcome="${4:-}" elapsed="${5:-}" utc record
  case "$caller:$workflow:$outcome" in
    ai-pr-wait:pr_wait:merged|ai-pr-wait:pr_wait:closed|\
    ai-pr-wait:pr_wait:checks_failed|ai-pr-wait:pr_wait:ejected|\
    ai-pr-wait:pr_wait:deadline|ai-blocker-watch:blocker_watch_tick:completed) ;;
    *) return 2 ;;
  esac
  [[ "$id" =~ ^[0-9a-f]{32}$ && "$elapsed" =~ ^[0-9]{1,9}$ ]] || return 2
  [ "$elapsed" -le 604800000 ] || return 2
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":3,"utc":"%s","measurement":"workflow_outcome","caller":"%s","workflow":"%s","workflow_id":"%s","outcome":"%s","elapsed_ms":%s}' \
    "$utc" "$caller" "$workflow" "$id" "$outcome" "$elapsed")
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
}

# Observe quota fields carried by an upstream GraphQL response. Optional
# remaining/resetAt stay null unless both fields validate; old cost-only
# responses remain useful without inventing a reset window.
gh_measure_graphql_cost(){
  local caller="${1:-}" operation="${2:-}" workflow="${3:-}" id="${4:-}" origin="${5:-}" context="${6:-}" observation utc record id_json=null context_json=null
  case "$caller:$operation:$workflow" in
    ai-pr-wait:graphql.pr_status:pr_wait) [ "$origin" = upstream_refresh ] || return 2 ;;
    ai-blocker-watch:graphql.open_issue_snapshot:blocker_watch_tick|\
    ai-blocker-watch:graphql.issue_detail:blocker_watch_tick) [ "$origin" = direct ] || return 2 ;;
    *) return 2 ;;
  esac
  [ -z "$id" ] || [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 2
  observation="$(jq -ce '
    .data.rateLimit as $r |
    select(($r.cost | type) == "number" and $r.cost >= 0 and $r.cost <= 1000000000 and $r.cost == ($r.cost | floor)) |
    if (($r.remaining | type) == "number" and $r.remaining >= 0 and $r.remaining <= 1000000000 and $r.remaining == ($r.remaining | floor)
        and ($r.resetAt | type) == "string" and ($r.resetAt | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")))
    then {graphql_points:$r.cost,graphql_remaining:$r.remaining,graphql_reset_at:$r.resetAt}
    else {graphql_points:$r.cost,graphql_remaining:null,graphql_reset_at:null} end
  ' 2>/dev/null)" || return 0
  observation="${observation#\{}"
  observation="${observation%\}}"
  [ -z "$id" ] || id_json="\"$id\""
  [[ "$context" =~ ^v1:[0-9a-f]{64}$ ]] && context_json="\"$context\""
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":2,"utc":"%s","measurement":"observed_graphql_cost","caller":"%s","operation":"%s","workflow":"%s","workflow_id":%s,"access_context":%s,"http_requests":null,%s}' \
    "$utc" "$caller" "$operation" "$workflow" "$id_json" "$context_json" "$observation")
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
}

# Both command records and server snapshots share the same filesystem boundary.
gh_measure_append(){
  local dir="$1" record="$2" file count
  # Completion must not hold up other callers. Use an
  # independent non-waiting lock; contention is a visible missing sample.
  [ ! -L "$dir" ] || return 1
  ( umask 077; mkdir -p "$dir" ) || return 1
  if ! mkdir "$dir/write.lock" 2>/dev/null; then
    # A writer holds the lock for milliseconds; one older than a minute was
    # left by a crash. Clear it once so measurement does not stop for good.
    [ -n "$(find "$dir/write.lock" -maxdepth 0 -type d -mmin +1 2>/dev/null)" ] || return 1
    rmdir "$dir/write.lock" 2>/dev/null
    mkdir "$dir/write.lock" 2>/dev/null || return 1
  fi
  local utc day
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  day="${utc:0:10}"
  file="$dir/$day.jsonl"
  # Seven daily files, <= 4 MiB each. Never follow a pre-existing symlink.
  if [ -L "$dir" ] || [ -L "$file" ] || { [ -e "$file" ] && [ ! -f "$file" ]; }; then
    rmdir "$dir/write.lock"; return 1
  fi
  count=$(wc -c 2>/dev/null < "$file") || count=0
  if [ "$count" -ge 4193280 ]; then rmdir "$dir/write.lock"; return 1; fi
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

# The existing admission probe supplies named resource rows. Keep telemetry's
# fixed schema separate from admission's dynamic resource inventory.
gh_measure_quota_rows(){
  local bucket remaining limit reset extra
  local core=(unknown unknown unknown) graphql=(unknown unknown unknown) search=(unknown unknown unknown)
  while read -r bucket remaining limit reset extra; do
    [ -z "$extra" ] || continue
    case "$bucket" in
      core) core=("$remaining" "$limit" "$reset") ;;
      graphql) graphql=("$remaining" "$limit" "$reset") ;;
      search) search=("$remaining" "$limit" "$reset") ;;
    esac
  done <<< "${1:-}"
  gh_measure_quota "${core[@]}" "${graphql[@]}" "${search[@]}"
}

# No extra request and no change to the upstream resource admission semantics.
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
  local dest="$STATE/quota-observation.json" temp utc
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -f "$dest" ]; }; then return 1; fi
  temp=$(umask 077; mktemp "$STATE/quota-observation.XXXXXX") || return 1
  # Retain bounded history as well as the latest observation, so normal probes
  # can establish reset-window bounds without a new sampling loop.
  record=$(printf '{"schema":1,"utc":"%s","principal":"%s","measurement":"server_bucket_snapshot","buckets":{%s}}' "$utc" "${GH_MEASURE_PRINCIPAL:-unknown}" "$record")
  printf '%s\n' "$record" > "$temp" || { rm -f -- "$temp"; return 1; }
  mv -f -- "$temp" "$dest" || { rm -f -- "$temp"; return 1; }
  gh_measure_append "$STATE/quota-measurements" "$record"
}
