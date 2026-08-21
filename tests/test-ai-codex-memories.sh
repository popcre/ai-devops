#!/usr/bin/env bash
# Offline tests for bin/ai-codex-memories. No real Codex is invoked; a stub on PATH
# stands in for it so the enable/verify contract can be tested deterministically.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-codex-memories"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/codexhome"
export CODEX_HOME="$TMP/codexhome"
printf '[features]\njs_repl = false\n' > "$CODEX_HOME/config.toml"

# Stub Codex: its flag state lives in a file so `enable` can flip it.
mk_stub() { # mk_stub <initial-state> <enable-succeeds:0|1>
  printf '%s' "$1" > "$TMP/state"
  cat > "$TMP/bin/codex" <<EOF
#!/usr/bin/env bash
if [ "\$1" = features ] && [ "\$2" = list ]; then
  s="\$(cat "$TMP/state")"
  [ "\$s" = missing ] && { echo "otherflag  stable  true"; exit 0; }
  echo "otherflag  stable  true"
  echo "memories   stable  \$s"
  exit 0
fi
if [ "\$1" = features ] && [ "\$2" = enable ] && [ "\$3" = memories ]; then
  [ "$2" = 1 ] || exit 1
  echo true > "$TMP/state"
  echo "Enabled feature \\\`memories\\\` in config.toml."
  exit 0
fi
exit 1
EOF
  chmod +x "$TMP/bin/codex"
}
run() { PATH="$TMP/bin:$PATH" bash "$SCRIPT" "$@" 2>&1; }

# --- already enabled ---------------------------------------------------------
mk_stub true 1
out="$(run)"; rc=$?
check "already enabled exits 0" "[ $rc -eq 0 ]"
check "already enabled says so" "printf '%s' \"\$out\" | grep -q 'already enabled'"
check "already enabled makes no backup" "[ -z \"\$(ls \"\$CODEX_HOME\"/config.toml.bak-* 2>/dev/null)\" ]"

# --- disabled, enable succeeds ----------------------------------------------
mk_stub false 1
out="$(run)"; rc=$?
check "enable exits 0" "[ $rc -eq 0 ]"
check "enable reports success" "printf '%s' \"\$out\" | grep -q 'OK Codex memories enabled'"
check "enable backs up config first" "ls \"\$CODEX_HOME\"/config.toml.bak-* >/dev/null 2>&1"
check "backup matches the original" "grep -q 'js_repl = false' \"\$(ls \"\$CODEX_HOME\"/config.toml.bak-* | head -1)\""

# --- --check never changes anything -----------------------------------------
rm -f "$CODEX_HOME"/config.toml.bak-*
mk_stub false 1
out="$(run --check)"; rc=$?
check "--check on disabled exits 1" "[ $rc -eq 1 ]"
check "--check does not enable" "[ \"\$(cat \"\$TMP/state\")\" = false ]"
check "--check makes no backup" "[ -z \"\$(ls \"\$CODEX_HOME\"/config.toml.bak-* 2>/dev/null)\" ]"
mk_stub true 1
run --check >/dev/null 2>&1; check "--check on enabled exits 0" "[ $? -eq 0 ]"

# --- enable fails ------------------------------------------------------------
mk_stub false 0
out="$(run)"; rc=$?
check "failed enable exits 1" "[ $rc -eq 1 ]"
check "failed enable is loud" "printf '%s' \"\$out\" | grep -q 'ERROR'"

# --- build without the flag --------------------------------------------------
mk_stub missing 1
out="$(run)"; rc=$?
check "missing feature flag exits 1" "[ $rc -eq 1 ]"
check "missing feature flag is loud" "printf '%s' \"\$out\" | grep -q 'does not expose'"

# --- no Codex installed ------------------------------------------------------
rm -f "$TMP/bin/codex"
out="$(PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP/nohome" USERPROFILE="$TMP/nohome" bash "$SCRIPT" 2>&1)"; rc=$?
check "no Codex exits 2" "[ $rc -eq 2 ]"
check "no Codex is informational, not an error" "printf '%s' \"\$out\" | grep -q 'not installed'"

# --- bad usage ---------------------------------------------------------------
run --nonsense >/dev/null 2>&1; check "unknown option exits 2" "[ $? -eq 2 ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
