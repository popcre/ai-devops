#!/usr/bin/env bash
# Offline native-envelope acceptance and private failure retention for Gemini.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard"
source "$ROOT/tests/lib-test-harness.sh"
mkdir -p "$TMP/work" "$TMP/packet"
printf 'Review the sealed packet.\n' > "$TMP/prompt"
cat > "$TMP/agy" <<'STUB'
#!/usr/bin/env bash
cat "$GEMINI_FIXTURE"
printf '%s\n' 'private provider diagnostic sentinel' >&2
exit "${GEMINI_NATIVE_EXIT:-0}"
STUB
chmod +x "$TMP/agy"
export AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_GEMINI_BIN="$TMP/agy"
export DOOR_WORKDIR="$TMP/work" DOOR_PACKET_DIR="$TMP/packet" DOOR_PROMPT_FILE="$TMP/prompt"
export DOOR_HEAD=0123456789012345678901234567890123456789 DOOR_TIMEOUT=10
export GEMINI_FIXTURE="$TMP/response.json"
passed=0
run_case() {
  local name="$1" expected="$2" json="$3" native_exit="${4:-0}" rc=0
  printf '%s\n' "$json" > "$GEMINI_FIXTURE"
  export DOOR_REPORT_OUT="$TMP/$name.report" DOOR_DIAGNOSTICS_DIR="$TMP/$name.diagnostics" GEMINI_NATIVE_EXIT="$native_exit"
  bash "$ROOT/tools/lib/review-doors/gemini.sh" review > "$TMP/$name.out" 2> "$TMP/$name.err" || rc=$?
  if [ "$expected" = success ]; then
    [ "$rc" -eq 0 ] && grep -q '^APPROVE$' "$DOOR_REPORT_OUT"
    [ ! -e "$DOOR_DIAGNOSTICS_DIR" ]
  else
    [ "$rc" -eq 1 ]
    grep -q "\"reason\": \"$expected\"" "$DOOR_DIAGNOSTICS_DIR/report.md"
    cmp "$GEMINI_FIXTURE" "$DOOR_DIAGNOSTICS_DIR/native.jsonl"
    grep -q 'private provider diagnostic sentinel' "$DOOR_DIAGNOSTICS_DIR/native.stderr"
    ! grep -q 'private provider diagnostic sentinel' "$DOOR_REPORT_OUT" "$TMP/$name.err"
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*)
        AI_DEVOPS_PRIVATE_HELPER="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")" \
        AI_DEVOPS_PRIVATE_TARGET="$(cygpath -w "$DOOR_DIAGNOSTICS_DIR")" \
        powershell.exe -NoProfile -NonInteractive -Command \
          '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET; Get-ChildItem -LiteralPath $env:AI_DEVOPS_PRIVATE_TARGET | ForEach-Object { Assert-AiDevOpsPrivateAcl -Path $_.FullName }' \
          > "$TMP/$name.acl-proof" 2>&1
        ;;
      *) python3 - "$DOOR_DIAGNOSTICS_DIR" <<'PY'
import pathlib,stat,sys
p=pathlib.Path(sys.argv[1]);assert stat.S_IMODE(p.stat().st_mode)==0o700
assert all(stat.S_IMODE(f.stat().st_mode)==0o600 for f in p.iterdir())
PY
        ;;
    esac
  fi
  passed=$((passed+1))
}
run_case good success '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":"Substantive findings\n## Verdict\nAPPROVE"}'
run_case empty empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":""}'
run_case whitespace empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":" \n\t"}'
run_case response-object empty-response-text '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":{"message":"APPROVE"}}'
run_case status provider-status-failed '{"status":"ERROR","model":"gemini-3.8-flash-high","response":"## Verdict\nAPPROVE","error":"private provider diagnostic sentinel"}'
run_case denied native-tool-denied '{"status":"SUCCESS","model":"gemini-3.8-flash-high","response":"## Verdict\nAPPROVE","denied_actions":[{"action":"private provider diagnostic sentinel"}]}'
run_case wrong-model model-mismatch '{"status":"SUCCESS","model":"other-model","response":"## Verdict\nAPPROVE"}'
run_case invalid invalid-response-json '{broken-json'
run_case array invalid-response-json '[{"status":"SUCCESS"}]'
run_case native-error provider-call-failed '{"status":"ERROR","error":"private provider diagnostic sentinel"}' 1
printf '%s Gemini native-envelope checks passed\n' "$passed"
