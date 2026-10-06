# shellcheck shell=bash
# Installation operations an exact-head review may approve by name.
# Owner: the ai-review approval front door (bin/ai-review), with the pool and
# Codex review wrappers that write the reviewer request. Each name matches an
# `ai-task-gates authorize-install` route, which requires the reviewer's report
# to contain the exact line "Approved <name>." (docs/deployment.md).
# stale-linux-manifest-recovery also binds host evidence: the wrapper computes
# the stale manifest SHA and hash plus the live installed SHA and gate hash
# from this machine itself (never from caller input) and writes them in the
# wrapper-owned report header, which is the only place the gate trusts them.

review_operation_valid() {
  case "${1:-}" in
    legacy-managed-launcher-refresh|first-managed-install|partial-managed-launcher-recovery|stale-linux-manifest-recovery) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the host evidence rows for an operation (nothing for operations that
# carry none). Fails when the evidence cannot be read from this machine.
# The paths are fixed; no environment or argument can redirect them.
review_operation_evidence() {
  [ "${1:-}" = stale-linux-manifest-recovery ] || return 0
  review_operation_evidence_from /usr/local/bin/ai-task-gates /etc/ai-devops/install-manifest.tsv
}

# Internal helper with explicit paths, used by review_operation_evidence and by
# the test suite. The installation gate recomputes every value from the real
# host, so rows produced for any other path can never authorize a recovery.
review_operation_evidence_from() {
  local launcher="$1" manifest="$2"
  local gate root head stale manifest_hash gate_hash
  [ -L "$launcher" ] && [ -f "$manifest" ] || return 1
  gate="$(readlink -f "$launcher")" && [ -f "$gate" ] || return 1
  root="$(cd "$(dirname "$gate")/.." && pwd -P)" || return 1
  head="$(git -C "$root" rev-parse --verify -q HEAD)" && [[ "$head" =~ ^[0-9a-f]{40}$ ]] || return 1
  stale="$(awk -F '\t' '$1=="meta" && $2=="source_sha" {print $3}' "$manifest")"
  [[ "$stale" =~ ^[0-9a-f]{40}$ ]] && [ "$stale" != "$head" ] || return 1
  manifest_hash="$(sha256sum "$manifest" | cut -d' ' -f1)" && [[ "$manifest_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  gate_hash="$(sha256sum "$root/bin/ai-task-gates" | cut -d' ' -f1)" && [[ "$gate_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '| stale manifest SHA | `%s` |\n| stale manifest hash | `%s` |\n| live installed SHA | `%s` |\n| live gate hash | `%s` |\n' \
    "$stale" "$manifest_hash" "$head" "$gate_hash"
}

# Prints the request text for an operation; prints nothing for an empty one.
# The optional second argument is the evidence from review_operation_evidence.
review_operation_request() {
  local op="${1:-}" evidence="${2:-}"
  [ -n "$op" ] || return 0
  review_operation_valid "$op" || return 1
  printf '%s\n' "This review also decides the one-use installation operation '$op' described in docs/deployment.md, applied to this exact reviewed head."
  if [ -n "$evidence" ]; then
    printf '%s\n' "The review wrapper read this host evidence from the local machine; it will be recorded in the report header and the installation gate re-checks it against the machine:" "$evidence" \
      "Approve this operation only if moving this host from the live installed SHA (whose installed manifest still names the stale manifest SHA) to this reviewed head is safe."
  fi
  printf '%s\n' "Examine the full target source and that operation. If, and only if, your verdict is APPROVE and you approve that operation, write this exact line on a line by itself before the Verdict heading:" "Approved $op." "If you do not approve that operation, do not write that line."
}
