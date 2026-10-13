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
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 7\n' > "$T/bin/curl"; chmod +x "$T/bin/curl"
printf '#!/bin/sh\nexit 1\n' > "$T/bin/op"; chmod +x "$T/bin/op"
out="$(echo '{"last_assistant_message":"All done.","session_id":"t","prompt_id":"p"}' \
  | PATH="$T/bin:$PATH" TYPESAFE_API_KEY=dummy AI_JEV_SHADOW_LOG="$T/log" "$ROOT/bin/ai-jev-completion-shadow" 2>&1)"
[[ "$out" == *"escalate=1"* ]] && ok || bad "outage not recorded as escalate: $out"
[ "$(jq -r .outcome "$T/log")" = escalate ] && ok || bad "log outcome not escalate"
grep -q "All done" "$T/log" && bad "message text leaked into log" || ok

# 3. Probe reports a network failure clearly.
out="$(PATH="$T/bin:$PATH" TYPESAFE_API_KEY=dummy "$ROOT/bin/ai-jev-probe" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^FAIL:'; then
  ok
else
  bad "probe did not fail clearly rc=$rc out=$out"
fi

# 4. Completion shadow leaves no Jev temp files (jev_tmp outside $(...)).
mkdir -p "$T/shtmp"
printf '%s\n' '{"last_assistant_message":"All done.","session_id":"t","prompt_id":"p"}' \
  '{"last_assistant_message":"Fixed it.","session_id":"t","prompt_id":"q"}' \
  | PATH="$T/bin:$PATH" TMPDIR="$T/shtmp" TYPESAFE_API_KEY=dummy AI_JEV_SHADOW_LOG="$T/log2" "$ROOT/bin/ai-jev-completion-shadow" >/dev/null 2>&1
[ -z "$(find "$T/shtmp" -mindepth 1 2>/dev/null)" ] && ok || bad "completion shadow leaked temp files: $(find "$T/shtmp" -mindepth 1)"

# 5-7. The op run re-exec path (#1646 H1/H2), exercised without real 1Password:
#      a stub `op` re-execs the consumer keyed, and the unkeyed parent must
#      exit with the child's status instead of continuing unkeyed.
mkdir -p "$T/opbin" "$T/cfgdir"
printf 'TYPESAFE_API_KEY=op://vault/item/field\n' > "$T/cfgdir/mcp.env"
cat > "$T/opbin/op" <<EOS
#!/bin/sh
printf '%s\n' "\$*" >> "$T/op-calls"
[ "\$1" = run ] || exit 1
while [ \$# -gt 0 ] && [ "\$1" != -- ]; do shift; done
shift
TYPESAFE_API_KEY=dummy exec "\$@"
EOS
chmod +x "$T/opbin/op"
PIN="$(jq -r .model_pin "$ROOT/config/jev-decisions.json")"
cat > "$T/opbin/curl" <<EOS
#!/bin/sh
out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [ -n "\$out" ]; then
  printf '%s\n' '{"model":"$PIN","answers":{"probe":{"type":"noul","noul":0.97},"c":{"type":"noul","noul":0.97}},"usage":{"input_tokens":1,"output_tokens":1}}' > "\$out"
fi
echo 200
EOS
chmod +x "$T/opbin/curl"

# 5. Probe through the re-exec path exits 0 and prints ok exactly once (a
#    returning parent would continue unkeyed and append FAIL: / exit 1).
rm -f "$T/op-calls"
out="$(env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opbin:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
  "$ROOT/bin/ai-jev-probe" </dev/null 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "probe via op run re-exec rc=$rc: $out"
[ "$(printf '%s\n' "$out" | grep -cx 'ok')" -eq 1 ] && ok || bad "probe via op run did not print ok exactly once: $out"
grep -q 'run --env-file' "$T/op-calls" 2>/dev/null && ok || bad "probe never re-executed through op run"

# 6. Completion shadow through the re-exec path prints exactly ONE items=
#    summary — the parent must not append a spurious second (items=0) line.
rm -f "$T/op-calls"
out="$(printf '%s\n' '{"last_assistant_message":"All done.","session_id":"t","prompt_id":"p"}' \
  | env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opbin:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
    AI_JEV_SHADOW_LOG="$T/log-reexec" "$ROOT/bin/ai-jev-completion-shadow" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "completion shadow via op run re-exec rc=$rc: $out"
[ "$(printf '%s\n' "$out" | grep -c '^items=')" -eq 1 ] && ok || bad "expected exactly one items= summary: $out"
printf '%s\n' "$out" | grep -q '^items=1 ' && ok || bad "summary is not the keyed child's (items=1): $out"
grep -q 'run --env-file' "$T/op-calls" 2>/dev/null && ok || bad "completion shadow never re-executed through op run"

echo "passed=$pass failed=$failn"
if [ "$failn" -eq 0 ]; then exit 0; else exit 1; fi
