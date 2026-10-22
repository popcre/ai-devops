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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# A fixed allow list, so the test does not change when the real one does.
ALLOW="$TMP/allow"
printf '# comment\n\nalpha_tool\nbeta_tool\ndeny:gamma_tool\nretire:deny:Bash(sleep:*)\nretire:old_tool\n' > "$ALLOW"

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
  case "$out" in *"ADDED 3, RETIRED 0"*) ok "fresh: added 3, retired 0" ;; *) bad "fresh: added 3, retired 0 ($out)" ;; esac
  grep -q '"alpha_tool"' "$H/settings.json" && grep -q '"beta_tool"' "$H/settings.json" \
    && ok "fresh: both entries written" || bad "fresh: both entries written"
  grep -q '"gamma_tool"' "$H/settings.json" && ok "fresh: deny entry written" || bad "fresh: deny entry written"
  grep -q 'sleep' "$H/settings.json" && bad "fresh: retired entry never added" || ok "fresh: retired entry never added"

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
  grep -q '"Read(./.env)"' "$H3/settings.json" && ok "existing: prior deny entry kept"       || bad "existing: prior deny entry kept"
  grep -q '"alpha_tool"' "$H3/settings.json"   && ok "existing: new entry added"             || bad "existing: new entry added"
  check "existing: deny entry sits in deny beside the prior deny, not in allow" \
    "$(jq -c '[(.permissions.deny|index("gamma_tool"))!=null, (.permissions.deny|index("Read(./.env)"))!=null, (.permissions.allow|index("gamma_tool"))==null]' "$H3/settings.json")" '[true,true,true]'

  # 4b. Only the deny entry missing: --check notices it, install adds it to deny once.
  H4="$TMP/$RUNTIME-denyonly"; mkdir -p "$H4"
  printf '{"permissions":{"allow":["alpha_tool","beta_tool"],"deny":["Read(./.env)"]}}\n' > "$H4/settings.json"
  out="$(run "$H4" --check)"; check "deny-only: check exit 1" "$?" "1"
  run "$H4" >/dev/null; run "$H4" >/dev/null
  check "deny-only: added exactly once, to deny, never to allow" \
    "$(jq -c '[(.permissions.deny|map(select(.=="gamma_tool"))|length), (.permissions.allow|map(select(.=="gamma_tool"))|length)]' "$H4/settings.json")" '[1,0]'
  out="$(run "$H4" --check)"; check "deny-only: check exit 0 after install" "$?" "0"
  [ -f "$H3/settings.json.aidevops.bak" ]      && ok "existing: backup written"              || bad "existing: backup written"

  # 5. Unparseable JSON is reported, never rewritten.
  H4="$TMP/$RUNTIME-broken"; mkdir -p "$H4"
  printf '{ oops\n' > "$H4/settings.json"
  out="$(run "$H4")"; check "broken: exit 3" "$?" "3"
  check "broken: file untouched" "$(cat "$H4/settings.json")" "{ oops"
  case "$out" in *"unparseable"*) ok "broken: says unparseable" ;; *) bad "broken: says unparseable ($out)" ;; esac

  # 6. A retired entry is removed from exactly the list it names, and only
  #    that entry; a machine without it is untouched (#1962, deny:Bash(sleep:*)).
  H6="$TMP/$RUNTIME-retire"; mkdir -p "$H6"
  printf '{"permissions":{"allow":["alpha_tool","beta_tool","old_tool","Bash(sleep:*)"],"deny":["gamma_tool","Bash(sleep:*)","Read(./.env)"]}}\n' > "$H6/settings.json"
  out="$(run "$H6" --check)"; check "retire: --check flags stale entry (exit 1)" "$?" "1"
  case "$out" in *"RETIRE deny:Bash(sleep:*)"*) ok "retire: check names the entry" ;; *) bad "retire: check names the entry ($out)" ;; esac
  out="$(run "$H6")"; check "retire: exit 0" "$?" "0"
  case "$out" in *"ADDED 0, RETIRED 2"*) ok "retire: retired 2" ;; *) bad "retire: retired 2 ($out)" ;; esac
  [ "$(grep -c 'Bash(sleep:\*)' "$H6/settings.json")" = "1" ] && grep -q '"gamma_tool"' "$H6/settings.json" \
    && grep -q '"Read(./.env)"' "$H6/settings.json" && ! grep -q '"old_tool"' "$H6/settings.json"
  [ $? -eq 0 ] && ok "retire: only the named deny removed; allow Bash(sleep:*) kept" || bad "retire: only the named deny removed; allow Bash(sleep:*) kept"
  out="$(run "$H6")"; case "$out" in *"already present"*) ok "retire: rerun is a no-op" ;; *) bad "retire: rerun is a no-op ($out)" ;; esac

  # 7. A permissions value of the wrong shape does not crash the script.
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
