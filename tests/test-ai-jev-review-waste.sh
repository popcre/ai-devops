#!/usr/bin/env bash
# Offline checks for bin/ai-jev-review-waste and tools/lib/jev-client.sh.
# No network and no real key. Endpoint is injectable only with AI_JEV_OFFLINE_TEST=1.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok()  { pass=$((pass+1)); }
bad() { failn=$((failn+1)); echo "FAIL: $*"; }

PIN="$(jq -r .model_pin "$ROOT/config/jev-decisions.json")"
[ -n "$PIN" ] && [ "$PIN" != null ] && ok || bad "model_pin missing from jev-decisions.json"

# --- stub curl that records request and writes a canned 200 body ---
mkdir -p "$T/bin"
cat > "$T/bin/curl" <<EOS
#!/bin/sh
out=""
req=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    --data-binary) req="\$2"; shift 2 ;;
    -H|-w|--connect-timeout|--max-time) shift 2 ;;
    -sS|-s|-S) shift ;;
    *) shift ;;
  esac
done
if [ -n "\$req" ]; then
  req="\${req#@}"
  [ -f "\$req" ] && cp "\$req" "\$TMPDIR/last-request.json" 2>/dev/null || true
fi
mode="\${STUB_MODE:-ok}"
if [ "\$mode" = fail7 ]; then exit 7; fi
if [ -n "\$out" ]; then
  case "\$mode" in
    badmodel)
      printf '%s\n' '{"model":"jev-latest","answers":{"chunk_filter":{"type":"choice","choice":"unrelated","probabilities":{"review_interaction":0.0,"meta_discussion":0.0,"unrelated":1.0},"confidence":0.9}},"usage":{"input_tokens":1,"output_tokens":1}}' > "\$out" ;;
    noanswer)
      printf '%s\n' '{"model":"$PIN","answers":{},"usage":{"input_tokens":1,"output_tokens":1}}' > "\$out" ;;
    *)
      printf '%s\n' '{"model":"$PIN","answers":{"chunk_filter":{"type":"choice","choice":"review_interaction","probabilities":{"review_interaction":0.9,"meta_discussion":0.05,"unrelated":0.05},"confidence":0.88},"value_level":{"type":"score","score":3.1,"legend":{"0":"negative","1":"none","2":"low","3":"medium","4":"highest"},"probabilities":{"0":0.0,"1":0.05,"2":0.1,"3":0.55,"4":0.3},"confidence":0.8}},"usage":{"input_tokens":10,"output_tokens":3}}' > "\$out" ;;
  esac
fi
echo 200
exit 0
EOS
chmod +x "$T/bin/curl"

export PATH="$T/bin:$PATH"
export TYPESAFE_API_KEY=dummy
export AI_JEV_OFFLINE_TEST=1
export AI_JEV_ENDPOINT="http://127.0.0.1:9/stub"
export TMPDIR="$T"
export T

# 1. Bootstrap refuses empty key loudly (no request).
empty_items="$T/empty.jsonl"
: > "$empty_items"
out="$(AI_JEV_REEXEC=1 TYPESAFE_API_KEY= "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$empty_items" 2>&1)"; rc=$?
[ $rc -ne 0 ] && [[ "$out" == *EMPTY* ]] && ok || bad "empty key not loud: $out"

# 2. chunk-filter marks a review interaction and never prints state text.
items="$T/items.jsonl"
printf '%s\n' '{"id":"c1","state":"SECRET_PRIVATE_TEXT_SENT_TO_REVIEWER"}' > "$items"
out="$(STUB_MODE=ok "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "chunk-filter rc=$rc: $out"
[[ "$out" == *'"label":"review_interaction"'* ]] && ok || bad "wrong label: $out"
[[ "$out" == *SECRET_PRIVATE* ]] && bad "state text leaked" || ok
# request body recorded by stub used the pinned model, not jev-latest
grep -q "$PIN" "$T/last-request.json" && ok || bad "request did not use model pin"
grep -q 'jev-latest' "$T/last-request.json" && bad "request used jev-latest" || ok

# 3. Model mismatch abstains, does not guess.
out="$(STUB_MODE=badmodel "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"
[[ "$out" == *'"decision":"abstain"'* ]] && ok || bad "model mismatch did not abstain: $out"
[[ "$out" == *'"label":"unrelated"'* ]] && bad "guessed label on model mismatch" || ok

# 4. HTTP/network failure abstains.
out="$(STUB_MODE=fail7 "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"
[[ "$out" == *'"decision":"abstain"'* ]] && ok || bad "network fail did not abstain: $out"

# 5. Malformed answers abstain.
out="$(STUB_MODE=noanswer "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"
[[ "$out" == *'"decision":"abstain"'* ]] && ok || bad "missing answers did not abstain: $out"

# 6. value-level returns an ordered label from Score.
out="$(STUB_MODE=ok "$ROOT/bin/ai-jev-review-waste" value-level --items "$items" 2>&1)"
[[ "$out" == *'"label":"medium"'* ]] && ok || bad "value-level label wrong: $out"
[[ "$out" == *SECRET_PRIVATE* ]] && bad "state text leaked in value-level" || ok

# 7. Per-run call cap.
cat > "$T/cap.env" <<EOF
EOF
# Run with max_calls 0 via a tiny config override
cp "$ROOT/config/jev-decisions.json" "$T/cfg.json"
jq '.max_calls_per_run=0' "$T/cfg.json" > "$T/cfg2.json" && mv "$T/cfg2.json" "$T/cfg.json"
out="$(JEV_CONFIG="$T/cfg.json" STUB_MODE=ok "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"
[[ "$out" == *abstain* ]] && ok || bad "call cap did not abstain: $out"

# 8. Shared client is the only transport: no second endpoint constant in thin caller.
grep -q 'api.typesafe.ai' "$ROOT/bin/ai-jev-review-waste" && bad "thin caller hardcodes endpoint" || ok
grep -q 'TYPESAFE_API_KEY=' "$ROOT/bin/ai-jev-review-waste" && bad "thin caller resolves secrets" || ok

echo "passed=$pass failed=$failn"
if [ "$failn" -eq 0 ]; then exit 0; else exit 1; fi
