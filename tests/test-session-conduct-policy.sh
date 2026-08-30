#!/usr/bin/env bash
# Guard the session-waiting and repository-growth rules from issue #165.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

check() { if eval "$2"; then printf 'PASS: %s\n' "$1"; else printf 'FAIL: %s\n' "$1"; failures=$((failures + 1)); fi; }

router="$ROOT/AGENTS.md"
codex="$ROOT/templates/system/AGENTS-global-codex.md"
claude="$ROOT/templates/system/CLAUDE-global.md"

for file in "$router" "$codex" "$claude"; do
  check "$(basename "$file") requires bounded event-aware CI waiting" \
    "grep -Fq 'bounded, event-aware' '$file'"
  check "$(basename "$file") contains no negated reuse rule" \
    "! grep -Eqi 'never (reuse|do independent useful work)|do not reuse|avoid reus' '$file'"
done

check 'router requires the bounded pull-request waiter and immediate failure reporting' \
  "grep -Fq 'Use \`bin/ai-pr-wait <pr>\` for a pull request, surface a failing check or queue' '$router'"
check 'router requires useful work during long checks' \
  "grep -Fq 'ejection immediately, and do independent useful work while long checks run.' '$router'"
check 'router requires ownership, reuse justification, and retirement' \
  "grep -Fq 'shared home cannot serve the need, and a retirement or consolidation path.' '$router'"
check 'router routes harness consolidation to issue 167' "grep -Fq 'Harness consolidation belongs to #167' '$router'"
check 'router routes provider sharing to issue 169' "grep -Fq 'provider-wrapper sharing to #169' '$router'"
check 'router routes backlog consolidation to issue 168' "grep -Fq 'plan-backlog consolidation to #168' '$router'"
check 'active throughput plan requires branch, pull request, and merge queue' \
  "grep -Fq 'work lands through a branch, pull request, and merge' '$ROOT/plan_repo-throughput-restructure.md'"
check 'active throughput plan does not direct sessions to work directly on main' \
  "! grep -Eqi 'work (directly )?on .*main([[:space:][:punct:]]|$)|lands directly on .*main([[:space:][:punct:]]|$)' '$ROOT/plan_repo-throughput-restructure.md'"

for file in "$codex" "$claude"; do
  check "$(basename "$file") requires immediate failure and ejection reporting" \
    "grep -Fq 'failing check or queue ejection immediately' '$file'"
  check "$(basename "$file") requires useful work during long checks" \
    "grep -Fq 'do independent useful work' '$file'"
  check "$(basename "$file") rejects long hand-written polling" \
    "grep -Fq 'while long checks run; never burn turns in long hand-written polling loops.' '$file'"
  check "$(basename "$file") requires reuse before copies" \
    "grep -Fq \"Reuse the repository's shared plans, workflows, harnesses, and provider\" '$file'"
  check "$(basename "$file") requires owner, necessity, and retirement" \
    "grep -Fq 'needs an explicit owner, necessity, and consolidation or retirement path.' '$file'"
done

printf '\nSESSION CONDUCT POLICY SUMMARY failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
