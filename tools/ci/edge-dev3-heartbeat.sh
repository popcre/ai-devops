#!/usr/bin/env bash
# Runs every minute on edge-dev3 (systemd user timer edge-dev3-heartbeat.timer).
# For each repository in config/edge-dev3-runners.tsv it publishes that
# repository's edge-dev3 runner state to the repository variable
# EDGE_DEV3_RUNNER_HEARTBEAT as "<online|offline>,<idle|busy>,<unix-seconds>"
# for tools/ci/edge-dev3-route.sh. State is read locally (runner service active,
# a Runner.Worker under that runner's folder), so only writes reach the API: on
# a state change, else every REFRESH seconds. The whole host reports busy once
# MAX_WORKERS jobs run at once, so routed work spills to GitHub-hosted instead
# of piling onto one desktop. If the host dies every heartbeat goes stale and
# all jobs route to GitHub-hosted. Uses the host's own gh login; no secret
# leaves the host.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
LIST="${EDGE_DEV3_RUNNERS:-$ROOT/config/edge-dev3-runners.tsv}"
STATE_DIR="${EDGE_DEV3_STATE_DIR:-$HOME/.cache/edge-dev3-heartbeat}"
REFRESH="${EDGE_DEV3_REFRESH:-120}"
MAX_WORKERS="${EDGE_DEV3_MAX_WORKERS:-3}"
mkdir -p "$STATE_DIR"
now=$(date +%s)
workers=$(pgrep -fc '/bin/Runner.Worker' || true)
rc=0
while IFS=$'\t' read -r repo dir unit; do
  case "$repo" in ''|'#'*) continue ;; esac
  dir="${dir/#\~/$HOME}"
  if systemctl --user is-active --quiet "$unit"; then state=online; else state=offline; fi
  if [ "$state" = offline ] || pgrep -f "^$dir/bin/Runner.Worker" >/dev/null || pgrep -f "$dir/bin.*/Runner.Worker" >/dev/null || [ "${workers:-0}" -ge "$MAX_WORKERS" ]; then work=busy; else work=idle; fi
  key="$STATE_DIR/$(printf '%s' "$repo" | tr / _)"
  last="$(cat "$key" 2>/dev/null || true)"
  if [ "${last%,*}" = "$state,$work" ] && [ $(( now - ${last##*,} )) -lt "$REFRESH" ]; then continue; fi
  if gh variable set EDGE_DEV3_RUNNER_HEARTBEAT -R "$repo" --body "$state,$work,$now" >/dev/null 2>&1; then
    printf '%s,%s,%s' "$state" "$work" "$now" > "$key"
  else
    printf 'heartbeat write failed for %s\n' "$repo" >&2; rc=1
  fi
done < "$LIST"
exit "$rc"
