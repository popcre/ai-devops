#!/usr/bin/env bash
# The installer's op shim must keep the checkout lock (fd 9) out of op and any
# daemon op leaves behind (#1783), while op still runs with its arguments.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/install-lock-shim.XXXXXX")"
trap 'kill $(cat "$TMP/daemon.pid" 2>/dev/null) 2>/dev/null || true; rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { if eval "$2"; then pass=$((pass+1)); printf '  ok   %s\n' "$1"; else fail=$((fail+1)); printf '  FAIL %s\n' "$1"; fi; }

mkdir -p "$TMP/real"
cat > "$TMP/real/op" <<EOS
#!/usr/bin/env bash
# fake op: record args and fd 9, leave a long-lived "daemon" behind
printf '%s\n' "\$*" > "$TMP/args"
[ -e /proc/\$\$/fd/9 ] && echo open > "$TMP/op-fd9" || echo closed > "$TMP/op-fd9"
( exec sleep 30 ) &
echo \$! > "$TMP/daemon.pid"
EOS
chmod +x "$TMP/real/op"

OLD_PATH="$PATH"
exec 9>"$TMP/lock"
PATH="$TMP/real:$PATH"
source "$ROOT/tools/lib/install-lock-shim.sh"
install_lock_shim_op "$TMP/shim"
check 'shim is first on PATH' '[ "$(command -v op)" = "$TMP/shim/op" ]'
op read "op://vault/item/field"
install_lock_shim_op "$TMP/shim"
check 'repeat call does not duplicate PATH entry' '[ "$(printf "%s" "$PATH" | tr : "\n" | grep -c "^$TMP/shim$")" = 1 ]'
exec 9>&-
PATH="$OLD_PATH"
check 'real op received the arguments' '[ "$(cat "$TMP/args")" = "read op://vault/item/field" ]'
check 'op ran without the lock fd' '[ "$(cat "$TMP/op-fd9")" = closed ]'
pid="$(cat "$TMP/daemon.pid")"
check 'leftover daemon does not hold the lock fd' '! ls -l /proc/$pid/fd 2>/dev/null | grep -q "$TMP/lock"'
check 'lock is free once the installer shell exits' 'flock -n "$TMP/lock" true'

mkdir -p "$TMP/empty"
install_lock_shim_op "$TMP/shim2"
set +e; PATH="$TMP/shim2:$TMP/empty" "$TMP/shim2/op" >/dev/null 2>&1; rc=$?; set -e
check 'missing real op is reported, not looped' '[ "$rc" = 127 ]'
printf 'install-lock-shim: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
