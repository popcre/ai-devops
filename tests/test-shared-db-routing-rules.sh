#!/usr/bin/env bash
# Regression for the #1097 -> #1113 successor-routing failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
FIX="$ROOT/tests/fixtures/shared-db-routing/1097-successor-1113.md"
ORCH="$ROOT/docs/shared-db-structural-safety/README.md"
MANUAL="$ROOT/docs/shared-db-structural-safety/references/operating-manual.md"
AUTHORING="$ROOT/skills/codex/codex-shared-db-change/SKILL.md"
CLAUDE="$ROOT/templates/system/CLAUDE-global.md"
CODEX="$ROOT/templates/system/AGENTS-global-codex.md"
REPO_AGENTS="$ROOT/AGENTS.md"

field(){ sed -n "s/^$1:[[:space:]]*//p" "$FIX" | head -1; }
eligible(){ [ "$(field status)" = ready ] && [ "$(field work_type)" = structural ] && [ "$(field route)" = claim-first ] && grep -q '^  - ' "$FIX"; }

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
check "AI review is advice only everywhere (owner 2026-10-29)" "grep -qi 'AI review is advice only' '$REPO_AGENTS'"
check "skill keeps protected claims locked with no author ceiling" "grep -qi 'Protected blocked claims keep every object and version lock' '$ORCH' && grep -qi 'no numeric ceiling on concurrent authors' '$ORCH' && grep -qi 'no numeric ceiling on concurrent authors' '$MANUAL'"
check "manual preserves collision protection after relinquishment" "grep -qi 'protected claim remains in every collision calculation' '$MANUAL'"
check "skill and manual name the guarded relinquish command" "grep -q -- '--relinquish-author-lease' '$ORCH' && grep -q -- '--relinquish-author-lease' '$MANUAL'"
check "skill and manual name the guarded resume command" "grep -q -- '--resume-author-lease' '$ORCH' && grep -q -- '--resume-author-lease' '$MANUAL'"
check "clock expiry releases no protection" "grep -qi 'clock expiry releases no protection' '$ORCH' && grep -qi 'releases no object protection' '$MANUAL'"
check "Phase 2 commands and historical warning stay synchronized" "grep -q -- '--prepare-preview-dispatch <issue>' '$ORCH' && grep -q -- '--repair-preview-ready <ready-id> --issue <n>' '$ORCH' && grep -q 'historical dry-run proves nothing' '$ORCH'"
check "review reservations are per head and session, never a busy wait" "grep -q 'one review per exact head and session' '$ORCH' && grep -q 'never serialize independent reviews by the same provider' '$ORCH' && ! grep -q 'durable ordered waits' '$MANUAL'"
check "both globals route production only through the automatic promotion workflow" "tr '\\r\\n' '  ' < '$CODEX' | grep -q 'Shared-db migrations *reach production only through its automatic promotion workflow' && tr '\\r\\n' '  ' < '$CLAUDE' | grep -q 'Shared-db *migrations reach production only through its automatic promotion workflow'"
check "automatic production never falls back to owner version naming" "grep -q 'never manually reconstruct version or artifact inputs' '$ORCH' && grep -q 'never falls back to asking Albert for migration numbers' '$MANUAL'"
check "automatic production retains engineer refusal and dry-run lock" "grep -q 'engineer action required' '$MANUAL' && grep -q 'fresh dry-run immediately' '$MANUAL' && grep -q 'global production lock' '$MANUAL'"
check "automatic production blocks every derived business-risk class" "grep -q 'All five derived business-risk conclusions must be clear' '$ORCH' && grep -q 'Automatic v2 evidence proceeds only' '$MANUAL' && grep -q 'any risk class stops to an engineer before a database' '$MANUAL'"
check "automatic production independently re-admits actual structural work" "grep -q 'one open linked structural work issue independently admitted' '$ORCH' && grep -q 'current scope plus the PR.s actual migration files' '$MANUAL'"
check "automatic production pins refusal and prior activation evidence" "tr '\\r\\n' '  ' < '$CODEX' | grep -q 'no manual production *command' && grep -q 'let AI launch it and remove that rule' '$ROOT/docs/owner-rulings.md' && tr '\\r\\n' '  ' < '$CLAUDE' | grep -q 'no manual *production command' && grep -q 'owner-rulings.md' '$CODEX' && grep -q 'owner-rulings.md' '$CLAUDE' && grep -q 'This policy cannot authorize its own rollout' '$MANUAL' && grep -q '6e4ea801798dae3ae30648a5e4682bbb3aa06e66' '$MANUAL' && grep -q '7c3e25454561748cd29e24bcfe1f3b4c0d3bdeb6' '$MANUAL'"
check "authoring skill defers only to the activated governed workflow" "grep -q 'sole exception is the separately activated automatic workflow' '$AUTHORING' && grep -q 'never reconstructs it or applies to production' '$AUTHORING' && grep -q 'stops for an engineer' '$AUTHORING'"
check "repository router pins the same automatic promotion route" "grep -q 'through its automatic promotion workflow' '$REPO_AGENTS' && grep -q 'no manual production command' '$REPO_AGENTS'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
