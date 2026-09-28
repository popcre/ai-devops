#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-muse"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
result(){
  if [ "$1" = pass ]; then PASS=$((PASS + 1)); printf '  ok   %s\n' "$2"
  else FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$2" >&2; fi
}

# Exercise only the credential-lock functions; the full Muse suite covers
# provider sessions and end-to-end key refresh separately.
FUNCS="$(sed -n '/^muse_os_profile_home(){/,/^}/p' "$SCRIPT")
$(sed -n '/^muse_credential_owner_alive(){/,/^read_key_from_op(){/{ /^read_key_from_op(){/d; p; }' "$SCRIPT")"
if [ -z "${SYSTEMROOT:-}" ] && [ -x /usr/bin/getent ]; then
  expected="$(/usr/bin/getent passwd "$(/usr/bin/id -u)" | cut -d: -f6)/.local/state/ai-devops/muse"
  actual="$(HOME="$TMP/hostile-home" USERPROFILE="$TMP/hostile-profile" AI_MUSE_STATE_DIR="$TMP/hostile-state" AI_MUSE_TEST_DIR='' SYSTEMROOT='' STATE="$TMP/hostile-state" bash -c 'source /dev/stdin; muse_credential_state' <<< "$FUNCS")"
  if [ "$actual" = "$expected" ]; then result pass 'production lock stays in the OS account profile'; else result fail 'production lock stays in the OS account profile'; fi
  mkdir -p "$TMP/account-home/.config/ai-devops"
  printf 'synthetic-token' > "$TMP/account-home/.config/ai-devops/op-service-account"
  chmod 600 "$TMP/account-home/.config/ai-devops/op-service-account"
  expected_flock="$TMP/account-home/.config/ai-devops/op-refresh.lock"
  if ( source /dev/stdin; source <(sed -n '/^read_key_from_op(){/,/^}/p' "$SCRIPT"); muse_os_profile_home(){ printf '%s\n' "$TMP/account-home"; }; linked_below_home(){ return 1; }; need(){ :; }; flock(){ printf '%s\n' "$4" > "$TMP/observed-flock"; [ "$OP_SERVICE_ACCOUNT_TOKEN" = synthetic-token ] || return 1; printf 'fake-key\n'; }; KEY_HOME="$TMP/account-home" AI_MUSE_TEST_DIR='' SYSTEMROOT='' STATE="$TMP/hostile-state" AI_MUSE_CREDENTIAL_WAIT_SECONDS=2; read_key_from_op && [ "$MODEL_API_KEY" = fake-key ] && [ "$(cat "$TMP/observed-flock")" = "$expected_flock" ] ) <<< "$FUNCS" >/dev/null 2>&1; then
    result pass 'Linux Muse refresh uses the shared account flock'
  else result fail 'Linux Muse refresh uses the shared account flock'; fi
  rm -f "$TMP/account-home/.config/ai-devops/op-service-account" "$TMP/op-without-token"
  if ( source /dev/stdin; source <(sed -n '/^read_key_from_op(){/,/^}/p' "$SCRIPT"); muse_os_profile_home(){ printf '%s\n' "$TMP/account-home"; }; linked_below_home(){ return 1; }; need(){ :; }; die(){ exit 1; }; flock(){ touch "$TMP/op-without-token"; }; KEY_HOME="$TMP/account-home" OP_SERVICE_ACCOUNT_TOKEN='untrusted-ambient-token' AI_MUSE_TEST_DIR='' SYSTEMROOT='' STATE="$TMP/hostile-state"; ! ( read_key_from_op ) && [ ! -e "$TMP/op-without-token" ] ) <<< "$FUNCS" >/dev/null 2>&1; then
    result pass 'production refresh refuses an ambient token without the protected file'
  else result fail 'production refresh refuses an ambient token without the protected file'; fi
fi

if ( source /dev/stdin; muse_credential_winpid_for(){ [ "$1" = "$EXPECTED_HOLDER" ] || return 1; printf 43210; }; EXPECTED_HOLDER="$BASHPID"; CRED_LOCK=''; CRED_TOKEN=''; muse_credential_publish "$TMP/published" && read -r owner winpid token < "$TMP/published/owner" && [ "$owner" = "$EXPECTED_HOLDER" ] && [ "$winpid" = 43210 ] && [ "$token" = "$CRED_TOKEN" ] ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'published lock identifies the holding shell and Windows process'
else result fail 'published lock identifies the holding shell and Windows process'; fi

mkdir -p "$TMP/bin" "$TMP/live-lock" "$TMP/legacy-lock"
cat > "$TMP/bin/ps" <<'EOF'
#!/usr/bin/env bash
[ "${PS_STUB_LIVE:-0}" = 1 ] && printf 'a b c 43210\n'
EOF
chmod +x "$TMP/bin/ps"
printf '%s\n' '999999 43210 live-token' > "$TMP/live-lock/owner"
if ( export SYSTEMROOT='C:\Windows' PS_STUB_LIVE=1 PATH="$TMP/bin:$PATH"; source /dev/stdin; CRED_LOCK=''; CRED_TOKEN=''; ! muse_credential_acquire "$TMP/live-lock" && [ "$(cat "$TMP/live-lock/owner")" = '999999 43210 live-token' ] ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'a live sibling Windows runtime keeps its lock'
else result fail 'a live sibling Windows runtime keeps its lock'; fi
if ( export SYSTEMROOT='C:\Windows' PS_STUB_LIVE=0 PATH="$TMP/bin:$PATH"; source /dev/stdin; CRED_LOCK=''; CRED_TOKEN=''; muse_credential_acquire "$TMP/live-lock" && [ -n "$CRED_TOKEN" ] && [ -d "$TMP/live-lock.dead.live-token" ] ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'a dead witnessed Windows owner can be reclaimed'
else result fail 'a dead witnessed Windows owner can be reclaimed'; fi
printf '%s\n' 999999 > "$TMP/legacy-lock/pid"
if ( export SYSTEMROOT='C:\Windows' PS_STUB_LIVE=0 PATH="$TMP/bin:$PATH"; source /dev/stdin; CRED_LOCK=''; CRED_TOKEN=''; ! muse_credential_acquire "$TMP/legacy-lock" && [ -f "$TMP/legacy-lock/pid" ] ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'a legacy Windows pid-only lock fails closed'
else result fail 'a legacy Windows pid-only lock fails closed'; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
