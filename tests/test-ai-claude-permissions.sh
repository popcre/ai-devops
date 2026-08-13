#!/usr/bin/env bash
# test-ai-claude-permissions.sh — unit tests for bin/ai-claude-permissions.
#
# Runs the script against a throwaway CLAUDE_HOME, once per available JSON
# runtime (python and node take separate code paths, so both must be proven).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-claude-permissions"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# A fixed allow list, so the test does not change when the real one does.
ALLOW="$TMP/allow"
printf '# comment\n\nalpha_tool\nbeta_tool\n' > "$ALLOW"

run() { # run <home> [args...]
  CLAUDE_HOME="$1" AI_DEVOPS_JSON_RUNTIME="$RUNTIME" \
    AI_DEVOPS_PERMISSIONS_FILE="$ALLOW" "$SCRIPT" "${@:2}" 2>&1
}

test_runtime() {
  RUNTIME="$1"
  echo "== runtime: $RUNTIME =="

  # 1. No settings file at all -> creates one with the whole block.
  H="$TMP/$RUNTIME-fresh"; mkdir -p "$H"
  out="$(run "$H")"; rc=$?
  check "fresh: exit 0" "$rc" "0"
  case "$out" in *"ADDED 2"*) ok "fresh: added 2" ;; *) bad "fresh: added 2 ($out)" ;; esac
  grep -q '"alpha_tool"' "$H/settings.json" && grep -q '"beta_tool"' "$H/settings.json" \
    && ok "fresh: both entries written" || bad "fresh: both entries written"

  # 2. Re-run is a no-op.
  out="$(run "$H")"; rc=$?
  check "rerun: exit 0" "$rc" "0"
  case "$out" in *"already present"*) ok "rerun: reports already present" ;; *) bad "rerun: reports already present ($out)" ;; esac

  # 3. --check on a compliant machine exits 0; on a bare one exits 1.
  out="$(run "$H" --check)"; check "check: compliant exit 0" "$?" "0"
  H2="$TMP/$RUNTIME-check"; mkdir -p "$H2"
  out="$(run "$H2" --check)"; check "check: missing exit 1" "$?" "1"
  [ -f "$H2/settings.json" ] && bad "check: must not create the file" || ok "check: creates nothing"

  # 4. Existing settings are preserved: other top-level keys, other permission
  #    keys, and pre-existing allow entries all survive.
  H3="$TMP/$RUNTIME-existing"; mkdir -p "$H3"
  printf '{"model":"opus","permissions":{"allow":["Bash(ls:*)"],"deny":["Read(./.env)"]}}\n' > "$H3/settings.json"
  run "$H3" >/dev/null
  grep -q '"model"' "$H3/settings.json"        && ok "existing: other top-level key kept"   || bad "existing: other top-level key kept"
  grep -q '"Bash(ls:\*)"' "$H3/settings.json"  && ok "existing: prior allow entry kept"      || bad "existing: prior allow entry kept"
  grep -q '"deny"' "$H3/settings.json"         && ok "existing: deny untouched"              || bad "existing: deny untouched"
  grep -q '"alpha_tool"' "$H3/settings.json"   && ok "existing: new entry added"             || bad "existing: new entry added"
  [ -f "$H3/settings.json.aidevops.bak" ]      && ok "existing: backup written"              || bad "existing: backup written"

  # 5. Unparseable JSON is reported, never rewritten.
  H4="$TMP/$RUNTIME-broken"; mkdir -p "$H4"
  printf '{ oops\n' > "$H4/settings.json"
  out="$(run "$H4")"; check "broken: exit 3" "$?" "3"
  check "broken: file untouched" "$(cat "$H4/settings.json")" "{ oops"
  case "$out" in *"unparseable"*) ok "broken: says unparseable" ;; *) bad "broken: says unparseable ($out)" ;; esac

  # 6. A permissions value of the wrong shape does not crash the script.
  H5="$TMP/$RUNTIME-weird"; mkdir -p "$H5"
  printf '{"permissions":"nope"}\n' > "$H5/settings.json"
  run "$H5" >/dev/null; check "weird: exit 0" "$?" "0"
  grep -q '"alpha_tool"' "$H5/settings.json" && ok "weird: entries added anyway" || bad "weird: entries added anyway"
}

RAN=0
for rt in python3 python node; do
  command -v "$rt" >/dev/null 2>&1 && "$rt" --version >/dev/null 2>&1 || continue
  test_runtime "$rt"
  RAN=$((RAN+1))
done

if [ "$RAN" -eq 0 ]; then
  echo "no JSON runtime available; cannot test" >&2
  exit 1
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
