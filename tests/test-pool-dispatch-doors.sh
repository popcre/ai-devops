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

# Cache-stable brief (#1430): briefs for two different heads share an identical
# byte prefix through the decision text and verdict format; per-review facts
# (head SHA, digest) come only after it, and the head SHA is still quoted.
# The engine's rlc_write_brief is the brief every registered door receives.
HEAD1=1111111111111111111111111111111111111111; HEAD2=2222222222222222222222222222222222222222
( . "$REPO_ROOT/tools/lib/review-lifecycle-core.sh" \
  && rlc_write_brief "$POOLTMP/brief1" final-check "$HEAD1" digest-one "$POOLTMP/copy-one" .ai/pkt-one 'Decide the fixed question.' 'exit 0' 'a.txt' \
  && rlc_write_brief "$POOLTMP/brief2" final-check "$HEAD2" digest-two "$POOLTMP/copy-two" .ai/pkt-two 'Decide the fixed question.' 'exit 1' 'b.txt' ) > /dev/null 2>&1
prefix_through_verdict(){ sed -n '1,/^APPROVE|REJECT|BLOCKED$/p' "$1"; }
check "brief_prefix_stable_across_heads" \
  "grep -qx 'APPROVE|REJECT|BLOCKED' '$POOLTMP/brief1' && prefix_through_verdict '$POOLTMP/brief1' | grep -q 'Decide the fixed question.' && [ \"\$(prefix_through_verdict '$POOLTMP/brief1')\" = \"\$(prefix_through_verdict '$POOLTMP/brief2')\" ] && ! prefix_through_verdict '$POOLTMP/brief1' | grep -qE '$HEAD1|digest-one|copy-one|a.txt'"
check "brief_run_facts_carry_head_sha_last" \
  "sed -n '/^## RUN FACTS/,\$p' '$POOLTMP/brief1' | grep -q 'The reviewed head commit is $HEAD1' && sed -n '/^## RUN FACTS/,\$p' '$POOLTMP/brief2' | grep -q 'The reviewed head commit is $HEAD2' && sed -n '/^## RUN FACTS/,\$p' '$POOLTMP/brief1' | grep -q 'copy-one/.ai/pkt-one/MANIFEST.md' && grep -q 'MUST quote the full reviewed head SHA' '$POOLTMP/brief1'"
# The legacy pool brief keeps the same order: no per-run value before RUN FACTS.
check "pool_legacy_brief_run_facts_last" \
  "awk '/^cat <<BRIEF\$/{on=1;next} on&&/^## RUN FACTS/{exit} on' '$POOL' | grep -q DECISION && ! awk '/^cat <<BRIEF\$/{on=1;next} on&&/^## RUN FACTS/{exit} on' '$POOL' | grep -qE 'REVIEW_HEAD|REVIEW_DIGEST|CHANGED_FILES|TESTS_'"

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

# ---------------------------------------------------------------------------
# Passing-report reuse (#1428): the same reviewer, mode, head, whole-source
# digest, repository and base returns the earlier APPROVE with no provider
# call; any difference, --force, or a lookup error dispatches normally.
# ---------------------------------------------------------------------------
set +e
REUSE_HEAD="$(git -C "$POOLTMP/fakerepo" rev-parse HEAD)"
REUSE_KEY="$(printf 'key' | sha256sum | cut -d' ' -f1)"
REUSE_DIGEST="$(printf 'digest' | sha256sum | cut -d' ' -f1)"
OTHER_DIGEST="$(printf 'other' | sha256sum | cut -d' ' -f1)"
LCDIR="$POOLTMP/lifecycle-store"
cat > "$POOLTMP/lifecycle-id" <<EOF
#!/usr/bin/env bash
if [ "\$1" = identity ]; then
  jq -nc --arg h "$REUSE_HEAD" --arg d "\${FAKE_DIGEST:-$REUSE_DIGEST}" --arg k "$REUSE_KEY" '{schema_version:1,head:\$h,source_digest:\$d,repository_key:\$k}'
fi
exit 0
EOF
chmod +x "$POOLTMP/lifecycle-id"
make_pass(){ # make_pass PROVIDER MODE RUN VERDICT [HEAD]
  local provider="$1" mode="$2" run="$3" verdict="$4" head="${5:-$REUSE_HEAD}" report sha
  mkdir -p "$POOLTMP/fakerepo/.ai/reviews" "$LCDIR/runs/$REUSE_KEY/$provider/zcode"
  report="$POOLTMP/fakerepo/.ai/reviews/$provider-$mode-$run.md"
  printf '# %s %s\n\n| field | value |\n|---|---|\n| reviewed commit | `%s` |\n| source digest | `%s` |\n\n## Result\n\nAnalysis of %s.\n\n## Verdict\n%s\n' \
    "$provider" "$mode" "$head" "$REUSE_DIGEST" "$head" "$verdict" > "$report"
  sha="$(sha256sum "$report" | cut -d' ' -f1)"
  jq -n --arg p "$provider" --arg m "$mode" --arg r "$run" --arg v "$verdict" --arg h "$head" --arg d "$REUSE_DIGEST" \
    --arg k "$REUSE_KEY" --arg rp "$report" --arg s "$sha" \
    '{schema_version:1,status:"completed",provider:$p,run_id:$r,caller:"zcode",review_mode:$m,base:null,repository_key:$k,head:$h,source_digest:$d,verdict:$v,failure_class:null,report_path:$rp,report_sha256:$s,stale:false,finished_at:"2026-10-07T00:00:00Z"}' \
    > "$LCDIR/runs/$REUSE_KEY/$provider/zcode/$run.json"
}
reuse_run(){ # reuse_run OUT PROVIDER MODE [ARGS...]
  local out="$1"; shift
  rm -f "$POOLTMP/engine-args"
  ( cd "$POOLTMP/fakerepo" && export_pool && export AI_REVIEW_LIFECYCLE_BIN="$POOLTMP/lifecycle-id" AI_REVIEW_LIFECYCLE_DIR="$LCDIR" && bash "$POOL" "$@" ) > "$POOLTMP/$out" 2> "$POOLTMP/$out.err"
}
make_pass qwen diff-review 20261007T000000-1-1 APPROVE
reuse_run reuse-1 qwen diff-review; RC=$?
check "reuse_same_head_digest" "[ '$RC' -eq 0 ] && [ ! -e '$POOLTMP/engine-args' ] && [ \"\$(tail -1 '$POOLTMP/reuse-1')\" = '$POOLTMP/fakerepo/.ai/reviews/qwen-diff-review-20261007T000000-1-1.md' ] && grep -q 'no provider call' '$POOLTMP/reuse-1.err'"
reuse_run reuse-2 qwen diff-review; RC=$?
check "reuse_second_identical_run_makes_zero_provider_calls" "[ '$RC' -eq 0 ] && [ ! -e '$POOLTMP/engine-args' ]"
FAKE_DIGEST="$OTHER_DIGEST" reuse_run reuse-digest qwen diff-review
check "no_reuse_on_digest_change" "engargs | grep -q -- '--provider qwen'"
reuse_run reuse-mode qwen final-check
check "no_reuse_on_mode_change" "engargs | grep -q -- '--mode final-check'"
reuse_run reuse-provider stepfun diff-review
check "no_reuse_for_another_provider" "engargs | grep -q -- '--provider stepfun'"
reuse_run reuse-force qwen diff-review --force
check "force_bypasses_reuse" "engargs | grep -q -- '--provider qwen' && ! engargs | grep -q -- '--force' && grep -q -- '--force given' '$POOLTMP/reuse-force.err'"
reuse_run reuse-base qwen diff-review --base HEAD~1
check "no_reuse_on_base_change" "engargs | grep -q -- '--base HEAD~1'"
make_pass gemini diff-review 20261007T000000-1-2 REJECT
reuse_run reuse-reject gemini diff-review
check "no_reuse_of_a_reject" "engargs | grep -q -- '--provider gemini'"
make_pass muse diff-review 20261007T000000-1-3 APPROVE 0000000000000000000000000000000000000000
reuse_run reuse-head muse diff-review
check "no_reuse_on_head_change" "engargs | grep -q -- '--provider muse'"
make_pass deepseek diff-review 20261007T000000-1-4 APPROVE
printf 'tampered\n' >> "$POOLTMP/fakerepo/.ai/reviews/deepseek-diff-review-20261007T000000-1-4.md"
reuse_run reuse-tamper deepseek diff-review
check "no_reuse_of_a_changed_report" "engargs | grep -q -- '--provider deepseek'"
make_pass qwen final-check 20261007T000000-1-5 APPROVE
AI_REVIEW_OPERATION=legacy-managed-launcher-refresh reuse_run reuse-op qwen final-check
check "no_reuse_for_a_review_operation" "engargs | grep -q -- '--operation legacy-managed-launcher-refresh'"
printf '{not json' > "$LCDIR/runs/$REUSE_KEY/qwen/zcode/corrupt.json"
reuse_run reuse-corrupt qwen diff-review; RC=$?
check "corrupt_events_falls_through" "[ '$RC' -eq 0 ] && engargs | grep -q -- '--provider qwen' && grep -q 'lookup unavailable; running a normal review' '$POOLTMP/reuse-corrupt.err'"
rm -f "$LCDIR/runs/$REUSE_KEY/qwen/zcode/corrupt.json" "$POOLTMP/engine-args"
( cd "$POOLTMP/fakerepo" && export_pool && AI_REVIEW_LIFECYCLE_DIR="$LCDIR" bash "$POOL" qwen diff-review ) > /dev/null 2> "$POOLTMP/reuse-noid.err"
check "identity_failure_falls_through" "engargs | grep -q -- '--provider qwen' && grep -q 'lookup unavailable' '$POOLTMP/reuse-noid.err'"
reuse_run reuse-tests qwen diff-review --tests true
check "no_reuse_when_tests_requested" "engargs | grep -q -- '--tests true' && grep -q -- '--tests given' '$POOLTMP/reuse-tests.err'"
make_pass glm diff-review 20261007T000000-1-6 APPROVE
jq '.base="ffffffffffffffffffffffffffffffffffffffff"' "$LCDIR/runs/$REUSE_KEY/glm/zcode/20261007T000000-1-6.json" > "$POOLTMP/b.json" && mv "$POOLTMP/b.json" "$LCDIR/runs/$REUSE_KEY/glm/zcode/20261007T000000-1-6.json"
( cd "$POOLTMP/fakerepo" && AI_REVIEW_LIFECYCLE_DIR="$LCDIR" python3 "$REPO_ROOT/tools/reviewer_events.py" find-passing-report glm diff-review "$REUSE_HEAD" "$REUSE_DIGEST" "$REUSE_KEY" ) > "$POOLTMP/unresolved-base" 2>&1
make_pass glm final-check 20261007T000000-1-8 APPROVE
( cd "$POOLTMP/fakerepo" && AI_REVIEW_LIFECYCLE_DIR="$LCDIR" python3 "$REPO_ROOT/tools/reviewer_events.py" find-passing-report glm final-check "$REUSE_HEAD" "$REUSE_DIGEST" "$REUSE_KEY" ) > "$POOLTMP/resolved-control" 2>&1
check "no_reuse_when_recorded_base_unresolvable" "grep -qx null '$POOLTMP/unresolved-base' && grep -q '\"provider\": \"glm\"' '$POOLTMP/resolved-control'"
make_pass qwen diff-review 20261007T000000-1-7 REJECT
jq '.finished_at="2026-10-08T00:00:00Z"' "$LCDIR/runs/$REUSE_KEY/qwen/zcode/20261007T000000-1-7.json" > "$POOLTMP/r.json" && mv "$POOLTMP/r.json" "$LCDIR/runs/$REUSE_KEY/qwen/zcode/20261007T000000-1-7.json"
reuse_run reuse-newer-reject qwen diff-review
check "newer_reject_supersedes_older_approve" "engargs | grep -q -- '--provider qwen'"

echo
echo "test-pool-dispatch-doors: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
