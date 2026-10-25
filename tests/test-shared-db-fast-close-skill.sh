#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOVER="$ROOT/skills/shared/shared-db-handover/SKILL.md"
WRAPUP="$ROOT/skills/shared/wrap-up/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
require() { grep -Fq -- "$2" "$1" || fail "$(basename "$(dirname "$1")") missing contract: $2"; }
forbid() { ! grep -Fq -- "$2" "$1" || fail "$(basename "$(dirname "$1")") retains forbidden instruction: $2"; }

require "$HANDOVER" "## Fast close — nothing unfinished: no PR, under 5 minutes (#498)"
require "$HANDOVER" "one comment on the existing work issue"
require "$HANDOVER" "do NOT write a \`HANDOFF.d/\` file"
require "$HANDOVER" "Never use \`--admin\` or"
require "$HANDOVER" "prose-only PRs do not wait for CI"
require "$HANDOVER" "using the merge queue where configured"
require "$HANDOVER" "no orchestrator or marker step"
require "$HANDOVER" "Do not create, resolve, or close markers."
require "$HANDOVER" "supported claim/stage handoff metadata operations remain required"
require "$HANDOVER" "source change #4271 is"
require "$HANDOVER" "clean canonical \`shared-db\` tool worktree at the current merged"
require "$HANDOVER" "Inspect that source's CLI option definitions"
require "$HANDOVER" "this helper has no \`--help\` handler"
require "$HANDOVER" "Run supported flags from"
require "$HANDOVER" "pass the preserved source"
require "$HANDOVER" "with \`--worktree\`"
require "$HANDOVER" "and native"
require "$HANDOVER" "readiness or operation receipts before claiming capability"
require "$HANDOVER" "create-only owner-issued handoff-ready receipt"
require "$HANDOVER" "Known successor: that actual recipient uses"
require "$HANDOVER" "Do not impersonate the predecessor"
require "$HANDOVER" "Dirty, remote, legacy or ambiguous custody"
require "$HANDOVER" "never claim readiness without the actual receipt"
require "$HANDOVER" "Do not open a new ticket."
require "$HANDOVER" "do not create a second issue for its handover or live-proof"
require "$HANDOVER" "Do not open or refresh a second \`db-work\` issue"
require "$HANDOVER" "actual client engine: \`Posted by <Codex or Claude>"
require "$HANDOVER" "popcre/shared-db/scripts/reap-merged-worktrees.mjs"
require "$HANDOVER" "current \`cleanup-worktree\` checks"
require "$HANDOVER" "no marker predicate"
forbid "$HANDOVER" "the skill is \`shared-db-orchestrator\`"
forbid "$HANDOVER" "Open an issue with the \`db-work\` label"
forbid "$HANDOVER" "close it as housekeeping"
forbid "$HANDOVER" "while any \`orchestrator-marker\` issue is open"
forbid "$HANDOVER" "until gh pr checks"
forbid "$HANDOVER" "gh pr checks <n>"
forbid "$HANDOVER" "open its OWN marker"
forbid "$HANDOVER" "Posted by Codex chat <id> on <machine>"
forbid "$HANDOVER" "manage-migration-author-lanes.mjs --help"
require "$WRAPUP" "docs: n/a"
require "$WRAPUP" "secrets: n/a — none appeared"
require "$WRAPUP" "Every owned item must be either"
require "$WRAPUP" "that actual session accepts the exact ready receipt"
require "$WRAPUP" "Preserve dirty or remote work through"
forbid "$HANDOVER" "or immediately acceptable ready receipt"
require "$HANDOVER" "ai-shared-db-closeout-check"
require "$HANDOVER" "An expired, relinquished or handoff-ready claim still owns"
require "$HANDOVER" "actual successor that has accepted"
require "$HANDOVER" "Never add \`--retire\`"
require "$WRAPUP" "ai-shared-db-closeout-check"
require "$WRAPUP" "zero owned open claims and zero owned preview"
require "$WRAPUP" "end the session with its reservation idle."
forbid "$WRAPUP" "shared-database or orchestrator session"

# The fast route must never recommend an admin merge for shared-db, under
# either the current name or the pre-transfer alias.
if grep -Eq 'gh pr merge[^`]*(popcre|u2giants)/shared-db[^`]*--admin' "$HANDOVER"; then
  fail "shared-db-handover recommends an admin merge"
fi

echo "PASS: shared-db fast close contract"
