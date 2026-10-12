#!/usr/bin/env bash
# Issue #1577: the Gemini door must tell the model shell commands are
# unavailable, and must name a denied tool when agy returns an empty response.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/packet"
printf 'Review the packet.\n' > "$TMP/prompt"
cat > "$TMP/agy" <<'AGY'
#!/usr/bin/env bash
set -eu
while [ "$#" -gt 0 ]; do [ "$1" = --print ] && printf '%s' "$2" > "$NOSHELL_FIXTURE/prompt-sent"; shift; done
if [ "${NOSHELL_DENY:-0}" = 1 ]; then
  printf '{"status":"SUCCESS","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}]}\n'
else
  printf '{"response":"Fine.\\n## Verdict\\nAPPROVE","model":"gemini-3.8-flash-high"}\n'
fi
AGY
chmod +x "$TMP/agy"
export NOSHELL_FIXTURE="$TMP" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_GEMINI_BIN="$TMP/agy"
export DOOR_WORKDIR="$TMP/work" DOOR_PACKET_DIR="$TMP/packet" DOOR_PROMPT_FILE="$TMP/prompt"
export DOOR_REPORT_OUT="$TMP/report" DOOR_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/out" 2>&1
grep -q 'Shell commands are NOT available' "$TMP/prompt-sent"
grep -q '^APPROVE' "$TMP/report"
if NOSHELL_DENY=1 bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/out" 2>&1; then
  printf 'FAIL: empty denied response accepted\n' >&2; exit 1
fi
grep -q 'denied a tool (RunCommand)' "$TMP/out"
printf 'Gemini door no-shell: brief and denied-tool diagnosis passed\n'
