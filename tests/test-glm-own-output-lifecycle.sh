#!/usr/bin/env bash
# Invented offline wrapper-control fixtures. No server, key or provider calls.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$FIXTURE_ROOT"' EXIT
for fixture_case in queue quota unknown-post repeated observational; do
  mkdir -p "$FIXTURE_ROOT/$fixture_case"
  AI_GLM_SOURCE="$ROOT/bin/ai-glm" FIXTURE="$FIXTURE_ROOT/$fixture_case" CASE="$fixture_case" \
    timeout 20 bash <<'CASES'
set -euo pipefail
source "$AI_GLM_SOURCE"
GLM_PROFILE=formal-review; CALLER=codex; MODEL=glm-5.3; PROVIDER=zai-coding-plan
PROMPT_TEXT=''; PROMPT_FILE=''; OPT_BASE=''; OPT_TESTS=''; OPT_DECISION=''; OPT_ASSERT_HEAD=''
TURN_META="$FIXTURE/meta.json"; ACTIVE_DIAG_RUN=""; POLL_SECS=1
mkdir -p "$FIXTURE/boundary" "$FIXTURE/source"
original_deadline=$(( $(date +%s) + 600 ))
jq -n --arg source "$FIXTURE/source" --arg boundary "$FIXTURE/boundary" --argjson deadline "$original_deadline" '
 {name:"owned",caller:"codex",type:"review",model:"glm-5.3",provider:"zai-coding-plan",
  opencode_session_id:"ses_owned",repository_root:$source,boundary_root:$boundary,
  remote_turn:{state:"pending",head:("b"*40),packet_sha256:("c"*64),boundary_root:$boundary,
   deadline_epoch:$deadline,original_invocation_id:("d"*32),previous_message_id:"msg_initial",
   own_output_recovery:{version:1,maximum:1,initial_prompt_sha256:("e"*64)}}}' > "$TURN_META"
chmod 600 "$TURN_META"
jq '.remote_turn|del(.previous_message_id,.own_output_state)' "$TURN_META" > "$FIXTURE/original-binding"
record_diagnostic(){ :; }
sleep(){ :; }
api(){
  [ "$1" = GET ] || { echo 'unexpected API mutation' >&2; return 91; }
  case "$2" in
    /api/session/ses_owned/message?limit=200) printf '{"data":[]}' ;;
    /session/status) printf '{}' ;;
    *) return 92 ;;
  esac
}
permission_http(){
  HTTP_STATUS=200; GLM_HTTP_DEADLINE_HIT=0
  if [ "$1" = GET ]; then
    if [ -e "$FIXTURE/rejected" ] && [ "$CASE" != repeated ]; then HTTP_BODY='{"data":[]}'
    else HTTP_BODY='{"data":[{"id":"per_owned","sessionID":"ses_owned","action":"external_directory","resources":["/invented/*"],"save":["/invented/*"],"source":{"type":"tool","messageID":"msg_owned","callID":"call_owned"}}]}'; fi
  else
    [ "$2" = /api/session/ses_owned/permission/per_owned/reply ]
    printf '%s' "$3" | jq -e '.reply=="reject" and (.message|type=="string" and length>0)' >/dev/null
    printf '%s\n' "$3" >> "$FIXTURE/permission-posts"
    touch "$FIXTURE/rejected"; HTTP_BODY='{}'
  fi
}
own_output_command(){
  local operation="$1"
  cat >/dev/null
  case "$operation" in
    qualify)
      [ ! -e "$FIXTURE/claim" ] || return 1
      touch "$FIXTURE/claim"
      printf '{"claim":"fixture-only","permission_id":"per_owned"}' ;;
    mirror)
      printf '{"destination":"/invented/full-output.txt","readable_view":"/invented/readable-page.jsonl","sha256":"%064d","bytes":51415}' 0 ;;
    intermediate)
      [ ! -e "$FIXTURE/intermediate" ] || return 1
      touch "$FIXTURE/intermediate"
      printf '{"prompt":"Read exact invented private mirror, original review unchanged.","sha256":"%064d","intermediate_id":"msg_intermediate","receipt":"fixture-only"}' 0 ;;
    submission)
      [ ! -e "$FIXTURE/submission" ] || return 1
      touch "$FIXTURE/submission"
      printf '{"state":"submission-reserved","receipt":"fixture-only"}' ;;
    *) return 90 ;;
  esac
}
capacity_gate(){
  printf 'checked\n' >> "$FIXTURE/admission-checks"
  [ "$CASE" != quota ]
}
send_prompt(){
  [ "$1" = ses_owned ] && [ "$GLM_REQUESTED_DEADLINE" = "$original_deadline" ]
  [ -e "$FIXTURE/submission" ] && [ -e "$FIXTURE/admission-checks" ]
  [ "$(jq -r .remote_turn.own_output_state.phase "$TURN_META")" = submitting ]
  grep -q 'original review unchanged' "$2"
  printf 'one submission\n' >> "$FIXTURE/provider-posts"
  [ "$CASE" != unknown-post ]
}
handle_permissions ses_owned owned review "$FIXTURE/boundary"
[ "$(jq -r .remote_turn.own_output_state.phase "$TURN_META")" = mirrored ]
[ "$(wc -l < "$FIXTURE/permission-posts")" -eq 1 ]
[ ! -e "$FIXTURE/provider-posts" ]
if [ "$CASE" = repeated ]; then
  if (handle_permissions ses_owned owned review "$FIXTURE/boundary") > "$FIXTURE/repeat.log" 2>&1; then exit 1; fi
  [ "$(wc -l < "$FIXTURE/permission-posts")" -eq 1 ]
  [ ! -e "$FIXTURE/provider-posts" ]
elif [ "$CASE" = observational ]; then
  REPO_OVERRIDE="$FIXTURE/source"
  repo_id(){ printf fixture; }; meta_path(){ printf '%s' "$TURN_META"; }; lock_path(){ printf '%s/lock' "$FIXTURE"; }; lock_acquire(){ :; }
  # Actual read-only recover must reject an intermediate result even after the
  # wrapper dies between exclusive reservation and corrective submission.
  cp "$FIXTURE/claim" "$FIXTURE/dddddddddddddddddddddddddddddddd.own-output.claim.json"
  if (cmd_recover owned) > "$FIXTURE/observational.log" 2>&1; then exit 1; fi
  grep -q 'observational recover cannot generate or publish' "$FIXTURE/observational.log" || { cat "$FIXTURE/observational.log" >&2; exit 1; }
  [ ! -e "$FIXTURE/provider-posts" ]
elif [ "$CASE" = queue ]; then
  last_assistant(){
    local count=0
    [ ! -e "$FIXTURE/polls" ] || count="$(cat "$FIXTURE/polls")"
    count=$((count+1)); printf '%s' "$count" > "$FIXTURE/polls"
    [ "$count" -le 6 ] || return 93
    if [ "$count" -le 4 ]; then printf '{"id":"msg_intermediate","finish":"stop"}'
    else printf '{"id":"msg_corrected","finish":"stop"}'; fi
  }
  GLM_REQUESTED_DEADLINE="$original_deadline"
  result="$(await_turn ses_owned owned review "$FIXTURE/boundary")"
  [ "$(printf '%s' "$result" | jq -r .id)" = msg_corrected ]
  [ "$(wc -l < "$FIXTURE/provider-posts")" -eq 1 ]
  [ "$(jq -r .remote_turn.own_output_state.phase "$TURN_META")" = submitted ]
else
  if (continue_own_output_review ses_owned owned "$FIXTURE/boundary" '{"id":"msg_intermediate","finish":"stop"}') > "$FIXTURE/refused.log" 2>&1; then exit 1; fi
  if [ "$CASE" = quota ]; then
    [ ! -e "$FIXTURE/provider-posts" ]
    [ "$(jq -r .remote_turn.own_output_state.phase "$TURN_META")" = intermediate-retained ]
  else
    [ "$(wc -l < "$FIXTURE/provider-posts")" -eq 1 ]
    [ "$(jq -r .remote_turn.own_output_state.phase "$TURN_META")" = submitting ]
    if (continue_own_output_review ses_owned owned "$FIXTURE/boundary" '{"id":"msg_intermediate","finish":"stop"}') >/dev/null 2>&1; then exit 1; fi
    [ "$(wc -l < "$FIXTURE/provider-posts")" -eq 1 ]
  fi
fi
jq '.remote_turn|del(.previous_message_id,.own_output_state)' "$TURN_META" > "$FIXTURE/final-binding"
cmp "$FIXTURE/original-binding" "$FIXTURE/final-binding"
CASES
done
printf 'PASS 5 invented lifecycle cases: reverse queue, quota denial, unknown POST, once-only, observational recovery\n'
