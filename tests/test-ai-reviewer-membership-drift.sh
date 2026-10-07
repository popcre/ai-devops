#!/usr/bin/env bash
# Offline test for bin/ai-reviewer-membership-drift using fixture allocator/registry files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
BIN="$ROOT/bin/ai-reviewer-membership-drift.cjs"
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
# The default allocator read is fresh and admitted; fixture file mode above
# remains wholly offline. A fake real CLI proves the installed command route.
cat > "$T/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
cat "$LANES_FIXTURE"
GH
chmod +x "$T/gh"
GH_LOG="$T/gh.log" LANES_FIXTURE="$T/lanes.mjs" \
AI_GH_REAL_GH="$T/gh" AI_GH_STATE_DIR="$T/gh-state" \
AI_GH_MIN_SPACING_SECONDS=0 AI_GH_QUOTA_PROBE_SECONDS=off \
  node "$BIN" --scope "$T/scope.json" --registry "$T/ok.json" | grep -q '^OK' ||
  { echo 'FAIL: shared transport did not read allocator'; exit 1; }
[ -f "$T/gh-state/last_call_ms" ] || { echo 'FAIL: allocator read bypassed shared admission'; exit 1; }
[ "$(wc -l < "$T/gh.log")" -eq 1 ] || { echo 'FAIL: unexpected allocator reads'; exit 1; }
grep -q 'contents/scripts/lib/lanes/reviewer-roster.mjs' "$T/gh.log" || { echo 'FAIL: roster not read from scripts/lib/lanes/reviewer-roster.mjs'; exit 1; }
echo 'PASS test-ai-reviewer-membership-drift'
