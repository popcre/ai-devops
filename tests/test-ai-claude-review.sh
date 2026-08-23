#!/usr/bin/env bash
# Offline trust tests for the Claude Opus 5 approval adapter.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-claude-review"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q; git -C "$R" config user.name Test; git -C "$R" config user.email t@example.com
printf '.ai/\n' > "$R/.gitignore"; printf 'base\n' > "$R/a.txt"; git -C "$R" add .gitignore a.txt; git -C "$R" commit -qm init
printf 'changed\n' >> "$R/a.txt"; printf 'new\n' > "$R/new file.txt"; printf '\000\377' > "$R/new.bin"
STUB="$TMP/claude-stub"; cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$AI_CLAUDE_TEST_ARGS/args-$$"
prompt="$(cat)"; printf '%s' "$prompt" > "$AI_CLAUDE_TEST_ARGS/prompt-$$"
[ -f "new file.txt" ] && [ -f new.bin ] || { printf '%s' "$prompt" | grep -q OPUS5_ACCESS_OK || exit 8; }
case "${AI_CLAUDE_STUB_MODE:-success}" in
  fail) exit 7;; malformed) printf 'not-json\n'; exit 0;; wrong-model) model=claude-sonnet-5;;
  canonical-mismatch) model=claude-opus-5;;
  mutate) printf 'write\n' >> a.txt; model=claude-opus-5;;
  mutate-source) printf 'write\n' >> "$AI_CLAUDE_STUB_SOURCE/a.txt"; model=claude-opus-5;;
  missing) model=claude-opus-5;; slow) sleep 1; model=claude-opus-5;; *) model=claude-opus-5;; esac
if printf '%s' "$prompt" | grep -q OPUS5_ACCESS_OK; then result=OPUS5_ACCESS_OK
elif [ "${AI_CLAUDE_STUB_MODE:-}" = missing ]; then result='findings only'
else result=$'review saw complete snapshot\n\n## Verdict\nAPPROVE'; fi
case "${AI_CLAUDE_STUB_MODE:-success}" in
  no-canonical) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{inputTokens:1}}}' ;;
  canonical-mismatch) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:"claude-sonnet-5"}}}' ;;
  auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-haiku-4-5-20251001":{canonicalModel:"claude-haiku-4-5",provider:"firstParty"}}}' ;;
  legacy-auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-3-5-haiku-20241022":{canonicalModel:"claude-3-5-haiku-20241022",provider:"firstParty"}}}' ;;
  foreign-auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-sonnet-5":{canonicalModel:"claude-sonnet-5",provider:"firstParty"}}}' ;;
  scalar-auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-haiku-4-5-20251001":7}}' ;;
  unproven-auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-haiku-4-5-20251001":{canonicalModel:"claude-haiku-4-5"}}}' ;;
  uncanonical-auxiliary) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model},"claude-haiku-4-5-20251001":{provider:"firstParty"}}}' ;;
  *) jq -nc --arg result "$result" --arg model "$model" '{is_error:false,result:$result,session_id:"claude-test-session",permission_denials:[],modelUsage:{($model):{canonicalModel:$model}}}' ;;
esac
EOF
chmod +x "$STUB"; mkdir -p "$TMP/args"
MODELS="$TMP/models.env"; printf "CLAUDE_REVIEW_CMD='%s -p --model claude-opus-5 --effort high --output-format json --permission-mode plan --tools Read,Grep,Glob --strict-mcp-config --mcp-config {\\\"mcpServers\\\":{}} --no-session-persistence --no-chrome --disable-slash-commands'\n" "$STUB" > "$MODELS"
export AI_DEVOPS_MODELS_ENV="$MODELS" AI_CLAUDE_TEST_ARGS="$TMP/args" AI_CLAUDE_STUB_SOURCE="$R"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/lifecycle" AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"

echo '== ai-claude-review'
check 'doctor proves exact model and tool boundary' "cd '$R' && '$SCRIPT' doctor | grep -q 'model=claude-opus-5 tools=Read,Grep,Glob permission=plan'"
check 'live doctor proves canonical returned model' "cd '$R' && '$SCRIPT' doctor --live | grep -q 'live=verified'"
check 'live doctor accepts the current exact-key envelope without canonicalModel' "cd '$R' && AI_CLAUDE_STUB_MODE=no-canonical '$SCRIPT' doctor --live | grep -q 'live=verified'"
check 'live doctor accepts the first-party Haiku helper in the current envelope' "cd '$R' && AI_CLAUDE_STUB_MODE=auxiliary '$SCRIPT' doctor --live | grep -q 'live=verified'"
check 'live doctor accepts a proven legacy first-party Haiku helper' "cd '$R' && AI_CLAUDE_STUB_MODE=legacy-auxiliary '$SCRIPT' doctor --live | grep -q 'live=verified'"
BEFORE="$($ROOT/bin/ai-review-sandbox digest "$R")"; OUT="$(cd "$R" && "$SCRIPT" diff-review)"
check 'successful review publishes report' "test -s '$OUT'"
check 'report identifies canonical Opus 5' "grep -q 'model.*claude-opus-5' '$OUT'"
check 'report contains exact verdict' "grep -A1 '^## Verdict' '$OUT' | tail -1 | grep -qx APPROVE"
check 'provider saw complete untracked snapshot' "grep -q 'review saw complete snapshot' '$OUT'"
check 'provider receives only read grep glob tools' "grep -Rzq -- 'Read,Grep,Glob' '$TMP/args' && ! grep -Rzq -- 'Bash,\|Write,\|Edit,' '$TMP/args'"
check 'source remains unchanged' "[ '$BEFORE' = \"\$('$ROOT/bin/ai-review-sandbox' digest '$R')\" ]"
check 'lifecycle records Claude completion' "find '$TMP/lifecycle/runs' -name '*.json' -exec jq -e 'select(.provider==\"claude\" and .status==\"completed\" and .verdict==\"APPROVE\")' {} \; | grep -q APPROVE"
check 'scoreboard records Claude current result' "jq -e 'select(.provider==\"claude\" and .evidence_state==\"current\" and .verdict==\"APPROVE\")' '$TMP/scoreboard/reviews.jsonl'"
NO_CANONICAL_OUT="$(cd "$R" && AI_CLAUDE_STUB_MODE=no-canonical "$SCRIPT" security-review)"
check 'review accepts the current exact-key envelope without canonicalModel' "test -s '$NO_CANONICAL_OUT' && grep -A1 '^## Verdict' '$NO_CANONICAL_OUT' | tail -1 | grep -qx APPROVE"
AUXILIARY_OUT="$(cd "$R" && AI_CLAUDE_STUB_MODE=auxiliary "$SCRIPT" security-review)"
check 'review accepts only a proven first-party Haiku auxiliary model' "test -s '$AUXILIARY_OUT' && grep -A1 '^## Verdict' '$AUXILIARY_OUT' | tail -1 | grep -qx APPROVE"
COUNT="$(find "$R/.ai/reviews" -name 'claude-*.md' | wc -l | tr -d ' ')"
for mode in fail malformed wrong-model canonical-mismatch foreign-auxiliary scalar-auxiliary unproven-auxiliary uncanonical-auxiliary missing mutate; do check "$mode is rejected" "cd '$R' && ! AI_CLAUDE_STUB_MODE='$mode' '$SCRIPT' security-review >/dev/null 2>&1"; done
check 'failed reviews publish no accepted report' "[ '$COUNT' = \"\$(find '$R/.ai/reviews' -name 'claude-*.md' | wc -l | tr -d ' ')\" ]"
check 'source mutation during review is rejected' "cd '$R' && ! AI_CLAUDE_STUB_MODE=mutate-source '$SCRIPT' final-check >/dev/null 2>&1"
git -C "$R" checkout -q -- a.txt; printf 'changed\n' >> "$R/a.txt"
(cd "$R" && AI_CLAUDE_STUB_MODE=slow "$SCRIPT" visual-review > "$TMP/one") & P1=$!; (cd "$R" && AI_CLAUDE_STUB_MODE=slow "$SCRIPT" visual-review > "$TMP/two") & P2=$!
wait "$P1"; C1=$?; wait "$P2"; C2=$?
check 'concurrent reviews both complete' "[ '$C1' -eq 0 ] && [ '$C2' -eq 0 ]"
check 'concurrent reports do not collide' "[ \"\$(cat '$TMP/one')\" != \"\$(cat '$TMP/two')\" ]"
BAD="$TMP/bad.env"; printf "CLAUDE_REVIEW_CMD='%s -p --model claude-opus-5 --output-format json --tools Bash'\n" "$STUB" > "$BAD"
check 'unsafe command is refused' "cd '$R' && ! AI_DEVOPS_MODELS_ENV='$BAD' '$SCRIPT' doctor >/dev/null 2>&1"
check 'unknown mode is rejected' "cd '$R' && ! '$SCRIPT' nonsense >/dev/null 2>&1"
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
