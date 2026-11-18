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
    [ "$3" = add ] && [ "$4" = owner/repo ] || exit 9
    printf '{"market":{"source":{"source":"github","repo":"owner/repo"}}}\n' \
      > "$CLAUDE_HOME/plugins/known_marketplaces.json" ;;
  "plugin install")
    [ "${STUB_FAIL:-}" = "install" ] && exit 1
    [ "$4" = --scope ] && [ "$5" = user ] || exit 9
    installed="$CLAUDE_HOME/plugins/installed_plugins.json"
    [ -f "$installed" ] || printf '{"version":2,"plugins":{}}\n' > "$installed"
    jq --arg id "$3" '.plugins[$id] += [{scope:"user",installPath:"/cache/plugin",version:"1.0"}]' \
      "$installed" > "$installed.tmp" && mv "$installed.tmp" "$installed" ;;
  *) exit 9 ;;
esac
STUB_EOF
chmod +x "$STUB"

run() { # run <home> [args...]
  CLAUDE_HOME="$1" AI_DEVOPS_CLAUDE_BIN="${BIN:-$STUB}" \
    AI_DEVOPS_CLAUDE_PLUGINS_FILE="${LIST_OVERRIDE:-$LIST}" "$SCRIPT" "${@:2}" 2>&1
}
new_home() { mkdir -p "$1/plugins" && : > "$1/calls.log"; }
calls() { wc -l < "$1/calls.log" | tr -d ' '; }

# 1. --check on a bare machine: exit 1, names what is missing, calls nothing.
H="$TMP/fresh"; new_home "$H"
out="$(run "$H" --check)"; check "check bare: exit 1" "$?" "1"
has "check bare: names the plugin" "$out" "MISSING alpha@market"
check "check bare: plugin manager not called" "$(calls "$H")" "0"

# 2. Apply on a bare machine: one marketplace add, two installs.
out="$(run "$H")"; check "fresh: exit 0" "$?" "0"
has "fresh: reports both added" "$out" "ADDED 2, already present 0"
check "fresh: three plugin manager calls" "$(calls "$H")" "3"
check "fresh: marketplace added once with the CR stripped from its source" \
  "$(grep -c '^plugin marketplace add owner/repo$' "$H/calls.log")" "1"
check "fresh: user-scope install" \
  "$(grep -c '^plugin install alpha@market --scope user$' "$H/calls.log")" "1"

# 3. Re-run is a no-op and --check now passes.
out="$(run "$H")"; check "rerun: exit 0" "$?" "0"
has "rerun: reports already present" "$out" "OK all 2 required Claude plugin(s) already present"
check "rerun: no further calls" "$(calls "$H")" "3"
out="$(run "$H" --check)"; check "check compliant: exit 0" "$?" "0"

# 4. Failed installs are reported and exit 1.
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
out="$(run "$H4" --help)"; check "help: exit 0" "$?" "0"
check "help: complete exit-code contract" "${out##*$'\n'}" '# 2 usage or malformed list.'

# An empty or comment-only list is malformed in both modes.
EMPTY="$TMP/empty.tsv"; : > "$EMPTY"
COMMENTS="$TMP/comments.tsv"; printf '# comment\r\n\r\n' > "$COMMENTS"
for file in "$EMPTY" "$COMMENTS"; do
  for mode in --check ''; do
    label="${file##*/} ${mode:-apply}"
    args=(); [[ -z "$mode" ]] || args+=("$mode")
    out="$(LIST_OVERRIDE="$file" run "$H" "${args[@]}")"
    check "$label: exit 2" "$?" "2"
    has "$label: names the empty list" "$out" "no required plugins listed"
  done
done
check "empty lists: no further calls" "$(calls "$H")" "3"

# 8. The shipped list parses and every line has three fields.
out="$(BIN="$TMP/does-not-exist" LIST_OVERRIDE="$REPO_ROOT/config/claude-plugins.tsv" run "$TMP/shipped" --check)"
rc=$?
check "shipped list: parses (missing on a bare home, exit 1)" "$rc" "1"
has "shipped list: carries the ScaleDown plugin" "$out" "MISSING slm-agent@scaledown"

# 9. A local install and strings outside the expected keys do not count.
H5="$TMP/scoped"; new_home "$H5"
cat > "$H5/plugins/installed_plugins.json" <<'JSON'
{
  "version": 2,
  "plugins": {
    "alpha@market": [{"scope":"local","projectPath":"/projects/demo","installPath":"/cache/alpha"}],
    "other@elsewhere": [{"scope":"user","installPath":"beta@market"}]
  }
}
JSON
printf '{"unrelated":{"installLocation":"market"}}\n' > "$H5/plugins/known_marketplaces.json"
out="$(run "$H5" --check)"; check "scoped: exit 1" "$?" "1"
has "scoped: local entry counts as missing" "$out" "MISSING alpha@market"
has "scoped: unrelated plugin string counts as missing" "$out" "MISSING beta@market"
check "scoped check: no calls" "$(calls "$H5")" "0"
out="$(run "$H5")"; check "scoped apply: exit 0" "$?" "0"
check "scoped apply: adds marketplace and both user installs" "$(calls "$H5")" "3"
out="$(run "$H5" --check)"; check "scoped recheck: exit 0" "$?" "0"

# 10. An explicitly disabled user installation is reported but left alone.
printf '{"enabledPlugins":{"alpha@market":false,"beta@market":true}}\n' > "$H5/settings.json"
out="$(run "$H5" --check)"; check "disabled check: exit 1" "$?" "1"
has "disabled check: explains why alpha is missing" "$out" "MISSING alpha@market (disabled in user settings)"
out="$(run "$H5")"; check "disabled apply: exit 1" "$?" "1"
has "disabled apply: reports the disabled plugin" "$out" "FAIL alpha@market (disabled in user settings)"
check "disabled apply: no further calls" "$(calls "$H5")" "3"

# 11. Broken JSON must not trigger installation.
printf '{' > "$H5/plugins/installed_plugins.json"
out="$(run "$H5")"; check "broken install state: exit 1" "$?" "1"
has "broken install state: identifies the file" "$out" "could not read $H5/plugins/installed_plugins.json"
check "broken install state: no further calls" "$(calls "$H5")" "3"

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
