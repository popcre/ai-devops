# Sourced before provider setup. The outer shell records the invocation; the
# inner, unchanged wrapper retains its own traps, permissions, stdin and status.
# No command arguments, prompts, output or credentials enter the event ledger.
reviewer_event_evidence(){
  local operation="$1" provider="$2"; shift 2
  local python event_tool name
  local -a evidence_env=()
  [ -n "${AI_REVIEW_EVENT_RUN_ID:-}" ] || { printf 'durable evidence requires an invocation identity\n' >&2; return 1; }
  python="$(command -v python3 || command -v python)" || return 1
  event_tool="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/reviewer_events.py"
  for name in PATH HOME USERPROFILE SYSTEMROOT COMSPEC PATHEXT TEMP TMP TMPDIR AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR; do
    [ -z "${!name:-}" ] || evidence_env+=("$name=${!name}")
  done
  env -i "${evidence_env[@]}" "$python" "$event_tool" "$operation" "$provider" "$AI_REVIEW_EVENT_RUN_ID" "$@"
}

reviewer_event_publish_report(){
  local provider="$1" report="$2" facts='{"phase":"report-publication"}'
  [ "$#" -lt 3 ] || facts="$3"
  local recovery_var="${provider^^}_RECOVERY_EVENT_RUN_ID" state_var="${provider^^}_RECOVERY_STATE" head_var="${provider^^}_ORIGINAL_HEAD_SHA"
  if [ "$#" -lt 3 ] && [ -n "${!recovery_var:-}" ]; then
    [[ "${!recovery_var}" =~ ^[0-9a-f]{32}$ ]] || return 1
    facts="{\"phase\":\"report-publication\",\"original_invocation_id\":\"${!recovery_var}\"}"
    if [ -n "${!state_var:-}" ]; then
      [ "${!state_var}" = completed-stale-source ] && [[ "${!head_var:-}" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || return 1
      facts="${facts%\}},\"recovery_state\":\"completed-stale-source\",\"original_head_sha\":\"${!head_var}\"}"
    fi
  fi
  reviewer_event_evidence require-report "$provider" || return 1
  reviewer_event_evidence publish-report "$provider" "$report" "$facts" >/dev/null || return 1
  reviewer_event_evidence verify-reports "$provider" >/dev/null
}

reviewer_event_publish_patch(){ reviewer_event_evidence publish-patch "$1" "$2" >/dev/null; }

reviewer_event_verify_private(){
  local python event_tool name
  local -a evidence_env=()
  python="$(command -v python3 || command -v python)" || return 1
  event_tool="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/reviewer_events.py"
  for name in PATH HOME USERPROFILE SYSTEMROOT COMSPEC PATHEXT TEMP TMP TMPDIR AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR; do
    [ -z "${!name:-}" ] || evidence_env+=("$name=${!name}")
  done
  env -i "${evidence_env[@]}" "$python" "$event_tool" "$@" >/dev/null
}
reviewer_event_verify_sandbox(){ reviewer_event_verify_private verify-sandbox "$1"; }
reviewer_event_verify_owner(){ reviewer_event_verify_private verify-owner "$1" "$2"; }

reviewer_event_cleanup_allowed(){
  local provider="$1"
  [ -n "${AI_REVIEW_EVENT_RUN_ID:-}" ] || return 0
  reviewer_event_evidence verify-reports "$provider" >/dev/null || {
    printf 'required evidence is not durable; retaining local output and review workspace\n' >&2
    return 1
  }
}

# True when AI_REVIEW_EVENT_RUN_ID has a started row and no finished row.
# Used instead of `kill -0` for nested inheritance: Windows/MSYS cannot
# reliably liveness-check a PID across process trees.
reviewer_event_run_is_open(){
  local python name run_id provider
  local -a evidence_env=()
  run_id="${AI_REVIEW_EVENT_RUN_ID:-}"
  provider="${AI_REVIEW_EVENT_PROVIDER:-}"
  [[ "$run_id" =~ ^[0-9a-f]{32}$ ]] || return 1
  [ -n "$provider" ] || return 1
  python="$(command -v python3 || command -v python)" || return 1
  for name in PATH HOME USERPROFILE SYSTEMROOT COMSPEC PATHEXT TEMP TMP TMPDIR AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR; do
    [ -z "${!name:-}" ] || evidence_env+=("$name=${!name}")
  done
  env -i "${evidence_env[@]}" "$python" - "$run_id" "$provider" <<'PY'
import json, os, sys
from pathlib import Path
run_id, provider = sys.argv[1], sys.argv[2]
base = os.environ.get("AI_REVIEW_EVENT_DIR") or (
    (os.environ.get("HOME") or str(Path.home())) + "/.local/state/ai-devops/reviewer-events")
path = Path(base) / "events.jsonl"
if not path.is_file():
    sys.exit(1)
started = finished = False
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    try:
        row = json.loads(line)
    except ValueError:
        continue
    if row.get("run_id") != run_id:
        continue
    if row.get("provider") != provider:
        # A run_id is only open for the provider that started it.
        sys.exit(1)
    if row.get("event") == "started":
        started = True
    elif row.get("event") == "finished":
        finished = True
sys.exit(0 if started and not finished else 1)
PY
}

reviewer_event_guard(){
  local provider="$1" wrapper="$2"; shift 2
  case "${1:-}" in
    doctor) [ "${2:-}" = --live ] || return 0;;
    ''|-h|--help|help|--version|list|show|status|logs|result|path|transcript) return 0;;
  esac
  # This re-entry already belongs to the outer recorded invocation. Nothing
  # may launch between DeepSeek's credential handoff and its secret scrub.
  [ "$provider" != deepseek ] || [ "${AI_DEEPSEEK_REEXEC:-}" != 1 ] || return 0
  # Two shapes inherit the SAME invocation:
  #   1. Direct child of the recorder (parent-match).
  #   2. Nested runner the already-re-entered pool launched. ai-review-pool
  #      reserves require-report, then spawns the provider runner; that runner
  #      must publish onto the same run_id or the reserved obligation is left
  #      unfilled ("required report is not durably published") even though the
  #      review text is on disk.
  # PROVIDER + RUN_ID identify the open invocation. Parent-match is the
  # direct-child path. Nested grandchildren (pool -> runner) also inherit
  # while that invocation is still open in the ledger — Windows/MSYS
  # `kill -0` across process trees is unreliable, so liveness comes from
  # the event ledger, not the PID. A finished run_id fails closed later
  # (require-report/publish-report refuse to rewrite a completed invocation).
  # qualify-live / doctor --live is its own safety proof, even when auto_requalify
  # launches it from inside an open review. It must never inherit that review's
  # run_id via the open-run rule: the probe runs in a private fixture (a different
  # repository), so binding its sandbox onto the review run is refused
  # ("sandbox evidence source differs from invocation"). Only the probe recorder's
  # own direct child keeps that qualification invocation.
  local entry_cmd="${1:-}" entry_live=0
  [ "$entry_cmd" = qualify-live ] && entry_live=1
  [ "$entry_cmd" = doctor ] && [ "${2:-}" = --live ] && entry_live=1
  if [ "${AI_REVIEW_EVENT_PROVIDER:-}" = "$provider" ] && [ -n "${AI_REVIEW_EVENT_RUN_ID:-}" ] \
     && [ -n "${AI_REVIEW_EVENT_PARENT:-}" ]; then
    if [ "${AI_REVIEW_EVENT_PARENT:-}" = "$PPID" ]; then
      AI_REVIEW_EVENT_OWNER_PID="${AI_REVIEW_EVENT_OWNER_PID:-${AI_REVIEW_EVENT_PARENT:-$$}}"
      export -n AI_REVIEW_EVENT_OWNER_PID
      return 0
    fi
    if [ "$entry_live" -eq 0 ] && reviewer_event_run_is_open; then
      AI_REVIEW_EVENT_OWNER_PID="${AI_REVIEW_EVENT_OWNER_PID:-${AI_REVIEW_EVENT_PARENT:-$$}}"
      export -n AI_REVIEW_EVENT_OWNER_PID
      return 0
    fi
  fi
  # Declining inherit (e.g. a qualify-live probe launched from an open review)
  # must begin its own invocation on a clean identity, never resume the outer run.
  unset AI_REVIEW_EVENT_PARENT AI_REVIEW_EVENT_PROVIDER AI_REVIEW_EVENT_RUN_ID
  local root python event_id child='' result=0 received='' observed_signal='' facts event_tool name operation=invocation
  local -a event_env=()
  root="$(cd "$(dirname "$wrapper")/.." && pwd -P)"
  python="$(command -v python3 || command -v python)" || { printf 'reviewer event recording requires Python 3\n' >&2; exit 1; }
  event_tool="$root/tools/reviewer_events.py"
  for name in PATH HOME USERPROFILE SYSTEMROOT COMSPEC PATHEXT TEMP TMP TMPDIR AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR AI_REVIEW_EVENT_RUN_ID AI_REVIEW_EVENT_OWNER_PID; do
    [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  done
  name="AI_${provider^^}_CALLER"; [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  name="AI_${provider^^}_REVIEW_CALLER"; [ -z "${!name:-}" ] || event_env+=("$name=${!name}")
  [ "$provider" != kimi ] || [ "${1:-}" != start ] || operation=async-submission
  [ "$provider" != qwen ] || [ "${1:-}" != finalize ] || operation=local-finalization
  [ "$provider" != deepseek ] || [ "${1:-}" != finalize ] || operation=local-finalization
  [ "$provider" != glm ] || [ "${1:-}" != recover ] || operation=local-finalization
  [ "$provider" != muse ] || [ "${1:-}" != reconcile ] || operation=local-finalization
  event_id="$(env -i "${event_env[@]}" "$python" "$event_tool" begin "$provider" "$operation")" || exit 1
  AI_REVIEW_EVENT_OWNER_PID="${AI_REVIEW_EVENT_OWNER_PID:-$$}"
  export AI_REVIEW_EVENT_PARENT="$$" AI_REVIEW_EVENT_PROVIDER="$provider" AI_REVIEW_EVENT_RUN_ID="$event_id" AI_REVIEW_EVENT_OWNER_PID
  # Forward only to this invocation's child; never search process names or
  # change another review's state. A killed supervisor leaves an unmatched start.
  trap 'received=TERM; observed_signal=TERM; [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true' TERM
  trap 'received=INT; observed_signal=INT; [ -z "$child" ] || kill -INT "$child" 2>/dev/null || true' INT
  trap 'received=HUP; observed_signal=HUP; [ -z "$child" ] || kill -HUP "$child" 2>/dev/null || true' HUP
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
  # A signal proves its name, not who sent it or whether remote paid work ended.
  # Keep that observation after the interrupted-wait loop clears `received`.
  facts='{"phase":"wrapper-exit"}'
  if [ -n "$observed_signal" ]; then
    facts="{\"source\":\"os-signal\",\"phase\":\"wrapper-running\",\"signal\":\"$observed_signal\"}"
  fi
  if ! env -i "${event_env[@]}" "$python" "$event_tool" finish "$provider" "$event_id" "$result" "$facts"; then
    printf 'reviewer finished, but required evidence verification failed; private recovery evidence retained\n' >&2
    [ "$result" -ne 0 ] || result=1
  fi
  exit "$result"
}

# Out-of-credit stop (Albert, 2026-09-24): the session that hits a billing or
# credit failure must learn it from this run, not from a later investigation.
# reviewer_credit_scan PROVIDER FILE... classifies provider error evidence with
# the one shared classifier; on a match it records the out-of-credit quarantine
# and keeps the two contract lines in REVIEWER_CREDIT_HIT. Call it only on a
# failure path with provider error channels, never on assistant content.
reviewer_credit_scan(){
  local provider="$1" python tool dir out rc=0 file
  local -a scan=()
  shift
  for file in "$@"; do
    if [ -n "$file" ] && [ -f "$file" ]; then scan+=(--scan "$file"); fi
  done
  [ "${#scan[@]}" -gt 0 ] || return 3
  python="$(command -v python3 || command -v python)" || return 1
  tool="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/reviewer_admission.py"
  dir="${AI_REVIEW_QUARANTINE_DIR:-$HOME/.local/state/ai-devops/review-quarantine}"
  out="$("$python" "$tool" credit "$provider" --directory "$dir" "${scan[@]}" --record)" || rc=$?
  [ "$rc" = 0 ] || return "$rc"
  [ -n "$out" ] || return 1
  REVIEWER_CREDIT_HIT="$out"
}

# reviewer_credit_exit prints the recorded diagnosis and exits 92; it returns
# without effect when no out-of-credit failure was classified.
reviewer_credit_exit(){
  [ -n "${REVIEWER_CREDIT_HIT:-}" ] || return 0
  printf '%s\n' "$REVIEWER_CREDIT_HIT" >&2
  exit 92
}

reviewer_credit_stop(){ reviewer_credit_scan "$@" || true; reviewer_credit_exit; }
