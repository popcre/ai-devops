#!/usr/bin/env bash
# Tests for bin/ai-mimo.
#
# Offline: a mock `mimo` CLI stands in via AI_MIMO_CLI. Contract facts pinned
# here come from the 2026-09-23 Desktop baseline
# (tests/verification/mimo-windows-2026-09-23/) and the 2026-09-25 CLI
# qualification (tests/verification/mimo-cli-2026-09-25/): yolo/skip-permissions
# are refused from caller input, ask defaults to agent plan, the model selector
# is -m/--model provider/model, the directory flag is --dir (never --cwd),
# missing CLI is local_dependency_unavailable, empty output is incomplete
# (the CLI can exit 0 with the error on stderr and empty stdout).
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-mimo"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

MOCK="$TMP/mimo"
cat > "$MOCK" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$MOCK_ARGS"
while [ $# -gt 0 ]; do
  case "$1" in
    --version) echo "mimo 9.9.9-mock"; exit 0 ;;
    --help) echo "mimo run mock"; exit 0 ;;
    run) shift; continue ;;
    --agent) echo "$2" > "$MOCK_AGENT"; shift 2 ;;
    --model|-m) echo "$2" > "$MOCK_MODEL"; shift 2 ;;
    --dir) echo "$2" > "$MOCK_DIR"; shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
case "${1:-}" in
  *DEFECT-EMPTY*) exit 0 ;;
  *DEFECT-FAIL*) echo "boom" >&2; exit 3 ;;
  *) printf 'OK\n' ;;
esac
EOF
chmod +x "$MOCK"

run() {
  AI_MIMO_CLI="$MOCK" AI_MIMO_DESKTOP_EXE="$TMP/no-desktop.exe" \
    AI_MIMO_HOME="$TMP/home" AI_MIMO_DATA="$TMP/data" \
    MOCK_ARGS="$TMP/args" MOCK_AGENT="$TMP/agent" MOCK_MODEL="$TMP/model" \
    MOCK_DIR="$TMP/dir" \
    "$SCRIPT" "$@"
}

export MOCK_ARGS="$TMP/args"
export MOCK_AGENT="$TMP/agent"
export MOCK_MODEL="$TMP/model"
export MOCK_DIR="$TMP/dir"

# A PATH that satisfies the wrapper's jq/timeout requirements but cannot
# contain `mimo`, so the PATH branch of resolve_cli is what runs (the real
# `mimo` has been on PATH on dev machines since 2026-09-25).
MIN_PATH="$(dirname "$(command -v jq)")":/usr/bin
mkdir -p "$TMP/home/skills" "$TMP/data"
printf '{}\n' > "$TMP/home/mimocode.jsonc"
printf 'globals\n' > "$TMP/home/AGENTS.md"

check 'ask prints answer' \
  "out=\$(run ask 'hello') && [ \"\$out\" = OK ]"

check 'ask defaults to plan agent' \
  "run ask 'hello' >/dev/null && [ \"\$(cat '$TMP/agent')\" = plan ]"

check 'ask passes --agent build' \
  "run ask --agent build 'hello' >/dev/null && [ \"\$(cat '$TMP/agent')\" = build ]"

check 'ask passes --model through to the CLI' \
  "run ask --model xiaomi/mimo-v2.6-flash 'hello' >/dev/null && [ \"\$(cat '$TMP/model')\" = xiaomi/mimo-v2.6-flash ]"

check 'ask omits --model when not given' \
  "run ask 'hello' >/dev/null && ! grep -qx -- '--model' '$TMP/args' && ! grep -qx -- '-m' '$TMP/args'"

check 'ask refuses malformed --model' \
  "! run ask --model flash 'hello' 2>/dev/null"

check 'ask passes --dir through to the CLI' \
  "run ask --dir '$TMP' 'hello' >/dev/null && [ \"\$(cat '$TMP/dir')\" = '$TMP' ]"

check 'ask refuses pre-qualification --cwd guess' \
  "! run ask --cwd '$TMP' 'hello' 2>/dev/null"

check 'ask refuses --yolo' \
  "! run ask --yolo 'hello' 2>/dev/null"

check 'ask refuses --dangerously-skip-permissions' \
  "! run ask --dangerously-skip-permissions 'hello' 2>/dev/null"

check 'ask refuses unknown --agent' \
  "! run ask --agent yolo 'hello' 2>/dev/null"

check 'ask treats empty output as incomplete' \
  "! run ask 'DEFECT-EMPTY' 2>/dev/null"

check 'ask surfaces non-zero CLI exit' \
  "! run ask 'DEFECT-FAIL' 2>/dev/null"

check 'missing CLI is local_dependency_unavailable' \
  "AI_MIMO_CLI='$TMP/missing-mimo' AI_MIMO_DESKTOP_EXE='$TMP/no-desktop.exe' AI_MIMO_HOME='$TMP/home' '$SCRIPT' ask 'hello' 2>&1 | grep -q local_dependency_unavailable"

check 'missing CLI message names the npm package' \
  "env -u AI_MIMO_CLI PATH='$MIN_PATH' AI_MIMO_DESKTOP_EXE='$TMP/no-desktop.exe' AI_MIMO_HOME='$TMP/home' '$SCRIPT' ask 'hello' 2>&1 | grep -q '@mimo-ai/cli'"

check 'doctor green on fixture home' \
  "run doctor >/dev/null"

check 'doctor fails when skills missing' \
  "rm -rf '$TMP/home/skills'; ! run doctor >/dev/null 2>&1; mkdir -p '$TMP/home/skills'"

check 'doctor fails when globals missing' \
  "rm -f '$TMP/home/AGENTS.md'; ! run doctor >/dev/null 2>&1; printf 'globals\\n' > '$TMP/home/AGENTS.md'"

check 'version runs' \
  "run version | grep -q ai-mimo"

check 'unknown command refused' \
  "! run nope 2>/dev/null"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
