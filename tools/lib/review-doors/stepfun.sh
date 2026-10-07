#!/usr/bin/env bash
# stepfun.sh — StepFun door for the shared review runner.
#
# Provider bits ONLY: engine selection (StepCode on Ubuntu/Linux under
# bubblewrap, pinned OpenCode on Windows), credentials presence, model pin,
# provider tool set, and parse to our report shape. This file must NOT own
# task gate, identity, sandbox, packet seal/store, lifecycle terminal, report
# floor, or cleanup. tests/test-ai-review-engine.sh asserts that source purity.
#
# Platform rule (owner 2026-09-30, #1086): StepCode is Linux-only. On Windows
# the OpenCode path runs as today (folder + test shell). A platform with no
# engine reports `unsupported-platform` and exits 2 — NEVER quarantine for a
# platform. preflight maps that exit to the platform class.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash stepfun.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'stepfun door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'stepfun door: usage: stepfun.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?stepfun door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?stepfun door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?stepfun door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?stepfun door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?stepfun door: DOOR_HEAD is required}"

# Repository root, for the pinned OpenCode install and the StepFun profile.
SF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SF_PROFILE_SRC="$SF_ROOT/config/opencode-stepfun"
# The one StepCode bubblewrap launch, shared with bin/ai-stepfun.
# shellcheck source=../stepfun-sandbox.sh
source "$SF_ROOT/tools/lib/stepfun-sandbox.sh"
SF_OC_VERSION="$(tr -d ' \r\n' < "$SF_ROOT/config/opencode/version" 2>/dev/null || true)"

# Model pins. StepCode uses the step/ id; the OpenCode profile pins
# stepfun-api/step-5-preview (bin/ai-stepfun model case).
SF_STEP_MODEL="${AI_STEPFUN_MODEL:-step/step-5-preview}"
SF_OC_PROVIDER="stepfun-api"
SF_OC_MODEL_ID="step-5-preview"
SF_TIMEOUT="${DOOR_TIMEOUT:-${AI_STEPFUN_TIMEOUT:-3600}}"
SF_BASE_URL="${AI_STEPFUN_BASE_URL:-https://api.stepfun.ai/v1}"

# Platform detection (same shape as bin/ai-stepfun).
SF_IS_WINDOWS=0
SF_IS_LINUX=0
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*) SF_IS_WINDOWS=1 ;;
  Linux|linux) SF_IS_LINUX=1 ;;
esac
native_path() {
  if [ "$SF_IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

unsupported_platform() {
  printf 'stepfun door: unsupported-platform: %s\n' "$1" >&2
  # Never quarantine for a platform. Exit 2 so preflight records the
  # platform class instead of a provider fault.
  exit 2
}

# `step` is a generic name (Smallstep's CLI uses it too), so prefer StepCode's
# own install path and accept a binary only if it identifies as StepCode
# (#1086). A wrong program in an override is refused, never silently replaced.
resolve_stepcode() {
  local b c
  if [ -n "${AI_STEPFUN_STEP_BIN:-}" ]; then
    [ -x "$AI_STEPFUN_STEP_BIN" ] && "$AI_STEPFUN_STEP_BIN" --help 2>/dev/null | head -n1 | grep -q '^step - AI coding assistant' || return 1
    printf '%s' "$AI_STEPFUN_STEP_BIN"; return 0
  fi
  for c in "${HOME:-}/.stepcode/bin/step" "$(command -v step 2>/dev/null || true)"; do
    [ -n "$c" ] && [ -x "$c" ] || continue
    "$c" --help 2>/dev/null | head -n1 | grep -q '^step - AI coding assistant' || continue
    b="$c"; break
  done
  [ -n "${b:-}" ] || return 1
  printf '%s' "$b"
}

resolve_opencode() {
  if [ -n "${AI_STEPFUN_OPENCODE:-}" ] && [ -x "${AI_STEPFUN_OPENCODE}" ]; then
    printf '%s' "$AI_STEPFUN_OPENCODE"; return 0
  fi
  local home_dir="$HOME" pinned c
  if [ "$SF_IS_WINDOWS" = 1 ] && [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
    home_dir="$(cygpath -u "$USERPROFILE")"
  fi
  if [ -n "$SF_OC_VERSION" ]; then
    pinned="$home_dir/.local/lib/ai-devops/opencode/$SF_OC_VERSION/node_modules/opencode-ai/bin/opencode.exe"
    [ -x "$pinned" ] && { printf '%s' "$pinned"; return 0; }
  fi
  c="$(command -v opencode 2>/dev/null || true)"
  [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  return 1
}

# Engine selection and the platform rule. Windows: OpenCode only — StepCode
# is Linux-only and asking for it on Windows is `unsupported-platform`, never
# a quarantine. Linux: StepCode under bubblewrap is the rotation rule; a host
# with neither StepCode nor OpenCode has no engine at all.
select_engine() {
  local forced="${AI_STEPFUN_ENGINE:-}"
  if [ "$SF_IS_WINDOWS" = 1 ]; then
    case "$forced" in
      stepcode)
        unsupported_platform 'StepCode is Linux-only. Use OpenCode on Windows (folder + test shell).' ;;
      opencode|'') ;;
      *)
        unsupported_platform "unknown engine $forced on Windows." ;;
    esac
    resolve_opencode >/dev/null || unsupported_platform 'no OpenCode install. Run bin/setup-opencode-glm.ps1 first.'
    printf 'opencode'
    return 0
  fi
  if [ "$SF_IS_LINUX" = 1 ]; then
    case "$forced" in
      stepcode)
        resolve_stepcode >/dev/null || unsupported_platform 'StepCode CLI (step) is not installed. Install: curl -fsSL https://static-openapi.stepfun.com/stepcode/install.sh | bash'
        printf 'stepcode'
        return 0
        ;;
      opencode)
        resolve_opencode >/dev/null || unsupported_platform 'no OpenCode install. Run bin/setup-opencode-glm.sh.'
        printf 'opencode'
        return 0
        ;;
      '')
        if resolve_stepcode >/dev/null; then printf 'stepcode'; return 0; fi
        if resolve_opencode >/dev/null; then printf 'opencode'; return 0; fi
        unsupported_platform 'no StepCode CLI and no OpenCode install. Install StepCode, or the OpenCode harness with bin/setup-opencode-glm.sh.'
        ;;
      *)
        unsupported_platform "unknown engine $forced on Linux." ;;
    esac
  fi
  unsupported_platform 'StepFun runs on Ubuntu/Linux (bubblewrap) or Windows (folder + test shell).'
}

# Credentials presence only — never print a key. A missing store is a local
# dependency failure, not a provider fault. The key enters the child
# environment only; it never appears in argv or output.
SF_KEY=""
require_credentials() {
  if [ -n "${AI_STEPFUN_KEY:-}" ]; then
    SF_KEY="$AI_STEPFUN_KEY"
    return 0
  fi
  if [ -n "${STEPFUN_API_KEY:-}" ]; then
    SF_KEY="$STEPFUN_API_KEY"
    return 0
  fi
  if [ -n "${STEP_API_KEY:-}" ]; then
    SF_KEY="$STEP_API_KEY"
    return 0
  fi
  local store="${AI_STEPFUN_KEY_STORE:-${HOME:-}/.config/ai-devops/secrets/stepfun-api-key}"
  if [ -s "$store" ]; then
    IFS= read -r SF_KEY < "$store" || SF_KEY=""
    [ -n "$SF_KEY" ] && return 0
  fi
  if [ "${AI_STEPFUN_ALLOW_NO_CREDS:-0}" = 1 ]; then
    return 0
  fi
  printf 'stepfun door: no StepFun key in the protected store. Run ai-stepfun store-key, or set AI_STEPFUN_ALLOW_NO_CREDS=1 for offline tests.\n' >&2
  return 127
}

# Fresh per-run XDG tree (#1086 pattern): the repository profile is copied in
# before the turn and the whole tree is discarded after. On Windows the
# folder-shell agent profiles replace the Linux ones (bin/ai-stepfun).
install_opencode_profile() { # install_opencode_profile XDG_ROOT AGENT
  local root="$1" agent="$2" xdg="$1/config/opencode" src
  [ -f "$SF_PROFILE_SRC/opencode.json" ] || {
    printf 'stepfun door: local_dependency_unavailable: profile missing: %s/opencode.json\n' "$SF_PROFILE_SRC" >&2
    return 127
  }
  mkdir -p "$xdg/agent" "$root/data" "$root/state" "$root/cache"
  cp "$SF_PROFILE_SRC/opencode.json" "$xdg/opencode.json"
  if [ "$SF_IS_WINDOWS" = 1 ]; then
    src="$SF_PROFILE_SRC/agent/${agent}-windows.md"
  else
    src="$SF_PROFILE_SRC/agent/${agent}.md"
  fi
  [ -f "$src" ] || {
    printf 'stepfun door: local_dependency_unavailable: agent profile missing: %s\n' "$src" >&2
    return 127
  }
  cp "$src" "$xdg/agent/${agent}.md"
}

# Parse the provider envelope into OUR report shape: findings first, verdict
# last under a literal '## Verdict' heading. OpenCode speaks the text/tool_use
# JSONL of the other OpenCode doors; StepCode prints its answer on stdout.
extract_report() { # extract_report RESULT DEST HEAD MODE ENGINE
  local result="$1" dest="$2" head="$3" mode="$4" engine="$5" text
  if [ "$engine" = opencode ]; then
    text="$(jq -r 'select(.type=="text") | .part.text // ""' "$result" 2>/dev/null | sed '/^$/d' || true)"
  else
    text="$(cat "$result" 2>/dev/null || true)"
  fi
  [ -n "$text" ] || {
    printf 'stepfun door: provider returned no assistant text.\n' >&2
    return 1
  }
  {
    printf '# StepFun %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    if [ "$engine" = opencode ]; then
      printf '| model | `%s/%s` |\n| harness | `opencode` |\n' "$SF_OC_PROVIDER" "$SF_OC_MODEL_ID"
    else
      printf '| model | `%s` |\n| harness | `stepcode` |\n' "$SF_STEP_MODEL"
    fi
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
  local engine bin prompt_full out log rc agent
  engine="$(select_engine)" || exit $?
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'stepfun door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'stepfun door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

  # Packet preamble: the sealed evidence is the subject; the workdir is the
  # disposable copy. The runner owns seal/store; this only points the model.
  prompt_full="$(mktemp)"
  {
    printf 'Your evidence packet is at %s/MANIFEST.md. Read it first.\n' "$DOOR_PACKET_DIR"
    printf 'It contains the exact commits under review, the changed files, the full patch, and what you are being asked to decide.\n'
    printf 'The reviewed head commit is %s; quote that full SHA in your report.\n' "$DOOR_HEAD"
    # StepCode refuses dangerous or unanalysable commands when no person can
    # confirm, and the refusal ends the turn with no report.
    printf 'Shell rule: this harness refuses, without a person present, any command it cannot fully analyse or judges dangerous, and the refusal ends your turn with no report. Use plain literal commands only: run a test suite as `bash tests/NAME.sh` with no options; never use rm -rf, sed -i, eval, or inline-code options such as bash -c, bash -x, sh -c, python -c, or node -e. The copy is discarded afterwards, so cleanup is never needed.\n\n'
    cat "$DOOR_PROMPT_FILE"
    printf '\n\n---\nFormatting requirement: structure your reply so the final answer is last, under a literal '"'"'## Verdict'"'"' heading, followed by exactly one of APPROVE, REJECT, or BLOCKED.\n'
  } > "$prompt_full"
  chmod 600 "$prompt_full" 2>/dev/null || true

  out="$(mktemp)"
  log="$out"
  set +e
  if [ "$engine" = opencode ]; then
    bin="$(resolve_opencode)" || { rm -f "$prompt_full"; exit 127; }
    if [ "$MODE" = implement ]; then agent="stepfun-implement"; else agent="stepfun-review"; fi
    local xdg
    xdg="$(mktemp -d)"
    if ! install_opencode_profile "$xdg" "$agent"; then
      rm -rf "$xdg"; rm -f "$prompt_full"; exit 127
    fi
    (
      export XDG_CONFIG_HOME="$(native_path "$xdg/config")" \
             XDG_DATA_HOME="$(native_path "$xdg/data")" \
             XDG_STATE_HOME="$(native_path "$xdg/state")" \
             XDG_CACHE_HOME="$(native_path "$xdg/cache")"
      if [ -n "$SF_KEY" ]; then export STEPFUN_API_KEY="$SF_KEY"; export STEP_API_KEY="$SF_KEY"; fi
      printf '%s' "$(cat "$prompt_full")" \
        | timeout "$SF_TIMEOUT" "$bin" run --agent "$agent" --auto \
            --format json --model "$SF_OC_PROVIDER/$SF_OC_MODEL_ID" \
            --dir "$(native_path "$DOOR_WORKDIR")" \
            > "$log" 2> "$out.err"
    )
    rc=$?
    rm -rf "$xdg"
  else
    # StepCode on Linux. Rotation rule 12 (#1086): every turn runs under the
    # shared bubblewrap launch (tools/lib/stepfun-sandbox.sh) with the system
    # trees, the CLI, the packet, and the disposable copy mounted.
    bin="$(resolve_stepcode)" || { rm -f "$prompt_full"; exit 127; }
    local bwrap timeout_bin
    bwrap="${AI_STEPFUN_BWRAP:-$(PATH=/usr/bin:/bin command -v bwrap 2>/dev/null || true)}"
    [ -n "$bwrap" ] && [ -x "$bwrap" ] || {
      printf 'stepfun door: unsupported-platform: StepCode turns require bubblewrap (bwrap) on Linux.\n' >&2
      rm -f "$prompt_full"
      exit 2
    }
    local home_tmp
    timeout_bin="$(PATH=/usr/bin:/bin command -v timeout)"
    home_tmp="$(mktemp -d)"
    # The packet usually lives outside the workdir; mount it read-only so the
    # model can read MANIFEST.md as the preamble tells it to.
    local -a packet_bind=()
    case "$DOOR_PACKET_DIR" in "$DOOR_WORKDIR"|"$DOOR_WORKDIR"/*) ;; *) packet_bind=(--ro-bind "$DOOR_PACKET_DIR" "$DOOR_PACKET_DIR") ;; esac
    # StepCode's command guard ends a non-interactive turn on any command it
    # will not run unattended, with no report and no override. One bounded
    # retry tells the model exactly which command was refused.
    local prompt_text attempt blocked
    prompt_text="$(cat "$prompt_full")"
    for attempt in 1 2; do
      (
        export HOME="$home_tmp" PATH="/usr/local/bin:/usr/bin:/bin"
        export STEP_API_KEY="$SF_KEY" STEP_BASE_URL="$SF_BASE_URL" STEP_AUTOPILOT=1
        stepfun_sandbox_exec "$bwrap" "$timeout_bin" "$SF_TIMEOUT" "$bin" \
          "${packet_bind[@]}" \
          --bind "$DOOR_WORKDIR" "$DOOR_WORKDIR" --chdir "$DOOR_WORKDIR" -- \
          -p --no-session --model "$SF_STEP_MODEL" \
          --approval-mode auto --non-interactive-approval allow \
          --no-extensions --no-skills --no-prompt-templates --no-themes \
          --no-approve --no-update-check -- "$prompt_text"
      ) < /dev/null > "$log" 2> "$out.err"
      rc=$?
      [ "$rc" -ne 0 ] && [ "$attempt" = 1 ] || break
      blocked="$(grep -m1 '^Blocked run_command:' "$out.err" | cut -c1-400 || true)"
      [ -n "$blocked" ] || break
      printf 'stepfun door: the command guard ended the turn; retrying once (%s)\n' "$blocked" >&2
      prompt_text="$prompt_text"$'\n\n'"A previous attempt at this review ended with no report because the harness refused this command: $blocked"$'\n'"Do not run that command or anything like it. Use plain literal commands only."
    done
    rm -rf "$home_tmp"
  fi
  set -e
  SF_KEY=""

  if [ "$rc" -eq 92 ]; then
    printf 'AI_REVIEWER_OUT_OF_CREDIT stepfun door\n' >&2
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || [ ! -s "$log" ]; then
    printf 'stepfun door: provider call failed (exit %s)\n' "$rc" >&2
    [ -s "$out.err" ] && sed -E 's/((API[_-]?KEY|TOKEN|SECRET|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig; s/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig' "$out.err" | tail -20 >&2 || true
    rm -f "$prompt_full"
    exit 1
  fi

  if ! extract_report "$log" "$DOOR_REPORT_OUT" "$DOOR_HEAD" "$MODE" "$engine"; then
    rm -f "$prompt_full"
    exit 1
  fi
  rm -f "$prompt_full"
  exit 0
}

main "$@"
