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

echo 'claim gate'
cat > "$TMP/bin/ai-local-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = claim ] && exit 3
exit 0
EOF
check 'tick skips when not leader' "bash $SCRIPT tick; [ \$? -eq 3 ]"

echo 'help'
check 'help mentions never Blacksmith' "bash $SCRIPT --help | grep -qi blacksmith"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
