#!/usr/bin/env bash
# Tests for bin/ai-mimo.
#
# Offline: a mock `mimo` CLI stands in via AI_MIMO_CLI. Contract facts pinned
# here come from the 2026-09-23 baseline (tests/verification/mimo-windows-2026-09-23/):
# yolo/skip-permissions are refused from caller input, ask defaults to agent
# plan, missing CLI is local_dependency_unavailable, empty output is incomplete.
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
    --cwd) shift 2 ;;
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
    MOCK_ARGS="$TMP/args" MOCK_AGENT="$TMP/agent" \
    "$SCRIPT" "$@"
}

export MOCK_ARGS="$TMP/args"
export MOCK_AGENT="$TMP/agent"
mkdir -p "$TMP/home/skills" "$TMP/data"
printf '{}\n' > "$TMP/home/mimocode.jsonc"
printf 'globals\n' > "$TMP/home/AGENTS.md"

check 'ask prints answer' \
  "out=\$(run ask 'hello') && [ \"\$out\" = OK ]"

check 'ask defaults to plan agent' \
  "run ask 'hello' >/dev/null && [ \"\$(cat '$TMP/agent')\" = plan ]"

check 'ask passes --agent build' \
  "run ask --agent build 'hello' >/dev/null && [ \"\$(cat '$TMP/agent')\" = build ]"

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
