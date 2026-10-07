#!/usr/bin/env bash
# gemini.sh — Gemini door for the shared review runner.
#
# Provider bits ONLY: local agy runtime selection, credentials presence,
# model pin, provider tool set, and parse to our report shape. This file must
# NOT own task gate, identity, sandbox, packet seal/store, lifecycle terminal,
# report floor, or cleanup. tests/test-ai-review-engine.sh asserts that source
# purity. Fingerprint requalification for Gemini stays in
# bin/ai-review-preflight (Phase B versioned records) — never here.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash gemini.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail
DOOR_CREDIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$DOOR_CREDIT_ROOT/tools/reviewer_event_guard.sh"

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'gemini door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'gemini door: usage: gemini.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?gemini door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?gemini door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?gemini door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?gemini door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?gemini door: DOOR_HEAD is required}"

# Model pin and tool set. --sandbox keeps every write inside the disposable
# copy the runner built (issue #974); accept-edits is the review tool set.
# --permission-mode / --always-approve style flags are deliberately not used.
GE_MODEL="${AI_GEMINI_MODEL:-gemini-3.8-flash-high}"
GE_TIMEOUT="${DOOR_TIMEOUT:-${AI_GEMINI_TIMEOUT:-3600}}"
# GNU timeout accepts bare seconds; agy requires an explicit Go duration unit.
# Keep one bounded budget for both, preserving their shared s/m/h syntax.
# Reject zero, negative, malformed and overflowing budgets before any call.
if [[ "$GE_TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then GE_TIMEOUT="${GE_TIMEOUT}s"; fi
if ! [[ "$GE_TIMEOUT" =~ ^[0-9]+([.][0-9]+)?[smh]$ ]] \
  || ! LC_ALL=C awk -v value="$GE_TIMEOUT" 'BEGIN {
    unit=substr(value,length(value),1); number=substr(value,1,length(value)-1)+0;
    seconds=number*(unit=="h" ? 3600 : unit=="m" ? 60 : 1);
    exit !(seconds>0 && seconds<=2147483647)
  }'; then
  printf 'gemini door: invalid bounded timeout duration.\n' >&2
  exit 2
fi

# On Windows the managed agy runtime and its --dir children want Windows
# paths (same conversion the other doors use).
GE_IS_WINDOWS=0
case "$(uname -s 2>/dev/null || echo unknown)" in MINGW*|MSYS*|CYGWIN*) GE_IS_WINDOWS=1 ;; esac
native_path() {
  if [ "$GE_IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

resolve_agy() {
  if [ -n "${AI_GEMINI_BIN:-}" ] && [ -x "${AI_GEMINI_BIN}" ]; then
    printf '%s' "$AI_GEMINI_BIN"; return 0
  fi
  local a
  for a in "$(command -v agy 2>/dev/null || true)" \
           "${HOME:-}/.local/bin/agy" \
           "${LOCALAPPDATA:-}/agy/bin/agy.exe"; do
    [ -n "$a" ] && [ -x "$a" ] && { printf '%s' "$a"; return 0; }
  done
  printf 'gemini door: local_dependency_unavailable: the LOCAL agy runtime is not installed. This is not a Gemini provider fault. Run: ai-gemini doctor\n' >&2
  return 127
}

# Credentials: agy owns its own local auth. A missing runtime is a local
# dependency failure, not a provider fault. An explicit key, when present,
# enters the child environment only; it never appears in argv or output.
GE_KEY=""
require_credentials() {
  if [ -n "${AI_GEMINI_KEY:-}" ]; then
    GE_KEY="$AI_GEMINI_KEY"
    return 0
  fi
  if [ -n "${GEMINI_API_KEY:-}" ]; then
    GE_KEY="$GEMINI_API_KEY"
    return 0
  fi
  if [ -n "${GOOGLE_API_KEY:-}" ]; then
    GE_KEY="$GOOGLE_API_KEY"
    return 0
  fi
  # No explicit key: agy's own local auth session is the credential store.
  return 0
}

# Parse the agy JSON envelope into OUR report shape: findings first, verdict
# last under a literal '## Verdict' heading. Same grammar the pool and
# lifecycle consume. The reviewed head is recorded before the verdict so the
# runner's head-binding check sees it.
extract_report() { # extract_report RESULT_JSON DEST HEAD MODE
  local result="$1" dest="$2" head="$3" mode="$4" text model
  text="$(jq -r '.response // ""' "$result" 2>/dev/null || true)"
  model="$(jq -r '.model // "unknown"' "$result" 2>/dev/null || echo unknown)"
  [ -n "$text" ] || {
    printf 'gemini door: provider returned no response text.\n' >&2
    return 1
  }
  {
    printf '# Gemini %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    printf '| model | `%s` |\n| harness | `agy` |\n' "$model"
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
  local agy prompt_full prompt_text out rc
  agy="$(resolve_agy)" || exit $?
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'gemini door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'gemini door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

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
  prompt_text="$(cat "$prompt_full")"

  out="$(mktemp)"
  set +e
  (
    cd "$DOOR_WORKDIR" || exit 1
    if [ -n "$GE_KEY" ]; then export GEMINI_API_KEY="$GE_KEY"; fi
    if [ "$MODE" = implement ]; then
      reviewer_credit_run gemini "$out" "$out.err" -- timeout "$GE_TIMEOUT" "$agy" --sandbox --mode accept-edits --model "$GE_MODEL" \
        --output-format json --print-timeout "$GE_TIMEOUT" --print "$prompt_text" \
        > "$out" 2> "$out.err"
    else
      reviewer_credit_run gemini "$out" "$out.err" -- timeout "$GE_TIMEOUT" "$agy" --new-project --sandbox --mode accept-edits --model "$GE_MODEL" \
        --output-format json --print-timeout "$GE_TIMEOUT" --print "$prompt_text" \
        > "$out" 2> "$out.err"
    fi
  )
  rc=$?
  set -e
  GE_KEY=""

  if [ "$rc" -eq 92 ]; then
    reviewer_capacity_current gemini "$out" || true
    reviewer_credit_exit
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || ! jq -e 'has("response")' "$out" >/dev/null 2>&1; then
    printf 'gemini door: provider call failed (exit %s)\n' "$rc" >&2
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
