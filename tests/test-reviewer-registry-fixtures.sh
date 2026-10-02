#!/usr/bin/env bash
# Offline adapter suites must never read live reviewer-pool membership.
# A membership on/off flip then cannot break wrapper tests.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

for suite in \
  tests/test-ai-claude-review.sh \
  tests/test-ai-codex-review.sh \
  tests/test-ai-grok-review.sh \
  tests/test-ai-qwen.sh \
  tests/test-ai-muse.sh \
  tests/test-ai-gemini.sh \
  tests/test-ai-deepseek-agent.sh
do
  check "$(basename "$suite") uses a fixture registry, not live membership" \
    "grep -q 'AI_REVIEW_REGISTRY_FILE' '$ROOT/$suite'"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
