#!/usr/bin/env bash
# Offline tests for bin/ai-windows-queue-watch: pickup delay, marker dedupe,
# non-PR skip. Fixture job JSON; GitHub is a stub.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-windows-queue-watch"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state"

cat > "$TMP/bin/ai-local-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = claim ] && exit 0
exit 0
EOF

# Fixture-driven gh stub. Honors --jq like the real gh.
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
S="$FAKE_STATE"
printf '%s\n' "$*" >> "$S/calls"
jqarg=""; args=("$@"); for i in "${!args[@]}"; do [ "${args[$i]}" = --jq ] && jqarg="${args[$((i+1))]}"; done
out(){ if [ -n "$jqarg" ]; then jq -r "$jqarg" <<<"$1"; else printf '%s\n' "$1"; fi; }
case "$*" in
  *workflows/verify.yml/runs*) out "$(cat "$S/runs.json" 2>/dev/null || echo '{"workflow_runs":[]}')" ;;
  *jobs?filter=latest*) out "$(cat "$S/jobs.json" 2>/dev/null || echo '{"jobs":[]}')" ;;
  "issue view"*) out "$(cat "$S/issue.json" 2>/dev/null || echo '{"comments":[]}')" ;;
  *issues/comments/*PATCH*) printf '%s\n' "$*" >> "$S/patched"; exit 0 ;;
  "pr comment"*) printf '%s\n' "$*" >> "$S/commented"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/ai-local-watch" "$TMP/bin/ai-gh"

jq '.tools={}' "$ROOT/config/local-watch.json" > "$TMP/config.json"
export PATH="$TMP/bin:$PATH" FAKE_STATE="$TMP/state" \
  AI_WINDOWS_QUEUE_WATCH_HOME="$TMP/home" AI_WINDOWS_QUEUE_WATCH_CONFIG="$TMP/config.json" \
  AI_WINDOWS_QUEUE_WATCH_GH="$TMP/bin/ai-gh" AI_WINDOWS_QUEUE_WATCH_REPO="o/r" \
  AI_LOCAL_WATCH_BIN="$TMP/bin/ai-local-watch"

# A PR verify run that started 5 minutes ago (past the 180s threshold).
started="$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)"
cat > "$TMP/state/runs.json" <<EOF
{"workflow_runs":[
  {"id":101,"event":"pull_request","run_started_at":"$started",
   "pull_requests":[{"number":7}]},
  {"id":102,"event":"merge_group","run_started_at":"$started",
   "pull_requests":[]}
]}
EOF

echo 'queued sections'
cat > "$TMP/state/jobs.json" <<'EOF'
{"jobs":[
  {"name":"windows-offline-section-1","status":"queued"},
  {"name":"windows-offline-section-2","status":"in_progress"},
  {"name":"linux-offline","status":"completed"}
]}
EOF
echo '{"comments":[]}' > "$TMP/state/issue.json"
rm -f "$TMP/state/commented" "$TMP/state/patched"
bash "$SCRIPT" scan 2>/dev/null; rc=$?
check 'one queued section past threshold gets one comment' "[ $rc -eq 0 ] && [ -f '$TMP/state/commented' ]"
check 'comment carries the marker and no paid-runner push' "grep -q 'windows-queue-watchdog' '$TMP/state/commented' && ! grep -qi blacksmith '$TMP/state/commented' && grep -qi 'free hosted' '$TMP/state/commented'"

echo 'dedupe'
echo '{"comments":[{"id":99,"body":"<!-- windows-queue-watchdog -->\\nold"}]}' > "$TMP/state/issue.json"
rm -f "$TMP/state/commented"
bash "$SCRIPT" scan 2>/dev/null
check 'second scan updates, does not re-comment' "[ ! -f '$TMP/state/commented' ] && [ -f '$TMP/state/patched' ]"

echo 'all picked up'
cat > "$TMP/state/jobs.json" <<'EOF'
{"jobs":[
  {"name":"windows-offline-section-1","status":"in_progress"},
  {"name":"windows-offline-section-2","status":"completed"}
]}
EOF
rm -f "$TMP/state/commented" "$TMP/state/patched"
bash "$SCRIPT" scan 2>/dev/null
check 'all sections picked up → no comment' "[ ! -f '$TMP/state/commented' ] && [ ! -f '$TMP/state/patched' ]"

echo 'below threshold'
started2="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$TMP/state/runs.json" <<EOF
{"workflow_runs":[{"id":103,"event":"pull_request","run_started_at":"$started2","pull_requests":[{"number":8}]}]}
EOF
cat > "$TMP/state/jobs.json" <<'EOF'
{"jobs":[{"name":"windows-offline-section-1","status":"queued"}]}
EOF
rm -f "$TMP/state/commented" "$TMP/state/patched"
bash "$SCRIPT" scan 2>/dev/null
check 'a fresh run under 3 minutes is not flagged' "[ ! -f '$TMP/state/commented' ]"

echo 'non-PR'
cat > "$TMP/state/runs.json" <<'EOF'
{"workflow_runs":[{"id":104,"event":"merge_group","run_started_at":"2020-01-01T00:00:00Z","pull_requests":[]}]}
EOF
rm -f "$TMP/state/commented" "$TMP/state/patched"
bash "$SCRIPT" scan 2>/dev/null
check 'merge_group runs are ignored' "[ ! -f '$TMP/state/commented' ]"

echo 'claim gate'
cat > "$TMP/bin/ai-local-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = claim ] && exit 3
exit 0
EOF
check 'tick skips when not leader' "bash $SCRIPT tick; [ \$? -eq 3 ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
