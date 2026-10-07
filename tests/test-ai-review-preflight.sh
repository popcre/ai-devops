#!/usr/bin/env bash
# Offline tests for bin/ai-review-preflight.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-preflight"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-review-public-fixture.sh"
ai_test_public_sources "$TMP"
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
 "qwen":{"registry_state":"registered","reason":"test"},
 "stepfun":{"registry_state":"registered","reason":"test"}}}
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
  [ "${2:-}" != --live ] || { [ "${MOCK_QWEN_MUTATE_WRAPPER:-0}" = 0 ] || printf '\n# replaced during canary\n' >> "$0"; }
  printf 'qwen runtime sha256: %s\n' "$(cat "$AI_QWEN_TEST_RUNTIME_FILE")"
  printf 'qwen preloader sha256: %s\n' "$(cat "$AI_QWEN_TEST_PRELOADER_FILE")"
  if [ "${MOCK_QWEN_FAIL:-0}" = capacity ]; then
    printf 'AI_REVIEWER_ALLOWANCE_EXHAUSTED provider=qwen code=quota_exhausted\n'
    printf 'ALLOWANCE EXHAUSTED: qwen; automatic return at provider reset; reset unavailable.\n'
    printf 'live probe    : FAILED — allowance-exhaustion (provider quota exhausted; resets at 11-01 16:00:00 UTC)\n'
    printf 'diagnostic    : /safe/.ai/reviews/qwen-qualification/failure.json\n'
    exit 1
  fi
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
cat > "$TMP/bin/slow-muse-live" <<'EOF'
#!/usr/bin/env bash
[ "${AI_MUSE_CALLER:-}" = preflight ] || { echo missing-caller >&2; exit 1; }
[ "${2:-}" = --live ] && sleep 2
echo health ok
EOF
cat > "$TMP/bin/slow-muse-doctor" <<'EOF'
#!/usr/bin/env bash
[ "${AI_MUSE_CALLER:-}" = preflight ] || { echo missing-caller >&2; exit 1; }
sleep 2
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
export AI_REVIEW_STEPFUN_WRAPPER="$TMP/bin/good"
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
check "status names the exact resolved wrapper command per provider" "env -u AI_REVIEW_GROK_WRAPPER $SCRIPT status grok | jq -e '.wrapper_command==\"ai-grok-review\" and (.wrapper_path|endswith(\"/ai-grok-review\"))' && env -u AI_REVIEW_QWEN_WRAPPER $SCRIPT status qwen | jq -e '.wrapper_command==\"ai-qwen\"' && env -u AI_REVIEW_CODEX_WRAPPER $SCRIPT status codex | jq -e '.wrapper_command==\"ai-codex-review\"' && $SCRIPT status grok | jq -e '.wrapper_command==\"good\"'"
check "check prints the exact resolved wrapper command" "$SCRIPT check grok '$REPO' 2>&1 | grep -qF 'grok wrapper command: good ($TMP/bin/good)'"
check "a crashing provider check still emits an unusable row and later providers still report" "mkdir -p '$TMP/crashq'; printf 'not json' > '$TMP/crashq/grok.json'; out=\$(AI_REVIEW_QUARANTINE_DIR='$TMP/crashq' $SCRIPT usable 2>/dev/null); printf '%s\n' \"\$out\" | jq -se 'map(select(.provider==\"grok\"))[0].usable==false and (map(.provider)|index(\"deepseek\"))!=null'"
check "all active providers are registered" "for p in claude grok kimi glm muse gemini qwen codex deepseek stepfun; do $SCRIPT status \"\$p\" | grep -q \"\\\"provider\\\":\\\"\$p\\\"\" || exit 1; done"
check "Gemini status enforces built-in quarantine" "$SCRIPT status gemini | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
check "Gemini check cannot report healthy while quarantined" "! $SCRIPT check gemini '$REPO' 2>&1 | grep -q 'health=ok'"
check "tampered Gemini qualification record fails closed" "mkdir -p '$AI_REVIEW_QUARANTINE_DIR'; printf '{\"version\":2,\"provider\":\"gemini\",\"wrapper_sha256\":\"bad\",\"agy_sha256\":\"bad\",\"agy_version\":\"1.1.19\",\"model\":\"gemini-3.8-flash-high\",\"qualified_epoch\":1}\n' > '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'; $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "successful Gemini live qualification durably releases quarantine" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "Gemini qualification remains valid when network-dependent normal doctor is unavailable" "MOCK_GEMINI_NORMAL_DOCTOR_FAIL=1 $SCRIPT qualify gemini && MOCK_GEMINI_NORMAL_DOCTOR_FAIL=1 $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
# Old "failed requalification revokes the prior qualification" (delete-before-
# canary) was a product bug: it was the 24-48h quarantine loop (issue #1112).
# A failed canary keeps the previous version valid — no quarantine, no lockout.
check "failed Gemini requalification keeps the prior qualification (no quarantine)" "! MOCK_GEMINI_FAIL=1 $SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
check "Gemini can be qualified again after a failed requalification" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
cp "$TMP/bin/gemini" "$TMP/bin/gemini-race"; chmod +x "$TMP/bin/gemini-race"
check "wrapper replacement during Gemini canary cannot authorize untested bytes" "rm -f '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'; ! MOCK_GEMINI_MUTATE_WRAPPER=1 AI_REVIEW_GEMINI_WRAPPER='$TMP/bin/gemini-race' $SCRIPT qualify gemini && test ! -e '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json'"
check "Gemini remains quarantined after a during-canary wrapper replacement" "AI_REVIEW_GEMINI_WRAPPER='$TMP/bin/gemini-race' $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
check "Gemini requalification still works after rejecting a race" "$SCRIPT qualify gemini && $SCRIPT status gemini | jq -e '.status==\"installed-healthy\"'"
# Re-scoped: the old assertion expected the whole record to be deleted
# (revoke-on-fail, the 24-48h product bug). The invariant to keep is that the
# untested runtime bytes are never authorized: no version may carry the
# replaced runtime hash, while the prior version is kept.
BAD_AGY_SHA="$(printf '%064d\n' 0 | tr 0 b)"
check "same-version Gemini runtime replacement during canary is rejected" "! MOCK_GEMINI_MUTATE_RUNTIME=1 $SCRIPT qualify gemini && ! jq -e --arg s '$BAD_AGY_SHA' 'any(.versions[]; .agy_sha256==\$s)' '$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json' && $SCRIPT status gemini | jq -e '.status==\"quarantined\"'"
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
# Old "failed requalification revokes the prior qualification" (delete-before-
# canary) was a product bug: it was the 24-48h quarantine loop (issue #1112).
# A failed canary keeps the previous version valid — no quarantine, no lockout.
check "failed Qwen requalification keeps the prior qualification (no quarantine)" "! MOCK_QWEN_FAIL=1 $SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
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

echo '== requalification keeps last good (#1112)'
# The old qualify path deleted the live-qualification record BEFORE the live
# canary ("revoke-on-fail"). That was a product bug — the 24-48h quarantine
# loop (issue #1112). The record is now a versioned store keyed by
# wrapper/runtime/preloader hashes (Gemini also model): every canary-proven key
# is kept, a failed canary never deletes the last good approval, and untested
# bytes are never authorized.
check "Qwen starts from a live-qualified last good version" "$SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
echo '== known-broken providers are un-drawable even when live-qualified (#1035)'
# Regression for the shared-db allocator drawing qwen-3.8-max while Qwen was
# known-broken on edge-dev (until ai-devops#1035). A live qualification must not
# make a known-broken provider drawable: preflight reports it un-drawable with
# failure_class provider_unavailable BEFORE any replacement sequence is spent,
# so the allocator's allocatableReviewers() skips it. Clearing the marker restores
# the already-qualified provider without re-qualifying.
check "Qwen is drawable while live-qualified (baseline)" "$SCRIPT usable qwen | jq -e '.status==\"installed-healthy\" and .usable==true'"
check "known-broken Qwen is un-drawable with provider_unavailable despite a current qualification" "$SCRIPT known-broken qwen 'Qwen is broken on edge-dev until ai-devops#1035' --issue 1035 && $SCRIPT usable qwen | jq -e '.status==\"known-broken\" and .failure_class==\"provider_unavailable\" and .usable==false'"
check "known-broken Qwen is skipped before a sequence is consumed (usable false)" "$SCRIPT usable qwen | jq -e '.usable==false'"
check "clearing known-broken restores the live-qualified Qwen to drawable (no re-qualification)" "$SCRIPT clear qwen && $SCRIPT usable qwen | jq -e '.status==\"installed-healthy\" and .usable==true'"
check "failed canary keeps previous version (no quarantine)" "! MOCK_QWEN_FAIL=1 $SCRIPT qualify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
cp "$TMP/bin/good" "$TMP/bin/good-mutated"
printf '\n# mutated wrapper for issue 1112\n' >> "$TMP/bin/good-mutated"
MUTATED_SHA="$(sha256sum "$TMP/bin/good-mutated" | awk '{print $1}')"
check "mutate wrapper hash keeps tool usable on last good version" "! MOCK_QWEN_FAIL=1 AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good-mutated' $SCRIPT qualify qwen && AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good' $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
check "successful canary publishes new version" "AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good-mutated' $SCRIPT qualify qwen && jq -e --arg sha '$MUTATED_SHA' 'any(.versions[]; .wrapper_sha256==\$sha)' '$AI_REVIEW_QUARANTINE_DIR/qwen-live-qualified.json' && AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good-mutated' $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
check "drift selects matching version instead of quarantine" "AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good' $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
cp "$TMP/bin/good" "$TMP/bin/good-race"; chmod +x "$TMP/bin/good-race"
check "untested bytes are never authorized" "! MOCK_QWEN_MUTATE_WRAPPER=1 AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good-race' $SCRIPT qualify qwen && AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good-race' $SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"' && AI_REVIEW_QWEN_WRAPPER='$TMP/bin/good' $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
RACE_SHA="$(sha256sum "$TMP/bin/good-race" | awk '{print $1}')"
check "no version authorizes the raced untested bytes" "jq -e --arg sha '$RACE_SHA' 'all(.versions[]; .wrapper_sha256!=\$sha)' '$AI_REVIEW_QUARANTINE_DIR/qwen-live-qualified.json'"

echo '== automatic requalification (#804)'
MOCK_QWEN_MODE_LOG="$TMP/qwen-requalify-mode-log"; export MOCK_QWEN_MODE_LOG
check "explain covers live-qualification-required" "$SCRIPT explain live-qualification-required | grep -q requalify"
check "requalify refuses a provider without a live-qualification contract" "! $SCRIPT requalify grok"
check "requalify on a host with no records is a no-op that still passes" "AI_REVIEW_QUARANTINE_DIR='$TMP/no-records-state' $SCRIPT requalify && test ! -e '$TMP/no-records-state/qwen-live-qualified.json' && test ! -e '$TMP/no-records-state/gemini-live-qualified.json'"
: > "$MOCK_QWEN_MODE_LOG"
check "requalify leaves a current qualification alone without a canary" "$SCRIPT requalify qwen && grep -qx -- --identity '$MOCK_QWEN_MODE_LOG' && ! grep -qx -- --live '$MOCK_QWEN_MODE_LOG' && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
printf '%064d\n' 1 | tr 0 b > "$AI_QWEN_TEST_RUNTIME_FILE"
: > "$MOCK_QWEN_MODE_LOG"
check "requalify refreshes a stale qualification after runtime drift" "$SCRIPT requalify qwen && grep -qx -- --live '$MOCK_QWEN_MODE_LOG' && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
printf '%064d\n' 2 | tr 0 b > "$AI_QWEN_TEST_RUNTIME_FILE"
rm -rf "$TMP/reviewer-issues"
export MOCK_QWEN_FAIL=1 AI_REVIEWER_ISSUE_DIR="$TMP/reviewer-issues"
REQUALIFY_OUT="$($SCRIPT requalify qwen 2>&1)"; REQUALIFY_RC=$?
unset MOCK_QWEN_FAIL
[ "$REQUALIFY_RC" -ne 0 ] && printf '%s' "$REQUALIFY_OUT" | grep -q 'reviewer issue:' && ok "failed automatic requalification is recorded and fails the command" || bad "failed automatic requalification is recorded and fails the command"
REQUALIFY_ID="$(printf '%s\n' "$REQUALIFY_OUT" | sed -n 's/.*reviewer issue: //p' | tail -n1)"
[ -n "$REQUALIFY_ID" ] && [ -f "$TMP/reviewer-issues/$REQUALIFY_ID/issue.json" ] \
  && jq -e --arg p qwen '.provider==$p and (.reported_command|test("requalify qwen")) and .evidence.complete_error_log==null and .evidence.session_details=="details.redacted.txt"' "$TMP/reviewer-issues/$REQUALIFY_ID/issue.json" >/dev/null \
  && ok "the recorded failure names the provider and the requalify command" || bad "the recorded failure names the provider and the requalify command"
check "a failed automatic requalification leaves the reviewer quarantined" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
printf '%064d\n' 4 | tr 0 b > "$AI_QWEN_TEST_RUNTIME_FILE"
CAPACITY_OUT="$(MOCK_QWEN_FAIL=capacity $SCRIPT requalify qwen 2>&1)"; CAPACITY_RC=$?
[ "$CAPACITY_RC" -eq 0 ] && printf '%s' "$CAPACITY_OUT" | grep -q 'reviewer issue:' && printf '%s' "$CAPACITY_OUT" | grep -q 'requalification deferred: provider capacity' \
  && ok "a provider capacity failure is recorded but does not fail requalify" || bad "a provider capacity failure is recorded but does not fail requalify"
check "a capacity-deferred requalification leaves the reviewer quarantined" "$SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
export MOCK_QWEN_CONTACT_FILE="$TMP/reset-canary-calls"
: > "$MOCK_QWEN_CONTACT_FILE"
check "capacity deferral without a known reset never probes" "$SCRIPT reset-requalify qwen && test ! -s '$MOCK_QWEN_CONTACT_FILE'"
reset_now="$(date +%s)"
reset_past="$(date -u -d '@'"$((reset_now-1))" +%FT%TZ)"
reset_future="$(date -u -d '@'"$((reset_now+3600))" +%FT%TZ)"
reset_state="$AI_REVIEW_QUARANTINE_DIR/qwen.json"
reset_fixture(){
  jq -nc --arg at "$1" --argjson now "$reset_now" \
    '{version:2,provider:"qwen",global:null,backoffs:{},capacity_hold:{provider:"qwen",failure_class:"allowance-exhausted",credential_profile_scope:null,model_scope:null,observed_epoch:($now-50),reset_at:$at,next_check_epoch:$now,record_id:"qualified-reset-fixture"}}' > "$reset_state"
}
reset_fixture "$reset_future"
check "capacity deferral before reset never probes" "$SCRIPT reset-requalify qwen && test ! -s '$MOCK_QWEN_CONTACT_FILE'"
reset_fixture "$reset_past"
"$SCRIPT" quarantine qwen authentication-failed --seconds 3600 >/dev/null
check "reset qualification preserves a stronger authentication hold" "$SCRIPT reset-requalify qwen && test ! -s '$MOCK_QWEN_CONTACT_FILE' && $SCRIPT pause-status qwen | jq -e '.failure_class==\"authentication-failed\"'"
# Remove only this fixture's stronger global hold; retain its due capacity record.
reset_python="$(command -v python3 || command -v python)"
"$reset_python" "$ROOT/tools/reviewer_admission.py" clear-global qwen --directory "$AI_REVIEW_QUARANTINE_DIR" >/dev/null
cp "$AI_QWEN_TEST_RUNTIME_FILE" "$TMP/reset-runtime-before"
printf '%064d\n' 9 | tr 0 f > "$AI_QWEN_TEST_RUNTIME_FILE"
check "reset cannot qualify bytes different from the capacity deferral" "$SCRIPT reset-requalify qwen && test ! -s '$MOCK_QWEN_CONTACT_FILE'"
cp "$TMP/reset-runtime-before" "$AI_QWEN_TEST_RUNTIME_FILE"
"$SCRIPT" reset-requalify qwen > "$TMP/reset-one.log" 2>&1 & reset_one=$!
"$SCRIPT" reset-requalify qwen > "$TMP/reset-two.log" 2>&1 & reset_two=$!
wait "$reset_one"; reset_one_rc=$?
wait "$reset_two"; reset_two_rc=$?
[ "$reset_one_rc" -eq 0 ] && [ "$reset_two_rc" -eq 0 ] && [ "$(wc -l < "$MOCK_QWEN_CONTACT_FILE" | tr -d ' ')" -eq 1 ] \
  && ok "concurrent due reset qualifies once through the existing canary" || bad "concurrent due reset qualifies once through the existing canary"
check "successful reset canary restores ordinary current qualification" "$SCRIPT status qwen | jq -e '.status==\"installed-healthy\" and .usable==true'"
check "current qualification never repeats the reset canary" "$SCRIPT reset-requalify qwen && test \"\$(wc -l < '$MOCK_QWEN_CONTACT_FILE' | tr -d ' ')\" -eq 1"
unset MOCK_QWEN_CONTACT_FILE
check "a failed requalification is retried, not silently abandoned" "$SCRIPT requalify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"
printf '{"version":1,"providers":{"qwen":{"registry_state":"absent","reason":"retired for this fixture"}}}\n' > "$TMP/qwen-omitted.json"
check "an unregistered reviewer is skipped without a canary" ": > '$MOCK_QWEN_MODE_LOG'; printf '%064d\n' 3 | tr 0 b > '$AI_QWEN_TEST_RUNTIME_FILE'; AI_REVIEW_REGISTRY_FILE='$TMP/qwen-omitted.json' $SCRIPT requalify qwen && ! grep -qx -- --live '$MOCK_QWEN_MODE_LOG' && $SCRIPT status qwen | jq -e '.status==\"quarantined\" and .failure_class==\"live-qualification-required\"'"
unset AI_REVIEWER_ISSUE_DIR
check "requalify recovers the reviewer on the next successful run" "$SCRIPT requalify qwen && $SCRIPT status qwen | jq -e '.status==\"installed-healthy\"'"

echo '== post-merge reviewer hook (#804)'
HOOKTEST="$TMP/hooktest"; HOOK_ORIGIN="$HOOKTEST/origin.git"; HOOK_CLONE="$HOOKTEST/clone"
git init -q --bare -b main "$HOOK_ORIGIN"
git clone -q "$HOOK_ORIGIN" "$HOOK_CLONE" 2>/dev/null
git -C "$HOOK_CLONE" config user.name Test; git -C "$HOOK_CLONE" config user.email t@example.com
mkdir -p "$HOOK_CLONE/bin"
printf '#!/usr/bin/env bash\nprintf "gitdir=[%%s]\\n" "${GIT_DIR:-}" >> "%s/hook-called"\nexit 0\n' "$TMP" > "$HOOK_CLONE/bin/ai-review-preflight"
chmod +x "$HOOK_CLONE/bin/ai-review-preflight"
cp "$ROOT/hooks/post-merge" "$HOOK_CLONE/.git/hooks/post-merge"
chmod +x "$HOOK_CLONE/.git/hooks/post-merge"
echo a > "$HOOK_CLONE/a"; git -C "$HOOK_CLONE" add a; git -C "$HOOK_CLONE" commit -qm one; git -C "$HOOK_CLONE" push -q origin main
echo b > "$HOOK_CLONE/b"; git -C "$HOOK_CLONE" add b; git -C "$HOOK_CLONE" commit -qm two; git -C "$HOOK_CLONE" push -q origin main
git -C "$HOOK_CLONE" reset -q --hard HEAD~1
git -C "$HOOK_CLONE" pull -q --ff-only
check "the managed hook fires after a main pull" "test -f '$TMP/hook-called'"
check "the hook strips git hook environment before requalify" "grep -q 'gitdir=\[\]' '$TMP/hook-called'"
rm -f "$TMP/hook-called"
git -C "$HOOK_CLONE" reset -q --hard HEAD~1
"$HOOK_CLONE/.git/hooks/post-merge"
check "the hook skips an older mainline commit" "test ! -e '$TMP/hook-called'"
git -C "$HOOK_CLONE" pull -q --ff-only
rm -f "$TMP/hook-called"
git -C "$HOOK_CLONE" checkout -qb feature HEAD~1
echo c > "$HOOK_CLONE/c"; git -C "$HOOK_CLONE" add c; git -C "$HOOK_CLONE" commit -qm three
git -C "$HOOK_CLONE" fetch -q origin
git -C "$HOOK_CLONE" merge -q origin/main -m "merge main into feature" >/dev/null 2>&1
check "the hook skips a development branch merge" "test ! -e '$TMP/hook-called'"
rm -rf "$HOOK_CLONE/bin"
git -C "$HOOK_CLONE" checkout -q main
git -C "$HOOK_CLONE" reset -q --hard HEAD~1
HOOK_SILENT="$(git -C "$HOOK_CLONE" pull -q --ff-only 2>&1)"; HOOK_RC=$?
[ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_SILENT" ] && ok "the hook stays silent when the toolkit command is absent" || bad "the hook stays silent when the toolkit command is absent"
check "the shipped hook carries the managed marker" "grep -q '^# ai-devops-managed: reviewer auto-requalification' '$ROOT/hooks/post-merge'"
check "the shipped hook fails hard when its exec target is missing" "grep -q '^set -euo pipefail' '$ROOT/hooks/post-merge'"

echo '== managed hook installer (#804)'
HOOK_INSTALL="$ROOT/bin/ai-install-post-merge-hook"
check "the hook installer is committed executable" "test \"\$(git -C '$ROOT' ls-files -s -- bin/ai-install-post-merge-hook | awk '{print \$1}')\" = 100755"
check "the shipped hook is committed executable" "test \"\$(git -C '$ROOT' ls-files -s -- hooks/post-merge | awk '{print \$1}')\" = 100755"
FIXTURE="$TMP/hook-fixture"
git init -q -b main "$FIXTURE"
git -C "$FIXTURE" config user.name Test; git -C "$FIXTURE" config user.email t@example.com
printf 'x\n' > "$FIXTURE/x"; git -C "$FIXTURE" add x; git -C "$FIXTURE" commit -qm one
check "dry-run install writes nothing" "'$HOOK_INSTALL' --repo '$FIXTURE' --dry-run && test ! -e '$FIXTURE/.git/hooks/post-merge'"
check "install places an executable managed hook" "'$HOOK_INSTALL' --repo '$FIXTURE' && test -x '$FIXTURE/.git/hooks/post-merge' && cmp -s '$ROOT/hooks/post-merge' '$FIXTURE/.git/hooks/post-merge'"
check "reinstall over a managed hook is idempotent" "'$HOOK_INSTALL' --repo '$FIXTURE' && cmp -s '$ROOT/hooks/post-merge' '$FIXTURE/.git/hooks/post-merge'"
printf '#!/bin/sh\n# local customization\ntrue\n' > "$FIXTURE/.git/hooks/post-merge"
check "a foreign hook is never touched" "'$HOOK_INSTALL' --repo '$FIXTURE' && grep -q 'local customization' '$FIXTURE/.git/hooks/post-merge'"
cp "$ROOT/hooks/post-merge" "$FIXTURE/.git/hooks/post-merge"
check "dry-run remove writes nothing" "'$HOOK_INSTALL' --remove --repo '$FIXTURE' --dry-run && test -e '$FIXTURE/.git/hooks/post-merge'"
printf '\n# drifted\n' >> "$FIXTURE/.git/hooks/post-merge"
check "a drifted managed hook is preserved on remove" "'$HOOK_INSTALL' --remove --repo '$FIXTURE' && test -e '$FIXTURE/.git/hooks/post-merge'"
cp "$ROOT/hooks/post-merge" "$FIXTURE/.git/hooks/post-merge"
chmod +x "$FIXTURE/.git/hooks/post-merge"
check "an owned matching hook is removed" "'$HOOK_INSTALL' --remove --repo '$FIXTURE' && test ! -e '$FIXTURE/.git/hooks/post-merge'"
check "remove without an owned hook is a no-op" "'$HOOK_INSTALL' --remove --repo '$FIXTURE'"
check "a non-repository target is refused for install" "! '$HOOK_INSTALL' --repo '$TMP/not-a-repo'"
check "a non-repository target has nothing to remove" "'$HOOK_INSTALL' --remove --repo '$TMP/not-a-repo'"
ln -s "$HOOK_INSTALL" "$TMP/bin/hook-tool-link" 2>/dev/null || true
if [ -L "$TMP/bin/hook-tool-link" ]; then
  check "the installer resolves a PATH symlink to its shipped hook" "'$TMP/bin/hook-tool-link' --repo '$FIXTURE' && cmp -s '$ROOT/hooks/post-merge' '$FIXTURE/.git/hooks/post-merge'"
else
  echo "SKIP: the installer resolves a PATH symlink to its shipped hook (ln -s cannot create symlinks here; readlink contract unexercised)"
fi
check "install.sh runs the shared hook installer" "grep -q 'ai-install-post-merge-hook' '$ROOT/install.sh'"
check "the Windows installer runs the shared hook installer" "grep -q 'ai-install-post-merge-hook' '$ROOT/bin/install-ai-devops-windows.ps1'"
check "the Windows installer disables hooks on its own fast-forward" "grep -q 'core.hooksPath' '$ROOT/bin/install-ai-devops-windows.ps1'"
check "update.sh disables hooks on its own pull" "grep -q 'core.hooksPath' '$ROOT/update.sh'"
check "Linux installer requires requalification before finalization" "grep -q 'run_stage required \"Reviewer requalification\".*ai-review-preflight' '$ROOT/install.sh' && grep -q 'install-verify --phase finalize' '$ROOT/update.sh'"
check "the Windows installer requalifies after installing the hook" "grep -q 'requalify' '$ROOT/bin/install-ai-devops-windows.ps1'"
check "uninstall removes the hook through the shared script" "grep -q 'bin/ai-install-post-merge-hook' '$ROOT/uninstall.sh' && grep -q -- '--remove.*--repo' '$ROOT/uninstall.sh'"
check "the hook tree is pinned to LF" "grep -q '^hooks/.*text eol=lf' '$ROOT/.gitattributes'"
check "line-ending checks scan the hook tree" "grep -q \"'hooks/\*'\" '$ROOT/tests/test-line-endings.sh'"
check "Codex status is available with its doctor contract" "$SCRIPT status codex | jq -e '.status==\"installed-healthy\"'"
check "Codex preflight uses its doctor contract" "$SCRIPT check codex '$REPO' | grep -q 'health=ok'"
check "DeepSeek status is available with its doctor contract" "$SCRIPT status deepseek | jq -e '.status==\"installed-healthy\"'"
check "DeepSeek preflight uses its doctor contract" "$SCRIPT check deepseek '$REPO' | grep -q 'health=ok'"
check "StepFun is usable on Linux with its doctor contract" "AI_STEPFUN_PLATFORM=Linux $SCRIPT status stepfun | jq -e '.status==\"installed-healthy\" and .usable==true'"
check "StepFun preflight passes on Linux" "AI_STEPFUN_PLATFORM=Linux $SCRIPT check stepfun '$REPO' | grep -q 'health=ok'"
# Restricted PATH: essential tools only, so `command -v opencode` fails and
# the StepFun engine-miss path is reachable on Windows CI runners.
WIN_TEST_PATH="/mingw64/bin:$(dirname "$(command -v jq)"):/usr/bin:/bin:$(dirname "$(command -v python3 || command -v python)")"
check "StepFun is unsupported-platform on Windows without OpenCode" "AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_OPENCODE='$TMP/missing-oc' PATH=\"$WIN_TEST_PATH\" $SCRIPT status stepfun | jq -e '.status==\"unsupported-platform\" and .usable==false'"
check "StepFun preflight refuses on Windows without an engine" "AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_OPENCODE='$TMP/missing-oc' PATH=\"$WIN_TEST_PATH\" $SCRIPT check stepfun '$REPO' >/dev/null 2>&1; [ \$? = 4 ]"
check "unsupported-platform has an explanation" "$SCRIPT explain unsupported-platform | grep -q 'Ubuntu/Linux under bubblewrap, or Windows folder + test shell'"
check "StepFun is not statically unsupported on Windows with OpenCode (folder + test shell)" "! AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_OPENCODE=/bin/true $SCRIPT status stepfun | jq -e '.failure_class==\"unsupported-platform\"'"
# Default install path must satisfy preflight even when AI_STEPFUN_OPENCODE is
# unset — otherwise a healthy Windows OpenCode setup is reported unsupported.
# Pin the path from config/opencode/version so a version bump cannot silently
# skip this branch. Restrict PATH like the sibling Windows engine-miss tests so
# a host `opencode` on PATH cannot satisfy the probe instead of the default path.
fake_oc_home="$TMP/oc-default-home"
fake_oc_ver="$(tr -d ' \r\n' < "$ROOT/config/opencode/version" 2>/dev/null || echo 1.18.12)"
mkdir -p "$fake_oc_home/.local/lib/ai-devops/opencode/$fake_oc_ver/node_modules/opencode-ai/bin"
printf '#!/bin/sh\nexit 0\n' > "$fake_oc_home/.local/lib/ai-devops/opencode/$fake_oc_ver/node_modules/opencode-ai/bin/opencode.exe"
chmod +x "$fake_oc_home/.local/lib/ai-devops/opencode/$fake_oc_ver/node_modules/opencode-ai/bin/opencode.exe"
check "StepFun is usable on Windows via the default OpenCode install path" "HOME='$fake_oc_home' PATH=\"$WIN_TEST_PATH\" AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 $SCRIPT status stepfun | jq -e '.status==\"installed-healthy\" and .usable==true'"
mkdir -p "$TMP/noauth-home" "$TMP/noauth-config"
# AI_DEEPSEEK_TEST_DIR makes the wrapper honor this isolated HOME; production
# mode intentionally anchors the key store to the OS user profile instead.
NOAUTH_OUT="$(env -u DEEPSEEK_API_KEY HOME="$TMP/noauth-home" AI_DEEPSEEK_TEST_DIR="$TMP/noauth-home" AI_DEVOPS_CONFIG_DIR="$TMP/noauth-config" AI_REVIEW_DEEPSEEK_WRAPPER="$ROOT/bin/ai-deepseek-agent" "$SCRIPT" check deepseek "$REPO" 2>&1)"; NOAUTH_RC=$?
[ "$NOAUTH_RC" -ne 0 ] && ! printf '%s' "$NOAUTH_OUT" | grep -q 'health=ok' && ok "DeepSeek without key or governed reference cannot pass offline preflight" || bad "DeepSeek without key or governed reference cannot pass offline preflight"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true
export AI_REVIEW_MUSE_WRAPPER="$TMP/bin/requires-muse-caller"
check "Muse preflight supplies its mandatory caller identity" "$SCRIPT check muse '$REPO' | grep -q 'health=ok'"
check "Muse live preflight outlasts the short check budget" "AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_MUSE_WRAPPER='$TMP/bin/slow-muse-live' $SCRIPT check muse '$REPO' --live | grep -q 'health=ok'"
check "Muse live preflight still times out past its own budget" "AI_REVIEW_MUSE_QUALIFY_TIMEOUT=1 AI_REVIEW_MUSE_WRAPPER='$TMP/bin/slow-muse-live' $SCRIPT check muse '$REPO' --live 2>&1 | grep -q 'provider-timeout'"
"$SCRIPT" clear muse >/dev/null 2>&1 || true
check "Muse offline doctor outlasts the short check budget" "AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_MUSE_WRAPPER='$TMP/bin/slow-muse-doctor' $SCRIPT check muse '$REPO' | grep -q 'health=ok'"
"$SCRIPT" clear muse >/dev/null 2>&1 || true
check "Muse offline doctor still times out past its own budget" "AI_REVIEW_MUSE_DOCTOR_TIMEOUT=1 AI_REVIEW_MUSE_WRAPPER='$TMP/bin/slow-muse-doctor' $SCRIPT check muse '$REPO' 2>&1 | grep -q 'muse probe timed out'"
"$SCRIPT" clear muse >/dev/null 2>&1 || true

export AI_REVIEW_KIMI_WRAPPER="$TMP/bin/noauth"
export MOCK_PREFLIGHT_EVIDENCE_LOG="$TMP/evidence-operations"
export MOCK_PREFLIGHT_PACKET="$ROOT/bin/ai-review-packet"
export MOCK_PREFLIGHT_SANDBOX="$ROOT/bin/ai-review-sandbox"
cat > "$TMP/bin/packet-observer" <<'EOF'
#!/usr/bin/env bash
printf 'packet %s\n' "$1" >> "$MOCK_PREFLIGHT_EVIDENCE_LOG"
if [ "${MOCK_PREFLIGHT_VERIFY_FAIL:-0}" = 1 ] && [ "$1" = verify ]; then exit 79; fi
exec "$MOCK_PREFLIGHT_PACKET" "$@"
EOF
cat > "$TMP/bin/sandbox-observer" <<'EOF'
#!/usr/bin/env bash
printf 'sandbox %s\n' "$1" >> "$MOCK_PREFLIGHT_EVIDENCE_LOG"
exec "$MOCK_PREFLIGHT_SANDBOX" "$@"
EOF
chmod +x "$TMP/bin/packet-observer" "$TMP/bin/sandbox-observer"
START=$(date +%s); OUT="$(AI_REVIEW_PACKET_BIN="$TMP/bin/packet-observer" AI_REVIEW_SANDBOX_BIN="$TMP/bin/sandbox-observer" $SCRIPT check kimi "$REPO" 2>&1)"; RC=$?; ELAPSED=$(( $(date +%s) - START ))
[ "$RC" -ne 0 ] && ok "invalid Kimi credential fails" || bad "invalid Kimi credential fails"
[ "$ELAPSED" -lt 10 ] && ok "invalid Kimi credential fails under ten seconds" || bad "invalid Kimi credential fails under ten seconds"
[ ! -e "$MOCK_PREFLIGHT_EVIDENCE_LOG" ] && ok "unhealthy provider is rejected before preparing review evidence" || bad "unhealthy provider is rejected before preparing review evidence"
printf '%s' "$OUT" | grep -q authentication-failed && ok "authentication failure is classified" || bad "authentication failure is classified"
check "failed provider is quarantined with the shared status contract" "$SCRIPT status kimi | jq -e '.status==\"quarantined\" and .failure_class==\"authentication-failed\"'"

check "quarantine skips provider without contact" "echo old > '$TMP/contact'; AI_REVIEW_KIMI_WRAPPER='$TMP/contact' $SCRIPT check kimi '$REPO' 2>&1 | grep -q quarantined"
check "clear removes quarantine" "$SCRIPT clear kimi && $SCRIPT status kimi | grep -q installed-healthy"

OUT="$(AI_REVIEW_KIMI_WRAPPER="$TMP/bin/good" AI_REVIEW_PACKET_BIN="$TMP/bin/packet-observer" AI_REVIEW_SANDBOX_BIN="$TMP/bin/sandbox-observer" $SCRIPT check kimi "$REPO" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'packet=verified health=ok' && grep -qx 'sandbox ensure-copy' "$MOCK_PREFLIGHT_EVIDENCE_LOG" && grep -qx 'packet build' "$MOCK_PREFLIGHT_EVIDENCE_LOG" && grep -qx 'packet verify' "$MOCK_PREFLIGHT_EVIDENCE_LOG" && grep -qx 'packet remove' "$MOCK_PREFLIGHT_EVIDENCE_LOG" && grep -qx 'sandbox remove-copy' "$MOCK_PREFLIGHT_EVIDENCE_LOG" && ok "healthy provider retains complete isolated evidence checks and cleanup" || bad "healthy provider retains complete isolated evidence checks and cleanup"
OUT="$(MOCK_PREFLIGHT_VERIFY_FAIL=1 AI_REVIEW_KIMI_WRAPPER="$TMP/bin/good" AI_REVIEW_PACKET_BIN="$TMP/bin/packet-observer" $SCRIPT check kimi "$REPO" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && ! printf '%s' "$OUT" | grep -q 'health=ok' && ok "healthy doctor cannot bypass failed packet verification" || bad "healthy doctor cannot bypass failed packet verification"

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
check "GLM is back in the shipped reviewer registry (owner instruction 2026-09-30)" "jq -e '.providers.glm.registry_state==\"registered\" and (.providers.glm.reason|test(\"2026-09-30\"))' '$REAL_REGISTRY'"
check "DeepSeek V4.1 Flash is registered (shared-db REVIEWERS) and Codex is an approval gate only" "jq -e '.providers.deepseek.registry_state==\"registered\" and (.providers.codex.reason|test(\"NOT a rotation\"))' '$REAL_REGISTRY'"
check "the shipped registry is Muse, Grok, Qwen, Gemini, GLM, DeepSeek, the Codex gate, and Linux-only StepFun" "jq -e '[.providers|to_entries[]|select(.value.registry_state==\"registered\")|.key]|sort==[\"codex\",\"deepseek\",\"gemini\",\"glm\",\"grok\",\"muse\",\"qwen\",\"stepfun\"]' '$REAL_REGISTRY'"
check "Claude is out of the shipped reviewer pool (owner instruction 2026-09-30)" "jq -e '.providers.claude.registry_state==\"absent\" and (.providers.claude.reason|test(\"2026-09-30\"))' '$REAL_REGISTRY'"
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


echo '== scoped refusal admission'
PYTHON="$(command -v python3 || command -v python)"
check "scoped store expiry, migration, concurrency and killed-owner behavior" "'$PYTHON' '$ROOT/tests/test_reviewer_admission.py'"
printf 'synthetic terminal refusal\n' > "$TMP/refusal.json"
OBSERVED="$(date +%s)"
$SCRIPT clear kimi >/dev/null
check "terminal refusal creates policy backoff without quota claim" "$SCRIPT observe-refusal kimi --profile profile-a --model model-a --run-id run-a --observed '$OBSERVED' --seconds 120 --reason usage-limit --evidence '$TMP/refusal.json' | jq -e '.state==\"backoff\" and .quota_state==\"unknown\" and .reset_at==null'"
check "matching scope is not allocatable despite healthy install" "AI_REVIEW_ADMISSION_PROFILE=profile-a AI_REVIEW_ADMISSION_MODEL=model-a $SCRIPT status kimi | jq -e '.usable==false and .status==\"installed-healthy\" and .admission.state==\"backoff\"'"
$SCRIPT clear kimi >/dev/null
$SCRIPT observe-refusal kimi --profile profile-a --model model-a --run-id run-a --observed "$OBSERVED" --seconds 120 --reason usage-limit --evidence "$TMP/refusal.json" >/dev/null
check "different profile remains allocatable" "AI_REVIEW_ADMISSION_PROFILE=profile-b AI_REVIEW_ADMISSION_MODEL=model-a $SCRIPT usable kimi | jq -e '.usable==true'"
check "different model remains allocatable" "AI_REVIEW_ADMISSION_PROFILE=profile-a AI_REVIEW_ADMISSION_MODEL=model-b $SCRIPT usable kimi | jq -e '.usable==true'"
check "capacity remains unknown during policy backoff" "$SCRIPT capacity kimi --json | jq -e '.state==\"unknown\" and .reset_at==null'"
check "global quarantine update preserves scoped refusal" "$SCRIPT quarantine kimi authentication-failed --seconds 30 && $SCRIPT admission kimi --profile profile-a --model model-a --json | jq -e '.state==\"backoff\"'"

# A doctor cut off by the check budget is a timeout, even when its partial
# output mentions a credential (#720).
printf '#!/usr/bin/env bash\necho "credential    : managed 1Password reference"\nsleep 5\n' > "$TMP/bin/slow-cred"; chmod +x "$TMP/bin/slow-cred"
SLOW_OUT="$(AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_DOCTOR_PROBE_TIMEOUT=1 AI_REVIEW_LIVE_PROBE_TIMEOUT=1 AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/slow-cred" $SCRIPT check deepseek "$REPO" 2>&1)"
printf '%s' "$SLOW_OUT" | grep -q 'deepseek failed: provider-timeout' && ok "timed-out doctor is classified as a timeout, not an auth failure" || bad "timed-out doctor is classified as a timeout, not an auth failure"

echo '== P7 timeout diagnosis: bounded probe, timeout-is-not-identity, timeout-never-approves'

# probe_first_call_bounded: a hanging first probe terminates and leaves no child.
printf '#!/usr/bin/env bash\nsleep 30\n' > "$TMP/bin/hang-first"; chmod +x "$TMP/bin/hang-first"
HANG_START=$(date +%s)
HANG_OUT="$(AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_DOCTOR_PROBE_TIMEOUT=1 AI_REVIEW_LIVE_PROBE_TIMEOUT=1 AI_REVIEW_TIMEOUT_RETRY_DELAY=0 AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/hang-first" $SCRIPT check deepseek "$REPO" 2>&1)"; HANG_RC=$?
HANG_ELAPSED=$(( $(date +%s) - HANG_START ))
check "probe_first_call_bounded" "[ '$HANG_RC' -ne 0 ] && [ '$HANG_ELAPSED' -lt 15 ] && printf '%s' '$HANG_OUT' | grep -q 'provider-timeout'"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true

# probe_timeout_not_identity_failure: timeout exit status is classified as
# provider-timeout, not authentication-failed or provider-unhealthy.
printf '#!/usr/bin/env bash\nsleep 5\n' > "$TMP/bin/hang-clean"; chmod +x "$TMP/bin/hang-clean"
TOUT="$(AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_DOCTOR_PROBE_TIMEOUT=1 AI_REVIEW_LIVE_PROBE_TIMEOUT=1 AI_REVIEW_TIMEOUT_RETRY_DELAY=0 AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/hang-clean" $SCRIPT check deepseek "$REPO" 2>&1)"
printf '%s' "$TOUT" | grep -q 'deepseek failed: provider-timeout' && ! printf '%s' "$TOUT" | grep -qE 'authentication-failed|provider-unhealthy|identity' && ok "probe_timeout_not_identity_failure" || bad "probe_timeout_not_identity_failure"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true

# probe_timeout_never_approves: a transient timeout never yields health=ok.
printf '#!/usr/bin/env bash\nsleep 5\n' > "$TMP/bin/hang-approve"; chmod +x "$TMP/bin/hang-approve"
AOUT="$(AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_DOCTOR_PROBE_TIMEOUT=1 AI_REVIEW_LIVE_PROBE_TIMEOUT=1 AI_REVIEW_TIMEOUT_RETRY_DELAY=0 AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/hang-approve" $SCRIPT check deepseek "$REPO" 2>&1)"; ARC=$?
[ "$ARC" -ne 0 ] && ! printf '%s' "$AOUT" | grep -q 'health=ok' && ok "probe_timeout_never_approves" || bad "probe_timeout_never_approves"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true

# Empty probe output is probe-no-output, not provider-unhealthy.
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/empty-out"; chmod +x "$TMP/bin/empty-out"
EOUT="$(AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/empty-out" $SCRIPT check deepseek "$REPO" 2>&1)"
printf '%s' "$EOUT" | grep -q 'probe-no-output' && ! printf '%s' "$EOUT" | grep -q 'provider-unhealthy' && ok "empty probe output is probe-no-output" || bad "empty probe output is probe-no-output"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true

# Transient timeout uses a short cooldown; auth failure uses the full cooldown.
printf '#!/usr/bin/env bash\nsleep 5\n' > "$TMP/bin/hang-cool"; chmod +x "$TMP/bin/hang-cool"
AI_REVIEW_PREFLIGHT_TIMEOUT=1 AI_REVIEW_DOCTOR_PROBE_TIMEOUT=1 AI_REVIEW_LIVE_PROBE_TIMEOUT=1 AI_REVIEW_TIMEOUT_RETRY_DELAY=0 AI_REVIEW_TIMEOUT_COOLDOWN_SECONDS=7 AI_REVIEW_DEEPSEEK_WRAPPER="$TMP/bin/hang-cool" $SCRIPT check deepseek "$REPO" >/dev/null 2>&1 || true
COOL_STATUS="$($SCRIPT status deepseek)"
printf '%s' "$COOL_STATUS" | jq -e '.failure_class=="provider-timeout"' >/dev/null && ok "timeout quarantine records provider-timeout" || bad "timeout quarantine records provider-timeout"
"$SCRIPT" clear deepseek >/dev/null 2>&1 || true

# Drift is reported as drift, not as a timeout.
check "drift is reported as drift" "$SCRIPT explain provider-timeout | grep -q 'transient liveness' && $SCRIPT explain authentication-failed | grep -q 'Quarantine'"

# #1346: the public pause interface preserves a stronger credit hold atomically.
"$SCRIPT" quarantine grok out-of-credit --seconds 7200 >/dev/null 2>&1
PAUSE_JSON="$($SCRIPT pause grok wrapper-crash --seconds 3600)"
printf '%s' "$PAUSE_JSON" | jq -e --argjson minimum "$(( $(date +%s) + 7000 ))" '.failure_class=="out-of-credit" and .expires_epoch >= $minimum' >/dev/null && ok "failure pause preserves stronger credit hold" || bad "failure pause preserves stronger credit hold"
"$SCRIPT" pause grok wrapper-crash --seconds 30 >/dev/null 2>&1 && bad "failure pause refuses wrong duration" || ok "failure pause refuses wrong duration"
"$SCRIPT" pause grok '' --seconds 3600 >/dev/null 2>&1 && bad "failure pause refuses unnamed cause" || ok "failure pause refuses unnamed cause"
"$SCRIPT" clear grok >/dev/null 2>&1
OBSERVED_PAUSE="$(( $(date +%s) - 120 ))"
PAUSE_INITIAL="$($SCRIPT pause grok provider-timeout --observed "$OBSERVED_PAUSE" --seconds 3600)"
PAUSE_READBACK="$($SCRIPT pause-status grok)"
[ "$PAUSE_INITIAL" = "$PAUSE_READBACK" ] && ok "pause-status reads exact persisted hold" || bad "pause-status reads exact persisted hold"
PAUSE_RETRY="$($SCRIPT pause grok provider-timeout --seconds 3600 --observed "$OBSERVED_PAUSE")"
[ "$PAUSE_INITIAL" = "$PAUSE_RETRY" ] && ok "observed failure retry never extends original hour" || bad "observed failure retry never extends original hour"
PAUSE_EXPIRED="$($SCRIPT pause grok provider-timeout --observed 0 --seconds 3600)"
printf '%s' "$PAUSE_EXPIRED" | jq -e '.status=="expired"' >/dev/null && [ "$PAUSE_READBACK" = "$($SCRIPT pause-status grok)" ] && ok "expired historical pause leaves current hold untouched" || bad "expired historical pause leaves current hold untouched"
"$SCRIPT" pause grok provider-timeout --observed "$(( $(date +%s) + 3600 ))" >/dev/null 2>&1 && bad "pause refuses future observation" || ok "pause refuses future observation"
"$SCRIPT" pause grok provider-timeout --observed malformed >/dev/null 2>&1 && bad "pause refuses malformed observation" || ok "pause refuses malformed observation"
"$SCRIPT" clear grok >/dev/null 2>&1

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
