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
review_shared_code_paths_regex() { # the shared review code every provider runs (#1834; release live check #1783)
  printf '%s\n' '^(bin/ai-review(-pool|-engine|-preflight|-packet|-sandbox|-lifecycle)?|tools/lib/review-(lifecycle-core|capabilities)\.sh|config/review-runner-doors\.json)$'
}
review_shared_code_changed() { # CHANGED_FILES (one per line) -> 0 when any is shared review code
  printf '%s\n' "$1" | grep -Eq "$(review_shared_code_paths_regex)"
}
review_shared_code_rule() { # CHANGED_FILES (one per line) -> the #1834 brief rule when shared review code changed
  review_shared_code_changed "$1" || return 0
  printf '%s\n' 'Shared review code rule (#1834): check every maintained provider (grok, muse, qwen, gemini, deepseek, stepfun, glm). A step that decides whether evidence, a receipt, a record, cleanup or qualification happens must apply to every provider unless a named capability in config/review-runner-doors.json declares the exception; a provider-name branch there is a finding. Provider policy data (timeouts, budgets, routes, platform guards) is allowed.'
}
review_closing_contract() { # REQUEST_FILE (may be empty) -> the closing report rules every brief ends with (#1783)
  # Governed consumers read ANY line opening with a decision word as a second
  # decision and refuse the review, and shared-db requires the requested
  # production-risk block on an approval. Both rules sit LAST, after any
  # carried request, so no provider sees them buried mid-brief.
  printf '\n%s\n' '## Report rules (apply to the whole report)'
  printf '%s\n' '- Give exactly one decision: the final `## Verdict` word. Do not give an early, provisional or second decision. No other line may begin with APPROVE, REJECT, REVISE or BLOCKED, including headings, bullets, bold or quoted text; when a finding must mention a decision, put other words first (for example: "Earlier wording said approve").'
  printf '%s\n' '- A tool missing from your copy (for example a database server) is not by itself grounds for BLOCKED: judge from the sealed source, and say what you could not run. Use BLOCKED only when the source itself leaves the decision undeterminable.'
  if [ -n "${1:-}" ] && [ -f "$1" ] && review_requests_risk_block "$1"; then
    printf '%s\n' '- The request above asks for a `production-risk-assessment` block. If you APPROVE, the report MUST contain exactly one fenced block with that info string, filled in as the request describes; an approval without it cannot be recorded.'
  fi
}
review_requests_risk_block() { # FILE -> 0 when a carried request asks for the shared-db production-risk block
  grep -q 'production-risk-assessment' "$1" 2>/dev/null
}
review_risk_block_count() { # REPORT -> number of production-risk-assessment fences
  grep -cE '^[[:space:]]*```production-risk-assessment[[:space:]]*$' "$1" 2>/dev/null || true # the fence shared-db accepts
}
