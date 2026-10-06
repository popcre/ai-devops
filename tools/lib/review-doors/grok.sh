#!/usr/bin/env bash
# grok.sh — Grok door for the shared review runner.
#
# Provider bits ONLY: binary selection, credentials presence, model pin,
# tool set, and parse to our report shape. This file must NOT own task gate,
# identity, sandbox, packet seal/store, lifecycle terminal, report floor, or
# cleanup. tests/test-ai-review-engine.sh asserts that source purity.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash grok.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'grok door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'grok door: usage: grok.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?grok door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?grok door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?grok door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?grok door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?grok door: DOOR_HEAD is required}"

# Model pin and tool set. Frozen on purpose: a stable request prefix is what
# makes prompt caching work, and a fixed permission set is what keeps the
# review boundary explicit. --permission-mode auto / --always-approve are
# deliberately NOT used (bin/ai-grok-review STEP 0 notes).
# The pin comes from config/provider-cli-versions.json (model_pin), the same
# source the installers write into ~/.grok/config.toml allowed_models. A
# hard-coded copy here drifted (grok-4.5 vs the grok-4.6 pin) and Grok refused
# every formal review: "isn't allowed by allowed_models".
grok_model_pin() {
  local here cfg pin=""
  here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")")" && pwd)"
  cfg="$here/../../../config/provider-cli-versions.json"
  if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
    pin="$(jq -r '.providers.grok.model_pin // empty' "$cfg" 2>/dev/null | tr -d '\r')"
  fi
  printf '%s' "${pin:-grok-4.6}"
}
GROK_MODEL="${AI_GROK_MODEL:-$(grok_model_pin)}"
GROK_MAX_TURNS="${DOOR_MAX_TURNS:-${AI_GROK_MAX_TURNS:-32}}"
GROK_WAIT="${AI_GROK_WAIT_TIMEOUT:-1800}"
# Review is not read-only (issue #974): the model may run commands and edit
# files only inside its disposable copy. Implement uses the same tool set
# against a real remote-less worktree the runner owns.
GROK_PERMS=(--permission-mode default --allow Read --allow Grep
            --allow Edit --allow Write --allow Bash --deny 'MCPTool(*)'
            --no-subagents --disable-web-search --no-memory)

resolve_grok() {
  if [ -n "${AI_GROK_BIN:-}" ] && [ -x "${AI_GROK_BIN}" ]; then
    printf '%s' "$AI_GROK_BIN"; return 0
  fi
  local c
  for c in "$(command -v grok 2>/dev/null || true)" \
           "${HOME:-}/.local/bin/grok" \
           "${HOME:-}/.grok/bin/grok" \
           /home/ai/.local/bin/grok \
           /usr/local/bin/grok; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  printf 'grok door: local_dependency_unavailable: grok binary not found. This is not a Grok provider fault. Set AI_GROK_BIN.\n' >&2
  return 127
}

# Credentials presence only — never print a key. A missing store is a local
# dependency failure, not a provider fault.
require_credentials() {
  if [ -s "${AI_GROK_AUTH_HOME:-${HOME:-}/.grok}/auth.json" ] || [ -n "${XAI_API_KEY:-}" ]; then
    return 0
  fi
  if [ "${AI_GROK_ALLOW_NO_CREDS:-0}" = 1 ]; then
    return 0
  fi
  printf 'grok door: no cached credentials and no XAI_API_KEY. Run grok login, or set AI_GROK_ALLOW_NO_CREDS=1 for offline tests.\n' >&2
  return 127
}

# Native path for --cwd on Windows (MSYS conversion is a heuristic, not a
# contract). bin/ai-grok-implement documents the cost of getting this wrong.
native_cwd() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

# Parse the provider envelope into OUR report shape: findings first, verdict
# last under a literal '## Verdict' heading. Same grammar the pool and
# lifecycle consume.
extract_report() { # extract_report RESULT_JSON DEST HEAD MODE
  local result="$1" dest="$2" head="$3" mode="$4" text stop turns cost model
  text="$(jq -r '.text // ""' "$result" 2>/dev/null || true)"
  stop="$(jq -r '.stopReason // "unknown"' "$result" 2>/dev/null || echo unknown)"
  turns="$(jq -r '.num_turns // "?"' "$result" 2>/dev/null || echo '?')"
  cost="$(jq -r '.total_cost_usd // "unknown"' "$result" 2>/dev/null || echo unknown)"
  model="$(jq -r '(.modelUsage // {} | keys | first) // "unknown"' "$result" 2>/dev/null || echo unknown)"
  case "$stop" in
    end_turn|EndTurn|stop|completed) ;;
    *)
      printf 'grok door: non-terminal stopReason: %s\n' "$stop" >&2
      return 1
      ;;
  esac
  {
    printf '# Grok %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    printf '| model | `%s` |\n| stopReason | `%s` |\n| turns | `%s` |\n| cost | `$%s` |\n| reviewed commit | `%s` |\n\n' \
      "$model" "$stop" "$turns" "$cost" "$head"
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
  local grok cwd out prompt_full rc
  grok="$(resolve_grok)" || exit $?
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'grok door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'grok door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

  # Packet preamble: the sealed evidence is the subject; the workdir is the
  # disposable copy. The runner owns seal/store; this only points the model.
  prompt_full="$(mktemp)"
  {
    printf 'Your evidence packet is at %s/MANIFEST.md. Read it first.\n' "$DOOR_PACKET_DIR"
    printf 'It contains the exact commits under review, the changed files, the full patch, and what you are being asked to decide.\n'
    printf 'The reviewed head commit is %s; quote that full SHA in your report.\n\n' "$DOOR_HEAD"
    cat "$DOOR_PROMPT_FILE"
    printf '\n\n---\nFormatting requirement: structure your reply so the final answer is last, under a literal '"'"'## Verdict'"'"' heading.\n'
  } > "$prompt_full"

  cwd="$(native_cwd "$DOOR_WORKDIR")"
  out="$(mktemp)"
  set +e
  if [ "$MODE" = implement ]; then
    env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" --prompt-file "$prompt_full" \
        --max-turns "$GROK_MAX_TURNS" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
  else
    env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" --prompt-file "$prompt_full" \
        --max-turns "$GROK_MAX_TURNS" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
  fi
  rc=$?
  set -e

  if [ "$rc" -eq 92 ]; then
    printf 'AI_REVIEWER_OUT_OF_CREDIT grok door\n' >&2
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || ! jq -e 'has("stopReason")' "$out" >/dev/null 2>&1; then
    printf 'grok door: provider call failed (exit %s)\n' "$rc" >&2
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
