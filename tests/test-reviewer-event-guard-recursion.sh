#!/usr/bin/env bash
# Regression: a recorded wrapper must never re-launch itself without end.
# edge-dev3, 2026-10-07: ~9,100 nested `ai-claude-review doctor --live`
# processes, each the child of the last. The guard trusted PPID to recognise
# its own child; a launcher that forks instead of exec'ing breaks that match.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$ROOT/tests/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'pkill -KILL -f "$TMP/" 2>/dev/null; rm -rf "$TMP"' EXIT
check(){ if bash -c "$2"; then ok "$1"; else bad "$1"; fi; }

mkdir -p "$TMP/bin" "$TMP/root/bin"; ln -s "$ROOT/tools" "$TMP/root/tools"
# An `env` that forks a child instead of exec'ing: the wrapper's PPID is the
# shim, not the recorder, exactly the shape that defeated the PPID check.
REAL_ENV="$(command -v env)"
cat > "$TMP/bin/env" <<SHIM
#!/bin/bash
"$REAL_ENV" "\$@"
exit \$?
SHIM
chmod +x "$TMP/bin/env"
# A minimal wrapper with the same guard entry as bin/ai-claude-review.
cat > "$TMP/root/bin/ai-fake-review" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _AI_EVENT_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
  source "$(dirname "$_AI_EVENT_SELF")/../tools/reviewer_event_guard.sh"
  reviewer_event_guard claude "$_AI_EVENT_SELF" "$@"
  unset _AI_EVENT_SELF
fi
printf 'x\n' >> "$RUNS"
[ -z "${AI_REVIEW_EVENT_REENTRY:-}" ] || { echo 'token leaked to wrapper' >&2; exit 9; }
echo "PASS live=verified"
WRAP
chmod +x "$TMP/root/bin/ai-fake-review"

run(){ (cd "$TMP" && RUNS="$TMP/runs" AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_PRIVACY_BASE="$TMP/privacy" \
  PATH="$TMP/bin:$PATH" timeout -s KILL 30 "$@" "$TMP/root/bin/ai-fake-review" doctor --live); }

echo '== reviewer event guard recursion'
OUT="$(run 2>"$TMP/err")"; RC=$?
check 'doctor --live through a forking launcher completes' "[ '$RC' = 0 ] && printf '%s' '$OUT' | grep -q 'live=verified'"
check 'wrapper body runs exactly once' "[ \"\$(wc -l < '$TMP/runs')\" = 1 ]"
check 'exactly one invocation is recorded' "[ \"\$(grep -c '\"event\": *\"started\"' '$TMP/events/events.jsonl')\" = 1 ]"
check 'no stray wrapper processes remain' "! pgrep -f '$TMP/root/bi[n]/ai-fake-review' >/dev/null"
: > "$TMP/runs"
OUT="$(AI_REVIEW_EVENT_GUARD_DEPTH=16 run 2>"$TMP/err")"; RC=$?
check 'depth cap refuses a runaway chain' "[ '$RC' != 0 ] && grep -q 'recursion guard' '$TMP/err' && [ ! -s '$TMP/runs' ]"
ai_test_summary 2>/dev/null || { printf '%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]; }
