#!/usr/bin/env bash
# Small, provider-neutral primitives for wrapper adapters.
#
# This file intentionally has no lock, payment, terminal-record, retry, or
# refusal policy. Those choices remain provider-owned until their behaviour is
# independently proven equivalent.

provider_wrapper_valid_name() {
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}

provider_wrapper_sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

# Caller identity is path-safe and may not start with a dot (it becomes a
# path component in session metadata). Stricter than provider_wrapper_valid_name.
provider_wrapper_valid_caller() {
  case "$1" in ''|.*|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}

# provider_wrapper_detect_caller
# Print the one harness driving this process, or fail when zero or several
# are present. Markers are process identity only: MiMo Desktop injects its
# MIMO_* tool paths into every process it starts; Claude Code sets CLAUDECODE
# / CLAUDE_CODE_SESSION_ID; Codex sets CODEX_THREAD_ID / CODEX_SANDBOX;
# ZCode sets ZCODE_SESSION_ID. Never guess across harnesses — independence
# recording depends on the name being the real caller.
provider_wrapper_detect_caller() {
  local -a found=()
  if [ -n "${MIMO_SESSION_ID:-}" ] || [ -n "${MIMO_NODE:-}" ] || [ -n "${MIMO_PYTHON:-}" ] || [ -n "${MIMO_NPM:-}" ] || [ -n "${MIMO_ELECTRON_NODE_HOST:-}" ]; then
    found+=("mimo")
  fi
  if [ "${CLAUDECODE:-}" = 1 ] || [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
    found+=("claude")
  fi
  if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; then
    found+=("codex")
  fi
  if [ -n "${ZCODE_SESSION_ID:-}" ]; then
    found+=("zcode")
  fi
  [ "${#found[@]}" -eq 1 ] || return 1
  printf '%s\n' "${found[0]}"
}

# provider_wrapper_resolve_caller EXPLICIT_VALUE
# Print the caller this invocation must record. An explicit value (the
# provider's own AI_*_CALLER, or --caller) always wins; otherwise the harness
# is detected. Fails when neither names a single caller — wrappers fail closed
# rather than silently defaulting to a wrong engine name.
provider_wrapper_resolve_caller() {
  local explicit="${1:-}" detected
  if [ -n "$explicit" ]; then
    provider_wrapper_valid_caller "$explicit" || return 2
    printf '%s\n' "$explicit"
    return 0
  fi
  detected="$(provider_wrapper_detect_caller)" || return 1
  printf '%s\n' "$detected"
}
