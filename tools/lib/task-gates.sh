#!/usr/bin/env bash
# Shared task-gate library. Sourced by bin/ai-task-gates and by
# tools/ci/classify-changes.sh so that one implementation serves CI routing,
# local suite selection, and the pre-action preflight.
#
# Nothing here writes state or starts an external process. Callers own that.

# ---------------------------------------------------------------------------
# Legacy coarse classifier.
#
# This is the byte-for-byte contract that .github/workflows/fast-classifier.yml
# and tests/lib-selection.sh already depend on. It is deliberately NOT derived
# from config/task-gates.json: the gate contract may grow classes freely without
# silently changing a CI output that other jobs branch on.
# ---------------------------------------------------------------------------
tg_legacy_classify() {
  local event="$1" path
  local prose_only=true skills=false code=false workflow=false
  local powershell=false test_fixtures=false count=0 run_long=true

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    count=$((count + 1))
    case "$path" in skills/*) skills=true ;; esac
    case "$path" in .github/workflows/*) workflow=true ;; esac
    case "$path" in *.ps1|*.psm1|*.psd1) powershell=true ;; esac
    case "$path" in tests/fixtures/*) test_fixtures=true ;; esac
    case "$path" in
      README.md|AGENTS.md|bugs.md|plan_*.md|HANDOFF.d/*.md|docs/*.md|docs/**/*.md|tests/verification/*.md|tests/verification/**/*.md) ;;
      *) prose_only=false; code=true ;;
    esac
  done

  # Only pull requests may use the prose bypass. All other events stay complete.
  if [ "$event" != pull_request ] || [ "$count" -eq 0 ]; then prose_only=false; fi
  [ "$prose_only" = true ] && run_long=false

  printf 'changed_count=%s\n' "$count"
  printf 'prose_only=%s\n' "$prose_only"
  printf 'skills=%s\n' "$skills"
  printf 'code=%s\n' "$code"
  printf 'workflow=%s\n' "$workflow"
  printf 'powershell=%s\n' "$powershell"
  printf 'test_fixtures=%s\n' "$test_fixtures"
  printf 'run_long=%s\n' "$run_long"
}

# ---------------------------------------------------------------------------
# Repository identity. A linked worktree shares its clone's origin, so a
# worktree and its parent checkout always resolve to the same string. Coverage
# is keyed on repositories, never on folders.
# ---------------------------------------------------------------------------
tg_identity() {
  local remote identity
  remote="$(git remote get-url origin 2>/dev/null || true)"
  case "$remote" in
    http://*|https://*|ssh://*|git@*)
      identity="$(printf '%s' "$remote" | sed -E \
        -e 's#^[a-z][a-z0-9+.-]*://([^/@]+(:[^/@]*)?@)?[^/]+/##' \
        -e 's#^[^@/]+@[^:/]+:##' -e 's#\.git$##' -e 's#^/+##' -e 's#/+$##')" ;;
    '') identity="" ;;
    *) identity="local/$(basename "${remote%.git}")" ;;
  esac
  [ -n "$identity" ] || identity="local/$(basename "$(git rev-parse --show-toplevel 2>/dev/null || printf 'unknown')")"
  printf '%s' "$identity"
}

# tg_glob_regex <glob> — translate a policy glob into an anchored ERE.
#   *   matches within one path segment
#   **  crosses segments; `**/` also matches zero segments
tg_glob_regex() {
  local glob="$1" out="" i=0 ch next
  while [ "$i" -lt "${#glob}" ]; do
    ch="${glob:$i:1}"
    case "$ch" in
      '*')
        next="${glob:$((i+1)):1}"
        if [ "$next" = '*' ]; then
          if [ "${glob:$((i+2)):1}" = '/' ]; then out="$out(.*/)?"; i=$((i+3))
          else out="$out.*"; i=$((i+2)); fi
        else
          out="$out[^/]*"; i=$((i+1))
        fi
        ;;
      '?') out="$out[^/]"; i=$((i+1)) ;;
      '.'|'+'|'('|')'|'['|']'|'{'|'}'|'^'|'$'|'|'|'\\') out="$out\\$ch"; i=$((i+1)) ;;
      *) out="$out$ch"; i=$((i+1)) ;;
    esac
  done
  printf '^%s$' "$out"
}

# tg_glob_match <glob> <path>
tg_glob_match() {
  local re; re="$(tg_glob_regex "$1")"
  [[ "$2" =~ $re ]]
}

# tg_identity_match <pattern> <identity> — shell-glob match on owner/repo.
tg_identity_match() {
  # shellcheck disable=SC2254
  case "$2" in $1) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Shared pre-action gate.
#
# Called by the entry points that start something expensive or risky: the
# reviewer lifecycle, the pull-request wait, and the approval-gate front door.
# It runs BEFORE any provider process starts and before any call is spent, so a
# task whose real change set does not match its declared class costs nothing.
#
#   tg_preflight_gate <action> [--owner-request TEXT] [--acknowledge TEXT]
#
# Returns 0 to proceed. Returns the engine's own status (3 blocked,
# 4 cannot classify) after printing its explanation on stderr. A gate that is
# missing, or a directory that is not a Git worktree, is not a block: there is
# nothing to classify, and this must never become a new way for a tool to fail.
#
# AI_TASK_GATES_MODE=none disables the gate, and only for a hostile test that
# has also set AI_DEVOPS_TEST_MODE=1. It is ignored everywhere else.
# ---------------------------------------------------------------------------
tg_preflight_gate() {
  local action="$1"; shift
  local bin="${AI_TASK_GATES_BIN:-}" out rc
  if [ "${AI_TASK_GATES_MODE:-standard}" = none ] && [ "${AI_DEVOPS_TEST_MODE:-0}" = 1 ]; then
    return 0
  fi
  if [ -z "$bin" ]; then
    bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../bin" 2>/dev/null && pwd)/ai-task-gates"
  fi
  [ -x "$bin" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  out="$("$bin" check --before "$action" "$@" 2>&1)"; rc=$?
  case "$rc" in
    0) return 0 ;;
    3|4) printf '%s\n' "$out" >&2; return "$rc" ;;
    # Anything else is the gate itself failing. Fail closed: a gate that cannot
    # answer must not be read as a yes.
    *) printf 'task gate failed (exit %s); refusing rather than guessing:\n%s\n' "$rc" "$out" >&2; return 4 ;;
  esac
}
