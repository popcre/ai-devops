#!/usr/bin/env bash
# Offline checks for bin/ai-jev-probe and bin/ai-jev-completion-shadow.
# No network and no real key: curl is replaced by a failing stub.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok()  { pass=$((pass+1)); }
bad() { failn=$((failn+1)); echo "FAIL: $*"; }

# 1. Empty key after op run fails loudly, never sends a request.
for s in ai-jev-probe ai-jev-completion-shadow; do
  out="$(AI_JEV_REEXEC=1 TYPESAFE_API_KEY= "$ROOT/bin/$s" </dev/null 2>&1)"; rc=$?
  [ $rc -ne 0 ] && [[ "$out" == *EMPTY* ]] && ok || bad "$s did not fail loudly on empty key"
done

# 2. A vendor failure is recorded as escalate, never as clean or agree.
mkdir -p "$T/bin"; printf '#!/bin/sh\ncat >/dev/null; exit 7\n' > "$T/bin/curl"; chmod +x "$T/bin/curl"
out="$(echo '{"last_assistant_message":"All done.","session_id":"t","prompt_id":"p"}' \
  | PATH="$T/bin:$PATH" TYPESAFE_API_KEY=dummy AI_JEV_SHADOW_LOG="$T/log" "$ROOT/bin/ai-jev-completion-shadow" 2>&1)"
[[ "$out" == *"escalate=1"* ]] && ok || bad "outage not recorded as escalate: $out"
[ "$(jq -r .outcome "$T/log")" = escalate ] && ok || bad "log outcome not escalate"
grep -q "All done" "$T/log" && bad "message text leaked into log" || ok

# 3. Probe reports a network failure clearly.
out="$(PATH="$T/bin:$PATH" TYPESAFE_API_KEY=dummy "$ROOT/bin/ai-jev-probe" 2>&1)"; rc=$?
[ $rc -ne 0 ] && [[ "$out" == FAIL:* ]] && ok || bad "probe did not fail clearly: $out"

echo "passed=$pass failed=$failn"
[ "$failn" -eq 0 ]
