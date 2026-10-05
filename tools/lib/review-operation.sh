# shellcheck shell=bash
# Installation operations an exact-head review may approve by name.
# Owner: the ai-review approval front door (bin/ai-review), with the pool and
# Codex review wrappers that write the reviewer request. Each name matches an
# `ai-task-gates authorize-install` route, which requires the reviewer's report
# to contain the exact line "Approved <name>." (docs/deployment.md).
# stale-linux-manifest-recovery is deliberately absent: its approval must also
# bind host-specific manifest and gate hashes that this request cannot carry.

review_operation_valid() {
  case "${1:-}" in
    legacy-managed-launcher-refresh|first-managed-install|partial-managed-launcher-recovery) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the request text for an operation; prints nothing for an empty one.
review_operation_request() {
  local op="${1:-}"
  [ -n "$op" ] || return 0
  review_operation_valid "$op" || return 1
  printf '%s\n' "This review also decides the one-use installation operation '$op' described in docs/deployment.md, applied to this exact reviewed head. Examine the full target source and that operation. If, and only if, your verdict is APPROVE and you approve that operation, write this exact line on a line by itself before the Verdict heading:" "Approved $op." "If you do not approve that operation, do not write that line."
}
