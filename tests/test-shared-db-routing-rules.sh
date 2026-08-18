#!/usr/bin/env bash
# Regression for the #1097 -> #1113 successor-routing failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
FIX="$ROOT/tests/fixtures/shared-db-routing/1097-successor-1113.md"
ORCH="$ROOT/skills/shared/shared-db-orchestrator/SKILL.md"
MANUAL="$ROOT/skills/shared/shared-db-orchestrator/references/operating-manual.md"
CLAUDE="$ROOT/templates/system/CLAUDE-global.md"
CODEX="$ROOT/templates/system/AGENTS-global-codex.md"

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
check "review safety gate is scoped, not blanket" "grep -qi 'Independent review is required for the reviewer safety path' '$CODEX' && grep -qi 'Ordinary plans' '$CODEX'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
