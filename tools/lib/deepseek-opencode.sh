#!/usr/bin/env bash
# Offline runtime selection shared by ordinary DeepSeek readiness and its door.
# Owner: reviewer harness; no provider calls or credential reads. Consolidated
# here so allocation cannot claim a runtime that the ordinary door cannot find.
deepseek_terminal_report() { # provider text on stdin -> reasoning, final verdict
  # Keep every reasoning line, including later compaction summaries. Move only
  # the LAST canonical heading and its authentic decision to the final two
  # lines. An invalid final section must never resurrect an earlier approval.
  awk '
    { lines[NR]=$0; clean=$0; sub(/\r$/, "", clean); if (clean ~ /^## Verdict[[:space:]]*$/) final=NR }
    END {
      if (!final) exit 1
      verdict=lines[final+1]; sub(/\r$/, "", verdict); gsub(/^[[:space:]]+|[[:space:]]+$/, "", verdict)
      if (verdict!="APPROVE" && verdict!="REJECT" && verdict!="BLOCKED") exit 1
      for (i=1;i<=NR;i++) if (i!=final && i!=final+1) print lines[i]
      print ""; print "## Verdict"; print verdict
    }
  '
}

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
