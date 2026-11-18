#!/usr/bin/env bash
# test-ai-claude-plugins.sh — unit tests for bin/ai-claude-plugins.
#
# Offline: runs the script against a throwaway CLAUDE_HOME with a stub `claude`
# that records its arguments and writes the two state files the real plugin
# manager writes.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-claude-plugins"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3' in: $2)" ;; esac; }

LIST="$TMP/list.tsv"
printf '# comment\n\nalpha\tmarket\towner/repo\r\nbeta\tmarket\towner/repo\n' > "$LIST"

# Stub plugin manager. STUB_FAIL=install makes `plugin install` fail.
STUB="$TMP/claude-stub"
cat > "$STUB" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CLAUDE_HOME/calls.log"
mkdir -p "$CLAUDE_HOME/plugins"
case "$1 $2" in
  "plugin marketplace")
    [ "${STUB_FAIL:-}" = "marketplace" ] && exit 1
    printf '{"market": {"source": "%s"}}\n' "$4" > "$CLAUDE_HOME/plugins/known_marketplaces.json" ;;
  "plugin install")
    [ "${STUB_FAIL:-}" = "install" ] && exit 1
    printf '"%s"\n' "$3" >> "$CLAUDE_HOME/plugins/installed_plugins.json" ;;
  *) exit 9 ;;
esac
STUB_EOF
chmod +x "$STUB"

run() { # run <home> [args...]
  CLAUDE_HOME="$1" AI_DEVOPS_CLAUDE_BIN="${BIN:-$STUB}" \
    AI_DEVOPS_CLAUDE_PLUGINS_FILE="${LIST_OVERRIDE:-$LIST}" "$SCRIPT" "${@:2}" 2>&1
}
calls() { [ -f "$1/calls.log" ] && wc -l < "$1/calls.log" | tr -d ' ' || echo 0; }

# 1. --check on a bare machine: exit 1, names what is missing, calls nothing.
H="$TMP/fresh"; mkdir -p "$H"
out="$(run "$H" --check)"; check "check bare: exit 1" "$?" "1"
has "check bare: names the plugin" "$out" "MISSING alpha@market"
check "check bare: plugin manager not called" "$(calls "$H")" "0"

# 2. Apply on a bare machine: one marketplace add, two installs.
out="$(run "$H")"; check "fresh: exit 0" "$?" "0"
has "fresh: reports both added" "$out" "ADDED 2, already present 0"
check "fresh: three plugin manager calls" "$(calls "$H")" "3"
check "fresh: marketplace added once from its source" \
  "$(grep -c '^plugin marketplace add owner/repo$' "$H/calls.log")" "1"
check "fresh: user-scope install (CR stripped from the list)" \
  "$(grep -c '^plugin install alpha@market --scope user$' "$H/calls.log")" "1"

# 3. Re-run is a no-op and --check now passes.
out="$(run "$H")"; check "rerun: exit 0" "$?" "0"
has "rerun: reports already present" "$out" "OK all 2 required Claude plugin(s) already present"
check "rerun: no further calls" "$(calls "$H")" "3"
out="$(run "$H" --check)"; check "check compliant: exit 0" "$?" "0"

# 4. A failed install is reported and exits 1; the other plugin still installs.
H2="$TMP/fail"; mkdir -p "$H2"
out="$(STUB_FAIL=install run "$H2")"; check "install failure: exit 1" "$?" "1"
has "install failure: says which plugin" "$out" "FAIL alpha@market"
has "install failure: summary" "$out" "FAILED 2, ADDED 0"

# 5. A marketplace that cannot be added fails without attempting the install.
H3="$TMP/nomarket"; mkdir -p "$H3"
out="$(STUB_FAIL=marketplace run "$H3")"; check "marketplace failure: exit 1" "$?" "1"
check "marketplace failure: install never attempted" \
  "$(grep -c '^plugin install' "$H3/calls.log")" "0"

# 6. No claude command on the machine: SKIP, exit 0.
H4="$TMP/nocli"; mkdir -p "$H4"
out="$(BIN="$TMP/does-not-exist" run "$H4")"; check "no cli: exit 0" "$?" "0"
has "no cli: reports SKIP" "$out" "SKIP alpha@market"

# 7. Malformed list line and unknown argument are usage errors.
BADLIST="$TMP/bad.tsv"; printf 'onlyname\n' > "$BADLIST"
out="$(LIST_OVERRIDE="$BADLIST" run "$H4")"; check "malformed line: exit 2" "$?" "2"
out="$(run "$H4" --bogus)"; check "unknown argument: exit 2" "$?" "2"

# 8. The shipped list parses and every line has three fields.
out="$(BIN="$TMP/does-not-exist" LIST_OVERRIDE="$REPO_ROOT/config/claude-plugins.tsv" run "$TMP/shipped" --check)"
rc=$?
check "shipped list: parses (missing on a bare home, exit 1)" "$rc" "1"
has "shipped list: carries the ScaleDown plugin" "$out" "MISSING slm-agent@scaledown"

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
