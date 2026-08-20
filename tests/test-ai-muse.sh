#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
check() { if "$@"; then printf 'ok - %s\n' "$*"; else printf 'not ok - %s\n' "$*" >&2; fail=1; fi; }

check bash -n "$ROOT/bin/ai-muse"
check bash -n "$ROOT/bin/setup-opencode-muse.sh"
check jq -e '.model == "meta-model-api/muse-spark-1.2-contributor" and .share == "disabled" and .autoupdate == false and .provider["meta-model-api"].options.baseURL == "https://api.meta.ai/v1" and .provider["meta-model-api"].options.apiKey == "{env:MODEL_API_KEY}"' "$ROOT/config/opencode-muse/opencode.json"
check bash -c "! grep -Eq '^  (write|edit|patch|bash|webfetch|task): true$' '$ROOT/config/opencode-muse/agent/muse-review.md'"
check bash -c "grep -q 'ensure-copy' '$ROOT/bin/ai-muse' && grep -q 'ai-review-packet' '$ROOT/bin/ai-muse'"
check bash -c "! grep -q 'serve ' '$ROOT/bin/ai-muse'"
check bash -c "grep -q 'VERDICT: FINDINGS' '$ROOT/bin/ai-muse' && grep -q 'muse-incomplete-' '$ROOT/bin/ai-muse'"
check bash -c "! grep -q 'MODEL_API_KEY=.*[A-Za-z0-9]' '$ROOT/config/opencode-muse/opencode.json'"

# --- verdict extraction regression (reviewer issue 20260820T013646Z) ---
# A complete Muse review ending in "VERDICT: APPROVE" was filed as incomplete,
# because the matcher only accepted FINDINGS/NO FINDINGS and ran over a stream
# still carrying ANSI colour codes. Test the shipped code, not a copy of it.
eval "$(grep -E '^strip_ansi\(\) ' "$ROOT/bin/ai-muse")"
VERDICT_RE="$(grep -E '^  verdict=' "$ROOT/bin/ai-muse" | sed -E "s/.*grep -Eo '([^']*)'.*/\1/")"
extract() { printf '%s\n' "$1" | strip_ansi | grep -Eo "$VERDICT_RE" | tail -n 1; }

check bash -c "[ -n \"$VERDICT_RE\" ]"
check test "$(extract "$(printf 'review body\nVERDICT: APPROVE')")" = 'VERDICT: APPROVE'
check test "$(extract "$(printf 'review body\n\033[0mVERDICT: NO FINDINGS\033[0m\r')")" = 'VERDICT: NO FINDINGS'
check test "$(extract "$(printf 'VERDICT: FINDINGS\ntrailing note\nVERDICT: APPROVE')")" = 'VERDICT: APPROVE'
check test -z "$(extract "$(printf 'narration only, no verdict line\nVERDICT:')")"
check test -z "$(extract "$(printf 'we will end with a VERDICT: APPROVE line')")"

# A brief that already dictates its own verdict wording must not get a second,
# conflicting instruction appended.
check bash -c "grep -q \"grep -Eqi 'VERDICT:'\" '$ROOT/bin/ai-muse'"

exit "$fail"
