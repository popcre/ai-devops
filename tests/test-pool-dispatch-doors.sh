#!/usr/bin/env bash
# Focused verification of the re-scoped pool dispatch contract (all six
# providers are registered runner doors). Mirrors the checks in
# tests/test-ai-grok-review.sh's pool section, which the suite's known-flaky
# wall-clock interrupt section prevents from being reached in a full run.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POOL="$REPO_ROOT/bin/ai-review-pool"
DOORS_JSON="$REPO_ROOT/config/review-runner-doors.json"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

export AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none
POOLTMP="$(mktemp -d)"
trap 'rm -rf "$POOLTMP"' EXIT

check "all_six_pool_providers_are_registered_doors" \
  "for p in grok muse qwen gemini deepseek stepfun; do jq -e --arg p \"\$p\" 'has(\$p)' '$DOORS_JSON' >/dev/null || exit 1; done"
check "pool_usage_lists_stepfun" "grep -q 'stepfun' '$POOL' && grep -q 'AI_POOL_RUNNER_STEPFUN' '$POOL'"
check "pool_keeps_legacy_fallback_for_future_unregistered_providers" \
  "grep -q 'Legacy session-runner fallback only' '$POOL'"

mkdir -p "$POOLTMP/fakerepo"
git -C "$POOLTMP/fakerepo" init -q -b main
git -C "$POOLTMP/fakerepo" config user.name Test
git -C "$POOLTMP/fakerepo" config user.email t@example.com
printf 'x\n' > "$POOLTMP/fakerepo/a.txt"
git -C "$POOLTMP/fakerepo" add a.txt
git -C "$POOLTMP/fakerepo" commit -qm init
printf '.ai/\n' > "$POOLTMP/fakerepo/.gitignore"
git -C "$POOLTMP/fakerepo" add .gitignore
git -C "$POOLTMP/fakerepo" commit -qm ignore

cat > "$POOLTMP/packet" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$POOLTMP/lifecycle" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$POOLTMP/engine" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$POOLTMP/engine-args"
exit 0
EOF
chmod +x "$POOLTMP/packet" "$POOLTMP/lifecycle" "$POOLTMP/engine"
export_pool() {
  export AI_REVIEW_PACKET_BIN="$POOLTMP/packet" AI_REVIEW_LIFECYCLE_BIN="$POOLTMP/lifecycle" \
         AI_REVIEW_ENGINE_BIN="$POOLTMP/engine" AI_POOL_TEST_HOOKS=1 AI_POOL_CALLER=zcode-test \
         AI_REVIEW_EVENT_DIR="$POOLTMP/events"
  mkdir -p "$POOLTMP/events"
}
engargs(){ cat "$POOLTMP/engine-args" 2>/dev/null; }

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" qwen security-review ) > "$POOLTMP/out-approve" 2>&1
RC_APPROVE=$?
check "pool_dispatches_qwen_through_engine" "[ '$RC_APPROVE' -eq 0 ] && engargs | grep -q -- '--provider qwen'"
check "pool_dispatch_names_carry_provider_and_mode" "engargs | grep -q -- '--name pool-qwen-security-review'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" muse final-check ) > "$POOLTMP/out-muse" 2>&1
RC_MUSE=$?
MUSE_TAG="$(engargs | tr ' ' '\n' | grep -A1 '^--name$' | tail -1)"
check "pool_muse_session_name_fits_native_limit" "[ '$RC_MUSE' -eq 0 ] && [ -n '$MUSE_TAG' ] && [ '${#MUSE_TAG}' -le 40 ] && [[ '$MUSE_TAG' == pool-muse-* ]]"
check "pool_muse_argv_omits_max_turns" "engargs | grep -q -- '--provider muse' && ! engargs | grep -q -- '--max-turns'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" gemini final-check ) > "$POOLTMP/out-gemini" 2>&1
RC_GEMINI=$?
GEMINI_TAG="$(engargs | tr ' ' '\n' | grep -A1 '^--name$' | tail -1)"
check "pool_gemini_session_name_fits_derived_sandbox_limit" "[ '$RC_GEMINI' -eq 0 ] && [ -n '$GEMINI_TAG' ] && [ $(( 7 + 12 + 1 + 10 + 1 + ${#GEMINI_TAG} )) -le 64 ] && [[ '$GEMINI_TAG' == pool-gemini-* ]]"
check "pool_gemini_argv_omits_max_turns" "engargs | grep -q -- '--provider gemini' && ! engargs | grep -q -- '--max-turns'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" qwen final-check ) > "$POOLTMP/out-qwen" 2>&1
RC_QWEN=$?
check "pool_qwen_dispatch_omits_max_turns" "[ '$RC_QWEN' -eq 0 ] && engargs | grep -q -- '--provider qwen' && ! engargs | grep -q -- '--max-turns'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" stepfun final-check ) > "$POOLTMP/out-stepfun" 2>&1
RC_STEPFUN=$?
check "pool_dispatches_stepfun_through_engine" "[ '$RC_STEPFUN' -eq 0 ] && engargs | grep -q -- '--provider stepfun'"
check "pool_stepfun_argv_omits_max_turns" "engargs | grep -q -- '--provider stepfun' && ! engargs | grep -q -- '--max-turns'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && AI_REVIEW_OPERATION=legacy-managed-launcher-refresh bash "$POOL" qwen final-check ) > "$POOLTMP/out-op" 2>&1
RC_OP=$?
check "pool_operation_forwarded_to_engine" "[ '$RC_OP' -eq 0 ] && engargs | grep -q -- '--operation legacy-managed-launcher-refresh'"

OP_ENG_BEFORE="$(engargs | grep -c -- '--provider' || true)"
( cd "$POOLTMP/fakerepo" && export_pool && AI_REVIEW_OPERATION=not-an-operation bash "$POOL" qwen final-check ) > "$POOLTMP/out-opbad" 2>&1
RC_OPBAD=$?
check "pool_unknown_operation_never_dispatches" "[ '$RC_OPBAD' -ne 0 ] && grep -q 'unknown review operation' '$POOLTMP/out-opbad' && [ \"\$(engargs | grep -c -- '--provider' || true)\" -eq '$OP_ENG_BEFORE' ]"

OP_ENG_BEFORE="$(engargs | grep -c -- '--provider' || true)"
( cd "$POOLTMP/fakerepo" && export_pool && AI_REVIEW_OPERATION=first-managed-install bash "$POOL" qwen security-review ) > "$POOLTMP/out-opmode" 2>&1
RC_OPMODE=$?
check "pool_operation_outside_final_check_never_dispatches" "[ '$RC_OPMODE' -ne 0 ] && grep -qi 'final-check' '$POOLTMP/out-opmode' && [ \"\$(engargs | grep -c -- '--provider' || true)\" -eq '$OP_ENG_BEFORE' ]"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && unset AI_REVIEW_OPERATION && bash "$POOL" qwen final-check ) > /dev/null 2>&1
check "pool_without_operation_omits_the_flag" "! engargs | grep -q -- '--operation'"

rm -f "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && bash "$POOL" grok security-review ) > "$POOLTMP/out-grkeng" 2>&1
check "pool_grok_argv_keeps_max_turns" "grep -q -- '--provider grok' '$POOLTMP/engine-args' && grep -q -- '--max-turns 120' '$POOLTMP/engine-args'"

# A plain runner substitution for a registered door is a bypass and is refused.
cat > "$POOLTMP/not-the-engine" <<'EOF'
#!/usr/bin/env bash
echo "must never be used" >&2
exit 99
EOF
chmod +x "$POOLTMP/not-the-engine"
set +e
( cd "$POOLTMP/fakerepo" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_MUSE="$POOLTMP/not-the-engine" \
    AI_REVIEW_PACKET_BIN="$POOLTMP/packet" AI_REVIEW_LIFECYCLE_BIN="$POOLTMP/lifecycle" \
    AI_REVIEW_ENGINE_BIN="$POOLTMP/engine" AI_POOL_CALLER=codex bash "$POOL" muse diff-review ) \
  > "$POOLTMP/out-bypass" 2>&1
BYPASS_RC=$?
set -e
check "pool_refuses_runner_substitution_for_registered_door" \
  "test '$BYPASS_RC' -ne 0 && grep -q 'bypasses the shared review runner' '$POOLTMP/out-bypass' && ! grep -q 'must never be used' '$POOLTMP/out-bypass'"

echo
echo "test-pool-dispatch-doors: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
