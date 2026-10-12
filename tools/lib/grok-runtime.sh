#!/usr/bin/env bash
# Owner: reviewer harness. One offline resolver for ordinary Grok allocation
# and its native door; replaces the door-local copy without invoking a provider.
grok_resolve_door_runtime() {
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
