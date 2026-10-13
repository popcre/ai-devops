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
# Fail fast if anything tries 1Password in CI (must never hang).
printf '#!/bin/sh\necho op-stub >&2\nexit 1\n' > "$T/bin/op"
chmod +x "$T/bin/op"
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

# 9. Unkeyed run: op run re-exec gets the original arguments, and the parent
#    exits with the child's status instead of running the pipeline again (#1620).
mkdir -p "$T/opbin" "$T/cfgdir"
printf 'TYPESAFE_API_KEY=op://vault/item/field\n' > "$T/cfgdir/mcp.env"
cat > "$T/opbin/op" <<'EOS'
#!/bin/sh
printf '%s\n' "$*" >> "$T/op-calls"
[ "$1" = run ] || exit 1
while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
shift
TYPESAFE_API_KEY=dummy exec "$@"
EOS
chmod +x "$T/opbin/op"
mkdir -p "$T/tmpcheck"; rm -f "$T/op-calls"
out="$(env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opbin:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
  TMPDIR="$T/tmpcheck" STUB_MODE=ok "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "unkeyed re-exec rc=$rc: $out"
grep -q -- '-- /usr/bin/env bash .*ai-jev-review-waste chunk-filter --items ' "$T/op-calls" && ok || bad "op run did not receive the original arguments: $(cat "$T/op-calls" 2>/dev/null)"
[ "$(printf '%s\n' "$out" | grep -c '"id"')" -eq 1 ] && ok || bad "parent continued after op run (expected one record): $out"
[[ "$out" == *'"label":"review_interaction"'* ]] && ok || bad "keyed child result missing: $out"

# 10. Temp files registered by jev_tmp are removed at exit (no subshell leak).
[ -z "$(find "$T/tmpcheck" -type f ! -name last-request.json 2>/dev/null)" ] && ok || bad "temp files leaked: $(find "$T/tmpcheck" -type f ! -name last-request.json)"
mkdir -p "$T/tmpcheck2"
TMPDIR="$T/tmpcheck2" STUB_MODE=ok "$ROOT/bin/ai-jev-review-waste" value-level --items "$items" >/dev/null 2>&1
[ -z "$(find "$T/tmpcheck2" -type f ! -name last-request.json 2>/dev/null)" ] && ok || bad "keyed run leaked temp files"

# 11. Python helpers: one secret path (op run), no field reveal, no private archive path.
grep -nE 'op", "item"|--reveal' "$ROOT"/tools/jev_*.py && bad "python helper reads a secret field directly" || ok
grep -nE 'C:\\\\Users|Dropbox' "$ROOT/tools/jev_review_waste_sample.py" | grep -v '^\s*#' | grep -q 'Path(' && bad "private archive path hardcoded" || ok
pyout="$(cd "$T" && env -u AI_JEV_ARCHIVE_DIR python3 -I -c "import sys; sys.path.insert(0, '$ROOT/tools'); import jev_review_waste_sample as s; s.archive_root()" 2>&1)"; rc=$?
[ $rc -ne 0 ] && [[ "$pyout" == *AI_JEV_ARCHIVE_DIR* ]] && ok || bad "archive root not required: $pyout"
pyout="$(cd "$T" && env -u TYPESAFE_API_KEY AI_JEV_REEXEC=1 python3 -I -c "import sys; sys.path.insert(0, '$ROOT/tools'); import jev_review_waste_http as h; h.resolve_key()" 2>&1)"; rc=$?
[ $rc -ne 0 ] && [[ "$pyout" == *EMPTY* ]] && ok || bad "python empty key after op run not loud: $pyout"

# 12. op run launch failure (before the child starts) keeps the consumer's
#     failure contract: abstain record / FAIL: line and exit 1.
mkdir -p "$T/opfail"
printf '#!/bin/sh\necho "op: session expired" >&2\nexit 3\n' > "$T/opfail/op"; chmod +x "$T/opfail/op"
out="$(env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opfail:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
  "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"; rc=$?
[ $rc -eq 1 ] && [[ "$out" == *'"reason":"bootstrap"'* ]] && ok || bad "op launch failure lost the abstain contract: rc=$rc $out"
out="$(env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opfail:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
  "$ROOT/bin/ai-jev-probe" </dev/null 2>&1)"; rc=$?
[ $rc -eq 1 ] && [[ "$out" == *'FAIL: bootstrap failed'* ]] && ok || bad "op launch failure lost probe FAIL: rc=$rc $out"
# A started child that fails (empty key) prints its own record once; parent adds nothing.
printf '#!/bin/sh\nwhile [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done; shift\nTYPESAFE_API_KEY= exec "$@"\n' > "$T/opfail/op"
out="$(env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opfail:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" \
  "$ROOT/bin/ai-jev-review-waste" chunk-filter --items "$items" 2>&1)"; rc=$?
[ $rc -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c '"reason":"bootstrap"')" -eq 1 ] && [[ "$out" == *EMPTY* ]] && ok || bad "failed child output not exactly once: rc=$rc $out"
# Python helper: op run failure is loud; the archive path expands ~.
printf '#!/bin/sh\nexit 3\n' > "$T/opfail/op"
pyout="$(cd "$T" && env -u TYPESAFE_API_KEY -u AI_JEV_REEXEC PATH="$T/opfail:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfgdir" python3 -I -c "import sys; sys.path.insert(0, '$ROOT/tools'); import jev_review_waste_http as h; h.resolve_key()" 2>&1)"; rc=$?
[ $rc -eq 3 ] && [[ "$pyout" == *'op run failed'* ]] && ok || bad "python op run failure not loud: rc=$rc $pyout"
mkdir -p "$T/home/arch"
pyout="$(cd "$T" && HOME="$T/home" AI_JEV_ARCHIVE_DIR='~/arch' python3 -I -c "import sys; sys.path.insert(0, '$ROOT/tools'); import jev_review_waste_sample as s; print(s.archive_root())" 2>&1)"
[ "$pyout" = "$T/home/arch" ] && ok || bad "archive root did not expand ~: $pyout"

echo "passed=$pass failed=$failn"
if [ "$failn" -eq 0 ]; then exit 0; else exit 1; fi
