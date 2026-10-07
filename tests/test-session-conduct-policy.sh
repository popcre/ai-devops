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
  "grep -Fq 'Use \`bin/ai-pr-wait <pr> --timeout-minutes N\` for a pull request, surface a failing check or queue' '$router'"
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
  check "$(basename "$file") keeps canonical checkouts landing-only" \
    "grep -Fq 'Keep canonical checkouts landing-only.' '$file'"
  check "$(basename "$file") requires a worktree before editing" \
    "grep -Fq 'before editing.' '$file'"
  check "$(basename "$file") isolates child repositories in umbrella projects" \
    "grep -Fq 'child Git' '$file'"
done

check 'router makes the canonical checkout landing-only' \
  "grep -Fq 'canonical local checkout is landing-only' '$router'"
check 'router requires write-capable tasks to use worktrees' \
  "grep -Fq 'write-capable Codex or Claude task uses its own current-upstream worktree' '$router'"
check 'router scopes Windows runner exclusion to the physical host or runtime' \
  "grep -Fq 'same physical' '$router' && grep -Fq 'shared installed runtime' '$router'"
check 'router preserves remote and hosted Windows capacity' \
  "grep -Fq 'busy remote self-hosted runner does' '$router' && grep -Fq 'GitHub-hosted and Blacksmith lanes remain' '$router'"
check 'runner guidance routes scheduling decisions through the scoped probe' \
  "grep -Fq 'bin/ai-test-local --check-collision' '$router' && grep -Fq 'bin/ai-test-local --check-collision' '$ROOT/docs/task-router.md'"

# These two instruction-contract cases check the obligations and four-client
# parity, including removal mutations. They do not prove live model behavior.
if ! python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) / "templates/system"
files = [root / name for name in (
    "CLAUDE-global.md", "AGENTS-global-codex.md",
    "AGENTS-global-zcode.md", "AGENTS-global-mimo.md",
)]
blocks = []
for file in files:
    match = re.search(r"^- \*\*Own coordinator progress\.\*\*.*?(?=\n- |\Z)",
                      file.read_text(), re.M | re.S)
    if not match:
        sys.exit(f"FAIL: {file.name} has no coordinator contract")
    blocks.append(" ".join(match.group().split()))
if len(set(blocks)) != 1 or len(blocks[0].split()) > 150:
    sys.exit("FAIL: coordinator contract differs across clients or exceeds 150 words")

cases = (
    ("preparation complete with unresolved dependency is waiting, not assumed active", (
        r"Before claiming agents are working, verify with a fresh message or existing status view",
        r"otherwise report activity unverified",
        r"preparation complete but waiting, blocked needing coordinator action, and complete",
        r"Check at meaningful transitions, not on a polling schedule",
        r"Preparation may legitimately leave agents idle; never invent busywork",
    ), "fresh message or existing status view"),
    ("actionable blocker is acted on and ready work resumes with safe stopping exceptions", (
        r"Act on authorized actionable blockers and resume ready work when dependencies clear",
        r"do not end an execution turn with either untouched",
        r"Escalate material delays promptly with owner, impact and next safe action",
        r"Keep decisions and messaging permissions within existing authority",
        r"Stop when complete, genuinely externally blocked with exact state preserved, or told to stop",
        r"Do not promise background execution the client cannot provide",
    ), "resume ready work when dependencies clear"),
)
for name, obligations, removed in cases:
    covers = lambda text: all(re.search(pattern, text) for pattern in obligations)
    if not all(covers(block) for block in blocks) or covers(blocks[0].replace(removed, "")):
        sys.exit(f"FAIL: {name}")
    print(f"PASS: {name} (four clients; missing obligation rejected)")
PY
then
  failures=$((failures + 1))
fi

printf '\nSESSION CONDUCT POLICY SUMMARY failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
