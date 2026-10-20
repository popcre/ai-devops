# shellcheck shell=bash
# Owner: installer (#1783). The checkout lock is fd 9 and must reach the child
# installer, but never a process that can outlive the install. `op` starts a
# background `op daemon` that inherited fd 9 and kept the lock held after the
# install ended (hetz, 2026-10-20). Put an `op` shim first on PATH that closes
# fd 9 before running the real op, so every op call below the installer,
# however deep, starts its daemon without the lock.
install_lock_shim_op() { # install_lock_shim_op SHIM_DIR -> prepends SHIM_DIR to PATH
  local dir="$1"
  mkdir -p "$dir" || return 1
  cat > "$dir/op" <<'SHIM'
#!/bin/sh
# ai-devops installer shim: run the real op without the checkout lock (fd 9).
# Uses only shell builtins, and refuses to re-enter itself, so a PATH with
# no real op (or a second shim copy) ends with 127 instead of an exec loop.
[ -z "${AI_DEVOPS_OP_SHIM_ACTIVE:-}" ] || { echo "op: command not found" >&2; exit 127; }
AI_DEVOPS_OP_SHIM_ACTIVE=1; export AI_DEVOPS_OP_SHIM_ACTIVE
case "$0" in */*) self_dir=${0%/*} ;; *) self_dir=. ;; esac
self_dir=$(cd "$self_dir" 2>/dev/null && pwd -P)
IFS=:
for d in $PATH; do
  [ -n "$d" ] || continue
  [ "$(cd "$d" 2>/dev/null && pwd -P)" = "$self_dir" ] && continue
  if [ -x "$d/op" ] && [ ! -d "$d/op" ]; then unset AI_DEVOPS_OP_SHIM_ACTIVE; exec "$d/op" "$@" 9>&-; fi
done
echo "op: command not found" >&2
exit 127
SHIM
  chmod 700 "$dir/op" || return 1
  case ":$PATH:" in *":$dir:"*) ;; *) PATH="$dir:$PATH"; export PATH ;; esac
}
