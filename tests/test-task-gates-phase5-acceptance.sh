#!/usr/bin/env bash
# Phase 5 controlled acceptance battery for Issue #335.
# No external action is launched: every protected case is a local Git fixture.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/bin/ai-task-gates"
PASS=0; FAIL=0
. "$ROOT/tests/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_TASK_GATES_DIR="$TMP/state"
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"
EXPENSIVE_LAUNCHES=0
REVIEW_STARTS=0
LONG_WAIT_STARTS=0
START_MS="$(date +%s%3N)"

new_repo() {
  local dir="$1" identity="$2"
  mkdir -p "$dir"
  git init -q --initial-branch=main "$dir"
  git -C "$dir" config user.name Fixture
  git -C "$dir" config user.email fixture@example.invalid
  git -C "$dir" remote add origin "https://github.com/$identity.git"
  printf 'base\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -qm baseline
}

write_policy() {
  local dir="$1" body="$2"
  mkdir -p "$dir/.ai-devops"
  printf '%s\n' "$body" > "$dir/.ai-devops/task-gates.json"
  git -C "$dir" add .ai-devops/task-gates.json
  git -C "$dir" commit -qm policy
}

start() { (cd "$1" && "$GATE" start --class "$2" --reason 'Phase 5 controlled fixture') >/dev/null; }
rc() { local dir="$1" want="$2"; shift 2; (cd "$dir" && "$GATE" "$@") >/dev/null 2>&1; [ "$?" -eq "$want" ]; }
explain() { (cd "$1" && printf '%s\n' "$2" | "$GATE" explain --json --paths-from -); }

printf 'Phase 5 controlled scenarios\n'

# 1. Documentation-only cleanup refuses both paid review and a long PR wait.
new_repo "$TMP/docs" popcre/ai-devops
start "$TMP/docs" prose
printf 'note\n' > "$TMP/docs/notes.md"
check 'documentation-only cleanup refuses paid review before launch' "rc '$TMP/docs' 3 check --before review"
check 'documentation-only cleanup refuses long wait before launch' "rc '$TMP/docs' 3 check --before pr-wait"
check 'documentation-only cleanup retains immediate shipping' "rc '$TMP/docs' 0 check --before ship"

# 2. A prose claim drifting into code is stopped before shipping.
new_repo "$TMP/drift" popcre/ai-devops
start "$TMP/drift" prose
printf 'code\n' > "$TMP/drift/app.js"
check 'docs-to-code drift is stopped before shipping' "rc '$TMP/drift' 3 check --before ship"

# 3. Ordinary code keeps its local-test gate and may use the normal ship path.
new_repo "$TMP/code" popcre/example
start "$TMP/code" code
printf 'code\n' > "$TMP/code/app.js"
code_json="$(explain "$TMP/code" app.js)"
check 'ordinary code retains local tests' "jq -e '.observed_class==\"code\" and (.required_gates|index(\"local-tests\")!=null)' <<<\"\$code_json\""
check 'ordinary code keeps the normal ship path' "rc '$TMP/code' 0 check --before ship"

# 4. Reviewer-safety work retains exact-head independent review.
new_repo "$TMP/reviewer" popcre/ai-devops
cp -R "$ROOT/.ai-devops" "$TMP/reviewer/.ai-devops"
git -C "$TMP/reviewer" add .ai-devops && git -C "$TMP/reviewer" commit -qm policy
start "$TMP/reviewer" reviewer-safety
review_json="$(explain "$TMP/reviewer" bin/ai-review)"
check 'reviewer-safety code retains exact-head independent review' "jq -e '.observed_class==\"reviewer-safety\" and (.required_gates|index(\"exact-head-independent-review\")!=null)' <<<\"\$review_json\""
check 'reviewer-safety work may enter the guarded review path' "rc '$TMP/reviewer' 0 check --before review"

# 5. DesignFlow UI work retains no-self-merge, visual, and authenticated proof.
new_repo "$TMP/ui" popcre/designflow-frontend
write_policy "$TMP/ui" '{"schema_version":1,"paths":[{"glob":"src/**","class":"ui-live-workflow"}],"gates":{"ui-live-workflow":{"required":["sandbox-branch-pr-to-develop","designflow-no-self-merge","visual-proof","authenticated-workflow-proof"],"forbidden_actions":[]}}}'
start "$TMP/ui" ui-live-workflow
ui_json="$(explain "$TMP/ui" src/app.ts)"
check 'DesignFlow UI retains visual, authenticated, and no-self-merge gates' "jq -e '.observed_class==\"ui-live-workflow\" and ([\"visual-proof\",\"authenticated-workflow-proof\",\"designflow-no-self-merge\"]- .required_gates|length==0)' <<<\"\$ui_json\""

# 6. Shared-database structure retains governance and target proof.
new_repo "$TMP/db" u2giants/shared-db
write_policy "$TMP/db" '{"schema_version":1,"paths":[{"glob":"supabase/**","class":"shared-db"}],"gates":{"shared-db":{"required":["repository-branch-and-pr","exact-head-independent-review","target-database-proof-before-write"],"forbidden_actions":[]}}}'
start "$TMP/db" shared-db
db_json="$(explain "$TMP/db" supabase/migrations/001.sql)"
check 'shared-db structure retains branch, review, and target proof' "jq -e '.observed_class==\"shared-db\" and ([\"repository-branch-and-pr\",\"exact-head-independent-review\",\"target-database-proof-before-write\"]- .required_gates|length==0)' <<<\"\$db_json\""
check 'shared-db fixture may enter its governed database path' "rc '$TMP/db' 0 check --before database"

# 7. Licensed evidence stays private and cannot launch an external action.
new_repo "$TMP/private" u2giants/licensor-source-data
write_policy "$TMP/private" '{"schema_version":1,"paths":[{"glob":"outputs/**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["private-repository-only","no-third-party-transmission","provenance-preserved"],"forbidden_actions":["deploy","infrastructure","production"]}}}'
start "$TMP/private" private-evidence
mkdir -p "$TMP/private/outputs"; printf 'synthetic fixture only\n' > "$TMP/private/outputs/fixture.csv"
private_json="$(explain "$TMP/private" outputs/fixture.csv)"
check 'licensed evidence retains privacy and provenance gates' "jq -e '.observed_class==\"private-evidence\" and ([\"private-repository-only\",\"no-third-party-transmission\",\"provenance-preserved\"]- .required_gates|length==0)' <<<\"\$private_json\""
check 'licensed evidence refuses paid review before launch' "rc '$TMP/private' 3 check --before review"

# 8. Infrastructure stays read-only and refuses apply entry points.
new_repo "$TMP/infra" popcre/infrastructure
write_policy "$TMP/infra" '{"schema_version":1,"paths":[{"glob":"**","class":"infrastructure"}],"gates":{"infrastructure":{"required":["branch-and-pr","read-only-baseline","reviewed-plan","exact-resource-owner-authorization"],"forbidden_actions":["infrastructure","production"]}}}'
start "$TMP/infra" infrastructure
printf '# synthetic fixture only\n' > "$TMP/infra/main.tf"
infra_json="$(explain "$TMP/infra" main.tf)"
check 'infrastructure retains plan and exact-resource authorization' "jq -e '.observed_class==\"infrastructure\" and ([\"read-only-baseline\",\"reviewed-plan\",\"exact-resource-owner-authorization\"]- .required_gates|length==0)' <<<\"\$infra_json\""
check 'infrastructure fixture refuses apply entry point' "rc '$TMP/infra' 3 check --before infrastructure"

# 9. Oracle production is allowed only when explicitly declared at production strength.
new_repo "$TMP/oracle" u2giants/theoracle
write_policy "$TMP/oracle" '{"schema_version":1,"paths":[{"glob":".github/workflows/**","class":"deployment"}],"gates":{"deployment":{"required":["repository-workflow-compliance","managed-platform-release-review","exact-owner-action-authorization"],"forbidden_actions":[]}}}'
start "$TMP/oracle" production
oracle_json="$(explain "$TMP/oracle" .github/workflows/release.yml)"
check 'Oracle production intent dominates the observed deployment path' "jq -e '.declared_class==\"production\" and .observed_class==\"deployment\" and .effective_class==\"production\"' <<<\"\$oracle_json\""
check 'Oracle production retains exact resource-and-action authorization' "jq -e '.required_gates|index(\"exact-resource-and-action-authorization\")!=null' <<<\"\$oracle_json\""
check 'Oracle production also retains deployment release review and owner authorization' "jq -e '([\"managed-platform-release-review\",\"exact-owner-action-authorization\",\"local-tests\"]- .required_gates|length==0)' <<<\"\$oracle_json\""
check 'Oracle fixture may enter production only at declared production strength' "rc '$TMP/oracle' 0 check --before production"

# Non-protected owner overrides are recorded, never silent.
check 'explicit owner-request override is accepted for prose review' "rc '$TMP/docs' 0 check --before review --owner-request 'controlled Phase 5 acceptance'"
docs_status="$(cd "$TMP/docs" && "$GATE" status)"
check 'explicit owner-request override is audited' "jq -e '[.overrides[].kind]|index(\"owner-request\")!=null' <<<\"\$docs_status\""

END_MS="$(date +%s%3N)"
ELAPSED_MS=$((END_MS - START_MS))
printf '\nPhase 5 measures: scenarios=9 expensive_gate_launches=%d reviewer_starts=%d long_wait_starts=%d elapsed_ms=%d\n' \
  "$EXPENSIVE_LAUNCHES" "$REVIEW_STARTS" "$LONG_WAIT_STARTS" "$ELAPSED_MS"
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
