#!/usr/bin/env bash
# review-session-skip.sh — per-session reviewer skip list (plan_reviewer-observation-week step 2).
#
# Once a reviewer fails in a coding session, that session never draws it
# again. The list is keyed by the CALLING session (not the reviewer's own
# session id), lives under the existing state root (never in a repository),
# and survives a worktree change. One append-only JSONL file per session:
#   {"provider":"muse","reason":"fast-fail-silent-start","at":"2026-10-21T21:00:00Z"}
#
# Sourced by bin/ai-review, bin/ai-review-lifecycle and the shared review
# core. Provider-neutral (#1834): no provider name appears here.

review_skip_dir() { # nonzero when the list is off (offline suites without a private dir)
  if [ -z "${AI_REVIEW_SESSION_SKIP_DIR:-}" ] && [ "${AI_DEVOPS_TEST_MODE:-0}" = 1 ]; then return 1; fi
  printf '%s\n' "${AI_REVIEW_SESSION_SKIP_DIR:-$HOME/.local/state/ai-devops/session-skip}"
}

# Resolve the calling coding session once: the first non-empty client id, else
# the parent process start time + pid. Exported so every child (pool, engine,
# lifecycle, scoreboard) records and keys on the same value.
review_caller_session_id() {
  local sid="" var start
  for var in AI_CALLER_SESSION_ID CLAUDE_CODE_SESSION_ID CODEX_SESSION_ID CODEX_THREAD_ID MIMO_SESSION_ID ZCODE_SESSION_ID; do
    sid="${!var:-}"
    [ -z "$sid" ] || break
  done
  if [ -z "$sid" ]; then
    start="$(ps -o lstart= -p "$PPID" 2>/dev/null | tr -cd '[:alnum:]' || true)"
    sid="ppid-${PPID}-${start:-unknown}"
  fi
  # A path component only: anything else becomes a stable digest.
  if ! [[ "$sid" =~ ^[A-Za-z0-9._-]{1,128}$ ]] || [ "$sid" = . ] || [ "$sid" = .. ]; then
    sid="sha-$(printf '%s' "$sid" | sha256sum | cut -c1-32)"
  fi
  printf '%s\n' "$sid"
}

review_export_caller_session_id() {
  AI_CALLER_SESSION_ID="$(review_caller_session_id)"
  export AI_CALLER_SESSION_ID
}

_review_skip_file() { # every read and write validates the id: a path component only
  local d
  [[ "${1:-}" =~ ^[A-Za-z0-9._-]{1,128}$ ]] && [ "$1" != . ] && [ "$1" != .. ] || return 1
  d="$(review_skip_dir)" || return 1
  printf '%s/%s.jsonl\n' "$d" "$1"
}

# Retention: a session's list is useless once the session is gone.
_review_skip_prune() {
  local d
  d="$(review_skip_dir)" || return 0
  [ -d "$d" ] && find "$d" -maxdepth 1 -type f -name '*.jsonl' -mtime +14 -delete 2>/dev/null || true
}

skip_add() { # skip_add SESSION PROVIDER REASON
  local sid="$1" provider="$2" reason="${3:-failed}" file
  [[ "$sid" =~ ^[A-Za-z0-9._-]{1,128}$ ]] && [[ "$provider" =~ ^[a-z0-9_-]{1,32}$ ]] || return 1
  [[ "$reason" =~ ^[A-Za-z0-9._:-]{1,80}$ ]] || reason=failed
  file="$(_review_skip_file "$sid")" || return 0
  mkdir -p "$(dirname "$file")" 2>/dev/null || return 1
  skip_has "$sid" "$provider" && return 0
  _review_skip_prune
  printf '{"provider":"%s","reason":"%s","at":"%s"}\n' "$provider" "$reason" "$(date -u +%FT%TZ)" >> "$file"
}

skip_has() { # skip_has SESSION PROVIDER -> 0 when skipped
  local file
  file="$(_review_skip_file "$1")" || return 1
  [ -f "$file" ] || return 1
  grep -Fq "\"provider\":\"$2\"," "$file"
}

skip_list() { # skip_list SESSION -> "provider reason at" per line
  local file
  file="$(_review_skip_file "$1")" || return 0
  [ -f "$file" ] || return 0
  jq -r '"\(.provider) \(.reason) \(.at)"' "$file" 2>/dev/null || true
}

skip_reason() { # skip_reason SESSION PROVIDER -> "reason at"
  skip_list "$1" | awk -v p="$2" '$1==p{print $2, $3; exit}'
}

# Failures that belong to the caller or the source, never to the reviewer:
# they must not cost the session a reviewer.
skip_failure_counts() { # skip_failure_counts FAILURE -> 0 when it should skip
  case "${1:-}" in
    ''|tests-command-failed|tests-evidence-recording-failed|source-identity-changed|stale-source|interrupted) return 1 ;;
  esac
  return 0
}
