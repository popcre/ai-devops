#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-model-call"; GATE="$ROOT/bin/ai-review"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }; check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q; git -C "$R" config user.name T; git -C "$R" config user.email t@e; echo x > "$R/a"; git -C "$R" add a; git -C "$R" commit -qm i; echo prompt > "$TMP/prompt"
STUB="$TMP/codex"; cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null; printf 'model-output\n'
EOF
REVIEW="$TMP/review"; cat > "$REVIEW" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$AI_MODEL_TEST_REVIEW_ARGS"; printf '# governed\n\n## Verdict\nAPPROVE\n' > "$AI_MODEL_TEST_REPORT"; printf '%s\n' "$AI_MODEL_TEST_REPORT"
EOF
chmod +x "$STUB" "$REVIEW"; GOOD="$TMP/good.env"; printf "CODEX_PLAN_CMD='%s exec -m gpt-5.6-sol --sandbox read-only -c model_reasoning_effort=medium'\nCODEX_IMPLEMENT_CMD='%s exec -m gpt-5.6-sol --sandbox workspace-write -c model_reasoning_effort=medium'\nCODEX_TEST_CMD='%s exec -m gpt-5.6-sol --sandbox workspace-write -c model_reasoning_effort=medium'\n" "$STUB" "$STUB" "$STUB" > "$GOOD"
export AI_DEVOPS_MODELS_ENV="$GOOD" AI_REVIEW_BIN="$REVIEW" AI_MODEL_TEST_REVIEW_ARGS="$TMP/review.args" AI_MODEL_TEST_REPORT="$TMP/review.md"
echo '== ai-model-call and ai-review gate'
check 'read-only plan command succeeds' "cd '$R' && '$SCRIPT' plan '$TMP/prompt' '$TMP/plan.out'"
check 'writable implementation command succeeds' "cd '$R' && '$SCRIPT' implement '$TMP/prompt' '$TMP/impl.out'"
check 'review routes through supported Claude gate' "cd '$R' && '$SCRIPT' plan-review '$TMP/prompt' '$TMP/review.out' && grep -qx 'claude plan-review' '$TMP/review.args'"
check 'review output is copied as immutable artifact' "grep -q '^APPROVE$' '$TMP/review.out'"
check 'existing output is never replaced' "cd '$R' && ! '$SCRIPT' plan '$TMP/prompt' '$TMP/plan.out'"
BAD="$TMP/bad.env"; printf "CODEX_PLAN_CMD='%s exec -m gpt-5.6-sol --sandbox read-only -c model_reasoning_effort=high'\n" "$STUB" > "$BAD"
check 'unsupported Codex reasoning is refused' "cd '$R' && ! AI_DEVOPS_MODELS_ENV='$BAD' '$SCRIPT' plan '$TMP/prompt' '$TMP/bad.out'"
INJECT="$TMP/inject.env"; printf "CODEX_PLAN_CMD='%s exec -m gpt-5.6-sol --sandbox read-only -c model_reasoning_effort=medium; touch BAD'\n" "$STUB" > "$INJECT"
check 'shell operators in config are refused' "cd '$R' && ! AI_DEVOPS_MODELS_ENV='$INJECT' '$SCRIPT' plan '$TMP/prompt' '$TMP/inject.out' && test ! -e '$R/BAD'"
check 'advisory provider cannot satisfy gate' "cd '$R' && ! '$GATE' qwen diff-review >/dev/null 2>&1"
check 'unknown stage is rejected' "cd '$R' && ! '$SCRIPT' nope '$TMP/prompt' '$TMP/nope.out'"
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
