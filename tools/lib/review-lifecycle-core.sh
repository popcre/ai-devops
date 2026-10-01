#!/usr/bin/env bash
# review-lifecycle-core.sh — the one review runner core.
#
# plan_reviewer-pipeline-core.md Phase D (issue #1114). Sourced only by
# bin/ai-review-engine. This file OWNS task gate, identity, sandbox, packet
# seal + durable store (store-before-delete), lifecycle terminal, report floor,
# and cleanup-after-store for BOTH contracts (review and implement).
#
# Doors supply provider bits only: binary/profile, credentials, model pin,
# tool set, parse to our report shape. A door that deletes a packet or sandbox
# is a rejected shape; see tests/test-ai-review-engine.sh purity checks.
#
# Structural forcing function: pool/preflight/allocator refuse a review that
# bypasses the runner. rlc_export_runner_token is the only writer of
# AI_REVIEW_RUNNER_CORE; doors and pool refuse without it.

# shellcheck shell=bash

RLC_VERSION="1.0.0"
RLC_STAMP="review-lifecycle-core/1"
RLC_RUNNER_NAME="ai-review-engine"

# Tag/path budget unified in Phase D (plan §11): 48 tag chars / 64 dir chars.
# Prior mixed budgets (muse caller 40, gemini tag 64, sandbox dir 77) are not
# left behind. short_name below is the single implementation.
RLC_TAG_MAX=48
RLC_DIR_MAX=64

# An approval must be backed by a report a human can read (lifecycle §report).
MIN_REPORT_CHARS="${AI_REVIEW_MIN_REPORT_CHARS:-200}"

rlc_die() {
  printf '%s: error: %s\n' "$RLC_RUNNER_NAME" "$*" >&2
  exit 1
}
rlc_note() { printf '%s: %s\n' "$RLC_RUNNER_NAME" "$*" >&2; }

# Capture a helper's stdout in the CALLER's shell (not a command substitution),
# so rlc_die inside the helper stops the runner instead of only ending a
# subshell. This is the only supported way to take output from an rlc_* helper
# that may refuse.
rlc_capture() { # rlc_capture VAR FUNC [args...]
  local __var="$1"; shift
  local __tmp __rc
  __tmp="$(mktemp)" || rlc_die 'could not allocate capture buffer.'
  set +e
  "$@" > "$__tmp"
  __rc=$?
  set -e
  if [ "$__rc" -ne 0 ]; then
    rm -f "$__tmp"
    rlc_die "step failed ($__rc): $*"
  fi
  printf -v "$__var" '%s' "$(cat "$__tmp")"
  rm -f "$__tmp"
}

# This file's own location, captured at source time. rlc_init resolves toolkit
# paths from here so a caller's argv or working directory cannot retarget the
# review-critical binaries.
RLC_CORE_FILE="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  _rlc_real="$(readlink -f "$RLC_CORE_FILE" 2>/dev/null || true)"
  [ -z "$_rlc_real" ] || RLC_CORE_FILE="$_rlc_real"
  unset _rlc_real
fi

# ---------------------------------------------------------------------------
# Tool resolution. bin/* is symlinked onto PATH, so resolve the real script
# location before looking for sibling tools.
# ---------------------------------------------------------------------------
rlc_init() {
  local dir candidate
  dir="$(cd "$(dirname "$RLC_CORE_FILE")" && pwd -P)"
  RLC_BIN_DIR=""
  for candidate in "$dir/../bin" "$dir/../../bin"; do
    [ -x "$candidate/ai-review-packet" ] || [ -f "$candidate/ai-review-packet" ] || continue
    RLC_BIN_DIR="$(cd "$candidate" && pwd -P)"
    break
  done
  [ -n "$RLC_BIN_DIR" ] || rlc_die 'cannot locate toolkit bin/ next to the review runner core.'
  RLC_ROOT="$(cd "$RLC_BIN_DIR/.." && pwd -P)"
  RLC_PACKET="${AI_REVIEW_PACKET_BIN:-$RLC_BIN_DIR/ai-review-packet}"
  RLC_SANDBOX="${AI_REVIEW_SANDBOX_BIN:-$RLC_BIN_DIR/ai-review-sandbox}"
  RLC_LIFECYCLE="${AI_REVIEW_LIFECYCLE_BIN:-$RLC_BIN_DIR/ai-review-lifecycle}"
  RLC_SCOREBOARD="${AI_REVIEW_SCOREBOARD_BIN:-$RLC_BIN_DIR/ai-review-scoreboard}"
  RLC_GATES_LIB="$RLC_ROOT/tools/lib/task-gates.sh"
  [ -f "$RLC_GATES_LIB" ] || rlc_die 'cannot find the task-gate library.'
  # shellcheck source=task-gates.sh
  . "$RLC_GATES_LIB"
  RLC_DOORS_JSON="${AI_REVIEW_RUNNER_DOORS_JSON:-$RLC_ROOT/config/review-runner-doors.json}"
  export RLC_STAMP RLC_RUNNER_NAME RLC_VERSION
}

# ---------------------------------------------------------------------------
# Tag budget. One implementation, one limit. Hash-bounds long names so a
# session name can never grow a sandbox dir past the budget.
# ---------------------------------------------------------------------------
rlc_short_name() { # rlc_short_name NAME MAX -> NAME bounded to MAX
  local name="$1" max="${2:-$RLC_TAG_MAX}" digest
  case "$max" in ''|*[!0-9]*) max="$RLC_TAG_MAX";; esac
  [ "${#name}" -le "$max" ] && { printf '%s' "$name"; return 0; }
  digest="$(printf '%s' "$name" | sha256sum | cut -c1-12)"
  printf '%s-%s' "${name:0:$((max - 13))}" "$digest"
}

rlc_assert_tag_budget() { # rlc_assert_tag_budget TAG
  local tag="$1"
  [ "${#tag}" -le "$RLC_DIR_MAX" ] || rlc_die "tag exceeds the ${RLC_DIR_MAX}-char dir budget: ${#tag}"
  return 0
}

# ---------------------------------------------------------------------------
# Report floor. Same substance rule as bin/ai-review-lifecycle, kept here so
# the runner can refuse a bare decision before the terminal transition.
# ---------------------------------------------------------------------------
rlc_report_substance() { # FILE -> substantive character count
  tr -d '\r' < "$1" \
    | sed -E -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' \
    | grep -Ev '^$' \
    | grep -Ev '^#{1,6}([[:space:]].*)?$' \
    | grep -Ev '^([-=_*][[:space:]]*){3,}$' \
    | grep -Evi '^[[:punct:][:space:]]*(verdict|decision|result|status)?[[:punct:][:space:]]*(approve[d]?|reject(ed)?|blocked|pass(ed)?|fail(ed)?|lgtm|ok|no[[:space:]]issues[[:space:]]found)[[:punct:][:space:]]*[0-9a-f]*[[:punct:][:space:]]*$' \
    | tr -d '[:space:]' | wc -c | tr -d ' '
}

rlc_report_floor_ok() { # FILE -> 0 when the report clears MIN_REPORT_CHARS
  local count
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  count="$(rlc_report_substance "$1")"
  [ "$count" -ge "$MIN_REPORT_CHARS" ]
}

# ---------------------------------------------------------------------------
# Structural forcing function. The engine is the only writer of the token;
# pool and doors refuse work that did not come through it.
# ---------------------------------------------------------------------------
rlc_export_runner_token() {
  export AI_REVIEW_RUNNER_CORE="$RLC_STAMP"
  export AI_REVIEW_VIA_RUNNER=1
  export AI_REVIEW_RUNNER_NAME="$RLC_RUNNER_NAME"
}

rlc_require_runner_token() {
  [ "${AI_REVIEW_RUNNER_CORE:-}" = "$RLC_STAMP" ] || {
    printf '%s: refusing work that bypasses the shared review runner (%s).\n' \
      "${RLC_RUNNER_NAME}" "$RLC_STAMP" >&2
    return 1
  }
  return 0
}

# Door registry. A provider listed here has a runner-native door and MUST be
# dispatched through ai-review-engine. Anything else is a bypass.
rlc_runner_door_registered() { # PROVIDER -> 0 when registered
  local provider="$1"
  [ -f "$RLC_DOORS_JSON" ] || return 1
  jq -e --arg p "$provider" 'has($p)' "$RLC_DOORS_JSON" >/dev/null 2>&1
}

rlc_door_path() { # PROVIDER -> prints door script path
  local provider="$1" override door
  override="AI_REVIEW_DOOR_$(printf '%s' "$provider" | tr '[:lower:]' '[:upper:]')"
  if [ -n "${!override:-}" ]; then
    door="${!override}"
    [ -f "$door" ] || rlc_die "door override is not a file: $door"
    printf '%s' "$door"
    return 0
  fi
  if [ -f "$RLC_DOORS_JSON" ]; then
    door="$(jq -r --arg p "$provider" '.[$p].door // empty' "$RLC_DOORS_JSON" 2>/dev/null || true)"
    if [ -n "$door" ] && [ "$door" != null ]; then
      case "$door" in
        /*|[A-Za-z]:*) ;;
        *) door="$RLC_ROOT/$door" ;;
      esac
      [ -f "$door" ] || rlc_die "registered door is missing: $door"
      printf '%s' "$door"
      return 0
    fi
  fi
  door="$RLC_ROOT/tools/lib/review-doors/$provider.sh"
  [ -f "$door" ] || rlc_die "no door registered for provider '$provider' (looked for $door)."
  printf '%s' "$door"
}

# ---------------------------------------------------------------------------
# Task gate. Same tg_preflight_gate the lifecycle uses. Runs before any
# provider process and before any state file.
# ---------------------------------------------------------------------------
rlc_task_gate() { # rlc_task_gate ACTION [extra gate args...]
  local action="$1"; shift
  if [ "${AI_REVIEW_GATE_MODE:-}" = plan-review ]; then
    return 0
  fi
  local -a gate_args=()
  [ -z "${AI_REVIEW_REVIEWER_APPROVAL:-}" ] || gate_args=(--reviewer-approval "$AI_REVIEW_REVIEWER_APPROVAL")
  ( cd "${RLC_REPO:?}" && tg_preflight_gate "$action" ${gate_args[@]+"${gate_args[@]}"} ) \
    || rlc_die 'task gate refused this work; no lock, no state, and no provider call were created.'
}

# ---------------------------------------------------------------------------
# Identity. Exact tree under review (head, base, digest) via ai-review-packet.
# ---------------------------------------------------------------------------
rlc_identity() { # rlc_identity REPO [BASE] [ASSERT_HEAD] -> identity JSON on stdout
  local repo="$1" base="${2:-}" assert_head="${3:-}" identity
  local -a args=("$repo")
  [ -z "$base" ] || args+=(--base "$base")
  [ -z "$assert_head" ] || args+=(--assert-head "$assert_head")
  identity="$("$RLC_PACKET" resolve "${args[@]}")" \
    || rlc_die 'source identity refused before review dispatch.'
  printf '%s\n' "$identity"
}

# ---------------------------------------------------------------------------
# Sandbox. Disposable remote-less snapshot so the model cannot dirty the live
# repo. Removal happens only after a successful durable store.
# ---------------------------------------------------------------------------
rlc_sandbox_ensure() { # rlc_sandbox_ensure REPO TAG [BASE] -> prints copy path
  local repo="$1" tag="$2" base="${3:-}" copy
  rlc_assert_tag_budget "$tag"
  copy="$(AI_REVIEW_SANDBOX_BASE="$base" "$RLC_SANDBOX" ensure-copy "$repo" "$tag")" \
    || rlc_die 'could not create the review snapshot.'
  printf '%s\n' "$copy"
}

rlc_sandbox_remove() { # rlc_sandbox_remove REPO TAG
  "$RLC_SANDBOX" remove-copy "$1" "$2" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Packet seal + durable store. Store-before-delete is mandatory: retain never
# deletes, and cleanup-after-store refuses to remove anything the store did
# not take.
# ---------------------------------------------------------------------------
rlc_packet_build() { # rlc_packet_build REVIEW_DIR TAG [IDENTITY_FILE] [BASE] -> prints packet dir
  local review_dir="$1" tag="$2" identity="${3:-}" base="${4:-}" pkt
  local -a args=("$review_dir" "$tag" --class small)
  [ -z "$identity" ] || args+=(--identity "$identity")
  [ -z "$base" ] || args+=(--base "$base")
  local err
  err="$(mktemp)"
  set +e
  pkt="$("$RLC_PACKET" build "${args[@]}" 2>"$err")"
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    cat "$err" >&2 || true
    rm -f "$err"
    rlc_die "evidence packet build failed (exit $rc)."
  fi
  rm -f "$err"
  if [ -n "$identity" ]; then
    "$RLC_PACKET" verify "$pkt" --identity "$identity" >/dev/null \
      || rlc_die 'source evidence verification failed.'
  fi
  printf '%s\n' "$pkt"
}

rlc_packet_sha() { # rlc_packet_sha PACKET_DIR -> 64-hex seal
  local sha
  sha="$(cat "$1/MANIFEST.sha256" 2>/dev/null || true)"
  printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || rlc_die 'packet has no valid MANIFEST.sha256 seal.'
  printf '%s\n' "$sha"
}

rlc_packet_store() { # rlc_packet_store PACKET_DIR -> prints durable path; nonzero if store failed
  local pkt="$1" dest
  dest="$("$RLC_PACKET" retain "$pkt" 2>/dev/null)" || return 1
  [ -n "$dest" ] && [ -d "$dest" ] || return 1
  printf '%s\n' "$dest"
}

# Cleanup AFTER store. If the store did not succeed, skip deletion and warn —
# the working copy is then the only evidence left.
rlc_cleanup_after_store() { # rlc_cleanup_after_store STORED_OK REPO TAG PACKET_DIR
  local stored_ok="$1" repo="$2" tag="$3" packet_dir="${4:-}"
  if [ "$stored_ok" != 1 ]; then
    rlc_note "durable store did not succeed; retaining sandbox $tag and packet for reconciliation."
    return 0
  fi
  if [ -n "$packet_dir" ] && [ -d "$packet_dir" ]; then
    # The durable copy is already sealed; drop only the working packet after
    # the sandbox goes, using the packet tool's own retain-then-delete path.
    rlc_sandbox_remove "$repo" "$tag"
    "$RLC_PACKET" remove "$repo" "$tag" >/dev/null 2>&1 || true
  else
    rlc_sandbox_remove "$repo" "$tag"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Lifecycle terminal. begin/finish/fail through ai-review-lifecycle, stamped
# as runner-owned. Report floor and packet identity ride the terminal call.
# ---------------------------------------------------------------------------
rlc_lifecycle_begin() { # rlc_lifecycle_begin PROVIDER REPO RUN_ID CALLER [BASE] [SESSION] [MODE]
  local provider="$1" repo="$2" run="$3" caller="$4" base="${5:-}" session="${6:-}" mode="${7:-standard}"
  local -a args=(--provider "$provider" --repo "$repo" --run-id "$run" --caller "$caller" --preflight "$mode")
  [ -z "$base" ] || args+=(--base "$base")
  [ -z "$session" ] || args+=(--session-id "$session")
  [ -z "${AI_REVIEW_REVIEWER_APPROVAL:-}" ] || args+=(--reviewer-approval "$AI_REVIEW_REVIEWER_APPROVAL")
  AI_REVIEW_RUNNER_CORE="$RLC_STAMP" "$RLC_LIFECYCLE" begin "${args[@]}" \
    || rlc_die 'provider preflight failed; no review was assigned.'
}

rlc_lifecycle_finish() { # rlc_lifecycle_finish STATE VERDICT REPORT ELAPSED [PACKET_DIR] [PACKET_SHA] [FAILURE]
  local state="$1" verdict="$2" report="$3" elapsed="$4" packet_dir="${5:-}" packet_sha="${6:-}" failure="${7:-}"
  local -a args=(--state "$state" --verdict "$verdict" --elapsed "$elapsed")
  [ -z "$report" ] || args+=(--report "$report")
  [ -z "$failure" ] || args+=(--failure "$failure")
  [ -z "$packet_dir" ] || args+=(--packet-dir "$packet_dir")
  [ -z "$packet_sha" ] || args+=(--packet-sha256 "$packet_sha")
  AI_REVIEW_RUNNER_CORE="$RLC_STAMP" "$RLC_LIFECYCLE" finish "${args[@]}"
}

rlc_lifecycle_fail() { # rlc_lifecycle_fail STATE ELAPSED FAILURE [REPORT] [PACKET_DIR] [PACKET_SHA]
  local state="$1" elapsed="$2" failure="$3" report="${4:-}" packet_dir="${5:-}" packet_sha="${6:-}"
  local -a args=(--state "$state" --elapsed "$elapsed" --failure "$failure")
  [ -z "$report" ] || args+=(--report "$report")
  [ -z "$packet_dir" ] || args+=(--packet-dir "$packet_dir")
  [ -z "$packet_sha" ] || args+=(--packet-sha256 "$packet_sha")
  AI_REVIEW_RUNNER_CORE="$RLC_STAMP" "$RLC_LIFECYCLE" fail "${args[@]}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Report shape. Last `## Verdict` heading wins (an earlier provisional verdict
# must never be read as the final answer). Head binding is checked on the
# body before the final heading.
# ---------------------------------------------------------------------------
rlc_parse_verdict() { # FILE -> prints APPROVE|REJECT|BLOCKED or nothing
  local file="$1" line verdict
  line="$(awk '/^## Verdict[[:space:]]*$/{n=NR} END{print n+0}' "$file")"
  [ "$line" -gt 0 ] || return 1
  verdict="$(awk -v n="$line" 'n>0 && NR==n+1{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}' "$file")"
  case "$verdict" in APPROVE|REJECT|BLOCKED) printf '%s\n' "$verdict"; return 0;; *) return 1;; esac
}

rlc_verdict_bound_to_head() { # FILE HEAD -> 0 when the body names HEAD
  local file="$1" head="$2" line
  line="$(awk '/^## Verdict[[:space:]]*$/{n=NR} END{print n+0}' "$file")"
  awk -v h="$head" -v n="$line" 'NR>=n{exit} index($0, h){found=1} END{exit found?0:1}' "$file"
}

# ---------------------------------------------------------------------------
# Door invocation. The door receives provider bits only; every governance
# surface above stays here.
# ---------------------------------------------------------------------------
rlc_call_door() { # rlc_call_door MODE DOOR WORKDIR PACKET_DIR PROMPT_FILE REPORT_OUT HEAD [MAX_TURNS] [ALLOW_WRITE]
  local mode="$1" door="$2" workdir="$3" packet_dir="$4" prompt_file="$5" report_out="$6" head="$7"
  local max_turns="${8:-}" allow_write="${9:-0}" rc=0
  rlc_require_runner_token || rlc_die 'door call without the runner token.'
  [ -f "$door" ] || rlc_die "door not found: $door"
  [ -f "$prompt_file" ] || rlc_die "prompt file not found: $prompt_file"
  : > "$report_out" || rlc_die "cannot write report destination: $report_out"
  set +e
  env AI_REVIEW_RUNNER_CORE="$RLC_STAMP" \
      AI_REVIEW_VIA_RUNNER=1 \
      DOOR_MODE="$mode" \
      DOOR_WORKDIR="$workdir" \
      DOOR_PACKET_DIR="$packet_dir" \
      DOOR_PROMPT_FILE="$prompt_file" \
      DOOR_REPORT_OUT="$report_out" \
      DOOR_HEAD="$head" \
      DOOR_MAX_TURNS="$max_turns" \
      DOOR_ALLOW_WRITE="$allow_write" \
      bash "$door" "$mode"
  rc=$?
  # Do not re-enable set -e before a possible non-zero return: `return N`
  # under set -e aborts the runner instead of reporting the door status.
  [ "$rc" -eq 0 ] || return "$rc"
  set -e
  return 0
}

# ---------------------------------------------------------------------------
# Brief. One shape for both contracts; the door may prepend its own packet
# preamble, but the decision and verdict grammar live here so every door
# returns our report shape.
# ---------------------------------------------------------------------------
rlc_write_brief() { # rlc_write_brief DEST MODE HEAD DIGEST WORKDIR PACKET_REL [DECISION] [TESTS_RESULT] [CHANGED_FILES]
  local dest="$1" mode="$2" head="$3" digest="$4" workdir="$5" packet_rel="$6"
  local decision="${7:-}" tests_result="${8:-}" changed_files="${9:-}"
  local verb
  case "$mode" in
    implement) verb='Implement the requested change';;
    *) verb='Judge the change';;
  esac
  cat > "$dest" <<BRIEF
You are performing a ${mode}. You MAY run shell commands, builds and tests$( [ "$mode" = implement ] && printf ', and edit files' || printf ', and edit files to test a hypothesis' ), but only inside your disposable copy at ${workdir}: your edits are discarded and are never part of the change under review unless this is implement mode. Never commit, push, merge, or touch any remote or any checkout outside your copy. No web search.

Your session harness announces an evidence packet at ${workdir}/${packet_rel}/MANIFEST.md. THAT PACKET is the review subject. The reviewed head commit is ${head} and the source digest is ${digest}; you MUST quote the full reviewed head SHA in your report.$( [ -n "$changed_files" ] && printf '\n\nThe change under review is exactly these files (read the packet manifest and its patch first):\n%s' "$changed_files" )$( [ -n "$tests_result" ] && printf '\n\ntests command on record: %s' "$tests_result" )

${decision:-${verb} for correctness, regressions, data exposure, and missing tests.}

Return ALL findings in one pass, grouped by severity, with file and line evidence. End with a literal heading and one allowed word exactly:

## Verdict
APPROVE|REJECT|BLOCKED
BRIEF
}

# ---------------------------------------------------------------------------
# Report assembly. Runner chrome is recorded; the model body stays separable
# so the floor judges analysis, not metadata.
# ---------------------------------------------------------------------------
rlc_write_report() { # rlc_write_report OUT PROVIDER MODE REPO HEAD DIGEST RUN CALLER ELAPSED BODY_FILE [EXTRA_FIELD_LINES]
  local out="$1" provider="$2" mode="$3" repo="$4" head="$5" digest="$6"
  local run="$7" caller="$8" elapsed="$9" body="${10}" extra="${11:-}"
  local tmp
  tmp="$(mktemp "$(dirname "$out")/.rlc-report.XXXXXX")"
  {
    printf '# %s %s — %s\n\n| field | value |\n|---|---|\n' "$provider" "$mode" "$run"
    printf '| provider | `%s` |\n| repository | `%s` |\n| reviewed commit | `%s` |\n| source digest | `%s` |\n' "$provider" "$repo" "$head" "$digest"
    printf '| run | `%s` |\n| caller | `%s` |\n| elapsed seconds | `%s` |\n| runner | `%s` (%s) |\n' "$run" "$caller" "$elapsed" "$RLC_RUNNER_NAME" "$RLC_STAMP"
    [ -z "$extra" ] || printf '%s\n' "$extra"
    printf '\n## Result\n\n'
    cat "$body"
  } > "$tmp" || { rm -f "$tmp"; rlc_die 'report assembly was empty.'; }
  [ -s "$tmp" ] || { rm -f "$tmp"; rlc_die 'report assembly was empty.'; }
  mv -f "$tmp" "$out"
}

# ---------------------------------------------------------------------------
# Review contract. Suggestion report + packet. Read/search (or the door's
# read-only policy); snapshot; failure is report quality or stale source.
# ---------------------------------------------------------------------------
rlc_run_review() {
  # rlc_run_review PROVIDER NAME REPO [BASE] [ASSERT_HEAD] [MODE] [PROMPT_FILE] [CALLER] [TESTS] [MAX_TURNS]
  local provider="$1" name="$2" repo="$3" base="${4:-}" assert_head="${5:-}"
  local mode="${6:-diff-review}" prompt_file="${7:-}" caller="${8:-ai-review-engine}" tests_cmd="${9:-}" max_turns="${10:-}"
  local started identity state review_dir packet_dir packet_sha tag run_id
  local body report verdict elapsed digest head stored_ok=0 stored="" body_file brief identity_file
  local snapshot_before snapshot_after after_identity extra_fields

  rlc_init
  rlc_export_runner_token
  RLC_REPO="$(cd "$repo" && pwd -P)" || rlc_die "repository not found: $repo"
  repo="$RLC_REPO"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || rlc_die "not a Git repository: $repo"

  started="$(date +%s)"
  run_id="$(date -u +%Y%m%dT%H%M%S)-$$-$RANDOM"
  tag="$(rlc_short_name "rlc-$provider-$(printf '%s' "$run_id" | git hash-object --stdin | cut -c1-12)" "$RLC_DIR_MAX")"
  rlc_assert_tag_budget "$tag"
  rlc_note "step task-gate"

  rlc_task_gate review
  rlc_note "step identity"

  rlc_capture identity rlc_identity "$repo" "$base" "$assert_head"
  head="$(jq -r .head <<<"$identity")"
  digest="$(jq -r .source_digest <<<"$identity")"
  [ -n "$head" ] && [ "$head" != null ] || rlc_die 'lifecycle state carries no reviewed head.'
  [[ "$head" =~ ^[0-9a-f]{40}$ ]] || rlc_die "reviewed head is not a full commit SHA: $head"
  rlc_note "step lifecycle-begin"

  rlc_capture state rlc_lifecycle_begin "$provider" "$repo" "$run_id" "$caller" "$base" "" standard
  rlc_note "step sandbox"

  rlc_capture review_dir rlc_sandbox_ensure "$repo" "$tag" "$base"
  identity_file="$(mktemp)"
  # Packet resolve on Windows emits CRLF JSON; strip CR so validate_identity
  # sees clean keys and values.
  printf '%s\n' "$(printf '%s' "$identity" | tr -d '\r')" > "$identity_file"
  rlc_note "step packet-build"
  rlc_capture packet_dir rlc_packet_build "$review_dir" "$tag" "$identity_file" "$base"
  rlc_capture packet_sha rlc_packet_sha "$packet_dir"
  rlc_note "step brief"

  # Propagate a credential-free upstream into the snapshot (same contract as
  # ai-review-pool): session locks key on origin, and userinfo must never
  # reach the model-readable copy.
  local upstream_raw scheme rest authority path upstream_url
  upstream_raw="$(git -C "$repo" config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$upstream_raw" ]; then
    case "$upstream_raw" in
      *://*)
        scheme="${upstream_raw%%://*}"; rest="${upstream_raw#*://}"
        authority="${rest%%/*}"; path="${rest#"$authority"}"
        authority="${authority##*@}"; authority="${authority,,}"
        upstream_url="$(printf '%s://%s%s' "${scheme,,}" "$authority" "$path")" ;;
      *:*)
        case "$upstream_raw" in
          *@*) upstream_url="git@${upstream_raw##*@}" ;;
          *)   upstream_url="$upstream_raw" ;;
        esac ;;
      *) upstream_url="$upstream_raw" ;;
    esac
    git -C "$review_dir" remote remove origin >/dev/null 2>&1 || true
    git -C "$review_dir" remote add origin -- "$upstream_url" 2>/dev/null || true
  fi

  local packet_rel tests_result="" changed_files="" decision=""
  packet_rel="$(basename "$packet_dir")"
  case "$mode" in
    plan-review) decision='Judge the implementation plan for missing cases, unsafe assumptions, forgotten files, and test gaps.';;
    diff-review) decision='Judge the complete change for correctness, regressions, data exposure, and missing tests.';;
    security-review) decision='Judge only security risks: authorization, data leakage, injection, secrets, file boundaries, and permissions.';;
    final-check) decision='Give the final go/no-go judgment for shipping this exact source state.';;
  esac

  if [ -n "$base" ]; then
    local resolved_base
    resolved_base="$(jq -r '.base // empty' <<<"$identity" 2>/dev/null || true)"
    [ -n "$resolved_base" ] || resolved_base="$(git -C "$repo" rev-parse --verify --quiet --end-of-options "$base^{commit}" 2>/dev/null || true)"
    if [ -n "$resolved_base" ]; then
      changed_files="$(git diff --name-only "$resolved_base" "$head" -- 2>/dev/null || true)"
    fi
  fi

  if [ -n "$tests_cmd" ]; then
    if ( cd "$review_dir" && bash -c "$tests_cmd" ) >/dev/null 2>&1; then
      tests_result="$tests_cmd (exit 0 — passed in the review snapshot before dispatch)"
    else
      rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" tests-command-failed
      rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
      rlc_die 'tests command failed; no review was dispatched.'
    fi
  fi

  brief="$(mktemp)"
  body_file="$(mktemp)"
  rlc_write_brief "$brief" "$mode" "$head" "$digest" "$review_dir" "$packet_rel" "$decision" "$tests_result" "$changed_files"
  if [ -n "$prompt_file" ] && [ -f "$prompt_file" ]; then
    cat "$prompt_file" >> "$brief"
  fi

  local door
  rlc_capture door rlc_door_path "$provider"
  snapshot_before="$("$RLC_SANDBOX" digest "$review_dir" 2>/dev/null || true)"
  rlc_note "step door-call"
  if ! rlc_call_door review "$door" "$review_dir" "$packet_dir" "$brief" "$body_file" "$head" "$max_turns" 0; then
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" provider-failed "$body_file" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die "door $provider exited nonzero; diagnostic retained in the lifecycle record."
  fi
  snapshot_after="$("$RLC_SANDBOX" digest "$review_dir" 2>/dev/null || true)"
  rlc_note "step validate-report"
  if [ -z "$snapshot_after" ] || [ "$snapshot_after" != "$snapshot_before" ]; then
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" snapshot-drifted "$body_file" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die 'the review snapshot changed during the review; verdict refused.'
  fi

  [ -s "$body_file" ] || {
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" invalid-provider-envelope "" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die "$provider returned an empty report."
  }

  verdict="$(rlc_parse_verdict "$body_file")" || {
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" missing-verdict "$body_file" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die "$provider returned no valid ## Verdict."
  }
  if ! rlc_verdict_bound_to_head "$body_file" "$head"; then
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" verdict-not-bound-to-head "$body_file" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die 'provider verdict did not name the reviewed head; refusing unbound verdict.'
  fi
  if ! rlc_report_floor_ok "$body_file"; then
    rlc_lifecycle_fail "$state" "$(( $(date +%s)-started ))" report-floor "$body_file" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die "provider analysis body is below the minimum analysis floor (${MIN_REPORT_CHARS} substantive chars)."
  fi

  elapsed="$(( $(date +%s)-started ))"
  report="$repo/.ai/reviews/${provider}-${mode}-${run_id}.md"
  mkdir -p "$(dirname "$report")"
  extra_fields="| tools | door ${provider} |
| packet | \`${packet_sha}\` |"
  rlc_write_report "$report" "$provider" "$mode" "$repo" "$head" "$digest" "$run_id" "$caller" "$elapsed" "$body_file" "$extra_fields"

  after_identity=""
  if ! after_identity="$(rlc_identity "$repo" "$base" "$assert_head" 2>/dev/null)"; then
    after_identity=""
  fi
  if [ -z "$after_identity" ] || [ "$after_identity" != "$identity" ]; then
    mv "$report" "$report.stale" 2>/dev/null || true
    rlc_lifecycle_fail "$state" "$elapsed" source-identity-changed "$report.stale" "$packet_dir" "$packet_sha"
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die 'source identity changed during review; paid report retained as stale.'
  fi

  # Store BEFORE delete. Retain never deletes; if it fails we keep everything.
  rlc_note "step packet-store"
  if stored="$(rlc_packet_store "$packet_dir")"; then
    stored_ok=1
    rlc_note "durable packet store: $stored"
  else
    rlc_note 'durable packet store failed; retaining working packet and sandbox.'
  fi

  rlc_note "step lifecycle-finish"
  if ! rlc_lifecycle_finish "$state" "$verdict" "$report" "$elapsed" "${stored:-$packet_dir}" "$packet_sha"; then
    rlc_cleanup_after_store 0 "$repo" "$tag" "$packet_dir"
    rm -f "$brief" "$body_file" "$identity_file"
    rlc_die 'lifecycle accounting failed.'
  fi

  rlc_cleanup_after_store "$stored_ok" "$repo" "$tag" "$packet_dir"
  rm -f "$brief" "$body_file" "$identity_file"
  printf '%s\n' "$report"
}

# ---------------------------------------------------------------------------
# Implement contract. Worktree + recovery — not a thin review adapter. The
# runner owns the remote-less worktree and preserves it for recovery on
# failure; the door only supplies the provider write call and result parse.
# ---------------------------------------------------------------------------
rlc_run_implement() {
  # rlc_run_implement PROVIDER NAME REPO [PROMPT_FILE] [REF] [CALLER] [MAX_TURNS] [KEEP]
  local provider="$1" name="$2" repo="$3" prompt_file="${4:-}" ref="${5:-}"
  local caller="${6:-ai-review-engine}" max_turns="${7:-}" keep="${8:-0}"
  local started identity state worktree packet_dir packet_sha tag run_id
  local body_file brief head digest stored_ok=0 stored="" work_root door rc=0

  rlc_init
  rlc_export_runner_token
  RLC_REPO="$(cd "$repo" && pwd -P)" || rlc_die "repository not found: $repo"
  repo="$RLC_REPO"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || rlc_die "not a Git repository: $repo"

  started="$(date +%s)"
  run_id="$(date -u +%Y%m%dT%H%M%S)-$$-$RANDOM"
  tag="$(rlc_short_name "rlc-impl-$provider-$(printf '%s' "$run_id" | git hash-object --stdin | cut -c1-12)" "$RLC_DIR_MAX")"
  rlc_assert_tag_budget "$tag"

  rlc_task_gate review

  rlc_capture identity rlc_identity "$repo" "${ref:-}" ""
  head="$(jq -r .head <<<"$identity")"
  digest="$(jq -r .source_digest <<<"$identity")"
  [[ "$head" =~ ^[0-9a-f]{40}$ ]] || rlc_die "reviewed head is not a full commit SHA: $head"

  rlc_capture state rlc_lifecycle_begin "$provider" "$repo" "$run_id" "$caller" "${ref:-}" "" standard

  # Implement isolation is the same disposable remote-less copy the review
  # contract uses (ai-review-sandbox ensure-copy), not a linked git worktree:
  # packet build refuses linked worktrees, and a plain clone fails identity
  # binding (source-repository-mismatch). Writes persist in the copy for
  # recovery; the caller's checkout is never modified. On failure the copy is
  # ALWAYS retained; on success it is removed only after a durable store.
  work_root=""
  rlc_assert_tag_budget "$tag"
  worktree="$(AI_REVIEW_SANDBOX_BASE="${ref:-}" "$RLC_SANDBOX" ensure-copy "$repo" "$tag")" \
    || rlc_die 'could not create the implement worktree.'
  git -C "$worktree" remote remove origin >/dev/null 2>&1 || true

  local identity_file
  identity_file="$(mktemp)"
  printf '%s\n' "$(printf '%s' "$identity" | tr -d '\r')" > "$identity_file"
  rlc_capture packet_dir rlc_packet_build "$worktree" "$tag" "$identity_file" "${ref:-}"
  rlc_capture packet_sha rlc_packet_sha "$packet_dir"

  brief="$(mktemp)"
  body_file="$(mktemp)"
  rlc_write_brief "$brief" implement "$head" "$digest" "$worktree" "$(basename "$packet_dir")" \
    'Implement the requested change in this worktree. Report what you changed and any residual risk.' "" ""
  if [ -n "$prompt_file" ] && [ -f "$prompt_file" ]; then
    cat "$prompt_file" >> "$brief"
  fi

  rlc_capture door rlc_door_path "$provider"
  set +e
  rlc_call_door implement "$door" "$worktree" "$packet_dir" "$brief" "$body_file" "$head" "$max_turns" 1
  rc=$?
  set -e

  elapsed="$(( $(date +%s)-started ))"
  if [ "$rc" -ne 0 ]; then
    # Recovery contract: never destroy the worktree on failure.
    rlc_note "implement run failed; worktree preserved for recovery: $worktree"
    if stored="$(rlc_packet_store "$packet_dir" 2>/dev/null)"; then
      stored_ok=1
    fi
    rlc_lifecycle_fail "$state" "$elapsed" provider-failed "$body_file" "$packet_dir" "$packet_sha"
    # Do NOT remove the worktree. The sandbox-equivalent is the worktree.
    rm -f "$brief" "$body_file"
    printf '%s\n' "$worktree"
    return 1
  fi

  # Success: store first, then optionally keep the worktree for the caller.
  if stored="$(rlc_packet_store "$packet_dir")"; then
    stored_ok=1
    rlc_note "durable packet store: $stored"
  fi
  local report
  report="$repo/.ai/reviews/${provider}-implement-${run_id}.md"
  mkdir -p "$(dirname "$report")"
  rlc_write_report "$report" "$provider" implement "$repo" "$head" "$digest" "$run_id" "$caller" "$elapsed" "$body_file" \
    "| worktree | \`${worktree}\` |
| packet | \`${packet_sha}\` |"
  rlc_lifecycle_finish "$state" "APPROVE" "$report" "$elapsed" "${stored:-$packet_dir}" "$packet_sha"

  if [ "$keep" = 1 ] || [ "${AI_KEEP_IMPLEMENT_WORKTREE:-0}" = 1 ]; then
    rlc_note "implement worktree kept: $worktree"
  else
    # Store already succeeded; the worktree is no longer the only evidence.
    if [ "$stored_ok" = 1 ]; then
      rlc_sandbox_remove "$repo" "$tag"
    else
      rlc_note "durable store failed; retaining implement worktree: $worktree"
    fi
  fi
  rm -f "$brief" "$body_file"
  printf '%s\n' "$worktree"
}
