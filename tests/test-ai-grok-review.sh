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
PASS=0; FAIL=0; SKIP=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
# A platform-gated case that did not execute is not a passing check.
# Counting it as one inflated the non-Windows totals and hid which
# Windows cases never ran.
skip() { printf '  skip %s\n' "$1"; SKIP=$((SKIP+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
isolation_homes_match(){
  local home grok_home profile xdg_config xdg_cache xdg_data appdata localappdata
  local normalized_home normalized_grok normalized_profile normalized_config normalized_cache normalized_data
  local normalized_appdata normalized_localappdata
  local want_grok="$AI_GROK_STATE_DIR/isolated-home" first_home='' count=0
  while IFS='|' read -r home grok_home profile xdg_config xdg_cache xdg_data appdata localappdata; do
    normalized_home="$home"; normalized_grok="$grok_home"; normalized_profile="$profile"
    normalized_config="$xdg_config"; normalized_cache="$xdg_cache"; normalized_data="$xdg_data"
    normalized_appdata="$appdata"; normalized_localappdata="$localappdata"
    if command -v cygpath >/dev/null 2>&1; then
      normalized_home="$(cygpath -u "$home" 2>/dev/null || printf '%s' "$home")"
      normalized_grok="$(cygpath -u "$grok_home" 2>/dev/null || printf '%s' "$grok_home")"
      normalized_profile="$(cygpath -u "$profile" 2>/dev/null || printf '%s' "$profile")"
      normalized_config="$(cygpath -u "$xdg_config" 2>/dev/null || printf '%s' "$xdg_config")"
      normalized_cache="$(cygpath -u "$xdg_cache" 2>/dev/null || printf '%s' "$xdg_cache")"
      normalized_data="$(cygpath -u "$xdg_data" 2>/dev/null || printf '%s' "$xdg_data")"
      normalized_appdata="$(cygpath -u "$appdata" 2>/dev/null || printf '%s' "$appdata")"
      normalized_localappdata="$(cygpath -u "$localappdata" 2>/dev/null || printf '%s' "$localappdata")"
    fi
    [ "$normalized_grok" = "$want_grok" ] || return 1
    case "$normalized_home" in "$AI_GROK_STATE_DIR"/runtime-home.*) ;; *) return 1;; esac
    [ "$normalized_config" = "$normalized_home/.config" ] || return 1
    [ "$normalized_cache" = "$normalized_home/.cache" ] || return 1
    [ "$normalized_data" = "$normalized_home/.local/share" ] || return 1
    case "$(uname -s 2>/dev/null || true)" in
      MINGW*|MSYS*|CYGWIN*)
        [ "$normalized_profile" = "$normalized_home" ] || return 1
        [ "$normalized_appdata" = "$normalized_home/AppData/Roaming" ] || return 1
        [ "$normalized_localappdata" = "$normalized_home/AppData/Local" ] || return 1
        ;;
    esac
    [ -z "$first_home" ] && first_home="$normalized_home"
    [ "$normalized_home" = "$first_home" ] || return 1
    count=$((count + 1))
  done < "$TMP/isolation-homes.txt"
  [ "$count" -eq 2 ]
}
check "missing local runtime is named distinctly" "grep -q 'local_dependency_unavailable: grok binary not found' '$SCRIPT'"
check "local runtime failure does not blame Grok" "grep -q 'not a Grok provider fault' '$SCRIPT'"

TMP="$(mktemp -d)"
# Git Bash can spell the Network Service temp directory as /tmp while native
# Windows children report its physical /c/Windows/ServiceProfiles/... path.
# Keep every fixture, progress fingerprint, and saved review path in one
# canonical namespace so service-account activity is observed truthfully.
TMP="$(cd "$TMP" && pwd -P)"
mkdir -p "$TMP/system-tmp"
export TMPDIR="$TMP/system-tmp"
cleanup() {
  # Native Windows children can exit before Git Bash releases their final cwd
  # handle. Keep a persistent leak visible, but allow that bounded handoff to
  # settle so a fully passing safety run does not fail only in EXIT cleanup.
  cd "$REPO_ROOT" || return 1
  # Release any still-held stub so it exits now instead of sitting out its
  # escape-hatch ceiling and keeping a handle on $TMP.
  touch "$TMP/release-grok" 2>/dev/null || true
  local attempt
  for attempt in 1 2 3 4 5; do
    rm -rf "$TMP" 2>/dev/null && return 0
    sleep 1
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

export AI_GROK_STATE_DIR="$TMP/state"
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_SANDBOX_PROGRESS_FILE="$TMP/source-digest.progress"
export AI_GROK_AUTH_HOME="$TMP/no-auth"
export AI_GROK_CALLER="claude"
export AI_GROK_TEST_MODE=1
export AI_DEVOPS_TEST_MODE=1
export AI_GROK_POLL_INTERVAL=1
export AI_GROK_WAIT_TIMEOUT=15
SYSTEM_TMP_PROBE="$(mktemp)"
check "review digest staging is inside the watched fixture boundary" \
  "case '$SYSTEM_TMP_PROBE' in '$TMP/system-tmp/'*) true;; *) false;; esac"
rm -f "$SYSTEM_TMP_PROBE"

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
printf '%s|%s|%s|%s\n' "${GROK_CLAUDE_MCPS_ENABLED:-}" "${GROK_CLAUDE_HOOKS_ENABLED:-}" "${GROK_CURSOR_MCPS_ENABLED:-}" "${GROK_CODEX_SESSIONS_ENABLED:-}" >> "$TMPDIR_FOR_TEST/isolation.txt"
printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
  "${HOME:-}" "${GROK_HOME:-}" "${USERPROFILE:-}" \
  "${XDG_CONFIG_HOME:-}" "${XDG_CACHE_HOME:-}" "${XDG_DATA_HOME:-}" \
  "${APPDATA:-}" "${LOCALAPPDATA:-}" >> "$TMPDIR_FOR_TEST/isolation-homes.txt"
printf '%s\n' "$([ -f "${GROK_HOME:-}/auth.json" ] && printf visible || printf missing)" >> "$TMPDIR_FOR_TEST/isolation-auth.txt"
if printf '%s\n' "$@" | grep -qx inspect; then
  case "${AI_GROK_TEST_INSPECT_MODE:-ok}" in
    badshape) printf '%s\n' '{}' ;;
    enabledhook) printf '%s\n' '{"mcpServers":[],"hooks":[{"source":{"path":"/home/test/.claude"}}],"plugins":[],"externalCompat":{"cells":[{"vendor":"claude","surface":"hooks","enabled":true}]}}' ;;
    inspecthang) printf '%s\n' "${BASHPID:-$$}" > "$TMPDIR_FOR_TEST/inspect-hang-pid"; while :; do sleep 1; done ;;
    *) printf '%s\n' '{"mcpServers":[{"name":"ambient","compatibilityStatus":"disabled"}],"hooks":[{"source":{"path":"/home/test/.claude"}}],"plugins":[],"externalCompat":{"cells":[{"vendor":"claude","surface":"hooks","enabled":false}]}}' ;;
  esac
  exit 0
fi
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
  export)    printf '%s\n' "$GROK_HOME" > "$TMPDIR_FOR_TEST/export-home"; echo "# transcript stub"; exit 0 ;;
esac
touch "$TMPDIR_FOR_TEST/provider-contacted"
case "$mode" in
  ok)        cat "$TMPDIR_FOR_TEST/fixture.json" ;;
  cancelled) cat "$TMPDIR_FOR_TEST/cancelled.json" ;;
  weird)     cat "$TMPDIR_FOR_TEST/weird.json" ;;
  nosession) cat "$TMPDIR_FOR_TEST/no-session.json" ;;
  empty)     : ;;
  slow)      # exit immediately leaving an empty file, then complete later:
             # this is the early-return bug, reproduced.
             ( sleep 3; cat "$TMPDIR_FOR_TEST/fixture.json" > "$TMPDIR_FOR_TEST/late_target" ) &
             ;;
  wait)      sleep 6; cat "$TMPDIR_FOR_TEST/fixture.json" ;;
  hold)      touch "$TMPDIR_FOR_TEST/hold-started"
             printf '%s\n' "$$" > "$TMPDIR_FOR_TEST/hold-child-pid"
             trap 'printf terminated > "$TMPDIR_FOR_TEST/hold-child-terminated"; exit 143' TERM
             # The hold is released by the test, or terminated by the wrapper's
             # own timeout. Its ceiling is only a last-resort escape hatch: a
             # short one made the fixture expire mid-test on a loaded machine
             # and the assertions then measured the box, not the wrapper.
             for _i in $(seq 1 "${AI_GROK_TEST_HOLD_SECONDS:-900}"); do
               [ -f "$TMPDIR_FOR_TEST/release-grok" ] && break
               sleep 1
             done
             cat "$TMPDIR_FOR_TEST/fixture.json" ;;
  orphan)    ( trap 'printf terminated > "$TMPDIR_FOR_TEST/orphan-terminated"; exit 143' TERM
               printf '%s\n' "${BASHPID:-$$}" > "$TMPDIR_FOR_TEST/orphan-pid"
               while :; do sleep 1; done ) &
             sleep 1
             exit 0 ;;
esac
exit 0
STUBEOF
chmod +x "$STUB/grok"
export TMPDIR_FOR_TEST="$TMP"
export PATH="$STUB:$PATH"
export AI_GROK_BIN="$STUB/grok"
check "source-digest progress is inside the watched fixture boundary" \
  "case '$AI_REVIEW_SANDBOX_PROGRESS_FILE' in '$TMP/'*) true;; *) false;; esac"

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
cat > "$TMP/no-session.json" <<'EOF'
{"text":"## Verdict\nAPPROVE","stopReason":"end_turn","num_turns":1,
 "usage":{},"modelUsage":{"grok-4.6-build":{}},"total_cost_usd":0}
EOF
echo ok > "$TMP/mode"

# --- measured timing budgets --------------------------------------------------
# Every wait ceiling below is derived from one measured wrapper round trip
# instead of a hard-coded constant. A constant that is generous on an idle CI
# runner is a lost race on a loaded developer box, which is what made this suite
# non-deterministic (see fix_test_ai.md). Scaling keeps the compression — a
# 900-second production ceiling is useless in a test — without asserting that
# the machine is fast.
BASELINE_REPO="$TMP/baseline-repo"; mkdir -p "$BASELINE_REPO"
git -C "$BASELINE_REPO" init -q
git -C "$BASELINE_REPO" config user.email t@example.com
git -C "$BASELINE_REPO" config user.name T
printf '.ai/\n' > "$BASELINE_REPO/.gitignore"; echo b > "$BASELINE_REPO/b.txt"
git -C "$BASELINE_REPO" add -A; git -C "$BASELINE_REPO" commit -qm baseline
git -C "$BASELINE_REPO" remote add origin https://github.com/example/timing-baseline.git
# One representative wrapper round trip. Every ceiling below is derived from
# it, so the suite adapts to the machine instead of asserting the machine is
# fast. budget()/poll_until() and the baseline cap live in the shared library.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-timing.sh"
ai_test_measure_baseline bash -c 'cd "$1" && AI_GROK_WAIT_TIMEOUT=600 bash "$2" new timing-baseline --prompt x' _ "$BASELINE_REPO" "$SCRIPT"
BASELINE="$AI_TEST_BASELINE"

# work_lock_labelled LABEL -> the newest work lock carrying that label.
# `find -print -quit` returned an arbitrary lock, so a leftover from an earlier
# section could be inspected, and later deleted, in place of the real one.
work_lock_labelled() {
  local d newest="" newest_t=0 t
  for d in "$AI_GROK_STATE_DIR"/locks/work--*.lock.d; do
    [ -d "$d" ] || continue
    grep -qs -x "$1" "$d/label" || continue
    t="$(stat -c %Y "$d" 2>/dev/null || echo 0)"
    if [ "$t" -ge "$newest_t" ]; then newest_t="$t"; newest="$d"; fi
  done
  printf %s "$newest"
}

# ask_session_lock_held NAME - the real precondition for the ask-concurrency
# assertions. Counting work locks globally could be satisfied by a leftover
# lock from an earlier section while the session under test had not started.
ask_session_lock_held() {
  grep -qs -x "ask:$1" "$AI_GROK_STATE_DIR"/locks/session--*.lock.d/label 2>/dev/null
}

# fixture_note_if_timed_out OUTPUT LABEL — a run that is not testing the wait
# ceiling must never be judged by it. Say so loudly when one trips.
fixture_note_if_timed_out() {
  case "$1" in
    *"exceeded the configured"*)
      printf '  fixture: %s hit the wait ceiling (%ss, baseline %ss); the assertions below measured the machine, not the wrapper\n' \
        "$2" "$AI_GROK_WAIT_TIMEOUT" "$BASELINE" >&2 ;;
  esac
}

# The general-purpose ceiling for runs that are NOT testing timeout behaviour.
export AI_GROK_WAIT_TIMEOUT="$(budget 10 15)"
# The ceiling for the cases that deliberately trip it. It must still be far
# below the held stub's escape hatch so the wrapper, not the fixture, ends them.
TIMEOUT_CEILING="$(budget 2 3)"
# Wall-clock bound for a run that trips TIMEOUT_CEILING, scaled the same way.
TIMEOUT_WALL="$(( TIMEOUT_CEILING * 15 ))"
[ "$TIMEOUT_WALL" -lt 45 ] && TIMEOUT_WALL=45

# 16 ------------------------------------------------------------------------
echo "== exact_work_lock_visibility_and_truthful_interrupt =="
CLONE="$TMP/clone"; git clone -q "$REPO" "$CLONE"
# Keep this first review alive until this test explicitly releases it. A fixed
# sleep made the assertions depend on how quickly Windows created repositories.
echo hold > "$TMP/mode"
export AI_GROK_HEARTBEAT_INTERVAL=2
# This turn is released explicitly below. Give only this test-owned process a
# wide ceiling so slow Windows clone/setup work cannot turn the fixture into an
# unintended timeout and leave a false remote-uncertain lock.
( cd "$REPO" && AI_GROK_WAIT_TIMEOUT="$(budget 40 120)" bash "$SCRIPT" new shared-lock --prompt x >"$TMP/first.out" 2>"$TMP/first.err" ) & FIRST_PID=$!
for _i in $(seq 1 "$(budget 20 60)"); do
  [ -d "$AI_GROK_STATE_DIR/locks/work--"*.lock.d ] 2>/dev/null && [ -f "$TMP/hold-started" ] && break
  sleep 1
done
if [ ! -f "$TMP/hold-started" ]; then
  printf '  diagnostic: first held review did not reach the Grok stub\n' >&2
  sed -n '1,80p' "$TMP/first.err" >&2 2>/dev/null || true
fi
check "slow_fixture_reached_the_provider_before_mode_changes" "test -f '$TMP/hold-started'"
rm -f "$TMP/hold-started"
( cd "$CLONE" && AI_GROK_WAIT_TIMEOUT="$(budget 40 120)" bash "$SCRIPT" new other-clone --prompt different >"$TMP/second.out" 2>"$TMP/second.err" ) & SECOND_PID=$!
poll_until "$(budget 15 30)" 'two concurrent work locks' \
  "test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 2" || true
check "same_repo_different_session_and_packet_run_concurrently" "test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 2"
EXACT="$( cd "$CLONE" && bash "$SCRIPT" new shared-lock --prompt x 2>&1 )"; EXACT_RC=$?
check "same_exact_session_and_turn_is_refused" "test '$EXACT_RC' -ne 0 && printf '%s' \"$EXACT\" | grep -Eq 'already has an owner|session-name collision|exact Grok'"
CLAUDE_PID=''
( cd "$CLONE" && AI_GROK_CALLER=claude AI_GROK_WAIT_TIMEOUT="$(budget 40 120)" bash "$SCRIPT" new claude-independent --prompt caller-different >"$TMP/claude.out" 2>"$TMP/claude.err" ) & CLAUDE_PID=$!
poll_until "$(budget 15 30)" 'three concurrent work locks' \
  "test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 3" || true
check "same_repo_different_caller_and_work_run_concurrently" "test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 3"
check "lock_metadata_contains_digests_not_raw_prompts" "! grep -R -F 'caller-different' '$AI_GROK_STATE_DIR/locks'"
SSH_CLONE="$TMP/ssh-clone"; git clone -q "$REPO" "$SSH_CLONE"
git -C "$SSH_CLONE" remote set-url origin git@GitHub.com:EXAMPLE/Reviewer-Fixture.git
SSH_BLOCKED="$( cd "$SSH_CLONE" && bash "$SCRIPT" new shared-lock --prompt x 2>&1 )"; SSH_RC=$?
[ "$SSH_RC" -ne 0 ] && ok "equivalent_origins_share_exact_session_duplicate_detection" || bad "equivalent_origins_share_exact_session_duplicate_detection"
OTHER="$TMP/unrelated"; mkdir -p "$OTHER"; git -C "$OTHER" init -q
git -C "$OTHER" config user.email t@example.com; git -C "$OTHER" config user.name T
printf '.ai/\n' > "$OTHER/.gitignore"; echo x > "$OTHER/x"; git -C "$OTHER" add -A; git -C "$OTHER" commit -qm i
git -C "$OTHER" remote add origin https://github.com/example/unrelated.git
echo ok > "$TMP/mode"
( cd "$OTHER" && bash "$SCRIPT" new unrelated --prompt x >/dev/null 2>&1 ) && ok "unrelated_upstreams_do_not_block_each_other" || bad "unrelated_upstreams_do_not_block_each_other"
echo wait > "$TMP/mode"
# These two assertions describe what `list` reports about a review that is
# still running. If the held fixture ended first they measure nothing, so name
# that case distinctly instead of letting it look like a wrapper defect.
kill -0 "$FIRST_PID" 2>/dev/null || \
  printf '  fixture: the held shared-lock review ended before the list assertions (baseline %ss)\n' "$BASELINE" >&2
LIST="$( cd "$CLONE" && bash "$SCRIPT" list 2>&1 )"
check "list_shows_active_reviews_across_clones_and_callers" "printf '%s' \"\$LIST\" | grep -q shared-lock"
check "list_reports_start_elapsed_pid_checkout_and_owner_state" "printf '%s' \"\$LIST\" | grep -q 'ELAPSED' && printf '%s' \"\$LIST\" | grep -Eq 'active.*[0-9]+s'"
# Heartbeats are proven by counting them, not by sleeping long enough that two
# probably happened. A fixed 5s sleep against a 2s interval left no margin and
# was one reason this section went red on a busy machine.
poll_until "$(budget 20 30)" 'two bounded heartbeats from the held review' \
  "test \"\$(grep -c 'does not prove provider activity' '$TMP/first.err')\" -ge 2" || true
touch "$TMP/release-grok"
wait "$FIRST_PID"
wait "$SECOND_PID"
wait "$CLAUDE_PID"
check "slow_turn_emits_truthful_bounded_heartbeats" "test \"\$(grep -c 'does not prove provider activity' '$TMP/first.err')\" -ge 2"
check "terminal_stop_reason_remains_the_only_completion_rule" "grep -q 'APPROVE' '$TMP/first.out'"

# The configured wait ceiling must also bound a Grok process that never exits.
# A timed-out paid turn remains blocked because local process death does not
# prove that the provider stopped billing or working.
rm -f "$TMP/release-grok" "$TMP/hold-child-pid" "$TMP/hold-child-terminated"; echo hold > "$TMP/mode"
TIMEOUT_START="$(date +%s)"
TIMED_OUT="$( cd "$OTHER" && AI_GROK_WAIT_TIMEOUT="$TIMEOUT_CEILING" bash "$SCRIPT" new bounded-timeout --prompt x 2>&1 )"; TIMED_OUT_RC=$?
TIMEOUT_ELAPSED=$(( $(date +%s) - TIMEOUT_START ))
TIMEOUT_LOCK="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)"
check "configured_timeout_stops_the_local_grok_process" "test '$TIMED_OUT_RC' -ne 0 && printf '%s' '$TIMED_OUT' | grep -q 'exceeded the configured ${TIMEOUT_CEILING}s limit' && test -s '$TMP/hold-child-pid' && ! kill -0 \"\$(cat '$TMP/hold-child-pid')\" 2>/dev/null"
check "configured_timeout_remains_bounded" "test '$TIMEOUT_ELAPSED' -lt '$TIMEOUT_WALL'"
check "timed_out_paid_work_remains_blocked" "test -f '$TIMEOUT_LOCK/remote-uncertain' && printf '%s' '$TIMED_OUT' | grep -q 'Do not retry'"
check "Windows timeouts delegate both process trees to the native supervisor" "test \"\$(grep -c -- '--stop-file \"\$ACTIVE_GROK_NATIVE_STOP_FILE\"' '$SCRIPT')\" -eq 2 && grep -q 'TerminateJobObject(job, 124)' '$REPO_ROOT/bin/ai-process-supervisor'"
check "Windows fallback translates the MSYS PID and never emits a console signal" "grep -q '/proc/\$child/winpid' '$SCRIPT' && grep -q 'taskkill.exe /PID \"\$windows_pid\"' '$SCRIPT'"
rm -rf "$TIMEOUT_LOCK"

# The launcher may exit before the worker. The terminal-result timeout must
# still terminate the worker captured from the launcher's process tree.
rm -f "$TMP/orphan-pid" "$TMP/orphan-terminated"; echo orphan > "$TMP/mode"
ORPHANED="$( cd "$OTHER" && AI_GROK_WAIT_TIMEOUT="$TIMEOUT_CEILING" bash "$SCRIPT" new orphan-timeout --prompt x 2>&1 )"; ORPHANED_RC=$?
ORPHAN_LOCK="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)"
check "launcher_exit_timeout_kills_the_tracked_orphan_worker" "test '$ORPHANED_RC' -ne 0 && test -s '$TMP/orphan-pid' && ! kill -0 \"\$(cat '$TMP/orphan-pid')\" 2>/dev/null"
check "orphan_timeout_remains_fail_closed_for_remote_work" "test -f '$ORPHAN_LOCK/remote-uncertain'"
rm -rf "$ORPHAN_LOCK"

LOCK_EQ="$AI_GROK_STATE_DIR/locks/repo--$(printf '%s' 'github.com/example/reviewer-fixture' | sha256sum | cut -c1-16).lock.d"
mkdir -p "$LOCK_EQ"; printf '99999999\n' > "$LOCK_EQ/pid"; printf 'stale\n' > "$LOCK_EQ/label"
echo ok > "$TMP/mode"
DEAD="$( cd "$CLONE" && bash "$SCRIPT" new dead-owner --prompt x 2>&1 )"; DEAD_RC=$?
[ "$DEAD_RC" -ne 0 ] && printf '%s' "$DEAD" | grep -q 'ambiguous legacy' && ok "dead_legacy_owner_remains_fail_closed" || bad "dead_legacy_owner_remains_fail_closed"
check "dead_owner_lock_is_preserved" "test -d '$LOCK_EQ'"
rm -rf "$LOCK_EQ"
mkdir -p "$LOCK_EQ"; printf 'not-a-pid\n' > "$LOCK_EQ/pid"; printf 'malformed\n' > "$LOCK_EQ/label"
MALFORMED="$( cd "$CLONE" && bash "$SCRIPT" new malformed --prompt x 2>&1 )"; MALFORMED_RC=$?
[ "$MALFORMED_RC" -ne 0 ] && printf '%s' "$MALFORMED" | grep -q 'ambiguous legacy' && ok "malformed_lock_is_not_reclaimed" || bad "malformed_lock_is_not_reclaimed"
rm -rf "$LOCK_EQ"

# During a mixed-version rollout, an older wrapper's checkout-keyed lock has no
# trustworthy upstream field. Fail closed on that legacy paid-work record.
LEGACY_ID="$(printf '%s\n%s' "$(cd "$REPO" && pwd -P)" "$(git -C "$REPO" config --get remote.origin.url)" | sha256sum | cut -c1-12)"
LEGACY_LOCK="$AI_GROK_STATE_DIR/locks/repo--$LEGACY_ID.lock.d"
mkdir -p "$LEGACY_LOCK"; printf '%s\n' "$$" > "$LEGACY_LOCK/pid"; printf 'new:old-wrapper\n' > "$LEGACY_LOCK/label"
LEGACY_CALLS="$(wc -l < "$TMP/argv.txt")"
LEGACY_BLOCKED="$( cd "$CLONE" && bash "$SCRIPT" new legacy-overlap --prompt x 2>&1 )"; LEGACY_RC=$?
check "legacy_live_lock_for_same_upstream_blocks_rollout" "[ \"$LEGACY_RC\" -ne 0 ] && printf '%s' \"$LEGACY_BLOCKED\" | grep -q 'legacy Grok paid-work lock' && [ \"$LEGACY_CALLS\" -eq \"\$(wc -l < '$TMP/argv.txt')\" ]"
rm -rf "$LEGACY_LOCK"
rm -f "$TMP/hold-started" "$TMP/release-grok" "$TMP/hold-child-pid" "$TMP/hold-child-terminated"
echo hold > "$TMP/mode"

# A locally interrupted wrapper must not claim or assume that the paid remote
# turn stopped. Its retained uncertainty marker blocks another paid call.
( cd "$REPO" && exec bash "$SCRIPT" new interrupted --prompt x >"$TMP/int.out" 2>"$TMP/int.err" ) & INT_PID=$!
poll_until_progress "$(budget 15 30)" 'the interrupt fixture took its work lock and reached the Grok stub' \
  "ai_test_fingerprint '$AI_GROK_STATE_DIR' '$TMP' '$TMP/int.err' '$TMP/int.out' '$TMP/hold-started'" \
  "test -n \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)\" && test -f '$TMP/hold-started'" || true
LOCK_NOW="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)"
check "interrupt_fixture_reached_the_provider" "test -n '$LOCK_NOW' && test -f '$TMP/hold-started'"
kill -TERM "$INT_PID" 2>/dev/null || true
wait "$INT_PID" 2>/dev/null || true
check "signal_releases_owned_locks_and_warns_about_remote_turn" "grep -q 'cancellation is not confirmed' '$TMP/int.err' && test -f '$LOCK_NOW/remote-uncertain'"
check "directed signal terminates and reaps the owned local Grok child" "test -s '$TMP/hold-child-pid' && ! kill -0 \"\$(cat '$TMP/hold-child-pid')\" 2>/dev/null"
BLOCKED="$( cd "$CLONE" && bash "$SCRIPT" new interrupted --prompt x 2>&1 )"; BLOCKED_RC=$?
[ "$BLOCKED_RC" -ne 0 ] && ok "remote_uncertainty_blocks_only_its_exact_duplicate" || bad "remote_uncertainty_blocks_only_its_exact_duplicate"
echo ok > "$TMP/mode"
UNRELATED_AFTER_STOP="$( cd "$CLONE" && bash "$SCRIPT" new after-interrupt --prompt different 2>&1 )"; UNRELATED_RC=$?
check "remote_uncertainty_allows_unrelated_review" "test '$UNRELATED_RC' -eq 0"
rm -rf "$LOCK_NOW"
echo empty > "$TMP/mode"
UNCONFIRMED="$( cd "$REPO" && AI_GROK_WAIT_TIMEOUT="$TIMEOUT_CEILING" bash "$SCRIPT" new no-terminal --prompt x 2>&1 )"; UNCONFIRMED_RC=$?
UNCERTAIN_LOCK="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)"
[ "$UNCONFIRMED_RC" -ne 0 ] && ok "missing_terminal_result_fails" || bad "missing_terminal_result_fails"
check "missing_terminal_result_retains_uncertainty_lock" "test -f '$UNCERTAIN_LOCK/remote-uncertain'"
echo ok > "$TMP/mode"
AFTER_MISSING="$( cd "$CLONE" && bash "$SCRIPT" new no-terminal --prompt x 2>&1 )"; AFTER_MISSING_RC=$?
[ "$AFTER_MISSING_RC" -ne 0 ] && ok "missing_terminal_result_blocks_exact_retry" || bad "missing_terminal_result_blocks_exact_retry"
COLLISION="$( cd "$CLONE" && bash "$SCRIPT" new no-terminal --prompt materially-different 2>&1 )"; COLLISION_RC=$?
check "same_session_name_with_different_new_contract_fails_clearly" "test '$COLLISION_RC' -ne 0 && printf '%s' \"$COLLISION\" | grep -q 'session-name collision'"
rm -rf "$UNCERTAIN_LOCK"

# Losing the uncertainty-marker write must still preserve the directory that
# blocks a second paid turn. The next caller converts the dead-owner lock into
# an explicit uncertainty marker and remains blocked.
echo empty > "$TMP/mode"
MARK_FAIL="$( cd "$REPO" && AI_GROK_TEST_MARK_FAILURE=1 AI_GROK_WAIT_TIMEOUT="$TIMEOUT_CEILING" bash "$SCRIPT" new marker-write-fails --prompt x 2>&1 )"; MARK_FAIL_RC=$?
MARK_FAIL_LOCK="$(find "$AI_GROK_STATE_DIR/locks" -type d -name 'work--*.lock.d' -print -quit 2>/dev/null)"
check "marker_write_failure_preserves_paid_work_lock" "[ \"$MARK_FAIL_RC\" -ne 0 ] && test -d '$MARK_FAIL_LOCK' && test ! -f '$MARK_FAIL_LOCK/remote-uncertain'"
echo ok > "$TMP/mode"
AFTER_MARK_FAIL="$( cd "$CLONE" && bash "$SCRIPT" new marker-write-fails --prompt x 2>&1 )"; AFTER_MARK_FAIL_RC=$?
check "marker_write_failure_still_blocks_second_paid_turn" "[ \"$AFTER_MARK_FAIL_RC\" -ne 0 ] && printf '%s' \"$AFTER_MARK_FAIL\" | grep -q 'remote completion is unconfirmed' && test -f '$MARK_FAIL_LOCK/remote-uncertain'"
rm -rf "$MARK_FAIL_LOCK"
echo ok > "$TMP/mode"

run() { ( cd "$REPO" && bash "$SCRIPT" "$@" ) ; }

echo "ai-grok-review tests"

SESSION_RECORDS_BEFORE="$(find "$AI_GROK_STATE_DIR/session-records" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
SESSION_WRITE_FAIL="$(AI_GROK_TEST_RESERVATION_WRITE_FAILURE=session run new session-write-fail --prompt x 2>&1)"; SESSION_WRITE_FAIL_RC=$?
check "session_reservation_field_write_failure_is_nonzero" "test '$SESSION_WRITE_FAIL_RC' -ne 0"
check "session_reservation_field_write_failure_publishes_nothing" "test '$SESSION_RECORDS_BEFORE' -eq \"\$(find '$AI_GROK_STATE_DIR/session-records' -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)\" && ! find '$AI_GROK_STATE_DIR/session-records' -name '*.pending.*' | grep -q ."
run new session-write-fail --prompt x >/dev/null 2>&1
check "session_reservation_retry_succeeds_after_write_failure" "test '$?' -eq 0"

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
check "Grok debate has no fixed round limit" "! grep -qi 'at most three rebuttal turns' '$GROK_SKILL'"
check "Grok debate has no fixed cost ceiling" "! grep -Fq '\$1.50' '$GROK_SKILL'"
check "Grok debate states no fixed limits" "grep -qi 'no fixed round limit and no fixed dollar ceiling' '$GROK_SKILL'"
check "Grok debate stops on quality degradation" "grep -qi 'Quality degradation' '$GROK_SKILL'"
check "Grok debate lists a hallucination signal" "grep -qi 'cites a file, line, function, test, or commit that does not exist' '$GROK_SKILL'"
check "Grok debate lists a repetition signal" "grep -qi 'repeats a claim already shown to be unsupported' '$GROK_SKILL'"
check "Grok debate does not stop on cost or rounds alone" "grep -qi 'accumulated cost is never by itself a reason to stop' '$GROK_SKILL'"
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
: > "$TMP/isolation-homes.txt"
: > "$TMP/isolation-auth.txt"
mkdir -p "$AI_GROK_AUTH_HOME"
printf 'fixture-auth\n' > "$AI_GROK_AUTH_HOME/auth.json"
run new t1 --prompt "review this" >/dev/null 2>&1
ARGV="$(cat "$TMP/argv.txt")"
check "new passes --max-turns"            "grep -q -- '--max-turns' '$TMP/argv.txt'"
check "new pins the model"                "grep -q -- '--model grok-4.6' '$TMP/argv.txt'"
check "new denies Edit"                   "grep -q -- '--deny Edit' '$TMP/argv.txt'"
check "new denies Bash"                   "grep -q -- '--deny Bash' '$TMP/argv.txt'"
check "new disables web search"           "grep -q -- '--disable-web-search' '$TMP/argv.txt'"
check "new passes --no-memory"            "grep -q -- '--no-memory' '$TMP/argv.txt'"
check "review disables ambient MCP, hook, and compatibility session imports" "grep -qx 'false|false|false|false' '$TMP/isolation.txt'"
check "inspect and paid children share one empty user home separate from GROK_HOME" "isolation_homes_match"
check "inspect and paid children both retain credential reachability through GROK_HOME" "test \"\$(grep -cx visible '$TMP/isolation-auth.txt')\" -eq 2"
check "Windows reviewer isolates USERPROFILE for the native Grok child" "grep -q '\"USERPROFILE=\$isolated_native_user_home\"' '$REPO_ROOT/bin/ai-grok-review'"
check "Windows reviewer isolates every XDG root for the native Grok child" "grep -q '\"XDG_CONFIG_HOME=\$isolated_native_user_home' '$REPO_ROOT/bin/ai-grok-review' && grep -q '\"XDG_CACHE_HOME=\$isolated_native_user_home' '$REPO_ROOT/bin/ai-grok-review' && grep -q '\"XDG_DATA_HOME=\$isolated_native_user_home' '$REPO_ROOT/bin/ai-grok-review'"
check "review denies MCP meta-tools"       "grep -q -- '--disallowed-tools search_tool,use_tool,Agent' '$TMP/argv.txt' && grep -q -- '--deny MCPTool(\\*)' '$TMP/argv.txt'"
check "review disables subagents"          "grep -q -- '--no-subagents' '$TMP/argv.txt'"
check "review runs from a neutral non-repository cwd" "! grep -q -- '--cwd $REPO' '$TMP/argv.txt'"
check "Windows script launcher pins the current Git Bash for native Python" "grep -q 'bash_bin=\"\${BASH:-\$(command -v bash' '$SCRIPT' && grep -q 'bash_bin=\"\$(cygpath -w' '$SCRIPT' && ! grep -q 'grok_command=(bash ' '$SCRIPT'"
BAD_SHAPE="$(AI_GROK_TEST_INSPECT_MODE=badshape run new inspect-schema-drift --prompt x 2>&1)"; BAD_SHAPE_RC=$?
check "isolation inspection fails closed on schema drift" "test '$BAD_SHAPE_RC' -ne 0 && printf '%s' \"$BAD_SHAPE\" | grep -q 'isolation inspection'"
BAD_HOOK="$(AI_GROK_TEST_INSPECT_MODE=enabledhook run new inspect-enabled-hook --prompt x 2>&1)"; BAD_HOOK_RC=$?
check "isolation inspection rejects an enabled compatibility hook" "test '$BAD_HOOK_RC' -ne 0 && printf '%s' \"$BAD_HOOK\" | grep -q 'isolation inspection'"
INSPECT_HANG="$(AI_GROK_TEST_INSPECT_MODE=inspecthang AI_GROK_ISOLATION_TIMEOUT=2 run new inspect-hang --prompt x 2>&1)"; INSPECT_HANG_RC=$?
check "hung isolation inspection is bounded and its process tree is terminated" "test '$INSPECT_HANG_RC' -ne 0 && grep -q 'process tree was terminated' <<<\"$INSPECT_HANG\" && test -s '$TMP/inspect-hang-pid' && ! kill -0 \"\$(cat '$TMP/inspect-hang-pid')\" 2>/dev/null"
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
norm() { grep -- '--model ' "$1" | tail -1 | sed 's/--cwd [^ ]*//; s/--max-turns [0-9]*//; s/--resume [^ ]*//; s/--prompt-file [^ ]*//' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }
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
# This case is about how a cancelled stopReason is reported, not about the wait
# ceiling. If the ceiling fired instead, the four assertions below are measuring
# process startup on a loaded machine — say so rather than reporting a defect.
fixture_note_if_timed_out "$OUT" 'the cancelled-stopReason run'
[ $RC -ne 0 ] && ok "cancelled exits non-zero" || bad "cancelled exits non-zero"
check "cancelled has cancellation recovery message" "printf '%s' \"\$OUT\" | grep -qi 'cancelled without a final answer'"
check "cancelled message names the session"     "printf '%s' \"\$OUT\" | grep -q '019fd4aa'"
check "cancelled does not recommend resume"     "! printf '%s' \"\$OUT\" | grep -q 'ai-grok-review ask'"
check "cancelled recommends a fresh session"   "printf '%s' \"\$OUT\" | grep -qi 'fresh named session'"

echo weird > "$TMP/mode"
run new t5 --prompt x >/dev/null 2>&1
[ $? -ne 0 ] && ok "unknown stopReason exits non-zero" || bad "unknown stopReason exits non-zero"
echo nosession > "$TMP/mode"
run new missing-session-cleanup --prompt x >/dev/null 2>&1
[ $? -ne 0 ] && ok "missing sessionId exits non-zero" || bad "missing sessionId exits non-zero"
check "missing sessionId cannot strand a temporary user profile" "! find '$AI_GROK_STATE_DIR' -maxdepth 1 -type d -name 'runtime-home.*' -print -quit | grep -q ."
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
echo "== duplicate_new_is_refused (exact-session ownership lock) =="
RROOT="$(git -C "$REPO" rev-parse --show-toplevel)"
SESSION_ID_NEW="$(printf 'grok\n%s\n%s\n%s' 'github.com/example/reviewer-fixture' "$AI_GROK_CALLER" t9 | sha256sum | cut -c1-24)"
LOCKDIR="$AI_GROK_STATE_DIR/locks/session--$SESSION_ID_NEW.lock.d"
mkdir -p "$LOCKDIR"; printf '%s\n' "$$" > "$LOCKDIR/pid"; printf 'new:t9\n' > "$LOCKDIR/label"
OUT="$(run new t9 --prompt x 2>&1)"; RC=$?
rm -rf "$LOCKDIR"
[ $RC -ne 0 ] && ok "a second concurrent review is refused" || bad "a second concurrent review is refused"
check "refusal names the running review" "printf '%s' \"\$OUT\" | grep -q 'already has an owner'"

# 13 ------------------------------------------------------------------------
echo "== reviews_dir_safety =="
check "review file written when .ai is ignored" "ls '$REPO'/.ai/reviews/grok-t1-*.md"
check "review publication reads cached tokens from the completed result, not stdin" "grep -q 'Tokens: 22720 (cached 21248)' '$REPO'/.ai/reviews/grok-t1-*.md"
REPO2="$TMP/repo2"; mkdir -p "$REPO2"; git -C "$REPO2" init -q
git -C "$REPO2" config user.email t@example.com; git -C "$REPO2" config user.name T
echo x > "$REPO2/f"; git -C "$REPO2" add -A; git -C "$REPO2" commit -qm i
git -C "$REPO2" remote add origin https://github.com/Example/Unsafe-Fixture.git
rm -f "$TMP/provider-contacted"
ERR="$( cd "$REPO2" && bash "$SCRIPT" new t10 --prompt x 2>&1 >/dev/null )"; UNSAFE_RC=$?
check "refuses to write into a repo that would commit it" "test '$UNSAFE_RC' -ne 0 && printf '%s' \"\$ERR\" | grep -qi 'exact report destination is unsafe'"
check "and writes no file there" "! ls '$REPO2'/.ai/reviews/*.md 2>/dev/null"
check "unsafe report destination is refused before provider contact" "test ! -e '$TMP/provider-contacted'"
check "Muse and Grok both fail closed on an unsafe exact report destination" "grep -q 'return 1' '$SCRIPT' && grep -q 'exact destination is not Git-ignored' '$REPO_ROOT/bin/ai-muse'"

# 14 ------------------------------------------------------------------------
echo "== session bookkeeping =="
check "list shows a session"       "run list | grep -q t1"
check "list shows cumulative cost" "run list | grep -q '0.24'"
check "show emits json"            "run show t1 | jq -e .grok_session_id"
check "transcript works"           "run transcript t1 | grep -q transcript"
check "transcript reads the isolated reviewer session home" "grep -qx '$AI_GROK_STATE_DIR/isolated-home' '$TMP/export-home'"
check "a reaped supervisor PID is disarmed before later failure handling" "sed -n '/local child=/,/^frozen_prefix()/p' '$SCRIPT' | grep -q \"ACTIVE_GROK_CHILD=''\""
SIGNAL_WINDOW_HOME="$AI_GROK_STATE_DIR/runtime-home.signal-window"; mkdir -p "$SIGNAL_WINDOW_HOME"
( . "$TMP/lib.sh"; STATE_DIR="$AI_GROK_STATE_DIR"; ACTIVE_GROK_CHILD=''; ACTIVE_ISOLATED_CWD=''; ACTIVE_ISOLATED_HOME="$SIGNAL_WINDOW_HOME"; stop_active_grok_tree )
check "signal-window cleanup removes the temporary profile without an active child" "test ! -e '$SIGNAL_WINDOW_HOME'"
check "paid signal requests native-supervisor shutdown before fallback" "sed -n '/^on_paid_signal()/,/^}/p' '$SCRIPT' | grep -q 'request_active_grok_stop || stop_active_grok_tree'"
if case "$(uname -s 2>/dev/null || true)" in MINGW*|MSYS*|CYGWIN*) true;; *) false;; esac; then
  (
    . "$TMP/lib.sh"
    STATE_DIR="$AI_GROK_STATE_DIR"
    ACTIVE_GROK_STOP_DIR=''; ACTIVE_GROK_STOP_FILE=''; ACTIVE_GROK_NATIVE_STOP_FILE=''
    ACTIVE_ISOLATED_CWD=''; ACTIVE_ISOLATED_HOME=''
    sleep 300 & ACTIVE_GROK_CHILD=$!
    printf '%s\n' "$ACTIVE_GROK_CHILD" > "$TMP/windows-fallback-child-pid"
    stop_active_grok_tree
  )
  FALLBACK_RC=$?
  check "Windows native fallback executes against and reaps the translated live child" "test '$FALLBACK_RC' -eq 0 && test -s '$TMP/windows-fallback-child-pid' && ! kill -0 \"\$(cat '$TMP/windows-fallback-child-pid')\" 2>/dev/null"
  FAIL_CLOSED_LOCK="$TMP/windows-fallback-failure.lock.d"
  (
    . "$TMP/lib.sh"
    STATE_DIR="$AI_GROK_STATE_DIR"
    mkdir -p "$FAIL_CLOSED_LOCK"; printf '%s\n' "$$" > "$FAIL_CLOSED_LOCK/pid"
    ACTIVE_GROK_STOP_DIR=''; ACTIVE_GROK_STOP_FILE=''; ACTIVE_GROK_NATIVE_STOP_FILE=''
    ACTIVE_ISOLATED_CWD=''; ACTIVE_ISOLATED_HOME=''; ACTIVE_GROK_CHILD=99999999
    preserve_uncertain_paid_turn "$FAIL_CLOSED_LOCK"
  )
  FAIL_CLOSED_RC=$?
  check "failed Windows fallback returns normally and preserves remote uncertainty" "test '$FAIL_CLOSED_RC' -eq 0 && test -f '$FAIL_CLOSED_LOCK/remote-uncertain'"
else
  skip "Windows native fallback runtime test skipped on non-Windows"
  skip "Windows fallback-failure fail-closed test skipped on non-Windows"
fi
check "new and ask both preserve uncertainty before fallible cleanup" "test \"\$(grep -c 'preserve_uncertain_paid_turn \"\$rid_lock\"' '$SCRIPT')\" -eq 2"
# on_paid_signal ordering: the interrupt path must record paid-work uncertainty
# BEFORE it attempts the fallible process-tree stop. Both stop helpers are
# replaced with functions that abort, so a marker can only exist if it was
# written first. This is the executable form of the 2026-08-23 Claude finding.
SIGNAL_LOCK="$TMP/on-paid-signal-ordering.lock.d"
(
  . "$TMP/lib.sh"
  STATE_DIR="$AI_GROK_STATE_DIR"
  mkdir -p "$SIGNAL_LOCK"; printf '%s\n' "$$" > "$SIGNAL_LOCK/pid"
  ACTIVE_PAID_LOCK="$SIGNAL_LOCK"; ACTIVE_SESSION_LOCK=''
  ACTIVE_GROK_CHILD=99999999
  request_active_grok_stop() { exit 99; }
  stop_active_grok_tree()    { exit 99; }
  on_paid_signal
) >/dev/null 2>&1
SIGNAL_RC=$?
check "on_paid_signal records remote uncertainty before any fallible cleanup"   "test -f '$SIGNAL_LOCK/remote-uncertain' && test '$SIGNAL_RC' -eq 99"
check "on_paid_signal warns instead of trusting the uncertainty marker write"   "sed -n '/^on_paid_signal()/,/^}/p' '$SCRIPT' | grep -q 'retaining the paid-work lock for manual reconciliation'"
ABANDONED_WORK="$TMP/work--abandoned.lock.d"; mkdir -p "$ABANDONED_WORK"; printf '99999999\n' > "$ABANDONED_WORK/pid"; printf 'new:abandoned\n' > "$ABANDONED_WORK/label"
( . "$TMP/lib.sh"; STATE_DIR="$AI_GROK_STATE_DIR"; lock_acquire "$ABANDONED_WORK" new:abandoned github.com/example/reviewer-fixture abandoned "$REPO" abandoned-work prompt-digest source-id 1 ) >"$TMP/abandoned.out" 2>&1
check "genuinely_abandoned_pre_provider_work_lock_is_reclaimed" "test \"\$(cat '$ABANDONED_WORK/pid')\" != 99999999 && grep -q 'never contacted Grok' '$TMP/abandoned.out'"
rm -rf "$ABANDONED_WORK"
DURABLE_WORK="$TMP/work--durable.lock.d"; mkdir -p "$DURABLE_WORK"; printf '99999999\n' > "$DURABLE_WORK/pid"; printf 'new:durable\n' > "$DURABLE_WORK/label"; date -u +%FT%TZ > "$DURABLE_WORK/provider-contacted"
( . "$TMP/lib.sh"; STATE_DIR="$AI_GROK_STATE_DIR"; lock_acquire "$DURABLE_WORK" new:durable github.com/example/reviewer-fixture durable "$REPO" durable-work prompt-digest source-id 1 ) >"$TMP/durable.out" 2>&1; DURABLE_RC=$?
check "stale_local_owner_does_not_erase_durable_provider_record" "test '$DURABLE_RC' -ne 0 && test -f '$DURABLE_WORK/provider-contacted' && test -f '$DURABLE_WORK/remote-uncertain'"
rm -rf "$DURABLE_WORK"
check "unconfirmed stops drop only the temporary supervisor stop state"   "test \"\$(grep -c 'clear_active_stop_file' '$SCRIPT')\" -ge 6"
check "the timeout path cleans orphaned stop state without releasing the paid lock"   "sed -n '/exceeded the configured/,/RUN_TURN_RC=124/p' '$SCRIPT' | grep -q 'clear_active_stop_file'"

check "live doctor cleans its neutral runtime directory" "sed -n '/^cmd_doctor()/,/^cmd_new()/p' '$SCRIPT' | grep -q 'clear_active_grok'"
check "installed symlink resolves the repository-owned process supervisor" "sed -n '/supervisor=.*ai-process-supervisor/,/process-tree ownership/p' '$SCRIPT' | grep -q 'readlink -f'"
check "timeout restores shell fail-fast state before returning" "sed -n '/RUN_TURN_RC=124/,+3p' '$SCRIPT' | grep -q 'set -e'"
check "POSIX supervisor escalates before the wrapper fallback" "grep -q 'time.monotonic() + 3' '$REPO_ROOT/bin/ai-process-supervisor'"
run new stale-session --prompt x >/dev/null 2>&1
STALE_META="$(find "$AI_GROK_STATE_DIR/sessions" -name 'claude--stale-session.json' -print -quit)"; STALE_SESSION_ID="$(printf 'grok\n%s\n%s\n%s' 'github.com/example/reviewer-fixture' "$AI_GROK_CALLER" stale-session | sha256sum | cut -c1-24)"; STALE_SESSION_LOCK="$AI_GROK_STATE_DIR/locks/session--$STALE_SESSION_ID.lock.d"
mkdir -p "$STALE_SESSION_LOCK"; printf '99999999\n' > "$STALE_SESSION_LOCK/pid"; printf 'ask:stale-session\n' > "$STALE_SESSION_LOCK/label"
run ask stale-session --prompt x > "$TMP/stale-session.out" 2>&1; STALE_ASK_RC=$?
check "dead local-only session lock is safely reclaimed without inventing paid uncertainty" "test '$STALE_ASK_RC' -eq 0 && grep -q 'reclaimed a stale local-only session lock' '$TMP/stale-session.out' && test ! -e '$STALE_SESSION_LOCK'"
run new ask-a --prompt seed >/dev/null 2>&1; run new ask-b --prompt seed >/dev/null 2>&1
TURN_RECORDS_BEFORE="$(find "$AI_GROK_STATE_DIR/turn-records" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
TURN_WRITE_FAIL="$(AI_GROK_TEST_RESERVATION_WRITE_FAILURE=turn run ask ask-a --prompt turn-write-fail 2>&1)"; TURN_WRITE_FAIL_RC=$?
check "turn_reservation_field_write_failure_is_nonzero" "test '$TURN_WRITE_FAIL_RC' -ne 0"
check "turn_reservation_field_write_failure_publishes_nothing" "test '$TURN_RECORDS_BEFORE' -eq \"\$(find '$AI_GROK_STATE_DIR/turn-records' -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)\" && ! find '$AI_GROK_STATE_DIR/turn-records' -name '*.pending.*' | grep -q ."
PARTIAL_TURN_ID="$(printf 'grok\n%s\n%s\n%s\n%s' 'github.com/example/reviewer-fixture' "$AI_GROK_CALLER" ask-a 2 | sha256sum | cut -c1-28)"
PARTIAL_TURN_RECORD="$AI_GROK_STATE_DIR/turn-records/$PARTIAL_TURN_ID"; mkdir -p "$PARTIAL_TURN_RECORD"
PARTIAL_RETRY="$(run ask ask-a --prompt recover-crash-window 2>&1)"; PARTIAL_RETRY_RC=$?
check "partial_preprovider_turn_publication_is_reclaimable" "test '$PARTIAL_RETRY_RC' -eq 0 && printf '%s' \"$PARTIAL_RETRY\" | grep -q 'APPROVE'"
PREPROVIDER_FAIL="$(AI_GROK_TEST_INSPECT_MODE=badshape run ask ask-a --prompt preprovider-original 2>&1)"; PREPROVIDER_FAIL_RC=$?
check "preprovider_ask_failure_is_nonzero" "test '$PREPROVIDER_FAIL_RC' -ne 0 && printf '%s' \"$PREPROVIDER_FAIL\" | grep -q 'isolation inspection'"
PREPROVIDER_RETRY="$(run ask ask-a --prompt corrected-after-preprovider-failure 2>&1)"; PREPROVIDER_RETRY_RC=$?
check "preprovider_turn_reservation_is_reclaimable_for_corrected_retry" "test '$PREPROVIDER_RETRY_RC' -eq 0 && printf '%s' \"$PREPROVIDER_RETRY\" | grep -q 'APPROVE'"
ASK_A_REVIEW_DIR="$(run show ask-a | jq -r '.review_dir')"
ASK_B_REVIEW_DIR="$(run show ask-b | jq -r '.review_dir')"
check "named-session snapshot activity is inside the watched fixture boundary" \
  "case '$ASK_A_REVIEW_DIR:$ASK_B_REVIEW_DIR' in '$TMP/sandboxes/'*:'$TMP/sandboxes/'*) true;; *) false;; esac"
rm -f "$TMP/release-grok" "$TMP/hold-started"; echo hold > "$TMP/mode"
# These two turns are released explicitly below, so give them a wide ceiling of
# their own. The duplicate that must be refused builds a review packet first -
# several git operations - and on a slow Windows disk that can outlast a normal
# ceiling. If it does, the first turn times out and releases its session lock
# BEFORE the duplicate reaches the lock check, and the duplicate is then allowed
# for a perfectly correct reason. Observed on the windows-reviewer-safety runner:
# the duplicate took 124s against a 110s ceiling.
# The owners must outlive the challenger below and the whole intentional stall.
# Packet preparation plus the 150s Windows stall reached 243s in CI, so 240s
# could expire a correct owner immediately before the exact retry checked it.
( AI_GROK_WAIT_TIMEOUT="$(budget 80 480)" run ask ask-a --prompt next >"$TMP/ask-a.out" 2>"$TMP/ask-a.err" ) & ASK_A_PID=$!
( AI_GROK_WAIT_TIMEOUT="$(budget 80 480)" run ask ask-b --prompt other-next >"$TMP/ask-b.out" 2>"$TMP/ask-b.err" ) & ASK_B_PID=$!
# Snapshot isolation must start with the suite, not only in the final boundary
# section. Before #177, packet refreshes happened outside TMP, so this otherwise
# complete fixture fingerprint went silent for 135s on loaded Windows CI. The
# suite-owned sandbox now lives under TMP and a genuine stall keeps the same
# window and diagnostic.
poll_until_progress "$(budget 15 30)" 'both named ask turns hold their own session locks' \
  "ai_test_fingerprint '$AI_GROK_STATE_DIR' '$TMP' '$TMP/ask-a.err' '$TMP/ask-b.err' '$TMP/ask-a.out' '$TMP/ask-b.out'" \
  "ask_session_lock_held ask-a && ask_session_lock_held ask-b && test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 2" || true
check "different_named_sessions_can_ask_concurrently" "test \"\$(find '$AI_GROK_STATE_DIR/locks' -type d -name 'work--*.lock.d' | wc -l)\" -ge 2"
# The duplicate needs the same wide ceiling as the turns it must lose to. It
# builds its own review packet BEFORE reaching the lock check, so on a slow
# runner a normal ceiling fires first and it reports a timeout instead of the
# refusal - failing this check for a reason that is not a wrapper defect.
DUP_ASK="$(AI_GROK_WAIT_TIMEOUT="$(budget 40 120)" run ask ask-a --prompt next 2>&1)"; DUP_ASK_RC=$?
check "same_next_ask_turn_is_serialized" "test '$DUP_ASK_RC' -ne 0 && printf '%s' \"$DUP_ASK\" | grep -q 'already has a turn running'"
touch "$TMP/release-grok"; wait "$ASK_A_PID"; wait "$ASK_B_PID"; echo ok > "$TMP/mode"
rm -f "$TMP/release-grok" "$TMP/hold-started"; echo hold > "$TMP/mode"
# Terminated by the test below, so it must not reach its own ceiling first:
# a self-timeout leaves different lock state than an interrupt, and the two
# retries that follow assert on the interrupt case.
( cd "$REPO" && AI_GROK_WAIT_TIMEOUT="$(budget 40 120)" exec bash "$SCRIPT" ask ask-a --prompt uncertain-original >"$TMP/ask-uncertain.out" 2>"$TMP/ask-uncertain.err" ) & ASK_UNCERTAIN_PID=$!
# This wait is load-bearing in a way the others are not: the TERM below is the
# whole point of the next three checks. If the ask never reached the stub, we
# terminate a process that holds no lock, and the retries then assert against
# state an interrupt never produced - reporting a wrapper defect that does not
# exist. Say so instead.
poll_until_progress "$(budget 15 30)" 'the uncertain ask took its work lock and reached the Grok stub' \
  "ai_test_fingerprint '$AI_GROK_STATE_DIR' '$TMP' '$TMP/ask-uncertain.err' '$TMP/ask-uncertain.out' '$TMP/hold-started'" \
  "test -n \"\$(work_lock_labelled 'ask:ask-a')\" && test -f '$TMP/hold-started'" || true
ASK_UNCERTAIN_LOCK="$(work_lock_labelled 'ask:ask-a')"
kill -TERM "$ASK_UNCERTAIN_PID" 2>/dev/null || true; wait "$ASK_UNCERTAIN_PID" 2>/dev/null || true
EXACT_ASK_RETRY="$(run ask ask-a --prompt uncertain-original 2>&1)"; EXACT_ASK_RETRY_RC=$?
check "uncertain_ask_blocks_its_exact_retry" "test '$EXACT_ASK_RETRY_RC' -ne 0 && printf '%s' \"$EXACT_ASK_RETRY\" | grep -q 'exact Grok continuation'"
CHANGED_ASK_RETRY="$(run ask ask-a --prompt changed-after-uncertainty 2>&1)"; CHANGED_ASK_RETRY_RC=$?
check "uncertain_ask_blocks_changed_prompt_for_same_next_turn" "test '$CHANGED_ASK_RETRY_RC' -ne 0 && printf '%s' \"$CHANGED_ASK_RETRY\" | grep -q 'continuation-turn collision'"
rm -rf "$ASK_UNCERTAIN_LOCK"; echo ok > "$TMP/mode"
run ask ask-b --prompt unrelated-after-uncertainty >/dev/null 2>&1
check "uncertain_ask_does_not_block_other_named_session" "test '$?' -eq 0"
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
WT_META="$(find "$AI_GROK_STATE_DIR/sessions" -name '*wtreview.json' | head -1)"
HANDED="$(jq -r .review_dir "$WT_META")"
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
PLAIN_META="$(find "$AI_GROK_STATE_DIR/sessions" -name '*plainreview.json' | head -1)"
PLAIN="$(jq -r .review_dir "$PLAIN_META")"
check "ordinary clone is reviewed in a private copy" \
  "[ \"\$(cd '$PLAIN' && pwd -P)\" != \"\$(cd '$REPO' && pwd -P)\" ]"
check "ordinary-clone copy owns its git controls" "test -d '$PLAIN/.git'"
check "ordinary-clone session records its fixed directory" \
  "[ \"\$(jq -r .review_dir '$PLAIN_META')\" = '$PLAIN' ]"
: > "$TMP/argv.txt"
run ask plainreview --prompt "continue" >/dev/null 2>&1
PLAIN_AGAIN="$(jq -r .review_dir "$PLAIN_META")"
check "ordinary-clone continuation reuses the recorded copy" "[ '$PLAIN_AGAIN' = '$PLAIN' ]"

echo "== evidence packet (issue #34, step 3) =="
# Grok runs with --deny Bash, so it cannot run `git diff` and cannot work out
# what changed. Without a packet it burns its whole budget rediscovering the
# comparison: 20 turns, ~3M tokens, no verdict (2026-08-16/17).
: > "$TMP/argv.txt"
echo second > "$REPO/b.txt"; git -C "$REPO" add -A; git -C "$REPO" commit -qm second
run new packetreview --prompt "review this" >/dev/null 2>&1
PF="$(grep -o -- '--prompt-file [^ ]*' "$TMP/argv.txt" | tail -1 | cut -d' ' -f2)"
PACKET_META="$(find "$AI_GROK_STATE_DIR/sessions" -name '*packetreview.json' | head -1)"
PACKET_REVIEW_DIR="$(jq -r .review_dir "$PACKET_META")"
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
printf 'passed %d, failed %d, skipped %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
