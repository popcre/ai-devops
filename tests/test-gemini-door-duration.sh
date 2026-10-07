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
  if [ "$1" = --print ]; then printf '%s' "$2" > "$DURATION_FIXTURE/captured-prompt"; fi
  shift
done
if [ "${DURATION_EMPTY:-0}" = 1 ]; then printf '{"status":"SUCCESS","response":"","num_turns":1}\n'; exit 0; fi
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

# Exercise the real core-generated brief, not a mirrored prompt fixture.
unset DOOR_TIMEOUT
source <(awk '/^rlc_write_brief\(\)/ { in_function=1 } in_function {print} in_function && /^}$/ {exit}' "$ROOT/tools/lib/review-lifecycle-core.sh")
for mode in plan-review diff-review security-review visual-review final-check implement; do
  rlc_write_brief "$TMP/prompt" "$mode" "$DOOR_HEAD" digest "$DOOR_WORKDIR" packet \
    'Assess every invariant independently.' 'recorded-test (exit 0 — passed in the review snapshot before dispatch)' 'source.sh'
  cp "$TMP/prompt" "$TMP/original"
  provider_mode=review; [ "$mode" != implement ] || provider_mode=implement
  bash "$ROOT/tools/lib/review-doors/gemini.sh" "$provider_mode" > "$TMP/out" 2>&1
  grep -Fq "You are performing a ${mode}. Gemini provider capabilities:" "$TMP/captured-prompt"
  grep -Fq 'Never call run_command or any terminal tool' "$TMP/captured-prompt"
  grep -Fq 'you may read and edit files only' "$TMP/captured-prompt"
  grep -Fq 'Distinguish recorded test results from tests you personally executed' "$TMP/captured-prompt"
  ! grep -Fq 'You MAY run shell commands' "$TMP/captured-prompt"
  # Everything after the one replaced paragraph is byte-identical.
  {
    tail -n +2 "$TMP/original"
    printf '\n\n---\nFormatting requirement: structure your reply so the final answer is last, under a literal '\''## Verdict'\'' heading, followed by exactly one of APPROVE, REJECT, or BLOCKED.\n'
  } > "$TMP/expected-tail"
  # Command substitution strips final newlines, not any sealed brief bytes.
  tail -n +6 "$TMP/captured-prompt" > "$TMP/actual-tail"
  python3 - "$TMP/expected-tail" "$TMP/actual-tail" <<'PY'
import pathlib,sys
assert pathlib.Path(sys.argv[1]).read_bytes().rstrip(b'\n') == pathlib.Path(sys.argv[2]).read_bytes()
PY
  grep -Fxq -- '--sandbox' "$TMP/args"
  grep -Fxq -- 'gemini-3.8-flash-high' "$TMP/args"
done

# Refuse malformed, displaced, duplicated, wrong-workdir and wrong-mode core
# capability paragraphs before even the fake runtime starts.
rlc_write_brief "$TMP/canonical" final-check "$DOOR_HEAD" digest "$DOOR_WORKDIR" packet
for invalid in malformed displaced duplicate workdir mode; do
  case "$invalid" in
    malformed) sed '1s/You MAY/You CAN/' "$TMP/canonical" > "$TMP/prompt" ;;
    displaced) { printf 'Unexpected preface\n'; cat "$TMP/canonical"; } > "$TMP/prompt" ;;
    duplicate) { cat "$TMP/canonical"; cat "$TMP/canonical"; } > "$TMP/prompt" ;;
    workdir) sed '1s/disposable copy at /disposable copy at WRONG/' "$TMP/canonical" > "$TMP/prompt" ;;
    mode) rlc_write_brief "$TMP/prompt" implement "$DOOR_HEAD" digest "$DOOR_WORKDIR" packet ;;
  esac
  rm -f "$TMP/args"
  if run; then printf 'FAIL: ambiguous core paragraph accepted (%s)\n' "$invalid" >&2; exit 1; fi
  [ ! -e "$TMP/args" ]
done
printf 'Short direct fixture stays intact.\n' > "$TMP/prompt"
run
grep -Fq 'Short direct fixture stays intact.' "$TMP/captured-prompt"
grep -Fq 'You are performing a review. Gemini provider capabilities:' "$TMP/captured-prompt"
export DURATION_EMPTY=1
if run; then printf 'FAIL: empty Gemini response accepted\n' >&2; exit 1; fi
printf 'Gemini file-tool instructions: 6 real core modes, 5 refusals, short fixture and empty response passed\n'
