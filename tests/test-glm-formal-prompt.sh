#!/usr/bin/env bash
# Formal presentation guidance must preserve caller evidence and ordinary asks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard"
source "$ROOT/tests/lib-test-harness.sh"
export AI_DEVOPS_CONFIG_DIR="$TMP/config" AI_REVIEWER_STATE_BASE="$TMP/state"
source "$ROOT/bin/ai-glm"
PROMPT_FILE=''
PROMPT_TEXT='Discuss the tradeoffs without deciding.'
out="$(read_prompt)"
[ "$(cat "$out")" = "$PROMPT_TEXT" ]; rm -f "$out"
for shape in 'VERDICT: APPROVE exact-head' $'Findings\n## Verdict\nAPPROVE'; do
  PROMPT_TEXT="$shape"
  out="$(read_prompt)"
  grep -q 'Emit exactly one' "$out"
  grep -q 'provisional decision' "$out"
  grep -q 'independent judgment' "$out"
  [ "$(head -c "${#shape}" "$out")" = "$shape" ]
  rm -f "$out"
done
PROMPT_TEXT=''
printf 'Evidence sentinel\nVERDICT: REJECT exact-head\n' > "$TMP/input"
PROMPT_FILE="$TMP/input"
out="$(read_prompt)"
cmp "$TMP/input" <(head -n 2 "$out")
grep -q 'requested exact-head' "$out"
rm -f "$out"
PROMPT_FILE=''
PROMPT_TEXT='Implement a parser for VERDICT: lines.'
out="$(read_prompt implement)"
[ "$(cat "$out")" = "$PROMPT_TEXT" ]; rm -f "$out"
mkdir "$TMP/ownership" "$TMP/session-temp"
out="$(TMPDIR="$TMP/session-temp" read_prompt implement "$TMP/ownership/job.json")"
rm -rf "$TMP/session-temp"
[ "$(cat "$out")" = "$PROMPT_TEXT" ]
[ "$(dirname "$out")" = "$TMP/ownership" ]; rm -f "$out"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # A restrictive parent policy must not prevent the trusted helper from
    # protecting a retained prompt. Inspect its real ACL after publication.
    saved_policy_set="${PSExecutionPolicyPreference+x}"
    saved_policy="${PSExecutionPolicyPreference-}"
    export PSExecutionPolicyPreference=Restricted
    out="$(read_prompt implement "$TMP/ownership/restricted.json")"
    [ "$(cat "$out")" = "$PROMPT_TEXT" ]
    AI_DEVOPS_PRIVATE_HELPER="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")" \
      AI_DEVOPS_PRIVATE_TARGET="$(cygpath -w "$out")" \
      powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \
      '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET'
    rm -f "$out"
    if [ "$saved_policy_set" = x ]; then
      export PSExecutionPolicyPreference="$saved_policy"
    else
      unset PSExecutionPolicyPreference
    fi
    printf '1 Windows restrictive-policy prompt privacy check passed\n'
    ;;
esac
printf '6 GLM formal-presentation and prompt-retention checks passed\n'
