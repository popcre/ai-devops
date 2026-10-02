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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-reviewer-approval.sh"
LIB_REVIEWER_APPROVAL_BIN="$ROOT/bin"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_TASK_GATES_DIR="$TMP/state"
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/review-lifecycle"

command -v jq >/dev/null 2>&1 || { printf 'jq is required for this suite\n' >&2; exit 1; }

# rc <expected> <dir> <args...> — run ai-task-gates in <dir> and compare status.
rc(){ local want="$1" dir="$2" got; shift 2; ( cd "$dir" && "$GATES" "$@" ) >/dev/null 2>&1; got=$?; [ "$got" -eq "$want" ]; }
out(){ local dir="$1"; shift; ( cd "$dir" && "$GATES" "$@" ) 2>&1; }

# appr <dir> <action> [head] [overrides-jq] — mint an allocator-assigned AI
# reviewer APPROVE record bound to the exact action, repository, and head
# (#996: no human approves; an independent AI reviewer does).
appr(){
  local dir="$1" action="$2" head="${3:-}" extra="${4:-.}" mode=final-check
  case "$action" in review|pr-wait|code-only-review) mode=plan-review ;; esac
  mint_reviewer_approval "$TMP" "$dir" "$mode" "$head" "$extra"
}

# newrepo <path> [origin-identity] — a repository with one commit on main.
newrepo(){
  local dir="$1" identity="${2-popcre/ai-devops}"
  mkdir -p "$dir"
  git init -q --initial-branch=main "$dir"
  git -C "$dir" config user.name T; git -C "$dir" config user.email t@e
  [ -z "$identity" ] || git -C "$dir" remote add origin "https://github.com/$identity.git"
  printf 'base\n' > "$dir/README.md"
  mkdir -p "$dir/config"
  cp "$ROOT/config/task-gates.json" "$dir/config/task-gates.json"
  git -C "$dir" add -A; git -C "$dir" commit -qm init
}

# The state file lives outside the repository and is named by a digest, so find
# it by the worktree path the tool itself recorded.
state_file_for(){
  local wt file; wt="$( cd "$1" && "$GATES" status 2>/dev/null | jq -r '.worktree // empty' )"
  [ -n "$wt" ] || return 0
  for file in "$AI_TASK_GATES_DIR"/*.json; do
    [ -f "$file" ] || continue
    if jq -e --arg wt "$wt" '.worktree==$wt' "$file" >/dev/null 2>&1; then printf '%s\n' "$file"; return 0; fi
  done
}

make_approved_report(){
  local dir="$1" target="$2" operation="${3:-}" exclude digest report report_hash key state_dir
  local reviewed="${dir}-reviewed"
  if [ ! -d "$reviewed" ]; then git -C "$dir" worktree add -q --detach "$reviewed" "$target" || return 1; fi
  [ "$(git -C "$reviewed" rev-parse HEAD)" = "$target" ] || return 1
  dir="$reviewed"
  exclude="$(git -C "$dir" rev-parse --git-path info/exclude)"
  printf '.ai/reviews/\n' >> "$exclude"
  mkdir -p "$dir/.ai/reviews"
  digest="$("$ROOT/bin/ai-review-sandbox" digest "$dir")" || return 1
  report="$dir/.ai/reviews/codex-final-check-test.md"
  printf '# Exact review\n\n| reviewed commit | %s%s%s |\n| source digest | %s%s%s |\n\n## Result\n\nApproved fixture source and routes.\nApproved %s.\n\n## Verdict\nAPPROVE\n' \
    "$(printf '\140')" "$target" "$(printf '\140')" "$(printf '\140')" "$digest" "$(printf '\140')" "$operation" > "$report"
  report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
  key="$("$ROOT/bin/ai-review-lifecycle" identity "$dir" | jq -r .repository_key)" || return 1
  state_dir="$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex"
  mkdir -p "$state_dir"
  jq -nc --arg head "$target" --arg source "$digest" --arg report "$report" --arg hash "$report_hash" \
    '{status:"completed",verdict:"APPROVE",stale:false,head:$head,source_digest:$source,report_path:$report,report_sha256:$hash}' \
    > "$state_dir/test.json"
  printf '%s\n' "$report"
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

printf 'shared-db promotion launch (owner ruling 2026-10-02)\n'
for repo in db-canonical db-redirected; do
  mkdir -p "$TMP/$repo/migrations"; printf 'select 1;\n' > "$TMP/$repo/migrations/001.sql"
  git -C "$TMP/$repo" add -A; git -C "$TMP/$repo" commit -qm migration
done
check 'canonical shared-db may launch the promotion run for a merged change' \
  "rc 0 '$TMP/db-canonical' check --before shared-db-promotion"
check 'redirected shared-db identity may launch the promotion run' \
  "rc 0 '$TMP/db-redirected' check --before shared-db-promotion"
check 'the promotion launch never unlocks a manual production action' \
  "! rc 0 '$TMP/db-canonical' check --before production"
newrepo "$TMP/db-app" u2giants/licensor-source-data
mkdir -p "$TMP/db-app/db/migrations"; printf 'select 1;\n' > "$TMP/db-app/db/migrations/001.sql"
git -C "$TMP/db-app" add -A; git -C "$TMP/db-app" commit -qm migration
check 'an application repository with SQL cannot launch the promotion run' \
  "rc 3 '$TMP/db-app' check --before shared-db-promotion"
newrepo "$TMP/code-promo" popcre/shared-db
printf 'x\n' > "$TMP/code-promo/tool.sh"; git -C "$TMP/code-promo" add -A; git -C "$TMP/code-promo" commit -qm code
( cd "$TMP/code-promo" && "$GATES" start --class code >/dev/null 2>&1 )
check 'a non-shared-db class in the shared-db repository cannot launch it' \
  "rc 3 '$TMP/code-promo' check --before shared-db-promotion"
check 'a reviewer approval cannot carry the launch to a non-shared-db class' \
  "out '$TMP/code-promo' check --before shared-db-promotion --reviewer-approval x | grep -q 'opens only for the shared-db class'"

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
check 'the ai-devops pilot protects Windows launcher receipt stamping' \
  "[ \"\$(class_of 'bin/install-machine-tools.ps1')\" = reviewer-safety ]"
check 'the ai-devops pilot protects Windows source gate and bootstrap' \
  "[ \"\$(class_of 'bin/install-ai-devops-windows.ps1')\" = reviewer-safety ] && [ \"\$(class_of 'bin/bootstrap-windows-dev.ps1')\" = reviewer-safety ]"
check 'the ai-devops pilot protects its Windows source gate test' \
  "[ \"\$(class_of 'tests/test-windows-source-gate.ps1')\" = reviewer-safety ]"
check 'the ai-devops pilot protects Linux installation routing and its tests' \
  "[ \"\$(class_of 'install.sh')\" = reviewer-safety ] && [ \"\$(class_of 'update.sh')\" = reviewer-safety ] && [ \"\$(class_of 'tests/test-linux-install-authorization.sh')\" = reviewer-safety ]"
mkdir -p "$TMP/class/bin"
printf '#!/bin/sh\n' > "$TMP/class/bin/ai-task-gates"
git -C "$TMP/class" add .ai-devops/task-gates.json bin/ai-task-gates
git -C "$TMP/class" commit -qm 'add pilot declaration'
( cd "$TMP/class" && "$GATES" start --class reviewer-safety ) >/dev/null
git -C "$TMP/class" worktree add -q --detach "$TMP/class-candidate" HEAD
mkdir -p "$TMP/fake-os" "$TMP/class-home/.local/bin"
cat > "$TMP/fake-os/uname" <<'EOF'
#!/bin/sh
printf 'MINGW64_NT\n'
EOF
chmod +x "$TMP/fake-os/uname"
class_saved_home="$HOME"; class_saved_path="$PATH"
class_saved_profile="${USERPROFILE:-}"; class_saved_programfiles="${PROGRAMFILES:-}"
export HOME="$TMP/class-home" PATH="$TMP/fake-os:$PATH" USERPROFILE="$TMP/class-home" PROGRAMFILES='C:\Program Files'
if ! command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$TMP/fake-cygpath"
  cat > "$TMP/fake-cygpath/cygpath" <<'EOF'
#!/bin/sh
case "$1" in -u|-wa|-aw) printf '%s\n' "$2" ;; *) exit 2 ;; esac
EOF
  chmod +x "$TMP/fake-cygpath/cygpath"
  export PATH="$TMP/fake-cygpath:$PATH"
fi
( cd "$TMP/class-candidate" && "$GATES" start --class installation ) >/dev/null
class_launcher="$HOME/.local/bin/ai-task-gates"
ln -s "$TMP/class/bin/ai-task-gates" "$class_launcher"
printf '#!/bin/sh\n' > "$TMP/class-candidate/bin/ai-review"
git -C "$TMP/class-candidate" add bin/ai-review
git -C "$TMP/class-candidate" commit -qm 'reviewed candidate'
class_target="$(git -C "$TMP/class-candidate" rev-parse HEAD)"
class_proof="--target-head $class_target --installed-checkout $TMP/class --installed-launcher $class_launcher"
class_report="$(make_approved_report "$TMP/class-candidate" "$class_target")"
( cd "$TMP/class-candidate-reviewed" && "$GATES" start --class reviewer-safety --base "$(git -C "$TMP/class" rev-parse HEAD)" ) >/dev/null
check 'separate reviewer task can pass the real review preflight' \
  "rc 0 '$TMP/class-candidate-reviewed' check --before review"
check 'stale target cannot issue install authority' \
  "rc 3 '$TMP/class-candidate' authorize-install --target-head \"\$(git -C '$TMP/class' rev-parse HEAD)\" --installed-checkout '$TMP/class' --installed-launcher '$class_launcher' --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
check 'an unlanded candidate cannot claim the toolkit installation route' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
git -C "$TMP/class" update-ref refs/remotes/origin/main "$class_target"
check 'reviewer-safety installation needs an assigned AI reviewer approval' \
  "rc 3 '$TMP/class-candidate' check --before deploy $class_proof"
check 'reviewer-safety installation keeps independent review and routing proof' \
  "out '$TMP/class-candidate' explain --json | jq -e '.required_gates | index(\"exact-head-independent-review\") != null and index(\"installed-routing-proof\") != null'"
check 'reviewer-safety deploy remains forbidden even with reviewer approval' \
  "rc 3 '$TMP/class-candidate' check --before deploy $class_proof --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
class_state="$(state_file_for "$TMP/class-candidate")"
jq '.declared_class="reviewer-safety"' "$class_state" > "$class_state.tmp" && mv "$class_state.tmp" "$class_state"
check 'a protected task cannot issue installation authority' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
jq '.declared_class="installation"' "$class_state" > "$class_state.tmp" && mv "$class_state.tmp" "$class_state"
check 'a separate installation task can issue exact reviewed authority' \
  "rc 0 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
check 'the issued authority binds old and target commits' \
  "jq -e --arg old \"\$(git -C '$TMP/class' rev-parse HEAD)\" --arg target '$class_target' '.installed_head==\$old and .target_head==\$target and .reviewer_approval!=\"\"' '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json'"
check 'authorization cannot be issued twice for one target' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$class_target.json"
cp "$class_report" "$TMP/class-report.backup"
printf '\nchanged report\n' >> "$class_report"
check 'tampered exact-head review cannot issue install authority' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
mv "$TMP/class-report.backup" "$class_report"
class_lifecycle="$(find "$AI_REVIEW_LIFECYCLE_DIR" -name test.json -type f | head -1)"
mv "$class_lifecycle" "$class_lifecycle.held"
check 'a report without completed lifecycle evidence cannot issue install authority' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
mv "$class_lifecycle.held" "$class_lifecycle"
printf 'uncommitted\n' > "$TMP/class-candidate/stray.txt"
check 'the exact candidate target refuses uncommitted files' \
  "rc 3 '$TMP/class-candidate' check --before deploy $class_proof --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$TMP/class-candidate/stray.txt"
rm -f "$class_launcher"
ln -s "$TMP/class-candidate/bin/ai-task-gates" "$class_launcher"
check 'the installed launcher cannot point into the candidate checkout' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$class_launcher"
ln -s "$TMP/class/bin/ai-task-gates" "$class_launcher"
newrepo "$TMP/unrelated-installed"
check 'a foreign installed checkout cannot be claimed as the same repository' \
  "rc 3 '$TMP/class-candidate' authorize-install --target-head '$class_target' --installed-checkout '$TMP/unrelated-installed' --installed-launcher '$class_launcher' --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
git -C "$TMP/class" worktree add -q --detach "$TMP/class-fake-installed" HEAD
rm "$class_launcher"
ln -s "$TMP/class-fake-installed/bin/ai-task-gates" "$class_launcher"
check 'a linked sibling cannot impersonate the durable installed checkout' \
  "rc 3 '$TMP/class-candidate' authorize-install --target-head '$class_target' --installed-checkout '$TMP/class-fake-installed' --installed-launcher '$class_launcher' --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm "$class_launcher"
ln -s "$TMP/class/bin/ai-task-gates" "$class_launcher"
if ! command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$TMP/fake-cygpath"
  cat > "$TMP/fake-cygpath/cygpath" <<'EOF'
#!/bin/sh
case "$1" in -u|-wa) printf '%s\n' "$2" ;; *) exit 2 ;; esac
EOF
  chmod +x "$TMP/fake-cygpath/cygpath"
  export PATH="$TMP/fake-cygpath:$PATH"
fi
windows_source="$(cygpath -u "$TMP/class/bin/ai-task-gates")"
rm "$class_launcher"
cat > "$class_launcher" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
export HOME="$HOME"
exec "$windows_source" "\$@"
EOF
cat > "$class_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
set "HOME=$USERPROFILE"
"$PROGRAMFILES\Git\bin\bash.exe" "$windows_source" %*
EOF
check 'managed Windows launcher resolves to the installed checkout' \
  "rc 0 '$TMP/class-candidate' authorize-install --target-head '$class_target' --installed-checkout '$TMP/class' --installed-launcher '$class_launcher' --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$class_target.json"
sed -i 's/\\Git\\bin\\bash.exe/\\Other\\bash.exe/' "$class_launcher.cmd"
check 'an update rejects a tampered Windows command route' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
sed -i 's/\\Other\\bash.exe/\\Git\\bin\\bash.exe/' "$class_launcher.cmd"
sed -i 's/^set "HOME=.*/set "HOME=elsewhere"/' "$class_launcher.cmd"
check 'an update rejects a tampered Windows home route' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
sed -i "s|^set \"HOME=.*|set \"HOME=$USERPROFILE\"|" "$class_launcher.cmd"
newrepo "$TMP/legacy-primary"
mkdir -p "$TMP/legacy-primary/.ai-devops" "$TMP/legacy-primary/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/legacy-primary/.ai-devops/task-gates.json"
printf '#!/bin/sh\n' > "$TMP/legacy-primary/bin/ai-task-gates"
git -C "$TMP/legacy-primary" add .ai-devops/task-gates.json bin/ai-task-gates
git -C "$TMP/legacy-primary" commit -qm 'legacy installed source'
legacy_target="$(git -C "$TMP/legacy-primary" rev-parse HEAD)"
git -C "$TMP/legacy-primary" update-ref refs/remotes/origin/main "$legacy_target"
git -C "$TMP/legacy-primary" worktree add -q --detach "$TMP/legacy-install" "$legacy_target"
( cd "$TMP/legacy-install" && "$GATES" start --class installation ) >/dev/null
legacy_report="$(make_approved_report "$TMP/legacy-install" "$legacy_target" legacy-managed-launcher-refresh)"
( cd "$TMP/legacy-install-reviewed" && "$GATES" start --class reviewer-safety --base "$legacy_target" ) >/dev/null
rm -f "$class_launcher" "$class_launcher.cmd"
legacy_source="$TMP/legacy-primary/bin/ai-task-gates"
cat > "$class_launcher" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
export HOME="$HOME"
exec "$legacy_source" "\$@"
EOF
cat > "$class_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
set "HOME=$USERPROFILE"
"$PROGRAMFILES\Git\bin\bash.exe" "$legacy_source" %*
EOF
legacy_proof="--target-head $legacy_target --installed-checkout $TMP/legacy-primary --installed-launcher $class_launcher --review-report $legacy_report --reviewer-approval $(appr "$TMP/legacy-primary" deploy "$legacy_target")"
check 'same-commit legacy migration requires explicit reviewed mode' \
  "rc 3 '$TMP/legacy-install' authorize-install $legacy_proof"
check 'same-commit legacy migration binds managed launcher and source bytes' \
  "rc 0 '$TMP/legacy-install' authorize-install $legacy_proof --legacy-migration"
check 'legacy authority records exact launcher and source hashes' \
  "jq -e '.legacy_migration==true and (.installed_launcher_sha256|length)==64 and (.installed_cmd_sha256|length)==64 and (.installed_source_sha256|length)==64' '$AI_TASK_GATES_DIR/install-authorizations/$legacy_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$legacy_target.json"
sed -i 's/\\Git\\bin\\bash.exe/\\Other\\bash.exe/' "$class_launcher.cmd"
check 'legacy migration refuses a changed command route' \
  "rc 3 '$TMP/legacy-install' authorize-install $legacy_proof --legacy-migration"
rm -f "$class_launcher" "$class_launcher.cmd"
newrepo "$TMP/first-primary"
mkdir -p "$TMP/first-primary/.ai-devops" "$TMP/first-primary/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/first-primary/.ai-devops/task-gates.json"
cp "$ROOT/config/machine-tools.tsv" "$TMP/first-primary/config/machine-tools.tsv"
printf '#!/bin/sh\n' > "$TMP/first-primary/bin/ai-task-gates"
git -C "$TMP/first-primary" add .ai-devops/task-gates.json config/machine-tools.tsv bin/ai-task-gates
git -C "$TMP/first-primary" commit -qm 'first managed source'
first_target="$(git -C "$TMP/first-primary" rev-parse HEAD)"
git -C "$TMP/first-primary" update-ref refs/remotes/origin/main "$first_target"
git -C "$TMP/first-primary" worktree add -q --detach "$TMP/first-install" "$first_target"
( cd "$TMP/first-install" && "$GATES" start --class installation ) >/dev/null
first_report="$(make_approved_report "$TMP/first-install" "$first_target" first-managed-install)"
first_proof="--target-head $first_target --installed-checkout $TMP/first-primary --installed-launcher $class_launcher --review-report $first_report --reviewer-approval $(appr "$TMP/first-primary" deploy "$first_target")"
first_key="$("$ROOT/bin/ai-review-lifecycle" identity "$TMP/first-install" | jq -r .repository_key)"
first_lifecycle="$AI_REVIEW_LIFECYCLE_DIR/runs/$first_key/codex/codex/test.json"
cp "$first_report" "$TMP/first-report-backup"
sed -i 's/^Approved first-managed-install\.$/Not approved first-managed-install./' "$first_report"
first_hash="$(sha256sum "$first_report" | cut -d' ' -f1)"
jq --arg hash "$first_hash" '.report_sha256=$hash' "$first_lifecycle" > "$TMP/first-lifecycle-updated"
mv "$TMP/first-lifecycle-updated" "$first_lifecycle"
check 'mentioning a sensitive install mode is not approval' \
  "rc 3 '$TMP/first-install' authorize-install $first_proof --first-install"
cp "$TMP/first-report-backup" "$first_report"
first_hash="$(sha256sum "$first_report" | cut -d' ' -f1)"
jq --arg hash "$first_hash" '.report_sha256=$hash' "$first_lifecycle" > "$TMP/first-lifecycle-updated"
mv "$TMP/first-lifecycle-updated" "$first_lifecycle"

check 'first managed installation needs explicit reviewed mode' \
  "rc 3 '$TMP/first-install' authorize-install $first_proof"
printf '# Managed by ai-devops install-machine-tools.ps1.\n' > "$(dirname "$class_launcher")/retired-tool"
check 'first managed installation rejects retired managed launchers' \
  "rc 3 '$TMP/first-install' authorize-install $first_proof --first-install"
rm -f "$(dirname "$class_launcher")/retired-tool"
auth_target="$AI_TASK_GATES_DIR/install-authorizations/$first_target.json"
printf 'sentinel\n' > "$TMP/authority-sentinel"
ln -s "$TMP/authority-sentinel" "$auth_target"
check 'dangling or linked authority destination cannot be replaced' \
  "rc 3 '$TMP/first-install' authorize-install $first_proof --first-install && [ \"\$(cat '$TMP/authority-sentinel')\" = sentinel ]"
rm "$auth_target"
check 'first managed installation binds clean source with absent launchers' \
  "rc 0 '$TMP/first-install' authorize-install $first_proof --first-install"
check 'first-install authority records target source hash' \
  "jq -e '.first_install==true and (.installed_source_sha256|length)==64' '$AI_TASK_GATES_DIR/install-authorizations/$first_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$first_target.json"
retired_launcher="$(dirname "$class_launcher")/retired-tool"
printf '# Managed by ai-devops install-machine-tools.ps1.\n' > "$retired_launcher"
recovery_report="$(make_approved_report "$TMP/first-install" "$first_target" partial-managed-launcher-recovery)"
recovery_proof="--target-head $first_target --installed-checkout $TMP/first-primary --installed-launcher $class_launcher --review-report $recovery_report --reviewer-approval $(appr "$TMP/first-primary" deploy "$first_target")"
check 'missing gate pair with sibling launcher needs reviewed recovery mode' \
  "rc 3 '$TMP/first-install' authorize-install $recovery_proof --first-install"
check 'reviewed recovery binds the full managed launcher inventory' \
  "rc 0 '$TMP/first-install' authorize-install $recovery_proof --recover-launchers"
check 'recovery authority records absent gate pair and present sibling hash' \
  "jq -e '.recover_launchers==true and .installed_launcher_sha256==\"\" and .installed_cmd_sha256==\"\" and (.managed_inventory|length)==1 and .managed_inventory[0].name==\"retired-tool\" and (.managed_inventory[0].sha256|length)==64' '$AI_TASK_GATES_DIR/install-authorizations/$first_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$first_target.json"
rm -f "$retired_launcher"
cat > "$class_launcher" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
export HOME="$USERPROFILE"
exec "$TMP/first-primary/bin/ai-task-gates" "\$@"
EOF
check 'reviewed recovery accepts one supported Bash launcher' \
  "rc 0 '$TMP/first-install' authorize-install $recovery_proof --recover-launchers"
check 'one-file recovery seals present and absent paths' \
  "jq -e '.recover_launchers==true and (.installed_launcher_sha256|length)==64 and .installed_cmd_sha256==\"\" and (.managed_inventory|length)==1' '$AI_TASK_GATES_DIR/install-authorizations/$first_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$first_target.json" "$class_launcher"
cat > "$class_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
set "HOME=$USERPROFILE"
"$PROGRAMFILES\\Git\\bin\\bash.exe" "$TMP/first-primary/bin/ai-task-gates" %*
EOF
check 'reviewed recovery accepts one supported command launcher' \
  "rc 0 '$TMP/first-install' authorize-install $recovery_proof --recover-launchers"
check 'command-only recovery seals present and absent paths' \
  "jq -e '.recover_launchers==true and .installed_launcher_sha256==\"\" and (.installed_cmd_sha256|length)==64 and (.managed_inventory|length)==1' '$AI_TASK_GATES_DIR/install-authorizations/$first_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$first_target.json" "$class_launcher.cmd"
partial_route="$TMP/partial-route.sh"
sed -n '/^windows_partial_launcher_route(){/,/^}/p' "$GATES" > "$partial_route"
cat >> "$partial_route" <<'EOF'
cygpath(){ printf '%s\n' "${@: -1}"; }
EOF
partial_launcher="$TMP/partial-gate"
printf '#!/usr/bin/env bash\n# Managed by ai-devops install-machine-tools.ps1.\nexport HOME="C:\\Users\\fixture"\nexec "%s" "$@"\n' "$TMP/class/bin/ai-task-gates" > "$partial_launcher"
check 'partial managed Bash launcher requires its exact supported route' \
  "USERPROFILE='C:\\Users\\fixture' bash -c 'source \"$partial_route\"; windows_partial_launcher_route \"$TMP/class/bin/ai-task-gates\" \"$partial_launcher\"'"
sed -i 's@/bin/ai-task-gates@/bin/foreign-gate@' "$partial_launcher"
check 'partial launcher recovery refuses a foreign executable route' \
  "rc 1 bash -c 'source \"$partial_route\"; USERPROFILE=\"C:\\Users\\fixture\" windows_partial_launcher_route \"$TMP/class/bin/ai-task-gates\" \"$partial_launcher\"'"
rm -f "$partial_launcher"
printf '@echo off\nrem Managed by ai-devops install-machine-tools.ps1.\nset "HOME=C:\\Users\\fixture"\n"C:\\Program Files\\Git\\bin\\bash.exe" "%s" %%*\n' "$TMP/class/bin/ai-task-gates" > "$partial_launcher.cmd"
check 'partial managed command launcher requires its exact supported route' \
  "USERPROFILE='C:\\Users\\fixture' PROGRAMFILES='C:\\Program Files' bash -c 'source \"$partial_route\"; windows_partial_launcher_route \"$TMP/class/bin/ai-task-gates\" \"$partial_launcher\"'"
sed -i 's@Git\\bin@Other\\bin@' "$partial_launcher.cmd"
check 'partial command launcher recovery refuses a foreign shell route' \
  "rc 1 bash -c 'source \"$partial_route\"; USERPROFILE=\"C:\\Users\\fixture\" PROGRAMFILES=\"C:\\Program Files\" windows_partial_launcher_route \"$TMP/class/bin/ai-task-gates\" \"$partial_launcher\"'"
rm -f "$partial_launcher.cmd"
ln -s "$TMP/class/bin/ai-task-gates" "$class_launcher"
mkdir -p "$TMP/class-candidate/services/api" "$TMP/class-candidate/infra"
printf 'FROM scratch\n' > "$TMP/class-candidate/services/api/Dockerfile"
check 'mixed deployment and reviewer release cannot use the narrow route' \
  "rc 3 '$TMP/class-candidate' check --before deploy --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$TMP/class-candidate/services/api/Dockerfile"
rmdir "$TMP/class-candidate/services/api" "$TMP/class-candidate/services"
printf 'resource \"x\" \"y\" {}\n' > "$TMP/class-candidate/infra/main.tf"
check 'mixed infrastructure and reviewer release cannot use the narrow route' \
  "rc 3 '$TMP/class-candidate' check --before deploy --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$TMP/class-candidate/infra/main.tf"
rmdir "$TMP/class-candidate/infra"
git -C "$TMP/class-candidate" rm -q bin/ai-review
git -C "$TMP/class-candidate" commit -qm 'finish mixed tests'
export HOME="$class_saved_home" PATH="$class_saved_path"
if [ -n "$class_saved_profile" ]; then export USERPROFILE="$class_saved_profile"; else unset USERPROFILE; fi
if [ -n "$class_saved_programfiles" ]; then export PROGRAMFILES="$class_saved_programfiles"; else unset PROGRAMFILES; fi

newrepo "$TMP/foreign-reviewer" u2giants/other-toolkit
mkdir -p "$TMP/foreign-reviewer/.ai-devops" "$TMP/foreign-reviewer/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/foreign-reviewer/.ai-devops/task-gates.json"
printf '#!/bin/sh\n' > "$TMP/foreign-reviewer/bin/ai-review"
( cd "$TMP/foreign-reviewer" && "$GATES" start --class reviewer-safety ) >/dev/null
check 'another repository cannot use the toolkit installation route' \
  "rc 3 '$TMP/foreign-reviewer' check --before deploy --reviewer-approval \"\$(appr '$TMP/foreign-reviewer' deploy)\""

for foreign_url in https://gitlab.com/popcre/ai-devops.git git@gitlab.com:popcre/ai-devops.git; do
  git -C "$TMP/foreign-reviewer" remote set-url origin "$foreign_url"
  check 'foreign host with the same owner and name cannot use the toolkit route' \
    "rc 3 '$TMP/foreign-reviewer' check --before deploy --reviewer-approval \"\$(appr '$TMP/foreign-reviewer' deploy)\""
done

newrepo "$TMP/deleted-reviewer"
mkdir -p "$TMP/deleted-reviewer/.ai-devops" "$TMP/deleted-reviewer/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/deleted-reviewer/.ai-devops/task-gates.json"
printf '#!/bin/sh\n' > "$TMP/deleted-reviewer/bin/ai-task-gates"
printf '#!/bin/sh\n' > "$TMP/deleted-reviewer/bin/ai-review"
git -C "$TMP/deleted-reviewer" add .ai-devops/task-gates.json bin/ai-review bin/ai-task-gates
git -C "$TMP/deleted-reviewer" commit -qm 'installed reviewer source'
( cd "$TMP/deleted-reviewer" && "$GATES" start --class reviewer-safety ) >/dev/null
installed_head="$(git -C "$TMP/deleted-reviewer" rev-parse HEAD)"
git -C "$TMP/deleted-reviewer" worktree add -q --detach "$TMP/deleted-candidate" "$installed_head"
export HOME="$TMP/class-home" PATH="$TMP/fake-os:$TMP/fake-cygpath:$class_saved_path"
rm -f "$class_launcher"
ln -s "$TMP/deleted-reviewer/bin/ai-task-gates" "$class_launcher"
( cd "$TMP/deleted-candidate" && "$GATES" start --class installation ) >/dev/null
git -C "$TMP/deleted-candidate" rm -q bin/ai-review
git -C "$TMP/deleted-candidate" commit -qm 'retire reviewer source'
deleted_target="$(git -C "$TMP/deleted-candidate" rev-parse HEAD)"
git -C "$TMP/deleted-reviewer" update-ref refs/remotes/origin/main "$deleted_target"
deleted_report="$(make_approved_report "$TMP/deleted-candidate" "$deleted_target")"
deleted_proof="--target-head $deleted_target --installed-checkout $TMP/deleted-reviewer --installed-launcher $class_launcher"
check 'deployment sees a reviewer path deleted after the recorded host HEAD' \
  "out '$TMP/deleted-candidate' explain --json --base '$installed_head' | jq -e '.changes[] | select(.path==\"bin/ai-review\" and .class==\"reviewer-safety\")'"
check 'a deleted reviewer path still uses the protected installation route' \
  "rc 0 '$TMP/deleted-candidate' authorize-install $deleted_proof --review-report '$deleted_report' --reviewer-approval \"\$(appr '$TMP/deleted-candidate' deploy)\""
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$deleted_target.json"
printf 'local edit\n' >> "$TMP/deleted-reviewer/bin/ai-task-gates"
check 'preflight refuses local edits in the installed checkout' \
  "rc 3 '$TMP/deleted-candidate' check --before deploy $deleted_proof --reviewer-approval \"\$(appr '$TMP/deleted-candidate' deploy)\""
git -C "$TMP/deleted-reviewer" checkout -q -- bin/ai-task-gates
check 'a caller cannot replace the recorded host HEAD with a newer base' \
  "rc 3 '$TMP/deleted-candidate' check --before deploy $deleted_proof --base HEAD --reviewer-approval \"\$(appr '$TMP/deleted-candidate' deploy)\""
check 'preflight rejects a wrong target commit' \
  "rc 3 '$TMP/deleted-candidate' check --before deploy --target-head '$installed_head' --installed-checkout '$TMP/deleted-reviewer' --installed-launcher '$class_launcher' --reviewer-approval \"\$(appr '$TMP/deleted-candidate' deploy)\""
git -C "$TMP/deleted-reviewer" merge --ff-only -q "$deleted_target"
check 'preflight rejects an installed checkout that already moved' \
  "rc 3 '$TMP/deleted-candidate' check --before deploy $deleted_proof --reviewer-approval \"\$(appr '$TMP/deleted-candidate' deploy)\""
export HOME="$class_saved_home" PATH="$class_saved_path"

newrepo "$TMP/empty-release"
mkdir -p "$TMP/empty-release/.ai-devops" "$TMP/empty-release/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/empty-release/.ai-devops/task-gates.json"
printf '#!/bin/sh\n' > "$TMP/empty-release/bin/ai-task-gates"
git -C "$TMP/empty-release" add .ai-devops/task-gates.json bin/ai-task-gates
git -C "$TMP/empty-release" commit -qm 'current source only'
git -C "$TMP/empty-release" update-ref refs/remotes/origin/main HEAD
( cd "$TMP/empty-release" && "$GATES" start --class reviewer-safety ) >/dev/null
check 'an empty reviewer release cannot be installed after a late start' \
  "rc 3 '$TMP/empty-release' check --before deploy --reviewer-approval \"\$(appr '$TMP/empty-release' deploy)\""
( cd "$TMP/empty-release" && "$GATES" start --class installation ) >/dev/null
check 'late declaration cannot hide an unreceipted installed source' \
  "rc 3 '$TMP/empty-release' check --before deploy --reviewer-approval \"\$(appr '$TMP/empty-release' deploy)\""
mkdir -p "$TMP/empty-home/.local/bin" "$TMP/fake-os"
cat > "$TMP/fake-os/uname" <<'EOF'
#!/bin/sh
printf 'MINGW64_NT\n'
EOF
chmod +x "$TMP/fake-os/uname"
saved_home="$HOME"; saved_path="$PATH"; saved_programfiles="${PROGRAMFILES:-}"; saved_profile="${USERPROFILE:-}"
export HOME="$TMP/empty-home" PATH="$TMP/fake-os:$TMP/fake-cygpath:$PATH" USERPROFILE="$TMP/empty-home"
export PROGRAMFILES='C:\Program Files'
empty_launcher="$HOME/.local/bin/ai-task-gates"
empty_proof="--installed-checkout $TMP/empty-release --installed-launcher $empty_launcher --reviewer-approval $(appr "$TMP/empty-release" deploy)"
check 'first install requires an explicit first-install claim' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
check 'first-time toolkit installation retains the reviewer-approved route' \
  "rc 0 '$TMP/empty-release' check --before deploy --first-install $empty_proof"
empty_sha="$(git -C "$TMP/empty-release" rev-parse HEAD)"
empty_hash="$(sha256sum "$TMP/empty-release/bin/ai-task-gates" | cut -d' ' -f1)"
cat > "$empty_launcher" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
# source-sha=$empty_sha
# source-hash=$empty_hash
export HOME="$HOME"
exec "$TMP/empty-release/bin/ai-task-gates" "\$@"
EOF
cat > "$empty_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
rem source-sha=$empty_sha
rem source-hash=$empty_hash
set "HOME=$HOME"
"$PROGRAMFILES\Git\bin\bash.exe" "$TMP/empty-release/bin/ai-task-gates" %*
EOF
check 'first install refuses a pre-existing managed launcher' \
  "rc 3 '$TMP/empty-release' check --before deploy --first-install $empty_proof"
check 'matching installed source receipt permits same-source maintenance' \
  "rc 0 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i 's|^export HOME=.*|export HOME="elsewhere"|' "$empty_launcher"
check 'tampered Windows Bash home refuses maintenance' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i "s|^export HOME=.*|export HOME=\"$HOME\"|" "$empty_launcher"
sed -i 's/\\Git\\bin\\bash.exe/\\Other\\bash.exe/' "$empty_launcher.cmd"
check 'tampered Windows command routing refuses maintenance' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i 's/\\Other\\bash.exe/\\Git\\bin\\bash.exe/' "$empty_launcher.cmd"
printf 'call bad.cmd\n' >> "$empty_launcher.cmd"
check 'extra Windows command refuses maintenance even with valid markers and route' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i '$d' "$empty_launcher.cmd"
sed -i 's/^rem source-hash=.*/rem source-hash=bad/' "$empty_launcher.cmd"
check 'tampered receipt refuses maintenance' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i "s/^rem source-hash=.*/rem source-hash=$empty_hash/" "$empty_launcher.cmd"
rm "$empty_launcher.cmd"
check 'missing receipt refuses maintenance' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
cat > "$empty_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
rem source-sha=$empty_sha
rem source-hash=$empty_hash
set "HOME=$HOME"
"$PROGRAMFILES\Git\bin\bash.exe" "$TMP/empty-release/bin/ai-task-gates" %*
EOF
rm "$empty_launcher" "$empty_launcher.cmd"
ln -s "$TMP/empty-release/bin/ai-task-gates" "$empty_launcher"
mkdir -p "$TMP/empty-etc"
export AI_DEVOPS_ETC="$TMP/empty-etc"
printf 'meta\tsource_sha\t%s\t-\nsymlink\t%s\t%s\t%s\n' \
  "$empty_sha" "$empty_launcher" "$TMP/empty-release/bin/ai-task-gates" "$empty_hash" > "$AI_DEVOPS_ETC/install-manifest.tsv"
linux_receipt_fixture(){
  ( eval "$(sed -n '/^toolkit_source_receipt(){/,/^}/p' "$GATES")"; toolkit_source_receipt "$TMP/empty-release" "$empty_launcher" "$empty_sha" "$AI_DEVOPS_ETC/install-manifest.tsv" )
}
check 'matching Linux install manifest proves the source receipt' 'linux_receipt_fixture'
check 'a caller-provided manifest path cannot authorize deployment' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
sed -i 's/^symlink.*$/symlink\tbad\tbad\tbad/' "$AI_DEVOPS_ETC/install-manifest.tsv"
check 'tampered Linux install manifest refuses source receipt' '! linux_receipt_fixture'
rm "$AI_DEVOPS_ETC/install-manifest.tsv"
check 'missing Linux install manifest refuses source receipt' '! linux_receipt_fixture'
printf 'meta\tsource_sha\t%s\t-\nsymlink\t%s\t%s\t%s\n' \
  "$empty_sha" "$empty_launcher" "$TMP/empty-release/bin/ai-task-gates" "$empty_hash" > "$AI_DEVOPS_ETC/install-manifest.tsv"
printf 'new release\n' >> "$TMP/empty-release/README.md"
git -C "$TMP/empty-release" add README.md
git -C "$TMP/empty-release" commit -qm 'early pulled update'
git -C "$TMP/empty-release" update-ref refs/remotes/origin/main HEAD
( cd "$TMP/empty-release" && "$GATES" start --class installation ) >/dev/null
check 'late declaration after early pull cannot claim an older source receipt' \
  "rc 3 '$TMP/empty-release' check --before deploy $empty_proof"
unset AI_DEVOPS_ETC
if [ -n "$saved_programfiles" ]; then export PROGRAMFILES="$saved_programfiles"; else unset PROGRAMFILES; fi
if [ -n "$saved_profile" ]; then export USERPROFILE="$saved_profile"; else unset USERPROFILE; fi
export HOME="$saved_home" PATH="$saved_path"

newrepo "$TMP/redirected-toolkit" u2giants/ai-devops
mkdir -p "$TMP/redirected-toolkit/.ai-devops" "$TMP/redirected-toolkit/bin"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/redirected-toolkit/.ai-devops/task-gates.json"
printf '#!/bin/sh\n' > "$TMP/redirected-toolkit/bin/ai-task-gates"
git -C "$TMP/redirected-toolkit" add .ai-devops/task-gates.json bin/ai-task-gates
git -C "$TMP/redirected-toolkit" commit -qm 'redirected origin base'
( cd "$TMP/redirected-toolkit" && "$GATES" start --class reviewer-safety ) >/dev/null
git -C "$TMP/redirected-toolkit" worktree add -q --detach "$TMP/redirected-candidate" HEAD
export HOME="$TMP/class-home" PATH="$TMP/fake-os:$TMP/fake-cygpath:$class_saved_path"
rm -f "$class_launcher"
ln -s "$TMP/redirected-toolkit/bin/ai-task-gates" "$class_launcher"
( cd "$TMP/redirected-candidate" && "$GATES" start --class installation ) >/dev/null
printf '#!/bin/sh\n' > "$TMP/redirected-candidate/bin/ai-review"
git -C "$TMP/redirected-candidate" add bin/ai-review
git -C "$TMP/redirected-candidate" commit -qm 'redirected candidate'
redirected_target="$(git -C "$TMP/redirected-candidate" rev-parse HEAD)"
git -C "$TMP/redirected-toolkit" update-ref refs/remotes/origin/main "$redirected_target"
redirected_report="$(make_approved_report "$TMP/redirected-candidate" "$redirected_target")"
check 'the documented u2giants GitHub origin retains toolkit install route' \
  "rc 0 '$TMP/redirected-candidate' authorize-install --target-head '$redirected_target' --installed-checkout '$TMP/redirected-toolkit' --installed-launcher '$class_launcher' --review-report '$redirected_report' --reviewer-approval \"\$(appr '$TMP/redirected-candidate' deploy)\""
export HOME="$class_saved_home" PATH="$class_saved_path"

newrepo "$TMP/mixed-explain"
mkdir -p "$TMP/mixed-explain/.ai-devops" "$TMP/mixed-explain/bin" "$TMP/mixed-explain/services/api"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/mixed-explain/.ai-devops/task-gates.json"
git -C "$TMP/mixed-explain" add .ai-devops/task-gates.json
git -C "$TMP/mixed-explain" commit -qm 'toolkit declaration'
( cd "$TMP/mixed-explain" && "$GATES" start --class deployment ) >/dev/null
printf '#!/bin/sh\n' > "$TMP/mixed-explain/bin/ai-review"
printf 'FROM scratch\n' > "$TMP/mixed-explain/services/api/Dockerfile"
check 'explain includes reviewer proofs inside a stronger mixed class' \
  "out '$TMP/mixed-explain' explain --json | jq -e '.effective_class==\"deployment\" and (.required_gates|index(\"exact-head-independent-review\")!=null and index(\"installed-routing-proof\")!=null)'"

printf '#!/usr/bin/env bash\n' > "$TMP/class/bin/install-fixture"
( cd "$TMP/class" && "$GATES" start --class installation ) >/dev/null
check 'installation refuses deployment without a reviewer approval' \
  "rc 3 '$TMP/class' check --before deploy"
check 'an assigned AI reviewer approval preserves the supported installation path' \
  "rc 0 '$TMP/class' check --before deploy --reviewer-approval \"\$(appr '$TMP/class' deploy)\""
rm -f "$TMP/class/bin/install-fixture"
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
  "out '$TMP/clean' explain --json | jq -e '.observed_class==\"none\" and .effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null)'"
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
check 'an assigned AI reviewer approval lifts a non-protected forbidden action' \
  "rc 0 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review)\""
check 'an approval whose reviewer is the implementing engine is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.implementer_engine=\"grok\"')\""
check 'a review with no recorded implementing engine is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.implementer_engine=null')\""
check 'a review with no recorded mode is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.review_mode=null')\""
check 'an approval bound to another head is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review 0000000000000000000000000000000000000000)\""
check 'a REJECT verdict is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.verdict=\"REJECT\"')\""
check 'a stale review is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.stale=true')\""
check 'a review of another source digest is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.source_digest=\"0\"')\""
check 'a review recorded for another repository is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$(appr '$TMP/gate' review '' '.repository_key=\"other\"')\""
check 'a report with no lifecycle row is refused' \
  "rc 3 '$TMP/gate' check --before review --reviewer-approval /etc/hostname"
check 'an edited report no longer matches its lifecycle row' \
  "f=\"\$(appr '$TMP/gate' review)\"; printf 'x\\n' >> \"\$f\"; rc 3 '$TMP/gate' check --before review --reviewer-approval \"\$f\""
check 'a plan-review cannot authorize a live action' \
  "rc 3 '$TMP/gate' check --before deploy --reviewer-approval \"\$(mint_reviewer_approval '$TMP' '$TMP/gate' plan-review)\""
check 'the reviewer approval is recorded in the intent state' \
  "out '$TMP/gate' status | jq -e '[.overrides[].kind]|index(\"reviewer-approval\")!=null'"
( cd "$TMP/gate" && "$GATES" start --class production ) >/dev/null
printf 'x\n' > "$TMP/gate/note.md"
check 'a stronger declared class supplies the effective gates' \
  "out '$TMP/gate' explain --json | jq -e '.observed_class==\"prose\" and .effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null)'"
check 'a stronger declared class does not drop observed-class required proof' \
  "out '$TMP/gate' explain --json | jq -e '.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null'"
rm -f "$TMP/gate/note.md"
( cd "$TMP/gate" && "$GATES" start --class prose ) >/dev/null
mkdir -p "$TMP/gate/bin"; printf '#!/bin/sh\n' > "$TMP/gate/bin/ai-review-lifecycle"
check 'a protected class cannot be reviewer-approved past a forbidden action' \
  "rc 3 '$TMP/gate' check --before production --reviewer-approval \"\$(appr '$TMP/gate' production)\""
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
  "! out '$TMP/lsd' check --before review --reviewer-approval \"\$(appr '$TMP/lsd' review)\" | grep -Fq 'exact resource and action'"
check 'the protected stop says there is no reviewer-approval path' \
  "out '$TMP/lsd' check --before review --reviewer-approval \"\$(appr '$TMP/lsd' review)\" | grep -Fq 'no reviewer-approval'"
rm -f "$TMP/lsd/warner-bros/assets.csv"

printf 'private code review keeps evidence and mutation boundaries\n'
newrepo "$TMP/private" 'u2giants/licensor-source-data'
mkdir -p "$TMP/private/disney-dcpvault" "$TMP/private/.ai-devops"
printf '# synthetic loader code only\n' > "$TMP/private/disney-dcpvault/loader.py"
cat > "$TMP/private/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"disney-dcpvault/**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]},"private-tooling":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy","infrastructure","production"]}}}
EOF
( cd "$TMP/private" && "$GATES" start --class private-tooling ) >/dev/null
check 'the sealed route needs no reviewer approval or acknowledgement' \
  "rc 0 '$TMP/private' check --before code-only-review"
check 'the formal review stays forbidden on the same change set' \
  "rc 3 '$TMP/private' check --before review"
check 'and that refusal still has no reviewer-approval path' \
  "out '$TMP/private' check --before review --reviewer-approval \"\$(appr '$TMP/private' review)\" | grep -Fq 'no reviewer-approval'"
check 'the sealed route retains central and consumer evidence requirements' \
  "out '$TMP/private' explain --json | jq -e '.effective_class==\"private-evidence\" and ([\"privacy-classification\",\"no-raw-content-read\",\"licensed-row-containment\",\"synthetic-fixtures-only\"] - .required_gates | length==0)'"
check 'private-evidence remains protected at its existing rank' \
  "jq -e '.change_classes[\"private-evidence\"] | .protected==true and .rank==90' '$AI_TASK_GATES_FILE'"
for action in deploy database infrastructure production; do
  check "private code review cannot authorize $action even with owner override" \
    "rc 3 '$TMP/private' check --before '$action' --reviewer-approval \"\$(appr '$TMP/private' '$action')\" --acknowledge 'in scope'"
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
  "rc 3 '$TMP/private' check --before review --reviewer-approval \"\$(appr '$TMP/private' review)\""
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

printf 'a quoted inventory name cannot hide a private path from the binding\n'
newrepo "$TMP/private-quoted"
mkdir -p "$TMP/private-quoted/outputs" "$TMP/private-quoted/.ai-devops"
printf 'x\n' > "$TMP/private-quoted/outputs/report.txt"
printf 'cafe row\n' > "$TMP/private-quoted/outputs/caf$(printf '\303\251').csv"
cat > "$TMP/private-quoted/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"outputs/**","class":"private-evidence"}]}
EOF
git -C "$TMP/private-quoted" add -A
git -C "$TMP/private-quoted" commit -qm private-outputs
check 'the non-ASCII inventory name still binds the sealed route to its class' \
  "rc 3 '$TMP/private-quoted' check --before code-only-review"
check 'and the stop still names the missing fixtures boundary' \
  "out '$TMP/private-quoted' check --before code-only-review | grep -Fq 'synthetic-fixtures-only'"

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
for args in 'start --class' 'start --class prose --reason' 'start --base' 'check --before' 'check --acknowledge' 'check --reviewer-approval' 'check --base'; do
  check "missing value for '$args' fails fast instead of looping" \
    "out=\$(timeout 10 bash '$GATES' $args 2>&1); rc=\$?; [ \$rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'requires a value'"
done

# Owner ruling 2026-10-02 ("yes, small entries can skip the reviewer"): a
# small owner-requested row-data write (1..10 rows) may pass the database gate
# without an AI reviewer, but only when the gate itself reads the repository's
# issue from GitHub (through ai-gh) and finds the owner's words verbatim.
newrepo "$TMP/small-entry" popcre/some-app
( cd "$TMP/small-entry" && "$GATES" start --class code >/dev/null 2>&1 )
SMALL_URL='https://github.com/popcre/some-app/issues/7'
SMALL_Q='add the three Hasbro contacts'
mkdir -p "$TMP/small-gh"
jq -n --arg u "$SMALL_URL" '{url:$u, author:{login:"u2giants"}, body:"Owner request (verbatim): \"add the three Hasbro contacts\"", comments:[]}' > "$TMP/small-gh/7.json"
jq -n '{url:"https://github.com/popcre/some-app/issues/8", author:{login:"someone"}, body:"x", comments:[{author:{login:"stranger"}, body:"add the three Hasbro contacts"}]}' > "$TMP/small-gh/8.json"
jq -n '{url:"https://github.com/popcre/some-app/issues/1", author:{login:"u2giants"}, body:"add the three Hasbro contacts", comments:[]}' > "$TMP/small-gh/9.json"
cat > "$TMP/small-gh/gh" <<EOF
#!/usr/bin/env bash
# Fake real gh behind ai-gh: serves issue JSON fixtures by number.
[ "\$1 \$2" = "issue view" ] || { [ "\$1" = api ] && { echo '{"resources":{"core":{"limit":5000,"remaining":5000,"reset":0}}}'; exit 0; }; exit 0; }
f="$TMP/small-gh/\$3.json"; [ -f "\$f" ] && cat "\$f" || exit 1
EOF
chmod +x "$TMP/small-gh/gh"
export AI_GH_REAL_GH="$TMP/small-gh/gh" AI_GH_STATE_DIR="$TMP/small-gh/state" AI_GH_MIN_SPACING_SECONDS=0 AI_GH_NO_WAIT=1
SMALL="--before database --small-owner-entry"
check 'database without reviewer or small entry stays blocked' \
  "rc 3 '$TMP/small-entry' check --before database"
check 'a 3-row owner entry passes the database gate without a reviewer' \
  "out '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q' | grep -q 'allowed as a small owner-requested entry'"
check 'a 10-row owner entry is still small' \
  "rc 0 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 10 --owner-quote '$SMALL_Q'"
check 'an 11-row entry needs a reviewer' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 11 --owner-quote '$SMALL_Q'"
check 'a zero or non-numeric row count is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 0 --owner-quote '$SMALL_Q' && rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3x --owner-quote '$SMALL_Q'"
check 'a missing row count is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --owner-quote '$SMALL_Q'"
check 'a quote absent from the issue is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote 'delete every contact row'"
check 'a trivially short quote is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote 'add'"
check 'a non-issue URL is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL 'https://example.com/x' --row-count 3 --owner-quote '$SMALL_Q'"
check 'an issue from another repository is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL 'https://github.com/popcre/other/issues/7' --row-count 3 --owner-quote '$SMALL_Q'"
check 'a quote written only by a non-owner is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL 'https://github.com/popcre/some-app/issues/8' --row-count 3 --owner-quote '$SMALL_Q'"
check 'GitHub returning a different issue is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL 'https://github.com/popcre/some-app/issues/9' --row-count 3 --owner-quote '$SMALL_Q'"
check 'an unreadable issue is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL 'https://github.com/popcre/some-app/issues/404' --row-count 3 --owner-quote '$SMALL_Q'"
newrepo "$TMP/small-undeclared" popcre/some-app; echo change > "$TMP/small-undeclared/app.txt"
check 'a small entry without a declared task is refused (no unrecorded release)' \
  "! rc 0 '$TMP/small-undeclared' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q'"
newrepo "$TMP/small-corrupt" popcre/some-app
check 'an unrecordable release is refused' \
  "( cd '$TMP/small-corrupt' && '$GATES' start --class code >/dev/null 2>&1 ) && f=\"\$(state_file_for '$TMP/small-corrupt')\" && jq '.overrides = \"broken\"' \"\$f\" > \"\$f.x\" && mv \"\$f.x\" \"\$f\" && rc 3 '$TMP/small-corrupt' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q'"
check 'small-entry options without --small-owner-entry fail' \
  "rc 1 '$TMP/small-entry' check --before database --row-count 3"
check 'small entry and reviewer approval together fail' \
  "rc 1 '$TMP/small-entry' check $SMALL '$SMALL_URL' --reviewer-approval /nonexistent"
check 'small entry never releases other actions' \
  "rc 3 '$TMP/small-entry' check --before production --small-owner-entry '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q'"
check 'the small-entry release is recorded in task state' \
  "jq -e '.overrides|map(select(.kind==\"small-owner-entry\"))|length>0' \"\$(state_file_for '$TMP/small-entry')\" >/dev/null"
unset AI_GH_REAL_GH AI_GH_STATE_DIR AI_GH_MIN_SPACING_SECONDS AI_GH_NO_WAIT
for args in 'check --small-owner-entry' 'check --row-count' 'check --owner-quote'; do
  check "missing value for '$args' fails fast instead of looping" \
    "out=\$(timeout 10 bash '$GATES' $args 2>&1); rc=\$?; [ \$rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'requires a value'"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
