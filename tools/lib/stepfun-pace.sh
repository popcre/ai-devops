# stepfun-pace.sh — one client-side request pacer for every StepFun turn.
#
# Sourced by bin/ai-stepfun and the shared-runner door
# tools/lib/review-doors/stepfun.sh. StepFun's account tier allows about 10
# requests a minute (HTTP 429 rate_limited). Without a pacer, concurrent runs
# start together, one hits 429, and the whole turn is rerun cold after a fixed
# pause, paying for every token again (#1432). The pacer instead waits BEFORE a
# turn starts: it keeps a sliding one-minute log of turn starts shared by every
# StepFun run of this user, and a cooldown that a 429 sets for everyone.
# It never limits how many turns or steps a run may take; it only spaces them.
#
# State (owner-only): <state dir>/pace/{starts,cooldown,lock}.

STEPFUN_PACE_RPM="${AI_STEPFUN_RPM:-10}"
STEPFUN_PACE_WINDOW="${AI_STEPFUN_PACE_WINDOW:-60}"

_stepfun_pace_dir(){ printf '%s/pace' "${1:-${AI_STEPFUN_STATE_DIR:-$HOME/.local/state/ai-devops/stepfun}}"; }

# _stepfun_pace_slot DIR: one locked decision. Prints 0 and records the start
# when a slot is free now; otherwise prints the seconds to wait.
_stepfun_pace_slot(){
  local d="$1" now cool=0 oldest count
  now="$(date +%s)"
  [ ! -s "$d/cooldown" ] || IFS= read -r cool < "$d/cooldown" || true
  [[ "$cool" =~ ^[0-9]+$ ]] || cool=0
  if [ "$now" -lt "$cool" ]; then printf '%s' "$((cool - now))"; return 0; fi
  touch "$d/starts"
  awk -v min="$((now - STEPFUN_PACE_WINDOW))" '$1 ~ /^[0-9]+$/ && $1 > min' "$d/starts" > "$d/starts.new" && mv -f "$d/starts.new" "$d/starts"
  count="$(wc -l < "$d/starts" | tr -d ' ')"
  if [ "$count" -lt "$STEPFUN_PACE_RPM" ]; then
    printf '%s\n' "$now" >> "$d/starts"; printf 0; return 0
  fi
  oldest="$(head -n1 "$d/starts")"
  printf '%s' "$(( oldest + STEPFUN_PACE_WINDOW - now > 0 ? oldest + STEPFUN_PACE_WINDOW - now : 1 ))"
}

# stepfun_pace_wait [STATE_DIR]: blocks until this turn may start, then
# records it. Every wait is announced on stderr. A pacer fault never blocks a
# review: it is reported and the turn starts.
stepfun_pace_wait(){
  local d wait
  d="$(_stepfun_pace_dir "${1:-}")"
  mkdir -p "$d" 2>/dev/null && chmod 700 "$d" 2>/dev/null || { printf 'stepfun pace: state dir unavailable; starting unpaced\n' >&2; return 0; }
  while :; do
    if command -v flock >/dev/null 2>&1; then
      wait="$( { flock -w 600 9 || exit 1; _stepfun_pace_slot "$d"; } 9>"$d/lock" )" || wait=""
    else
      wait="$(_stepfun_pace_slot "$d")" || wait=""
    fi
    [[ "$wait" =~ ^[0-9]+$ ]] || { printf 'stepfun pace: pacer error; starting unpaced\n' >&2; return 0; }
    [ "$wait" -gt 0 ] || return 0
    printf 'stepfun pace: waiting %ss for a StepFun request slot (limit %s per %ss)\n' "$wait" "$STEPFUN_PACE_RPM" "$STEPFUN_PACE_WINDOW" >&2
    sleep "$wait"
  done
}

# stepfun_pace_cooldown SECONDS [STATE_DIR]: after an HTTP 429, every StepFun
# run of this user waits SECONDS before its next turn starts.
stepfun_pace_cooldown(){
  local secs="${1:-0}" d until cur=0
  [[ "$secs" =~ ^[0-9]+$ ]] && [ "$secs" -gt 0 ] || return 0
  d="$(_stepfun_pace_dir "${2:-}")"; mkdir -p "$d" 2>/dev/null || return 0
  until="$(( $(date +%s) + secs ))"
  [ ! -s "$d/cooldown" ] || IFS= read -r cur < "$d/cooldown" || true
  [[ "$cur" =~ ^[0-9]+$ ]] && [ "$cur" -ge "$until" ] || printf '%s\n' "$until" > "$d/cooldown"
}
