#!/usr/bin/env bash
# Offline tests for bin/ai-review-preflight.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-preflight"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_QUARANTINE_DIR="$TMP/state"
# Wrapper mechanics are tested against a registry that carries every provider,
# so these checks measure install health only. Registry membership itself is
# tested separately below against the repository's real registry.
export AI_REVIEW_REGISTRY_FILE="$TMP/registry.json"
cat > "$AI_REVIEW_REGISTRY_FILE" <<'REGEOF'
{"version":1,"providers":{
 "claude":{"registry_state":"registered","reason":"test"},
 "codex":{"registry_state":"registered","reason":"test"},
 "deepseek":{"registry_state":"registered","reason":"test"},
 "gemini":{"registry_state":"registered","reason":"test"},
 "glm":{"registry_state":"registered","reason":"test"},
 "grok":{"registry_state":"registered","reason":"test"},
 "kimi":{"registry_state":"registered","reason":"test"},
 "muse":{"registry_state":"registered","reason":"test"},
 "qwen":{"registry_state":"registered","reason":"test"}}}
REGEOF
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_PREFLIGHT_TIMEOUT=3
export AI_REVIEW_CAPACITY_CONFIG="$ROOT/config/reviewer-capacity.json"

REPO="$TMP/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
echo x > "$REPO/a"; git -C "$REPO" add a; git -C "$REPO" commit -qm init
mkdir -p "$TMP/bin"
cat > "$TMP/bin/good" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = doctor ] && [ -n "${AI_QWEN_TEST_RUNTIME_FILE:-}" ]; then
  [ -z "${MOCK_QWEN_MODE_LOG:-}" ] || printf '%s\n' "${2:-ordinary}" >> "$MOCK_QWEN_MODE_LOG"
  if [ "${2:-}" = --identity ]; then
    [ "${MOCK_QWEN_IDENTITY_FAIL:-0}" = 0 ] || exit 70
    printf 'IDENTITY runtime_sha256=%s preloader_sha256=%s\n' "$(cat "$AI_QWEN_TEST_RUNTIME_FILE")" "$(cat "$AI_QWEN_TEST_PRELOADER_FILE")"
    [ "${MOCK_QWEN_IDENTITY_DUPLICATE:-0}" = 0 ] || printf 'IDENTITY runtime_sha256=%s preloader_sha256=%s\n' "$(cat "$AI_QWEN_TEST_RUNTIME_FILE")" "$(cat "$AI_QWEN_TEST_PRELOADER_FILE")"
    [ "${MOCK_QWEN_IDENTITY_EXTRA:-0}" = 0 ] || printf 'unexpected extra output\n'
    exit 0
  fi
  [ "${2:-}" = --live ] || { [ "${MOCK_QWEN_NORMAL_DOCTOR_FAIL:-0}" = 0 ] || exit 124; }
  [ "${2:-}" != --live ] || { [ -z "${MOCK_QWEN_CONTACT_FILE:-}" ] || printf 'one\n' >> "$MOCK_QWEN_CONTACT_FILE"; }
  printf 'qwen runtime sha256: %s\n' "$(cat "$AI_QWEN_TEST_RUNTIME_FILE")"
  printf 'qwen preloader sha256: %s\n' "$(cat "$AI_QWEN_TEST_PRELOADER_FILE")"
  if [ "${MOCK_QWEN_FAIL:-0}" = 1 ]; then
    printf 'live probe    : FAILED — authentication-failure\n'
    printf 'diagnostic    : /safe/.ai/reviews/qwen-qualification/failure.json\n'
    exit 1
  fi
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
cat > "$TMP/bin/gemini" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  qualify-live) [ "${MOCK_GEMINI_FAIL:-0}" = 0 ] || exit 70; [ "${MOCK_GEMINI_MUTATE_WRAPPER:-0}" = 0 ] || printf '\n# replaced during canary\n' >> "$0"; [ "${MOCK_GEMINI_MUTATE_RUNTIME:-0}" = 0 ] || printf '%064d\n' 0 | tr 0 b > "$MOCK_AGY_SHA_FILE"; printf 'QUALIFIED session=test model=%s exact-resume=yes mutation-request=no-change outside-sentinel=unchanged reports=durable fixture=/tmp/test\n' "${MOCK_GEMINI_MODEL:-gemini-3.8-flash-high}" ;;
  doctor) if [ "${2:-}" = --live ]; then printf 'live\n' >> "$MOCK_GEMINI_LIVE_CONTACT"; printf 'QUALIFIED session=live model=gemini-3.8-flash-high exact-resume=yes mutation-request=no-change outside-sentinel=unchanged reports=durable fixture=/tmp/live\n'; exit 0; fi; if [ "${2:-}" != --identity ] && [ "${MOCK_GEMINI_NORMAL_DOCTOR_FAIL:-0}" = 1 ]; then exit 124; fi; status=QUARANTINED; rc=3; [ "${2:-}" = --identity ] && { status=IDENTITY; rc=0; }; [ ! -f "$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json" ] || { [ "${2:-}" = --identity ] || status=PASS; rc=0; }; printf '%s agy=%s agy_sha256=%s model=%s disposable-copy=yes containment=test\n' "$status" "${MOCK_AGY_VERSION:-1.1.19}" "$(cat "$MOCK_AGY_SHA_FILE")" "${MOCK_GEMINI_MODEL:-gemini-3.8-flash-high}"; exit "$rc" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$TMP/bin/"*
export AI_REVIEW_GROK_WRAPPER="$TMP/bin/good"
export AI_REVIEW_CODEX_WRAPPER="$TMP/bin/good"
export AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/good"
export AI_REVIEW_QWEN_WRAPPER="$TMP/bin/good"
export AI_REVIEW_GEMINI_WRAPPER="$TMP/bin/gemini"
export MOCK_AGY_SHA_FILE="$TMP/gemini-agy-sha"
export MOCK_GEMINI_LIVE_CONTACT="$TMP/gemini-live-contact"
export AI_QWEN_TEST_RUNTIME_FILE="$TMP/qwen-runtime-sha"
export AI_QWEN_TEST_PRELOADER_FILE="$TMP/qwen-preloader-sha"
printf '%064d\n' 0 | tr 0 a > "$AI_QWEN_TEST_RUNTIME_FILE"
printf '%064d\n' 0 | tr 0 c > "$AI_QWEN_TEST_PRELOADER_FILE"
printf '%064d\n' 0 | tr 0 a > "$MOCK_AGY_SHA_FILE"

echo '== ai-review-preflight'
grep -q 'AI_REVIEW_QWEN_QUALIFY_TIMEOUT:-1800' "$SCRIPT" || { echo 'not ok Qwen live qualification has a realistic independent timeout'; exit 1; }
mkdir -p "$REPO/.ai-review"
printf '%s\n' "$REPO" > "$REPO/.ai-review/.ai-review-packet"
printf 'live-review-evidence\n' > "$REPO/.ai-review/sentinel"
check "valid provider passes offline checks" "$SCRIPT check grok '$REPO' | grep -q 'packet=verified'"
check "unsupported Kimi capacity is explicit unknown" "$SCRIPT capacity kimi --json | jq -e '.state==\"unknown\" and .reason==\"unsupported-interface\" and .reset_at==null'"
check "unsupported capacity separates qualified policy from observed version" "$SCRIPT capacity kimi --json | jq -e '.provider_version==\"unverified\" and .qualified_version==\"0.36.1\"'"
check "capacity requires its JSON contract flag" "! $SCRIPT capacity kimi"
check "capacity timeout comes from the strict policy" "AI_REVIEW_CAPACITY_TIMEOUT= $SCRIPT capacity kimi --json | jq -e '.state==\"unknown\"'"
check "unsupported capacity performs no network request" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_TEST_COUNT_FILE='$TMP/no-contact' $SCRIPT capacity grok --json | jq -e '.state==\"unknown\"' && test ! -e '$TMP/no-contact'"
NOW_ISO="$(date -u +%FT%TZ)"
CAP_COUNT="$TMP/capacity-count"; : > "$CAP_COUNT"
AVAILABLE="$(jq -nc --arg now "$NOW_ISO" '{schema_version:1,provider:"kimi",state:"available",checked_at:$now,provider_version:"0.36.1",credential_profile_scope:"local-profile",model_scope:"kimi-code/k3",source_kind:"synthetic-fixture",reason:"reported-capacity",reset_at:null}')"
check "qualified available capacity validates" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_TEST_COUNT_FILE='$CAP_COUNT' AI_REVIEW_CAPACITY_TEST_RESPONSE='$AVAILABLE' $SCRIPT capacity kimi --json | jq -e '.state==\"available\" and .credential_profile_scope==\"local-profile\"'"
check "capacity probe is attempted exactly once" "test \"\$(wc -l < '$CAP_COUNT')\" -eq 1"
EXHAUSTED="$(jq -nc --arg now "$NOW_ISO" '{schema_version:1,provider:"grok",state:"exhausted",checked_at:$now,provider_version:"1.0.13",credential_profile_scope:"local-profile",model_scope:null,source_kind:"synthetic-fixture",reason:"reported-exhaustion",reset_at:null}')"
check "qualified exhaustion validates without invented reset" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_TEST_RESPONSE='$EXHAUSTED' $SCRIPT capacity grok --json | jq -e '.state==\"exhausted\" and .reset_at==null'"
check "wrong credential scope becomes unknown" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_EXPECTED_PROFILE=other-profile AI_REVIEW_CAPACITY_TEST_RESPONSE='$EXHAUSTED' $SCRIPT capacity grok --json | jq -e '.state==\"unknown\" and .reason==\"wrong-scope\"'"
MALFORMED='{"schema_version":1,"provider":"glm","state":"exhausted","checked_at":"bad","provider_version":"1","credential_profile_scope":null,"model_scope":null,"source_kind":"http-429","reason":"reported-exhaustion","reset_at":null}'
check "429 and unscoped exhaustion cannot become quota truth" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_TEST_RESPONSE='$MALFORMED' $SCRIPT capacity glm --json | jq -e '.state==\"unknown\" and .reason==\"malformed-response\"'"
STALE="$(jq -nc '{schema_version:1,provider:"kimi",state:"available",checked_at:"2020-01-01T00:00:00Z",provider_version:"0.36.1",credential_profile_scope:"local-profile",model_scope:null,source_kind:"synthetic-fixture",reason:"reported-capacity",reset_at:null}')"
check "stale capacity becomes explicit unknown" "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_CAPACITY_TEST_RESPONSE='$STALE' $SCRIPT capacity kimi --json | jq -e '.state==\"unknown\" and .reason==\"stale-response\"'"
check "live review packet is never touched" "grep -qx 'live-review-evidence' '$REPO/.ai-review/sentinel'"
check "disposable preflight snapshot is cleaned" "test -z \"\$(find '$TMP/sandboxes' -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)\""
check "bad base is refused before provider" "! $SCRIPT check grok '$REPO' --base deadbeef"
check "unknown provider is refused" "! $SCRIPT check nope '$REPO'"
check "all active providers are registered" "for p in claude grok kimi glm muse gemini qwen codex deepseek; do $SCRIPT status \"\$p\" | grep -q \"\\\"provider\\\":\\\"\$p\\\"\" || exit 1; done"
check "Gemini status enforces built-in quarantine" "$SCRIPT status gemini | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
check "Gemini check cannot report healthy while quarantined" "! $SCRIPT check gemini '$REPO' 2>&1 | grep -q 'health=ok'"
check "tampered Gemini qualification record fails closed" "mkdir -p '$AI_REVIEW_QUARANTINE_DIR'; printf '{\"version\":2,\"provider\":\"gemini\",\"wrapper_sha256\":\"bad\",\"agy_sha256\":\"bad\",\"agy_version\":\"1.1.19\",\"model\":\"gemini-3.8-flash-high\",\"qualified_epoch\":1}\n' > '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'; $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "successful Gemini live qualification durably releases quarantine" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "Gemini qualification remains valid when network-dependent normal doctor is unavailable" "MOCK_GEMINI_NORMAL_DOCTOR_FAIL=1 $SCRIPT qualify gemini && MOCK_GEMINI_NORMAL_DOCTOR_FAIL=1 $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "failed Gemini requalification revokes the prior qualification" "! MOCK_GEMINI_FAIL=1 $SCRIPT qualify gemini && test ! -e '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json' && $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "Gemini can be qualified again after a failed requalification" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
cp "$TMP/bin/gemini" "$TMP/bin/gemini-race"; chmod +x "$TMP/bin/gemini-race"
check "wrapper replacement during Gemini canary cannot authorize untested bytes" "rm -f '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'; ! MOCK_GEMINI_MUTATE_WRAPPER=1 AI_REVIEW_GEMINI_WRAPPER='$TMP/bin/gemini-race' $SCRIPT qualify gemini && test ! -e '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'"
check "Gemini remains quarantined after a during-canary wrapper replacement" "AI_REVIEW_GEMINI_WRAPPER='$TMP/bin/gemini-race' $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "Gemini requalification still works after rejecting a race" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "same-version Gemini runtime replacement during canary is rejected" "! MOCK_GEMINI_MUTATE_RUNTIME=1 $SCRIPT qualify gemini && test ! -e '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'"
printf '%064d\n' 0 | tr 0 a > "$MOCK_AGY_SHA_FILE"
check "Gemini can be requalified after rejecting runtime replacement" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "Gemini runtime version drift invalidates qualification" "MOCK_AGY_VERSION=1.1.20 $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "Gemini model drift invalidates qualification" "MOCK_GEMINI_MODEL=gemini-other $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
printf '\n# wrapper changed\n' >> "$TMP/bin/gemini"
check "Gemini wrapper drift invalidates qualification" "$SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
sed -i '$d' "$TMP/bin/gemini"
check "Gemini can be requalified after wrapper drift" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "Gemini live preflight performs a genuine live probe" "rm -f '$MOCK_GEMINI_LIVE_CONTACT'; $SCRIPT check gemini '$REPO' --live | grep -q 'allowance=live-verified' && test \"\$(wc -l < '$MOCK_GEMINI_LIVE_CONTACT')\" -eq 1"
check "Qwen status enforces built-in quarantine until live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
check "Qwen check cannot report healthy while credits block live qualification" "! $SCRIPT check qwen '$REPO' 2>&1 | grep -q 'health=ok'"
check "successful Qwen live qualification durably releases quarantine" "$SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
MOCK_QWEN_MODE_LOG="$TMP/qwen-mode-log"; export MOCK_QWEN_MODE_LOG; : > "$MOCK_QWEN_MODE_LOG"
check "Qwen qualification and status avoid the ordinary slow doctor" "MOCK_QWEN_NORMAL_DOCTOR_FAIL=1 $SCRIPT qualify qwen && MOCK_QWEN_NORMAL_DOCTOR_FAIL=1 $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"' && ! grep -qx ordinary '$MOCK_QWEN_MODE_LOG'"
check "default Qwen preflight preserves the ordinary doctor" ": > '$MOCK_QWEN_MODE_LOG'; $SCRIPT check qwen '$REPO' | grep -q 'health=ok' && test \"\$(grep -cx -- --identity '$MOCK_QWEN_MODE_LOG')\" -eq 1 && test \"\$(grep -cx ordinary '$MOCK_QWEN_MODE_LOG')\" -eq 1"
check "default Qwen preflight fails closed when the ordinary doctor fails" "! MOCK_QWEN_NORMAL_DOCTOR_FAIL=1 $SCRIPT check qwen '$REPO' 2>&1 | grep -q 'health=ok' && $SCRIPT status qwen | jq -e '.status==\"quarantined\"' && $SCRIPT clear qwen"
check "duplicate Qwen identity output fails closed" "MOCK_QWEN_IDENTITY_DUPLICATE=1 $SCRIPT status qwen | jq -e '.status==\"quarantined\"'"
check "extra Qwen identity output fails closed" "MOCK_QWEN_IDENTITY_EXTRA=1 $SCRIPT status qwen | jq -e '.status==\"quarantined\"'"
check "failed Qwen identity command fails closed" "MOCK_QWEN_IDENTITY_FAIL=1 $SCRIPT status qwen | jq -e '.status==\"quarantined\"'"
unset MOCK_QWEN_MODE_LOG
MOCK_QWEN_CONTACT_FILE="$TMP/qwen-contact"; export MOCK_QWEN_CONTACT_FILE; : > "$MOCK_QWEN_CONTACT_FILE"
check "failed Qwen requalification revokes the prior qualification" "! MOCK_QWEN_FAIL=1 $SCRIPT qualify qwen && test ! -e '$AI_REVIEW_QUARANTINE_DIR/qwen-live-qualified.json' && $SCRIPT status qwen | jq -e '.status==\"quarantined\"'"
check "failed Qwen qualification is attempted exactly once" "test \"\$(wc -l < '$MOCK_QWEN_CONTACT_FILE')\" -eq 1"
unset MOCK_QWEN_CONTACT_FILE
check "Qwen can be qualified after an evidence-directed failure" "$SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
printf '%064d\n' 0 | tr 0 b > "$AI_QWEN_TEST_RUNTIME_FILE"
check "Qwen runtime changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
printf '%064d\n' 0 | tr 0 a > "$AI_QWEN_TEST_RUNTIME_FILE"
printf '%064d\n' 0 | tr 0 d > "$AI_QWEN_TEST_PRELOADER_FILE"
check "Qwen credential preloader changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
printf '%064d\n' 0 | tr 0 c > "$AI_QWEN_TEST_PRELOADER_FILE"
printf '\n# version changed\n' >> "$TMP/bin/good"
check "Qwen wrapper changes invalidate prior live qualification" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
sed -i '$d' "$TMP/bin/good"
check "Qwen can be requalified after a wrapper change" "$SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
check "Codex status is available with its doctor contract" "$SCRIPT status codex | jq -e '.status==\"installed-healthy\"'"
check "Codex preflight uses its doctor contract" "$SCRIPT check codex '$REPO' | grep -q 'health=ok'"
check "DeepSeek status is available with its doctor contract" "$SCRIPT status deepseek | jq -e '.status==\"installed-healthy\"'"
check "DeepSeek preflight uses its doctor contract" "$SCRIPT check deepseek '$REPO' | grep -q 'health=ok'"
mkdir -p "$TMP/noauth-home" "$TMP/noauth-config"
NOAUTH_OUT="$(env -u DEEPSEEK_API_KEY HOME="$TMP/noauth-home" AI_DEVOPS_CONFIG_DIR="$TMP/noauth-config" AI_REVIEW_DEEPSEEK_WRAPPER="$ROOT/bin/ai-deepseek-agent" "$SCRIPT" check deepseek "$REPO" 2>&1)"; NOAUTH_RC=$?
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
check "clear removes quarantine" "$SCRIPT clear kimi && $SCRIPT status kimi | grep -q installed-healthy"

export AI_REVIEW_KIMI_WRAPPER="$TMP/bin/allowance"
OUT="$($SCRIPT check kimi "$REPO" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q allowance-exhausted && ok "allowance failure is classified" || bad "allowance failure is classified"

for class in allowance-exhausted broken-snapshot empty-assistant-turns turn-exhaustion service-unavailable substantive-finding; do
  check "guidance exists for $class" "$SCRIPT explain '$class' | grep -q ."
done
check "turn exhaustion never recommends more turns" "! $SCRIPT explain turn-exhaustion | grep -Eqi 'higher ceiling|double the turns|--max-turns [0-9]'"
check "substantive finding stops shopping" "$SCRIPT explain substantive-finding | grep -qi 'Never rotate'"

echo '== registry membership is a separate gate from install health'
REAL_REGISTRY="$ROOT/config/reviewer-registry.json"
check "shipped reviewer registry is valid JSON" "jq -e '.version==1 and (.providers|type==\"object\")' '$REAL_REGISTRY'"
check "Gemini is carried in the shipped reviewer registry after live re-qualification"   "jq -e '.providers.gemini.registry_state==\"registered\"' '$REAL_REGISTRY'"
check "the Gemini entry still records why the empty report mattered"   "jq -e '.providers.gemini.reason|test(\"empty report\")' '$REAL_REGISTRY'"
check "Kimi is removed from the shipped reviewer registry while credit is exhausted" "jq -e '.providers.kimi.registry_state==\"absent\" and (.providers.kimi.reason|test(\"out of credit\"))' '$REAL_REGISTRY'"
# Health alone must still never mean allocatable. Proved against a fixture that
# omits a provider, so the guard survives any future registry membership change.
printf '{"version":1,"providers":{"codex":{"registry_state":"absent","reason":"omitted for this fixture"}}}
' > "$TMP/omitted.json"
check "healthy install alone never reports usable when the registry omits the provider"   "AI_REVIEW_REGISTRY_FILE='$TMP/omitted.json' $SCRIPT status codex | jq -e '.usable==false and .registry_state==\"absent\"'"
check "status no longer calls a merely healthy install available"   "! $SCRIPT status codex | grep -q '\"status\":\"available\"'"
check "status reports one reconciled answer per provider"   "$SCRIPT status codex | jq -e '.status==\"installed-healthy\" and .usable==true and .registry_state==\"registered\" and (.registry_reason|length>0)'"
check "usable exits non-zero for a provider the registry omits"   "! AI_REVIEW_REGISTRY_FILE='$TMP/omitted.json' $SCRIPT usable codex"
check "usable exits zero for a registered healthy provider" "$SCRIPT usable codex"
check "usable names why an omitted provider cannot be used"   "AI_REVIEW_REGISTRY_FILE='$TMP/omitted.json' $SCRIPT usable codex | jq -e '.registry_reason|test(\"omitted for this fixture\")'"
check "an unregistered provider cannot be preflighted for a review"   "! AI_REVIEW_REGISTRY_FILE='$TMP/omitted.json' $SCRIPT check codex '$REPO' 2>&1 | grep -q 'health=ok'"
check "a missing registry never reports a provider as usable"   "AI_REVIEW_REGISTRY_FILE='$TMP/no-such-registry.json' $SCRIPT status codex | jq -e '.usable==false and .registry_state==\"unknown\"'"
check "guidance exists for empty-report" "$SCRIPT explain empty-report | grep -qi 'not as an approval'"
check "guidance exists for not-registered" "$SCRIPT explain not-registered | grep -qi 'registry'"


printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
