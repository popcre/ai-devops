#!/usr/bin/env bash
# ai-nas: on-demand NAS connector call through a launcher (fake stdio server here).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-nas"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
cat > "$TMP/fake.py" <<'FAKE'
import json, sys
mode = sys.argv[1]
print("Authorization: Bearer SHOULD-NOT-SHOW", file=sys.stderr, flush=True)
for line in sys.stdin:
    m = json.loads(line)
    if mode == "die":
        sys.exit(7)
    if mode == "hang":
        continue
    if "id" not in m:
        continue
    if m["method"] == "initialize":
        r = {"protocolVersion": "2025-06-18", "capabilities": {}, "serverInfo": {"name": "fake", "version": "0"}}
    elif m["method"] == "tools/list":
        r = {"tools": [{"name": "check_disk_space", "description": "Disk\nmore"}]}
    else:
        p = m["params"]
        r = {"content": [{"type": "text", "text": "called %s %s" % (p["name"], json.dumps(p["arguments"], sort_keys=True))}],
             "isError": p["name"] == "bad"}
    print(json.dumps({"jsonrpc": "2.0", "id": m["id"], "result": r}), flush=True)
FAKE
FAKE_PY="$TMP/fake.py"
# Native Windows Python cannot open a Git Bash /tmp path.
command -v cygpath >/dev/null 2>&1 && FAKE_PY="$(cygpath -m "$FAKE_PY")"
L(){ printf '%s|%s|%s' "$PY" "$FAKE_PY" "$1"; }

out="$(AI_NAS_LAUNCHER="$(L ok)" "$SCRIPT" tools)"; rc=$?
[ $rc -eq 0 ] && [ "$out" = "$(printf 'check_disk_space\tDisk')" ] && ok "tools lists names with first description line" || bad "tools: rc=$rc out=$out"
out="$(AI_NAS_LAUNCHER="$(L ok)" "$SCRIPT" call check_disk_space '{"target":"both"}')"; rc=$?
[ $rc -eq 0 ] && [ "$out" = 'called check_disk_space {"target": "both"}' ] && ok "call passes arguments and prints text" || bad "call: rc=$rc out=$out"
out="$(AI_NAS_LAUNCHER="$(L ok)" "$SCRIPT" call check_disk_space)"; rc=$?
[ $rc -eq 0 ] && [ "$out" = 'called check_disk_space {}' ] && ok "call defaults to empty arguments" || bad "default args: rc=$rc out=$out"
AI_NAS_LAUNCHER="$(L ok)" "$SCRIPT" call bad >/dev/null; rc=$?
[ $rc -eq 1 ] && ok "tool error exits 1" || bad "tool error rc=$rc"
AI_NAS_LAUNCHER="$(L ok)" "$SCRIPT" call x '[1]' 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "non-object arguments are refused" || bad "bad args rc=$rc"
"$SCRIPT" bogus 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "unknown mode is a usage error" || bad "usage rc=$rc"
err="$(AI_NAS_LAUNCHER="$(L die)" "$SCRIPT" tools 2>&1 >/dev/null)"; rc=$?
[ $rc -eq 3 ] && ok "launcher death exits 3" || bad "die rc=$rc"
case "$err" in *SHOULD-NOT-SHOW*) bad "bearer line leaked to output" ;; *) ok "bearer lines are never echoed" ;; esac
start=$SECONDS; AI_NAS_LAUNCHER="$(L hang)" "$SCRIPT" --timeout 2 tools 2>/dev/null; rc=$?
[ $rc -eq 3 ] && [ $((SECONDS - start)) -lt 15 ] && ok "a silent server times out" || bad "hang rc=$rc"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
