#!/usr/bin/env bash
# Offline tests for tools/lib/local-watch.sh and bin/ai-local-watch claim/lease.
# GitHub is a stub; the clock is frozen via AI_LOCAL_WATCH_NOW.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-local-watch"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state"

# Fake gh: claim issue state lives in $TMP/state.
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
S="$FAKE_STATE"
printf '%s\n' "$*" >> "$S/calls"
case "$*" in
  "issue list"*)
    if [ -f "$S/issue_num" ]; then echo "$(cat "$S/issue_num")"; fi
    exit 0 ;;
  "issue create"*)
    echo 42 > "$S/issue_num"
    printf '%s\n' "$*" >> "$S/created"
    echo 'https://github.com/o/r/issues/42'
    exit 0 ;;
  "issue view"*)
    if [ -f "$S/body" ]; then cat "$S/body"; else echo ''; fi
    exit 0 ;;
  "issue edit"*)
    # Capture --body
    body=""
    prev=""
    for a in "$@"; do
      [ "$prev" = "--body" ] && body="$a"
      prev="$a"
    done
    printf '%s' "$body" > "$S/body"
    printf '%s\n' "$*" >> "$S/edited"
    exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/ai-gh"

cat > "$TMP/config.json" <<'EOF'
{
  "repo": "o/r",
  "watch_hosts": ["edge-dev", "edge-dev3", "hetz"],
  "claim_issue": 0,
  "claim_issue_title": "local-watch-leader",
  "lease_ttl_minutes": 15,
  "lock_stale_minutes": 20,
  "log_max_bytes": 5000000,
  "tools": {
    "demo": { "tick_minutes": 2, "command": "true" }
  }
}
EOF

export FAKE_STATE="$TMP/state" PATH="$TMP/bin:$PATH"
export AI_LOCAL_WATCH_HOME="$TMP/home" AI_LOCAL_WATCH_CONFIG="$TMP/config.json"
export AI_LOCAL_WATCH_GH="$TMP/bin/ai-gh" AI_LOCAL_WATCH_REPO="o/r"
run(){
  AI_LOCAL_WATCH_HOST="${HOST_AS:-edge-dev}" AI_LOCAL_WATCH_NOW="${NOW_AS:-2026-10-02T12:00:00Z}" \
    bash "$SCRIPT" "$@"
}

echo 'harness'
check 'local-watch.sh is sourceable' "bash -c '. \"$ROOT/tools/lib/local-watch.sh\" && type take_lock >/dev/null'"
check 'take_lock creates and releases' "bash -c '. \"$ROOT/tools/lib/local-watch.sh\"; HOME_DIR=$TMP/l; mkdir -p \$HOME_DIR; take_lock \$HOME_DIR/tick.lock 20; [ -d \$HOME_DIR/tick.lock ]; unlock \$HOME_DIR/tick.lock; [ ! -d \$HOME_DIR/tick.lock ]'"

echo 'pool membership'
HOST_AS=not-in-pool run claim 2>/dev/null; rc=$?
check 'a host outside watch_hosts cannot claim' "[ $rc -ne 0 ] && [ $rc -ne 3 ]"
HOST_AS=not-in-pool run tick-all 2>/dev/null; rc=$?
check 'tick-all on a non-pool host is a no-op success' "[ $rc -eq 0 ]"

echo 'claim'
rm -f "$TMP/state"/*
run claim 2>/dev/null; rc=$?
check 'first claim creates the issue and holds duty' "[ $rc -eq 0 ] && [ -f '$TMP/state/issue_num' ] && grep -q 'leader=edge-dev' '$TMP/state/body'"
check 'lease_until is in the body' "grep -q 'lease_until=2026-10-02T12:15:00Z' '$TMP/state/body'"

run claim 2>/dev/null; rc=$?
check 'own lease renews (exit 0)' "[ $rc -eq 0 ] && grep -q 'renewed_at=2026-10-02T12:00:00Z' '$TMP/state/body'"

# Another host with a fresh lease
cat > "$TMP/state/body" <<'EOF'
<!-- local-watch-claim -->
leader=edge-dev3
lease_until=2026-10-02T12:30:00Z
renewed_at=2026-10-02T12:00:00Z
EOF
run claim 2>/dev/null; rc=$?
check 'a fresh other lease skips (exit 3)' "[ $rc -eq 3 ]"
check 'skip logs the leader' "grep -q 'skip: leader=edge-dev3' <(run claim 2>&1)"

# Expired other lease
cat > "$TMP/state/body" <<'EOF'
<!-- local-watch-claim -->
leader=edge-dev3
lease_until=2026-10-02T11:00:00Z
renewed_at=2026-10-02T10:45:00Z
EOF
run claim 2>/dev/null; rc=$?
check 'an expired lease can be stolen (exit 0)' "[ $rc -eq 0 ] && grep -q 'leader=edge-dev' '$TMP/state/body'"

# Unparsable lease must expire (never stall duty)
cat > "$TMP/state/body" <<'EOF'
<!-- local-watch-claim -->
leader=edge-dev3
lease_until=not-a-date
renewed_at=2026-10-02T10:45:00Z
EOF
run claim 2>/dev/null; rc=$?
check 'an unparsable lease is treated as expired' "[ $rc -eq 0 ] && grep -q 'leader=edge-dev' '$TMP/state/body'"

# API failure must not look like leadership
rm -f "$TMP/state/body"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/ai-gh"
chmod +x "$TMP/bin/ai-gh"
run claim 2>/dev/null; rc=$?
check 'claim API error exits alarm (not 0, not 3)' "[ $rc -eq 1 ]"

echo 'status'
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "issue list"*) echo 42 ;;
  "issue view"*)
    cat <<'BODY'
<!-- local-watch-claim -->
leader=hetz
lease_until=2026-10-02T12:30:00Z
renewed_at=2026-10-02T12:00:00Z
BODY
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/ai-gh"
out="$(run status 2>/dev/null)"
check 'status prints leader and lease age' "printf '%s' '$out' | grep -q 'leader=hetz' && printf '%s' '$out' | grep -q 'lease=fresh'"

echo 'tick-all skip'
cat > "$TMP/state/body" <<'EOF'
<!-- local-watch-claim -->
leader=hetz
lease_until=2026-10-02T12:30:00Z
renewed_at=2026-10-02T12:00:00Z
EOF
# restore working gh for claim read
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
S="$FAKE_STATE"
case "$*" in
  "issue list"*) [ -f "$S/issue_num" ] && cat "$S/issue_num" || echo 42 ;;
  "issue view"*) cat "$S/body" 2>/dev/null || echo '' ;;
  "issue edit"*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/ai-gh"
echo 42 > "$TMP/state/issue_num"
run tick-all 2>/dev/null; rc=$?
check 'tick-all skips when another host is leader' "[ $rc -eq 3 ]"

echo 'tick-all leader runs tools'
cat > "$TMP/state/body" <<'EOF'
<!-- local-watch-claim -->
leader=edge-dev
lease_until=2026-10-02T12:30:00Z
renewed_at=2026-10-02T12:00:00Z
EOF
cat > "$TMP/bin/ai-gh" <<'EOF'
#!/usr/bin/env bash
S="$FAKE_STATE"
case "$*" in
  "issue list"*) echo 42 ;;
  "issue view"*) cat "$S/body" 2>/dev/null || echo '' ;;
  "issue edit"*)
    prev=""; body=""
    for a in "$@"; do [ "$prev" = "--body" ] && body="$a"; prev="$a"; done
    printf '%s' "$body" > "$S/body"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/ai-gh"
# A real duty tool tick-all can run (absolute path).
cat > "$TMP/demo-watch" <<'EOF'
#!/usr/bin/env bash
[ "$1" = tick ] || exit 2
echo demo-tick-ok
exit 0
EOF
chmod +x "$TMP/demo-watch"
cat > "$TMP/config.json" <<EOF
{
  "repo": "o/r",
  "watch_hosts": ["edge-dev", "edge-dev3", "hetz"],
  "claim_issue": 42,
  "claim_issue_title": "local-watch-leader",
  "lease_ttl_minutes": 15,
  "lock_stale_minutes": 20,
  "log_max_bytes": 5000000,
  "tools": {
    "demo": { "tick_minutes": 2, "command": "$TMP/demo-watch" }
  }
}
EOF
run tick-all 2>/dev/null; rc=$?
check 'tick-all as leader succeeds and logs duty' "[ $rc -eq 0 ] && grep -q 'duty: leader=edge-dev' '$TMP/home/tick.log'"
check 'tick-all runs the duty tool tick' "grep -q 'tool demo exit 0' '$TMP/home/tick.log' && grep -q 'demo-tick-ok' '$TMP/home/tick.log'"
# Second immediate tick-all must skip a 2-minute-cadence tool
run tick-all 2>/dev/null; rc=$?
check 'tick-all skips a tool still inside its cadence' "grep -q 'tool demo skipped (cadence 2m)' '$TMP/home/tick.log'"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
