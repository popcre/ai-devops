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
    legacy-managed-launcher-refresh|first-managed-install|partial-managed-launcher-recovery|stale-linux-manifest-recovery|mcp-launchers-only) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the host evidence rows for an operation (nothing for operations that
# carry none). Fails when the evidence cannot be read from this machine.
# The paths are fixed; no environment or argument can redirect them.
review_operation_evidence() {
  case "${1:-}" in
    stale-linux-manifest-recovery)
      review_operation_evidence_from /usr/local/bin/ai-task-gates /etc/ai-devops/install-manifest.tsv ;;
    mcp-launchers-only) review_mcp_launcher_host_evidence ;;
  esac
}

# The reviewer and the gate call this from separate worktrees of the same
# repository. Derive the primary checkout from Git, never from a caller path.
# Only fixed paths and hashes enter the report; credentials are never read.
review_mcp_launcher_host_evidence() {
  local common root head source_hash receipt_sha receipt_hash state launcher cmd
  local cfg item value inventory='' node
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  root="$(cd "$(dirname "$common")" && pwd -P)" || return 1
  [ "$(git -C "$root" rev-parse --path-format=absolute --git-dir 2>/dev/null)" = "$common" ] || return 1
  head="$(git -C "$root" rev-parse HEAD 2>/dev/null)" || return 1
  [[ "$head" =~ ^[0-9a-f]{40}$ ]] || return 1
  source_hash="$(sha256sum "$root/bin/ai-task-gates" | cut -d' ' -f1)" || return 1
  cfg="$HOME/.config/ai-devops"
  if [[ "$(uname -s)" = MINGW* || "$(uname -s)" = MSYS* || "$(uname -s)" = CYGWIN* ]]; then
    [ -n "${USERPROFILE:-}" ] || return 1
    cfg="$(cygpath -u "$USERPROFILE")/.config/ai-devops"
    launcher="$HOME/.local/bin/ai-task-gates"; cmd="$launcher.cmd"
    [ -f "$launcher" ] && [ -f "$cmd" ] || return 1
    receipt_sha="$(sed -n 's/^# source-sha=\([0-9a-f]\{40\}\)$/\1/p' "$launcher")"
    if [ -n "$receipt_sha" ]; then
      [ "$(sed -n 's/^rem source-sha=\([0-9a-f]\{40\}\)$/\1/p' "$cmd")" = "$receipt_sha" ] || return 1
      state=paired
    else
      [ "$(wc -l < "$launcher")" -eq 4 ] && [ "$(wc -l < "$cmd")" -eq 4 ] || return 1
      receipt_sha=legacy; state=legacy
    fi
    receipt_hash="$( { sha256sum "$launcher" "$cmd"; } | sha256sum | cut -d' ' -f1)" || return 1
    for item in mcp-remote-launch.cmd mcp-session-guard.mjs mcp-secret-launch.ps1; do
      if [ -f "$cfg/$item" ] && [ ! -L "$cfg/$item" ]; then value="$(sha256sum "$cfg/$item" | cut -d' ' -f1)"; else value=missing; fi
      inventory+="$item:$value;"
    done
    if [ -d "$cfg/mcp-runtime" ] && [ ! -L "$cfg/mcp-runtime" ]; then
      [ -z "$(find "$cfg/mcp-runtime" -type l -print -quit)" ] || return 1
      value="$(find "$cfg/mcp-runtime" -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1)" || return 1
    else value=missing; fi
    inventory+="mcp-runtime:$value;"
  else
    node="$(command -v node)" && [ -x "$node" ] || return 1
    printf '| mcp node path | `%s` |\n| mcp node hash | `%s` |\n' "$node" "$(sha256sum "$node" | cut -d' ' -f1)"
    launcher=/usr/local/bin/ai-task-gates
    [ -L "$launcher" ] && [ "$(readlink -f "$launcher")" = "$root/bin/ai-task-gates" ] || return 1
    [ -f /etc/ai-devops/install-manifest.tsv ] || return 1
    receipt_sha="$(awk -F '\t' '$1=="meta" && $2=="source_sha" {print $3}' /etc/ai-devops/install-manifest.tsv)"
    [[ "$receipt_sha" =~ ^[0-9a-f]{40}$ ]] || return 1
    state=manifest
    receipt_hash="$(sha256sum /etc/ai-devops/install-manifest.tsv | cut -d' ' -f1)" || return 1
    for item in mcp-remote-launch.sh mcp-session-guard.mjs; do
      [ ! -L "$cfg/$item" ] || return 1
      if [ -f "$cfg/$item" ] && [ ! -L "$cfg/$item" ]; then value="$(sha256sum "$cfg/$item" | cut -d' ' -f1)"; else value=missing; fi
      inventory+="$item:$value;"
    done
  fi
  printf '| mcp installed SHA | `%s` |\n| mcp installed gate hash | `%s` |\n| mcp full receipt state | `%s` |\n| mcp full receipt SHA | `%s` |\n| mcp full receipt hash | `%s` |\n| mcp launcher baseline digest | `%s` |\n' \
    "$head" "$source_hash" "$state" "$receipt_sha" "$receipt_hash" \
    "$(printf '%s' "$inventory" | sha256sum | cut -d' ' -f1)"
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
    printf '%s\n' "The review wrapper read this host evidence from the local machine; it will be recorded in the report header and the installation gate re-checks it against the machine:" "$evidence"
    if [ "$op" = mcp-launchers-only ]; then
      printf '%s\n' 'Approve only the fixed MCP launcher destination set. The full toolkit installation receipt stays unchanged; a later full install remains required. Review the entire recorded receipt-to-target source range, including any stale or legacy baseline.'
    else
      printf '%s\n' "Approve this operation only if moving this host from the live installed SHA (whose installed manifest still names the stale manifest SHA) to this reviewed head is safe."
    fi
  fi
  printf '%s\n' "Examine the full target source and that operation. If, and only if, your verdict is APPROVE and you approve that operation, write this exact line on a line by itself before the Verdict heading:" "Approved $op." "If you do not approve that operation, do not write that line."
}
