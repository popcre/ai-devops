#!/usr/bin/env bash
# Tests for bin/ai-grok-review.
#
# Offline by default: a stub `grok` on PATH stands in for the real binary, so no
# network, no xAI calls, no cost. The live probe runs only with AI_GROK_LIVE=1.
#
# The two tests that matter most and must never be weakened:
#   - await_blocks_until_terminal_json : the regression test for the 2026-08-05
#     early-return bug (exit 0 + 0-byte file mistaken for a finished run).
#   - max_turns_always_present / permissions_are_fixed : the executable form of
#     decisions D4 and D2. If a change makes these fail, the change is wrong.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-grok-review"
PASS=0; FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
check "missing local runtime is named distinctly" "grep -q 'local_dependency_unavailable: grok binary not found' '$SCRIPT'"
check "local runtime failure does not blame Grok" "grep -q 'not a Grok provider fault' '$SCRIPT'"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export AI_GROK_STATE_DIR="$TMP/state"
export AI_GROK_CALLER="claude"
export AI_GROK_POLL_INTERVAL=1
export AI_GROK_WAIT_TIMEOUT=15

# --- a git repo to run in -----------------------------------------------------
REPO="$TMP/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name Test
printf '.ai/\n' > "$REPO/.gitignore"
echo hi > "$REPO/a.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm init
git -C "$REPO" remote add origin https://github.com/Example/Reviewer-Fixture.git

# --- stub grok ----------------------------------------------------------------
# Records its argv to $TMP/argv.txt and emits whatever $TMP/mode says.
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/grok" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMPDIR_FOR_TEST/argv.txt"
# Keep a copy of the prompt: the wrapper deletes it, and the tests need to
# assert what the reviewer was actually told.
for _i in $(seq 1 $#); do :; done
_prev=""
for _a in "$@"; do
  [ "$_prev" = "--prompt-file" ] && [ -f "$_a" ] && cp "$_a" "$TMPDIR_FOR_TEST/prompt-copy"
  _prev="$_a"
done
mode="$(cat "$TMPDIR_FOR_TEST/mode" 2>/dev/null || echo ok)"
case "${1:-}" in
  --version) echo "grok 0.2.118 (stub)"; exit 0 ;;
  models)    [ "$mode" = noauth ] && exit 1; echo "grok-4.6"; exit 0 ;;
  export)    echo "# transcript stub"; exit 0 ;;
esac
case "$mode" in
  ok)        cat "$TMPDIR_FOR_TEST/fixture.json" ;;
  cancelled) cat "$TMPDIR_FOR_TEST/cancelled.json" ;;
  weird)     cat "$TMPDIR_FOR_TEST/weird.json" ;;
  empty)     : ;;
  slow)      # exit immediately leaving an empty file, then complete later:
             # this is the early-return bug, reproduced.
             ( sleep 3; cat "$TMPDIR_FOR_TEST/fixture.json" > "$TMPDIR_FOR_TEST/late_target" ) &
             ;;
  wait)      sleep 6; cat "$TMPDIR_FOR_TEST/fixture.json" ;;
esac
exit 0
STUBEOF
chmod +x "$STUB/grok"
export TMPDIR_FOR_TEST="$TMP"
export PATH="$STUB:$PATH"
export AI_GROK_BIN="$STUB/grok"

cat > "$TMP/fixture.json" <<'EOF'
{"text":"I'll read the files first.\nNext I'll inspect the tests.\n## Verdict\nAPPROVE — looks correct.",
 "thought":"reasoning","sessionId":"019fd4e9-28d9-77c3-81f7-9fc9ca72fa7a",
 "stopReason":"end_turn","num_turns":3,"model":null,
 "usage":{"input_tokens":1440,"cache_read_input_tokens":21248,"total_tokens":22720},
 "modelUsage":{"grok-4.6-build":{}},"total_cost_usd":0.1234}
EOF
cat > "$TMP/cancelled.json" <<'EOF'
{"text":"I'll read the plan...","sessionId":"019fd4aa-7c5a-7ff2-b29b-258156f06ad3",
 "stopReason":"cancelled","num_turns":6,
 "usage":{"total_tokens":247740},"modelUsage":{"grok-4.6-build":{}},"total_cost_usd":0.25}
EOF
cat > "$TMP/weird.json" <<'EOF'
{"text":"x","sessionId":"s","stopReason":"banana","usage":{},"modelUsage":{},"total_cost_usd":0}
EOF
cat > "$TMP/endturn.json" <<'EOF'
{"text":"## Verdict\nAPPROVE","sessionId":"s-endturn","stopReason":"EndTurn","num_turns":1,
 "usage":{"cache_read_input_tokens":10},"modelUsage":{"grok-4.6-build":{}},"total_cost_usd":0.01}
EOF
echo ok > "$TMP/mode"

# 16 ------------------------------------------------------------------------
echo "== shared_upstream_lock_visibility_and_truthful_interrupt =="
CLONE="$TMP/clone"; git clone -q "$REPO" "$CLONE"
echo wait > "$TMP/mode"
export AI_GROK_HEARTBEAT_INTERVAL=2
( cd "$REPO" && bash "$SCRIPT" new shared-lock --prompt x >"$TMP/first.out" 2>"$TMP/first.err" ) & FIRST_PID=$!
for _i in 1 2 3 4 5; do
  [ -d "$AI_GROK_STATE_DIR/locks/repo--"*.lock.d ] 2>/dev/null && break
  sleep 1
done
SECOND="$( cd "$CLONE" && bash "$SCRIPT" new other-clone --prompt x 2>&1 )"; SECOND_RC=$?
[ "$SECOND_RC" -ne 0 ] && ok "equivalent_github_clones_share_one_paid_review_lock" || bad "equivalent_github_clones_share_one_paid_review_lock"
SSH_CLONE="$TMP/ssh-clone"; git clone -q "$REPO" "$SSH_CLONE"
git -C "$SSH_CLONE" remote set-url origin git@GitHub.com:EXAMPLE/Reviewer-Fixture.git
SSH_BLOCKED="$( cd "$SSH_CLONE" && bash "$SCRIPT" new ssh-spelling --prompt x 2>&1 )"; SSH_RC=$?
[ "$SSH_RC" -ne 0 ] && printf '%s' "$SSH_BLOCKED" | grep -q 'already running' && ok "https_ssh_dotgit_and_case_normalize_to_one_upstream" || bad "https_ssh_dotgit_and_case_normalize_to_one_upstream"
OTHER="$TMP/unrelated"; mkdir -p "$OTHER"; git -C "$OTHER" init -q
git -C "$OTHER" config user.email t@example.com; git -C "$OTHER" config user.name T
printf '.ai/\n' > "$OTHER/.gitignore"; echo x > "$OTHER/x"; git -C "$OTHER" add -A; git -C "$OTHER" commit -qm i
git -C "$OTHER" remote add origin https://github.com/example/unrelated.git
echo ok > "$TMP/mode"
( cd "$OTHER" && bash "$SCRIPT" new unrelated --prompt x >/dev/null 2>&1 ) && ok "unrelated_upstreams_do_not_block_each_other" || bad "unrelated_upstreams_do_not_block_each_other"
echo wait > "$TMP/mode"
LIST="$( cd "$CLONE" && bash "$SCRIPT" list 2>&1 )"
check "list_shows_active_reviews_across_clones_and_callers" "printf '%s' \"\$LIST\" | grep -q shared-lock"
check "list_reports_start_elapsed_pid_checkout_and_owner_state" "printf '%s' \"\$LIST\" | grep -q 'alive'"
wait "$FIRST_PID"
check "slow_turn_emits_truthful_bounded_heartbeat" "grep -q 'does not prove provider activity' '$TMP/first.err'"
check "terminal_stop_reason_remains_the_only_completion_rule" "grep -q 'APPROVE' '$TMP/first.out'"

LOCK_EQ="$AI_GROK_STATE_DIR/locks/repo--$(printf '%s' 'github.com/example/reviewer-fixture' | sha256sum | cut -c1-16).lock.d"
mkdir -p "$LOCK_EQ"; printf '99999999\n' > "$LOCK_EQ/pid"; printf 'stale\n' > "$LOCK_EQ/label"
echo ok > "$TMP/mode"
( cd "$CLONE" && bash "$SCRIPT" new reclaimed --prompt x >/dev/null 2>&1 ) && ok "dead_owned_lock_is_reclaimed" || bad "dead_owned_lock_is_reclaimed"
mkdir -p "$LOCK_EQ"; printf 'not-a-pid\n' > "$LOCK_EQ/pid"; printf 'malformed\n' > "$LOCK_EQ/label"
MALFORMED="$( cd "$CLONE" && bash "$SCRIPT" new malformed --prompt x 2>&1 )"; MALFORMED_RC=$?
[ "$MALFORMED_RC" -ne 0 ] && printf '%s' "$MALFORMED" | grep -q 'malformed lock' && ok "malformed_lock_is_not_reclaimed" || bad "malformed_lock_is_not_reclaimed"
rm -rf "$LOCK_EQ"
echo wait > "$TMP/mode"

# A locally interrupted wrapper must not claim or assume that the paid remote
# turn stopped. Its retained uncertainty marker blocks another paid call.
( cd "$REPO" && exec bash "$SCRIPT" new interrupted --prompt x >"$TMP/int.out" 2>"$TMP/int.err" ) & INT_PID=$!
for _i in 1 2 3 4 5; do
  LOCK_NOW="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'repo--*.lock.d' -print -quit 2>/dev/null)"
  [ -n "$LOCK_NOW" ] && break
  sleep 1
done
kill -TERM "$INT_PID" 2>/dev/null || true
wait "$INT_PID" 2>/dev/null || true
check "signal_releases_owned_locks_and_warns_about_remote_turn" "grep -q 'cancellation is not confirmed' '$TMP/int.err' && test -f '$LOCK_NOW/remote-uncertain'"
BLOCKED="$( cd "$CLONE" && bash "$SCRIPT" new after-interrupt --prompt x 2>&1 )"; BLOCKED_RC=$?
[ "$BLOCKED_RC" -ne 0 ] && ok "remote_uncertainty_blocks_duplicate_paid_turn" || bad "remote_uncertainty_blocks_duplicate_paid_turn"
rm -rf "$LOCK_NOW"
echo ok > "$TMP/mode"

run() { ( cd "$REPO" && bash "$SCRIPT" "$@" ) ; }

echo "ai-grok-review tests"

echo "== debate_contract_and_skill_guidance =="
TEMPLATE="$REPO_ROOT/templates/delegation/debate-turn.md"
GROK_SKILL="$REPO_ROOT/skills/shared/grok-cli/SKILL.md"
GLM_SKILL="$REPO_ROOT/skills/shared/ask-glm/SKILL.md"
check "debate template exists" "test -f '$TEMPLATE'"
for heading in "Goal" "Disputed claim" "Other model's reasoning" \
  "Current plan or diff paths" "New test or runtime evidence" "Constraints" \
  "What changed since the last turn" "Claim-by-claim check" "Material objections" \
  "Required correction" "Consensus question" "Consensus ledger" \
  "Agreed decisions" "Rejected alternatives" "Unresolved objections" \
  "Evidence still needed" "Last verified commit and path state"; do
  check "template has $heading" "grep -Fqx \"## $heading\" '$TEMPLATE' || grep -Fqx \"### $heading\" '$TEMPLATE'"
done
check "template requires current path re-read" "grep -qi 're-read.*current' '$TEMPLATE'"
check "Grok skill uses shared template" "grep -Fq 'templates/delegation/debate-turn.md' '$GROK_SKILL'"
check "GLM skill uses shared template" "grep -Fq 'templates/delegation/debate-turn.md' '$GLM_SKILL'"
check "Grok debate reuses exact named session" "grep -qi 'reuse the exact named session' '$GROK_SKILL'"
check "Grok debate has three-rebuttal bound" "grep -qi 'at most three rebuttal turns' '$GROK_SKILL'"
check "Grok debate has default cost ceiling" "grep -Fq '\$1.50' '$GROK_SKILL'"
check "Grok debate reports unresolved objections" "grep -qi 'report unresolved objections' '$GROK_SKILL'"
check "Grok skill keeps frozen prefix" "grep -qi 'Never broaden permissions, change the frozen prefix' '$GROK_SKILL'"
check "Grok skill forbids automatic turn increases" "grep -q 'do not automatically raise.*--max-turns' '$GROK_SKILL'"
check "Grok skill removes higher-turn recovery" "! grep -q 'same session with a higher.*--max-turns' '$GROK_SKILL'"
check "wrapper still reports cached tokens" "grep -Fq 'cached:' '$SCRIPT'"
check "wrapper still reports cost" "grep -Fq 'cost:' '$SCRIPT'"

# 1 -------------------------------------------------------------------------
echo "== usage_and_exit_codes =="
run >/dev/null 2>&1; [ $? -eq 2 ] && ok "no args exits 2" || bad "no args exits 2"
run bogus-cmd >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown command exits 2" || bad "unknown command exits 2"
check "help exits 0" "run --help"

# 2/3 -----------------------------------------------------------------------
echo "== max_turns_always_present / permissions_are_fixed =="
: > "$TMP/argv.txt"
run new t1 --prompt "review this" >/dev/null 2>&1
ARGV="$(cat "$TMP/argv.txt")"
check "new passes --max-turns"            "grep -q -- '--max-turns' '$TMP/argv.txt'"
check "new pins the model"                "grep -q -- '--model grok-4.6' '$TMP/argv.txt'"
check "new denies Edit"                   "grep -q -- '--deny Edit' '$TMP/argv.txt'"
check "new denies Bash"                   "grep -q -- '--deny Bash' '$TMP/argv.txt'"
check "new disables web search"           "grep -q -- '--disable-web-search' '$TMP/argv.txt'"
check "new passes --no-memory"            "grep -q -- '--no-memory' '$TMP/argv.txt'"
check "never uses permission-mode auto"   "! grep -q -- '--permission-mode auto' '$TMP/argv.txt'"
check "never allows Bash"                 "! grep -q -- '--allow Bash' '$TMP/argv.txt'"
check "never uses --always-approve"       "! grep -q -- '--always-approve' '$TMP/argv.txt'"
check "uses --prompt-file (no ARG_MAX)"   "grep -q -- '--prompt-file' '$TMP/argv.txt'"

: > "$TMP/argv.txt"
run ask t1 --prompt "follow up" >/dev/null 2>&1
check "ask passes --max-turns"            "grep -q -- '--max-turns' '$TMP/argv.txt'"
check "ask resumes the session"           "grep -q -- '--resume 019fd4e9' '$TMP/argv.txt'"
check "ask keeps the frozen permissions"  "grep -q -- '--deny Bash' '$TMP/argv.txt'"

# 4 -------------------------------------------------------------------------
echo "== no_flag_passthrough =="
run new t2 --prompt x --permission-mode auto >/dev/null 2>&1
[ $? -ne 0 ] && ok "arbitrary grok flags are rejected" || bad "arbitrary grok flags are rejected"
run new t2 --prompt x --always-approve >/dev/null 2>&1
[ $? -ne 0 ] && ok "--always-approve is rejected" || bad "--always-approve is rejected"

# 5 -------------------------------------------------------------------------
echo "== prefix_stable_across_turns =="
# The frozen prefix (model + permissions), i.e. everything except --max-turns,
# must be identical between new and ask. --max-turns is a runtime bound (D13).
: > "$TMP/argv.txt"
run new t3 --prompt x --max-turns 5 >/dev/null 2>&1
norm() { sed 's/--max-turns [0-9]*//; s/--resume [^ ]*//; s/--prompt-file [^ ]*//' "$1" | tr -s ' ' | sed 's/^ *//; s/ *$//'; }
NEWARGS="$(norm "$TMP/argv.txt")"
: > "$TMP/argv.txt"
run ask t3 --prompt y --max-turns 30 >/dev/null 2>&1
ASKARGS="$(norm "$TMP/argv.txt")"
[ "$NEWARGS" = "$ASKARGS" ] && ok "prefix minus --max-turns is byte-identical" \
  || bad "prefix minus --max-turns is byte-identical ('$NEWARGS' vs '$ASKARGS')"
check "--max-turns override is accepted on ask" "true"

# 6 -------------------------------------------------------------------------
echo "== await_blocks_until_terminal_json (the regression test) =="
# Directly exercise await_result: empty file, then partial JSON, then complete.
AWAIT_OUT="$TMP/await.json"
: > "$AWAIT_OUT"
(
  sleep 2; printf '{"text":"partial"' > "$AWAIT_OUT"      # invalid JSON
  sleep 2; cat "$TMP/fixture.json"    > "$AWAIT_OUT"      # complete
) &
BGPID=$!
START=$(date +%s)
# shellcheck disable=SC1090
( set +e
  # Source just enough of the script to reach await_result without executing main.
  sed '/^CMD=/,$d' "$SCRIPT" > "$TMP/lib.sh"
  . "$TMP/lib.sh"
  await_result "$AWAIT_OUT" "test"
) >/dev/null 2>&1
RC=$?
ELAPSED=$(( $(date +%s) - START ))
wait $BGPID 2>/dev/null
[ $RC -eq 0 ] && ok "await_result succeeds once JSON is terminal" || bad "await_result succeeds once JSON is terminal"
[ $ELAPSED -ge 3 ] && ok "await_result blocked through empty+partial (${ELAPSED}s)" \
  || bad "await_result returned too early (${ELAPSED}s) — the early-return bug is NOT caught"

# 7/8 -----------------------------------------------------------------------
echo "== stop_reason handling =="
echo cancelled > "$TMP/mode"
OUT="$(run new t4 --prompt x 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "cancelled exits non-zero" || bad "cancelled exits non-zero"
check "cancelled has cancellation recovery message" "printf '%s' \"\$OUT\" | grep -qi 'cancelled without a final answer'"
check "cancelled message names the session"     "printf '%s' \"\$OUT\" | grep -q '019fd4aa'"
check "cancelled does not recommend resume"     "! printf '%s' \"\$OUT\" | grep -q 'ai-grok-review ask'"
check "cancelled recommends a fresh session"   "printf '%s' \"\$OUT\" | grep -qi 'fresh named session'"

echo weird > "$TMP/mode"
run new t5 --prompt x >/dev/null 2>&1
[ $? -ne 0 ] && ok "unknown stopReason exits non-zero" || bad "unknown stopReason exits non-zero"
echo ok > "$TMP/mode"
cp "$TMP/fixture.json" "$TMP/fixture.lower.bak"
cp "$TMP/endturn.json" "$TMP/fixture.json"
run new t5-endturn --prompt x >/dev/null 2>&1
[ $? -eq 0 ] && ok "current EndTurn spelling succeeds" || bad "current EndTurn spelling succeeds"
cp "$TMP/fixture.lower.bak" "$TMP/fixture.json"

# 9/10 ----------------------------------------------------------------------
echo "== json_field_extraction =="
OUT="$(run new t6 --prompt x --json 2>/dev/null)"
check "--json emits the raw result"    "printf '%s' \"\$OUT\" | jq -e .stopReason"
check "null top-level model is fine"   "printf '%s' \"\$OUT\" | jq -e '.model == null'"
ERR="$(run ask t6 --prompt x 2>&1 >/dev/null)"
check "usage line reports tokens"      "printf '%s' \"\$ERR\" | grep -q 'tokens:'"
check "usage line reports cached"      "printf '%s' \"\$ERR\" | grep -q 'cached:'"
check "usage line reports cost"        "printf '%s' \"\$ERR\" | grep -q 'cost:'"
check "model reported by prefix"       "printf '%s' \"\$ERR\" | grep -q 'grok-4.6'"

# 11 ------------------------------------------------------------------------
echo "== verdict_delimiter_extraction =="
OUT="$(run new t7 --prompt x 2>/dev/null)"
check "verdict section is emitted"     "printf '%s' \"\$OUT\" | grep -q 'APPROVE'"
check "verdict comes first"            "[ \"\$(printf '%s' \"\$OUT\" | head -1)\" = '## Verdict' ]"
# Contract changed 2026-08-18. Emitting ONLY the verdict section discarded the
# findings: a real measured review produced 42 lines of evidenced defects above
# the heading and the caller saw two words. A verdict with no reasons cannot be
# acted on. The verdict still leads; the reasoning is kept below it.
check "findings are NOT discarded"     "printf '%s' \"\$OUT\" | grep -q \"I'll read the files\""
check "findings are clearly labelled"  "printf '%s' \"\$OUT\" | grep -q 'Findings and reasoning'"
cat > "$TMP/fixture2.json" <<'EOF'
{"text":"no delimiter here","sessionId":"s2","stopReason":"end_turn","num_turns":1,
 "usage":{},"modelUsage":{"grok-4.6-build":{}},"total_cost_usd":0}
EOF
cp "$TMP/fixture.json" "$TMP/fixture.bak"; cp "$TMP/fixture2.json" "$TMP/fixture.json"
ERR="$(run new t8 --prompt x 2>&1 >/dev/null)"
check "missing delimiter warns"        "printf '%s' \"\$ERR\" | grep -qi 'no .## Verdict. section'"
cp "$TMP/fixture.bak" "$TMP/fixture.json"

# 12 ------------------------------------------------------------------------
echo "== duplicate_new_is_refused (per-repo in-flight lock) =="
# Derive the repo id exactly as the script does — from git's own toplevel, which
# on Windows is a C:/… path and not the mktemp path in $REPO.
RROOT="$(git -C "$REPO" rev-parse --show-toplevel)"
RREMOTE="$(git -C "$RROOT" config --get remote.origin.url 2>/dev/null || echo '')"
RID_NEW="$(printf '%s' 'github.com/example/reviewer-fixture' | sha256sum | cut -c1-16)"
LOCKDIR="$AI_GROK_STATE_DIR/locks/repo--$RID_NEW.lock.d"
mkdir -p "$LOCKDIR"; printf '%s\n' "$$" > "$LOCKDIR/pid"; printf 'new:other\n' > "$LOCKDIR/label"
printf '2\n' > "$LOCKDIR/schema"; printf 'github.com/example/reviewer-fixture\n' > "$LOCKDIR/upstream"
printf 'other\n' > "$LOCKDIR/session"; printf 'codex\n' > "$LOCKDIR/caller"
printf '%s\n' "$RROOT" > "$LOCKDIR/source"; date -u +%FT%TZ > "$LOCKDIR/started"
OUT="$(run new t9 --prompt x 2>&1)"; RC=$?
rm -rf "$LOCKDIR"
[ $RC -ne 0 ] && ok "a second concurrent review is refused" || bad "a second concurrent review is refused"
check "refusal names the running review" "printf '%s' \"\$OUT\" | grep -q 'already running'"

# 13 ------------------------------------------------------------------------
echo "== reviews_dir_safety =="
check "review file written when .ai is ignored" "ls '$REPO'/.ai/reviews/grok-t1-*.md"
REPO2="$TMP/repo2"; mkdir -p "$REPO2"; git -C "$REPO2" init -q
git -C "$REPO2" config user.email t@example.com; git -C "$REPO2" config user.name T
echo x > "$REPO2/f"; git -C "$REPO2" add -A; git -C "$REPO2" commit -qm i
git -C "$REPO2" remote add origin https://github.com/Example/Unsafe-Fixture.git
ERR="$( cd "$REPO2" && bash "$SCRIPT" new t10 --prompt x 2>&1 >/dev/null )"
check "refuses to write into a repo that would commit it" "printf '%s' \"\$ERR\" | grep -qi 'not git-ignored'"
check "and writes no file there" "! ls '$REPO2'/.ai/reviews/*.md 2>/dev/null"

# 14 ------------------------------------------------------------------------
echo "== session bookkeeping =="
check "list shows a session"       "run list | grep -q t1"
check "list shows cumulative cost" "run list | grep -q '0.24'"
check "show emits json"            "run show t1 | jq -e .grok_session_id"
check "transcript works"           "run transcript t1 | grep -q transcript"
check "delete removes the record"  "run delete t1 && ! run show t1"

# 15 ------------------------------------------------------------------------
echo "== doctor =="
check "doctor is free (no billable probe by default)" "run doctor | grep -q 'auth *: OK'"
check "doctor reports the resolved binary"            "run doctor | grep -q 'grok binary'"
echo noauth > "$TMP/mode"
OUT="$(run doctor 2>&1)"
check "ambiguous auth does not blame grok doctor" "printf '%s' \"\$OUT\" | grep -qi 'terminal/clipboard'"
echo ok > "$TMP/mode"

# --- live ---------------------------------------------------------------------
if [ "${AI_GROK_LIVE:-0}" = 1 ]; then
  echo "== live_round_trip =="
  unset AI_GROK_BIN
  export PATH="${PATH#"$STUB":}"
  LREPO="$TMP/live"; mkdir -p "$LREPO"; git -C "$LREPO" init -q
  git -C "$LREPO" config user.email t@example.com; git -C "$LREPO" config user.name T
  printf '.ai/\n' > "$LREPO/.gitignore"; echo 'hello world' > "$LREPO/a.txt"
  git -C "$LREPO" add -A; git -C "$LREPO" commit -qm i
  O1="$( cd "$LREPO" && bash "$SCRIPT" new live --prompt 'Read a.txt and say what it contains.' --max-turns 5 --json 2>/dev/null )"
  check "live turn 1 has a terminal stopReason" "printf '%s' \"\$O1\" | jq -e '.stopReason==\"end_turn\" or .stopReason==\"EndTurn\"'"
  check "live turn 1 has non-empty text"        "printf '%s' \"\$O1\" | jq -e '.text|length>0'"
  O2="$( cd "$LREPO" && bash "$SCRIPT" ask live --prompt 'What file did you just read?' --max-turns 5 --json 2>/dev/null )"
  S1="$(printf '%s' "$O1" | jq -r .sessionId)"; S2="$(printf '%s' "$O2" | jq -r .sessionId)"
  [ "$S1" = "$S2" ] && ok "live turn 2 reuses the session" || bad "live turn 2 reuses the session"
  # Warning, not an assertion: caching depends on the whole request prefix
  # (repo AGENTS.md/CLAUDE.md, skills, MCP servers) and on TTL, none of which
  # the wrapper controls.
  CR="$(printf '%s' "$O2" | jq -r '.usage.cache_read_input_tokens // 0')"
  if [ "${CR:-0}" -gt 0 ]; then ok "live turn 2 read $CR tokens from cache"
  else printf '  warn cache read was 0 on turn 2 (not a failure; caching is not wrapper-controlled)\n'; fi
fi

echo "== linked worktree boundary (2026-08-17 regression) =="
# A reviewer gets ONE directory. Run from a linked worktree, that directory used
# to be the worktree itself, whose `.git` is a FILE pointing outside it — the
# reviewer died before reading any code. The wrapper must hand over a
# self-contained snapshot instead.
WT="$TMP/worktree"
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
git -C "$REPO" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1
echo only-in-worktree > "$WT/wt-only.txt"
: > "$TMP/argv.txt"
( cd "$WT" && bash "$SCRIPT" new wtreview --prompt "review this" ) >/dev/null 2>&1
HANDED="$(grep -o -- '--cwd [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
check "worktree run hands over a directory"      "test -n '$HANDED'"
check "handed directory is not the raw worktree" "[ \"\$(cd '$HANDED' && pwd -P)\" != \"\$(cd '$WT' && pwd -P)\" ]"
check "handed directory owns its git control files" \
  "test -d '$HANDED/.git' && ! test -f '$HANDED/.git'"
check "handed directory carries the worktree's untracked work" \
  "grep -q only-in-worktree '$HANDED/wt-only.txt'"
check "delete removes the snapshot" \
  "( cd '$WT' && bash '$SCRIPT' delete wtreview ) >/dev/null 2>&1; test ! -d '$HANDED'"
# An ordinary clone must also be isolated. Otherwise a pull, branch switch, or
# another session's commit moves the tree underneath the reviewer (issue #53).
: > "$TMP/argv.txt"
run new plainreview --prompt "review this" >/dev/null 2>&1
PLAIN="$(grep -o -- '--cwd [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
PLAIN_META="$(find "$AI_GROK_STATE_DIR/sessions" -name '*plainreview.json' | head -1)"
check "ordinary clone is reviewed in a private copy" \
  "[ \"\$(cd '$PLAIN' && pwd -P)\" != \"\$(cd '$REPO' && pwd -P)\" ]"
check "ordinary-clone copy owns its git controls" "test -d '$PLAIN/.git'"
check "ordinary-clone session records its fixed directory" \
  "[ \"\$(jq -r .review_dir '$PLAIN_META')\" = '$PLAIN' ]"
: > "$TMP/argv.txt"
run ask plainreview --prompt "continue" >/dev/null 2>&1
PLAIN_AGAIN="$(grep -o -- '--cwd [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
check "ordinary-clone continuation reuses the recorded copy" "[ '$PLAIN_AGAIN' = '$PLAIN' ]"

echo "== evidence packet (issue #34, step 3) =="
# Grok runs with --deny Bash, so it cannot run `git diff` and cannot work out
# what changed. Without a packet it burns its whole budget rediscovering the
# comparison: 20 turns, ~3M tokens, no verdict (2026-08-16/17).
: > "$TMP/argv.txt"
echo second > "$REPO/b.txt"; git -C "$REPO" add -A; git -C "$REPO" commit -qm second
run new packetreview --prompt "review this" >/dev/null 2>&1
PF="$(grep -o -- '--prompt-file [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
PACKET_REVIEW_DIR="$(grep -o -- '--cwd [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
check "packet is built in the review directory" "test -s '$PACKET_REVIEW_DIR/.ai-review-grok-packetreview/MANIFEST.md'"
check "packet carries the real head sha" \
  "grep -qF \"\$(git -C '$REPO' rev-parse HEAD)\" '$PACKET_REVIEW_DIR/.ai-review-grok-packetreview/MANIFEST.md'"
check "packet is sealed with a hash"            "test -s '$PACKET_REVIEW_DIR/.ai-review-grok-packetreview/MANIFEST.sha256'"
check "packet verifies"                         "'$REPO_ROOT/bin/ai-review-packet' verify '$PACKET_REVIEW_DIR/.ai-review-grok-packetreview'"
check "packet never enters the repository"      "[ -z \"\$(git -C '$REPO' status --porcelain | grep ai-review)\" ]"

# The prompt must point at the packet AND keep the reviewer's freedom to read on.
# The preamble must name THIS session's packet directory. A hard-coded
# `.ai-review` would send the reviewer to another session's evidence, or to
# nothing at all (shared-db#1296).
check "prompt points at the manifest"           "grep -q '.ai-review-grok-packetreview/MANIFEST.md' '$TMP/prompt-copy'"
check "prompt does not point at a shared packet" "! grep -q '[^-]\.ai-review/MANIFEST.md' '$TMP/prompt-copy'"
check "prompt keeps the caller's own brief"     "grep -q 'review this' '$TMP/prompt-copy'"
check "prompt still demands the verdict heading" "grep -qF '## Verdict' '$TMP/prompt-copy'"
check "prompt does NOT fence the reviewer in" \
  "grep -q 'not a boundary' '$TMP/prompt-copy'"

# Identity is the wrapper's job. A caller-typed SHA may only be CHECKED.
META="$(find "$AI_GROK_STATE_DIR/sessions" -name '*packetreview.json' | head -1)"
check "meta records the head sha"               "[ \"\$(jq -r .head '$META')\" = \"\$(git -C '$REPO' rev-parse HEAD)\" ]"
BASE_IN_META="$(jq -r '.base // ""' "$META")"
check "meta records the base sha derived by the wrapper" \
  "[ \"$BASE_IN_META\" = \"\$(git -C '$REPO' rev-parse HEAD~1)\" ]"
check "meta records the packet hash"            "[ -n \"\$(jq -r .packet_sha256 '$META')\" ]"
check "wrong --assert-head is refused" \
  "! ( cd '$REPO' && bash '$SCRIPT' new badsha --prompt x --assert-head 0000000000000000000000000000000000000000 )"
check "refusal names both shas" \
  "( cd '$REPO' && bash '$SCRIPT' new badsha2 --prompt x --assert-head 0000000000000000000000000000000000000000 ) 2>&1 | grep -q 'actual'"
check "right --assert-head is accepted" \
  "( cd '$REPO' && bash '$SCRIPT' new goodsha --prompt x --assert-head \"\$(git -C '$REPO' rev-parse HEAD)\" ) >/dev/null 2>&1"

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
