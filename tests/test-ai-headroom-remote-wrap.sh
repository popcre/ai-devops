#!/usr/bin/env bash
# Offline checks for ai-headroom's Claude remote-worker wrapper.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bin/ai-headroom"
TMP="${TMPDIR:-/tmp}/ai-headroom-remote-wrap-$$"
mkdir -p "$TMP/ccd" "$TMP/home"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>"$TMP/check.err"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name"; cat "$TMP/check.err" >&2
    exit 1
  fi
}

check 'tool is executable' test -x "$TOOL"
check 'cmd launcher exists' test -f "$ROOT/bin/ai-headroom.cmd"

# Fake "ELF" payload: is_elf only reads the first four bytes.
make_elf() {
  printf '\x7fELF' > "$1"
  dd if=/dev/zero bs=1 count=32 >>"$1" 2>/dev/null
  chmod +x "$1"
}

make_elf "$TMP/ccd/2.1.299-deadbeef"
make_elf "$TMP/ccd/2.1.300-cafebabe"

export AI_HEADROOM_CCD_DIR="$TMP/ccd"
export AI_HEADROOM_PROXY_URL="http://127.0.0.1:9/health-parent"
export HOME="$TMP/home"
# A fake systemctl, so unwrap-remote never touches this host's real user units.
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/systemctl" <<EOF
#!/usr/bin/env bash
printf '%s
' "\$*" >> "$TMP/systemctl.log"
# is-active succeeds only for a unit named in FAKE_ACTIVE, so tests can hold a unit "running".
# show -p ActiveState reports FAKE_STATE for a unit named in FAKE_ACTIVE, else inactive.
if [ "\$2" = show ]; then
  [ -z "\${FAKE_SHOW_FAIL:-}" ] || exit 1
  case " \${FAKE_ACTIVE:-} " in *" \${6} "*) echo "\${FAKE_STATE:-activating}";; *) echo inactive;; esac; exit 0
fi
exit 0
EOF
chmod +x "$TMP/fakebin/systemctl"; export PATH="$TMP/fakebin:$PATH"
# Installed auto-rewrap units, so unwrap-remote has a timer to stop.
arm() { mkdir -p "$HOME/.config/systemd/user"; : > "$HOME/.config/systemd/user/ai-headroom-autowrap.timer"; }

"$TOOL" wrap-remote >"$TMP/wrap.out"
check 'wrap moves first binary aside' test -f "$TMP/ccd/2.1.299-deadbeef.headroom-real"
check 'wrap moves second binary aside' test -f "$TMP/ccd/2.1.300-cafebabe.headroom-real"
check 'wrapper installed' grep -q 'Managed by ai-headroom' "$TMP/ccd/2.1.299-deadbeef"
check 'wrapper bakes proxy URL' grep -q "ANTHROPIC_BASE_URL='http://127.0.0.1:9/health-parent'" "$TMP/ccd/2.1.299-deadbeef"
check 'wrapper is executable' test -x "$TMP/ccd/2.1.299-deadbeef"
check 'status reports wrapped' bash -c "\"$TOOL\" status | grep -q 'wrapped -> Headroom'"

# The wrapper must exec the real binary with the forced URL.
# Swap in a stub "real", run it, then put the ELF back so unwrap checks stay honest.
cp "$TMP/ccd/2.1.299-deadbeef.headroom-real" "$TMP/elf.bak"
cat > "$TMP/ccd/2.1.299-deadbeef.headroom-real" <<EOF
#!/usr/bin/env bash
printf 'REAL_RAN url=%s args=%s\n' "\${ANTHROPIC_BASE_URL:-}" "\$*"
EOF
chmod +x "$TMP/ccd/2.1.299-deadbeef.headroom-real"
out="$("$TMP/ccd/2.1.299-deadbeef" --version)"
cp "$TMP/elf.bak" "$TMP/ccd/2.1.299-deadbeef.headroom-real"
chmod +x "$TMP/ccd/2.1.299-deadbeef.headroom-real"
check 'wrapper forces proxy URL' bash -c "printf '%s' '$out' | grep -q 'url=http://127.0.0.1:9/health-parent'"
check 'wrapper execs real binary' bash -c "printf '%s' '$out' | grep -q 'args=--version'"

# A Claude update drops a new unwrapped version next to the old ones.
make_elf "$TMP/ccd/2.1.301-f00dface"
"$TOOL" status >"$TMP/status.out"
check 'status flags a new raw binary' grep -q 'still DIRECT' "$TMP/status.out"
"$TOOL" wrap-remote >/dev/null
check 're-wrap covers the new version' test -f "$TMP/ccd/2.1.301-f00dface.headroom-real"
check 'status clean after re-wrap' bash -c "\"$TOOL\" status | grep -q 'wrapped -> Headroom'"

# Re-wrap updates the baked URL without duplicating the real binary.
export AI_HEADROOM_PROXY_URL="http://127.0.0.1:9/other"
"$TOOL" wrap-remote >/dev/null
check 're-wrap updates URL' grep -q "ANTHROPIC_BASE_URL='http://127.0.0.1:9/other'" "$TMP/ccd/2.1.299-deadbeef"
check 're-wrap keeps one real binary' bash -c "[ ! -e '$TMP/ccd/2.1.299-deadbeef.headroom-real.headroom-real' ]"

arm; "$TOOL" unwrap-remote >/dev/null
check 'unwrap restores raw binary' bash -c "dd if='$TMP/ccd/2.1.299-deadbeef' bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \\n' | grep -q 7f454c46"
check 'unwrap removes wrapper' bash -c "! grep -q 'Managed by ai-headroom' '$TMP/ccd/2.1.299-deadbeef'"
check 'unwrap removes real sidecar' bash -c "! test -e '$TMP/ccd/2.1.299-deadbeef.headroom-real'"
if [ -f "$TMP/systemctl.log" ]; then  # Linux only: Windows skips the timer entirely
  check 'unwrap disables the auto-rewrap timer' grep -q 'disable --now ai-headroom-autowrap.timer' "$TMP/systemctl.log"
  check 'unwrap waits for a running rewrap instead of killing it' bash -c "grep -q 'show -p ActiveState --value ai-headroom-autowrap.service' '$TMP/systemctl.log' && ! grep -q '^--user stop' '$TMP/systemctl.log'"
fi

# A rewrap that will not finish, or a timer that will not stop, blocks the unwrap (Linux only).
if [ -f "$TMP/systemctl.log" ]; then
  "$TOOL" wrap-remote >/dev/null
  arm; check 'stuck rewrap service refuses the unwrap' bash -c "! FAKE_ACTIVE=ai-headroom-autowrap.service AI_HEADROOM_AUTOWRAP_WAIT=1 '$TOOL' unwrap-remote >/dev/null 2>&1"
  check 'refused unwrap leaves the wrapper intact' test -f "$TMP/ccd/2.1.299-deadbeef.headroom-real"
  arm; check 'active timer refuses the unwrap' bash -c "! FAKE_ACTIVE=ai-headroom-autowrap.timer '$TOOL' unwrap-remote >/dev/null 2>&1"
  arm; check 'an unreadable unit state refuses the unwrap' bash -c "! FAKE_SHOW_FAIL=1 '$TOOL' unwrap-remote >/dev/null 2>&1"
  arm; "$TOOL" unwrap-remote >/dev/null
fi

# Claude Desktop layout: <ver>/<hash>/claude, wrapped only once .verified exists.
D="$TMP/desktop"
mkdir -p "$D/2.1.304/abc" "$D/2.1.305/def"
make_elf "$D/2.1.304/abc/claude"; : > "$D/2.1.304/abc/.verified"
make_elf "$D/2.1.305/def/claude"   # still downloading: no .verified
export AI_HEADROOM_DESKTOP_CC_DIR="$D"
"$TOOL" wrap-remote >/dev/null
check 'desktop binary wrapped' grep -q 'Managed by ai-headroom' "$D/2.1.304/abc/claude"
check 'desktop real binary kept' test -f "$D/2.1.304/abc/claude.headroom-real"
check 'unverified download untouched' bash -c "! test -e '$D/2.1.305/def/claude.headroom-real'"
arm; "$TOOL" unwrap-remote >/dev/null
check 'desktop unwrap restores binary' bash -c "! test -e '$D/2.1.304/abc/claude.headroom-real'"

printf 'ok - all ai-headroom remote-wrap checks\n'
