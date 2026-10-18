# shellcheck shell=bash
# Owner: reviewer infrastructure (#1834). The one reader for provider behaviour
# capabilities in config/review-runner-doors.json (.capabilities). Shared review
# layers call this instead of branching on a provider name for any step that
# decides whether evidence, a receipt, a record, cleanup or qualification
# happens. An absent field, provider or file means the common path.
review_capability() { # review_capability DOORS_JSON PROVIDER FIELD -> 0 when true
  [ -f "$1" ] || return 1
  jq -e --arg p "$2" --arg f "$3" '.capabilities[$p][$f] == true' "$1" >/dev/null 2>&1
}
review_capability_providers() { # DOORS_JSON FIELD -> space-separated providers, file order
  [ -f "$1" ] || return 0
  jq -r --arg f "$2" '[.capabilities // {} | to_entries[] | select((.value|type)=="object" and .value[$f]==true) | .key] | join(" ")' "$1" 2>/dev/null
}
review_shared_code_rule() { # CHANGED_FILES (one per line) -> the #1834 brief rule when shared review code changed
  printf '%s\n' "$1" | grep -Eq '^(bin/ai-review(-pool|-engine|-preflight|-packet|-sandbox)?|tools/lib/review-(lifecycle-core|capabilities)\.sh|config/review-runner-doors\.json)$' || return 0
  printf '%s\n' 'Shared review code rule (#1834): check every maintained provider (grok, muse, qwen, gemini, deepseek, stepfun, glm). A step that decides whether evidence, a receipt, a record, cleanup or qualification happens must apply to every provider unless a named capability in config/review-runner-doors.json declares the exception; a provider-name branch there is a finding. Provider policy data (timeouts, budgets, routes, platform guards) is allowed.'
}
