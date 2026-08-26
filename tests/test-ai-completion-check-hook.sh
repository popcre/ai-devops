#!/usr/bin/env bash
# Offline tests for bin/ai-completion-check-hook and bin/ai-install-completion-check-hook.
#
# The hook runs at EVERY turn end, so "stays silent on an ordinary reply" matters
# as much as "stops a false completion claim". Two failure modes would be worse
# than the bug it fixes: firing twice in a row (a stop loop wedges the session)
# and firing on genuinely finished work (noise trains the reader to ignore it).
# Both are covered below. The installer edits the user's settings.json, so
# "never corrupts it, never removes the memory-index hook" is the rest of the point.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/bin/ai-completion-check-hook"
INSTALL="$ROOT/bin/ai-install-completion-check-hook"
MEMINSTALL="$ROOT/bin/ai-install-memory-hook"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"

# fire <prompt_id> <message> [extra_json_fields]
fire() {
  local pid="$1" msg="$2" extra="${3:-}"
  # %b so a literal backslash-n in a test case becomes a real paragraph
  # break: the hook judges the CLOSING paragraphs, so paragraph structure
  # is part of the input being tested.
  msg="$(printf '%b' "$msg")"
  jq -nc --arg p "$pid" --arg m "$msg" --argjson e "${extra:-null}" \
    '{hook_event_name:"Stop", session_id:"sess-1", prompt_id:$p, last_assistant_message:$m}
     + (if $e == null then {} else $e end)' \
    | bash "$HOOK" 2>/dev/null
}

# --- the case that matters: the 2026-08-26 failure -----------------------------
out="$(fire p1 "The database is ready. Nothing is needed from you now.")"
check "a completion claim is stopped" "[ -n \"\$out\" ]"
check "the block is valid JSON" "printf '%s' \"\$out\" | jq -e . >/dev/null"
check "it blocks the stop" "printf '%s' \"\$out\" | jq -e '.decision == \"block\"' >/dev/null"
check "it uses the documented Stop decision shape" "printf '%s' \"\$out\" | jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' >/dev/null"
check "the reason names the deliverables check" "printf '%s' \"\$out\" | grep -q 'name every deliverable'"
check "the reason says preparation is not delivery" "printf '%s' \"\$out\" | grep -q 'Preparation is not delivery'"
check "the reason says keep working, not ask" "printf '%s' \"\$out\" | grep -q 'keep working'"
check "the phrase that triggered it is quoted back" "printf '%s' \"\$out\" | grep -q 'nothing is needed'"

# --- the loop guard: never twice for the same prompt ---------------------------
out2="$(fire p1 "Nothing is needed from you now, really.")"
check "the same prompt is never blocked twice" "[ -z \"\$out2\" ]"
check "a LATER prompt is still checked" "[ -n \"\$(fire p2 'You are all set.')\" ]"
check "stop_hook_active short-circuits immediately" "[ -z \"\$(fire p3 'all set' '{\"stop_hook_active\":true}')\" ]"

# --- the phrasings this hook MISSED on 2026-08-26 -------------------------------
# It shipped catching "nothing is needed" and nothing else, so two real false
# completions closed with "Nothing right now" and "nothing is waiting on you" and
# passed silently. It fired on that turn only because the reply QUOTED its own
# trigger phrase while explaining the hook. Both halves are locked below.
check "'Nothing right now' at the close is caught" \
  "[ -n \"\$(fire m1 'Here is the state.\n\nNothing right now, the two open items are mine.')\" ]"
check "'nothing is waiting on you' at the close is caught" \
  "[ -n \"\$(fire m2 'Three things are running.\n\nNothing else is waiting on me, and nothing is waiting on you.')\" ]"
mention_msg="A turn ending on the phrase nothing is needed gets stopped once.\n\nHere is the diff; two tests fail on line 40.\n\nFixing them now."
mention_out="$(fire m3 "$mention_msg")"
check "a MENTION of the trigger phrase mid-reply is NOT caught" "[ -z \"\$mention_out\" ]"

# --- silence where silence is correct ------------------------------------------
check "an ordinary reply is silent" "[ -z \"\$(fire p4 'Here is the diff. Two tests fail on line 40.')\" ]"
check "a reply naming pending work is silent" "[ -z \"\$(fire p5 'The loader is still pending; I am building it next.')\" ]"
check "a question back to the user is silent" "[ -z \"\$(fire p6 'Which branch should this target?')\" ]"
check "a non-Stop event is silent" "[ -z \"\$(fire p7 'all set' '{\"hook_event_name\":\"PostToolUse\"}')\" ]"

# --- robustness: a broken hook must never wedge a turn -------------------------
check "empty stdin exits 0" "printf '' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "malformed JSON exits 0" "echo 'not json' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "payload without a message exits 0" "echo '{\"hook_event_name\":\"Stop\"}' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "a blocking run still exits 0" "fire p8 'all set' >/dev/null; [ \$? -eq 0 ]"
check "an unwritable state dir does not break the turn" \
  "XDG_STATE_HOME=/dev/null/nope bash -c 'echo {\\\"hook_event_name\\\":\\\"Stop\\\",\\\"session_id\\\":\\\"s\\\",\\\"prompt_id\\\":\\\"z\\\",\\\"last_assistant_message\\\":\\\"all set\\\"} | bash \"$HOOK\"'; [ \$? -eq 0 ]"

# --- installer -----------------------------------------------------------------
CH="$TMP/claudehome"; mkdir -p "$CH"
printf '{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo pre-existing"}]}]}}\n' > "$CH/settings.json"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "installer registers the hook" "grep -q 'completion-check-hook' \"$CH/settings.json\""
check "installer keeps the pre-existing Stop hook" "grep -q 'pre-existing' \"$CH/settings.json\""
check "installer keeps unrelated settings" "grep -q '\"theme\"' \"$CH/settings.json\""
check "installer leaves valid JSON" "jq -e 'type == \"object\"' \"$CH/settings.json\""
check "installer backs the file up" "[ -f \"$CH/settings.json.aidevops.bak\" ]"
check "installer copies the hook script" "[ -f \"$TMP/fakehome/.config/ai-devops/completion-check-hook\" ]"

before="$(md5sum < "$CH/settings.json")"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
after="$(md5sum < "$CH/settings.json")"
check "installer is idempotent" "[ \"$before\" = \"$after\" ]"
HOME="$TMP/fakehome" bash "$INSTALL" --check --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "--check passes once installed" "[ \$? -eq 0 ]"

# --- the two hooks must coexist ------------------------------------------------
HOME="$TMP/fakehome" bash "$MEMINSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "the memory-index hook still installs alongside" "grep -q 'memory-index-hook' \"$CH/settings.json\""
check "and the closeout hook survives it" "grep -q 'completion-check-hook' \"$CH/settings.json\""
check "settings still parse with both" "jq -e 'type == \"object\"' \"$CH/settings.json\""

# --- installer must refuse a broken settings file ------------------------------
BAD="$TMP/badhome"; mkdir -p "$BAD"; printf '{ this is not json' > "$BAD/settings.json"
HOME="$TMP/fakehome2" bash "$INSTALL" --claude-home "$BAD" --repo-root "$ROOT" >/dev/null 2>&1; rc=$?
check "installer fails on unparseable settings" "[ $rc -ne 0 ]"
check "installer did not rewrite the broken file" "grep -q 'this is not json' \"$BAD/settings.json\""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
