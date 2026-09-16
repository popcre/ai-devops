#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOVER="$ROOT/skills/shared/shared-db-handover/SKILL.md"
WRAPUP="$ROOT/skills/shared/wrap-up/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
require() { grep -Fq -- "$2" "$1" || fail "$(basename "$(dirname "$1")") missing contract: $2"; }

require "$HANDOVER" "## Fast close — nothing unfinished: no PR, under 5 minutes (#498)"
require "$HANDOVER" "one comment on your marker issue"
require "$HANDOVER" "do NOT write a \`HANDOFF.d/\` file"
require "$HANDOVER" "gh pr checks <n> --repo u2giants/shared-db --required --watch --interval 30"
require "$HANDOVER" "until gh pr checks <n> --repo u2giants/shared-db --required >/dev/null 2>&1 || [ \$? -eq 8 ]; do sleep 10; done"
require "$HANDOVER" "gh pr merge <n> --repo u2giants/shared-db --squash"
require "$HANDOVER" "**Never** use \`--admin\`"
require "$HANDOVER" "dispatch \`guarded-migration-merge\` for prose"
require "$HANDOVER" "**never** merge \`main\` into the"
require "$WRAPUP" "docs: n/a"
require "$WRAPUP" "secrets: n/a — none appeared"

# The fast route must never recommend an admin merge for shared-db.
if grep -Eq 'gh pr merge[^`]*u2giants/shared-db[^`]*--admin' "$HANDOVER"; then
  fail "shared-db-handover recommends an admin merge"
fi

echo "PASS: shared-db fast close contract"
