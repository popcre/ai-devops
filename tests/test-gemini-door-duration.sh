#!/usr/bin/env bash
# Reproduce agy's unitless-duration refusal without any provider generation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/packet"
printf 'Review the packet.\n' > "$TMP/prompt"
cat > "$TMP/agy" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" > "$DURATION_FIXTURE/args"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --print-timeout ]; then
    [[ "$2" =~ ^[0-9]+([.][0-9]+)?[smh]$ ]] || exit 2
    printf '%s\n' "$2" > "$DURATION_FIXTURE/duration"
  fi
  shift
done
printf '{"response":"Review complete.\\n## Verdict\\nAPPROVE","model":"gemini-3.8-flash-high"}\n'
EOF
chmod +x "$TMP/agy"
export DURATION_FIXTURE="$TMP" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_GEMINI_BIN="$TMP/agy"
export DOOR_WORKDIR="$TMP/work" DOOR_PACKET_DIR="$TMP/packet" DOOR_PROMPT_FILE="$TMP/prompt"
export DOOR_REPORT_OUT="$TMP/report" DOOR_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
run(){ bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/out" 2>&1; }
unset DOOR_TIMEOUT AI_GEMINI_TIMEOUT || true
run
[ "$(cat "$TMP/duration")" = 3600s ]
for valid in 60 10m 0.5h 30s; do
  export DOOR_TIMEOUT="$valid"
  run
  expected="$valid"; [[ "$valid" =~ ^[0-9]+$ ]] && expected="${valid}s"
  [ "$(cat "$TMP/duration")" = "$expected" ]
done
for invalid in 0 0s -1 1d nonsense 1h30m 999999999999999999999999999999999999h; do
  rm -f "$TMP/args"
  export DOOR_TIMEOUT="$invalid"
  if run; then printf 'FAIL: invalid duration accepted\n' >&2; exit 1; fi
  [ ! -e "$TMP/args" ]
done
printf 'Gemini door duration: default, 4 valid and 7 refusal cases passed\n'
