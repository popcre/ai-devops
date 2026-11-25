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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

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

# --- a turn that ends HOLDING a machine wait must be registered (#723) -------
# Waiting language is no longer gated (coord-del Step 4B): registration is
# gone, so a turn that ends on waiting language is allowed. The existing
# issue/PR is the card. Human waits still never match.
check "'keep polling' at the close is allowed (registration deleted)" \
  "[ -z \"\$(fire w1 'The PR checks need 40 more minutes.\n\nI will keep polling and report back.')\" ]"
check "'still waiting for the review' at the close is allowed" \
  "[ -z \"\$(fire w2 'The reviewer has the branch.\n\nStill waiting for the review to finish.')\" ]"
check "'watching until' at the close is allowed" \
  "[ -z \"\$(fire w3 'The merge queue is moving.\n\nWatching until 15:03.')\" ]"
check "a human wait in the still-open shape is NOT stopped" \
  "[ -z \"\$(fire w4 'The budget ruling is with Albert.\n\nWaiting on — Albert: the fall-line budget ruling.')\" ]"

# --- a promise of action must be backed by action in this turn -----------------
fire init '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
future_out="$(fire f1 "I am going to proceed now.")"
check "'I'm proceeding' with no execution action is stopped" "[ -n \"\$future_out\" ]"
check "future block names the no-action defect" "printf '%s' \"\$future_out\" | grep -q 'no implementation, test, or other execution action'"
for future_phrase in 'Running now; I will update you.' 'Monitoring now; I will update you.' 'Continuing now; I will update you.'; do
  fire phrase-init '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
  check "future activity phrase is stopped: $future_phrase" "[ -n \"\$(fire \"phrase-$future_phrase\" '$future_phrase')\" ]"
done
fire init2 '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
fire inspect '' '{"hook_event_name":"PostToolUse","tool_name":"Read"}' >/dev/null
check "inspection alone does not fulfil a future promise" \
  "[ -n \"\$(fire f2 'I will proceed now.')\" ]"
fire shellread '' '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"rg -n TODO ."}}' >/dev/null
check "read-only shell use does not fulfil a future promise" \
  "[ -n \"\$(fire f2b 'Proceeding now.')\" ]"
fire connector '' '{"hook_event_name":"PostToolUse","tool_name":"mcp__example__lookup"}' >/dev/null
check "an unknown connector cannot become a future-promise bypass" \
  "[ -n \"\$(fire f2c 'I will proceed now.')\" ]"
fire tool '' '{"hook_event_name":"PostToolUse","tool_name":"Edit"}' >/dev/null
check "the same promise after an execution action is silent" \
  "[ -z \"\$(fire f3 'Next I will summarize the result.')\" ]"
fire init-race '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
(fire race-action '' '{"hook_event_name":"PostToolUse","tool_name":"Edit"}' >/dev/null) & race_action_pid=$!
(fire race-read '' '{"hook_event_name":"PostToolUse","tool_name":"Read"}' >/dev/null) & race_read_pid=$!
wait "$race_action_pid"; wait "$race_read_pid"
check "parallel inspection cannot erase execution evidence" \
  "[ -z \"\$(fire f3-race 'I will proceed now.')\" ]"
fire init3 '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
fire shelltest '' '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"bash tests/test-focused.sh"}}' >/dev/null
check "a test command is an execution action" \
  "[ -z \"\$(fire f3b 'I will proceed with the report now.')\" ]"
rm -f "$XDG_STATE_HOME/ai-devops/completion-check/actions/sess-1"
check "a promise without activity-event evidence stays fail-open" \
  "[ -z \"\$(fire f4 \"I'll start now.\")\" ]"

# --- sample transcripts: a bare promise blocks (exit 2), a backed one passes ---
fire s-init '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
jq -nc '{hook_event_name:"Stop",session_id:"sess-1",prompt_id:"s1",last_assistant_message:"Plan noted.\n\nRunning now; I will update you."}' \
  | bash "$HOOK" >/dev/null 2>"$TMP/s1.err"; s1_rc=$?
check "sample: promise with no tool call exits 2" "[ $s1_rc -eq 2 ]"
check "sample: block reason goes to stderr" "grep -q 'no implementation' \"$TMP/s1.err\""
fire s-init2 '' '{"hook_event_name":"UserPromptSubmit"}' >/dev/null
fire s-edit '' '{"hook_event_name":"PostToolUse","tool_name":"Edit"}' >/dev/null
jq -nc '{hook_event_name:"Stop",session_id:"sess-1",prompt_id:"s2",last_assistant_message:"Edited the file.\n\nRunning now; I will update you."}' \
  | bash "$HOOK" >/dev/null 2>&1; s2_rc=$?
check "sample: promise after a tool call passes (exit 0)" "[ $s2_rc -eq 0 ]"

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

# --- proof-of-done (--sensors, #2835) -----------------------------------------
# sev <session> <json fields>: a sensors event; sstop <session> <prompt> <msg>:
# a sensors Stop. Each prints stdout and leaves exit status in $TMP/rc.
FIX="$ROOT/tests/fixtures/hooks"
sev() { jq -nc --arg s "$1" --argjson e "$2" '{session_id:$s} + $e' | bash "$HOOK" --sensors >/dev/null 2>&1; }
sstop() {
  local msg; msg="$(printf '%b' "$3")"
  jq -nc --arg s "$1" --arg p "$2" --arg m "$msg" '{hook_event_name:"Stop",session_id:$s,prompt_id:$p,last_assistant_message:$m}' \
    | bash "$HOOK" --sensors 2>"$TMP/serr"; echo $? >"$TMP/rc"
}
newturn() { sev "$1" '{"hook_event_name":"UserPromptSubmit"}'; }
edit() { sev "$1" '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.txt"}}'; }
bashok() { sev "$1" "$(jq -nc --arg c "$2" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c}}')"; }
bashfail() { sev "$1" "$(jq -nc --arg c "$2" '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_input:{command:$c},error:"Exit code 1"}')"; }
rc() { cat "$TMP/rc"; }

newturn v1; edit v1; bashok v1 'bash tests/test-x.sh'
out="$(sstop v1 q1 'Fixed it.\n\nThe task is complete.')"
check "sensors: verification ok after mutation then claim -> silent" "[ -z \"\$out\" ] && [ \"\$(rc)\" = 0 ]"

newturn v2; edit v2
out="$(sstop v2 q2 'Fixed it.\n\nThe task is complete.')"
check "sensors: mutation, no verification, claim -> exit 2" "[ \"\$(rc)\" = 2 ]"
check "sensors: unverified block reason on stderr" "grep -q 'no command that could fail checked the result' \"$TMP/serr\""
check "sensors: unverified block JSON on stdout" "printf '%s' \"\$out\" | jq -e '.decision == \"block\"' >/dev/null"
out="$(sstop v2 q2 'Fixed it.\n\nThe task is complete.')"
check "sensors: the unverified block fires once per prompt" "[ -z \"\$out\" ] && [ \"\$(rc)\" = 0 ]"

newturn v3
jq -nc '{hook_event_name:"PostToolUse",session_id:"v3",tool_name:"Edit",tool_input:{file_path:"/repo/a"}}' | bash "$HOOK" --sensors >/dev/null 2>&1
sstop v3 q3 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: PostToolUse without prompt_id -> Stop still sees its events" "[ \"\$(rc)\" = 2 ]"

newturn v4; edit v4; newturn v4
out="$(sstop v4 q4 'Looked around.\n\nThe task is complete.')"
check "sensors: mutation in prompt 1 does not leak into prompt 2 (old nudge only)" "[ \"\$(rc)\" = 0 ] && printf '%s' \"\$out\" | grep -q 'name every deliverable'"

newturn v5; sev v5 '{"hook_event_name":"PostToolUse","tool_name":"Read"}'
out="$(sstop v5 q5 'Read it.\n\nThe task is complete.')"
check "sensors: inspection only, claim -> old nudge text" "[ \"\$(rc)\" = 0 ] && printf '%s' \"\$out\" | grep -q 'name every deliverable'"

newturn v6; edit v6; bashok v6 'pytest'; edit v6
sstop v6 q6 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: passing test, then Edit, then claim -> blocks" "[ \"\$(rc)\" = 2 ]"

newturn v7; edit v7
jq --arg s v7 '.session_id=$s | .tool_input.command="pytest"' "$FIX/posttoolusefailure-bash-exit3.json" | bash "$HOOK" --sensors >/dev/null 2>&1
sstop v7 q7 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: failing test (captured failure fixture) then claim -> blocks" "[ \"\$(rc)\" = 2 ]"

newturn v7b; edit v7b
jq --arg s v7b '.session_id=$s | .tool_input.command="pytest -q"' "$FIX/posttooluse-bash-ok.json" | bash "$HOOK" --sensors >/dev/null 2>&1
sstop v7b q7b 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: passing test (captured success fixture) then claim -> silent" "[ \"\$(rc)\" = 0 ]"

newturn v8; edit v8; bashok v8 'pytest && git status'
sstop v8 q8 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: pytest && git status then claim -> silent" "[ \"\$(rc)\" = 0 ]"

n=0
for c in 'pytest || true' '! pytest' 'true || pytest' 'pytest; echo ok' 'pytest | tail' $'pytest\necho ok' 'if pytest; then echo ok; fi'; do
  n=$((n+1)); newturn "vx$n"; edit "vx$n"; bashok "vx$n" "$c"
  sstop "vx$n" "qx$n" 'Done.\n\nThe task is complete.' >/dev/null
  check "sensors: '$c' is not proof -> blocks" "[ \"\$(rc)\" = 2 ]"
done

newturn v9; edit v9; bashok v9 'set -o pipefail && pytest | tail -5'
sstop v9 q9 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: set -o pipefail && pytest | tail then claim -> silent" "[ \"\$(rc)\" = 0 ]"

n=0
for c in 'echo --check' 'grep -- --check f' 'gh pr view 12' 'curl -s https://x' 'cat tests/x.sh'; do
  n=$((n+1)); newturn "vn$n"; edit "vn$n"; bashok "vn$n" "$c"
  sstop "vn$n" "qn$n" 'Done.\n\nThe task is complete.' >/dev/null
  check "sensors: '$c' is not verification" "[ \"\$(rc)\" = 2 ]"
done

n=0
for c in 'ai-install-completion-check-hook --check' 'bin/ai-pr-wait 12' 'gh pr checks 12' 'curl -fsS https://x' 'git diff --exit-code' 'python3 -m pytest -q' 'npm test' 'cd sub && bash tests/t.sh'; do
  n=$((n+1)); newturn "vy$n"; edit "vy$n"; bashok "vy$n" "$c"
  sstop "vy$n" "qy$n" 'Done.\n\nThe task is complete.' >/dev/null
  check "sensors: '$c' counts as verification" "[ \"\$(rc)\" = 0 ]"
done

newturn v10; edit v10; bashok v10 'bash tests/t.sh'; bashok v10 'git add -A && git commit -m x && git push'
sstop v10 q10 'Tested, committed and pushed.\n\nThe task is complete.' >/dev/null
check "sensors: commit and push after a passing test stay verified" "[ \"\$(rc)\" = 0 ]"

newturn v11; bashok v11 'git commit -am x && git push'
sstop v11 q11 'Fixed and pushed.' >/dev/null
check "sensors: \"Fixed and pushed.\" after an unchecked push -> blocks" "[ \"\$(rc)\" = 2 ]"

newturn v12; edit v12
out="$(sstop v12 q12 'Fixed and pushed.')"
check "sensors: \"Fixed and pushed.\" after unverified mutation -> blocks" "[ \"\$(rc)\" = 2 ]"
out="$(sstop v12 q12 'Fixed and pushed.')"
check "sensors: ... and only once" "[ \"\$(rc)\" = 0 ] && [ -z \"\$out\" ]"

for m in 'Fixed; not tested yet.' 'Edited the file.\n\n**Still open**\n- You — which branch?' 'Edited it. Want me to run the suite?' 'Edited. Tests are pending.'; do
  newturn v13; edit v13
  sstop v13 "q13-$m" "$m" >/dev/null
  check "sensors: honest unverified close is silent: $m" "[ \"\$(rc)\" = 0 ]"
done

newturn v14; edit v14
sstop v14 q14 'Edited the config.\n\nNext I will run the suite.' >/dev/null
check "sensors: a promise after real action is not an unverified close" "[ \"\$(rc)\" = 0 ]"

newturn v15
sev v15 '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/brief.md"}}'
sev v15 '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/home/u/.claude/projects/x/memory/m.md"}}'
sstop v15 q15 'Saved the note.' >/dev/null
check "sensors: scratch and memory writes are not deliverables" "[ \"\$(rc)\" = 0 ]"

newturn v16
for i in 1 2 3 4 5 6 7 8 9 10; do edit v16 & done; wait
check "sensors: parallel PostToolUse lines never lose an event" "[ \"\$(grep -c mutation \"$XDG_STATE_HOME/ai-devops/completion-check/turns/v16\")\" = 10 ]"

NOPY="$TMP/nopy"; mkdir -p "$NOPY"
for t in bash jq awk grep cat date mkdir rm mv tr cksum tail printf; do p="$(command -v "$t")" && ln -sf "$p" "$NOPY/$t"; done
newturn v17; edit v17
jq -nc '{hook_event_name:"PostToolUse",session_id:"v17",tool_name:"Bash",tool_input:{command:"pytest"}}' | PATH="$NOPY" "$NOPY/bash" "$HOOK" --sensors >/dev/null 2>&1; nopy_rc=$?
sstop v17 q17 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: python3 missing -> inspection, no crash" "[ $nopy_rc = 0 ] && [ \"\$(rc)\" = 2 ]"
WAPPS="$TMP/WindowsApps"; mkdir -p "$WAPPS"; printf '#!/bin/sh\necho verification\n' >"$WAPPS/python3"; chmod +x "$WAPPS/python3"
newturn v18; edit v18
jq -nc '{hook_event_name:"PostToolUse",session_id:"v18",tool_name:"Bash",tool_input:{command:"echo hi"}}' | PATH="$WAPPS:$NOPY" "$NOPY/bash" "$HOOK" --sensors >/dev/null 2>&1
sstop v18 q18 'Done.\n\nThe task is complete.' >/dev/null
check "sensors: a WindowsApps python3 alias is never run" "[ \"\$(rc)\" = 2 ]"

# Off switches survive reinstall because they are files, not settings.
SW="$TMP/swhome/.config/ai-devops"; mkdir -p "$SW"
swev() { jq -nc --arg s "$1" --argjson e "$2" '{session_id:$s} + $e' | HOME="$TMP/swhome" bash "$HOOK" --sensors >/dev/null 2>&1; }
swstop() { jq -nc --arg s "$1" --arg p "$2" --arg m "$3" '{hook_event_name:"Stop",session_id:$s,prompt_id:$p,last_assistant_message:$m}' | HOME="$TMP/swhome" bash "$HOOK" --sensors >/dev/null 2>"$TMP/swerr"; echo $?; }
: >"$SW/proof-of-done.off"
swev w1 '{"hook_event_name":"UserPromptSubmit"}'; swev w1 '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/r/a"}}'
check "proof-of-done.off: an unverified close is not blocked" "[ \"\$(swstop w1 sq1 'Fixed and pushed.')\" = 0 ]"
rm -f "$SW/proof-of-done.off"; : >"$SW/promise-block.off"
swev w2 '{"hook_event_name":"UserPromptSubmit"}'
check "promise-block.off: an empty promise is nudged, not hard-blocked" "[ \"\$(swstop w2 sq2 'Running now; I will update you.')\" = 0 ]"
rm -f "$SW/promise-block.off"
swev w3 '{"hook_event_name":"UserPromptSubmit"}'
check "with no switch files the empty-promise hard block is back" "[ \"\$(swstop w3 sq3 'Running now; I will update you.')\" = 2 ]"

# Without --sensors (the ZCode / Antigravity path) nothing new happens.
jq -nc '{hook_event_name:"UserPromptSubmit",session_id:"z1"}' | bash "$HOOK" >/dev/null 2>&1
jq -nc '{hook_event_name:"PostToolUse",session_id:"z1",tool_name:"Edit"}' | bash "$HOOK" >/dev/null 2>&1
check "no --sensors: no turn log is written" "[ ! -e \"$XDG_STATE_HOME/ai-devops/completion-check/turns/z1\" ]"
jq -nc '{hook_event_name:"Stop",session_id:"z1",prompt_id:"zq",last_assistant_message:"Fixed and pushed."}' | bash "$HOOK" >/dev/null 2>&1
check "no --sensors: an unverified close is not blocked" "[ \$? -eq 0 ]"

# --- installer -----------------------------------------------------------------
CH="$TMP/claudehome"; mkdir -p "$CH"
printf '{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo pre-existing"}]}]}}\n' > "$CH/settings.json"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "installer registers the hook" "grep -q 'completion-check-hook' \"$CH/settings.json\""
check "installer registers turn-start activity" "jq -e '.hooks.UserPromptSubmit | length == 1' \"$CH/settings.json\" >/dev/null"
check "installer registers tool-use activity" "jq -e '.hooks.PostToolUse | length == 1' \"$CH/settings.json\" >/dev/null"
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

# --- step 2: the hard block must reach Claude (#2835) ---------------------------
check "installer registers --sensors with no swallowed exit status" \
  "jq -e '[.hooks.Stop[].hooks[].command | select(contains(\"completion-check-hook\"))] | all(. == \"bash \\\"\$HOME/.config/ai-devops/completion-check-hook\\\" --sensors\")' \"$CH/settings.json\" >/dev/null"
check "installer registers PostToolUseFailure" "jq -e '.hooks.PostToolUseFailure | length == 1' \"$CH/settings.json\" >/dev/null"
OLD="$TMP/oldhome"; mkdir -p "$OLD"
oldcmd='bash "$HOME/.config/ai-devops/completion-check-hook" 2>/dev/null || true'
jq -n --arg c "$oldcmd" '{hooks:{UserPromptSubmit:[{hooks:[{type:"command",command:$c}]}],PostToolUse:[{hooks:[{type:"command",command:$c}]}],Stop:[{hooks:[{type:"command",command:"echo keep"},{type:"command",command:$c}]}]}}' >"$OLD/settings.json"
mkdir -p "$TMP/fakehome3/.config/ai-devops"; cp "$HOOK" "$TMP/fakehome3/.config/ai-devops/completion-check-hook"
check_out="$(HOME="$TMP/fakehome3" bash "$INSTALL" --check --claude-home "$OLD" --repo-root "$ROOT" 2>&1)"
check "--check DRIFT on the old registration" "printf '%s' \"\$check_out\" | grep -q '^DRIFT'"
HOME="$TMP/fakehome3" bash "$INSTALL" --claude-home "$OLD" --repo-root "$ROOT" >/dev/null 2>&1
check "installer upgrades old Claude registration in place" \
  "[ \"\$(jq '[.. | .command? // empty | select(contains(\"completion-check-hook\"))] | length' \"$OLD/settings.json\")\" = 4 ] && ! grep -q '|| true' \"$OLD/settings.json\" && grep -q 'echo keep' \"$OLD/settings.json\""
HOME="$TMP/fakehome3" bash "$INSTALL" --check --claude-home "$OLD" --repo-root "$ROOT" >/dev/null 2>&1
check "--check OK after the upgrade" "[ \$? -eq 0 ]"
regcmd="$(jq -r '[.hooks.Stop[].hooks[].command | select(contains("completion-check-hook"))][0]' "$OLD/settings.json")"
jq -nc '{hook_event_name:"UserPromptSubmit",session_id:"reg"}' | HOME="$TMP/fakehome3" bash -c "$regcmd" >/dev/null 2>&1
jq -nc '{hook_event_name:"Stop",session_id:"reg",prompt_id:"r1",last_assistant_message:"Running now; I will update you."}' \
  | HOME="$TMP/fakehome3" bash -c "$regcmd" >/dev/null 2>"$TMP/regerr"; reg_rc=$?
check "future promise exits 2 through the registered command line" "[ $reg_rc -eq 2 ] && grep -q 'no implementation' \"$TMP/regerr\""
ZH="$TMP/zhome"; mkdir -p "$ZH/cli"
HOME="$TMP/fakehome4" bash "$INSTALL" --client zcode --zcode-home "$ZH" --repo-root "$ROOT" >/dev/null 2>&1
zcmd="bash \"$TMP/fakehome4/.config/ai-devops/completion-check-hook\""
# The ZCode branch is untouched by #2835: same three events, same command, no --sensors.
check "zcode config byte-identical (no --sensors, same three events)" \
  "jq -e --arg c \"\$zcmd\" '(.hooks.events | keys | sort) == [\"PostToolUse\",\"Stop\",\"UserPromptSubmit\"] and ([.hooks.events[][].hooks[].command] | all(. == \$c)) and ([.hooks.events[][].hooks[].timeoutMs] | all(. == 30000))' \"$ZH/cli/config.json\" >/dev/null"

# --- installer must refuse a broken settings file ------------------------------
BAD="$TMP/badhome"; mkdir -p "$BAD"; printf '{ this is not json' > "$BAD/settings.json"
HOME="$TMP/fakehome2" bash "$INSTALL" --claude-home "$BAD" --repo-root "$ROOT" >/dev/null 2>&1; rc=$?
check "installer fails on unparseable settings" "[ $rc -ne 0 ]"
check "installer did not rewrite the broken file" "grep -q 'this is not json' \"$BAD/settings.json\""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
