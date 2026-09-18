#!/usr/bin/env bash
# Offline tests for bin/ai-reviewer-start-watch: the shared-db remote is a local
# repository and node / ai-review-preflight are stubs.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-reviewer-start-watch"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/remote/.github/workflows" "$TMP/remote/scripts/orchestrator-flow"

# Fake shared-db main: the workflow carries the transition guard the tool must read.
git -C "$TMP/remote" init -q -b main
cat > "$TMP/remote/.github/workflows/reviewer-start-watch.yml" <<'EOF'
env:
  # guard comment
  DRAWN_SINCE: '2026-09-18T02:00:00Z'
EOF
echo '// watcher' > "$TMP/remote/scripts/orchestrator-flow/reviewer-start-watch.mjs"
git -C "$TMP/remote" add -A && git -C "$TMP/remote" -c user.name=t -c user.email=t@t commit -qm init

# Stub node: records its arguments and working directory; FAKE_NODE_EXIT decides the result.
cat > "$TMP/bin/node" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$(basename "$PWD")" "${REVIEWER_DOCTOR_TIMEOUT_MS:-unset}" "$*" >> "$FAKE_CALLS"; echo '{"leases":[]}'; exit "${FAKE_NODE_EXIT:-0}"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/ai-review-preflight"
chmod +x "$TMP/bin/node" "$TMP/bin/ai-review-preflight"

jq '.run_on_host="watcher-box"' "$ROOT/config/reviewer-start-watch.json" > "$TMP/config.json"
export PATH="$TMP/bin:$PATH" FAKE_CALLS="$TMP/calls" AI_REVIEWER_START_WATCH_HOME="$TMP/home" \
  AI_REVIEWER_START_WATCH_CONFIG="$TMP/config.json" AI_REVIEWER_START_WATCH_REMOTE="$TMP/remote"
run(){ AI_REVIEWER_START_WATCH_HOST="${HOST_AS:-watcher-box}" bash "$SCRIPT" "$@"; }

echo 'config'
check 'shipped config names exactly one watching machine' "jq -e '(.run_on_host | type == \"string\" and length > 0)' '$ROOT/config/reviewer-start-watch.json'"
check 'shipped interval keeps a reroute inside SLO plus one pass' "jq -e '.schedule_every_minutes >= 1 and .schedule_every_minutes <= 5' '$ROOT/config/reviewer-start-watch.json'"

echo 'other machines'
HOST_AS=someone-else run tick 2>/dev/null; rc=$?
check 'a tick on another machine succeeds and does nothing' "[ $rc -eq 0 ] && [ ! -e '$TMP/calls' ] && [ ! -d '$TMP/home/shared-db' ]"
HOST_AS=someone-else run schedule 2>/dev/null; rc=$?
check 'schedule refuses on another machine' "[ $rc -ne 0 ]"

echo 'tick'
run tick 2>/dev/null; rc=$?
check 'a tick on the watching machine succeeds' "[ $rc -eq 0 ]"
check 'it runs the watcher from the fresh clone with apply, the guard from main and the long preflight timeout' "grep -qx 'shared-db|240000|scripts/orchestrator-flow/reviewer-start-watch.mjs --repo popcre/shared-db --apply --drawn-since 2026-09-18T02:00:00Z' '$TMP/calls'"
check 'the pass is logged' "grep -q 'drawn-since 2026-09-18T02:00:00Z' '$TMP/home/tick.log' && grep -q leases '$TMP/home/tick.log'"
check 'the lock is released' "[ ! -e '$TMP/home/tick.lock' ]"

sed -i "s/2026-09-18T02:00:00Z/2026-09-19T00:00:00Z/" "$TMP/remote/.github/workflows/reviewer-start-watch.yml"
git -C "$TMP/remote" -c user.name=t -c user.email=t@t commit -qam bump
run tick 2>/dev/null
check 'the next tick follows a new main' "tail -1 '$TMP/calls' | grep -q 'drawn-since 2026-09-19T00:00:00Z'"

echo 'failures'
FAKE_NODE_EXIT=1 run tick 2>/dev/null; rc=$?
check 'a failed watcher pass fails the tick and is logged' "[ $rc -ne 0 ] && grep -q 'FAILED exit 1' '$TMP/home/tick.log'"
mkdir "$TMP/home/tick.lock"; before="$(wc -l < "$TMP/calls")"
run tick 2>/dev/null; rc=$?
check 'an overlapping tick is refused without running the watcher' "[ $rc -ne 0 ] && [ \"\$(wc -l < '$TMP/calls')\" = '$before' ]"
touch -d '1 hour ago' "$TMP/home/tick.lock"
run tick 2>/dev/null; rc=$?
check 'a stale lock is broken' "[ $rc -eq 0 ] && [ ! -e '$TMP/home/tick.lock' ]"
echo dirty > "$TMP/home/shared-db/stray"
run tick 2>/dev/null; rc=$?
check 'a dirty clone is refused, not reset' "[ $rc -ne 0 ] && [ -f '$TMP/home/shared-db/stray' ]"
rm -f "$TMP/home/shared-db/stray"
sed -i '/DRAWN_SINCE/d' "$TMP/remote/.github/workflows/reviewer-start-watch.yml"
git -C "$TMP/remote" -c user.name=t -c user.email=t@t commit -qam drop
run tick 2>/dev/null; rc=$?
check 'a main without the guard fails the tick' "[ $rc -ne 0 ]"
AI_REVIEWER_START_WATCH_PREFLIGHT=no-such-preflight-command run tick 2>/dev/null; rc=$?
check 'a machine without ai-review-preflight fails the tick' "[ $rc -ne 0 ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
