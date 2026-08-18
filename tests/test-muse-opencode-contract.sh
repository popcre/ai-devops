#!/usr/bin/env bash
# Offline guard for the sanitized Muse contract fixture. This test must never call Meta.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$ROOT/tests/fixtures/muse-opencode/contract-2026-08-18.json"
CONFIG="$ROOT/tests/fixtures/muse-opencode/opencode-1.18.12.json"
failures=0

check() {
  local label="$1"
  shift
  if "$@"; then printf 'ok - %s\n' "$label"; else printf 'not ok - %s\n' "$label" >&2; failures=$((failures + 1)); fi
}

check fixture-model jq -e '.required_model == "muse-spark-1.2-contributor"' "$FIXTURE" >/dev/null
check fixture-listing jq -e '.model_listing.matched_models | index("muse-spark-1.2-contributor") != null' "$FIXTURE" >/dev/null
check fixture-tools jq -e '.tool_calling.finish_reason == "tool_calls" and .tool_calling.function_name == "add"' "$FIXTURE" >/dev/null
check fixture-continuity jq -e '.multi_turn.finish_reason == "stop" and .multi_turn.continuity_observed == true' "$FIXTURE" >/dev/null
check fixture-errors jq -e '.errors.invalid_key.status == 401 and .errors.invalid_model.status == 404' "$FIXTURE" >/dev/null
check config-key-reference jq -e '.provider["meta-model-api"].options.apiKey == "{env:MODEL_API_KEY}"' "$CONFIG" >/dev/null
check config-no-literal-key jq -e '(.provider["meta-model-api"].options | tostring | contains("MODEL_API_KEY")) and (.provider["meta-model-api"].options | tostring | contains("LLM|")) | not' "$CONFIG" >/dev/null
check config-exact-model jq -e '.model == "meta-model-api/muse-spark-1.2-contributor" and .share == "disabled" and .autoupdate == false' "$CONFIG" >/dev/null

if [ "$failures" -ne 0 ]; then exit 1; fi
printf 'Muse OpenCode contract fixtures passed.\n'
