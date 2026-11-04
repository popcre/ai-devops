#!/usr/bin/env bash
# Picks a job's runner for .github/workflows/edge-dev3-route.yml (owner request
# 2026-11-03: every repository's CI runs on edge-dev3 first and free
# GitHub-hosted runners as fallback, so nothing waits on one machine).
#
# Prints a JSON runs-on value. It is the self-hosted label list only when the
# calling repository's edge-dev3 runner is proven online and idle by a fresh
# heartbeat ("<online|offline>,<idle|busy>,<unix-seconds>", written by
# tools/ci/edge-dev3-heartbeat.sh on the host). Every other outcome - fork pull
# request, pull_request_target, missing, malformed or stale heartbeat, busy or
# offline runner, bad labels - prints the hosted fallback. It never exits
# non-zero for a routing reason.
#
# Inputs (environment): EVENT_NAME, HEAD_REPO, REPOSITORY, HEARTBEAT,
# FALLBACK (default ubuntu-24.04), SELF_HOSTED (JSON array), NOW (optional).
set -uo pipefail
MAX_AGE=330
fallback="${FALLBACK:-ubuntu-24.04}"
labels="${SELF_HOSTED:-[\"self-hosted\",\"Linux\",\"X64\",\"ai-devops-linux\"]}"
now="${NOW:-$(date +%s)}"
hosted() { printf '%s\n' "$(jq -cn --arg l "$fallback" '$l')"; printf 'reason: %s\n' "$1" >&2; exit 0; }

case "${EVENT_NAME:-}" in
  pull_request_target) hosted 'pull_request_target never routes to self-hosted' ;;
  pull_request) [ "${HEAD_REPO:-}" = "${REPOSITORY:-x}" ] || hosted 'fork pull request never routes to self-hosted' ;;
esac
if ! [[ "${HEARTBEAT:-}" =~ ^(online|offline),(idle|busy),([0-9]{9,11})$ ]]; then hosted 'no valid runner heartbeat'; fi
state="${BASH_REMATCH[1]}"; work="${BASH_REMATCH[2]}"; stamp="${BASH_REMATCH[3]}"
age=$(( now - stamp ))
{ [ "$age" -le "$MAX_AGE" ] && [ "$age" -ge -60 ]; } || hosted "heartbeat is stale (${age}s old)"
[ "$state" = online ] || hosted 'runner offline'
[ "$work" = idle ] || hosted 'runner busy'
out="$(jq -c 'if type == "array" and length > 0 and all(.[]; type == "string") and (index("self-hosted") != null) then . else error("bad") end' <<<"$labels" 2>/dev/null)" || hosted 'self-hosted labels are not a valid array'
printf '%s\n' "$out"
printf 'reason: runner online and idle (heartbeat %ss old)\n' "$age" >&2
