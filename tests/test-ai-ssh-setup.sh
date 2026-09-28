#!/usr/bin/env bash
# Offline tests for bin/ai-ssh-setup (Linux 916-alien key + SSH alias install).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bin/ai-ssh-setup"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT

ok(){ PASS=$((PASS+1)); printf 'ok %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'not ok %s\n' "$1" >&2; }
check(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

command -v ssh-keygen >/dev/null 2>&1 || { echo "skip: ssh-keygen missing"; exit 0; }

# A throwaway key pair stands in for the 1Password item.
ssh-keygen -q -t ed25519 -N '' -C fixture -f "$TMP/fixture" >/dev/null
ssh-keygen -q -t ed25519 -N '' -C other -f "$TMP/other" >/dev/null

# Fake op: serves fixture files, records its argv, and proves stdin is closed.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/op" <<'OP'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_OP_LOG"
[ -t 0 ] && { echo "stdin open" >&2; exit 9; }
read -r -t 0 _ && true
[ "${1:-}" = read ] || exit 2
case "$2" in
  *"private key") [ -n "${FAKE_OP_FAIL:-}" ] && exit 1; cat "$FAKE_OP_PRIV" ;;
  *"public key")  cat "$FAKE_OP_PUB" ;;
  *) exit 1 ;;
esac
OP
chmod +x "$TMP/bin/op"

printf 'Host vps\n    HostName 100.66.37.58\nMatch host vps !exec "ping -c 1 -W 1 1.2.3.4 || ping.exe -n 1 -w 800 1.2.3.4"\n' > "$TMP/template"
printf 'Match host vps !exec "ping -n 1 -w 800 1.2.3.4"\n' > "$TMP/windows-template"

run(){ # home, extra env...
  local home="$1"; shift
  env HOME="$home" PATH="$TMP/bin:$PATH" FAKE_OP_LOG="$TMP/op.log" \
      FAKE_OP_PRIV="$TMP/fixture" FAKE_OP_PUB="$TMP/fixture.pub" \
      AI_SSH_SETUP_TEMPLATE="$TMP/template" "$@" "$TOOL"
}

# 1. Fresh install.
H="$TMP/h1"; mkdir -p "$H"
out="$(run "$H" 2>&1)"; rc=$?
check 'fresh install exits 0' test "$rc" -eq 0
check 'private key installed byte-identical' cmp -s "$TMP/fixture" "$H/.ssh/916-alien"
check 'private key mode 600' test "$(stat -c %a "$H/.ssh/916-alien")" = 600
check 'public key installed' cmp -s "$TMP/fixture.pub" "$H/.ssh/916-alien.pub"
check 'installed key parses' ssh-keygen -y -f "$H/.ssh/916-alien"
check 'alias template installed' cmp -s "$TMP/template" "$H/.ssh/ai-devops.conf"
check 'config created with Include' test "$(cat "$H/.ssh/config")" = 'Include ai-devops.conf'
check 'no secret printed' bash -c '! grep -q "PRIVATE KEY" <<<"$1"' _ "$out"
check 'op never given secret in argv' bash -c '! grep -q "PRIVATE KEY" "$1"' _ "$TMP/op.log"

# 2. Idempotent rerun changes nothing and leaves no backups.
before="$(ls -la --time-style=+%s%N "$H/.ssh" | md5sum)"
out="$(run "$H" 2>&1)"
check 'rerun reports current' grep -q 'already current' <<<"$out"
check 'rerun leaves files untouched' test "$before" = "$(ls -la --time-style=+%s%N "$H/.ssh" | md5sum)"

# 3. Existing ~/.ssh/config is preserved, Include moved first, no duplicates.
H="$TMP/h2"; mkdir -p "$H/.ssh"
printf 'Host mine\n    User me\n\nInclude ai-devops.conf\n' > "$H/.ssh/config"
run "$H" >/dev/null 2>&1
check 'Include is first line' test "$(head -n1 "$H/.ssh/config")" = 'Include ai-devops.conf'
check 'exactly one Include' test "$(grep -c 'ai-devops.conf' "$H/.ssh/config")" = 1
check 'user host block kept' grep -q '^Host mine$' "$H/.ssh/config"
check 'config backup kept' bash -c 'ls "$1"/.ssh/config.bak.* >/dev/null' _ "$H"

# 4. op unavailable: key step skipped, existing key untouched, aliases still installed.
H="$TMP/h3"; mkdir -p "$H/.ssh"; cp "$TMP/other" "$H/.ssh/916-alien"
# A PATH holding every system command except op.
mkdir -p "$TMP/noop-bin"
for d in /usr/local/bin /usr/bin /bin; do
  for f in "$d"/*; do n="${f##*/}"; [ "$n" = op ] || [ -e "$TMP/noop-bin/$n" ] || [ -L "$TMP/noop-bin/$n" ] || ln -s "$f" "$TMP/noop-bin/$n"; done
done
out="$(env HOME="$H" PATH="$TMP/noop-bin" AI_SSH_SETUP_TEMPLATE="$TMP/template" "$TOOL" 2>&1)"; rc=$?
check 'no op exits 0' test "$rc" -eq 0
check 'no op warns' grep -q 'op (1Password CLI) not found' <<<"$out"
check 'no op keeps existing key' cmp -s "$TMP/other" "$H/.ssh/916-alien"

# 5. op read fails: existing key untouched.
out="$(run "$H" FAKE_OP_FAIL=1 2>&1)"
check 'op failure keeps existing key' cmp -s "$TMP/other" "$H/.ssh/916-alien"

# 6. Garbage from op is never installed.
printf 'not a key\n' > "$TMP/garbage"
out="$(run "$H" FAKE_OP_PRIV="$TMP/garbage" 2>&1)"; rc=$?
check 'garbage key fails' test "$rc" -ne 0
check 'garbage key not installed' cmp -s "$TMP/other" "$H/.ssh/916-alien"

# 7. Mismatched public key is refused.
out="$(run "$H" FAKE_OP_PUB="$TMP/other.pub" 2>&1)"; rc=$?
check 'mismatched pub refused' test "$rc" -ne 0
check 'mismatched pub keeps key' cmp -s "$TMP/other" "$H/.ssh/916-alien"

# 8. Rotation keeps the previous key as a backup.
run "$H" >/dev/null 2>&1
check 'rotated key installed' cmp -s "$TMP/fixture" "$H/.ssh/916-alien"
check 'previous key backed up' bash -c 'cmp -s "$1" "$2"/.ssh/916-alien.bak.*' _ "$TMP/other" "$H"

# 9. Windows-only template is refused on Linux.
H="$TMP/h4"; mkdir -p "$H"
out="$(run "$H" AI_SSH_SETUP_TEMPLATE="$TMP/windows-template" 2>&1)"; rc=$?
check 'windows-only template refused' test "$rc" -ne 0
check 'windows-only template not installed' test ! -e "$H/.ssh/ai-devops.conf"

# 10. Dry run writes nothing.
H="$TMP/h5"; mkdir -p "$H"
env HOME="$H" PATH="$TMP/bin:$PATH" FAKE_OP_LOG="$TMP/op.log" FAKE_OP_PRIV="$TMP/fixture" \
  FAKE_OP_PUB="$TMP/fixture.pub" AI_SSH_SETUP_TEMPLATE="$TMP/template" "$TOOL" --dry-run >/dev/null 2>&1
check 'dry run writes nothing' test ! -e "$H/.ssh/916-alien" -a ! -e "$H/.ssh/config"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
