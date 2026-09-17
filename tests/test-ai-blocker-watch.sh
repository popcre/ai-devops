#!/usr/bin/env bash
# Offline tests for bin/ai-blocker-watch: GitHub and every harness are stubs.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-blocker-watch"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/fake"

# Fake GitHub: state files under $TMP/fake decide answers; every call is logged.
cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env bash
F="$FAKE"; printf '%s\n' "$*" >> "$F/calls"
[ -f "$F/fail" ] && exit 1
jqarg=""; args=("$@"); for i in "${!args[@]}"; do [ "${args[$i]}" = --jq ] && jqarg="${args[$((i+1))]}"; done
out(){ if [ -n "$jqarg" ]; then jq -r "$jqarg" <<<"$1"; else printf '%s\n' "$1"; fi; }
case "$*" in
  "issue comment"*) printf '%s\n' "$*" >> "$F/comments"; exit 0 ;;
  "issue create"*) printf '%s\n' "$*" >> "$F/created"; echo 'https://github.com/o/r/issues/31'; exit 0 ;;
  "issue edit"*) printf '%s\n' "$*" >> "$F/edited"; echo '{}'; exit 0 ;;
  "search issues"*) out "$(cat "$F/digest_search.json" 2>/dev/null || echo '[]')" ;;
  *graphql*states:OPEN*) out "$(cat "$F/gql_parents.json" 2>/dev/null || echo '{"data":{"repository":{"issues":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}')" ;;
  *graphql*)
    n=""
    for i in "${!args[@]}"; do
      [ "${args[$i]}" = -F ] || continue
      v="${args[$((i+1))]:-}"
      case "$v" in n=*) n="${v#n=}" ;; esac
    done
    out "$(cat "$F/gql_issue_$n.json" 2>/dev/null || echo '{"data":{"repository":{"issue":{"updatedAt":"2000-01-01T00:00:00Z","createdAt":"2000-01-01T00:00:00Z","body":"","comments":{"nodes":[]},"timelineItems":{"nodes":[]},"blocking":{"nodes":[]}}}}}')" ;;
  *search/issues*) out "$(cat "$F/closed.json" 2>/dev/null || echo '{"items":[]}')" ;;
  *dependencies/blocking*) out "$(cat "$F/blocking.json" 2>/dev/null || echo '[]')" ;;
  *"-X POST"*blocked_by*) printf 'linked\n' >> "$F/links"; echo '{}' ;;
  *dependencies/blocked_by*) out '[]' ;;
  *repos/o/r/issues/5*) out "{\"id\":55,\"state\":\"$(cat "$F/state5" 2>/dev/null || echo open)\",\"title\":\"gate bug\"}" ;;
  *) out '{"id":1,"state":"open","title":"x"}' ;;
esac
EOF
# Fake harness: records how it was resumed.
cat > "$TMP/harness" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >> "$FAKE/resumed"; [ -f "$FAKE/harness_fail" ] && exit 7; exit 0
EOF
chmod +x "$TMP/gh" "$TMP/harness"
# The fixture config drops propagate_on_host so the suite is machine-independent:
# the shipped value names one real machine, and on any other host (CI runners)
# propagation would be skipped and every propagation check below would fail.
jq --arg h "$TMP/harness" '.repos=["o/r"] | del(.propagate_on_host) | .harness.claude=[$h,"claude","{session}","{prompt}"] | .harness.codex=[$h,"codex","{session}"] | .max_wake_attempts=2' \
  "$ROOT/config/blocker-watch.json" > "$TMP/config.json"
export FAKE="$TMP/fake" AI_BLOCKER_WATCH_HOME="$TMP/home" AI_BLOCKER_WATCH_CONFIG="$TMP/config.json" AI_BLOCKER_WATCH_GH="$TMP/gh"
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID ZCODE_SESSION_ID
BW(){ "$SCRIPT" "$@"; }

check 'shipped config is valid and names all three programs' "jq -e '.harness|has(\"claude\") and has(\"codex\") and has(\"zcode\")' '$ROOT/config/blocker-watch.json'"
check 'shipped config names exactly one propagating machine' "jq -e '(.propagate_on_host | type == \"string\" and length > 0)' '$ROOT/config/blocker-watch.json'"
check 'wait refuses a malformed reference' "! BW wait 'not-a-ref' --harness claude --session s1"
check 'wait refuses when the program cannot be detected' "! (cd '$TMP/work' && BW wait o/r#5)"
id="$(cd "$TMP/work" && CODEX_THREAD_ID=thread-abc BW wait o/r#5 --for o/r#9 --note 'finish the loader' 2>/dev/null)"
check 'wait detects Codex from its environment' "jq -e '.harness==\"codex\" and .session==\"thread-abc\" and .state==\"waiting\"' '$TMP/home/waits/$id.json'"
check 'wait --for records the native blocked-by link' "grep -q linked '$FAKE/links'"
id2="$(cd "$TMP/work" && CLAUDE_CODE_SESSION_ID=claude-1 BW wait o/r#5 2>/dev/null)"
check 'wait detects Claude from its environment' "jq -e '.harness==\"claude\"' '$TMP/home/waits/$id2.json'"

check 'tick while the blocker is open resumes nobody' "BW tick && [ ! -f '$FAKE/resumed' ]"
echo closed > "$FAKE/state5"
check 'dry run resumes nobody' "BW tick --dry-run && [ ! -f '$FAKE/resumed' ]"
check 'tick after the blocker closes succeeds' "BW tick"
check 'the Codex session was resumed with its own session ID' "grep -q '|codex thread-abc' '$FAKE/resumed'"
check 'the Claude session got a prompt naming the closed blocker and its note-free wait' "grep -q '|claude claude-1 ai-blocker-watch: the blocker you registered a wait on, o/r#5' '$FAKE/resumed'"
check 'resume runs in the registered directory' "grep -q \"^$(cd "$TMP/work" && pwd)|\" '$FAKE/resumed' || grep -q 'work|' '$FAKE/resumed'"
check 'both waits are marked woken' "[ \"\$(jq -s 'map(select(.state==\"woken\"))|length' '$TMP/home/waits/'*.json)\" = 2 ]"
: > "$FAKE/resumed"
check 'a woken session is never resumed twice' "BW tick && [ ! -s '$FAKE/resumed' ]"

# Propagation up the chain.
echo '{"items":[{"number":5,"repository_url":"https://api.github.com/repos/o/r"}]}' > "$FAKE/closed.json"
echo '[{"number":9,"state":"open","repository_url":"https://api.github.com/repos/o/r"},{"number":8,"state":"closed","repository_url":"https://api.github.com/repos/o/r"}]' > "$FAKE/blocking.json"
rm -f "$TMP/home/last-scan"
check 'tick tells the open issue a closed blocker was blocking' "BW tick && grep -q 'issue comment 9 -R o/r' '$FAKE/comments'"
check 'closed dependents are not commented on' "! grep -q 'issue comment 8' '$FAKE/comments'"
check 'the comment carries a machine marker' "grep -q 'ai-blocker-watch:o/r#5' '$FAKE/comments'"
rm -f "$TMP/home/last-scan"
check 'the same closure is never announced twice' "BW tick && [ \"\$(grep -c 'issue comment 9' '$FAKE/comments')\" = 1 ]"

# One batched search query per tick, never one per repo (issue #549).
: > "$FAKE/calls"
jq '.repos=["o/r","o/r2","o/r3"]' "$TMP/config.json" > "$TMP/config-many.json"
rm -f "$TMP/home/last-scan"
AI_BLOCKER_WATCH_CONFIG="$TMP/config-many.json" BW tick >/dev/null 2>&1
check 'one search query per tick covers every configured repo' "[ \"\$(grep -c 'search/issues' '$FAKE/calls')\" = 1 ]"

# Exactly one machine propagates; every machine still wakes its own sessions.
: > "$FAKE/calls"; : > "$FAKE/comments"
id4="$(cd "$TMP/work" && BW wait o/r#5 --harness claude --session s9 2>/dev/null)"
jq '.propagate_on_host="some-other-machine"' "$TMP/config.json" > "$TMP/config-off.json"
rm -f "$TMP/home/last-scan"
# Run to completion into a file: `BW tick | grep -q` would SIGPIPE the tick at
# its first output line and never reach the wake.
AI_BLOCKER_WATCH_CONFIG="$TMP/config-off.json" BW tick >"$TMP/off-tick.out" 2>&1
check 'a non-propagating machine says so and still exits zero' "grep -q 'only local wakes run here' '$TMP/off-tick.out'"
check 'a non-propagating machine never searches or comments' "[ \"\$(grep -c 'search/issues' '$FAKE/calls')\" = 0 ] && [ ! -s '$FAKE/comments' ]"
check 'a non-propagating machine still wakes its own sessions' "grep -q '|claude s9' '$FAKE/resumed'"
this_host="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
: > "$FAKE/calls"; : > "$FAKE/resumed"
jq --arg h "$this_host" '.propagate_on_host=($h | ascii_upcase)' "$TMP/config.json" > "$TMP/config-host.json"
rm -f "$TMP/home/last-scan"
AI_BLOCKER_WATCH_CONFIG="$TMP/config-host.json" BW tick >/dev/null 2>&1
check 'the propagating machine is matched case-insensitively' "[ \"\$(grep -c 'search/issues' '$FAKE/calls')\" -ge 1 ]"

# Failures must be loud and bounded.
id3="$(cd "$TMP/work" && BW wait o/r#5 --harness claude --session broken 2>/dev/null)"
touch "$FAKE/harness_fail"
check 'a failed resume makes tick exit non-zero' "! BW tick"
check 'a failed resume is retried later' "jq -e '.state==\"waiting\" and .attempts==1' '$TMP/home/waits/$id3.json'"
BW tick >/dev/null 2>&1
check 'after max attempts the wait is left failed for a human' "jq -e '.state==\"failed\" and .attempts==2 and .exit==7' '$TMP/home/waits/$id3.json'"

# A harness program this machine does not have is skipped with a visible error,
# never retried, and never starts a session (issue #549).
jq '.harness.claude=["/nonexistent-machines/claude-bin","{session}"]' "$TMP/config.json" > "$TMP/config-noharness.json"
id5="$(cd "$TMP/work" && AI_BLOCKER_WATCH_CONFIG="$TMP/config-noharness.json" BW wait o/r#5 --harness claude --session s10 2>/dev/null)"
: > "$FAKE/resumed"
check 'a missing harness program makes tick exit non-zero' "! AI_BLOCKER_WATCH_CONFIG='$TMP/config-noharness.json' BW tick"
check 'the wait is marked unrunnable without burning attempts' "jq -e '.state==\"unrunnable\" and .attempts==0 and (.error | contains(\"not found on this machine\"))' '$TMP/home/waits/$id5.json'"
check 'an unrunnable wake never starts a session' "[ ! -s '$FAKE/resumed' ]"
rm -f "$FAKE/harness_fail"; touch "$FAKE/fail"; rm -f "$TMP/home/last-scan"
check 'an unreachable GitHub makes tick exit non-zero' "! BW tick"
check 'a failed scan does not advance the scan window' "[ ! -f '$TMP/home/last-scan' ]"
rm -f "$FAKE/fail"
check 'list shows registered waits' "BW list | grep -q \"$id\""
check 'cancel removes a wait' "BW cancel '$id3' && [ ! -f '$TMP/home/waits/$id3.json' ]"
# Unowned-blocker alarm (#550).
old3d="$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)"
fresh="$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
mkissue(){ # mkissue <n> <body> <comments> <timeline> <blocking> [updatedAt]
  jq -n --arg up "${6:-$old3d}" --arg created "$old3d" --arg body "$2" --argjson comments "$3" --argjson timeline "$4" --argjson blocking "$5" \
    '{data:{repository:{issue:{updatedAt:$up,createdAt:$created,body:$body,comments:{nodes:$comments},timelineItems:{nodes:$timeline},blocking:{nodes:$blocking}}}}}' > "$FAKE/gql_issue_$1.json"
}
jq -n --arg old "$old3d" --arg fresh "$fresh" '{data:{repository:{issues:{pageInfo:{hasNextPage:false,endCursor:null},nodes:[
  {number:20,blockedBy:{nodes:[{number:7,state:"OPEN",title:"gate bug",repository:{nameWithOwner:"o/r"},assignees:{totalCount:0}}]}},
  {number:21,blockedBy:{nodes:[{number:6,state:"OPEN",title:"assigned blocker",repository:{nameWithOwner:"o/r"},assignees:{totalCount:1}}]}},
  {number:25,blockedBy:{nodes:[{number:20,state:"OPEN",title:"chain parent",repository:{nameWithOwner:"o/r"},assignees:{totalCount:1}}]}},
  {number:30,blockedBy:{nodes:[{number:8,state:"OPEN",title:"marker blocker",repository:{nameWithOwner:"o/r"},assignees:{totalCount:0}}]}},
  {number:31,blockedBy:{nodes:[{number:9,state:"OPEN",title:"pr blocker",repository:{nameWithOwner:"o/r"},assignees:{totalCount:0}}]}},
  {number:32,blockedBy:{nodes:[{number:10,state:"OPEN",title:"fresh blocker",repository:{nameWithOwner:"o/r"},assignees:{totalCount:0}}]}}
]}}}}' > "$FAKE/gql_parents.json"
mkissue 7 "gate bug" '[]' '[{"source":{"number":1,"state":"CLOSED"}}]' '[{"number":20,"state":"OPEN","repository":{"nameWithOwner":"o/r"}}]'
mkissue 20 "" '[]' '[]' '[{"number":25,"state":"OPEN","repository":{"nameWithOwner":"o/r"}}]'
mkissue 25 "" '[]' '[]' '[]'
mkissue 8 "" '[{"body":"owner: claude/session-9","createdAt":"2000-01-01T00:00:00Z"}]' '[]' '[]'
mkissue 9 "" '[]' '[{"source":{"number":2,"state":"OPEN"}}]' '[]'
mkissue 10 "" '[]' '[]' '[]' "$fresh"
day="$(date -u +%Y-%m-%d)"
check 'finding an unowned stalled blocker is not a failure' "BW alarm"
check 'the stalled blocker gets one marked request-for-owner comment' "grep -q 'ai-blocker-watch:unowned:o/r#7' '$FAKE/comments'"
check 'an assignee, an owner line, an open pull request and fresh activity each prevent the alarm' "! grep -qE 'unowned:o/r#(6|8|9|10)\b' '$FAKE/comments'"
check 'the stalled blocker is listed in a newly opened digest issue' "grep -q 'issue create' '$FAKE/calls' && grep -q \"ai-blocker-watch digest $day\" '$FAKE/calls'"
check 'a chain three deep is escalated in the digest' "grep -q 'Priority' '$TMP/home/digest-$day.md' && grep -q 'chain 3 deep' '$TMP/home/digest-$day.md'"
check 'owned or active blockers stay out of the digest' "! grep -qE 'o/r#(6|8|9|10)\b' '$TMP/home/digest-$day.md'"

# Second scan: GitHub now holds our comment on #7 — no re-post, no digest churn.
alarmcmt="$(jq -n --arg at "$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ)" '[{body:"<!-- ai-blocker-watch:unowned:o/r#7 --> take it",createdAt:$at}]')"
mkissue 7 "gate bug" "$alarmcmt" '[{"source":{"number":1,"state":"CLOSED"}}]' '[{"number":20,"state":"OPEN","repository":{"nameWithOwner":"o/r"}}]' "$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
echo "[{\"number\":31,\"title\":\"ai-blocker-watch digest $day\"}]" > "$FAKE/digest_search.json"
c_before="$(grep -c 'issue comment' "$FAKE/comments")"
la_before="$(cat "$TMP/home/last-alarm")"
# The scan clock has whole-second resolution; without this sleep the second
# alarm can start inside the same second as the first and "advanced" reads
# as "unchanged" (seen failing a merge-group run exactly that way).
sleep 1.1
if BW alarm && [ "$(grep -c 'issue comment' "$FAKE/comments")" = "$c_before" ] && [ ! -e "$FAKE/edited" ] && [ "$(cat "$TMP/home/last-alarm")" != "$la_before" ]; then
  ok 'a re-scan neither re-posts nor edits an unchanged digest, but advances the scan clock'
else bad 'a re-scan neither re-posts nor edits an unchanged digest, but advances the scan clock'; fi

dry_before="$(grep -cE 'issue (create|edit|comment)' "$FAKE/calls")"
la_dry="$(cat "$TMP/home/last-alarm")"
check 'dry run neither posts nor advances the scan clock' "BW alarm --dry-run && [ \"\$(grep -cE 'issue (create|edit|comment)' "$FAKE/calls")\" = \"\$dry_before\" ] && [ \"\$(cat "$TMP/home/last-alarm")\" = \"\$la_dry\" ]"

# The blocker gains an owner: the digest is updated to all clear, not duplicated.
jq '(.data.repository.issues.nodes[0].blockedBy.nodes[0].assignees.totalCount)=1' "$FAKE/gql_parents.json" > "$FAKE/gql_parents.json.new" && mv "$FAKE/gql_parents.json.new" "$FAKE/gql_parents.json"
check 'a stall that gains an owner updates the digest to all clear' "BW alarm && grep -q 'issue edit 31' '$FAKE/edited' && grep -q 'No open blocker older than' '$TMP/home/digest-$day.md'"

la_fail="$(cat "$TMP/home/last-alarm")"
touch "$FAKE/fail"
check 'a failed scan exits non-zero and does not advance the scan clock' "! BW alarm && [ \"\$(cat "$TMP/home/last-alarm")\" = \"\$la_fail\" ]"
rm -f "$FAKE/fail"

g_before="$(grep -c graphql "$FAKE/calls")"
check 'a tick inside the alarm interval does not rescan' "BW tick && [ \"\$(grep -c graphql "$FAKE/calls")\" = \"\$g_before\" ]"

jq '.alarm_enabled=false' "$TMP/config.json" > "$TMP/config-noalarm.json"
check 'a disabled alarm refuses to run standalone' "! AI_BLOCKER_WATCH_CONFIG='$TMP/config-noalarm.json' BW alarm"

# Only the machine named by propagate_on_host may post alarm comments and
# digests; every other machine must leave GitHub untouched.
jq '.propagate_on_host="not-this-machine-xyz"' "$TMP/config.json" > "$TMP/config-foreign.json"
gate_before="$(grep -cE 'issue (create|edit|comment)' "$FAKE/calls")"
la_gate="$(cat "$TMP/home/last-alarm" 2>/dev/null || printf none)"
check 'a foreign host runs no alarm posting and advances no clock' "AI_BLOCKER_WATCH_CONFIG='$TMP/config-foreign.json' BW alarm && [ \"\$(grep -cE 'issue (create|edit|comment)' "$FAKE/calls")\" = \"\$gate_before\" ] && [ \"\$(cat "$TMP/home/last-alarm")\" = \"\$la_gate\" ]"

mkdir "$TMP/home/tick.lock"
check 'a running tick blocks a second one without doing work' "BW tick 2>&1 | grep -q 'another tick is running'"
rmdir "$TMP/home/tick.lock"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
