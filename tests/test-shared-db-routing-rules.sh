#!/usr/bin/env bash
# Regression for the #1097 -> #1113 successor-routing failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
FIX="$ROOT/tests/fixtures/shared-db-routing/1097-successor-1113.md"
ORCH="$ROOT/skills/shared/shared-db-orchestrator/SKILL.md"
MANUAL="$ROOT/skills/shared/shared-db-orchestrator/references/operating-manual.md"
CLAUDE="$ROOT/templates/system/CLAUDE-global.md"
CODEX="$ROOT/templates/system/AGENTS-global-codex.md"
REPO_AGENTS="$ROOT/AGENTS.md"

field(){ sed -n "s/^$1:[[:space:]]*//p" "$FIX" | head -1; }
eligible(){ [ "$(field status)" = ready ] && [ "$(field work_type)" = structural ] && [ "$(field route)" = shared-db-orchestrator ] && grep -q '^  - ' "$FIX"; }

echo '== shared-db source routing'
check "fixture names the predecessor" "grep -q '#1097' '$FIX'"
check "successor classifies its own work" "test \"\$(field work_type)\" = application-data"
check "successor routes to application session" "test \"\$(field route)\" = application-session"
check "non-structural successor is rejected from author lane" "! eligible"
check "fixture claims no database objects" "! grep -q '^  - ' '$FIX'"
check "orchestrator forbids inherited successor route" "grep -qi 'inherit.*predecessor issue' '$ORCH'"
check "manual requires reclassification from scratch" "grep -qi 'successor issue must write this block from scratch' '$MANUAL'"
check "Codex global carries successor rule" "grep -qi 'Route every successor from its own work' '$CODEX'"
check "Claude global carries successor rule" "grep -qi 'Route every successor from its own work' '$CLAUDE'"
check "misroute preserves private artifacts" "grep -qi 'private artifact' '$ORCH'"
check "review safety gate is scoped to this toolkit, not every project" "grep -qi 'Independent review is required for the reviewer safety path' '$REPO_AGENTS' && grep -qi 'Ordinary plans' '$REPO_AGENTS'"
check "skill separates protected claims from active-author capacity" "grep -qi 'Protected blocked claims do not consume active-author capacity' '$ORCH'"
check "manual preserves collision protection after relinquishment" "grep -qi 'protected claim remains in every collision calculation' '$MANUAL'"
check "skill and manual name the guarded relinquish command" "grep -q -- '--relinquish-author-lease' '$ORCH' && grep -q -- '--relinquish-author-lease' '$MANUAL'"
check "skill and manual name the guarded resume command" "grep -q -- '--resume-author-lease' '$ORCH' && grep -q -- '--resume-author-lease' '$MANUAL'"
check "clock expiry releases neither protection nor capacity" "grep -qi 'Clock expiry releases neither protection nor capacity' '$ORCH' && grep -qi 'releases neither object protection nor active-author capacity' '$MANUAL'"
check "Phase 2 commands and historical warning stay synchronized" "grep -q -- '--prepare-preview-dispatch <issue>' '$ORCH' && grep -q -- '--repair-preview-ready <ready-id> --issue <n>' '$ORCH' && grep -q 'historical dry-run proves nothing' '$ORCH'"
check "review reservations use provider execution identity" "grep -q 'provider/wrapper execution keys' '$ORCH'"
check "both globals carry only the governed automatic production exception" "grep -q 'sole narrow exception is .*shared-db.*activated automatic migration' '$CODEX' && grep -q 'sole narrow exception is .*shared-db.*activated automatic migration' '$CLAUDE'"
check "automatic production never falls back to owner version naming" "grep -q 'never manually reconstruct version or artifact inputs' '$ORCH' && grep -q 'never falls back to asking Albert for migration numbers' '$MANUAL'"
check "automatic production retains engineer refusal and dry-run lock" "grep -q 'engineer action required' '$MANUAL' && grep -q 'fresh dry-run immediately' '$MANUAL' && grep -q 'global production lock' '$MANUAL'"
check "automatic production independently re-admits actual structural work" "grep -q 'one open linked structural work issue independently admitted' '$ORCH' && grep -q 'current scope plus the PR.s actual migration files' '$MANUAL' && grep -q 'one open structural work' '$CODEX' && grep -q 'one open structural work' '$CLAUDE'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
