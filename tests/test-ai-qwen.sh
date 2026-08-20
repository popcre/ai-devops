#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-qwen"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

mkdir -p "$REPO_ROOT/.ai"
TMP="$(mktemp -d "$REPO_ROOT/.ai/qwen-test.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
export AI_QWEN_STATE_DIR="$TMP/state"
export AI_QWEN_CALLER=codex
export AI_QWEN_POLL_INTERVAL=1
export AI_QWEN_WAIT_TIMEOUT=2
export TMPDIR_FOR_TEST="$TMP"

REPO="$TMP/repo"; mkdir -p "$REPO/.ai/reviews"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name T
git -C "$REPO" remote add origin https://example.invalid/qwen/repo.git
printf '.ai/\n' > "$REPO/.gitignore"; printf 'original\n' > "$REPO/a.txt"
git -C "$REPO" add -A; git -C "$REPO" commit -qm init

STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/qwen" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMPDIR_FOR_TEST/argv.txt"
case "${1:-}" in
  --version) echo '0.21.11'; exit 0 ;;
  sessions)
    printf '{"sessionId":"qwen-session-1","filePath":"%s/transcript.jsonl"}\n' "$TMPDIR_FOR_TEST"
    exit 0 ;;
esac
mode="$(cat "$TMPDIR_FOR_TEST/mode" 2>/dev/null || echo review)"
cat >/dev/null
case "$mode" in
  review) ;;
  write) printf 'qwen change\n' > qwen.txt ;;
  mutate-review) printf 'bad\n' >> a.txt ;;
  fail) printf '{"type":"assistant","message":{"content":[]}}\n'; exit 0 ;;
esac
printf '{"type":"assistant","session_id":"qwen-session-1","message":{"model":"qwen3.8-max-preview","content":[]}}\n'
printf '{"type":"result","subtype":"success","session_id":"qwen-session-1","is_error":false,"num_turns":2,"result":"## Verdict\\nAPPROVE","usage":{"input_tokens":11,"output_tokens":7},"permission_denials":[]}\n'
STUBEOF
chmod +x "$STUB/qwen"
export AI_QWEN_BIN="$STUB/qwen"
printf '{"saved":true}\n' > "$TMP/transcript.jsonl"
echo review > "$TMP/mode"
run(){ (cd "$REPO" && bash "$SCRIPT" "$@"); }

echo 'ai-qwen tests'
check 'syntax is valid' "bash -n '$SCRIPT'"
check 'help exits zero' 'run --help'

: > "$TMP/argv.txt"
run new review-1 --prompt 'review this' >/dev/null 2>&1
check 'review pins Qwen 3.8' "grep -q -- '--model qwen3.8-max-preview' '$TMP/argv.txt'"
check 'review uses safe mode' "grep -q -- '--safe-mode' '$TMP/argv.txt'"
check 'review uses plan mode' "grep -q -- '--approval-mode plan' '$TMP/argv.txt'"
check 'review excludes mutation tools' "grep -q -- '--exclude-tools shell,write,edit' '$TMP/argv.txt'"
check 'review has all budgets' "grep -q -- '--max-session-turns 30' '$TMP/argv.txt' && grep -q -- '--max-tool-calls 80' '$TMP/argv.txt' && grep -q -- '--max-wall-time 15m' '$TMP/argv.txt'"
check 'review never uses yolo or continue' "! grep -qE -- '--approval-mode yolo|--continue' '$TMP/argv.txt'"
check 'review record stores exact session' "run show review-1 | jq -e '.qwen_session_id==\"qwen-session-1\" and .caller==\"codex\"'"
REVIEW_DIR="$(run show review-1 | jq -r .review_dir)"
check 'ordinary clone review uses a private copy' "[ \"\$(cd '$REVIEW_DIR' && pwd -P)\" != \"\$(cd '$REPO' && pwd -P)\" ]"
check 'private review copy owns its git controls' "test -d '$REVIEW_DIR/.git'"

run ask review-1 --prompt 'follow up' >/dev/null 2>&1
check 'follow-up resumes exact session' "grep -q -- '--resume qwen-session-1' '$TMP/argv.txt'"
check 'follow-up keeps the recorded review copy' "[ \"\$(run show review-1 | jq -r .review_dir)\" = '$REVIEW_DIR' ]"

echo mutate-review > "$TMP/mode"
if run new hostile --prompt 'write a file' >/dev/null 2>&1; then bad 'review mutation fails loudly'; else ok 'review mutation fails loudly'; fi
git -C "$REPO" checkout -q -- a.txt

printf 'owner work\n' >> "$REPO/a.txt"
BEFORE_DIRTY="$(sha256sum "$REPO/a.txt" | awk '{print $1}')"
echo mutate-review > "$TMP/mode"
if run new hostile-dirty --prompt 'write a file' >/dev/null 2>&1; then bad 'mutation inside an already-dirty file fails'; else ok 'mutation inside an already-dirty file fails'; fi
AFTER_DIRTY="$(sha256sum "$REPO/a.txt" | awk '{print $1}')"
if [ "$BEFORE_DIRTY" = "$AFTER_DIRTY" ]; then ok 'private-copy mutation leaves owner work untouched'; else bad 'private-copy mutation leaves owner work untouched'; fi
git -C "$REPO" checkout -q -- a.txt

echo write > "$TMP/mode"; : > "$TMP/argv.txt"
IMPL_OUT="$(run implement impl-1 --prompt 'make the change' 2>&1)"; IMPL_RC=$?
[ "$IMPL_RC" -eq 0 ] || printf '  diagnostic: implementation: %s\n' "$IMPL_OUT"
PATCH="$(/usr/bin/find "$REPO/.ai/reviews" -name 'qwen-impl-1-*.patch' | head -1)"
check 'implementation requires Qwen sandbox' "grep -q -- '--sandbox --approval-mode yolo' '$TMP/argv.txt'"
check 'implementation exports a patch' "test -n '$PATCH' && grep -q qwen.txt '$PATCH'"
check 'implementation does not touch live checkout' "test ! -e '$REPO/qwen.txt'"
check 'implementation removes disposable worktree' "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"

echo review > "$TMP/mode"
run transcript review-1 >/dev/null 2>&1
check 'transcript copy stays in ignored review directory' "/usr/bin/find '$REPO/.ai/reviews' -name 'qwen-review-1-*.jsonl' | grep -q ."
run delete review-1 >/dev/null 2>&1
check 'delete removes the private review copy' "test ! -d '$REVIEW_DIR'"
check 'doctor checks installed interface without a model call' 'run doctor'

echo fail > "$TMP/mode"
if run new no-terminal --prompt x >/dev/null 2>&1; then bad 'missing terminal result fails'; else ok 'missing terminal result fails'; fi

echo "== #1220: silence must never read as APPROVE =="
# ai-qwen carried the identical extract_answer defect as ai-kimi: it printed only
# the tail from '## Verdict' (discarding findings that sat above it) and treated a
# run that ended with no verdict as a review with nothing to say. Exercised
# directly, because these are pure-text defects.
sed -n '/^extract_answer() {/,/^}/p' "$SCRIPT" > "$TMP/extract.sh"
probe(){ bash -c '. "$1"; ANSWER_DEFECT=""; extract_answer "$2" >/dev/null; printf "%s" "$ANSWER_DEFECT"' _ "$TMP/extract.sh" "$1"; }

printf '%s\n' '{"type":"result","is_error":false,"result":"I have read the files. Let me verify a few things before finalizing findings."}' > "$TMP/noverdict.jsonl"
NOV="$(probe "$TMP/noverdict.jsonl")"
check 'a result with no verdict is reported as a defect' "printf '%s' \"\$NOV\" | grep -q Verdict"

: > "$TMP/silent.jsonl"
SIL="$(probe "$TMP/silent.jsonl")"
check 'a stream with no answer at all is reported as a defect' "printf '%s' \"\$SIL\" | grep -q 'no answer text'"

printf '%s\n' '{"type":"result","is_error":false,"result":"finding one\n## Verdict\nAPPROVE"}' > "$TMP/good.jsonl"
GOOD="$(probe "$TMP/good.jsonl")"
check 'a complete review is NOT flagged as a defect' "[ -z \"\$GOOD\" ]"

BODY="$(bash -c '. "$1"; extract_answer "$2"' _ "$TMP/extract.sh" "$TMP/good.jsonl")"
check 'the text above the verdict is still emitted' "printf '%s' \"\$BODY\" | grep -q 'finding one'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
