#!/usr/bin/env bash
# Offline tests for bin/ai-blocker-watch: GitHub and every harness are stubs.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-blocker-watch"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/fake"
cat > "$TMP/brief.md" <<'BRIEF'
Improve how the product description extractor pulls the specific description out of the full description.
Done: the parser handles the single-paragraph case.
Next: handle multi-paragraph descriptions, then add a regression test.
BRIEF

# Fake GitHub: state files under $TMP/fake decide answers; every call is logged.
cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env bash
F="$FAKE"; printf '%s\n' "$*" >> "$F/calls"
printf '%s\n' "${AI_GH_CALLER:-unset}" >> "$F/callers"
[ -f "$F/fail" ] && exit 1
jqarg=""; args=("$@"); for i in "${!args[@]}"; do [ "${args[$i]}" = --jq ] && jqarg="${args[$((i+1))]}"; done
out(){ if [ -n "$jqarg" ]; then jq -r "$jqarg" <<<"$1"; else printf '%s\n' "$1"; fi; }
bodyfile=""; for i in "${!args[@]}"; do [ "${args[$i]}" = --body-file ] && bodyfile="${args[$((i+1))]}"; done
[ -n "$bodyfile" ] && cp "$bodyfile" "$F/body"
case "$*" in
  "label create"*) rm -f "$F/nolabel"; exit 0 ;;
  "repo view"*) out '{"nameWithOwner":"o/r"}' ;;
  "search issues"*--label*) out "$(cat "$F/find.json" 2>/dev/null || echo '[]')" ;;
  "issue comment"*) printf '%s\n' "$*" >> "$F/comments"; exit 0 ;;
  "issue create"*) [ -f "$F/nolabel" ] && exit 1; printf '%s\n' "$*" >> "$F/created"; echo 'https://github.com/o/r/issues/31'; exit 0 ;;
  "issue edit"*) [ -f "$F/nolabel" ] && exit 1; printf '%s\n' "$*" >> "$F/edited"; echo '{}'; exit 0 ;;
  "search issues"*) out "$(cat "$F/digest_search.json" 2>/dev/null || echo '[]')" ;;
  *graphql*states:OPEN*)
    # One open-issue query serves both scans: merge the links and parents
    # fixtures by issue number, as GitHub would answer the combined query, and
    # page it 100 at a time (the cursor is the next offset).
    after=0; for i in "${!args[@]}"; do case "${args[$i]}" in after=*) after="${args[$i]#after=}" ;; esac; done
    empty='{"data":{"repository":{"issues":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}}'
    [ -f "$F/gql_links.json" ] && lf="$F/gql_links.json" || { lf="$F/empty.json"; echo "$empty" > "$lf"; }
    [ -f "$F/gql_parents.json" ] && pf="$F/gql_parents.json" || { pf="$F/empty.json"; echo "$empty" > "$pf"; }
    out "$(jq -cn --argjson off "$after" --slurpfile l "$lf" --slurpfile p "$pf" '$l[0] as $l | $p[0] as $p |
      $l * {data:{repository:{issues:{nodes:
        ([$l.data.repository.issues.nodes[], $p.data.repository.issues.nodes[]] | group_by(.number)
         | map(reduce .[] as $x ({}; . + ($x | del(.blockedBy)) | .blockedBy.nodes = ((.blockedBy.nodes // []) + ($x.blockedBy.nodes // []) | group_by(.number) | map(add)))))}}}}
      | .data.repository.issues |= (.nodes as $all | .nodes = $all[$off:$off+100]
          | .pageInfo = {hasNextPage: ($all | length > $off+100), endCursor: (if ($all | length > $off+100) then ($off+100 | tostring) else null end)})')" ;;
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
  *issues/31/comments*) out "$(cat "$F/comments31.json" 2>/dev/null || echo '[]')" ;;
  *repos/o/r/pulls/5*) out "$(cat "$F/pull5.json" 2>/dev/null || echo '{"merged":true}')" ;;
  *repos/o/r/issues/5*) pr=null; [ -f "$F/is_pr" ] && pr='{"url":"x"}'; out "{\"id\":55,\"state\":\"$(cat "$F/state5" 2>/dev/null || echo open)\",\"title\":\"gate bug\",\"pull_request\":$pr}" ;;
  *) out '{"id":1,"state":"open","title":"x"}' ;;
esac
EOF
# Fake harness: records how it was resumed.
cat > "$TMP/harness" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${AI_GH_CALLER:-unset}" >> "$FAKE/resumed-callers"
printf '%s|%s\n' "$PWD" "$*" >> "$FAKE/resumed"; [ -f "$FAKE/harness_fail" ] && exit 7; exit 0
EOF
chmod +x "$TMP/gh" "$TMP/harness"
# The fixture config drops propagate_on_host so the suite is machine-independent:
# the shipped value names one real machine, and on any other host (CI runners)
# propagation would be skipped and every propagation check below would fail.
jq --arg h "$TMP/harness" '.repos=["o/r"] | del(.propagate_on_host) | .harness.claude=[$h,"claude","{session}","{prompt}"] | .harness.codex=[$h,"codex","{session}"] | .max_wake_attempts=2 | .transcript_glob={claude:"",codex:"",zcode:"",mimo:""}' \
  "$ROOT/config/blocker-watch.json" > "$TMP/config.json"
export FAKE="$TMP/fake" AI_BLOCKER_WATCH_HOME="$TMP/home" AI_BLOCKER_WATCH_CONFIG="$TMP/config.json" AI_BLOCKER_WATCH_GH="$TMP/gh"
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID ZCODE_SESSION_ID
BW(){ "$SCRIPT" "$@"; }

check 'shipped config is valid and names all four programs' "jq -e '.harness|has(\"claude\") and has(\"codex\") and has(\"zcode\") and has(\"mimo\")' '$ROOT/config/blocker-watch.json'"
check 'shipped config names exactly one propagating machine' "jq -e '(.propagate_on_host | type == \"string\" and length > 0)' '$ROOT/config/blocker-watch.json'"
check 'wait refuses a malformed reference' "! BW wait 'not-a-ref' --harness claude --session s1"
check 'wait refuses when the program cannot be detected' "! (cd '$TMP/work' && BW wait o/r#5 --park 'x' --brief-file '$TMP/brief.md')"
id="$(cd "$TMP/work" && CODEX_THREAD_ID=thread-abc BW wait o/r#5 --for o/r#7 --note 'finish the loader' --brief-file "$TMP/brief.md" 2>/dev/null)"
check 'wait detects Codex from its environment' "jq -e '.harness==\"codex\" and .session==\"thread-abc\" and .state==\"waiting\"' '$TMP/home/waits/$id.json'"
check 'wait --for records the native blocked-by link' "grep -q linked '$FAKE/links'"
id2="$(cd "$TMP/work" && CLAUDE_CODE_SESSION_ID=claude-1 BW wait o/r#5 --park 'claude one' --brief-file "$TMP/brief.md" 2>/dev/null)"
check 'wait detects Claude from its environment' "jq -e '.harness==\"claude\"' '$TMP/home/waits/$id2.json'"

check 'tick while the blocker is open resumes nobody' "BW tick && [ ! -f '$FAKE/resumed' ]"
echo closed > "$FAKE/state5"
check 'dry run resumes nobody' "BW tick --dry-run && [ ! -f '$FAKE/resumed' ]"
check 'tick after the blocker closes succeeds' "AI_GH_CALLER=interactive BW tick"
check 'every BlockerWatch transport call has its own caller label' "[ -s '$FAKE/callers' ] && ! grep -vx ai-blocker-watch '$FAKE/callers'"
check 'resumed sessions retain their own caller instead of inheriting BlockerWatch' "[ \"\$(grep -c '^interactive$' '$FAKE/resumed-callers')\" = 2 ] && ! grep -q ai-blocker-watch '$FAKE/resumed-callers'"
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
id4="$(cd "$TMP/work" && BW wait o/r#5 --harness claude --session s9 --park 's nine' --brief-file "$TMP/brief.md" 2>/dev/null)"
# The outcome comment on a parked issue is a separate mechanism (#617);
# mark it already posted so this check sees only propagation's own writes.
jq -n --arg m "<!-- ai-blocker-watch:woke:$id4 -->" '[{body:$m}]' > "$FAKE/comments31.json"
jq '.propagate_on_host="some-other-machine"' "$TMP/config.json" > "$TMP/config-off.json"
rm -f "$TMP/home/last-scan"
# Run to completion into a file: `BW tick | grep -q` would SIGPIPE the tick at
# its first output line and never reach the wake.
AI_BLOCKER_WATCH_CONFIG="$TMP/config-off.json" BW tick >"$TMP/off-tick.out" 2>&1
check 'a non-propagating machine says so and still exits zero' "grep -q 'only local wakes run here' '$TMP/off-tick.out'"
check 'a non-propagating machine never searches or comments' "[ \"\$(grep -c 'search/issues' '$FAKE/calls')\" = 0 ] && [ ! -s '$FAKE/comments' ]"
check 'a non-propagating machine still wakes its own sessions' "grep -q '|claude s9' '$FAKE/resumed'"
rm -f "$FAKE/comments31.json"
this_host="$(hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1)"
: > "$FAKE/calls"; : > "$FAKE/resumed"
jq --arg h "$this_host" '.propagate_on_host=($h | ascii_upcase)' "$TMP/config.json" > "$TMP/config-host.json"
rm -f "$TMP/home/last-scan"
AI_BLOCKER_WATCH_CONFIG="$TMP/config-host.json" BW tick >/dev/null 2>&1
check 'the propagating machine is matched case-insensitively' "[ \"\$(grep -c 'search/issues' '$FAKE/calls')\" -ge 1 ]"

# Failures must be loud and bounded.
id3="$(cd "$TMP/work" && BW wait o/r#5 --harness claude --session broken --park 'broken one' --brief-file "$TMP/brief.md" 2>/dev/null)"
touch "$FAKE/harness_fail"
check 'a failed resume makes tick exit non-zero' "! BW tick"
check 'a failed resume is retried later' "jq -e '.state==\"waiting\" and .attempts==1' '$TMP/home/waits/$id3.json'"
BW tick >/dev/null 2>&1
check 'after max attempts the wait is left failed for a human' "jq -e '.state==\"failed\" and .attempts==2 and .exit==7' '$TMP/home/waits/$id3.json'"

# A harness program this machine does not have is skipped with a visible error,
# never retried, and never starts a session (issue #549).
jq '.harness.claude=["/nonexistent-machines/claude-bin","{session}"]' "$TMP/config.json" > "$TMP/config-noharness.json"
id5="$(cd "$TMP/work" && AI_BLOCKER_WATCH_CONFIG="$TMP/config-noharness.json" BW wait o/r#5 --harness claude --session s10 --park 's ten' --brief-file "$TMP/brief.md" 2>/dev/null)"
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
rm -f "$FAKE/edited"
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

# Blocked-by link maintenance from db-work-scope depends_on fences (#596).
fence(){ printf '```db-work-scope\nstatus: ready\nwork_type: repo-maintenance\nroute: repo-maintenance\npriority: 100\ndepends_on: %s\nobjects:\n```\n' "$1"; }
lnode(){ jq -n --argjson n "$1" --argjson did "$2" --arg body "$3" --argjson bb "$4" \
  '{number:$n,databaseId:$did,body:$body,blockedBy:{nodes:($bb|map({number:.}))}}'; }
lnodes(){ rm -f "$FAKE/gql_parents.json"; jq -n --argjson nodes "$1" '{data:{repository:{issues:{pageInfo:{hasNextPage:false,endCursor:null},nodes:$nodes}}}}' > "$FAKE/gql_links.json"; }
check 'shipped config enables link maintenance' "jq -e '.links_enabled == true and (.links_interval_minutes | type == \"number\" and . > 0)' '$ROOT/config/blocker-watch.json'"
: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"
lnodes "[$(lnode 20 220 "$(fence 7)" '[]'), $(lnode 7 207 'gate bug' '[]')]"
check 'a tick records a missing blocked-by link from a depends_on fence' "BW tick && grep -q linked '$FAKE/links'"
check 'the link used the blocker id found in the open-issue scan' "grep -q 'issue_id=207' '$FAKE/calls'"
check 'the links scan clock advanced' "[ -f '$TMP/home/last-links' ]"

: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"
lnodes "[$(lnode 20 220 "$(fence 7)" '[7]'), $(lnode 7 207 'gate bug' '[]')]"
check 'a present link is left alone' "BW tick && [ ! -f '$FAKE/links' ]"

: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"
lnodes "[$(lnode 21 221 "$(fence soon)" '[]'), $(lnode 22 222 'two fences
```db-work-scope
depends_on: 7
```
```db-work-scope
depends_on: 8
```' '[]')]"
BW tick > /dev/null 2> "$TMP/links-err.out"
check 'malformed fences are skipped and counted, never a failure' "grep -q 'malformed db-work-scope' '$TMP/links-err.out' && [ ! -f '$FAKE/links' ]"
check 'the malformed count is reported in the tick log' "grep -q 'skipped 2 malformed' '$TMP/links-err.out'"

: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"
lnodes "[$(lnode 23 223 "$(fence '#7, 12')" '[]'), $(lnode 7 207 'gate bug' '[]')]"
check '#-prefixed and comma-listed deps each get a link' "BW tick && [ \"\$(grep -c linked '$FAKE/links')\" = 2 ]"
check 'an open blocker resolves its id without an extra read' "grep -q 'issue_id=207' '$FAKE/calls'"
check 'a closed or absent blocker falls back to one REST read' "grep -q 'repos/o/r/issues/12' '$FAKE/calls' && grep -q 'issue_id=1' '$FAKE/calls'"

: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"
lnodes "[$(lnode 24 224 "$(fence 24)" '[]')]"
BW tick > /dev/null 2> "$TMP/links-err.out"
check 'a self-dependency is skipped, not posted' "[ ! -f '$FAKE/links' ] && grep -q 'names itself' '$TMP/links-err.out'"

: > "$FAKE/calls"; rm -f "$FAKE/links"
lnodes "[$(lnode 20 220 "$(fence 7)" '[]'), $(lnode 7 207 'gate bug' '[]')]"
check 'a dry run records no link' "BW links --dry-run 2> '$TMP/links-dry.out' && [ ! -f '$FAKE/links' ] && grep -q 'would record o/r#20 is blocked by o/r#7' '$TMP/links-dry.out'"
check 'a standalone links run creates the link' "BW links && grep -q linked '$FAKE/links'"
ll_before="$(grep -c databaseId "$FAKE/calls")"
check 'a tick inside the links interval does not rescan' "BW tick && [ \"\$(grep -c databaseId '$FAKE/calls')\" = \"\$ll_before\" ]"
jq '.links_enabled=false' "$TMP/config.json" > "$TMP/config-nolinks.json"
check 'a disabled links config refuses a standalone run' "! AI_BLOCKER_WATCH_CONFIG='$TMP/config-nolinks.json' BW links"
gate_before="$(grep -c databaseId "$FAKE/calls")"
ll_gate="$(cat "$TMP/home/last-links" 2>/dev/null || printf none)"
# The standalone run above created $FAKE/links; remove it so absence below
# proves the foreign host posted nothing.
rm -f "$FAKE/links"
check 'a foreign host neither reads nor posts links' "AI_BLOCKER_WATCH_CONFIG='$TMP/config-foreign.json' BW links && [ \"\$(grep -c databaseId '$FAKE/calls')\" = \"\$gate_before\" ] && [ ! -f '$FAKE/links' ] && [ \"\$(cat "$TMP/home/last-links")\" = \"\$ll_gate\" ]"
touch "$FAKE/fail"
check 'an unreachable GitHub fails the links run and writes no clock' "! BW links && [ \"\$(cat "$TMP/home/last-links")\" = \"\$ll_gate\" ]"
rm -f "$FAKE/fail"

mkdir -p "$TMP/transcripts" "$TMP/mainco" "$TMP/gone"
jq --arg t "$TMP/transcripts/{session}.jsonl" --arg h "$TMP/harness" \
  '.transcript_glob.claude=$t | .transcript_glob.codex=$t
   | .harness_fresh.claude=[$h,"fresh-claude","{prompt}"]
   | .harness_fresh.codex=[$h,"fresh-codex","{prompt}"]
   | .alarm_enabled=false | .links_enabled=false' \
  "$TMP/config.json" > "$TMP/config-modes.json"
BW2(){ AI_BLOCKER_WATCH_HOME="$TMP/home2" AI_BLOCKER_WATCH_CONFIG="$TMP/config-modes.json" "$SCRIPT" "$@"; }
W2="$TMP/home2/waits"

check 'shipped config carries the parked labels, fresh commands and transcript globs' \
  "jq -e '.parked_label and .resumed_label and (.find_owners|length>0) and (.harness_fresh|has(\"claude\") and has(\"codex\") and has(\"zcode\") and has(\"mimo\")) and (.transcript_glob|has(\"claude\"))' '$ROOT/config/blocker-watch.json'"
check 'wait refuses without a brief file' \
  "! (cd '$TMP/work' && BW2 wait o/r#5 --harness claude --session nobrief --park 'no brief' >/dev/null 2>&1) && (cd '$TMP/work' && BW2 wait o/r#5 --harness claude --session nobrief --park 'no brief' 2>&1 | grep -q 'needs --brief-file')"
check 'wait refuses with neither --for nor --park' \
  "! (cd '$TMP/work' && BW2 wait o/r#5 --harness claude --session nopark --brief-file '$TMP/brief.md' >/dev/null 2>&1) && (cd '$TMP/work' && BW2 wait o/r#5 --harness claude --session nopark --brief-file '$TMP/brief.md' 2>&1 | grep -q 'name the parked issue')"

: > "$FAKE/calls"; rm -f "$FAKE/created" "$FAKE/body"
pid="$(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session parked-1 --park 'product description extraction' --brief-file "$TMP/brief.md" 2>/dev/null)"
check 'wait --park opens a labelled parked issue and records it' \
  "grep -q 'issue create' '$FAKE/created' && grep -q -- '--label parked' '$FAKE/created' && jq -e '.parked_issue==\"o/r#31\" and .parked_url!=\"\"' '$W2/$pid.json'"
check 'the parked issue body carries the plain-English summary, the blocker and an owner line' \
  "grep -q 'What this is about' '$FAKE/body' && grep -q 'description extractor' '$FAKE/body' && grep -q 'gate bug' '$FAKE/body' && grep -q '^owner: ai-blocker-watch' '$FAKE/body'"
check 'wait --park spends no calls creating a label that already exists' "! grep -q 'label create' '$FAKE/calls'"
check 'wait --park reads the blocker exactly once' "[ \"\$(grep -c 'api repos/o/r/issues/5 ' '$FAKE/calls')\" = 1 ]"
: > "$FAKE/calls"; touch "$FAKE/nolabel"
lid="$(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session nolabel1 --park 'label missing' --brief-file "$TMP/brief.md" 2>/dev/null)"
check 'wait --park creates the label when GitHub refuses a missing one, then parks'   "grep -q 'label create parked' '$FAKE/calls' && jq -e '.parked_issue==\"o/r#31\"' '$W2/$lid.json'"
rm -f "$W2/$lid.json"  # keep later wake counts about the original waits
check 'the parked issue is recorded as blocked by the blocker' "grep -q linked '$FAKE/links'"

: > "$FAKE/comments"; : > "$FAKE/edited"
fid="$(cd "$TMP/work" && BW2 wait o/r#5 --for o/r#9 --harness claude --session parked-2 --brief-file "$TMP/brief.md" 2>/dev/null)"
check 'wait --for marks the existing issue parked and comments the brief' \
  "grep -q 'issue comment 9' '$FAKE/comments' && grep -q 'issue edit 9' '$FAKE/edited' && grep -q -- '--add-label parked' '$FAKE/edited' && jq -e '.parked_issue==\"o/r#9\"' '$W2/$fid.json'"

# A pull request blocker: GitHub refuses a "blocked by" link to a PR, so the
# wait must register without trying one (it used to die after parking).
touch "$FAKE/is_pr"; rm -f "$FAKE/links"; : > "$FAKE/calls"
prid="$(cd "$TMP/work" && BW2 wait o/r#5 --for o/r#9 --harness claude --session prblock1 --brief-file "$TMP/brief.md" 2>"$TMP/prerr")"
check 'a pull-request blocker registers a wait without a GitHub link'   "[ ! -f '$FAKE/links' ] && ! grep -q blocked_by '$FAKE/calls' && jq -e '.blocker==\"o/r#5\" and .state==\"waiting\"' '$W2/$prid.json'"
check 'a pull-request blocker is explained, not silent' "grep -q 'is a pull request' '$TMP/prerr'"
check 'a wait --for costs at most five GitHub calls' "[ \"\$(grep -c . '$FAKE/calls')\" -le 5 ]"
rm -f "$FAKE/is_pr" "$W2/$prid.json"

touch "$FAKE/fail"
(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session failcrea --park 'never lands' --brief-file "$TMP/brief.md") >/dev/null 2>&1 || true
rm -f "$FAKE/fail"
check 'a GitHub failure leaves no half-registered wait' "! ls '$W2' | grep -q failcrea"

check 'wait records the main checkout of the current repository' \
  "mid=\"\$(cd '$ROOT' && BW2 wait o/r#5 --harness claude --session maincheck --park 'main checkout' --brief-file '$TMP/brief.md' 2>/dev/null)\" && jq -e '.main_checkout != \"\"' \"$W2/\$mid.json\" && BW2 cancel \"\$mid\""

# Mode 1: the folder and the transcript are both still there.
rm -f "$W2/$pid.json" "$W2/$fid.json"
echo closed > "$FAKE/state5"
rid="$(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session live-1 --park 'resumable work' --brief-file "$TMP/brief.md" 2>/dev/null)"
touch "$TMP/transcripts/live-1.jsonl"
: > "$FAKE/resumed"; : > "$FAKE/comments"; : > "$FAKE/edited"
BW2 tick >/dev/null 2>&1
check 'wake resumes the original session when the folder and transcript exist' \
  "grep -q '|claude live-1' '$FAKE/resumed' && jq -e '.mode==\"resumed\" and .state==\"woken\"' '$W2/$rid.json'"
check 'a wake writes one outcome comment on the parked issue and swaps its label' \
  "[ \"\$(grep -c 'issue comment 31' '$FAKE/comments')\" = 1 ] && grep -q 'Resumed the original claude session' '$FAKE/comments' && grep -q -- '--remove-label parked' '$FAKE/edited' && grep -q -- '--add-label resumed' '$FAKE/edited'"

# Mode 2: the worktree was deleted, so a brand-new session starts in the main checkout.
gid="$(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session gone-1 --park 'fresh start work' --brief-file "$TMP/brief.md" --cwd "$TMP/gone" 2>/dev/null)"
jq --arg m "$TMP/mainco" '.main_checkout=$m' "$W2/$gid.json" > "$W2/$gid.new" && mv "$W2/$gid.new" "$W2/$gid.json"
rm -rf "$TMP/gone"
: > "$FAKE/resumed"; : > "$FAKE/comments"
BW2 tick >/dev/null 2>&1
check 'wake starts a fresh session in the main checkout when the folder is gone' \
  "grep -q 'fresh-claude' '$FAKE/resumed' && grep -q \"^$TMP/mainco|\" '$FAKE/resumed' && jq -e '.mode==\"fresh\" and .state==\"woken\"' '$W2/$gid.json'"
check 'the fresh session is told to read the parked issue and make its own worktree' \
  "grep -q 'issues/31' '$FAKE/resumed' && grep -q 'own worktree from current upstream' '$FAKE/resumed'"
check 'the fresh outcome is reported on the parked issue' \
  "grep -q 'Started a fresh claude session' '$FAKE/comments'"

# The same outcome is never posted twice.
jq '.state="waiting"' "$W2/$gid.json" > "$W2/$gid.new" && mv "$W2/$gid.new" "$W2/$gid.json"
jq -n --arg m "<!-- ai-blocker-watch:woke:$gid -->" '[{body:$m}]' > "$FAKE/comments31.json"
: > "$FAKE/comments"
BW2 tick >/dev/null 2>&1
check 'an outcome already on the parked issue is never posted twice' "[ ! -s '$FAKE/comments' ]"
rm -f "$FAKE/comments31.json" "$W2/$gid.json"

# Mode 3: nothing can restart it — say so on the issue and fail the tick.
mkdir -p "$TMP/vanished"
oid="$(cd "$TMP/vanished" && BW2 wait o/r#5 --harness claude --session orph-1 --park 'orphaned work' --brief-file "$TMP/brief.md" 2>/dev/null)"
jq '.main_checkout=""' "$W2/$oid.json" > "$W2/$oid.new" && mv "$W2/$oid.new" "$W2/$oid.json"
rm -rf "$TMP/vanished"
: > "$FAKE/comments"; : > "$FAKE/resumed"
check 'a wait nothing can restart fails the tick' "! BW2 tick"
check 'an orphaned wait is marked and explained on its parked issue' \
  "jq -e '.state==\"orphaned\"' '$W2/$oid.json' && grep -q 'A person must pick it up' '$FAKE/comments' && [ ! -s '$FAKE/resumed' ]"
rm -f "$W2/$oid.json"

# An old record, registered before parked issues existed, still resumes as before.
jq -n --arg cwd "$TMP/work" '{id:"old-1",blocker:"o/r#5",for:"",note:"",harness:"claude",session:"old-1",cwd:$cwd,registered_at:"2026-01-01T00:00:00Z",state:"waiting",attempts:0}' > "$W2/old-1.json"
touch "$TMP/transcripts/old-1.jsonl"
: > "$FAKE/resumed"; : > "$FAKE/comments"
BW2 tick >/dev/null 2>&1
check 'an old record without a parked issue still resumes and comments nowhere' \
  "grep -q '|claude old-1' '$FAKE/resumed' && [ ! -s '$FAKE/comments' ] && jq -e '.state==\"woken\"' '$W2/old-1.json'"

# A wait on a time, and a wait released by whichever comes first.
echo open > "$FAKE/state5"
soon="$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)"; past="$(date -u -d '-2 hours' +%Y-%m-%dT%H:%M:%SZ)"
tid="$(cd "$TMP/work" && BW2 wait --until "$soon" --harness claude --session time-1 --park 'check back later' --brief-file "$TMP/brief.md" 2>/dev/null)"
touch "$TMP/transcripts/time-1.jsonl"
: > "$FAKE/resumed"
check 'wait --until registers a wait with no blocker' "jq -e '.blocker==\"\" and .until!=\"\"' '$W2/$tid.json'"
check 'a time wait does not wake early' "BW2 tick && [ ! -s '$FAKE/resumed' ]"
jq --arg u "$past" '.until=$u' "$W2/$tid.json" > "$W2/$tid.new" && mv "$W2/$tid.new" "$W2/$tid.json"
BW2 tick >/dev/null 2>&1
check 'a time wait wakes once its time has passed' \
  "grep -q '|claude time-1' '$FAKE/resumed' && grep -q 'called back at' '$FAKE/resumed'"
cid="$(cd "$TMP/work" && BW2 wait o/r#5 --until "$soon" --harness claude --session both-1 --park 'job with a check-in' --brief-file "$TMP/brief.md" 2>/dev/null)"
touch "$TMP/transcripts/both-1.jsonl"
: > "$FAKE/resumed"
check 'a combined wait waits for whichever comes first' "BW2 tick && [ ! -s '$FAKE/resumed' ]"
echo closed > "$FAKE/state5"
BW2 tick >/dev/null 2>&1
check 'a combined wait wakes when the blocker closes first' \
  "grep -q '|claude both-1' '$FAKE/resumed' && jq -e '.state==\"woken\"' '$W2/$cid.json'"

# A blocking pull request that closed unmerged must say so.
echo '{"merged":false}' > "$FAKE/pull5.json"
echo pr > "$FAKE/is_pr"
prid="$(cd "$TMP/work" && BW2 wait o/r#5 --harness claude --session pr-1 --park 'waiting on a pull request' --brief-file "$TMP/brief.md" 2>/dev/null)"
touch "$TMP/transcripts/pr-1.jsonl"
: > "$FAKE/resumed"
BW2 tick >/dev/null 2>&1
check 'wake says when a blocking pull request closed unmerged' \
  "grep -q 'WITHOUT being merged' '$FAKE/resumed'"
rm -f "$FAKE/is_pr" "$W2/$prid.json"

# Plain-language search across the configured owners.
jq -n '[{repository:{nameWithOwner:"o/r"},number:31,title:"product description extraction",state:"OPEN",updatedAt:"2026-09-18T10:00:00Z",url:"https://github.com/o/r/issues/31"}]' > "$FAKE/find.json"
check 'find prints matching parked work' "BW2 find description extraction | grep -q 'o/r#31'"
check 'find searches the configured owners and both labels' \
  "[ \"\$(BW2 find description extraction >/dev/null 2>&1; grep -c 'search issues' '$FAKE/calls')\" -ge 2 ]"
echo '[]' > "$FAKE/find.json"
check 'find reports no match plainly' "BW2 find nothing here 2>&1 | grep -q 'no parked work matches'"
check 'list shows the parked issue column' "BW2 list | awk -F'\t' '\$6==\"o/r#9\" || \$6==\"o/r#5\" || \$6!=\"\"' | grep -q ."

# Replay (#658 P5): 240 open issues over three pages, 60 missing depends_on
# links (to owned blockers, which the alarm must skip) and 60 parents of
# unowned blockers. One tick with both scans due must walk each repo's open
# issues once, create every link, and alarm on every unowned blocker. Set
# AI_BLOCKER_WATCH_OLD to a previous build to compare outcomes and calls.
AI_BLOCKER_WATCH_OLD="${AI_BLOCKER_WATCH_OLD:-}"
# The node budget is raised so every candidate is read; the budget has its own path.
jq '.alarm_max_nodes = 500' "$TMP/config.json" > "$TMP/config-replay.json"
replay(){ # replay <script>: fresh state, both scans due, one tick
  rm -rf "$TMP/home" "$FAKE/links" "$FAKE/comments" "$FAKE/created" "$FAKE/edited" "$FAKE"/gql_issue_*.json "$FAKE/digest_search.json"; : > "$FAKE/calls"
  AI_BLOCKER_WATCH_CONFIG="$TMP/config-replay.json" "$1" tick > "$TMP/replay.out" 2>&1
}
rnodes=""; pnodes=""
for i in $(seq 101 220); do
  if [ "$i" -le 160 ]; then rnodes="$rnodes$(lnode "$i" "$((i+1000))" "$(fence "$((i+120))")" '[]'),"
    rnodes="$rnodes{\"number\":$((i+120)),\"databaseId\":$((i+1120)),\"title\":\"owned $((i+120))\",\"assignees\":{\"totalCount\":1},\"body\":\"\",\"blockedBy\":{\"nodes\":[]}},"
  else rnodes="$rnodes$(lnode "$i" "$((i+1000))" "blocker $i" '[]'),"
    pnodes="$pnodes{\"number\":$((i-120)),\"blockedBy\":{\"nodes\":[{\"number\":$i,\"state\":\"OPEN\",\"title\":\"blocker $i\",\"repository\":{\"nameWithOwner\":\"o/r\"},\"assignees\":{\"totalCount\":0}}]}},"; fi
done
lnodes "[${rnodes%,}]"
jq -n --argjson nodes "[${pnodes%,}]" '{data:{repository:{issues:{pageInfo:{hasNextPage:false,endCursor:null},nodes:$nodes}}}}' > "$FAKE/gql_parents.json"
replay "$SCRIPT"
check 'replay: every one of 60 missing links is created once' "[ \"\$(grep -c linked '$FAKE/links')\" = 60 ]"
check 'replay: every one of 60 unowned blockers gets its owner request' "[ \"\$(grep -c 'ai-blocker-watch:unowned:' '$FAKE/comments')\" = 60 ]"
check 'replay: both scans share one three-page open-issue walk' "[ \"\$(grep -c 'states:OPEN' '$FAKE/calls')\" = 3 ] && grep -q 'after=200' '$FAKE/calls'"
if [ -n "$AI_BLOCKER_WATCH_OLD" ]; then # compare against a previous build
  sort "$FAKE/comments" > "$TMP/new.comments"; cp "$FAKE/links" "$TMP/new.links"; new_calls="$(wc -l < "$FAKE/calls")"
  replay "$AI_BLOCKER_WATCH_OLD"; sort "$FAKE/comments" > "$TMP/old.comments"
  check 'replay: outcomes match the previous build' "cmp -s '$TMP/new.comments' '$TMP/old.comments' && cmp -s '$TMP/new.links' '$FAKE/links'"
  printf '  replay calls: previous %s, now %s\n' "$(wc -l < "$FAKE/calls")" "$new_calls"
fi

# A link created this tick is seen by the same tick's alarm without a re-read.
lnodes "[$(lnode 50 250 "$(fence 51)" '[]'), {\"number\":51,\"databaseId\":251,\"title\":\"new unowned blocker\",\"assignees\":{\"totalCount\":0},\"body\":\"\",\"blockedBy\":{\"nodes\":[]}}]"
replay "$SCRIPT"
check 'a new link to an unowned blocker is alarmed in the same tick' "grep -q linked '$FAKE/links' && grep -q 'ai-blocker-watch:unowned:o/r#51' '$FAKE/comments' && [ \"\$(grep -c 'states:OPEN' '$FAKE/calls')\" = 1 ]"
check 'a failed snapshot edit drops the copy instead of crashing' "grep -q '^snapshot_drop()' '$SCRIPT'"

# Scans share a tick: a due scan pulls the other forward from half its interval, never sooner.
mkdir -p "$TMP/home"; rm -f "$FAKE/links"
date -u -d '70 minutes ago' +%Y-%m-%dT%H:%M:%SZ > "$TMP/home/last-alarm"
date -u -d '35 minutes ago' +%Y-%m-%dT%H:%M:%SZ > "$TMP/home/last-links"; ll="$(cat "$TMP/home/last-links")"
AI_BLOCKER_WATCH_CONFIG="$TMP/config-replay.json" BW tick >/dev/null 2>&1
check 'a due alarm pulls the links scan forward past half its interval' "[ \"\$(cat '$TMP/home/last-links')\" != \"$ll\" ]"
date -u -d '70 minutes ago' +%Y-%m-%dT%H:%M:%SZ > "$TMP/home/last-alarm"
date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ > "$TMP/home/last-links"; ll="$(cat "$TMP/home/last-links")"
AI_BLOCKER_WATCH_CONFIG="$TMP/config-replay.json" BW tick >/dev/null 2>&1
check 'a links scan inside half its interval is not pulled forward' "[ \"\$(cat '$TMP/home/last-links')\" = \"$ll\" ]"

# A depends_on naming a pull request is skipped, never a failed scan (the
# refused link otherwise re-ran the full scan every tick).
: > "$FAKE/calls"; rm -f "$FAKE/links" "$TMP/home/last-links"; touch "$FAKE/is_pr"
lnodes "[$(lnode 24 224 "$(fence 5)" '[]')]"
check 'a pull request named in depends_on is skipped without failing the scan' "BW tick 2>'$TMP/pr-links.err' && [ ! -f '$FAKE/links' ] && [ -f '$TMP/home/last-links' ] && grep -q 'is a pull request' '$TMP/pr-links.err'"
rm -f "$FAKE/is_pr"

mkdir "$TMP/home/tick.lock"
check 'a running tick blocks a second one without doing work' "BW tick 2>&1 | grep -q 'another tick is running'"
rmdir "$TMP/home/tick.lock"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
