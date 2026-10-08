#!/usr/bin/env bash
# P1 collector owned by #658. No request/response text reaches this file.
# Sourced by ai-gh; opaque CLI executions are estimates, never HTTP counts.
GH_MEASURE_LOCAL_PLATFORM_INITIALIZED=0
GH_MEASURE_LOCAL_PLATFORM=unknown
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
    'auth status') GH_MEASURE_OPERATION=auth.status ;;
    api\ *) GH_MEASURE_OPERATION=api.unknown ;;
  esac
  GH_MEASURE_CALLER=unknown
  case "${AI_GH_CALLER:-}" in
    ai-pr-wait|ai-gh-wait|ai-blocker-watch|ai-verify-run|ai-memory-sync|ai-test-local|\
    ai-merge-group-evidence|ai-transcript-destination-check|ai-workspace-status|\
    ai-reviewer-membership-drift|ai-devops-doctor|ai-devops-installer|interactive)
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
  GH_MEASURE_BUCKET=unknown
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

# Independent local observation clock.  The waiter calls this exactly at its
# two boundary points; it never falls back to wall time or a configurable
# source.  /proc/uptime reports BOOTTIME in seconds with centisecond precision.
gh_measure_local_clock_parse(){
  GH_MEASURE_LOCAL_CLOCK_MS=''
  GH_MEASURE_LOCAL_CLOCK_BASIS=unknown
  local uptime="${1:-}" seconds centis
  [[ "$uptime" =~ ^([0-9]{1,10})\.([0-9]{2})$ ]] || return 0
  seconds="${BASH_REMATCH[1]}"
  centis="${BASH_REMATCH[2]}"
  seconds=$((10#$seconds))
  centis=$((10#$centis))
  GH_MEASURE_LOCAL_CLOCK_MS=$((seconds * 1000 + centis * 10))
  [ "$GH_MEASURE_LOCAL_CLOCK_MS" -le 9999999999999 ] || { GH_MEASURE_LOCAL_CLOCK_MS=''; return 0; }
  GH_MEASURE_LOCAL_CLOCK_BASIS=linux_boottime_centiseconds
}

gh_measure_local_clock(){
  GH_MEASURE_LOCAL_CLOCK_MS=''
  GH_MEASURE_LOCAL_CLOCK_BASIS=unknown
  if [ "$GH_MEASURE_LOCAL_PLATFORM_INITIALIZED" -eq 0 ]; then
    GH_MEASURE_LOCAL_PLATFORM_INITIALIZED=1
    [ "$(uname -s 2>/dev/null || true)" = Linux ] && GH_MEASURE_LOCAL_PLATFORM=linux
  fi
  [ "$GH_MEASURE_LOCAL_PLATFORM" = linux ] || return 0
  local uptime
  IFS=' ' read -r uptime _ < /proc/uptime 2>/dev/null || return 0
  gh_measure_local_clock_parse "$uptime"
}

gh_measure_local_observation(){
  local id="${1:-}" outcome="${2:-}" start="${3:-}" end="${4:-}" basis="${5:-unknown}" output_failed="${6:-1}" utc record reason=clock_unknown lower=null upper=null error=null start_json=null end_json=null
  case "$outcome" in merged|closed|checks_failed|ejected|deadline) ;; *) return 2 ;; esac
  [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 2
  if [ "$output_failed" = 1 ]; then
    reason=delivery_unknown
  elif [ "$basis" = linux_boottime_centiseconds ] && [[ "$start" =~ ^[0-9]{1,13}$ ]] && [[ "$end" =~ ^[0-9]{1,13}$ ]]; then
    start_json="$start"; end_json="$end"
    if [ "$end" -lt "$start" ]; then
      reason=clock_negative
      start_json=null; end_json=null
    else
      local elapsed=$((end - start))
      if [ "$elapsed" -le 604800000 ]; then
        lower=$((elapsed - 20)); [ "$lower" -lt 0 ] && lower=0
        upper=$((elapsed + 20)); error=20; reason=source_unknown
      else
        reason=clock_negative
        start_json=null; end_json=null
      fi
    fi
  fi
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":5,"utc":"%s","measurement":"local_workflow_observation","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"%s","outcome":"%s","boundary":"receipt_init_to_terminal_output","clock_basis":"%s","start_monotonic_ms":%s,"end_monotonic_ms":%s,"duration_lower_ms":%s,"duration_upper_ms":%s,"clock_error_bound_ms":%s,"source_verified":"unknown","acceptance":"unknown","unknown_reason":"%s"}' \
    "$utc" "$id" "$outcome" "$basis" "$start_json" "$end_json" "$lower" "$upper" "$error" "$reason")
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
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
  if [ "$GH_MEASURE_OPERATION" = api.graphql ] || [ "${GH_MEASURE_BUCKET:-unknown}" = graphql ]; then bucket=graphql; fi
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

# Read the only metadata file accepted by the private companion.  Invalid or
# unavailable metadata is evidence of an unknown cohort; it never affects the
# caller's result.
gh_measure_read_cohort(){
  local helper python result
  GH_MEASURE_COHORT_ID=''; GH_MEASURE_TARGET_ORDINAL=''; GH_MEASURE_COHORT_REASON=metadata_absent
  helper="${BASH_SOURCE[0]%/*}/report.py"
  python="${PYTHON_RUNNER:-}"
  [ -n "$python" ] || python="$(command -v python3 || command -v python || true)"
  if [ -z "$python" ] || [ ! -f "$helper" ]; then GH_MEASURE_COHORT_REASON=metadata_untrusted; return 0; fi
  result="$("$python" "$helper" --cohort "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" 2>/dev/null)" || { GH_MEASURE_COHORT_REASON=metadata_untrusted; return 0; }
  GH_MEASURE_COHORT_REASON="$(printf '%s' "$result" | jq -r '.unknown_reason // empty' 2>/dev/null)"
  case "$GH_MEASURE_COHORT_REASON" in metadata_absent|metadata_untrusted) return 0 ;; source_unknown) ;; *) GH_MEASURE_COHORT_REASON=metadata_untrusted; return 0 ;; esac
  GH_MEASURE_COHORT_ID="$(printf '%s' "$result" | jq -r '.cohort_id // empty' 2>/dev/null)"
  [[ "$GH_MEASURE_COHORT_ID" =~ ^[0-9a-f]{32}$ ]] || { GH_MEASURE_COHORT_ID=''; GH_MEASURE_COHORT_REASON=metadata_untrusted; }
}

gh_measure_source_bookend(){
  PR_WAIT_SOURCE_VERIFIED=unknown
  PR_WAIT_SOURCE_FINGERPRINT_START=''
  PR_WAIT_SOURCE_FINGERPRINT_END=''
  PR_WAIT_INSTALL_GENERATION_BINDING=''
}

gh_measure_workflow_evidence(){
  local caller="${1:-}" workflow="${2:-}" id="${3:-}" utc record reason=metadata_absent cohort_json=null
  [ "$caller:$workflow" = ai-pr-wait:pr_wait ] || return 2
  [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 2
  case "${PR_WAIT_EVENT_KIND:-unknown}" in pr_merged|pr_closed|check_completed|unknown) ;; *) return 2 ;; esac
  case "${PR_WAIT_SOURCE_VERIFIED:-unknown}" in unknown|verified|changed) ;; *) return 2 ;; esac
  case "${PR_WAIT_CLOCK_QUALITY:-unknown}" in verified_bound|unverified|jump|negative|unknown) ;; *) return 2 ;; esac
  case "${PR_WAIT_DELIVERY_BOUNDARY:-unknown}" in terminal_report|unknown) ;; *) return 2 ;; esac
  gh_measure_read_cohort
  reason="$GH_MEASURE_COHORT_REASON"
  [ "$GH_MEASURE_COHORT_REASON" = source_unknown ] || { GH_MEASURE_COHORT_ID=''; GH_MEASURE_TARGET_ORDINAL=''; }
  [ -z "${GH_MEASURE_COHORT_ID:-}" ] || cohort_json="\"$GH_MEASURE_COHORT_ID\""
  [[ "${PR_WAIT_OBSERVED_UTC_MS:-}" =~ ^[0-9]{1,13}$ ]] || PR_WAIT_OBSERVED_UTC_MS=''
  [[ "${PR_WAIT_DELIVERED_UTC_MS:-}" =~ ^[0-9]{1,13}$ ]] || PR_WAIT_DELIVERED_UTC_MS=''
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  [[ "${PR_WAIT_ELIGIBLE_UTC_MS:-}" =~ ^[0-9]{1,13}$ ]] || PR_WAIT_ELIGIBLE_UTC_MS=''
  [ -z "${PR_WAIT_ELIGIBLE_UTC_MS:-}" ] || [ "$PR_WAIT_ELIGIBLE_UTC_MS" -le 9999999999999 ] || PR_WAIT_ELIGIBLE_UTC_MS=''
  if [ "${PR_WAIT_EVENT_KIND:-unknown}" = unknown ]; then PR_WAIT_ELIGIBLE_UTC_MS=''; fi
  if [ -n "$PR_WAIT_ELIGIBLE_UTC_MS" ] && { [ -z "$PR_WAIT_OBSERVED_UTC_MS" ] || [ "$PR_WAIT_ELIGIBLE_UTC_MS" -gt "$PR_WAIT_OBSERVED_UTC_MS" ]; }; then PR_WAIT_ELIGIBLE_UTC_MS=''; fi
  [ -n "$PR_WAIT_ELIGIBLE_UTC_MS" ] || PR_WAIT_EVENT_KIND=unknown
  if [ "${PR_WAIT_DELIVERY_BOUNDARY:-unknown}" = terminal_report ] &&
    { [ -z "$PR_WAIT_OBSERVED_UTC_MS" ] || [ -z "$PR_WAIT_DELIVERED_UTC_MS" ] || [ "$PR_WAIT_DELIVERED_UTC_MS" -lt "$PR_WAIT_OBSERVED_UTC_MS" ]; }; then PR_WAIT_DELIVERY_BOUNDARY=unknown; fi
  [ "${PR_WAIT_DELIVERY_BOUNDARY:-unknown}" != unknown ] || PR_WAIT_DELIVERED_UTC_MS=''
  record=$(printf '{"schema":4,"utc":"%s","measurement":"workflow_evidence","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"%s","cohort_id":%s,"target_ordinal":null,"source_verified":"unknown","source_fingerprint_start":null,"source_fingerprint_end":null,"install_generation_binding":null,"event_kind":"%s","eligible_utc_ms":%s,"observed_utc_ms":%s,"delivered_utc_ms":%s,"delivery_boundary":"%s","clock_quality":"unknown","clock_error_bound_ms":null,"latency_ms":null,"unknown_reason":"%s"}' \
    "$utc" "$id" "$cohort_json" "${PR_WAIT_EVENT_KIND:-unknown}" "${PR_WAIT_ELIGIBLE_UTC_MS:-null}" "${PR_WAIT_OBSERVED_UTC_MS:-null}" "${PR_WAIT_DELIVERED_UTC_MS:-null}" "${PR_WAIT_DELIVERY_BOUNDARY:-unknown}" "$reason")
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
    ai-blocker-watch:graphql.issue_detail:blocker_watch_tick|\
    ai-blocker-watch:graphql.open_issue_snapshot:blocker_watch_alarm|\
    ai-blocker-watch:graphql.issue_detail:blocker_watch_alarm|\
    ai-blocker-watch:graphql.open_issue_snapshot:blocker_watch_links) [ "$origin" = direct ] || return 2 ;;
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
  gh_measure_quota "${core[@]}" "${graphql[@]}" "${search[@]}" "${2:-}"
}

# No extra request and no change to the upstream resource admission semantics.
gh_measure_quota(){
  local bucket record='' context="${10:-}" context_json=null; local remaining limit reset
  [[ "$context" =~ ^v1:[0-9a-f]{64}$ ]] && context_json="\"$context\""
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
  record=$(printf '{"schema":1,"utc":"%s","principal":"%s","measurement":"server_bucket_snapshot","access_context":%s,"buckets":{%s}}' "$utc" "${GH_MEASURE_PRINCIPAL:-unknown}" "$context_json" "$record")
  printf '%s\n' "$record" > "$temp" || { rm -f -- "$temp"; return 1; }
  mv -f -- "$temp" "$dest" || { rm -f -- "$temp"; return 1; }
  gh_measure_append "$STATE/quota-measurements" "$record"
}
