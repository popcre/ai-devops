# local-watch.sh — shared helpers for watchdog duty-pool timed tasks.
# Sourced by bin/ai-local-watch and each thin watchdog tool.
#
# Provides: note, die, stamp, lower, rotate_log, take_lock, unlock,
#           register_timer, unregister_timer (Task Scheduler / crontab).
# Callers set: TOOL_NAME, HOME_DIR, CONFIG, and optionally TASK_NAME,
# CRON_MARKER, and a cmd_tick function.
#
# See docs/watchdog-duty-pool.md and plan_watchdog-local-timed-tasks.md.

# shellcheck shell=bash

note(){ printf '%s: %s\n' "${TOOL_NAME:-local-watch}" "$*" >&2; }
die(){ note "$*"; exit 1; }
stamp(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
lower(){ tr '[:upper:]' '[:lower:]'; }

rotate_log(){
  local log="$1" max
  max="${2:-5000000}"
  [ -f "$log" ] || return 0
  [ "$(wc -c < "$log")" -le "$max" ] || mv -f "$log" "$log.1"
}

# take_lock [lock_dir] [stale_minutes]
take_lock(){
  local lock="${1:-$HOME_DIR/tick.lock}" stale="${2:-20}"
  mkdir -p "$(dirname "$lock")"
  if ! mkdir "$lock" 2>/dev/null; then
    [ -n "$(find "$lock" -maxdepth 0 -mmin "+$stale" 2>/dev/null)" ] \
      || die "another tick is still running (lock $lock)"
    note "breaking a lock older than $stale minutes"
    rm -rf "$lock"; mkdir "$lock"
  fi
  # shellcheck disable=SC2064
  trap "rm -rf '$lock'" EXIT
}

unlock(){
  local lock="${1:-$HOME_DIR/tick.lock}"
  rm -rf "$lock"
  trap - EXIT
}

# register_timer <every_minutes> <command...>
# Windows: Task Scheduler under \ai-devops\<TOOL_NAME>.
# Linux/macOS: one marked user-crontab block. Idempotent (/F / re-write).
register_timer(){
  local every="$1"; shift
  local task="${TASK_NAME:-ai-devops\\$TOOL_NAME}"
  local marker="${CRON_MARKER:-# ai-devops $TOOL_NAME (managed by $TOOL_NAME schedule; unschedule removes)}"
  mkdir -p "$HOME_DIR"
  if command -v schtasks.exe >/dev/null 2>&1; then
    local bash_exe self
    bash_exe="$(cygpath -w "$(command -v bash)")"
    self="$(cygpath -m "$1")"; shift
    local args_ quoted=""
    for args_ in "$@"; do quoted="$quoted \\\"$args_\\\""; done
    MSYS2_ARG_CONV_EXCL='*' schtasks.exe /Create /F /SC MINUTE /MO "$every" /TN "$task" \
      /TR "conhost.exe --headless \"$bash_exe\" -lc \"'$self'$quoted >> $HOME_DIR/cron.log 2>&1\"" >/dev/null \
      || die "schtasks refused $task"
    note "scheduled every $every minutes as $task"
    return 0
  fi
  command -v crontab >/dev/null || die "schedule needs schtasks (Windows) or crontab (Linux/macOS)"
  local tmp cmd_line
  cmd_line=""
  for args_ in "$@"; do cmd_line="$cmd_line '$args_'"; done
  tmp="$(mktemp)"
  { crontab -l 2>/dev/null | grep -vF "$marker" | grep -vF "'$1'" || :; } >> "$tmp"
  printf '%s\n*/%s * * * * %s >> %s 2>&1\n' "$marker" "$every" "$cmd_line" "'$HOME_DIR/cron.log'" >> "$tmp"
  local rc=0; crontab "$tmp" || rc=$?; rm -f "$tmp"
  [ "$rc" -eq 0 ] || die "crontab refused the $TOOL_NAME entry"
  note "scheduled every $every minutes in the user crontab"
}

unregister_timer(){
  local task="${TASK_NAME:-ai-devops\\$TOOL_NAME}"
  local marker="${CRON_MARKER:-# ai-devops $TOOL_NAME (managed by $TOOL_NAME schedule; unschedule removes)}"
  if command -v schtasks.exe >/dev/null 2>&1; then
    MSYS2_ARG_CONV_EXCL='*' schtasks.exe /Delete /F /TN "$task" >/dev/null 2>&1 || true
    note "removed $task"
    return 0
  fi
  command -v crontab >/dev/null || die "unschedule needs schtasks (Windows) or crontab"
  local tmp
  tmp="$(mktemp)"
  { crontab -l 2>/dev/null | grep -vF "$marker" || :; } > "$tmp"
  local rc=0; crontab "$tmp" || rc=$?; rm -f "$tmp"
  [ "$rc" -eq 0 ] || die "crontab refused the removal"
  note "removed the $TOOL_NAME crontab entry"
}
