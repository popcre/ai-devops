#!/usr/bin/env bash
# Offline tests for bin/ai-pr-poll-guard-hook and bin/ai-install-pr-poll-guard-hook
# (plan_ruleset-trim-and-enforce.md step 2.1, #1881).
#
# The hook runs before EVERY Bash call, so "allows ordinary commands" matters as
# much as "blocks hand-written PR polling loops". The installer edits the user's
# settings.json, so "never corrupts it, never removes an existing hook" is the point.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/bin/ai-pr-poll-guard-hook"
INSTALL="$ROOT/bin/ai-install-pr-poll-guard-hook"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Runs the hook on a Bash tool payload; prints the exit status.
fire() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$HOOK" 2>"$TMP/err" >/dev/null; echo $?; }
blocks() { CASE="$2"; check "blocks: $1" "[ \"\$(fire \"\$CASE\")\" = 2 ] && grep -q 'ai-pr-wait <pr> --timeout-minutes N' \"$TMP/err\""; }
allows() { CASE="$2"; check "allows: $1" "[ \"\$(fire \"\$CASE\")\" = 0 ]"; }

# --- every polling shape in the plan is blocked --------------------------------
blocks "sleep then gh pr view" 'sleep 60; gh pr view 12 --json state'
blocks "sleep then gh pr checks" 'sleep 30 && gh pr checks 12'
blocks "sleep then gh pr merge" 'sleep 120; gh pr merge 12 --squash'
blocks "sleep then ai-gh pr" 'sleep 45; ai-gh pr view 12'
blocks "until loop over gh pr view" 'until gh pr view 12 --json state -q .state | grep -q MERGED; do sleep 30; done'
blocks "while loop over gh pr checks" 'while true; do gh pr checks 12; done'
blocks "multi-line while loop" $'while :\ndo\n  gh pr view 12\ndone'
blocks "seq loop over gh pr view" 'for i in $(seq 1 20); do gh pr view 12; done'
blocks "timeout ai-pr-wait inside a loop" 'for i in 1 2 3; do timeout 600 bin/ai-pr-wait 12 --timeout-minutes 9; done'
# #1901: a loop handed to a child shell or eval is still a loop.
blocks "a poll loop inside bash -c" "bash -c 'for i in 1 2 3; do sleep 5; gh pr view 1 >/dev/null; done'"
blocks "a poll loop inside sh -lc" 'sh -lc "until gh pr view 1; do sleep 9; done"'
blocks "a poll loop inside eval" "eval 'while true; do gh pr checks 1; done'"
blocks "a poll loop inside bash with options" "bash --norc -o pipefail -c 'while :; do gh pr view 1; done'"
blocks "a poll loop inside ksh -c" "ksh -c 'until gh pr view 1; do sleep 5; done'"
allows "a quoted note passed to bash -c" "bash -c 'echo done'"

# --- ordinary commands are allowed ---------------------------------------------
allows "a single gh pr view" 'gh pr view 12 --json state'
allows "ai-pr-wait itself" 'ai-pr-wait 12 --timeout-minutes 9'
allows "ai-pr-wait with --fit-tool-call" 'bin/ai-pr-wait 12 --timeout-minutes 30 --fit-tool-call'
allows "a quoted commit message that mentions polling" "git commit -m 'stop sleep; gh pr checks loops'"
allows "a double-quoted note that mentions polling" 'printf "sleep then gh pr view\n" >> notes.md'
allows "a here-document that mentions polling" $'cat > notes.md <<\'EOF\'\nwhile true; do gh pr view 1; sleep 9; done\nEOF\nwc -l notes.md'
blocks "a loop after a here-document" $'cat > x <<EOF\ntext\nEOF\nwhile :; do gh pr checks 1; done'
blocks "a here-document fed to bash (#1901)" $'bash <<\'EOF\'\nwhile true; do gh pr view 1; sleep 9; done\nEOF'
blocks "a tab-stripped here-document fed to sh (#1901)" $'sh <<-EOF\n\tuntil gh pr merge 1; do sleep 9; done\nEOF'
blocks "a loop piped into bash (#1901)" "printf 'while true; do gh pr view 1; sleep 9; done' | bash"
blocks "a loop after a tab-indented <<- terminator (#1901)" $'cat > f <<-EOF\n\thi\n\tEOF\nwhile :; do gh pr view 1; done'
blocks "a loop inside an unterminated here-document (#1901)" $'cat > f <<EOF\nwhile :; do gh pr view 1; done'
blocks "a loop piped into /bin/bash (#1901)" "printf '%s' 'while :; do gh pr view 1; done' | /bin/bash"
blocks "a loop piped into /usr/bin/env bash (#1901)" "printf '%s' 'while :; do gh pr view 1; done' | /usr/bin/env bash"
blocks "a here-document fed to /bin/bash (#1901)" $'/bin/bash <<EOF\nwhile :; do gh pr view 1; done\nEOF'
blocks "a tight for loop over gh pr view (#1901)" 'for i in 1 2 3; do gh pr view 1; done'
blocks "a for loop inside bash -c (#1901)" "bash -c \"for i in 1 2 3; do gh pr checks 1; done\""
allows "sleep alone" 'sleep 5'
allows "an unrelated loop" 'for f in *.md; do wc -w "$f"; done'

# --- robustness: the hook must never break a turn ------------------------------
check "empty stdin exits 0" "echo '' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "malformed JSON exits 0" "echo 'not json' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "payload without a command exits 0" "echo '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"C:\\\\\\\\x\\\\\\\\y.md\"}}' | bash \"$HOOK\"; [ \$? -eq 0 ]"

# --- installer -----------------------------------------------------------------
CH="$TMP/claudehome"; mkdir -p "$CH"
printf '{"theme":"dark","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo pre-existing"}]}]}}\n' > "$CH/settings.json"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "installer registers the hook" "jq -e '[.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[].command] | any(contains(\"pr-poll-guard-hook\"))' \"$CH/settings.json\""
check "installed command keeps the blocking exit status" "! grep -q 'pr-poll-guard-hook.*|| true' \"$CH/settings.json\""
check "installer keeps the pre-existing hook" "grep -q 'pre-existing' \"$CH/settings.json\""
check "installer keeps unrelated settings" "grep -q '\"theme\"' \"$CH/settings.json\""
check "installer leaves valid JSON" "jq -e 'type == \"object\"' \"$CH/settings.json\""
check "installer backs the file up" "[ -f \"$CH/settings.json.aidevops.bak\" ]"
check "installer copies the hook script" "[ -f \"$TMP/fakehome/.config/ai-devops/pr-poll-guard-hook\" ]"

before="$(md5sum < "$CH/settings.json")"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
after="$(md5sum < "$CH/settings.json")"
check "installer is idempotent" "[ \"$before\" = \"$after\" ]"
HOME="$TMP/fakehome" bash "$INSTALL" --check --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "--check passes once installed" "[ \$? -eq 0 ]"

BAD="$TMP/badhome"; mkdir -p "$BAD"; printf '{ this is not json' > "$BAD/settings.json"
HOME="$TMP/fakehome2" bash "$INSTALL" --claude-home "$BAD" --repo-root "$ROOT" >/dev/null 2>&1; rc=$?
check "installer fails on unparseable settings" "[ $rc -ne 0 ]"
check "installer did not rewrite the broken file" "grep -q 'this is not json' \"$BAD/settings.json\""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
