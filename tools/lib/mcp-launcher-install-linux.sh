# shellcheck shell=bash
# Fixed Linux launcher transaction. Source-only helper: no host work on load.
. "$REPO_ROOT/tools/lib/mcp-remote-render.sh"

mcp_linux_safe_dir() {
  local p="$1"
  while [ "$p" != / ]; do
    [ ! -L "$p" ] || return 1
    if [ -e "$p" ]; then
      [ -d "$p" ] && [ "$(stat -c %u "$p")" = "$(id -u)" ] || return 1
      [ $((8#$(stat -c %a "$p") & 0022)) -eq 0 ] || return 1
    fi
    p="$(dirname "$p")"
    [ "$p" != "$HOME" ] || break
  done
}

# Transaction engine takes explicit testable paths; the entry point below is
# the only installer caller and supplies the fixed destination set.
mcp_linux_write_pair() {
  local cfg="$1" txn="$2" launcher="$3" guard="$4" i name before now
  [ -d "$cfg" ] && [ -d "$txn" ] && [ ! -L "$cfg" ] && [ ! -L "$txn" ] || return 1
  for name in mcp-remote-launch.sh mcp-session-guard.mjs; do
    [ ! -L "$cfg/$name" ] && { [ ! -e "$cfg/$name" ] || [ -f "$cfg/$name" ]; } || return 1
  done
  if [ -f "$txn/journal.tsv" ]; then
    # Crash retry restores only bytes written by this exact transaction.
    while IFS=$'\t' read -r name before now; do
      case "$name" in mcp-remote-launch.sh|mcp-session-guard.mjs) ;; *) return 1 ;; esac
      i=missing; [ ! -f "$cfg/$name" ] || i="$(sha256sum "$cfg/$name" | cut -d' ' -f1)"
      [ "$i" = "$before" ] || [ "$i" = "$now" ] || return 1
    done < "$txn/journal.tsv"
    mcp_linux_rollback "$cfg" "$txn" || return 1
  fi
  for name in mcp-remote-launch.sh mcp-session-guard.mjs; do
    [ ! -e "$cfg/.$name.stage" ] && [ ! -L "$cfg/.$name.stage" ] || return 1
  done
  : > "$txn/journal.tsv"
  for name in mcp-remote-launch.sh mcp-session-guard.mjs; do
    i="$launcher"; [ "$name" != mcp-session-guard.mjs ] || i="$guard"
    cp -- "$i" "$txn/$name.new" && chmod 755 "$txn/$name.new" || return 1
    before=missing
    if [ -f "$cfg/$name" ]; then
      cp -p -- "$cfg/$name" "$txn/$name.old" || return 1
      before="$(sha256sum "$cfg/$name" | cut -d' ' -f1)"
    else rm -f -- "$txn/$name.old"; fi
    now="$(sha256sum "$i" | cut -d' ' -f1)"
    printf '%s\t%s\t%s\n' "$name" "$before" "$now" >> "$txn/journal.tsv"
  done
  chmod 600 "$txn/journal.tsv" || return 1
  for name in mcp-session-guard.mjs mcp-remote-launch.sh; do
    # Same-filesystem atomic replacement; nothing points at the candidate.
    cp -- "$txn/$name.new" "$cfg/.$name.stage" && chmod 755 "$cfg/.$name.stage" &&
      mv -- "$cfg/.$name.stage" "$cfg/$name" || return 1
  done
}

mcp_linux_rollback() {
  local cfg="$1" txn="$2" name before after current
  [ -f "$txn/journal.tsv" ] || return 0
  while IFS=$'\t' read -r name before after; do
    case "$name" in mcp-remote-launch.sh|mcp-session-guard.mjs) ;; *) return 1 ;; esac
    [ ! -L "$cfg/$name" ] || return 1
    [ ! -L "$cfg/.$name.stage" ] || return 1
    if [ -e "$cfg/.$name.stage" ]; then
      [ -f "$cfg/.$name.stage" ] &&
        [ "$(sha256sum "$cfg/.$name.stage" | cut -d' ' -f1)" = "$after" ] || return 1
      rm -- "$cfg/.$name.stage" || return 1
    fi
    current=missing; [ ! -f "$cfg/$name" ] || current="$(sha256sum "$cfg/$name" | cut -d' ' -f1)"
    [ "$current" = "$before" ] || [ "$current" = "$after" ] || return 1
    if [ "$before" = missing ]; then rm -f -- "$cfg/$name" || return 1
    else
      [ "$(sha256sum "$txn/$name.old" | cut -d' ' -f1)" = "$before" ] || return 1
      cp -p -- "$txn/$name.old" "$cfg/.$name.stage" && mv -- "$cfg/.$name.stage" "$cfg/$name" || return 1
    fi
    rm -f -- "$cfg/.$name.stage" || return 1
  done < "$txn/journal.tsv"
  rm -- "$txn/journal.tsv"
}

mcp_linux_install() (
  set -euo pipefail
  local installed="$1" target="$2" cfg="$HOME/.config/ai-devops" state txn node
  local TOKEN_FILE CFG_DIR NODE_BIN GUARD_JS inventory report
  [ "$target" = "$(git -C "$REPO_ROOT" rev-parse HEAD)" ] || return 1
  mcp_linux_safe_dir "$cfg" || { warn 'MCP destination directory is unsafe'; return 1; }
  [ -d "$cfg" ] || { warn 'MCP-only mode requires an existing managed profile'; return 1; }
  node="$(command -v node)"; [ -x "$node" ] || return 1
  state="${AI_TASK_GATES_DIR:-$HOME/.local/state/ai-devops/task-gates}"
  mcp_linux_safe_dir "$state" || return 1
  umask 077
  mkdir -p "$state/mcp-launcher-transactions"
  txn="$state/mcp-launcher-transactions/$target"
  [ ! -L "$txn" ] || return 1
  mkdir -p "$txn"; chmod 700 "$txn"
  exec 8>"$state/mcp-launcher.lock"; flock -n 8 || return 1
  if [ -e "$state/mcp-launcher-installs/$target.json" ]; then
    "$REPO_ROOT/bin/ai-task-gates" install-verify --mcp-launchers-only --phase preflight \
      --target-head "$target" --installed-checkout "$installed" --installed-launcher /usr/local/bin/ai-task-gates
    rm -f -- "$txn/journal.tsv"
    return 0
  fi
  # A crashed transaction must be restored before authority revalidation.
  mcp_linux_rollback "$cfg" "$txn" || return 1
  "$REPO_ROOT/bin/ai-task-gates" install-verify --mcp-launchers-only --phase preflight \
    --target-head "$target" --installed-checkout "$installed" --installed-launcher /usr/local/bin/ai-task-gates
  TOKEN_FILE="$cfg/op-service-account"; CFG_DIR="$cfg"; NODE_BIN="$node"; GUARD_JS="$cfg/mcp-session-guard.mjs"
  mcp_remote_render > "$txn/launcher"
  bash -n "$txn/launcher"
  mcp_linux_write_pair "$cfg" "$txn" "$txn/launcher" "$REPO_ROOT/bin/mcp-session-guard.mjs" || {
    mcp_linux_rollback "$cfg" "$txn"; return 1;
  }
  # Once the gate publishes a coherent receipt, preserve it even if cleanup
  # fails; the next invocation verifies and finishes one-use cleanup.
  trap 'if [ ! -f "$state/mcp-launcher-installs/$target.json" ]; then mcp_linux_rollback "$cfg" "$txn"; fi' EXIT
  cmp -s "$txn/launcher" "$cfg/mcp-remote-launch.sh"
  cmp -s "$REPO_ROOT/bin/mcp-session-guard.mjs" "$cfg/mcp-session-guard.mjs"
  "$REPO_ROOT/tests/test-mcp-remote-header-freshness.sh" >/dev/null
  "$REPO_ROOT/tests/test-mcp-session-guard.sh" >/dev/null
  # Read-only inventory/report helper is shared with the gate.
  ROOT="$REPO_ROOT"; SCRIPT_DIR="$REPO_ROOT/bin"
  . "$REPO_ROOT/tools/lib/mcp-launcher-install-gate.sh"
  inventory="$(mcp_install_inventory)"
  report="$txn/stage.json"
  jq -nc --arg h "$target" --arg p "$installed" --arg i "$inventory" \
    '{schema_version:1,scope:"mcp-launchers",target_head:$h,installed_checkout:$p,after_inventory:$i,synthetic_probe_pass:true}' > "$report"
  chmod 600 "$report"
  "$REPO_ROOT/bin/ai-task-gates" install-verify --mcp-launchers-only --phase finalize \
    --target-head "$target" --installed-checkout "$installed" --installed-launcher /usr/local/bin/ai-task-gates --stage-report "$report"
  trap - EXIT
  rm -- "$txn/journal.tsv"
  info 'MCP launcher partial install complete; full toolkit installation remains separate'
)
