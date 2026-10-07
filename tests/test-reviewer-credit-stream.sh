#!/usr/bin/env bash
# Offline incremental inspection and cross-platform owned-supervisor proof.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$(command -v python3 || command -v python)"
"$PYTHON" "$ROOT/tests/test_reviewer_credit_stream.py"
TASK_TMP="$(mktemp -d)"; trap 'rm -rf "$TASK_TMP"' EXIT
source "$ROOT/tools/reviewer_event_guard.sh"
# The helper must provide native executable/log paths even when a caller has
# disabled Git Bash's automatic argument conversion for a protected boundary.
printf 'stream-input' | MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  reviewer_credit_run muse "$TASK_TMP/out" "$TASK_TMP/err" -- "$PYTHON" \
    -c 'import sys;sys.stdout.write(sys.stdin.read())' > "$TASK_TMP/out" 2> "$TASK_TMP/err"
[ "$(cat "$TASK_TMP/out")" = stream-input ]
printf 'native-path helper with argument conversion disabled: PASS\n'
# A native supervisor must preserve PATH= for MSYS env -> Bash credential
# boundaries. Windows argument auto-conversion must not turn it into a
# semicolon list, or otherwise healthy boundaries cannot find even rm.
reviewer_credit_run muse "$TASK_TMP/env-out" "$TASK_TMP/env-err" -- \
  "$(command -v env)" -i "PATH=$PATH" "$(command -v bash)" --noprofile --norc \
  -c 'command -v rm >/dev/null && printf boundary-path-ok' \
  > "$TASK_TMP/env-out" 2> "$TASK_TMP/env-err"
[ "$(cat "$TASK_TMP/env-out")" = boundary-path-ok ]
printf 'native supervisor preserves MSYS credential boundary PATH: PASS\n'
# A shebang launcher must receive literal argv even when native Python starts
# MSYS Bash: its startup parser otherwise expands @files, braces and wildcards.
cat > "$TASK_TMP/argv-fixture" <<'FIXTURE'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$AI_REVIEW_ARGV_FIXTURE_FILE"
IFS= read -r fixture_input || true
printf '%s' "$fixture_input"
FIXTURE
chmod +x "$TASK_TMP/argv-fixture"
printf '{"model":"deepseek-flash","messages":[]}' > "$TASK_TMP/response-file"
export AI_REVIEW_ARGV_FIXTURE_FILE="$TASK_TMP/actual-argv"
fixture_args=(-d "@$TASK_TMP/response-file" -w '%{http_code}' 'literal-*' \
  "quote\"single'back\\slash" '' $'line1\nline2' \
  '$(touch '"$TASK_TMP"'/should-not-run)' \
  '`touch '"$TASK_TMP"'/should-not-run`' \
  '; touch '"$TASK_TMP"'/should-not-run; #')
printf '%s\0' "${fixture_args[@]}" > "$TASK_TMP/expected-argv"
printf 'fixture-header\n' | reviewer_credit_run deepseek "$TASK_TMP/argv-out" \
  "$TASK_TMP/argv-err" -- "$TASK_TMP/argv-fixture" "${fixture_args[@]}" \
  > "$TASK_TMP/argv-out" 2> "$TASK_TMP/argv-err"
cmp -s "$TASK_TMP/expected-argv" "$TASK_TMP/actual-argv"
[ "$(cat "$TASK_TMP/argv-out")" = fixture-header ]
[ ! -e "$TASK_TMP/should-not-run" ]
printf 'native supervised shebang preserves literal argv and stdin: PASS\n'
