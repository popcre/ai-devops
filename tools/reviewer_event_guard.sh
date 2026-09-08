# Sourced before provider setup. The outer shell records the invocation; the
# inner, unchanged wrapper retains its own traps, permissions, stdin and status.
# No command arguments, prompts, output or credentials enter the event ledger.
reviewer_event_guard(){
  local provider="$1" wrapper="$2"; shift 2
  case "${1:-}" in
    doctor) [ "${2:-}" = --live ] || return 0;;
    ''|-h|--help|help|--version|list|show|status|logs|result|path|transcript) return 0;;
  esac
  # This re-entry already belongs to the outer recorded invocation. Nothing
  # may launch between DeepSeek's credential handoff and its secret scrub.
  [ "$provider" != deepseek ] || [ "${AI_DEEPSEEK_REEXEC:-}" != 1 ] || return 0
  if [ "${AI_REVIEW_EVENT_PARENT:-}" = "$PPID" ] && [ "${AI_REVIEW_EVENT_PROVIDER:-}" = "$provider" ]; then
    unset AI_REVIEW_EVENT_PARENT AI_REVIEW_EVENT_PROVIDER
    return 0
  fi
  local root python event_id child='' result=0 received='' event_tool name operation=invocation
  local -a event_env=()
  root="$(cd "$(dirname "$wrapper")/.." && pwd -P)"
  python="$(command -v python3 || command -v python)" || { printf 'reviewer event recording requires Python 3\n' >&2; exit 1; }
  event_tool="$root/tools/reviewer_events.py"
  for name in PATH HOME USERPROFILE SYSTEMROOT COMSPEC PATHEXT TEMP TMP TMPDIR AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR AI_REVIEW_EVENT_RUN_ID; do
    [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  done
  name="AI_${provider^^}_CALLER"; [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  name="AI_${provider^^}_REVIEW_CALLER"; [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  [ "$provider" != kimi ] || [ "${1:-}" != start ] || operation=async-submission
  event_id="$(env -i "${event_env[@]}" "$python" "$event_tool" begin "$provider" "$operation")" || exit 1
  export AI_REVIEW_EVENT_PARENT="$$" AI_REVIEW_EVENT_PROVIDER="$provider" AI_REVIEW_EVENT_RUN_ID="$event_id"
  # Forward only to this invocation's child; never search process names or
  # change another review's state. A killed supervisor leaves an unmatched start.
  trap 'received=TERM; [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true' TERM
  trap 'received=INT; [ -z "$child" ] || kill -INT "$child" 2>/dev/null || true' INT
  trap 'received=HUP; [ -z "$child" ] || kill -HUP "$child" 2>/dev/null || true' HUP
  # Bash normally ignores INT in asynchronous children. Reset inherited signal
  # dispositions before entering the wrapper so its cancellation traps work.
  env --default-signal=INT --default-signal=QUIT "$BASH" "$wrapper" "$@" <&0 & child=$!
  [ -z "$received" ] || kill "-$received" "$child" 2>/dev/null || true
  while true; do
    received=''
    if wait "$child"; then result=0; else result=$?; fi
    # An interrupted wait reports the signal, not the child's eventual result.
    # Wait once more even if the child exited while the forwarding trap ran.
    [ -n "$received" ] || break
  done
  trap - TERM INT HUP
  if ! env -i "${event_env[@]}" "$python" "$event_tool" finish "$provider" "$event_id" "$result"; then
    printf 'reviewer finished, but durable event recording failed; start evidence retained\n' >&2
    [ "$result" -ne 0 ] || result=1
  fi
  exit "$result"
}
