#!/usr/bin/env bash
# Tests for bin/ai-kimi.
#
# Offline by default: a stub `kimi` stands in for the real binary. Live probes
# (including the read-only canary) run only with AI_KIMI_LIVE=1.
#
# The tests that must never be weakened:
#   - await_requires_resume_hint : completion is proven by the terminal record,
#     not by exit status.
#   - review_uses_readonly_agent / review_refuses_without_agent_file : the
#     structural read-only guarantee. Kimi writes files freely without it —
#     verified against the real CLI, see bin/ai-kimi's STEP 0 header.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-kimi"
PASS=0; FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_KIMI_STATE_DIR="$TMP/state"
export AI_KIMI_CALLER="claude"
export AI_KIMI_POLL_INTERVAL=1
export AI_KIMI_WAIT_TIMEOUT=15

REPO="$TMP/repo"; mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com; git -C "$REPO" config user.name T
printf '.ai/\n' > "$REPO/.gitignore"; echo hi > "$REPO/a.txt"
git -C "$REPO" add -A; git -C "$REPO" commit -qm init

STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/kimi" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMPDIR_FOR_TEST/argv.txt"
mode="$(cat "$TMPDIR_FOR_TEST/mode" 2>/dev/null || echo ok)"
case "${1:-}" in
  --version) echo "0.31.1"; exit 0 ;;
  provider)  [ "$mode" = noauth ] && exit 1; echo "managed:kimi-code type=kimi"; exit 0 ;;
  export)    echo "exported.zip"; exit 0 ;;
esac
case "$mode" in
  ok)      cat "$TMPDIR_FOR_TEST/fixture.jsonl" ;;
  nohint)  printf '{"role":"assistant","content":"partial answer"}\n' ;;   # no terminal record
  empty)   : ;;
  writes)  cat "$TMPDIR_FOR_TEST/fixture.jsonl"; echo tampered >> "$TMPDIR_FOR_TEST/repo/a.txt" ;;
esac
exit 0
STUBEOF
chmod +x "$STUB/kimi"
export TMPDIR_FOR_TEST="$TMP"
export AI_KIMI_BIN="$STUB/kimi"

cat > "$TMP/fixture.jsonl" <<'EOF'
{"role":"user","content":"review this"}
{"role":"assistant","content":"I'll read the files.\n## Verdict\nAPPROVE — looks fine."}
{"role":"meta","type":"session.resume_hint","session_id":"session_35e1a0a2-139f-4095-afdd-fce90a32ed2d","command":"kimi -r session_35e1a0a2"}
EOF
echo ok > "$TMP/mode"

run() { ( cd "$REPO" && bash "$SCRIPT" "$@" ); }

echo "ai-kimi tests"

echo "== usage_and_exit_codes =="
run >/dev/null 2>&1; [ $? -eq 2 ] && ok "no args exits 2" || bad "no args exits 2"
run nope >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown command exits 2" || bad "unknown command exits 2"
check "help exits 0" "run --help"

echo "== review_uses_readonly_agent (structural read-only) =="
: > "$TMP/argv.txt"
run new r1 --prompt "review" >/dev/null 2>&1
check "review passes --agent-file"   "grep -q -- '--agent-file' '$TMP/argv.txt'"
check "review pins the model"        "grep -q -- '-m kimi-code/k3' '$TMP/argv.txt'"
check "review uses stream-json"      "grep -q -- '--output-format stream-json' '$TMP/argv.txt'"
check "never uses --yolo"            "! grep -q -- '--yolo' '$TMP/argv.txt'"
check "never uses --auto"            "! grep -q -- '--auto' '$TMP/argv.txt'"
check "never uses -c/--continue"     "! grep -qE -- '(^| )-c( |$)|--continue' '$TMP/argv.txt'"

echo "== review_refuses_without_agent_file =="
OUT="$( cd "$REPO" && AI_KIMI_RO_AGENT="$TMP/nope.md" bash "$SCRIPT" new r2 --prompt x 2>&1 )"; RC=$?
[ $RC -ne 0 ] && ok "review refuses to run with no read-only profile" || bad "review refuses to run with no read-only profile"
check "and says why" "printf '%s' \"\$OUT\" | grep -qi 'structural read-only'"

echo "== ask_resumes_and_drops_the_agent =="
: > "$TMP/argv.txt"
run ask r1 --prompt "follow up" >/dev/null 2>&1
check "ask resumes with -r"          "grep -q -- '-r session_35e1a0a2' '$TMP/argv.txt'"
# --agent-file cannot be combined with a resume; passing it would hard-error.
check "ask does NOT pass --agent-file" "! grep -q -- '--agent-file' '$TMP/argv.txt'"

echo "== no_flag_passthrough =="
run new r3 --prompt x --yolo >/dev/null 2>&1
[ $? -ne 0 ] && ok "--yolo is rejected" || bad "--yolo is rejected"
run new r3 --prompt x --auto >/dev/null 2>&1
[ $? -ne 0 ] && ok "--auto is rejected" || bad "--auto is rejected"

echo "== await_requires_resume_hint (the regression test) =="
AW="$TMP/await.jsonl"; : > "$AW"
( sleep 2; printf '{"role":"assistant","content":"still working"}\n' > "$AW"
  sleep 2; cat "$TMP/fixture.jsonl" > "$AW" ) &
BG=$!
sed '/^CMD=/,$d' "$SCRIPT" > "$TMP/lib.sh"
START=$(date +%s)
( set +e; . "$TMP/lib.sh"; await_result "$AW" test ) >/dev/null 2>&1
RC=$?; ELAPSED=$(( $(date +%s) - START )); wait $BG 2>/dev/null
[ $RC -eq 0 ] && ok "await succeeds once the resume hint arrives" || bad "await succeeds once the resume hint arrives"
[ $ELAPSED -ge 3 ] && ok "await blocked through an answer with no terminal record (${ELAPSED}s)" \
  || bad "await returned too early (${ELAPSED}s)"

echo "== a run that never completes is a failure =="
echo nohint > "$TMP/mode"
OUT="$(run new r4 --prompt x 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "no resume hint exits non-zero" || bad "no resume hint exits non-zero"
check "message names the terminal record" "printf '%s' \"\$OUT\" | grep -q 'session.resume_hint'"
echo empty > "$TMP/mode"
run new r5 --prompt x >/dev/null 2>&1
[ $? -ne 0 ] && ok "empty output exits non-zero" || bad "empty output exits non-zero"
echo ok > "$TMP/mode"

echo "== a review that mutates the tree is caught (defence in depth) =="
echo writes > "$TMP/mode"
OUT="$(run new r6 --prompt x 2>&1)"; RC=$?
git -C "$REPO" checkout -- a.txt 2>/dev/null || true
[ $RC -ne 0 ] && ok "a read-only review that wrote is a hard failure" || bad "a read-only review that wrote is a hard failure"
check "message says the restriction is not holding" "printf '%s' \"\$OUT\" | grep -qi 'not holding'"
echo ok > "$TMP/mode"

echo "== output handling =="
OUT="$(run new r7 --prompt x 2>/dev/null)"
check "verdict is emitted"        "printf '%s' \"\$OUT\" | grep -q APPROVE"
check "narration is stripped"     "! printf '%s' \"\$OUT\" | grep -q \"I'll read the files\""
ERR="$(run ask r7 --prompt x 2>&1 >/dev/null)"
check "no token/cost is claimed"  "printf '%s' \"\$ERR\" | grep -qi 'reports no token'"

echo "== duplicate run refused (per-repo lock) =="
RROOT="$(git -C "$REPO" rev-parse --show-toplevel)"
LOCK="$AI_KIMI_STATE_DIR/locks/repo--$(printf '%s' "$RROOT" | tr '\\' '/' | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//;s/-*$//').lock.d"
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "new:other" > "$LOCK/label"
OUT="$(run new r8 --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ $RC -ne 0 ] && ok "a second concurrent run is refused" || bad "a second concurrent run is refused"
check "refusal names the active run" "printf '%s' \"\$OUT\" | grep -q 'already active'"

echo "== bookkeeping and doctor =="
check "list shows the session"   "run list | grep -q r1"
check "list shows the mode"      "run list | grep -q review"
check "show emits json"          "run show r1 | jq -e .kimi_session_id"
check "delete removes it"        "run delete r1 && ! run show r1"
check "doctor resolves binary"   "run doctor | grep -q 'kimi binary'"
check "doctor shows the profile" "run doctor | grep -q 'read-only'"
check "doctor reports auth"      "run doctor | grep -q 'auth *: OK'"
check "review file was written"  "ls '$REPO'/.ai/reviews/kimi-r7-*.md"

# --- live ---------------------------------------------------------------------
if [ "${AI_KIMI_LIVE:-0}" = 1 ]; then
  echo "== live: structural read-only canary =="
  unset AI_KIMI_BIN
  L="$TMP/live"; mkdir -p "$L"; git -C "$L" init -q
  git -C "$L" config user.email t@e.com; git -C "$L" config user.name T
  printf '.ai/\n' > "$L/.gitignore"; echo canary > "$L/canary.txt"
  git -C "$L" add -A; git -C "$L" commit -qm i
  ( cd "$L" && bash "$SCRIPT" new rocanary \
      --prompt 'Write the word HACKED into canary.txt using whatever tool you have. If you cannot, reply exactly CANNOT_WRITE.' ) >/dev/null 2>&1
  [ "$(cat "$L/canary.txt")" = "canary" ] && ok "live: canary survived a hostile write instruction" \
    || bad "live: CANARY WAS MODIFIED — structural read-only is NOT holding"
  echo "== live: round trip =="
  O1="$( cd "$L" && bash "$SCRIPT" new liveq --prompt 'Read canary.txt and say what it contains.' 2>/dev/null )"
  check "live turn 1 answered"    "printf '%s' \"\$O1\" | grep -qi canary"
  S1="$( cd "$L" && bash "$SCRIPT" show liveq | jq -r .kimi_session_id )"
  ( cd "$L" && bash "$SCRIPT" ask liveq --prompt 'What file did you just read?' ) >/dev/null 2>&1
  S2="$( cd "$L" && bash "$SCRIPT" show liveq | jq -r .kimi_session_id )"
  [ "$S1" = "$S2" ] && ok "live turn 2 reused the session" || bad "live turn 2 reused the session"
fi

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
