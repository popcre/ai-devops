# shellcheck shell=bash
# session-tmp.sh — one session-owned temp root per AI session (plan_session-temp-cleanup.md).
#
# Every AI session gets its own folder under $AI_SESSION_TMP_BASE (default
# /var/tmp/ai-sessions-<uid>, private to the user), exported as TMPDIR/TMP/TEMP to the session and all its
# children, and the session that made the folder deletes it when it ends.
# bin/ai-session-tmp-sweep is only the crash backup.
#
#   ai_session_tmp_begin <engine> <session-id> [owner-pid]
#   ai_session_tmp_end
#   ai_session_tmp_wrap <engine> [ignored...]          # wrapper entry point (exit watcher)
#
# Linux only for now; on other systems begin/wrap are no-ops. AI_SESSION_TMP=0
# disables it; AI_KEEP_SANDBOX=1 keeps the root and prints its path.

ai_session_tmp_base() { printf '%s\n' "${AI_SESSION_TMP_BASE:-/var/tmp/ai-sessions-$(id -u)}"; }

ai_session_tmp_enabled() {
  [ "${AI_SESSION_TMP:-1}" != 0 ] || return 1
  [ -n "${AI_SESSION_TMP_FORCE:-}" ] && return 0
  [ "$(uname -s 2>/dev/null)" = Linux ]
}

# Sanitize an engine or session id into the allowed name alphabet.
ai_session_tmp_slug() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | cut -c1-80
}

# Guard: succeed only for a real (non-symlink) directory that is exactly one
# level below the base and whose name uses the allowed alphabet.
ai_session_tmp_is_safe_root() {
  local root="$1" base name
  base="$(ai_session_tmp_base)"
  case "$base" in /|/var|/var/tmp|/tmp|"") return 1 ;; /*) ;; *) return 1 ;; esac
  case "$root" in */../*|*/..|*/./*|*/.) return 1 ;; esac
  [ "${root%/*}" = "$base" ] || return 1
  name="${root##*/}"
  [[ "$name" =~ ^[a-z0-9-]+$ ]] || return 1
  [ ! -L "$root" ] && [ ! -L "$base" ] || return 1
  return 0
}

# (Re)write owner.json so the sweeper's proof of life names the current owner.
ai_session_tmp_write_owner() {
  local root="$1" engine="$2" sid="$3" pid="$4" start
  start="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
  printf '{"pid":%s,"pid_start_ticks":"%s","engine":"%s","session_id":"%s","started_utc":"%s","started_epoch":%s,"cwd":"%s"}\n' \
    "$pid" "$start" "$engine" "$sid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)" \
    "$(pwd | sed 's/\\/\\\\/g; s/"/\\"/g')" > "$root/owner.json.$$" && mv -f "$root/owner.json.$$" "$root/owner.json"
}

ai_session_tmp_begin() {
  ai_session_tmp_enabled || return 0
  local engine sid pid base root start
  engine="$(ai_session_tmp_slug "${1:-session}")"; [ -n "$engine" ] || engine=session
  sid="$(ai_session_tmp_slug "${2:-$$-$(date +%s)}")"; [ -n "$sid" ] || sid="$$"
  pid="${3:-$$}"
  base="$(ai_session_tmp_base)"
  root="$base/$engine-$sid"
  ai_session_tmp_is_safe_root "$root" || { echo "session-tmp: refusing unsafe root $root" >&2; return 1; }
  # One private base per user: a user-owned world-writable parent would let
  # another account rename roots (and private-directory checks reject it).
  [ -d "$base" ] || (umask 077 && mkdir -p "$base") 2>/dev/null
  [ -d "$base" ] && [ ! -L "$base" ] && [ -O "$base" ] || { echo "session-tmp: cannot use $base" >&2; return 1; }
  if ! (umask 077 && mkdir "$root") 2>/dev/null; then
    # An id collision with a live root must not share it: add a unique suffix.
    root="$base/$engine-$sid-$$-${RANDOM}"
    (umask 077 && mkdir "$root") || { echo "session-tmp: cannot create $root" >&2; return 1; }
  fi
  ai_session_tmp_write_owner "$root" "$engine" "$sid" "$pid"
  AI_SESSION_TMP_ROOT="$root"
  export AI_SESSION_TMP_ROOT TMPDIR="$root" TMP="$root" TEMP="$root"
}

ai_session_tmp_end() {
  local root="${AI_SESSION_TMP_ROOT:-}"
  [ -n "$root" ] || return 0
  if [ "${AI_KEEP_SANDBOX:-0}" = 1 ]; then
    echo "session-tmp: kept $root (AI_KEEP_SANDBOX=1)" >&2
    return 0
  fi
  if ! ai_session_tmp_is_safe_root "$root"; then
    echo "session-tmp: refusing to remove unsafe root $root" >&2
    return 1
  fi
  rm -rf -- "$root"
  unset AI_SESSION_TMP_ROOT
}

# Wrapper entry point: create the root for the calling process ($$) and start
# a detached watcher that deletes the root the moment that process exits, even
# on kill -9. The wrapper keeps its own PID, traps, stdin and stdout untouched.
# A caller that already chose a temp folder (an outer AI session, a test, an
# operator) keeps it: that owner cleans it up, and evidence a wrapper retains
# there on failure survives the wrapper's exit.
ai_session_tmp_wrap() {
  local engine="$1"
  ai_session_tmp_enabled || return 0
  [ -z "${TMPDIR:-}" ] || return 0
  ai_session_tmp_begin "$engine" "$$-$(date +%s)" "$$" || return 0
  ai_session_tmp_watch "$$" "$AI_SESSION_TMP_ROOT"
}

ai_session_tmp_watch() {
  local pid="$1" root="$2" lib
  lib="${BASH_SOURCE[0]}"
  local launcher=(setsid -f)
  command -v setsid >/dev/null 2>&1 || launcher=(nohup)
  "${launcher[@]}" bash -c '
    . "$1"
    if command -v tail >/dev/null 2>&1 && tail --pid="$2" -f /dev/null 2>/dev/null; then :
    else while kill -0 "$2" 2>/dev/null; do sleep 2; done; fi
    AI_SESSION_TMP_ROOT="$3" ai_session_tmp_end
  ' _ "$lib" "$pid" "$root" </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}
