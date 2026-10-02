#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/host/claude/main" "$fixture/host/claude/main/subagents" "$fixture/host/codex/main"
cat > "$fixture/host/claude/main/a.jsonl" <<'JSON'
{"type":"user","sessionId":"c1","message":{"content":"SECRET SENTINEL"}}
{"type":"assistant","sessionId":"c1","message":{"id":"m1","usage":{"input_tokens":2,"cache_creation_input_tokens":3,"cache_read_input_tokens":4,"output_tokens":5},"content":[{"type":"tool_use","name":"Skill","input":{"skill":"example"}}]}}
{"type":"assistant","sessionId":"c1","message":{"id":"m1","usage":{"input_tokens":2,"cache_creation_input_tokens":3,"cache_read_input_tokens":4,"output_tokens":5},"content":[]}}
JSON
cp "$fixture/host/claude/main/a.jsonl" "$fixture/host/claude/main/duplicate.jsonl"
cp "$fixture/host/claude/main/a.jsonl" "$fixture/host/claude/main/subagents/child.jsonl"
cat > "$fixture/host/codex/main/a.jsonl" <<'JSON'
{"type":"session_meta","payload":{"id":"x1"}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":6,"output_tokens":2}}}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":12,"output_tokens":4}}}}
JSON
output="$(python3 "$repo_root/tests/verification/jev/spend_baseline_audit.py" "$fixture")"
[[ "$output" == *'"sessions": 1'* ]]
[[ "$output" == *'"excluded_duplicate_files": 1'* ]]
[[ "$output" == *'"excluded_subagent_files": 1'* ]]
[[ "$output" == *'"billed_messages": 1'* ]]
[[ "$output" == *'"cache_read_input_tokens": 4'* ]]
[[ "$output" == *'"cached_input_tokens": 12'* ]]
[[ "$output" != *'SECRET SENTINEL'* ]]
printf '%s\n' 'ok: structural spend audit deduplicates usage and omits content'
