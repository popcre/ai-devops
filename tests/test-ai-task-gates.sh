#!/usr/bin/env bash
# bin/ai-task-gates — task classification and gate enforcement.
#
# The awkward cases are the point: a repository with no remote, a linked
# worktree, a detached HEAD, a rename that hides a migration behind a Markdown
# name, an untracked file that quietly turns a documentation task into a
# reviewer-safety task, and two tasks running side by side.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$ROOT/bin/ai-task-gates"
CLASSIFY="$ROOT/tools/ci/classify-changes.sh"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_TASK_GATES_DIR="$TMP/state"
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"

command -v jq >/dev/null 2>&1 || { printf 'jq is required for this suite\n' >&2; exit 1; }

# rc <expected> <dir> <args...> — run ai-task-gates in <dir> and compare status.
rc(){ local want="$1" dir="$2" got; shift 2; ( cd "$dir" && "$GATES" "$@" ) >/dev/null 2>&1; got=$?; [ "$got" -eq "$want" ]; }
out(){ local dir="$1"; shift; ( cd "$dir" && "$GATES" "$@" ) 2>&1; }

# newrepo <path> [origin-identity] — a repository with one commit on main.
newrepo(){
  local dir="$1" identity="${2-popcre/ai-devops}"
  mkdir -p "$dir"
  git init -q --initial-branch=main "$dir"
  git -C "$dir" config user.name T; git -C "$dir" config user.email t@e
  [ -z "$identity" ] || git -C "$dir" remote add origin "https://github.com/$identity.git"
  printf 'base\n' > "$dir/README.md"
  git -C "$dir" add -A; git -C "$dir" commit -qm init
}

# The state file lives outside the repository and is named by a digest, so find
# it by the worktree path the tool itself recorded.
state_file_for(){
  local wt; wt="$( cd "$1" && "$GATES" status 2>/dev/null | jq -r '.worktree // empty' )"
  [ -n "$wt" ] || return 0
  grep -rlF -- "$wt" "$AI_TASK_GATES_DIR" 2>/dev/null | head -1
}

printf 'classification\n'

newrepo "$TMP/class"
class_of(){ ( cd "$TMP/class" && printf '%s\n' "$1" | "$GATES" explain --json --paths-from - ) | jq -r .observed_class; }
while IFS='|' read -r path want; do
  [ -n "$path" ] || continue
  got="$(class_of "$path")"
  if [ "$got" = "$want" ]; then ok "$path -> $want"; else bad "$path -> $want (got ${got:-<empty>})"; fi
done <<'TABLE'
docs/notes.md|prose
HANDOFF.md|prose
notes.txt|prose
tools/ci/helper.sh|code
build.ps1|code
skills/shared/x/SKILL.md|code
.github/workflows/verify.yml|code
bin/ai-review-lifecycle|reviewer-safety
bin/ai-task-gates|reviewer-safety
tools/lib/task-gates.sh|reviewer-safety
config/task-gates.json|reviewer-safety
services/api/Dockerfile|deployment
infra/main.tf|infrastructure
db/migrations/001_init.sql|shared-db
TABLE

mixed="$(printf 'docs/a.md\nbin/ai-review-lifecycle\ntools/x.sh\n' | ( cd "$TMP/class" && "$GATES" explain --json --paths-from - ))"
check 'mixed change set takes the strongest class' "jq -e '.observed_class==\"reviewer-safety\"' <<<\"\$mixed\""
check 'every changed path is still classified individually' "jq -e '.changes|length==3' <<<\"\$mixed\""
check 'unmatched path falls back to code, not to the strongest class' \
  "[ \"\$(class_of 'random/thing.bin')\" = code ]"

newrepo "$TMP/db-canonical" popcre/shared-db
newrepo "$TMP/db-redirected" u2giants/shared-db
db_canonical="$(cd "$TMP/db-canonical" && printf 'migrations/001.sql\n' | "$GATES" explain --json --paths-from -)"
db_redirected="$(cd "$TMP/db-redirected" && printf 'migrations/001.sql\n' | "$GATES" explain --json --paths-from -)"
check 'canonical shared-db identity retains the structural class and gates' \
  "jq -e '.observed_class==\"shared-db\" and ([\"governed-issue-claim\",\"preview-target-proof\",\"production-promotion-authorization\"]- .required_gates|length==0)' <<<\"\$db_canonical\""
check 'redirected pre-transfer shared-db identity retains identical structural gates' \
  "[ \"\$(jq -cS '[.observed_class,.required_gates,.forbidden_actions]' <<<\"\$db_canonical\")\" = \"\$(jq -cS '[.observed_class,.required_gates,.forbidden_actions]' <<<\"\$db_redirected\")\" ]"

printf 'consumer declarations\n'
mkdir -p "$TMP/class/.ai-devops"
cat > "$TMP/class/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"bin/ai-review-lifecycle","class":"prose"},{"glob":"docs/runbook.md","class":"deployment"}]}
EOF
check 'a local rule cannot downgrade a protected class' "[ \"\$(class_of 'bin/ai-review-lifecycle')\" = reviewer-safety ]"
check 'a local rule may strengthen a class' "[ \"\$(class_of 'docs/runbook.md')\" = deployment ]"

# The first real consumer declaration is this repository's own. It must retain
# the central reviewer-safety class even if a second local rule tries to lower
# it, and it must strengthen installer paths without disabling installation.
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/class/.ai-devops/task-gates.json"
check 'the ai-devops pilot retains reviewer-safety for the review front door' \
  "[ \"\$(class_of 'bin/ai-review')\" = reviewer-safety ]"
check 'the ai-devops pilot protects the pull-request wait gate' \
  "[ \"\$(class_of 'bin/ai-pr-wait')\" = reviewer-safety ]"
check 'the ai-devops pilot protects the policy validator' \
  "[ \"\$(class_of 'tools/ci/validate-task-gates.py')\" = reviewer-safety ]"
check 'the ai-devops pilot protects its own declaration' \
  "[ \"\$(class_of '.ai-devops/task-gates.json')\" = reviewer-safety ]"
check 'the ai-devops pilot classifies Windows installation separately' \
  "[ \"\$(class_of 'bin/install-machine-tools.ps1')\" = installation ]"
git -C "$TMP/class" add .ai-devops/task-gates.json
git -C "$TMP/class" commit -qm 'add pilot declaration'
printf '#!/usr/bin/env bash\n' > "$TMP/class/install.sh"
check 'installation refuses deployment without an owner request' \
  "rc 3 '$TMP/class' check --before deploy"
check 'an explicit owner request preserves the supported installation path' \
  "rc 0 '$TMP/class' check --before deploy --owner-request 'Albert requested installation'"
rm -f "$TMP/class/install.sh"
jq '.paths += [{"glob":"bin/ai-review","class":"prose"}]' \
  "$TMP/class/.ai-devops/task-gates.json" > "$TMP/class/.ai-devops/task-gates.tmp"
mv "$TMP/class/.ai-devops/task-gates.tmp" "$TMP/class/.ai-devops/task-gates.json"
check 'the ai-devops pilot cannot weaken the central reviewer class' \
  "[ \"\$(class_of 'bin/ai-review')\" = reviewer-safety ]"
# A corrupt local declaration must stop the run, not silently drop the stricter
# local rules and carry on with the central ones.
printf 'not json at all
' > "$TMP/class/.ai-devops/task-gates.json"
check 'a corrupt consumer declaration refuses to classify'   "rc 4 '$TMP/class' explain"
check 'the refusal names the declaration file'   "( cd '$TMP/class' && \"$GATES\" explain 2>&1 ) | grep -q 'not valid JSON'"
check 'a corrupt consumer declaration also fails closed before an action'   "rc 4 '$TMP/class' check --before ship"
rm -rf "$TMP/class/.ai-devops"

printf 'the complete change set\n'
newrepo "$TMP/set"
( cd "$TMP/set" && "$GATES" start --class prose --reason 'docs only' ) >/dev/null

printf 'x\n' > "$TMP/set/docs.md"
check 'untracked prose keeps a prose task' "rc 0 '$TMP/set' check --before ship"
mkdir -p "$TMP/set/bin"; printf '#!/bin/sh\n' > "$TMP/set/bin/ai-review-lifecycle"
check 'an untracked reviewer file blocks the declared prose task' "rc 3 '$TMP/set' check --before ship"
check 'the protected escalation cannot be acknowledged away' \
  "rc 3 '$TMP/set' check --before ship --acknowledge 'in scope'"
check 'the block names the file that escalated the class' \
  "out '$TMP/set' check --before ship | grep -Fq 'bin/ai-review-lifecycle'"
rm -rf "$TMP/set/bin"

git -C "$TMP/set" add -A >/dev/null 2>&1; git -C "$TMP/set" commit -qm docs
mkdir -p "$TMP/set/db/migrations"; printf 'select 1;\n' > "$TMP/set/db/migrations/001.sql"
git -C "$TMP/set" add -A >/dev/null; git -C "$TMP/set" commit -qm mig
git -C "$TMP/set" switch -qc work
git -C "$TMP/set" rm -q "db/migrations/001.sql"
check 'a deleted migration is still classified as shared-db' \
  "[ \"\$( out '$TMP/set' explain --json --base main | jq -r .observed_class )\" = shared-db ]"

git -C "$TMP/set" reset -q --hard HEAD
mkdir -p "$TMP/set/docs"
git -C "$TMP/set" mv "db/migrations/001.sql" "docs/moved.md"
git -C "$TMP/set" commit -qm rename
renamed="$(out "$TMP/set" explain --json --base main)"
check 'a rename classifies both sides, so the migration is not hidden' \
  "jq -e '.observed_class==\"shared-db\"' <<<\"\$renamed\""
check 'the renamed-away source path is present in the change set' \
  "jq -e '[.changes[].path]|index(\"db/migrations/001.sql\")!=null' <<<\"\$renamed\""

printf 'awkward repositories\n'

newrepo "$TMP/with spaces"
( cd "$TMP/with spaces" && "$GATES" start --class prose ) >/dev/null
printf 'x\n' > "$TMP/with spaces/note one.md"
check 'a worktree path with spaces still classifies' "rc 0 '$TMP/with spaces' check --before ship"
check 'a changed path with spaces is not split' \
  "out '$TMP/with spaces' explain --json | jq -e '[.changes[].path]|index(\"note one.md\")!=null'"

newrepo "$TMP/noremote" ""
printf 'x\n' > "$TMP/noremote/a.md"
check 'a repository with no remote still resolves a local identity' \
  "out '$TMP/noremote' explain --json | jq -e '.identity_resolved==false and (.repository|startswith(\"local/\"))'"
check 'an unresolved identity may still ship' "rc 0 '$TMP/noremote' check --before ship"
check 'an unresolved identity fails closed before production' "rc 4 '$TMP/noremote' check --before production"
check 'an unresolved identity fails closed before infrastructure' "rc 4 '$TMP/noremote' check --before infrastructure"

mkdir -p "$TMP/fresh"; git init -q --initial-branch=main "$TMP/fresh"
git -C "$TMP/fresh" config user.name T; git -C "$TMP/fresh" config user.email t@e
git -C "$TMP/fresh" remote add origin https://github.com/popcre/ai-devops.git
printf 'x\n' > "$TMP/fresh/README.md"
check 'a repository with no commits classifies its working tree' \
  "[ \"\$( out '$TMP/fresh' explain --json | jq -r .observed_class )\" = prose ]"

newrepo "$TMP/detached"
git -C "$TMP/detached" checkout -q --detach HEAD
printf 'x\n' > "$TMP/detached/note.md"
check 'a detached HEAD still classifies the working tree' \
  "[ \"\$( out '$TMP/detached' explain --json | jq -r .observed_class )\" = prose ]"

newrepo "$TMP/clean"
check 'no changes at all allows the action' "rc 0 '$TMP/clean' check --before ship"
check 'no changes and no declaration fail closed before production' "rc 4 '$TMP/clean' check --before production"
( cd "$TMP/clean" && "$GATES" start --class production ) >/dev/null
check 'a declared production task retains its production gate with no file change' \
  "out '$TMP/clean' explain --json | jq -e '.observed_class==\"none\" and .effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-authorization\")!=null)'"
check 'a declared production task may enter its guarded production path' \
  "rc 0 '$TMP/clean' check --before production"

printf 'stale and corrupt intent state\n'
newrepo "$TMP/stale"
( cd "$TMP/stale" && "$GATES" start --class prose ) >/dev/null
statepath="$(state_file_for "$TMP/stale")"
check 'start records the worktree it belongs to' "[ -n \"\$statepath\" ]"
jq '.base="0000000000000000000000000000000000000000"' "$statepath" > "$statepath.n" && mv "$statepath.n" "$statepath"
printf 'x\n' > "$TMP/stale/note.md"
check 'a stale recorded base falls back instead of failing' "rc 0 '$TMP/stale' check --before ship"
printf 'not json at all\n' > "$statepath"
check 'corrupt intent state does not crash the check' "rc 0 '$TMP/stale' check --before ship"
jq -n '{schema_version:1,declared_class:"made-up-class"}' > "$statepath"
check 'an unknown recorded class fails closed' "rc 4 '$TMP/stale' check --before ship"
rm -f "$statepath"

printf 'worktrees and concurrent tasks\n'
newrepo "$TMP/main-checkout"
git -C "$TMP/main-checkout" worktree add -q -b side "$TMP/side-worktree" >/dev/null 2>&1
( cd "$TMP/main-checkout" && "$GATES" start --class prose ) >/dev/null
( cd "$TMP/side-worktree" && "$GATES" start --class code ) >/dev/null
check 'a linked worktree keeps its own declared class' \
  "[ \"\$( out '$TMP/side-worktree' status | jq -r .declared_class )\" = code ]"
check 'the parent checkout is unaffected by the worktree task' \
  "[ \"\$( out '$TMP/main-checkout' status | jq -r .declared_class )\" = prose ]"
check 'both worktrees resolve to the same repository identity' \
  "[ \"\$( out '$TMP/side-worktree' status | jq -r .identity )\" = \"\$( out '$TMP/main-checkout' status | jq -r .identity )\" ]"
check 'no intent state is written inside the repository' \
  "[ -z \"\$(git -C '$TMP/main-checkout' status --porcelain)\" ]"
( cd "$TMP/main-checkout" && "$GATES" end ) >/dev/null
check 'ending one task leaves the other task recorded' \
  "[ \"\$( out '$TMP/side-worktree' status | jq -r .declared_class )\" = code ]"

printf 'submodules\n'
newrepo "$TMP/sub-child"
newrepo "$TMP/sub-parent"
if git -C "$TMP/sub-parent" -c protocol.file.allow=always submodule add -q "$TMP/sub-child" vendor/child >/dev/null 2>&1; then
  git -C "$TMP/sub-parent" commit -qm 'add submodule'
  printf 'drift\n' >> "$TMP/sub-parent/vendor/child/README.md"
  printf 'x\n' > "$TMP/sub-parent/note.md"
  check 'a dirty submodule is not treated as a documentation change' \
    "[ \"\$( out '$TMP/sub-parent' explain --json | jq -r .observed_class )\" = code ]"
  check 'a dirty submodule is surfaced in the change set' \
    "out '$TMP/sub-parent' explain --json | jq -e '[.changes[].path]|index(\"vendor/child\")!=null'"
else
  ok 'submodule case skipped: local submodule transport is disabled'
fi

printf 'gates and overrides\n'
newrepo "$TMP/gate"
( cd "$TMP/gate" && "$GATES" start --class prose ) >/dev/null
printf 'x\n' > "$TMP/gate/note.md"
check 'a paid review is refused for a documentation change' "rc 3 '$TMP/gate' check --before review"
check 'a long PR wait is refused for a documentation change' "rc 3 '$TMP/gate' check --before pr-wait"
check 'an owner request lifts a non-protected forbidden action' \
  "rc 0 '$TMP/gate' check --before review --owner-request 'Albert asked for a review'"
check 'the owner request is recorded in the intent state' \
  "out '$TMP/gate' status | jq -e '[.overrides[].kind]|index(\"owner-request\")!=null'"
( cd "$TMP/gate" && "$GATES" start --class production ) >/dev/null
printf 'x\n' > "$TMP/gate/note.md"
check 'a stronger declared class supplies the effective gates' \
  "out '$TMP/gate' explain --json | jq -e '.observed_class==\"prose\" and .effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-authorization\")!=null)'"
check 'a stronger declared class does not drop observed-class required proof' \
  "out '$TMP/gate' explain --json | jq -e '.required_gates|index(\"exact-resource-and-action-authorization\")!=null'"
rm -f "$TMP/gate/note.md"
( cd "$TMP/gate" && "$GATES" start --class prose ) >/dev/null
mkdir -p "$TMP/gate/bin"; printf '#!/bin/sh\n' > "$TMP/gate/bin/ai-review-lifecycle"
check 'a protected class cannot be owner-requested past a forbidden action' \
  "rc 3 '$TMP/gate' check --before production --owner-request 'please'"
rm -rf "$TMP/gate/bin"
printf 'select 1;\n' > "$TMP/gate/x.sql"
check 'shared-db work is refused a deployment' "rc 3 '$TMP/gate' check --before deploy"
rm -f "$TMP/gate/x.sql"

printf 'licensor-source-data tooling exception\n'
newrepo "$TMP/lsd" u2giants/licensor-source-data
lsd_class_of(){ ( cd "$TMP/lsd" && printf '%s\n' "$1" | "$GATES" explain --json --paths-from - ) | jq -r .observed_class; }
while IFS='|' read -r path want; do
  [ -n "$path" ] || continue
  got="$(lsd_class_of "$path")"
  if [ "$got" = "$want" ]; then ok "lsd $path -> $want"; else bad "lsd $path -> $want (got ${got:-<empty>})"; fi
done <<'TABLE'
warner-bros/scripts/check-weekly-capture.mjs|private-tooling
warner-bros/scripts/test-check-weekly-capture.mjs|private-tooling
warner-bros/README.md|private-evidence
warner-bros/assets.csv|private-evidence
warner-bros/capture-state.json|private-evidence
warner-bros/contracts/inventory-private.json|private-evidence
warner-bros/manifest/assets.csv|private-evidence
warner-bros/deltas/2026-08-20T0445Z/summary.json|private-evidence
TABLE
check 'tooling-only change set is private-tooling' \
  "[ \"\$( ( cd '$TMP/lsd' && printf '%s\n' warner-bros/scripts/check-weekly-capture.mjs warner-bros/scripts/test-check-weekly-capture.mjs | \"$GATES\" explain --json --paths-from - ) | jq -r .observed_class )\" = private-tooling ]"
check 'one licensed row pulls the whole change set back to private-evidence' \
  "[ \"\$( ( cd '$TMP/lsd' && printf '%s\n' warner-bros/scripts/check-weekly-capture.mjs warner-bros/assets.csv | \"$GATES\" explain --json --paths-from - ) | jq -r .observed_class )\" = private-evidence ]"
( cd "$TMP/lsd" && "$GATES" start --class private-tooling ) >/dev/null
mkdir -p "$TMP/lsd/warner-bros/scripts"
printf '#!/usr/bin/env node\n' > "$TMP/lsd/warner-bros/scripts/check-weekly-capture.mjs"
check 'tooling-only Warner work still refuses a formal review' \
  "rc 3 '$TMP/lsd' check --before review"
check 'tooling-only Warner work may ship without that review' \
  "rc 0 '$TMP/lsd' check --before ship"
printf 'id,name\n1,secret\n' > "$TMP/lsd/warner-bros/assets.csv"
check 'a higher-ranked declaration cannot outrank licensed rows' \
  "out '$TMP/lsd' explain --json | jq -e '.effective_class==\"private-evidence\"'"
check 'and the refusal still names the protected class' \
  "out '$TMP/lsd' check --before review | grep -Fq 'private-evidence'"
check 'the protected stop does not claim an owner resource unlock' \
  "! out '$TMP/lsd' check --before review --owner-request 'please' | grep -Fq 'exact resource and action'"
check 'the protected stop says there is no owner-request path' \
  "out '$TMP/lsd' check --before review --owner-request 'please' | grep -Fq 'no owner-request'"
rm -f "$TMP/lsd/warner-bros/assets.csv"

printf 'private code review keeps evidence and mutation boundaries\n'
newrepo "$TMP/private" 'u2giants/licensor-source-data'
mkdir -p "$TMP/private/disney-dcpvault" "$TMP/private/.ai-devops"
printf '# synthetic loader code only\n' > "$TMP/private/disney-dcpvault/loader.py"
cat > "$TMP/private/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"disney-dcpvault/**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]},"private-tooling":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]}}}
EOF
( cd "$TMP/private" && "$GATES" start --class private-tooling ) >/dev/null
check 'the sealed route needs no owner request or acknowledgement' \
  "rc 0 '$TMP/private' check --before code-only-review"
check 'the formal review stays forbidden on the same change set' \
  "rc 3 '$TMP/private' check --before review"
check 'and that refusal still has no owner-request path' \
  "out '$TMP/private' check --before review --owner-request 'please' | grep -Fq 'no owner-request'"
check 'the sealed route retains central and consumer evidence requirements' \
  "out '$TMP/private' explain --json | jq -e '.effective_class==\"private-evidence\" and ([\"privacy-classification\",\"no-raw-content-read\",\"licensed-row-containment\",\"synthetic-fixtures-only\"] - .required_gates | length==0)'"
check 'private-evidence remains protected at its existing rank' \
  "jq -e '.change_classes[\"private-evidence\"] | .protected==true and .rank==90' '$AI_TASK_GATES_FILE'"
for action in deploy database infrastructure production; do
  check "private code review cannot authorize $action even with owner override" \
    "rc 3 '$TMP/private' check --before '$action' --owner-request 'review requested' --acknowledge 'in scope'"
done
# A declaration on the weaker tooling class must not open the route for a
# sticky private-evidence change set: the opt-in is proven by the effective
# class's own gates.
printf 'id,name\n1,secret\n' > "$TMP/private/disney-dcpvault/rows.csv"
cat > "$TMP/private/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"disney-dcpvault/**","class":"private-evidence"}],"gates":{"private-tooling":{"required":["synthetic-fixtures-only"]}}}
EOF
( cd "$TMP/private" && "$GATES" start --class private-tooling ) >/dev/null
check 'a tooling-only declaration cannot open the route for licensed rows' \
  "rc 3 '$TMP/private' check --before code-only-review"
check 'and that stop still names the missing fixtures boundary' \
  "out '$TMP/private' check --before code-only-review | grep -Fq 'synthetic-fixtures-only'"
rm -f "$TMP/private/disney-dcpvault/rows.csv"
cat > "$TMP/private/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"disney-dcpvault/**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]},"private-tooling":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]}}}
EOF
( cd "$TMP/private" && "$GATES" start --class code ) >/dev/null
check 'private code still requires honest protected-class declaration' \
  "rc 3 '$TMP/private' check --before review --acknowledge 'read only'"
( cd "$TMP/private" && "$GATES" start --class private-tooling ) >/dev/null
cat > "$TMP/private/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"gates":{"private-evidence":{"forbidden_actions":["review"]}}}
EOF
check 'an explicit consumer review prohibition remains binding' \
  "rc 3 '$TMP/private' check --before review --owner-request 'review requested'"
check 'the sealed route closes once the fixtures declaration is gone' \
  "rc 3 '$TMP/private' check --before code-only-review"
check 'and the stop names the missing fixtures boundary' \
  "out '$TMP/private' check --before code-only-review | grep -Fq 'synthetic-fixtures-only'"

printf 'a private repository that never declared the boundary stays closed\n'
newrepo "$TMP/private-closed" 'u2giants/licensor-source-data'
mkdir -p "$TMP/private-closed/scripts"
printf '#!/bin/sh\n' > "$TMP/private-closed/scripts/check.sh"
( cd "$TMP/private-closed" && "$GATES" start --class private-tooling ) >/dev/null
check 'no local declaration means no sealed code-only review' \
  "rc 3 '$TMP/private-closed' check --before code-only-review"
check 'and the stop says which gate is missing' \
  "out '$TMP/private-closed' check --before code-only-review | grep -Fq 'synthetic-fixtures-only'"
check 'the formal review is still refused there' \
  "rc 3 '$TMP/private-closed' check --before review"

# A clean private checkout has an EMPTY change set, so the sealed route's
# proof binding must be judged against the complete repository inventory,
# never against an absent or leftover declaration (two exact-head review
# findings on the reconciliation head, 2026-09-25).
newrepo "$TMP/private-clean" 'u2giants/licensor-source-data'
check 'a clean undeclared private tree refuses the sealed route' \
  "rc 3 '$TMP/private-clean' check --before code-only-review"
check 'and the stop names the missing fixtures boundary' \
  "out '$TMP/private-clean' check --before code-only-review | grep -Fq 'synthetic-fixtures-only'"
check 'while an unbound action still starts on the same clean tree' \
  "rc 0 '$TMP/private-clean' check --before pr-wait"
( cd "$TMP/private-clean" && "$GATES" start --class code ) >/dev/null
check 'a leftover plain-code declaration does not open the sealed route' \
  "rc 3 '$TMP/private-clean' check --before code-only-review"
check 'that stop is the protected-class escalation, not a fixtures pass' \
  "out '$TMP/private-clean' check --before code-only-review | grep -Fq 'escalated'"

printf 'a public repository may use the sealed route freely\n'
newrepo "$TMP/public-code"
mkdir -p "$TMP/public-code/bin"
printf '#!/bin/sh\n' > "$TMP/public-code/bin/tool.sh"
( cd "$TMP/public-code" && "$GATES" start --class code ) >/dev/null
check 'a public code change may start a sealed code-only review' \
  "rc 0 '$TMP/public-code' check --before code-only-review"

printf 'an undeclared task still gets classified\n'

newrepo "$TMP/undeclared"
printf 'x\n' > "$TMP/undeclared/note.md"
check 'no declared class falls back to the observed class' "rc 3 '$TMP/undeclared' check --before review"
check 'and says so plainly' "out '$TMP/undeclared' check --before review | grep -Fq 'no task class was declared'"

printf 'existing contracts stay green\n'
legacy="$(printf 'docs/a.md\nREADME.md\n' | bash "$CLASSIFY" pull_request)"
check 'prose-only pull request still bypasses the long suite' \
  "grep -Fqx 'prose_only=true' <<<\"\$legacy\" && grep -Fqx 'run_long=false' <<<\"\$legacy\""
legacy2="$(printf 'bin/ai-task-gates\n' | bash "$CLASSIFY" pull_request)"
check 'a code change still runs the long suite' \
  "grep -Fqx 'prose_only=false' <<<\"\$legacy2\" && grep -Fqx 'code=true' <<<\"\$legacy2\""
legacy3="$(printf 'docs/a.md\n' | bash "$CLASSIFY" push)"
check 'only pull requests may use the prose bypass' "grep -Fqx 'run_long=true' <<<\"\$legacy3\""
subcmd="$(printf 'docs/a.md\n' | "$GATES" classify pull_request)"
standalone="$(printf 'docs/a.md\n' | bash "$CLASSIFY" pull_request)"
check 'the classifier subcommand matches the standalone script' "[ \"\$subcmd\" = \"\$standalone\" ]"

printf 'usage\n'
check 'an unknown action is a usage error, not a silent allow' "rc 1 '$TMP/gate' check --before teleport"
check 'an unknown class is a usage error' "rc 1 '$TMP/gate' start --class imaginary"
check 'version prints' "out '$TMP/gate' version | grep -q '^ai-task-gates '"

printf 'installed on PATH through a symlink\n'
# install.sh symlinks every bin/* into /usr/local/bin, and bash reports the
# symlink path in BASH_SOURCE. A gate that resolved its library and policy from
# that path would find neither, and would then either die or allow everything.
LINKDIR="$TMP/usrlocalbin"; mkdir -p "$LINKDIR"
if ln -s "$ROOT/bin/ai-task-gates" "$LINKDIR/ai-task-gates" 2>/dev/null && [ -L "$LINKDIR/ai-task-gates" ]; then
  check 'the gate still runs when invoked through its installed symlink' \
    "env -u AI_TASK_GATES_FILE '$LINKDIR/ai-task-gates' version >/dev/null"
  check 'the gate still classifies when invoked through its installed symlink' \
    "( cd '$TMP/class' && printf 'bin/ai-review-lifecycle\n' | env -u AI_TASK_GATES_FILE '$LINKDIR/ai-task-gates' explain --json --paths-from - ) | jq -e '.observed_class==\"reviewer-safety\"' >/dev/null"
else
  printf '  skip symlink cases (this filesystem does not make real symlinks)\n'
fi

# A copy that is genuinely detached from the repository - no symlink to follow -
# must refuse loudly rather than run with no policy and allow everything.
ORPHAN="$TMP/orphan"; mkdir -p "$ORPHAN"; cp "$ROOT/bin/ai-task-gates" "$ORPHAN/ai-task-gates"
ORPHAN_OUT="$( cd "$TMP/class" && env -u AI_TASK_GATES_FILE "$ORPHAN/ai-task-gates" version 2>&1 )"; ORPHAN_RC=$?
check 'a gate detached from its library refuses instead of allowing' "[ '$ORPHAN_RC' -eq 4 ]"
check 'and says what it could not find' \
  "printf '%s' \"\$ORPHAN_OUT\" | grep -q 'tools/lib/task-gates.sh'"

printf 'the policy matches its published schema\n'
VALIDATE="$ROOT/tools/ci/validate-task-gates.py"
PY_BIN="$(command -v python3 || command -v python)"
check 'the shipped contract validates against the schema' \
  "'$PY_BIN' '$VALIDATE' '$ROOT/config/task-gates.json'"
check 'the ai-devops pilot declaration validates against the schema' \
  "'$PY_BIN' '$VALIDATE' '$ROOT/.ai-devops/task-gates.json'"
SCHEMA_TMP="$TMP/schema"; mkdir -p "$SCHEMA_TMP"
"$PY_BIN" - "$SCHEMA_TMP" "$ROOT/config/task-gates.json" <<'EOF'
import json, pathlib, sys
out, src = pathlib.Path(sys.argv[1]), sys.argv[2]
base = json.loads(pathlib.Path(src).read_text(encoding='utf-8'))
weak = json.loads(json.dumps(base)); weak['default']['fallback_class'] = 'prose'
(out / 'weak.json').write_text(json.dumps(weak), encoding='utf-8')
ghost = json.loads(json.dumps(base)); ghost['default']['paths'].append({'glob': 'x', 'class': 'invented'})
(out / 'ghost.json').write_text(json.dumps(ghost), encoding='utf-8')
stray = json.loads(json.dumps(base)); stray['surprise'] = 1
(out / 'stray.json').write_text(json.dumps(stray), encoding='utf-8')
EOF
check 'a fallback set to the weakest class is rejected' \
  "! '$PY_BIN' '$VALIDATE' '$SCHEMA_TMP/weak.json'"
check 'a path rule naming an undeclared class is rejected' \
  "! '$PY_BIN' '$VALIDATE' '$SCHEMA_TMP/ghost.json'"
check 'an unrecognised top-level key is rejected' \
  "! '$PY_BIN' '$VALIDATE' '$SCHEMA_TMP/stray.json'"
jq '.action_gates = {"teleport": {"require_gate": {"prose": "whatever"}}}' \
  "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/bad-action.json"
jq '.action_gates["code-only-review"].require_gate["made-up-class"] = "whatever"' \
  "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/bad-class.json"
newrepo "$TMP/schema-repo"
check 'an action-gate naming an unknown action fails closed' \
  "[ \"\$(AI_TASK_GATES_FILE='$SCHEMA_TMP/bad-action.json' out '$TMP/schema-repo' check --before review >/dev/null 2>&1; echo \$?)\" = 4 ]"
check 'an action-gate naming an undeclared class fails closed' \
  "[ \"\$(AI_TASK_GATES_FILE='$SCHEMA_TMP/bad-class.json' out '$TMP/schema-repo' check --before review >/dev/null 2>&1; echo \$?)\" = 4 ]"

# A flag given without its value must fail fast, never spin: on 2026-09-17 an
# orphaned `start --class` burned 11 CPU-hours and starved the local GLM server.
for args in 'start --class' 'start --class prose --reason' 'start --base' 'check --before' 'check --acknowledge' 'check --owner-request' 'check --base'; do
  check "missing value for '$args' fails fast instead of looping" \
    "out=\$(timeout 10 bash '$GATES' $args 2>&1); rc=\$?; [ \$rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'requires a value'"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
