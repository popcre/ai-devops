#!/usr/bin/env bash
# Classify newline-delimited repository paths for coarse CI routing.
#
# The logic now lives in tools/lib/task-gates.sh so that CI routing, local suite
# selection, and the ai-task-gates preflight share one implementation. The
# output contract of this script is unchanged.
set -uo pipefail

event="${1:-}"
[ -n "$event" ] || { printf 'usage: classify-changes.sh <event-name>\n' >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/task-gates.sh
. "$ROOT/tools/lib/task-gates.sh"

tg_legacy_classify "$event"
