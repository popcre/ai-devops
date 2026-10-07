#!/usr/bin/env bash
# qwen.sh — Qwen door for the shared review runner.
#
# Provider bits ONLY: binary selection, credentials presence, model pin,
# provider tool set, and parse to our report shape. This file must NOT own
# task gate, identity, sandbox, packet seal/store, lifecycle terminal, report
# floor, or cleanup. tests/test-ai-review-engine.sh asserts that source purity.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash qwen.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'qwen door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'qwen door: usage: qwen.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?qwen door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?qwen door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?qwen door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?qwen door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?qwen door: DOOR_HEAD is required}"

# Model pin and tool set. Reviews may run code and edit only inside the
# disposable remote-less copy the runner built (issue #974); the container
# sandbox is preferred, and a host without Docker/podman falls back to the
# reviewer-only tool set (same containment choice bin/ai-qwen makes).
QWEN_MODEL="${AI_QWEN_MODEL:-qwen3.8-max}"
QWEN_MAX_TURNS="${DOOR_MAX_TURNS:-${AI_QWEN_MAX_TURNS:-120}}"
QWEN_TIMEOUT="${DOOR_TIMEOUT:-${AI_QWEN_TIMEOUT:-3600}}"

# On Windows the managed Qwen install wants Windows paths for --cwd-style
# children; the same conversion the other doors use.
QWEN_IS_WINDOWS=0
case "$(uname -s 2>/dev/null || echo unknown)" in MINGW*|MSYS*|CYGWIN*) QWEN_IS_WINDOWS=1 ;; esac
native_path() {
  if [ "$QWEN_IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

resolve_qwen() {
  if [ -n "${AI_QWEN_BIN:-}" ] && [ -x "${AI_QWEN_BIN}" ]; then
    printf '%s' "$AI_QWEN_BIN"; return 0
  fi
  local c
  for c in "$(command -v qwen 2>/dev/null || true)" \
           "${LOCALAPPDATA:-}/qwen-code/bin/qwen.exe" \
           "${LOCALAPPDATA:-}/qwen-code/bin/qwen.cmd" \
           "${HOME:-}/.local/bin/qwen" \
           "${HOME:-}/.local/lib/qwen-code/bin/qwen"; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  printf 'qwen door: local_dependency_unavailable: qwen binary not found. This is not a Qwen provider fault. Set AI_QWEN_BIN.\n' >&2
  return 127
}

# Credentials presence only — never print a key. A missing store is a local
# dependency failure, not a provider fault. The key enters the child
# environment only; it never appears in argv or output.
QWEN_KEY=""
require_credentials() {
  if [ -n "${AI_QWEN_KEY:-}" ]; then
    QWEN_KEY="$AI_QWEN_KEY"
    return 0
  fi
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    QWEN_KEY="$OPENAI_API_KEY"
    return 0
  fi
  local cfg="${AI_DEVOPS_CONFIG_DIR:-${HOME:-}/.config/ai-devops}"
  local store="${AI_QWEN_KEY_STORE:-$cfg/secrets/qwen-token-plan-key}"
  if [ -s "$store" ]; then
    IFS= read -r QWEN_KEY < "$store" || QWEN_KEY=""
    [ -n "$QWEN_KEY" ] && return 0
  fi
  if [ "${AI_QWEN_ALLOW_NO_CREDS:-0}" = 1 ]; then
    return 0
  fi
  printf 'qwen door: no Qwen key in the protected store. Run ai-qwen store-key, or set AI_QWEN_ALLOW_NO_CREDS=1 for offline tests.\n' >&2
  return 127
}

# Container sandbox when a runtime is present; otherwise the reviewer-only
# tool set (plan mode, shell/write/edit removed). Both stay inside the
# disposable copy the runner owns — the caller's checkout is never written.
review_containment() {
  if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
    printf 'sandbox'
  else
    printf 'reviewer-only'
  fi
}

# Parse the stream-json NDJSON envelope into OUR report shape: findings first,
# verdict last under a literal '## Verdict' heading. Completion is ONLY a
# terminal type:"result" row (bin/ai-qwen stream-json contract).
extract_report() { # extract_report LOG DEST HEAD MODE
  local log="$1" dest="$2" head="$3" mode="$4" text stop turns
  stop="$(jq -r 'select(.type=="result") | if .is_error then "error" else "stop" end' "$log" 2>/dev/null | tail -1 || echo unknown)"
  text="$(jq -r 'select(.type=="result") | .result // ""' "$log" 2>/dev/null | tail -1 || true)"
  turns="$(jq -r 'select(.type=="result") | .num_turns // "?"' "$log" 2>/dev/null | tail -1 || echo '?')"
  case "$stop" in
    stop) ;;
    *)
      printf 'qwen door: non-terminal or errored result: %s\n' "$stop" >&2
      return 1
      ;;
  esac
  [ -n "$text" ] || {
    printf 'qwen door: provider returned no result text.\n' >&2
    return 1
  }
  {
    printf '# Qwen %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    printf '| model | `%s` |\n| harness | `qwen-code` |\n' "$QWEN_MODEL"
    printf '| turns | `%s` |\n| reviewed commit | `%s` |\n\n' "$turns" "$head"
    printf -- '---\n\n'
    if grep -qF '## Verdict' <<< "$text"; then
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
  local qwen containment out prompt_full rc
  qwen="$(resolve_qwen)" || exit $?
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'qwen door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'qwen door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

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

  containment="$(review_containment)"
  local -a args=(--model "$QWEN_MODEL" --auth-type openai --output-format stream-json --safe-mode
    --max-session-turns "$QWEN_MAX_TURNS" --max-subagent-depth 1)
  if [ "$MODE" = implement ]; then
    args+=(--sandbox --approval-mode yolo)
  elif [ "$containment" = sandbox ]; then
    args+=(--sandbox --approval-mode yolo)
  else
    args+=(--approval-mode plan --exclude-tools shell,write,edit)
  fi

  out="$(mktemp)"
  set +e
  (
    cd "$DOOR_WORKDIR" || exit 1
    if [ -n "$QWEN_KEY" ]; then export OPENAI_API_KEY="$QWEN_KEY"; else unset OPENAI_API_KEY || true; fi
    timeout "$QWEN_TIMEOUT" "$qwen" "${args[@]}" < "$prompt_full" > "$out" 2> "$out.err"
  )
  rc=$?
  set -e
  QWEN_KEY=""

  if [ "$rc" -eq 92 ]; then
    printf 'AI_REVIEWER_OUT_OF_CREDIT qwen door\n' >&2
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || [ ! -s "$out" ]; then
    printf 'qwen door: provider call failed (exit %s)\n' "$rc" >&2
    [ -s "$out.err" ] && sed -E 's/((API[_-]?KEY|TOKEN|SECRET|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig; s/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig' "$out.err" | tail -20 >&2 || true
    rm -f "$prompt_full"
    exit 1
  fi

  if ! extract_report "$out" "$DOOR_REPORT_OUT" "$DOOR_HEAD" "$MODE"; then
    rm -f "$prompt_full"
    exit 1
  fi
  rm -f "$prompt_full"
  exit 0
}

main "$@"
