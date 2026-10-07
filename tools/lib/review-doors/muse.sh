#!/usr/bin/env bash
# muse.sh — Muse door for the shared review runner.
#
# Provider bits ONLY: engine/binary selection (muse-code pinned CLI, or the
# OpenCode rollback), credentials presence, model pin, provider tool set, and
# parse to our report shape. This file must NOT own task gate, identity,
# sandbox, packet seal/store, lifecycle terminal, report floor, or cleanup.
# tests/test-ai-review-engine.sh asserts that source purity.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash muse.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'muse door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'muse door: usage: muse.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?muse door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?muse door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?muse door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?muse door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?muse door: DOOR_HEAD is required}"

# Repository root, for the pinned engine install and the OpenCode profile.
MU_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$MU_ROOT/tools/reviewer_event_guard.sh"

# Runtime engine: Meta's Muse Code CLI (default) or the pinned OpenCode
# harness (rollback). Sessions never cross engines: each engine records its
# own model identifier (bin/ai-muse engine case).
MU_ENGINE="${AI_MUSE_ENGINE:-muse-code}"
case "$MU_ENGINE" in
  opencode)
    MU_PROFILE_SRC="$MU_ROOT/config/opencode-muse"
    MU_OC_VERSION="$(tr -d ' \r\n' < "$MU_ROOT/config/opencode/version" 2>/dev/null || true)"
    MU_MODEL="meta-model-api/muse-spark-1.3-contributor"
    MU_AGENT="muse-review"
    ;;
  muse-code)
    MU_MODEL="muse-spark-1.3-contributor"
    ;;
  *)
    printf 'muse door: unknown AI_MUSE_ENGINE: %s (use muse-code or opencode)\n' "$MU_ENGINE" >&2
    exit 2
    ;;
esac
MU_TIMEOUT="${DOOR_TIMEOUT:-${AI_MUSE_TIMEOUT:-1800}}"

# On Windows the managed installs and native workspace flags want Windows
# paths (same conversion the other OpenCode doors use).
MU_IS_WINDOWS=0
case "$(uname -s 2>/dev/null || echo unknown)" in MINGW*|MSYS*|CYGWIN*) MU_IS_WINDOWS=1 ;; esac
native_path() {
  if [ "$MU_IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

resolve_muse_code() {
  local pin version bin
  if [ -n "${AI_MUSE_BIN:-}" ] && [ -x "${AI_MUSE_BIN}" ]; then
    printf '%s' "$AI_MUSE_BIN"; return 0
  fi
  if [ "$MU_IS_WINDOWS" = 1 ]; then
    pin="$MU_ROOT/config/muse-code"
  else
    pin="$MU_ROOT/config/muse-code/linux-$(uname -m)"
  fi
  version="$(tr -d ' \r\n' < "$pin/version" 2>/dev/null || true)"
  [ -n "$version" ] || {
    printf 'muse door: local_dependency_unavailable: no Muse Code pin for this platform (%s). This is not a Muse provider fault.\n' "$pin" >&2
    return 127
  }
  if [ "$MU_IS_WINDOWS" = 1 ]; then
    bin="${USERPROFILE:-}/AppData/Local/Programs/muse/muse-bin-$version.exe"
  else
    bin="${HOME:-}/.local/bin/muse-bin-$version"
  fi
  [ -x "$bin" ] && { printf '%s' "$bin"; return 0; }
  printf 'muse door: local_dependency_unavailable: Muse Code binary not found: %s. This is not a Muse provider fault.\n' "$bin" >&2
  return 127
}

resolve_opencode() {
  if [ -n "${AI_MUSE_OPENCODE:-}" ] && [ -x "${AI_MUSE_OPENCODE}" ]; then
    printf '%s' "$AI_MUSE_OPENCODE"; return 0
  fi
  local home_dir="$HOME" pinned c
  if [ "$MU_IS_WINDOWS" = 1 ] && [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home_dir="$(cygpath -u "$USERPROFILE")"
  fi
  if [ -n "$MU_OC_VERSION" ]; then
    pinned="$home_dir/.local/lib/ai-devops/opencode/$MU_OC_VERSION/node_modules/opencode-ai/bin/opencode.exe"
    [ -x "$pinned" ] && { printf '%s' "$pinned"; return 0; }
  fi
  c="$(command -v opencode 2>/dev/null || true)"
  [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  printf 'muse door: local_dependency_unavailable: OpenCode binary not found. This is not a Muse provider fault.\n' >&2
  return 127
}

# Credentials presence only — never print a key. A missing store is a local
# dependency failure, not a provider fault. The key enters the child
# environment only; it never appears in argv or output.
MU_KEY=""
require_credentials() {
  if [ -n "${AI_MUSE_KEY:-}" ]; then
    MU_KEY="$AI_MUSE_KEY"
    return 0
  fi
  if [ -n "${META_API_KEY:-}" ]; then
    MU_KEY="$META_API_KEY"
    return 0
  fi
  local store="${AI_MUSE_KEY_STORE:-${HOME:-}/.config/ai-devops/secrets/muse-api-key}"
  if [ -s "$store" ]; then
    IFS= read -r MU_KEY < "$store" || MU_KEY=""
    [ -n "$MU_KEY" ] && return 0
  fi
  if [ "${AI_MUSE_ALLOW_NO_CREDS:-0}" = 1 ]; then
    return 0
  fi
  printf 'muse door: no Muse key in the protected store. Run ai-muse store-key, or set AI_MUSE_ALLOW_NO_CREDS=1 for offline tests.\n' >&2
  return 127
}

# Fresh per-run XDG tree for the OpenCode engine (#1086 pattern): the
# repository profile is copied in before the turn and the whole tree is
# discarded after, so nothing a model writes survives into the next run.
install_opencode_profile() { # install_opencode_profile XDG_ROOT
  local root="$1" xdg="$1/config/opencode"
  [ -f "$MU_PROFILE_SRC/opencode.json" ] || {
    printf 'muse door: local_dependency_unavailable: profile missing: %s/opencode.json\n' "$MU_PROFILE_SRC" >&2
    return 127
  }
  mkdir -p "$xdg/agent" "$root/data" "$root/state" "$root/cache"
  cp "$MU_PROFILE_SRC/opencode.json" "$xdg/opencode.json"
  if [ -f "$MU_PROFILE_SRC/agent/$MU_AGENT.md" ]; then
    cp "$MU_PROFILE_SRC/agent/$MU_AGENT.md" "$xdg/agent/$MU_AGENT.md"
  fi
}

# Parse the provider envelope into OUR report shape: findings first, verdict
# last under a literal '## Verdict' heading. Same grammar the pool and
# lifecycle consume. Muse Code speaks a run.terminal JSONL; the OpenCode
# engine speaks the same text/tool_use JSONL as the other OpenCode doors.
extract_report() { # extract_report RESULT_FILE DEST HEAD MODE ENGINE
  local result="$1" dest="$2" head="$3" mode="$4" engine="$5" text stop
  if [ "$engine" = muse-code ]; then
    stop="$(jq -sr '[.[]|select((.payload_type//"")|startswith("run.terminal."))]|last|if .==null then "" elif .payload_type=="run.terminal.completed" and .payload.terminal=="completed" then "stop" else (.payload.terminal//.payload_type) end' "$result" 2>/dev/null || echo unknown)"
    text="$(jq -sr '[.[]|select((.payload_type//"")|startswith("run.terminal."))]|last|.payload.text//empty' "$result" 2>/dev/null || true)"
  else
    stop="stop"
    text="$(jq -r 'select(.type=="text") | .part.text // ""' "$result" 2>/dev/null | sed '/^$/d' || true)"
  fi
  case "$stop" in
    stop|completed|end_turn|EndTurn) ;;
    *)
      printf 'muse door: non-terminal stop: %s\n' "$stop" >&2
      return 1
      ;;
  esac
  [ -n "$text" ] || {
    printf 'muse door: provider returned no assistant text.\n' >&2
    return 1
  }
  {
    printf '# Muse %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    printf '| model | `%s` |\n| engine | `%s` |\n' "$MU_MODEL" "$engine"
    printf '| reviewed commit | `%s` |\n\n' "$head"
    printf -- '---\n\n'
    if printf '%s' "$text" | grep -qF '## Verdict'; then
      printf '### Findings and reasoning\n\n'
      printf '%s\n' "$text" | sed -n '1,/^## Verdict/p' | sed '/^## Verdict/d'
      printf '\n---\n\n'
      printf '%s\n' "$text" | sed -n '/^## Verdict/,$p'
    else
      printf '%s\n' "$text"
      printf '\n## Verdict\nBLOCKED\n'
    fi
  } > "$dest"
}

main() {
  local bin prompt_full out log rc sid workspace
  if [ "$MU_ENGINE" = muse-code ]; then
    bin="$(resolve_muse_code)" || exit $?
  else
    bin="$(resolve_opencode)" || exit $?
  fi
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'muse door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'muse door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

  # Packet preamble: the sealed evidence is the subject; the workdir is the
  # disposable copy. The runner owns seal/store; this only points the model.
  prompt_full="$(mktemp)"
  {
    printf 'Your evidence packet is at %s/MANIFEST.md. Read it first.\n' "$DOOR_PACKET_DIR"
    printf 'It contains the exact commits under review, the changed files, the full patch, and what you are being asked to decide.\n'
    printf 'The reviewed head commit is %s; quote that full SHA in your report.\n\n' "$DOOR_HEAD"
    cat "$DOOR_PROMPT_FILE"
    printf '\n\n---\nFormatting requirement: structure your reply so the final answer is last, under a literal '"'"'## Verdict'"'"' heading, followed by exactly one of APPROVE, REJECT, or BLOCKED.\n'
  } > "$prompt_full"
  chmod 600 "$prompt_full" 2>/dev/null || true

  out="$(mktemp)"
  log="$out"
  set +e
  if [ "$MU_ENGINE" = muse-code ]; then
    sid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())' 2>/dev/null || python -c 'import uuid;print(uuid.uuid4())' 2>/dev/null || printf '%08x-%04x-%04x-%04x-%012x' "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM$RANDOM")"
    workspace="$(native_path "$DOOR_WORKDIR")"
    # Review (#974): writes and a sandboxed shell inside the disposable,
    # remote-less copy the runner built; no approval prompts, no web, no
    # personal context. Same flags bin/ai-muse uses for a review turn.
    (
      if [ -n "$MU_KEY" ]; then export META_API_KEY="$MU_KEY"; else unset META_API_KEY || true; fi
      reviewer_credit_run muse "$log" "$out.err" -- timeout "$MU_TIMEOUT" "$bin" exec --json --model "$MU_MODEL" --session-id "$sid" \
        --workspace "$workspace" --disable-approval --disable-web-tools \
        --no-foreign-personal-context --user-input-auto-resolve \
        --prompt-file "$(native_path "$prompt_full")" \
        > "$log" 2> "$out.err"
    )
    rc=$?
  else
    xdg="$(mktemp -d)"
    if ! install_opencode_profile "$xdg"; then
      rm -rf "$xdg"; rm -f "$prompt_full"; exit 127
    fi
    (
      export XDG_CONFIG_HOME="$(native_path "$xdg/config")" \
             XDG_DATA_HOME="$(native_path "$xdg/data")" \
             XDG_STATE_HOME="$(native_path "$xdg/state")" \
             XDG_CACHE_HOME="$(native_path "$xdg/cache")"
      if [ -n "$MU_KEY" ]; then export META_API_KEY="$MU_KEY"; else unset META_API_KEY || true; fi
      printf '%s' "$(cat "$prompt_full")" \
        | reviewer_credit_run muse "$log" "$out.err" -- timeout "$MU_TIMEOUT" "$bin" run --agent "$MU_AGENT" --auto \
            --format json --model "$MU_MODEL" \
            --dir "$(native_path "$DOOR_WORKDIR")" \
            > "$log" 2> "$out.err"
    )
    rc=$?
    rm -rf "$xdg"
  fi
  set -e
  MU_KEY=""

  if [ "$rc" -eq 92 ]; then
    reviewer_capacity_current muse "$log" || true
    reviewer_credit_exit
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || [ ! -s "$log" ]; then
    printf 'muse door: provider call failed (exit %s)\n' "$rc" >&2
    [ -s "$out.err" ] && sed -E 's/((API[_-]?KEY|TOKEN|SECRET|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig; s/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig' "$out.err" | tail -20 >&2 || true
    rm -f "$prompt_full"
    exit 1
  fi

  if ! extract_report "$log" "$DOOR_REPORT_OUT" "$DOOR_HEAD" "$MODE" "$MU_ENGINE"; then
    rm -f "$prompt_full"
    exit 1
  fi
  rm -f "$prompt_full"
  exit 0
}

main "$@"
