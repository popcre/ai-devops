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

exit "$fail"
