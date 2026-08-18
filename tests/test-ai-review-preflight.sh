#!/usr/bin/env bash
# Offline tests for bin/ai-review-preflight.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-preflight"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_QUARANTINE_DIR="$TMP/state"
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_PREFLIGHT_TIMEOUT=3

REPO="$TMP/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
echo x > "$REPO/a"; git -C "$REPO" add a; git -C "$REPO" commit -qm init
mkdir -p "$TMP/bin"
cat > "$TMP/bin/good" <<'EOF'
#!/usr/bin/env bash
echo health ok
EOF
cat > "$TMP/bin/noauth" <<'EOF'
#!/usr/bin/env bash
echo 'NOT AUTHENTICATED: login required' >&2
exit 1
EOF
cat > "$TMP/bin/allowance" <<'EOF'
#!/usr/bin/env bash
echo 'HTTP 403: usage limit / allowance exhausted' >&2
exit 1
EOF
chmod +x "$TMP/bin/"*
export AI_REVIEW_GROK_WRAPPER="$TMP/bin/good"

echo '== ai-review-preflight'
mkdir -p "$REPO/.ai-review"
printf '%s\n' "$REPO" > "$REPO/.ai-review/.ai-review-packet"
printf 'live-review-evidence\n' > "$REPO/.ai-review/sentinel"
check "valid provider passes offline checks" "$SCRIPT check grok '$REPO' | grep -q 'packet=verified'"
check "live review packet is never touched" "grep -qx 'live-review-evidence' '$REPO/.ai-review/sentinel'"
check "disposable preflight snapshot is cleaned" "test -z \"\$(find '$TMP/sandboxes' -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)\""
check "bad base is refused before provider" "! $SCRIPT check grok '$REPO' --base deadbeef"
check "unknown provider is refused" "! $SCRIPT check nope '$REPO'"

export AI_REVIEW_KIMI_WRAPPER="$TMP/bin/noauth"
START=$(date +%s); OUT="$($SCRIPT check kimi "$REPO" 2>&1)"; RC=$?; ELAPSED=$(( $(date +%s) - START ))
[ "$RC" -ne 0 ] && ok "invalid Kimi credential fails" || bad "invalid Kimi credential fails"
[ "$ELAPSED" -lt 10 ] && ok "invalid Kimi credential fails under ten seconds" || bad "invalid Kimi credential fails under ten seconds"
printf '%s' "$OUT" | grep -q authentication-failed && ok "authentication failure is classified" || bad "authentication failure is classified"
check "failed provider is quarantined" "$SCRIPT status kimi | grep -q authentication-failed"

check "quarantine skips provider without contact" "echo old > '$TMP/contact'; AI_REVIEW_KIMI_WRAPPER='$TMP/contact' $SCRIPT check kimi '$REPO' 2>&1 | grep -q quarantined"
check "clear removes quarantine" "$SCRIPT clear kimi && $SCRIPT status kimi | grep -q available"

export AI_REVIEW_KIMI_WRAPPER="$TMP/bin/allowance"
OUT="$($SCRIPT check kimi "$REPO" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q allowance-exhausted && ok "allowance failure is classified" || bad "allowance failure is classified"

for class in allowance-exhausted broken-snapshot empty-assistant-turns turn-exhaustion service-unavailable substantive-finding; do
  check "guidance exists for $class" "$SCRIPT explain '$class' | grep -q ."
done
check "turn exhaustion never recommends more turns" "! $SCRIPT explain turn-exhaustion | grep -Eqi 'higher ceiling|double the turns|--max-turns [0-9]'"
check "substantive finding stops shopping" "$SCRIPT explain substantive-finding | grep -qi 'Never rotate'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
