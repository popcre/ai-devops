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
if [ "${1:-}" = doctor ] && [ -n "${AI_QWEN_TEST_RUNTIME_FILE:-}" ]; then
  printf 'qwen runtime sha256: %s\n' "$(cat "$AI_QWEN_TEST_RUNTIME_FILE")"
  printf 'qwen preloader sha256: %s\n' "$(cat "$AI_QWEN_TEST_PRELOADER_FILE")"
fi
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
cat > "$TMP/bin/requires-muse-caller" <<'EOF'
#!/usr/bin/env bash
[ "${AI_MUSE_CALLER:-}" = preflight ] || { echo missing-caller >&2; exit 1; }
echo health ok
EOF
chmod +x "$TMP/bin/"*
export AI_REVIEW_GROK_WRAPPER="$TMP/bin/good"
export AI_REVIEW_CODEX_WRAPPER="$TMP/bin/good"
export AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/good"
export AI_REVIEW_QWEN_WRAPPER="$TMP/bin/good"
export AI_QWEN_TEST_RUNTIME_FILE="$TMP/qwen-runtime-sha"
export AI_QWEN_TEST_PRELOADER_FILE="$TMP/qwen-preloader-sha"
printf '%064d\n' 0 | tr 0 a > "$AI_QWEN_TEST_RUNTIME_FILE"
printf '%064d\n' 0 | tr 0 c > "$AI_QWEN_TEST_PRELOADER_FILE"

echo '== ai-review-preflight'
mkdir -p "$REPO/.ai-review"
printf '%s\n' "$REPO" > "$REPO/.ai-review/.ai-review-packet"
printf 'live-review-evidence\n' > "$REPO/.ai-review/sentinel"
check "valid provider passes offline checks" "$SCRIPT check grok '$REPO' | grep -q 'packet=verified'"
check "live review packet is never touched" "grep -qx 'live-review-evidence' '$REPO/.ai-review/sentinel'"
check "disposable preflight snapshot is cleaned" "test -z \"\$(find '$TMP/sandboxes' -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)\""
check "bad base is refused before provider" "! $SCRIPT check grok '$REPO' --base deadbeef"
check "unknown provider is refused" "! $SCRIPT check nope '$REPO'"
check "all active providers are registered" "for p in claude grok kimi glm muse gemini qwen codex deepseek; do $SCRIPT status \"\$p\" | grep -q \"\\\"provider\\\":\\\"\$p\\\"\" || exit 1; done"
check "Gemini status enforces built-in quarantine" "$SCRIPT status gemini | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
check "Gemini check cannot report healthy while quarantined" "! $SCRIPT check gemini '$REPO' 2>&1 | grep -q 'health=ok'"
check "Qwen status enforces built-in quarantine until live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
check "Qwen check cannot report healthy while credits block live qualification" "! $SCRIPT check qwen '$REPO' 2>&1 | grep -q 'health=ok'"
check "successful Qwen live qualification durably releases quarantine" "$SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"available\"'"
printf '%064d\n' 0 | tr 0 b > "$AI_QWEN_TEST_RUNTIME_FILE"
check "Qwen runtime changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
printf '%064d\n' 0 | tr 0 a > "$AI_QWEN_TEST_RUNTIME_FILE"
printf '%064d\n' 0 | tr 0 d > "$AI_QWEN_TEST_PRELOADER_FILE"
check "Qwen credential preloader changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
printf '%064d\n' 0 | tr 0 c > "$AI_QWEN_TEST_PRELOADER_FILE"
printf '\n# version changed\n' >> "$TMP/bin/good"
check "Qwen wrapper changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
sed -i '$d' "$TMP/bin/good"
check "Qwen can be requalified after a wrapper change" "$SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"available\"'"
check "Codex status is available with its doctor contract" "$SCRIPT status codex | jq -e '.status==\"available\"'"
check "Codex preflight uses its doctor contract" "$SCRIPT check codex '$REPO' | grep -q 'health=ok'"
check "DeepSeek status is available with its doctor contract" "$SCRIPT status deepseek | jq -e '.status==\"available\"'"
check "DeepSeek preflight uses its doctor contract" "$SCRIPT check deepseek '$REPO' | grep -q 'health=ok'"
mkdir -p "$TMP/noauth-home" "$TMP/noauth-config"
NOAUTH_OUT="$(HOME="$TMP/noauth-home" AI_DEVOPS_CONFIG_DIR="$TMP/noauth-config" AI_REVIEW_DEEPSEEK_WRAPPER="$ROOT/bin/ai-deepseek-agent" "$SCRIPT" check deepseek "$REPO" 2>&1)"; NOAUTH_RC=$?
[ "$NOAUTH_RC" -ne 0 ] && ! printf '%s' "$NOAUTH_OUT" | grep -q 'health=ok' && ok "DeepSeek without key or governed reference cannot pass offline preflight" || bad "DeepSeek without key or governed reference cannot pass offline preflight"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true
export AI_REVIEW_MUSE_WRAPPER="$TMP/bin/requires-muse-caller"
check "Muse preflight supplies its mandatory caller identity" "$SCRIPT check muse '$REPO' | grep -q 'health=ok'"

export AI_REVIEW_KIMI_WRAPPER="$TMP/bin/noauth"
START=$(date +%s); OUT="$($SCRIPT check kimi "$REPO" 2>&1)"; RC=$?; ELAPSED=$(( $(date +%s) - START ))
[ "$RC" -ne 0 ] && ok "invalid Kimi credential fails" || bad "invalid Kimi credential fails"
[ "$ELAPSED" -lt 10 ] && ok "invalid Kimi credential fails under ten seconds" || bad "invalid Kimi credential fails under ten seconds"
printf '%s' "$OUT" | grep -q authentication-failed && ok "authentication failure is classified" || bad "authentication failure is classified"
check "failed provider is quarantined with the shared status contract" "$SCRIPT status kimi | jq -e '.status==\"quarantined\" and .failure_class==\"authentication-failed\"'"

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
