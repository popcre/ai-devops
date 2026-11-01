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
    ai-reviewer-membership-drift|ai-devops-doctor|ai-devops-installer|ai-task-gates|review-fixer|interactive)
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
    # Never date's three-digit fraction: uutils coreutils 0.10 drops its leading zeros.
    stamp=$(date +%s%N)
    if [[ "$stamp" =~ ^[0-9]{19}$ ]]; then GH_MEASURE_CLOCK=$(( 10#$stamp / 1000000 ))
    else GH_MEASURE_CLOCK=$(( $(date +%s) * 1000 )); fi
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
    # MSYS/Git Bash/Cygwin expose the same /proc/uptime centisecond BOOTTIME
    # interface as Linux (GetTickCount64-based, monotonic).  Accept every
    # POSIX-procfs platform so Windows waiters get real duration rows instead
    # of clock_unknown on every observation.
    case "$(uname -s 2>/dev/null || true)" in
      Linux|MINGW*|MSYS*|CYGWIN*) GH_MEASURE_LOCAL_PLATFORM=posix_procfs ;;
    esac
  fi
  [ "$GH_MEASURE_LOCAL_PLATFORM" = posix_procfs ] || return 0
  local uptime
  IFS=' ' read -r uptime _ < /proc/uptime 2>/dev/null || return 0
  gh_measure_local_clock_parse "$uptime"
}

gh_measure_local_observation(){
  local id="${1:-}" outcome="${2:-}" start="${3:-}" end="${4:-}" basis="${5:-unknown}" output_failed="${6:-1}" utc record reason=clock_unknown acceptance=unknown lower=null upper=null error=null start_json=null end_json=null
  case "$outcome" in merged|closed|checks_failed|ejected|deadline) ;; *) return 2 ;; esac
  [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 2
  if [ "$output_failed" = 1 ]; then
    reason=delivery_unknown
  elif [ "$basis" = linux_boottime_centiseconds ] && [[ "$start" =~ ^(0|[1-9][0-9]{0,12})$ ]] && [[ "$end" =~ ^(0|[1-9][0-9]{0,12})$ ]]; then
    start_json="$start"; end_json="$end"
    if [ "$end" -lt "$start" ]; then
      reason=clock_negative
      start_json=null; end_json=null
    else
      local elapsed=$((end - start))
      if [ "$elapsed" -le 604800000 ]; then
        lower=$((elapsed - 20)); [ "$lower" -lt 0 ] && lower=0
        upper=$((elapsed + 20)); error=20
        # A supported monotonic clock that produced a non-negative bounded
        # interval qualifies the duration.  Source verification stays a
        # separate axis and is genuinely unknown here.
        reason=source_unknown
        acceptance=qualified
      else
        reason=clock_negative
        start_json=null; end_json=null
      fi
    fi
  fi
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":5,"utc":"%s","measurement":"local_workflow_observation","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"%s","outcome":"%s","boundary":"receipt_init_to_terminal_output","clock_basis":"%s","start_monotonic_ms":%s,"end_monotonic_ms":%s,"duration_lower_ms":%s,"duration_upper_ms":%s,"clock_error_bound_ms":%s,"source_verified":"unknown","acceptance":"%s","unknown_reason":"%s"}' \
    "$utc" "$id" "$outcome" "$basis" "$start_json" "$end_json" "$lower" "$upper" "$error" "$acceptance" "$reason")
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

gh_measure_active_channel(){
  local phase="$1" record="$2" helper="${BASH_SOURCE[0]%/*}/report.py" python="${AI_GH_ACTIVE_PYTHON:-}"
  { [[ "${AI_GH_ACTIVE_EVENT_FD:-}" =~ ^[0-9]{1,5}$ && "${AI_GH_ACTIVE_ACK_FD:-}" =~ ^[0-9]{1,5}$ ]] ||
    [[ "${AI_GH_ACTIVE_EVENT_HANDLE:-}" =~ ^[0-9]{1,20}$ && "${AI_GH_ACTIVE_ACK_HANDLE:-}" =~ ^[0-9]{1,20}$ ]]; } || return 2
  [ -n "$python" ] && [ -f "$helper" ] || return 2
  printf '%s' "$record" | "$python" -I -S -c \
    'import os,runpy,sys; p=sys.argv.pop(1); sys.path.insert(0,os.path.dirname(p)); runpy.run_path(p,run_name="__main__")' \
    "$helper" --active-channel "$phase" 2>/dev/null
}

gh_measure_active_begin(){
  local workflow="$1" id="$2" parent="$3" boundary="$4" record
  [ "${GH_MEASURE_ACTIVE_DISABLED:-0}" != 1 ] || return 2
  [ -z "$parent" ] && parent=null || parent="\"$parent\""
  record=$(printf '{"schema":1,"measurement":"active_completion_boundary","phase":"begin","caller":"ai-blocker-watch","workflow":"%s","workflow_id":"%s","parent_workflow_id":%s,"boundary":"%s"}' "$workflow" "$id" "$parent" "$boundary")
  gh_measure_active_channel begin "$record"
}

gh_measure_active_harness(){
  local helper="${BASH_SOURCE[0]%/*}/report.py" executable
  executable="$(command -v "$1")" || { "$@"; return "$?"; }
  shift
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) executable="$(cygpath -w "$executable")" || return 127 ;; esac
  printf '%s\0' "$executable" "$@" | "${AI_GH_ACTIVE_PYTHON}" -I -S -c \
    'import os,runpy,sys; p=sys.argv.pop(1); sys.path.insert(0,os.path.dirname(p)); runpy.run_path(p,run_name="__main__")' \
    "$helper" --active-harness
}

gh_measure_workflow_outcome(){
  local caller="${1:-}" workflow="${2:-}" id="${3:-}" outcome="${4:-}" elapsed="${5:-}" utc record
  local boundary="${6:-}" attempted="${7:-}" succeeded="${8:-}" failed="${9:-}" skipped="${10:-}" parent="${11:-}" extended=0 number
  case "$caller:$workflow:$outcome" in
    ai-pr-wait:pr_wait:merged|ai-pr-wait:pr_wait:closed|\
    ai-pr-wait:pr_wait:checks_failed|ai-pr-wait:pr_wait:ejected|\
    ai-pr-wait:pr_wait:deadline|ai-blocker-watch:blocker_watch_tick:completed) ;;
    ai-blocker-watch:blocker_watch_alarm:completed|ai-blocker-watch:blocker_watch_alarm:partial|ai-blocker-watch:blocker_watch_alarm:failed|ai-blocker-watch:blocker_watch_alarm:skipped|\
    ai-blocker-watch:blocker_watch_links:completed|ai-blocker-watch:blocker_watch_links:partial|ai-blocker-watch:blocker_watch_links:failed|ai-blocker-watch:blocker_watch_links:skipped|\
    ai-blocker-watch:blocker_watch_wake:process_succeeded|ai-blocker-watch:blocker_watch_wake:process_failed|ai-blocker-watch:blocker_watch_wake:refused|ai-blocker-watch:blocker_watch_wake:skipped) extended=1 ;;
    ai-verify-run:verify_dispatch:dispatched|ai-verify-run:verify_dispatch:duplicate_refused|ai-verify-run:verify_dispatch:failed|\
    ai-verify-run:verify_status:completed|ai-verify-run:verify_status:failed|\
    ai-verify-run:verify_cancel:cancel_requested|ai-verify-run:verify_cancel:refused|ai-verify-run:verify_cancel:failed|\
    ai-transcript-destination-check:transcript_privacy:verified|ai-transcript-destination-check:transcript_privacy:refused|\
    ai-transcript-destination-check:transcript_privacy:failed|ai-transcript-destination-check:transcript_privacy:skipped) ;;
    *) return 2 ;;
  esac
  [[ "$id" =~ ^[0-9a-f]{32}$ && "$elapsed" =~ ^[0-9]{1,9}$ ]] || return 2
  [ "$elapsed" -le 604800000 ] || return 2
  if [ "$extended" = 1 ]; then
    [ "$#" = 11 ] || return 2
    case "$workflow:$boundary" in blocker_watch_alarm:alarm_scan|blocker_watch_links:links_scan|blocker_watch_wake:wake_process_exit) ;; *) return 2 ;; esac
    for number in "$attempted" "$succeeded" "$failed" "$skipped"; do
      [[ "$number" =~ ^(0|[1-9][0-9]{0,8})$ ]] || return 2
    done
    [ "$((succeeded + failed))" -le "$attempted" ] || return 2
    [[ -z "$parent" || "$parent" =~ ^[0-9a-f]{32}$ ]] || return 2
    [ "$id" != "$parent" ] || return 2
    case "$outcome" in
      completed|process_succeeded) [ "$attempted" -gt 0 ] && [ "$succeeded" -gt 0 ] && [ "$failed" = 0 ] || return 2 ;;
      partial) [ "$succeeded" -gt 0 ] || return 2 ;;
      skipped|refused) [ "$succeeded" = 0 ] || return 2 ;;
    esac
  else
    [ "$#" = 5 ] || return 2
  fi
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":3,"utc":"%s","measurement":"workflow_outcome","caller":"%s","workflow":"%s","workflow_id":"%s","outcome":"%s","elapsed_ms":%s}' \
    "$utc" "$caller" "$workflow" "$id" "$outcome" "$elapsed")
  if [ "$extended" = 1 ]; then
    [ -z "$parent" ] && parent=null || parent="\"$parent\""
    record="${record%\}},\"boundary\":\"$boundary\",\"attempted_count\":$attempted,\"succeeded_count\":$succeeded,\"failed_count\":$failed,\"skipped_count\":$skipped,\"parent_workflow_id\":$parent}"
  fi
  if [ "$caller" = ai-blocker-watch ] &&
    { [ "${BW_ACTIVE_OBSERVER_READY:-0}" = 1 ] || [ "$workflow" = blocker_watch_tick ]; }; then
    gh_measure_active_channel end "$record" || :
  fi
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
  # An explicit qualification parent may consume this *unqualified* event.
  # A caller-supplied descriptor never grants source or clock authority.
  local event_python="${PYTHON_RUNNER:-}" event_helper='' event_windows=0
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) event_windows=1 ;; esac
  if [ "$event_windows" = 1 ] && [[ "${AI_GH_QUALIFICATION_EVENT_HANDLE:-}" =~ ^[0-9]{1,20}$ ]]; then
    # This is data only. The native writer verifies a bounded nonblocking
    # message pipe; neither this handle nor its environment grants authority.
    event_helper="${BASH_SOURCE[0]%/*}/windows_event.py"
    [ -n "$event_python" ] || event_python="$(command -v python3 || command -v python || true)"
    if [ -n "$event_python" ] && [ -f "$event_helper" ]; then
      printf '%s\n' "$record" | "$event_python" "$event_helper" 2>/dev/null || :
    fi
  elif [[ "${AI_GH_QUALIFICATION_EVENT_FD:-}" =~ ^[0-9]{1,5}$ ]] &&
    [ "$AI_GH_QUALIFICATION_EVENT_FD" -ge 3 ] && [ -p "/proc/self/fd/$AI_GH_QUALIFICATION_EVENT_FD" ]; then
    event_helper="${BASH_SOURCE[0]%/*}/measure_append.py"
    [ -n "$event_python" ] || event_python="$(command -v python3 || command -v python || true)"
    if [ -n "$event_python" ] && [ -f "$event_helper" ]; then
      printf '%s' "$record" | "$event_python" "$event_helper" --event-fd "$AI_GH_QUALIFICATION_EVENT_FD" 2>/dev/null || :
    fi
  fi
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
}

# Separate ordinary BlockerWatch facts. Deliberately durable-only: neither the
# PR event pipe nor the governed completion channel accepts this policy.
gh_measure_blocker_evidence(){
  [ "$#" = 7 ] || return 2
  local workflow="$1" id="$2" event="$3" eligible="$4" observed="$5" delivered="$6" boundary="$7" number utc record reason=source_unknown
  [[ "$id" =~ ^[0-9a-f]{32}$ ]] || return 2
  case "$workflow:$event" in
    blocker_watch_wake:blocker_closed|blocker_watch_wake:timer_due|blocker_watch_wake:unknown|\
    blocker_watch_alarm:alarm_stale|blocker_watch_alarm:unknown|blocker_watch_links:unknown) ;;
    *) return 2 ;;
  esac
  case "$workflow:$boundary" in
    blocker_watch_wake:wake_command_returned|blocker_watch_alarm:alarm_batch_acknowledged|\
    blocker_watch_links:links_batch_acknowledged|*:unknown) ;;
    *) return 2 ;;
  esac
  for number in "$eligible" "$observed" "$delivered"; do
    [[ -z "$number" || "$number" =~ ^(0|[1-9][0-9]{0,12})$ ]] || return 2
  done
  [ "$event" != unknown ] || [ -z "$eligible" ] || return 2
  [ "$event" = unknown ] || [ -n "$observed" ] || return 2
  [ "$event" != alarm_stale ] || [ -n "$eligible" ] || return 2
  if [ "$boundary" = unknown ]; then [ -z "$delivered" ] || return 2
  else [ -n "$observed" ] && [ -n "$delivered" ] || return 2; fi
  if [ -n "$observed" ] && { { [ -n "$eligible" ] && [ "$eligible" -gt "$observed" ]; } ||
       { [ -n "$delivered" ] && [ "$delivered" -lt "$observed" ]; }; }; then reason=clock_unknown; fi
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":4,"utc":"%s","measurement":"workflow_evidence","caller":"ai-blocker-watch","workflow":"%s","workflow_id":"%s","cohort_id":null,"target_ordinal":null,"source_verified":"unknown","source_fingerprint_start":null,"source_fingerprint_end":null,"install_generation_binding":null,"event_kind":"%s","eligible_utc_ms":%s,"observed_utc_ms":%s,"delivered_utc_ms":%s,"delivery_boundary":"%s","clock_quality":"unknown","clock_error_bound_ms":null,"latency_ms":null,"unknown_reason":"%s"}' \
    "$utc" "$workflow" "$id" "$event" "${eligible:-null}" "${observed:-null}" "${delivered:-null}" "$boundary" "$reason")
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

# Count a completed local read of a correlated target. Cache hits are saved
# upstream reads; the report denominates them by same-target replays.
gh_measure_read_observation(){
  local caller="${1:-}" workflow="${2:-}" ordinal="${3:-}" source="${4:-}" utc record cache_hit=false saved=false
  case "$caller" in ai-pr-wait|ai-merge-group-evidence|ai-blocker-watch|ai-gh-wait) ;; *) return 2 ;; esac
  case "$workflow" in pr_wait|blocker_watch_tick|blocker_watch_alarm|blocker_watch_links|blocker_watch_wake|merge_group_evidence) ;; *) return 2 ;; esac
  case "$source" in cache) cache_hit=true; saved=true ;; upstream) ;; *) return 2 ;; esac
  [ -z "$ordinal" ] || [[ "$ordinal" =~ ^[0-9]{1,10}$ ]] || return 2
  local ordinal_json=null
  [ -z "$ordinal" ] || ordinal_json="$ordinal"
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":6,"utc":"%s","measurement":"read_observation","caller":"%s","workflow":"%s","target_ordinal":%s,"source":"%s","cache_hit":%s,"saved_upstream_read":%s}' \
    "$utc" "$caller" "$workflow" "$ordinal_json" "$source" "$cache_hit" "$saved")
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
}

# Count a managed write attempt and whether its content was already present.
# duplicate_unchanged_write must stay zero for section 13 item 2.
gh_measure_write_observation(){
  local caller="${1:-}" workflow="${2:-}" ordinal="${3:-}" action="${4:-}" relation="${5:-}" utc record dup=false
  case "$caller" in ai-pr-wait|ai-merge-group-evidence|ai-blocker-watch|ai-gh-wait) ;; *) return 2 ;; esac
  case "$workflow" in pr_wait|blocker_watch_tick|blocker_watch_alarm|blocker_watch_links|blocker_watch_wake|merge_group_evidence) ;; *) return 2 ;; esac
  case "$action" in written|skipped) ;; *) return 2 ;; esac
  case "$relation" in new|unchanged|unknown) ;; *) return 2 ;; esac
  if [ "$action" = written ] && [ "$relation" = unchanged ]; then dup=true; fi
  [ -z "$ordinal" ] || [[ "$ordinal" =~ ^[0-9]{1,10}$ ]] || return 2
  local ordinal_json=null
  [ -z "$ordinal" ] || ordinal_json="$ordinal"
  TZ=UTC printf -v utc '%(%FT%TZ)T' -1
  record=$(printf '{"schema":6,"utc":"%s","measurement":"write_observation","caller":"%s","workflow":"%s","target_ordinal":%s,"action":"%s","content_relation":"%s","duplicate_unchanged_write":%s}' \
    "$utc" "$caller" "$workflow" "$ordinal_json" "$action" "$relation" "$dup")
  gh_measure_append "${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}/measurements" "$record"
}

# Resolve a local target ordinal through the reviewed-shaped correlation
# adapter. Missing adapter or private state yields empty (uncorrelated), never
# an invented ordinal.
gh_measure_target_ordinal(){
  GH_MEASURE_TARGET_ORDINAL=''
  local key="${1:-}" helper python result state
  [ -n "$key" ] || return 0
  helper="${BASH_SOURCE[0]%/*}/target_ordinal.py"
  python="${PYTHON_RUNNER:-}"
  [ -n "$python" ] || python="$(command -v python3 || command -v python || true)"
  [ -n "$python" ] && [ -f "$helper" ] || return 0
  state="${AI_GH_STATE_DIR:-$HOME/.ai-devops/gh-throttle}"
  result="$("$python" "$helper" --state-dir "$state" --key "$key" 2>/dev/null)" || return 0
  [[ "$result" =~ ^[0-9]{1,10}$ ]] || return 0
  GH_MEASURE_TARGET_ORDINAL="$result"
}

# Both command records and server snapshots share the same filesystem boundary.
gh_measure_append(){
  local dir="$1" record="$2" file count
  # Completion must not hold up other callers. Use an independent lock with
  # a short bounded retry (<= ~0.5s): writers hold it for milliseconds, so two
  # callers finishing together both record; longer contention is a visible
  # missing sample.
  [ ! -L "$dir" ] || return 1
  ( umask 077; mkdir -p "$dir" ) || return 1
  local tries=0 locked=0
  while [ "$tries" -lt 50 ]; do
    if mkdir "$dir/write.lock" 2>/dev/null; then locked=1; break; fi
    tries=$(( tries + 1 )); sleep 0.01
  done
  if [ "$locked" -eq 0 ]; then
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
