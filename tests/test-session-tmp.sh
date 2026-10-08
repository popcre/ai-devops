#!/usr/bin/env bash
# Offline suite for tools/lib/session-tmp.sh and bin/ai-session-tmp-hook
# (plan_session-temp-cleanup.md §10).
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
root_dir="$(cd "$here/.." && pwd)"
lib="$root_dir/tools/lib/session-tmp.sh"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export AI_SESSION_TMP_BASE="$work/base" AI_SESSION_TMP_FORCE=1
unset AI_KEEP_SANDBOX AI_SESSION_TMP_ROOT AI_SESSION_TMP_CHILD TMPDIR

echo "== begin / end"
out="$(bash -c '. "$1"; ai_session_tmp_begin test abc; printf "%s|%s|%s|%s\n" "$AI_SESSION_TMP_ROOT" "$TMPDIR" "$TMP" "$TEMP"; [ -f "$AI_SESSION_TMP_ROOT/owner.json" ] && cat "$AI_SESSION_TMP_ROOT/owner.json"; stat -c %a "$AI_SESSION_TMP_ROOT"' _ "$lib")"
r="$AI_SESSION_TMP_BASE/test-abc"
check "root created under base" '[ -d "$r" ]'
check "TMPDIR/TMP/TEMP exported" '[[ "$out" == "$r|$r|$r|$r"* ]]'
check "owner.json has pid and engine" 'grep -q "\"pid\":[0-9]" <<<"$out" && grep -q "\"engine\":\"test\"" <<<"$out"'
check "root mode 700" '[[ "$out" == *$'"'"'\n'"'"'700 ]]'
bash -c '. "$1"; AI_SESSION_TMP_ROOT="$2" ai_session_tmp_end' _ "$lib" "$r"
check "end removes the root" '[ ! -e "$r" ]'

echo "== exit paths"
for how in normal error int term; do
  bash -c '. "$1"; ai_session_tmp_begin exit '"$how"'; trap ai_session_tmp_end EXIT; trap "exit 130" INT TERM
    case '"$how"' in normal) exit 0;; error) exit 3;; int) kill -INT $$; sleep 1;; term) kill -TERM $$; sleep 1;; esac' _ "$lib" 2>/dev/null
  check "end deletes on $how exit" '[ ! -e "$AI_SESSION_TMP_BASE/exit-'"$how"'" ]'
done

echo "== keep"
AI_KEEP_SANDBOX=1 bash -c '. "$1"; ai_session_tmp_begin keep k; ai_session_tmp_end' _ "$lib" 2>/dev/null
check "AI_KEEP_SANDBOX=1 keeps the root" '[ -d "$AI_SESSION_TMP_BASE/keep-k" ]'

echo "== guard"
g() { bash -c '. "$1"; AI_SESSION_TMP_ROOT="$2" ai_session_tmp_end' _ "$lib" "$1" 2>/dev/null; }
mkdir -p "$work/victim"; touch "$work/victim/keep"
ln -s "$work/victim" "$AI_SESSION_TMP_BASE/link-root"
check "refuses /" '! g /'
check "refuses the base itself" '! g "$AI_SESSION_TMP_BASE"'
check "refuses /var/tmp" '! g /var/tmp'
check "refuses a path with .." '! g "$AI_SESSION_TMP_BASE/../victim"'
check "refuses a symlink root" '! g "$AI_SESSION_TMP_BASE/link-root" && [ -f "$work/victim/keep" ]'
check "refuses an outside path" '! g "$work/victim" && [ -f "$work/victim/keep" ]'
check "begin refuses base /" '! AI_SESSION_TMP_BASE=/ bash -c ". \"$lib\"; ai_session_tmp_begin a b" 2>/dev/null'
check "begin slugs a hostile id" 'bash -c ". \"$lib\"; ai_session_tmp_begin x \"../../etc\"; [[ \$AI_SESSION_TMP_ROOT == \$AI_SESSION_TMP_BASE/x-etc ]]"'

echo "== wrap (wrapper entry point, nesting)"
no_roots() { local i; for i in $(seq 1 50); do [ -z "$(ls -A "$AI_SESSION_TMP_BASE" | grep -v -e keep-k -e link-root -e x-etc)" ] && return 0; sleep 0.1; done; return 1; }
cat > "$work/inner.sh" <<'IN'
#!/usr/bin/env bash
set -euo pipefail
. "$LIB"; ai_session_tmp_wrap inner "$0" "$@"
echo "inner=$TMPDIR" >> "$LOG"; touch "$TMPDIR/scratch"
IN
cat > "$work/outer.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail
. "$LIB"; ai_session_tmp_wrap outer "$0" "$@"
echo "outer=$TMPDIR" >> "$LOG"; bash "$INNER"
[ -d "$TMPDIR" ] && echo "outer-survives" >> "$LOG"
read -r line; echo "stdin=$line" >> "$LOG"
exit 7
OUT
export LIB="$lib" LOG="$work/log" INNER="$work/inner.sh"
echo hello | bash "$work/outer.sh"; rc=$?
check "wrapper exit code preserved" '[ "$rc" = 7 ]'
check "inner wrapper reuses the outer root" '[ "$(sed -n "s/^inner=//p" "$LOG")" = "$(sed -n "s/^outer=//p" "$LOG")" ]'
check "outer root survives inner end" 'grep -q outer-survives "$LOG"'
mkdir -p "$work/mine"; TMPDIR="$work/mine" bash "$work/inner.sh"
check "a caller-chosen TMPDIR is kept, not replaced" 'grep -q "inner=$work/mine$" "$LOG" && [ -f "$work/mine/scratch" ]'
check "stdin reaches the wrapped child" 'grep -q "stdin=hello" "$LOG"'
check "no roots left after wrappers exit" 'no_roots'
: > "$LOG"
bash "$work/outer.sh" </dev/null & wpid=$!; sleep 1; kill -TERM "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
check "TERM to wrapper removes its root" 'no_roots'
bash "$work/outer.sh" </dev/null & wpid=$!; sleep 1; kill -KILL "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
check "kill -9 of wrapper still removes its root" 'no_roots'
out="$(bash -c ". \"$lib\"; ai_session_tmp_wrap cap; echo done")"
check "command substitution does not wait on the watcher" '[ "$out" = done ]'
check "AI_SESSION_TMP=0 disables" 'AI_SESSION_TMP=0 bash -c ". \"$lib\"; ai_session_tmp_begin a b; [ -z \"\${AI_SESSION_TMP_ROOT:-}\" ]"'

echo "== Claude hook"
hook="$root_dir/bin/ai-session-tmp-hook"
envf="$work/claude.env"
printf '{"session_id":"11111111-2222-3333-4444-555555555555"}' | CLAUDE_ENV_FILE="$envf" bash "$hook" start
hr="$AI_SESSION_TMP_BASE/claude-11111111-2222-3333-4444-555555555555"
check "hook start creates the session root" '[ -f "$hr/owner.json" ]'
check "hook start exports TMPDIR via CLAUDE_ENV_FILE" 'grep -q "export TMPDIR=$hr" "$envf"'
printf '{"session_id":"11111111-2222-3333-4444-555555555555"}' | bash "$hook" end
check "hook end removes the session root" '[ ! -e "$hr" ]'
printf 'not json' | bash "$hook" start; check "hook never fails on bad input" '[ $? -eq 0 ]'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
