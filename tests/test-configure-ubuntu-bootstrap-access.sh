#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bin/configure-ubuntu-bootstrap-access.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT

ok(){ PASS=$((PASS+1)); printf 'ok %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'not ok %s\n' "$1" >&2; }

KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureBootstrapKeyForTestsOnly fixture@ai-devops'

make_scenario(){
  local dir="$1"
  mkdir -p "$dir/bin" "$dir/state" "$dir/home"
  : > "$dir/log"

  cat > "$dir/bin/id" <<'EOF'
#!/usr/bin/env bash
printf 'id %s\n' "$*" >> "$SHIM_LOG"
case "$*" in *-u*) printf '%s\n' "${ID_UID:-0}" ;; *-g*) printf '1000\n' ;; esac
EOF

  cat > "$dir/bin/getent" <<'EOF'
#!/usr/bin/env bash
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
printf 'tester:x:1000:1000::%s:/bin/bash\n' "$FAKE_HOME"
EOF

  cat > "$dir/bin/dpkg" <<'EOF'
#!/usr/bin/env bash
printf 'dpkg %s\n' "$*" >> "$SHIM_LOG"
case "$*" in *-s*) [ -f "$SHIM_STATE/package" ] ;; *) exit 0 ;; esac
EOF

  cat > "$dir/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >> "$SHIM_LOG"
case "$*" in *install*) : > "$SHIM_STATE/package" ;; esac
exit 0
EOF

  cat > "$dir/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$SHIM_LOG"
case "$1" in
  is-active) [ -f "$SHIM_STATE/service" ] ;;
  enable) : > "$SHIM_STATE/service" ;;
  *) exit 0 ;;
esac
EOF

  cat > "$dir/bin/ip" <<'EOF'
#!/usr/bin/env bash
printf 'ip %s\n' "$*" >> "$SHIM_LOG"
[ "${FAKE_TAILSCALE:-0}" = 1 ]
EOF

  cat > "$dir/bin/ufw" <<'EOF'
#!/usr/bin/env bash
printf 'ufw %s\n' "$*" >> "$SHIM_LOG"
case "$1" in
  status)
    if [ "${FAKE_UFW:-inactive}" != active ]; then printf 'Status: inactive\n'; exit 0; fi
    printf 'Status: active\n\nTo                         Action      From\n--                         ------      ----\n'
    [ -f "$SHIM_STATE/ufw-tailscale" ] && printf '22/tcp on tailscale0       ALLOW IN    Anywhere\n'
    [ -f "$SHIM_STATE/ufw-any" ] && printf '22/tcp                      ALLOW IN    Anywhere\n'
    exit 0 ;;
  allow)
    case "$*" in *tailscale0*) : > "$SHIM_STATE/ufw-tailscale" ;; *) : > "$SHIM_STATE/ufw-any" ;; esac
    exit 0 ;;
  *) exit 0 ;;
esac
EOF

  cat > "$dir/bin/install" <<'EOF'
#!/usr/bin/env bash
printf 'install %s\n' "$*" >> "$SHIM_LOG"
target=''
while [ $# -gt 0 ]; do
  case "$1" in
    -d) shift ;;
    -m|-o|-g) shift 2 ;;
    -*) shift ;;
    *) target="$1"; shift ;;
  esac
done
[ -n "$target" ] && mkdir -p "$target"
exit 0
EOF

  cat > "$dir/bin/chown" <<'EOF'
#!/usr/bin/env bash
printf 'chown %s\n' "$*" >> "$SHIM_LOG"
exit 0
EOF

  chmod +x "$dir"/bin/*
}

run_scenario(){
  local dir="$1"; shift
  PATH="$dir/bin:$PATH" SHIM_LOG="$dir/log" SHIM_STATE="$dir/state" \
    FAKE_HOME="$dir/home" FAKE_UFW="${FAKE_UFW_OVERRIDE:-inactive}" \
    FAKE_TAILSCALE="${FAKE_TAILSCALE_OVERRIDE:-0}" \
    SUDO_USER="${SUDO_USER_OVERRIDE-tester}" ID_UID="${ID_UID_OVERRIDE:-0}" \
    "$TOOL" "$@"
}

printf '%s\n' "$KEY" > "$TMP/bootstrap_key.pub"

# 1. Non-root invocation is refused before any command runs.
d="$TMP/s1"; make_scenario "$d"
out="$(ID_UID_OVERRIDE=1000 run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" 2>&1)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'run with sudo'; then
  ok 'non-root invocation is refused with a sudo hint'
else
  bad "non-root invocation is refused with a sudo hint (rc=$rc)"
fi

# 2. Full apply on a bare machine: installs, starts, keys, firewall (Tailscale).
d="$TMP/s2"; make_scenario "$d"
FAKE_UFW_OVERRIDE=active FAKE_TAILSCALE_OVERRIDE=1 \
  run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
auth="$d/home/.ssh/authorized_keys"
if [ "$rc" -eq 0 ]; then ok 'full apply exits 0'; else bad "full apply exits 0 (rc=$rc)"; fi
[ "$(grep -cxF "$KEY" "$auth" 2>/dev/null)" = 1 ] && ok 'bootstrap key written exactly once' || bad 'bootstrap key written exactly once'
grep -q '^apt-get install .*openssh-server' "$d/log" && ok 'openssh-server installed when absent' || bad 'openssh-server installed when absent'
grep -q '^systemctl enable --now ssh' "$d/log" && ok 'ssh service enabled and started' || bad 'ssh service enabled and started'
grep -q '^ufw allow in on tailscale0 to any port 22' "$d/log" && ok 'firewall opened on tailscale0 when present' || bad 'firewall opened on tailscale0 when present'
[ -f "$d/state/ufw-tailscale" ] && ok 'tailscale firewall rule recorded' || bad 'tailscale firewall rule recorded'

# 3. Idempotent second run: no duplicate key, no repeated firewall allow.
d="$TMP/s2"
run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then ok 'second run exits 0'; else bad "second run exits 0 (rc=$rc)"; fi
[ "$(grep -cxF "$KEY" "$auth")" = 1 ] && ok 'second run does not duplicate the key' || bad 'second run does not duplicate the key'
allow_count="$(grep -c '^ufw allow ' "$d/log")"
[ "$allow_count" = 1 ] && ok 'second run does not repeat the firewall rule' || bad "second run does not repeat the firewall rule (count=$allow_count)"

# 4. Test-only on a bare machine reports MISSING and changes nothing.
d="$TMP/s4"; make_scenario "$d"
FAKE_UFW_OVERRIDE=active FAKE_TAILSCALE_OVERRIDE=1 \
  run_scenario "$d" --test-only --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then ok 'test-only on a bare machine exits 2'; else bad "test-only on a bare machine exits 2 (rc=$rc)"; fi
[ ! -f "$d/state/package" ] && [ ! -f "$d/state/service" ] && [ ! -f "$d/state/ufw-tailscale" ] \
  && [ ! -e "$d/home/.ssh" ] \
  && ok 'test-only applies no machine change' || bad 'test-only applies no machine change'

# 5. Active ufw without tailscale0 falls back to plain port 22.
d="$TMP/s5"; make_scenario "$d"
FAKE_UFW_OVERRIDE=active FAKE_TAILSCALE_OVERRIDE=0 \
  run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then ok 'plain-ufw apply exits 0'; else bad "plain-ufw apply exits 0 (rc=$rc)"; fi
grep -q '^ufw allow 22/tcp' "$d/log" && ! grep -q '^ufw allow in on tailscale0' "$d/log" \
  && ok 'firewall opened for plain 22/tcp without tailscale0' || bad 'firewall opened for plain 22/tcp without tailscale0'

# 6. Inactive ufw: no firewall rule is attempted.
d="$TMP/s6"; make_scenario "$d"
FAKE_UFW_OVERRIDE=inactive run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then ok 'inactive-ufw apply exits 0'; else bad "inactive-ufw apply exits 0 (rc=$rc)"; fi
grep -q '^ufw allow ' "$d/log" && bad 'inactive ufw triggers no allow rule' || ok 'inactive ufw triggers no allow rule'

# 7. Missing public key file fails closed.
d="$TMP/s7"; make_scenario "$d"
run_scenario "$d" --public-key-file "$TMP/does-not-exist" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok 'missing public key file exits 1' || bad "missing public key file exits 1 (rc=$rc)"

# 8. Root without SUDO_USER fails closed.
d="$TMP/s8"; make_scenario "$d"
SUDO_USER_OVERRIDE='' run_scenario "$d" --public-key-file "$TMP/bootstrap_key.pub" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok 'empty SUDO_USER exits 1' || bad "empty SUDO_USER exits 1 (rc=$rc)"

printf '%s\n' "Passed: $PASS" "Failed: $FAIL"
[ "$FAIL" -eq 0 ]
