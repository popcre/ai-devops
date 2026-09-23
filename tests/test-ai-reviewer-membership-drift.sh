#!/usr/bin/env bash
# Offline test for bin/ai-reviewer-membership-drift using fixture allocator/registry files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
BIN="$ROOT/bin/ai-reviewer-membership-drift"
cat > "$T/lanes.mjs" <<'M'
export const REVIEWERS = Object.freeze([
  { name:'grok-4.6', provider:'grok', wrapper:'ai-grok-review' },
  { name:'glm-5.3', provider:'glm', wrapper:'ai-glm' },
  { name:'qwen-3.8-max', provider:'qwen', wrapper:'ai-qwen' },
])
export const RETIRED_REVIEWERS = Object.freeze(['glm-5.3'])
export const QUARANTINED_REVIEWERS = Object.freeze([])
M
printf '{"outside_allocator":{"claude":"x"}}' > "$T/scope.json"
printf '{"providers":{"claude":{"registry_state":"registered"},"grok":{"registry_state":"registered"},"qwen":{"registry_state":"registered"},"glm":{"registry_state":"absent"}}}' > "$T/ok.json"
printf '{"providers":{"grok":{"registry_state":"registered"},"glm":{"registry_state":"registered"}}}' > "$T/bad.json"
node "$BIN" --lanes-file "$T/lanes.mjs" --scope "$T/scope.json" --registry "$T/ok.json" | grep -q '^OK .*grok, qwen' || { echo 'FAIL: matching membership not accepted'; exit 1; }
set +e; out="$(node "$BIN" --lanes-file "$T/lanes.mjs" --scope "$T/scope.json" --registry "$T/bad.json")"; rc=$?; set -e
[ "$rc" = 1 ] || { echo "FAIL: drift exit $rc"; exit 1; }
grep -q 'glm: registered in ai-devops but retired' <<<"$out" || { echo 'FAIL: retired glm not reported'; exit 1; }
grep -q 'qwen: active in the shared-db allocator but missing' <<<"$out" || { echo 'FAIL: missing qwen not reported'; exit 1; }
printf 'nothing here' > "$T/empty.mjs"
set +e; node "$BIN" --lanes-file "$T/empty.mjs" --scope "$T/scope.json" --registry "$T/ok.json" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 2 ] || { echo "FAIL: unparseable allocator exit $rc"; exit 1; }
echo 'PASS test-ai-reviewer-membership-drift'
