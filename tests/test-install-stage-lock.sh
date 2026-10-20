#!/usr/bin/env bash
# install.sh's run_stage must keep the checkout lock (fd 9) out of every stage
# and anything a stage leaves running, such as an `op daemon` (#1783), while the
# installer shell itself keeps holding the lock.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/install-stage-lock.XXXXXX")"
trap 'kill "$(cat "$TMP/daemon.pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { if eval "$2"; then pass=$((pass+1)); printf '  ok   %s\n' "$1"; else fail=$((fail+1)); printf '  FAIL %s\n' "$1"; fi; }

# Load the real run_stage from install.sh.
eval "$(sed -n '/^run_stage() {/,/^}/p' "$ROOT/install.sh")"
info() { :; }; ok() { :; }; warn() { :; }
required_failures=(); optional_failures=(); stage_results=()
check 'run_stage closes fd 9 for stages' 'sed -n "/^run_stage() {/,/^}/p" "$ROOT/install.sh" | grep -q "\"\$@\" 9>&-"'

leave_daemon() { # a stage that, like op, leaves a background process behind
  [ -e /dev/fd/9 ] && echo open > "$TMP/stage-fd9" || echo closed > "$TMP/stage-fd9"
  ( exec sleep 30 ) >/dev/null 2>&1 &
  echo $! > "$TMP/daemon.pid"
}
failing_stage() { return 3; }

exec 9>"$TMP/lock"
flock -n 9
run_stage optional "daemon stage" leave_daemon
check 'stage ran without the lock fd' '[ "$(cat "$TMP/stage-fd9")" = closed ]'
check 'installer still holds the lock' '! flock -n "$TMP/lock" true'
check 'installer fd 9 is still open after the stage' '[ -e /dev/fd/9 ]'
run_stage optional "failing stage" failing_stage
check 'stage results still recorded' '[ "${#stage_results[@]}" = 2 ] && [ "${optional_failures[0]}" = "failing stage" ]'
exec 9>&-
check 'leftover daemon does not keep the lock once the installer exits' 'flock -n "$TMP/lock" true'
printf 'install-stage-lock: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
