#!/usr/bin/env bash
# Offline tests for bin/ai-runner-pool-watch: roster fixtures 0 / 1 / 2+ online.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-runner-pool-watch"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"

# Stub ai-local-watch claim → always leader.
cat > "$TMP/bin/ai-local-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = claim ] && exit 0
exit 0
EOF
# Stub gh with a fixture roster.
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *actions/runners*) cat "$ROSTER_FILE" ;;
  *) echo '{}' ;;
esac
EOF
chmod +x "$TMP/bin/ai-local-watch" "$TMP/bin/ai-gh"

jq '.tools={}' "$ROOT/config/local-watch.json" > "$TMP/config.json"
export PATH="$TMP/bin:$PATH" AI_RUNNER_POOL_WATCH_HOME="$TMP/home" \
  AI_RUNNER_POOL_WATCH_CONFIG="$TMP/config.json" AI_RUNNER_POOL_WATCH_GH="$TMP/bin/ai-gh" \
  AI_LOCAL_WATCH_BIN="$TMP/bin/ai-local-watch" \
  RUNNER_POOL_READ_TOKEN=dummy

roster(){
  local n="$1" status="$2"
  echo '{"runners":[' > "$TMP/roster.json"
  local i=0
  while [ $i -lt "$n" ]; do
    [ $i -gt 0 ] && echo ',' >> "$TMP/roster.json"
    printf '{"name":"win-%s","status":"%s","busy":false,"labels":[{"name":"ai-devops-windows-qualified"}]}' "$i" "$status" >> "$TMP/roster.json"
    i=$((i+1))
  done
  echo ']}' >> "$TMP/roster.json"
  export ROSTER_FILE="$TMP/roster.json"
}

echo 'fixtures'
roster 0 online
check '0 online is an alarm' "bash $SCRIPT check; [ \$? -eq 1 ]"
check '0 online is logged' "grep -q 'ALARM' '$TMP/home/tick.log'"

roster 1 online
check '1 online is a warning but exit 0' "bash $SCRIPT check; [ \$? -eq 0 ]"
check '1 online logs WARN' "grep -q 'WARN' '$TMP/home/tick.log'"

roster 3 online
check '3 online is ok' "bash $SCRIPT check; [ \$? -eq 0 ]"
check 'online count is logged' "grep -q 'online=3' '$TMP/home/tick.log'"

roster 2 offline
check 'offline hosts do not count' "bash $SCRIPT check; [ \$? -eq 1 ]"

echo 'token'
unset RUNNER_POOL_READ_TOKEN
check 'missing token is an alarm' "bash $SCRIPT check; [ \$? -eq 1 ]"
export RUNNER_POOL_READ_TOKEN=dummy

echo 'secrets env file'
roster 1 online
unset RUNNER_POOL_READ_TOKEN
printf 'export RUNNER_POOL_READ_TOKEN=dummy\n' > "$TMP/watchdog.env"
chmod 600 "$TMP/watchdog.env"
check 'secrets env file supplies the token' "AI_DEVOPS_SECRETS_ENV='$TMP/watchdog.env' bash $SCRIPT check; [ \$? -eq 0 ]"
check 'missing secrets file still alarms' "AI_DEVOPS_SECRETS_ENV='$TMP/missing.env' bash $SCRIPT check; [ \$? -eq 1 ]"
export RUNNER_POOL_READ_TOKEN=dummy

echo 'claim gate'
cat > "$TMP/bin/ai-local-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = claim ] && exit 3
exit 0
EOF
check 'tick skips when not leader' "bash $SCRIPT tick; [ \$? -eq 3 ]"

echo 'host health (step 3.2)'
export CALL_LOG="$TMP/calls.log" PUT_BODY="$TMP/put-body.json" \
  RUNS_FILE="$TMP/runs.json" JOBS_FILE="$TMP/jobs.json" \
  RUN_LIST_JSON="$TMP/run-list.json" RUN_VIEW_JSON="$TMP/run-view.json"
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALL_LOG"
case "$*" in
  *"api -X PUT repos/popcre/ai-devops/actions/runners/"*)
    cat > "$PUT_BODY"
    echo '{"ok":true}' ;;
  *"workflows/verify.yml/runs"*) cat "$RUNS_FILE" ;;
  *"actions/runs/"*"/jobs"*) cat "$JOBS_FILE" ;;
  *"workflow run windows-host-canary.yml"*) echo '' ;;
  *"run list"*) cat "$RUN_LIST_JSON" ;;
  *"run view"*) cat "$RUN_VIEW_JSON" ;;
  *"actions/runners --paginate"*) cat "$ROSTER_FILE" ;;
  *"actions/runners"*) echo '{"runners":[]}' ;;
  *) echo '{}' ;;
esac
EOF
chmod +x "$TMP/bin/ai-gh"
cat > "$RUNS_FILE" <<'EOF'
{"workflow_runs":[{"id":100}]}
EOF
cat > "$RUN_LIST_JSON" <<'EOF'
[{"databaseId":777}]
EOF
cat > "$RUN_VIEW_JSON" <<'EOF'
{"status":"completed","conclusion":"success"}
EOF

host_roster(){
  # $1 host, $2 runner id, $3 json labels array (names; emitted as label objects)
  printf '{"runners":[{"id":%s,"name":"%s","status":"online","busy":false,"labels":%s}]}\n' \
    "$2" "$1" "$(printf '%s' "$3" | jq -c 'map({name: .})')" > "$ROSTER_FILE"
}
reset_calls(){ : > "$CALL_LOG"; rm -f "$PUT_BODY"; rm -f "$TMP/home"/canary-*.json; }

reset_calls
host_roster win-bad 5 '["ai-devops-windows","ai-devops-windows-qualified"]'
cat > "$JOBS_FILE" <<'EOF'
{"jobs":[{"name":"windows-offline-section (2)","runner_id":5,"runner_name":"win-bad","started_at":null,"conclusion":"timed_out","status":"completed"}]}
EOF
check 'never-started evidence pauses the host' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT health; [ \$? -eq 0 ]"
check 'pause writes the paused label and remembers the work label' \
  "jq -e '.labels == [\"ai-devops-windows\",\"ai-devops-windows-paused\",\"was-ai-devops-windows-qualified\",\"canary-win-bad\"]' '$PUT_BODY'"
check 'pause is reported' "grep -q 'PAUSED host=win-bad' '$TMP/home/tick.log'"

reset_calls
host_roster win-slow 7 '["ai-devops-windows","ai-devops-windows-section"]'
cat > "$JOBS_FILE" <<'EOF'
{"jobs":[
  {"name":"windows-offline-section (3)","runner_id":7,"runner_name":"win-slow","started_at":"2026-11-06T10:00:00Z","conclusion":"timed_out","status":"completed"},
  {"name":"windows-offline-section (9)","runner_id":7,"runner_name":"win-slow","started_at":"2026-11-06T10:20:00Z","conclusion":"timed_out","status":"completed"}
]}
EOF
check 'two section timeouts pause the host' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT health; [ \$? -eq 0 ]"
check 'section host remembers was-ai-devops-windows-section' \
  "jq -e '.labels == [\"ai-devops-windows\",\"ai-devops-windows-paused\",\"was-ai-devops-windows-section\",\"canary-win-slow\"]' '$PUT_BODY'"

reset_calls
cat > "$JOBS_FILE" <<'EOF'
{"jobs":[
  {"name":"windows-offline-section (3)","runner_id":7,"runner_name":"win-slow","started_at":"2026-11-06T10:00:00Z","conclusion":"timed_out","status":"completed"}
]}
EOF
check 'one section timeout does not pause' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT health; [ \$? -eq 0 ]"
check 'no label write without enough evidence' "[ ! -f '$PUT_BODY' ]"

reset_calls
host_roster win-restored 9 '["ai-devops-windows","ai-devops-windows-paused","was-ai-devops-windows-qualified","canary-win-restored"]'
printf '{"run_id": "901", "dispatched_at": 0}\n' > "$TMP/home/canary-win-restored.json"
cat > "$JOBS_FILE" <<'EOF'
{"jobs":[]}
EOF
check 'a passing canary restores the work label' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT health; [ \$? -eq 0 ]"
check 'restore removes the paused markers' \
  "jq -e '.labels == [\"ai-devops-windows\",\"ai-devops-windows-qualified\"]' '$PUT_BODY'"
check 'restore clears the canary state' "[ ! -f '$TMP/home/canary-win-restored.json' ]"
check 'restore is reported' "grep -q 'RESTORED host=win-restored work=ai-devops-windows-qualified' '$TMP/home/tick.log'"

reset_calls
host_roster win-new 10 '["ai-devops-windows","ai-devops-windows-paused","was-ai-devops-windows-qualified","canary-win-new"]'
check 'a paused host with no canary gets one dispatched' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT health; [ \$? -eq 0 ]"
check 'the canary dispatch names the per-host label' \
  "grep -q 'workflow run windows-host-canary.yml --repo popcre/ai-devops -f host_label=canary-win-new' '$CALL_LOG'"
check 'the canary run id is recorded' "grep -q '\"run_id\": \"777\"' '$TMP/home/canary-win-new.json'"

reset_calls
host_roster win-bad 5 '["ai-devops-windows","ai-devops-windows-qualified"]'
cat > "$JOBS_FILE" <<'EOF'
{"jobs":[{"name":"windows-offline-section (2)","runner_id":5,"runner_name":"win-bad","started_at":null,"conclusion":"timed_out","status":"completed"}]}
EOF
check 'report-only never writes labels' "AI_RUNNER_POOL_WATCH_SETTLE=0 bash $SCRIPT --report-only health; [ \$? -eq 0 ]"
check 'report-only wrote no PUT' "! grep -q 'api -X PUT' '$CALL_LOG'"
check 'report-only says what it would do' "grep -q 'report-only' '$TMP/home/tick.log'"

echo 'help'
check 'help mentions never Blacksmith' "bash $SCRIPT --help | grep -qi blacksmith"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
