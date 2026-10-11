#!/usr/bin/env bash
# Offline runtime selection shared by ordinary DeepSeek readiness and its door.
# Owner: reviewer harness; no provider calls or credential reads. Consolidated
# here so allocation cannot claim a runtime that the ordinary door cannot find.
deepseek_resolve_opencode() { # TOOLKIT_ROOT -> executable path
  local root="$1" home_dir="$HOME" version pinned candidate platform
  if [ -n "${AI_DEEPSEEK_OPENCODE:-}" ] && [ -x "$AI_DEEPSEEK_OPENCODE" ]; then
    printf '%s' "$AI_DEEPSEEK_OPENCODE"; return 0
  fi
  platform="$(uname -s 2>/dev/null || echo unknown)"
  case "$platform" in MINGW*|MSYS*|CYGWIN*)
    if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
      home_dir="$(cygpath -u "$USERPROFILE")"
    fi ;;
  esac
  version="$(tr -d ' \r\n' < "$root/config/opencode/version" 2>/dev/null || true)"
  if [ -n "$version" ]; then
    pinned="$home_dir/.local/lib/ai-devops/opencode/$version/node_modules/opencode-ai/bin/opencode.exe"
    [ -x "$pinned" ] && { printf '%s' "$pinned"; return 0; }
  fi
  candidate="$(command -v opencode 2>/dev/null || true)"
  [ -n "$candidate" ] && [ -x "$candidate" ] && { printf '%s' "$candidate"; return 0; }
  printf 'deepseek door: local_dependency_unavailable: OpenCode binary not found. This is not a DeepSeek provider fault. Set AI_DEEPSEEK_OPENCODE or run bin/setup-opencode-glm.sh.\n' >&2
  return 127
}
