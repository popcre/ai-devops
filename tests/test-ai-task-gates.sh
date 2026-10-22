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
# Isolate from a live reviewer observation week window on the host running
# the suite; the observation-week section sets its own window explicitly.
export AI_OBSERVATION_WEEK_FILE="$TMP/no-observation-week-window.json"

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
  printf '# Exact review\n\n| reviewed commit | %s%s%s |\n| source digest | %s%s%s |\n\n## Result\n\nApproved fixture source and routes.\nApproved %s.\n\n## Verdict\n\nAPPROVE\n\n' \
    "$(printf '\140')" "$target" "$(printf '\140')" "$(printf '\140')" "$digest" "$(printf '\140')" "$operation" > "$report"
  case "$operation" in
    legacy-managed-launcher-refresh|first-managed-install|partial-managed-launcher-recovery)
      # The review wrapper records the requested operation in the report table.
      sed -i "/^| source digest | /a | operation | $(printf '\140')$operation$(printf '\140') |" "$report" ;;
  esac
  # Resolve with pwd -P (not realpath) so the stored path matches what
  # reviewer_approval_summary computes via cd+pwd -P on Windows CI runners.
  report="$(cd "$(dirname "$report")" && pwd -P)/$(basename "$report")"
  report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
  key="$("$ROOT/bin/ai-review-lifecycle" identity "$dir" | jq -r .repository_key)" || return 1
  state_dir="$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex"
  mkdir -p "$state_dir"
  jq -nc --arg head "$target" --arg source "$digest" --arg report "$report" --arg hash "$report_hash" \
    '{status:"completed",verdict:"APPROVE",stale:false,head:$head,source_digest:$source,report_path:$report,report_sha256:$hash}' \
    > "$state_dir/test.json"
  printf '%s\n' "$report"
}

refresh_report_lifecycle_hash(){
  local report="$1" hash state
  hash="$(sha256sum "$report" | cut -d' ' -f1)"
  while IFS= read -r state; do
    [ -f "$state" ] || continue
    jq -e --arg report "$report" '.report_path==$report' "$state" >/dev/null 2>&1 || continue
    jq --arg hash "$hash" '.report_sha256=$hash' "$state" > "$state.tmp" && mv "$state.tmp" "$state"
  done < <(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -type f -name '*.json' 2>/dev/null)
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
bin/ai-install-skills|reviewer-safety
tests/test-ai-install-skills.sh|reviewer-safety
tools/lib/task-gates.sh|reviewer-safety
tools/application_workflow_target.py|reviewer-safety
config/task-gates.json|reviewer-safety
config/review-action-profiles.json|reviewer-safety
config/muse-code/version|reviewer-safety
config/muse-code/sha256|reviewer-safety
config/muse-code/linux-x86_64/sha256|reviewer-safety
config/opencode/version|reviewer-safety
config/provider-cli-versions.json|reviewer-safety
config/opencode/opencode.json|code
tools/review_action_profile.py|reviewer-safety
bin/ai-process-supervisor|reviewer-safety
services/api/Dockerfile|deployment
infra/main.tf|infrastructure
db/migrations/001_init.sql|shared-db
TABLE

mixed="$(printf 'docs/a.md\nbin/ai-review-lifecycle\ntools/x.sh\n' | ( cd "$TMP/class" && "$GATES" explain --json --paths-from - ))"
check 'mixed change set takes the strongest class' "jq -e '.observed_class==\"reviewer-safety\"' <<<\"\$mixed\""
check 'every changed path is still classified individually' "jq -e '.changes|length==3' <<<\"\$mixed\""
# #1650: a Muse runtime re-pin release (pins + its test + docs) is reviewer-safety,
# so the reviewed toolkit install route accepts it.
repin="$(printf 'config/muse-code/version\nconfig/muse-code/sha256\ntests/test-ai-muse-code.sh\ndocs/muse-opencode.md\n' | ( cd "$TMP/class" && "$GATES" explain --json --paths-from - ))"
check 'reviewer-binary re-pin release is reviewer-safety' "jq -e '.observed_class==\"reviewer-safety\"' <<<\"\$repin\""
check 'unmatched path falls back to code, not to the strongest class' \
  "[ \"\$(class_of 'random/thing.bin')\" = code ]"

newrepo "$TMP/db-canonical" popcre/shared-db
newrepo "$TMP/db-redirected" u2giants/shared-db
db_canonical="$(cd "$TMP/db-canonical" && printf 'migrations/001.sql\n' | "$GATES" explain --json --paths-from -)"
db_redirected="$(cd "$TMP/db-redirected" && printf 'migrations/001.sql\n' | "$GATES" explain --json --paths-from -)"
check 'canonical shared-db identity retains the structural class and gates' \
  "jq -e '.observed_class==\"shared-db\" and ([\"governed-issue-claim\",\"preview-target-proof\",\"production-promotion-authorization\"]- (.required_gates + .unchecked_gates)|length==0)' <<<\"\$db_canonical\""
check 'redirected pre-transfer shared-db identity retains identical structural gates' \
  "[ \"\$(jq -cS '[.observed_class,.required_gates,.forbidden_actions]' <<<\"\$db_canonical\")\" = \"\$(jq -cS '[.observed_class,.required_gates,.forbidden_actions]' <<<\"\$db_redirected\")\" ]"
check 'an enforced promotion gate stays a required gate, not an unchecked one' \
  "jq -e '.required_gates | index(\"production-promotion-authorization\") != null' <<<\"\$db_canonical\""

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
# #1962: the pre-transfer identity is the same repository; its reviewer gates
# are required, never waived, so a manual production action stays refused.
check 'the redirected shared-db identity never unlocks a manual production action' \
  "! rc 0 '$TMP/db-redirected' check --before production"
( cd "$TMP/db-redirected" && "$GATES" start --class production ) >/dev/null
check 'a declared production task in the redirected shared-db identity keeps its reviewer gate required, not waived' \
  "out '$TMP/db-redirected' explain --json | jq -e '.effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null) and (.waived_gates|length)==0'"
check 'a redirected shared-db production refusal names the missing reviewer approval' \
  "rc 3 '$TMP/db-redirected' check --before production && out '$TMP/db-redirected' check --before production | grep -q 'requires an assigned AI reviewer APPROVE'"
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
# Platform brief at task start (#1783), in its own scratch copy so the pilot's
# recorded task state below is untouched.
git clone -q "$TMP/class" "$TMP/brief" 2>/dev/null
( cd "$TMP/brief" && "$GATES" start --class code ) > "$TMP/brief-start.out" 2>&1
check 'start prints no platform brief where the repository ships none' "! grep -q 'PLATFORM CHECK' '$TMP/brief-start.out'"
mkdir -p "$TMP/brief/config"; printf 'PLATFORM CHECK fixture\n' > "$TMP/brief/config/reviewer-platform-brief.txt"
( cd "$TMP/brief" && "$GATES" start --class code ) > "$TMP/brief-start.out" 2>&1
check 'start prints the shipped platform brief before any edit' "grep -q 'PLATFORM CHECK fixture' '$TMP/brief-start.out'"
! ( cd "$TMP/brief" && "$GATES" start --class bogus ) > "$TMP/bad-class.out" 2>&1
check 'start rejects an unknown class and prints the valid class list (#1881)' \
  "grep -q 'unknown change class: bogus (valid: .*ui-live-workflow' '$TMP/bad-class.out'"
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
# Release live check (#1783): a fake gh answers commit-status reads from a
# file, so a fixture release that changes shared review code sees the Ubuntu
# and Windows live-review statuses the test chooses.
live_status() { # STATE -> both live-review contexts at STATE by the trusted login
  jq -n --arg s "$1" '[{context:"ai-devops/live-review/linux",state:$s,created_at:"2026-10-19T00:00:00Z",creator:{login:"u2giants"}},{context:"ai-devops/live-review/windows",state:$s,created_at:"2026-10-19T00:00:00Z",creator:{login:"u2giants"}}]' > "$TMP/live-statuses.json"
}
live_status success
printf '#!/usr/bin/env bash\ncase "$*" in *commits/*/statuses*) cat %q ;; *) exit 1 ;; esac\n' "$TMP/live-statuses.json" > "$TMP/fake-os/gh"
chmod +x "$TMP/fake-os/gh"
class_saved_home="$HOME"; class_saved_path="$PATH"
class_saved_profile="${USERPROFILE:-}"; class_saved_programfiles="${PROGRAMFILES:-}"
export HOME="$TMP/class-home" PATH="$TMP/fake-os:$PATH" USERPROFILE="$TMP/class-home" PROGRAMFILES='C:\Program Files'
if ! command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$TMP/fake-cygpath"
  cat > "$TMP/fake-cygpath/cygpath" <<'EOF'
#!/bin/sh
case "$1" in -u|-wa|-aw|-am) for last in "$@"; do :; done; printf '%s\n' "$last" ;; *) exit 2 ;; esac
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
  "out '$TMP/class-candidate' explain --json | jq -e '(.required_gates + .unchecked_gates + .waived_gates) | index(\"exact-head-independent-review\") != null and index(\"installed-routing-proof\") != null'"
check 'reviewer-safety deploy remains forbidden even with reviewer approval' \
  "rc 3 '$TMP/class-candidate' check --before deploy $class_proof --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
class_state="$(state_file_for "$TMP/class-candidate")"
jq '.declared_class="reviewer-safety"' "$class_state" > "$class_state.tmp" && mv "$class_state.tmp" "$class_state"
check 'a protected task cannot issue installation authority' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
jq '.declared_class="installation"' "$class_state" > "$class_state.tmp" && mv "$class_state.tmp" "$class_state"
# A runner door repeats its own "reviewed commit" table below "## Result"
# (Muse door, #1322). The gate must read the target only from the header.
dup_report_door(){
  local report="$1" target="$2" hash state
  hash="$(sha256sum "$report" | cut -d' ' -f1)"
  awk -v t="$target" '{print} /^## Result$/ {printf "\n# Muse review - runner door\n\n| field | value |\n|---|---|\n| reviewed commit | `%s` |\n", t}' "$report" > "$report.tmp" && mv "$report.tmp" "$report"
  state="$(grep -rl "$hash" "$AI_REVIEW_LIFECYCLE_DIR/runs")" || return 1
  jq --arg s "$(sha256sum "$report" | cut -d' ' -f1)" '.report_sha256=$s' "$state" > "$state.tmp" && mv "$state.tmp" "$state"
}
dup_report_door "$class_report" "$class_target"
check 'a runner-door header repeated below Result still names the exact target' \
  "[ \"\$(grep -c 'reviewed commit' '$class_report')\" = 2 ]"
# Keep the lifecycle record bound to each fixture mutation so these cases
# exercise the raw terminal-shape guard rather than failing only on a hash.
cp "$class_report" "$TMP/class-report-valid"
awk '{ print } /^## Verdict$/ { print "intervening prose" }' "$TMP/class-report-valid" > "$class_report"
refresh_report_lifecycle_hash "$class_report"
check 'intervening text between verdict heading and token is rejected' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
awk '{ if ($0=="APPROVE") print "REJECT"; else print }' "$TMP/class-report-valid" > "$class_report"
refresh_report_lifecycle_hash "$class_report"
check 'raw REJECT cannot be overridden by a completed lifecycle APPROVE' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
awk '{ print } /^APPROVE$/ { print "trailing prose" }' "$TMP/class-report-valid" > "$class_report"
refresh_report_lifecycle_hash "$class_report"
check 'trailing report prose after APPROVE is rejected' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
cp "$TMP/class-report-valid" "$class_report"
refresh_report_lifecycle_hash "$class_report"
# A later merge may land between review and authorization; the reviewed target
# stays authorizable while it is in fetched origin/main history.
class_later="$(git -C "$TMP/class" commit-tree "$class_target^{tree}" -p "$class_target" -m 'later merge')"
git -C "$TMP/class" update-ref refs/remotes/origin/main "$class_later"
# The install routes decide LOCAL_TESTS_REQUIRED before their approval call
# site; an approval without passing test evidence must be refused there, with a
# refusal that names the missing evidence (review finding on d1e12965).
check 'authorize-install refuses an approval that carries no passing test evidence' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy '' '.tests=null')\" && [ ! -e '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json' ]"
check 'authorize-install local-tests refusal names the missing test evidence' \
  "out '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy '' '.tests=null')\" | grep -q 'local-tests'"
live_status failure
check 'a shared review code release without passing live reviews is refused' \
  "out '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\" | grep -q 'ai-release-live-check fleet' && [ ! -e '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json' ]"
live_status success
check 'a separate installation task can issue exact reviewed authority' \
  "rc 0 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
check 'the issued authority binds old and target commits' \
  "jq -e --arg old \"\$(git -C '$TMP/class' rev-parse HEAD)\" --arg target '$class_target' '.installed_head==\$old and .target_head==\$target and .reviewer_approval!=\"\"' '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json'"
check 'authorization cannot be issued twice for one target' \
  "rc 3 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$class_target.json"
# Another session's ordinary pull may fast-forward the installed checkout
# during a long review. A forward move inside start..target is accepted and
# the authority binds the checkout's actual HEAD; a backward move still stops.
class_start="$(git -C "$TMP/class" rev-parse HEAD)"
git -C "$TMP/class" merge -q --ff-only "$class_target"
check 'an installed checkout advanced within the reviewed range can issue authority' \
  "rc 0 '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\""
check 'authority advanced within the range binds the actual installed HEAD' \
  "jq -e --arg target '$class_target' '.installed_head==\$target and .target_head==\$target' '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$class_target.json"
git -C "$TMP/class" reset -q --hard "$class_start^"
check 'an installed checkout moved backward since declaration still stops' \
  "out '$TMP/class-candidate' authorize-install $class_proof --review-report '$class_report' --reviewer-approval \"\$(appr '$TMP/class-candidate' deploy)\" | grep -q 'outside the reviewed release range' && [ ! -e '$AI_TASK_GATES_DIR/install-authorizations/$class_target.json' ]"
git -C "$TMP/class" reset -q --hard "$class_start"
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
case "$1" in -u|-wa|-am) for last in "$@"; do :; done; printf '%s\n' "$last" ;; *) exit 2 ;; esac
EOF
  chmod +x "$TMP/fake-cygpath/cygpath"
  export PATH="$TMP/fake-cygpath:$PATH"
fi
windows_source="$(cygpath -u "$TMP/class/bin/ai-task-gates")"
windows_receipt="$(git -C "$TMP/class" rev-parse HEAD)"
windows_hash="$(sha256sum "$TMP/class/bin/ai-task-gates" | cut -d' ' -f1)"
rm "$class_launcher"
cat > "$class_launcher" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
# source-sha=$windows_receipt
# source-hash=$windows_hash
export HOME="$HOME"
exec "$windows_source" "\$@"
EOF
cat > "$class_launcher.cmd" <<EOF
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
rem source-sha=$windows_receipt
rem source-hash=$windows_hash
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
git -C "$TMP/legacy-primary" worktree add -q --detach "$TMP/legacy-advance" "$legacy_target"
( cd "$TMP/legacy-advance" && "$GATES" start --class installation ) >/dev/null
printf '# new reviewed gate\n' >> "$TMP/legacy-advance/bin/ai-task-gates"
git -C "$TMP/legacy-advance" add bin/ai-task-gates
git -C "$TMP/legacy-advance" commit -qm 'protected legacy cross-commit release'
legacy_advance_target="$(git -C "$TMP/legacy-advance" rev-parse HEAD)"
git -C "$TMP/legacy-advance" update-ref refs/remotes/origin/main "$legacy_advance_target"
legacy_advance_report="$(make_approved_report "$TMP/legacy-advance" "$legacy_advance_target" legacy-managed-launcher-refresh)"
( cd "$TMP/legacy-advance-reviewed" && "$GATES" start --class reviewer-safety --base "$legacy_target" ) >/dev/null
legacy_advance_proof="--target-head $legacy_advance_target --installed-checkout $TMP/legacy-primary --installed-launcher $class_launcher --review-report $legacy_advance_report --reviewer-approval $(appr "$TMP/legacy-advance" deploy "$legacy_advance_target")"
check 'legacy Windows cross-commit migration binds the original installed source' \
  "rc 0 '$TMP/legacy-advance' authorize-install $legacy_advance_proof --legacy-migration"
check 'legacy cross-commit authority retains old checkout and empty original receipt' \
  "jq -e '.legacy_migration==true and .installed_head==\"$legacy_target\" and .windows_receipt_sha==\"\"' '$AI_TASK_GATES_DIR/install-authorizations/$legacy_advance_target.json'"
rm -f "$AI_TASK_GATES_DIR/install-authorizations/$legacy_advance_target.json"
git -C "$TMP/legacy-primary" update-ref refs/remotes/origin/main "$legacy_target"
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
# A report that also approves a sibling operation, or records no operation or a
# different one, must not authorize the requested operation (issue #658).
for op_case in sibling missing-row other-row body-row; do
  cp "$TMP/first-report-backup" "$first_report"
  case "$op_case" in
    sibling) sed -i 's/^Approved first-managed-install\.$/&\nApproved legacy-managed-launcher-refresh./' "$first_report" ;;
    missing-row) sed -i '/^| operation | /d' "$first_report" ;;
    other-row) sed -i 's/^| operation | .*$/| operation | `partial-managed-launcher-recovery` |/' "$first_report" ;;
    # Reviewer text below "## Result" cannot supply the wrapper's operation row.
    body-row) sed -i '/^| operation | /d; s/^## Result$/&\n\n| operation | `first-managed-install` |/' "$first_report" ;;
  esac
  op_hash="$(sha256sum "$first_report" | cut -d' ' -f1)"
  jq --arg hash "$op_hash" '.report_sha256=$hash' "$first_lifecycle" > "$TMP/first-lifecycle-updated"
  mv "$TMP/first-lifecycle-updated" "$first_lifecycle"
  check "install operation binding refuses $op_case report" \
    "rc 3 '$TMP/first-install' authorize-install $first_proof --first-install"
done
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
sed -n '/^windows_program_files(){/,/^}/p' "$GATES" > "$partial_route"
sed -n '/^windows_partial_launcher_route(){/,/^}/p' "$GATES" >> "$partial_route"
cat >> "$partial_route" <<'EOF'
cygpath(){ printf '%s\n' "${@: -1}"; }
EOF
check 'ProgramFiles mixed-case environment is supported' \
  "[ \"\$(PROGRAMFILES= ProgramFiles='D:\\Program Files' bash -c 'source \"$partial_route\"; windows_program_files')\" = 'D:\\Program Files' ]"
windows_detection="$TMP/windows-detection.sh"
cp "$partial_route" "$windows_detection"
cat >> "$windows_detection" <<'EOF'
[(){
  if [[ "$#" -eq 3 && "$1" = -f && "$2" = '/c/Program Files/Git/bin/bash.exe' && "$3" = ']' ]]; then return 0; fi
  builtin [ "$@"
}
cygpath(){ printf '%s\n' 'C:\Program Files'; }
EOF
check 'Windows shell detects existing Git when both ProgramFiles variables are absent' \
  "[ \"\$(PROGRAMFILES= ProgramFiles= bash -c 'source \"$windows_detection\"; windows_program_files')\" = 'C:\\Program Files' ]"
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
  "out '$TMP/mixed-explain' explain --json | jq -e '.effective_class==\"deployment\" and ((.required_gates + .unchecked_gates + .waived_gates)|index(\"exact-head-independent-review\")!=null and index(\"installed-routing-proof\")!=null)'"

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

# Owner ruling 2026-10-15 (#1960): outside popcre/shared-db no PR waits for a
# code review. The production-mutation APPROVE is not a PR review and stays
# enforced everywhere (#1962: DeepSeek REJECT of 5cc973dd).
newrepo "$TMP/noreview"
( cd "$TMP/noreview" && "$GATES" start --class production ) >/dev/null
check 'outside shared-db a production task is still refused without a reviewer approval' \
  "rc 3 '$TMP/noreview' check --before production"
check 'outside shared-db the production-mutation gate stays required, never waived' \
  "out '$TMP/noreview' explain --json | jq -e '(.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null) and (.waived_gates|length)==0'"
check 'outside shared-db a valid exact-head APPROVE still opens the production path' \
  "rc 0 '$TMP/noreview' check --before production --reviewer-approval \"\$(appr '$TMP/noreview' production)\""
# Reviewer regression case: u2giants/ansible, production class, no approval.
newrepo "$TMP/ansible" u2giants/ansible
( cd "$TMP/ansible" && "$GATES" start --class production ) >/dev/null
check 'u2giants/ansible production without an approval fails closed (rc 3)' \
  "rc 3 '$TMP/ansible' check --before production"
check 'u2giants/ansible production refusal names the missing reviewer approval' \
  "out '$TMP/ansible' check --before production | grep -q 'requires an assigned AI reviewer APPROVE'"
check 'u2giants/ansible reports the production gate required, not waived' \
  "out '$TMP/ansible' explain --json | jq -e '.effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null) and (.waived_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")==null)'"
( cd "$TMP/noreview" && "$GATES" start --class deployment ) >/dev/null
check 'outside shared-db a deployment-class check opens without a reviewer approval' \
  "rc 0 '$TMP/noreview' check --before ship"
newrepo "$TMP/clean" popcre/shared-db
check 'no changes at all allows the action' "rc 0 '$TMP/clean' check --before ship"
check 'no changes and no declaration fail closed before production' "rc 4 '$TMP/clean' check --before production"
( cd "$TMP/clean" && "$GATES" start --class production ) >/dev/null
check 'a declared production task retains its production gate with no file change' \
  "out '$TMP/clean' explain --json | jq -e '.observed_class==\"none\" and .effective_class==\"production\" and (.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null)'"
check 'a declared production task is refused without an AI reviewer approval' \
  "rc 3 '$TMP/clean' check --before production"
check 'a production refusal names the missing reviewer approval' \
  "out '$TMP/clean' check --before production | grep -q 'requires an assigned AI reviewer APPROVE'"
check 'a production task refuses a reviewer report path that does not exist' \
  "rc 3 '$TMP/clean' check --before production --reviewer-approval '$TMP/no-such-report.json'"
check 'a production task with a valid exact-head AI APPROVE may enter its guarded path' \
  "rc 0 '$TMP/clean' check --before production --reviewer-approval \"\$(appr '$TMP/clean' production)\""
check 'a production task may still dispatch its review (the approval producer is not gated)' \
  "rc 0 '$TMP/clean' check --before review"
check 'a production task may still wait on its pull request without a reviewer report' \
  "rc 0 '$TMP/clean' check --before pr-wait"
check 'a production task may still run code-only review without a reviewer report' \
  "rc 0 '$TMP/clean' check --before code-only-review"
check 'a production task refuses ship without an AI reviewer approval' \
  "rc 3 '$TMP/clean' check --before ship"
# The pre-rename identity u2giants/shared-db (a redirected remote) is the same
# repository and keeps the reviewer requirement.
newrepo "$TMP/clean-alias" u2giants/shared-db
( cd "$TMP/clean-alias" && "$GATES" start --class production ) >/dev/null
check 'a redirected u2giants/shared-db production task is refused without an AI reviewer approval'   "rc 3 '$TMP/clean-alias' check --before production"
check 'a redirected u2giants/shared-db keeps the reviewer gate required, not waived'   "out '$TMP/clean-alias' explain --json | jq -e '(.required_gates|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null)'"
newrepo "$TMP/rs" popcre/shared-db
( cd "$TMP/rs" && "$GATES" start --class reviewer-safety ) >/dev/null
newrepo "$TMP/unchecked"
( cd "$TMP/unchecked" && "$GATES" start --class code ) >/dev/null
check 'an unenforced gate is never printed as required' \
  "out '$TMP/unchecked' explain --json | jq -e '(.required_gates | index(\"local-tests\") == null) and (.unchecked_gates | index(\"local-tests\") != null)'"
check 'explain names the gates this tool does not check' \
  "out '$TMP/unchecked' explain | grep -q 'not checked by this tool'"
check 'local-tests is a checked gate where a reviewer approval is required' \
  "out '$TMP/rs' explain --json | jq -e '.required_gates | index(\"local-tests\") != null'"
newrepo "$TMP/rawarchive"
( cd "$TMP/rawarchive" && "$GATES" start --class code ) >/dev/null
mkdir -p "$TMP/rawarchive/transcripts" && printf '{}\n' > "$TMP/rawarchive/transcripts/session.jsonl"
check 'a raw transcript archive in the change set is refused for every action' \
  "rc 3 '$TMP/rawarchive' check --before ship"
check 'the raw transcript refusal names the archive path' \
  "out '$TMP/rawarchive' check --before ship | grep -q 'transcripts/session.jsonl'"
newrepo "$TMP/rawclean"
( cd "$TMP/rawclean" && "$GATES" start --class code ) >/dev/null
printf 'ok\n' > "$TMP/rawclean/notes.md"
check 'a change set without raw archives is not refused by the archive rule' \
  "out '$TMP/rawclean' check --before ship | grep -q 'raw transcript' ; ! out '$TMP/rawclean' check --before ship | grep -q 'raw transcript'"
# The archive rule must hold for every action, match case-insensitive
# spellings, fire before weaker action-specific checks, and judge only the
# change set — not files that merely exist in the repository (Muse review
# 2026-10-14).
check 'a raw transcript archive is refused for the database action' \
  "rc 3 '$TMP/rawarchive' check --before database"
check 'the database refusal names the archive path' \
  "out '$TMP/rawarchive' check --before database | grep -q 'transcripts/session.jsonl'"
check 'a raw transcript archive is refused for code-only-review' \
  "rc 3 '$TMP/rawarchive' check --before code-only-review"
check 'a raw transcript archive is refused for deploy' \
  "rc 3 '$TMP/rawarchive' check --before deploy"
check 'the deploy refusal names the archive path before the installation pre-checks' \
  "out '$TMP/rawarchive' check --before deploy | grep -q 'transcripts/session.jsonl'"
check 'a raw transcript archive is refused before the application-workflow argument checks' \
  "rc 3 '$TMP/rawarchive' check --before application-workflow"
check 'the application-workflow refusal names the archive path' \
  "out '$TMP/rawarchive' check --before application-workflow | grep -q 'transcripts/session.jsonl'"
check 'explain surfaces the raw transcript refusal' \
  "out '$TMP/rawarchive' explain | grep -q 'raw transcript or chat archives'"
check 'explain --json lists the raw archive paths' \
  "out '$TMP/rawarchive' explain --json | jq -e '.raw_archive_paths | index(\"transcripts/session.jsonl\") != null'"
newrepo "$TMP/rawupper"
( cd "$TMP/rawupper" && "$GATES" start --class code >/dev/null )
printf '{}\n' > "$TMP/rawupper/session.JSONL"
check 'an uppercase .JSONL extension is refused' "rc 3 '$TMP/rawupper' check --before ship"
check 'the uppercase refusal names the archive path' \
  "out '$TMP/rawupper' check --before ship | grep -q 'session.JSONL'"
newrepo "$TMP/rawuppertree"
( cd "$TMP/rawuppertree" && "$GATES" start --class code >/dev/null )
mkdir -p "$TMP/rawuppertree/Transcripts" && printf 'x\n' > "$TMP/rawuppertree/Transcripts/note.md"
check 'an uppercase Transcripts/ directory is refused' "rc 3 '$TMP/rawuppertree' check --before ship"
newrepo "$TMP/rawupperchat"
( cd "$TMP/rawupperchat" && "$GATES" start --class code >/dev/null )
mkdir -p "$TMP/rawupperchat/Chat_Archives" && printf 'x\n' > "$TMP/rawupperchat/Chat_Archives/note.md"
check 'an uppercase Chat_Archives/ directory is refused' "rc 3 '$TMP/rawupperchat' check --before ship"
newrepo "$TMP/rawnear"
( cd "$TMP/rawnear" && "$GATES" start --class code >/dev/null )
mkdir -p "$TMP/rawnear/my-transcripts" && printf 'x\n' > "$TMP/rawnear/my-transcripts/note.md"
printf 'ok\n' > "$TMP/rawnear/transcripts_backup.md"
check 'transcript-like names outside the archive shapes are not refused' \
  "rc 0 '$TMP/rawnear' check --before ship"
newrepo "$TMP/rawhistory"
mkdir -p "$TMP/rawhistory/transcripts" && printf '{}\n' > "$TMP/rawhistory/transcripts/old.jsonl"
git -C "$TMP/rawhistory" add -A && git -C "$TMP/rawhistory" commit -qm 'historical archive'
check 'a historical archive outside the change set does not block code-only-review' \
  "rc 0 '$TMP/rawhistory' check --before code-only-review"
check 'a historical archive outside the change set does not block ship' \
  "rc 0 '$TMP/rawhistory' check --before ship"
check 'a reviewer-safety task refuses ship without an exact-head independent review' \
  "rc 3 '$TMP/rs' check --before ship"
check 'a reviewer-gated release refuses an approval that carries no passing test evidence' \
  "rc 3 '$TMP/rs' check --before ship --reviewer-approval \"\$(appr '$TMP/rs' ship '' '.tests=null')\""
check 'the local-tests refusal names the missing test evidence' \
  "out '$TMP/rs' check --before ship --reviewer-approval \"\$(appr '$TMP/rs' ship '' '.tests=null')\" | grep -q 'local-tests'"
check 'a refused local-tests release records no reviewer approval in task state' \
  "rc 3 '$TMP/rs' check --before ship --reviewer-approval \"\$(appr '$TMP/rs' ship '' '.tests=null')\" && state=\"\$(state_file_for '$TMP/rs')\" && jq -e '((.overrides // []) | map(select(.kind==\"reviewer-approval\")) | length) == 0' \"\$state\""
check 'a reviewer-safety task ships with a valid exact-head AI APPROVE' \
  "rc 0 '$TMP/rs' check --before ship --reviewer-approval \"\$(appr '$TMP/rs' ship)\""
check 'a production task refuses a report that is not an AI APPROVE for this head' \
  "printf '{}' > '$TMP/fake-report.json'; rc 3 '$TMP/clean' check --before production --reviewer-approval '$TMP/fake-report.json'"
# The evidence requirement must be decided BEFORE every approval call site: a
# LOCAL_TESTS_REQUIRED assigned after the call would never be seen by
# reviewer_approval_summary, and the refusal would silently disappear. This
# static ordering check pins every function that calls it — including the
# offline-native route, the forbidden-release route, install-verify, and
# authorize-install, which have no separate behavioral pin below.
lt_undecided="$(awk '
  /^[A-Za-z_][A-Za-z0-9_]*\(\)/ { fn=$0; sub(/\(.*/, "", fn); decided=0 }
  /^[[:space:]]*#/ { next }
  /decide_local_tests_required[[:space:]]/ { decided=1 }
  /\$\(reviewer_approval_summary/ { if (!decided) printf "%s line %d\n", fn, NR }
' "$GATES")"
check 'LOCAL_TESTS_REQUIRED is decided before every approval call site' \
  "[ -z \"\$lt_undecided\" ] || { printf 'approval call sites with no preceding decide_local_tests_required:\n%s\n' \"\$lt_undecided\" >&2; false; }"

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
  "out '$TMP/gate' explain --json | jq -e '.observed_class==\"prose\" and .effective_class==\"production\" and ((.required_gates+.waived_gates)|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null)'"
check 'a stronger declared class does not drop observed-class required proof' \
  "out '$TMP/gate' explain --json | jq -e '(.required_gates+.waived_gates)|index(\"exact-resource-and-action-ai-reviewer-approval\")!=null'"
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

printf 'reviewed private data writer release (#1239)\n'
newrepo "$TMP/writer" u2giants/licensor-source-data
mkdir -p "$TMP/writer/reconciliation/x" "$TMP/writer/.ai-devops"
( cd "$TMP/writer" && "$GATES" start --class private-tooling ) >/dev/null
printf 'export default 1;\n' > "$TMP/writer/reconciliation/x/writer.mjs"
check 'an undeclared repository keeps database sealed for a writer' \
  "out '$TMP/writer' check --before database --reviewer-approval \"\$(appr '$TMP/writer' database)\" | grep -Fq 'no reviewer-approval'"
# The declaration lands on the base first, through its own PR. That PR changes
# only the repository's gate file, which is private-tooling (it carries no
# licensed rows), so its own sealed code-only review can start.
rm -f "$TMP/writer/reconciliation/x/writer.mjs"
printf '%s\n' '{"schema_version":1,"gates":{"private-tooling":{"required":["synthetic-fixtures-only","reviewed-private-data-writer"]}}}' > "$TMP/writer/.ai-devops/task-gates.json"
check 'the declaration PR itself is private-tooling and reaches code-only review' \
  "rc 0 '$TMP/writer' check --before code-only-review"
git -C "$TMP/writer" add -A && git -C "$TMP/writer" commit -qm declare
( cd "$TMP/writer" && "$GATES" start --class private-tooling --base HEAD ) >/dev/null
printf 'export default 1;\n' > "$TMP/writer/reconciliation/x/writer.mjs"
check 'a declared writer reaches the reviewer-approval step for database' \
  "out '$TMP/writer' check --before database | grep -Fq 'obtain an assigned AI reviewer APPROVE'"
check 'and is still refused without that approval' \
  "rc 3 '$TMP/writer' check --before database"
check 'an approval that is not an exact-head lifecycle APPROVE is refused' \
  "out '$TMP/writer' check --before database --reviewer-approval '$TMP/writer/.ai-devops/task-gates.json' | grep -Fq 'not a lifecycle-recorded'"
check 'the release never opens production for the same writer' \
  "out '$TMP/writer' check --before production --reviewer-approval \"\$(appr '$TMP/writer' production)\" | grep -Fq 'no reviewer-approval'"
check 'the release never opens a formal review' \
  "rc 3 '$TMP/writer' check --before review"
printf 'id,name\n1,secret\n' > "$TMP/writer/reconciliation/x/rows.csv"
check 'one licensed row keeps database sealed despite the declaration' \
  "out '$TMP/writer' check --before database --reviewer-approval \"\$(appr '$TMP/writer' database)\" | grep -Fq 'no reviewer-approval'"
rm -rf "$TMP/writer"

printf 'infrastructure production reviewer release stays pinned, declared and reviewer-gated\n'
infra_decl='{"schema_version":1,"paths":[{"glob":"**","class":"infrastructure"}],"gates":{"infrastructure":{"required":["reviewed-production-dispatch"],"forbidden_actions":["infrastructure","production"]}}}'
infra_repo(){ # <dir> <identity> — declared, committed, clean; local origin/main forged to HEAD
  newrepo "$1" "$2"
  mkdir -p "$1/.ai-devops"; printf '%s\n' "$infra_decl" > "$1/.ai-devops/task-gates.json"
  git -C "$1" add -A && git -C "$1" commit -qm declare
  git -C "$1" update-ref refs/remotes/origin/main HEAD
  ( cd "$1" && "$GATES" start --class infrastructure --base HEAD ) >/dev/null
}
newrepo "$TMP/infra-undeclared" 'u2giants/ansible'
( cd "$TMP/infra-undeclared" && "$GATES" start --class infrastructure --base HEAD ) >/dev/null
check 'an undeclared infrastructure repository keeps production sealed' \
  "out '$TMP/infra-undeclared' check --before production --reviewer-approval \"\$(appr '$TMP/infra-undeclared' production)\" | grep -Fq 'no reviewer-approval'"
infra_repo "$TMP/infra" 'u2giants/ansible'
check 'a forged local origin/main never stands in for the real GitHub main' \
  "out '$TMP/infra' check --before production --reviewer-approval \"\$(appr '$TMP/infra' production)\" | grep -Fq 'no reviewer-approval'"
check 'the release never opens the infrastructure action' \
  "out '$TMP/infra' check --before infrastructure --reviewer-approval \"\$(appr '$TMP/infra' infrastructure)\" | grep -Fq 'no reviewer-approval'"
git -C "$TMP/infra" config url."https://github.com/u2giants/ansible.git".insteadOf "file://$TMP/fake-origin.git"
git -C "$TMP/infra" remote set-url origin "file://$TMP/fake-origin.git"
check 'an insteadOf-rewritten origin cannot impersonate the ansible repository' \
  "out '$TMP/infra' check --before production --reviewer-approval \"\$(appr '$TMP/infra' production)\" | grep -Fq 'no reviewer-approval'"
infra_repo "$TMP/infra-foreign" 'u2giants/hiclaw'
check 'another repository with the same declaration keeps production sealed' \
  "out '$TMP/infra-foreign' check --before production --reviewer-approval \"\$(appr '$TMP/infra-foreign' production)\" | grep -Fq 'no reviewer-approval'"
jq '.reviewer_release.production.infrastructure="anything"' "$ROOT/config/task-gates.json" > "$TMP/broad-infra.json"
check 'central policy cannot broaden the infrastructure production release' \
  "AI_TASK_GATES_FILE='$TMP/broad-infra.json' out '$TMP/infra-foreign' check --before production | grep -Fq 'closed u2giants/ansible production boundary'"
rm -rf "$TMP/infra" "$TMP/infra-undeclared" "$TMP/infra-foreign" "$TMP/broad-infra.json"
# The positive path needs the real repository: a clean clone of the current
# u2giants/ansible main (which declares the gate) reaches the approval step,
# then starts only with the exact-head APPROVE; a dirty or unpushed head and an
# uncommitted declaration stay sealed. Skipped only when GitHub is unreachable.
if git clone -q --depth 1 https://github.com/u2giants/ansible.git "$TMP/ansible-real" 2>/dev/null \
  && grep -q reviewed-production-dispatch "$TMP/ansible-real/.ai-devops/task-gates.json"; then
  git -C "$TMP/ansible-real" config user.name T; git -C "$TMP/ansible-real" config user.email t@e
  ( cd "$TMP/ansible-real" && "$GATES" start --class infrastructure --base HEAD ) >/dev/null
  check 'the real ansible main reaches the reviewer-approval step for production' \
    "out '$TMP/ansible-real' check --before production | grep -Fq 'obtain an assigned AI reviewer APPROVE'"
  check 'and is still refused without that approval' \
    "rc 3 '$TMP/ansible-real' check --before production"
  check 'and starts with an exact-head AI reviewer APPROVE' \
    "rc 0 '$TMP/ansible-real' check --before production --reviewer-approval \"\$(appr '$TMP/ansible-real' production)\""
  printf 'x\n' > "$TMP/ansible-real/untracked.txt"
  check 'a dirty checkout keeps production sealed' \
    "out '$TMP/ansible-real' check --before production --reviewer-approval \"\$(appr '$TMP/ansible-real' production)\" | grep -Fq 'no reviewer-approval'"
  rm -f "$TMP/ansible-real/untracked.txt"
  git -C "$TMP/ansible-real" commit -q --allow-empty -m unpushed
  check 'an unpushed head keeps production sealed' \
    "out '$TMP/ansible-real' check --before production --reviewer-approval \"\$(appr '$TMP/ansible-real' production)\" | grep -Fq 'no reviewer-approval'"
else
  printf '  skip real ansible main positive path (GitHub unreachable or gate not yet declared)\n'
fi
rm -rf "$TMP/ansible-real"

printf 'private code review keeps evidence and mutation boundaries\n'
newrepo "$TMP/private" 'u2giants/licensor-source-data'
mkdir -p "$TMP/private/disney-dcpvault" "$TMP/private/.ai-devops"
printf '# synthetic loader code only\n' > "$TMP/private/disney-dcpvault/loader.py"
# A synthetic fixture under the licensed folder keeps this change set in
# private-evidence; the gate file alone is private-tooling (#1239).
printf 'id\n0\n' > "$TMP/private/disney-dcpvault/fixture.csv"
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
  "out '$TMP/private' explain --json | jq -e '.effective_class==\"private-evidence\" and ([\"privacy-classification\",\"no-raw-content-read\",\"licensed-row-containment\",\"synthetic-fixtures-only\"] - (.required_gates + .unchecked_gates) | length==0)'"
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
jq '.reviewer_release.database["private-evidence"] = "whatever"' \
  "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/bad-release.json"
jq '.application_source_releases["popcre/designflow-backend"].target.project = "wrong-project"' \
  "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/bad-application-target.json"
newrepo "$TMP/schema-repo"
check 'a reviewer release broadening the private-evidence boundary fails closed' \
  "[ \"\$(AI_TASK_GATES_FILE='$SCHEMA_TMP/bad-release.json' out '$TMP/schema-repo' check --before review >/dev/null 2>&1; echo \$?)\" = 4 ]"
check 'a centrally altered application release target fails schema validation' \
  "! '$PY_BIN' '$VALIDATE' '$SCHEMA_TMP/bad-application-target.json'"
check 'an action-gate naming an unknown action fails closed' \
  "[ \"\$(AI_TASK_GATES_FILE='$SCHEMA_TMP/bad-action.json' out '$TMP/schema-repo' check --before review >/dev/null 2>&1; echo \$?)\" = 4 ]"
check 'an action-gate naming an undeclared class fails closed' \
  "[ \"\$(AI_TASK_GATES_FILE='$SCHEMA_TMP/bad-class.json' out '$TMP/schema-repo' check --before review >/dev/null 2>&1; echo \$?)\" = 4 ]"

# The application exception is an exact committed source target, not a generic
# release of deployment actions or the reviewer-safety refusal.
check 'new source-release proof module passes offline real-graph and mocked API tests' \
  "'$PY_BIN' '$ROOT/tests/test_application_source_release.py'"

for new_repo in designflow-tracking designflow-frontend designflow-item-master; do
  NEW_APP="$TMP/$new_repo-release"
  newrepo "$NEW_APP" "popcre/$new_repo"
  NEW_BASE="$(git -C "$NEW_APP" rev-parse HEAD)"
  mkdir -p "$NEW_APP/.ai-devops" "$NEW_APP/supabase"
  jq --arg repo "popcre/$new_repo" '.application_source_releases[$repo].target' \
    "$ROOT/config/task-gates.json" > "$NEW_APP/.ai-devops/application-release-target.json"
  printf '%s\n' '{"schema_version":1,"gates":{"deployment":{"required":["cloud-build-release-review"]}}}' \
    > "$NEW_APP/.ai-devops/task-gates.json"
  printf '%s\n' '-- actual owned structural delta, not an inherited mirror' > "$NEW_APP/supabase/owned.sql"
  git -C "$NEW_APP" add .ai-devops supabase && git -C "$NEW_APP" commit -qm 'new target structural refusal fixture'
  ( cd "$NEW_APP" && "$GATES" start --class deployment --base "$NEW_BASE" >/dev/null 2>&1 )
  if [ "$("$PY_BIN" -c 'import sys; print(sys.platform)')" != linux ]; then
    check "$new_repo new Linux-only target refuses unsupported platform without affecting backend" \
      "rc 3 '$NEW_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json"
    continue
  fi
  # CI may put its own Git in /usr/local/bin. The admitted fixture must select
  # the lane's pinned /usr/bin/git; an alternate PATH remains a runtime refusal.
  mkdir -p "$TMP/new-app-shadow-git"
  printf '#!/bin/sh\nexec /usr/bin/git "$@"\n' > "$TMP/new-app-shadow-git/git"
  chmod +x "$TMP/new-app-shadow-git/git"
  check "$new_repo alternate PATH Git still fails pre-discovery confinement" \
    "got=\"\$(PATH='$TMP/new-app-shadow-git':\"\$PATH\" out '$NEW_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json)\"; status=\$?; [ \"\$status\" -eq 3 ] && printf '%s\\n' \"\$got\" | grep -q 'pre-discovery confinement refused'"
  check "$new_repo cannot hide an actual shared-db contributor behind deployment rank" \
    "got=\"\$(PATH='/usr/bin:/bin':\"\$PATH\" out '$NEW_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json)\"; status=\$?; [ \"\$status\" -eq 3 ] && printf '%s\\n' \"\$got\" | grep -q 'cannot contain structural'"
  check "$new_repo no receipt is published by structural refusal" \
    "! jq -e '.overrides | any(.kind==\"application-source-release\")' \"\$(state_file_for '$NEW_APP')\" >/dev/null"
  NEW_STATE="$(state_file_for "$NEW_APP")"
  jq '.overrides=[{kind:"application-source-release",action:"deploy",observed_class:"deployment",reason:"legacy backend receipt"}]' \
    "$NEW_STATE" > "$NEW_STATE.fixture"
  mv "$NEW_STATE.fixture" "$NEW_STATE"
  cp "$NEW_STATE" "$NEW_STATE.before"
  git -C "$NEW_APP" rm -q supabase/owned.sql && git -C "$NEW_APP" commit -qm 'no owned structural delta remains'
  check "$new_repo old backend receipt cannot authorize an off-branch new-target release" \
    "rc 3 '$NEW_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json && cmp -s '$NEW_STATE' '$NEW_STATE.before'"
  check "$new_repo Git directory injection is refused before discovery" \
    "(cd '$NEW_APP' && GIT_DIR='/not/a/repository' '$GATES' check --before deploy --application-release-target .ai-devops/application-release-target.json 2>&1) | grep -q 'pre-discovery confinement refused'"
  # The opt-in declaration is already upstream in this future-release case.
  # Only ordinary app/pipeline files change, so no reviewer-safety delta can
  # accidentally supply the generic-deploy refusal on behalf of this guard.
  NEW_FUTURE_BASE="$(git -C "$NEW_APP" rev-parse HEAD)"
  printf '%s\n' '// next ordinary app release fixture' > "$NEW_APP/app.js"
  printf '%s\n' 'steps: []' > "$NEW_APP/cloudbuild.yaml"
  git -C "$NEW_APP" add app.js cloudbuild.yaml && git -C "$NEW_APP" commit -qm 'future ordinary source release'
  ( cd "$NEW_APP" && "$GATES" start --class deployment --base "$NEW_FUTURE_BASE" >/dev/null 2>&1 )
  NEW_APPROVAL="$(appr "$NEW_APP" deploy "$(git -C "$NEW_APP" rev-parse HEAD)")"
  check "$new_repo upstream closed-gate opt-in refuses future generic deploy even with exact approval" \
    "rc 3 '$NEW_APP' check --before deploy --reviewer-approval '$NEW_APPROVAL' && out '$NEW_APP' check --before deploy --reviewer-approval '$NEW_APPROVAL' | grep -q 'requires explicit --application-release-target'"
  check "$new_repo closed-gate opt-in leaves review action unchanged" \
    "rc 0 '$NEW_APP' check --before review"
  # A forged backend manifest cannot switch source identity to the old route.
  jq '.application_source_releases["popcre/designflow-backend"].target' \
    "$ROOT/config/task-gates.json" > "$NEW_APP/.ai-devops/application-release-target.json"
  git -C "$NEW_APP" add .ai-devops/application-release-target.json && git -C "$NEW_APP" commit -qm 'forged backend target'
  check "$new_repo forged backend manifest cannot acquire a new-target receipt" \
    "rc 3 '$NEW_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json"
done

for policy_case in missing fifth cross-target; do
  case "$policy_case" in
    missing) policy_filter='del(.application_source_releases["popcre/designflow-tracking"])' ;;
    fifth) policy_filter='.application_source_releases["popcre/foreign"] = .application_source_releases["popcre/designflow-backend"]' ;;
    cross-target) policy_filter='.application_source_releases["popcre/designflow-tracking"].target.service = "popcre-albert-item-sandbox"' ;;
  esac
  jq "$policy_filter" "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/release-$policy_case.json"
  check "closed four-target source release schema rejects $policy_case policy" \
    "! '$PY_BIN' '$VALIDATE' '$SCHEMA_TMP/release-$policy_case.json'"
done

APP="$TMP/application-release"
newrepo "$APP" popcre/designflow-backend
APP_BASE="$(git -C "$APP" rev-parse HEAD)"
( cd "$APP" && "$GATES" start --class deployment --base "$APP_BASE" >/dev/null 2>&1 )
mkdir -p "$APP/.ai-devops"
cat > "$APP/.ai-devops/task-gates.json" <<'EOF'
{"schema_version":1,"paths":[{"glob":"src/router.ts","class":"reviewer-safety"}],"gates":{"deployment":{"required":["cloud-build-release-review"]}}}
EOF
cat > "$APP/.ai-devops/application-release-target.json" <<'EOF'
{"schema_version":1,"repository":"popcre/designflow-backend","route":"cloud-build-branch-push","branch":"sandbox-albert","project":"lithe-breaker-323913","region":"us-east4","service":"popcre-albert-core-sandbox"}
EOF
printf 'steps: []\n' > "$APP/cloudbuild.yaml"
mkdir -p "$APP/bin"
printf '# application reviewer route fixture\n' > "$APP/bin/ai-review-lifecycle"
mkdir -p "$APP/src"
printf 'reviewed application router fixture\n' > "$APP/src/router.ts"
git -C "$APP" add .ai-devops/task-gates.json .ai-devops/application-release-target.json cloudbuild.yaml bin/ai-review-lifecycle src/router.ts
git -C "$APP" commit -qm 'declare reviewed sandbox source target'
APP_HEAD="$(git -C "$APP" rev-parse HEAD)"
APP_APPROVAL="$(appr "$APP" deploy "$APP_HEAD")"
check 'application release fixture actually contains a changed reviewer-safety router' \
  "out '$APP' explain --json | jq -e '.changes | any(.class==\"reviewer-safety\" and .path==\"src/router.ts\")' >/dev/null"
check 'mixed protected application source keeps the generic deployment refusal' \
  "rc 3 '$APP' check --before deploy --reviewer-approval '$APP_APPROVAL'"
check 'the exact committed application source target records its independent approval' \
  "out '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL' | grep -q 'recorded exact application source-release override'"
check 'outside shared-db the application source route records its release without a reviewer approval' \
  "rc 0 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json"
check 'application source route rejects a reviewer REJECT' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(appr '$APP' deploy '$APP_HEAD' '.verdict=\"REJECT\"')\""
check 'application source route rejects plan-review for a live action' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(mint_reviewer_approval '$TMP' '$APP' plan-review '$APP_HEAD')\""
check 'application source route rejects a self-provider approval' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(appr '$APP' deploy '$APP_HEAD' '.provider=\"claude\"')\""
check 'application source route rejects a stale approval' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(appr '$APP' deploy '$APP_HEAD' '.stale=true')\""
check 'application source route rejects an approval for another source digest' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(appr '$APP' deploy '$APP_HEAD' '.source_digest=\"foreign\"')\""
check 'application source route rejects an approval for another repository' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval \"\$(appr '$APP' deploy '$APP_HEAD' '.repository_key=\"foreign\"')\""
check 'application source target cannot be used for another action' \
  "rc 3 '$APP' check --before review --application-release-target .ai-devops/application-release-target.json"
check 'application source target cannot override an explicit comparison base' \
  "rc 3 '$APP' check --before deploy --base HEAD --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
check 'application source target cannot combine with acknowledgement' \
  "rc 3 '$APP' check --before deploy --acknowledge reason --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
check 'application source target cannot combine with toolkit installation arguments' \
  "rc 3 '$APP' check --before deploy --target-head HEAD --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
check 'application source target cannot combine with small-owner entry' \
  "rc 3 '$APP' check --before deploy --small-owner-entry https://github.com/popcre/designflow-backend/issues/1 --row-count 1 --owner-quote request --application-release-target .ai-devops/application-release-target.json"
check 'application source target rejects a noncanonical manifest path' \
  "rc 3 '$APP' check --before deploy --application-release-target cloudbuild.yaml --reviewer-approval '$APP_APPROVAL'"
 jq '.reviewer_release.deploy={deployment:"generic-release"}' "$ROOT/config/task-gates.json" > "$SCHEMA_TMP/generic-deployment-release.json"
check 'application source route fails closed if central policy adds a generic protected deployment release' \
  "AI_TASK_GATES_FILE='$SCHEMA_TMP/generic-deployment-release.json' rc 4 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
check 'application source override is persisted with its exact head and manifest blob' \
  "jq -e '.overrides | any(.kind==\"application-source-release\" and .action==\"deploy\" and (.reason|contains(\"head=$APP_HEAD manifest_blob=\")))' \"\$(state_file_for '$APP')\" >/dev/null"

PRIVATE_APP="$TMP/private-application"
newrepo "$PRIVATE_APP" popcre/designflow-backend
( cd "$PRIVATE_APP" && "$GATES" start --class code --base HEAD >/dev/null 2>&1 )
mkdir -p "$PRIVATE_APP/.ai-devops" "$PRIVATE_APP/disney-dcpvault"
printf '%s\n' '{"schema_version":1,"paths":[{"glob":"disney-dcpvault/**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["synthetic-fixtures-only"],"forbidden_actions":["deploy"]}}}' > "$PRIVATE_APP/.ai-devops/task-gates.json"
cp "$APP/.ai-devops/application-release-target.json" "$PRIVATE_APP/.ai-devops/application-release-target.json"
printf 'id,name\n1,secret\n' > "$PRIVATE_APP/disney-dcpvault/rows.csv"
git -C "$PRIVATE_APP" add .ai-devops disney-dcpvault && git -C "$PRIVATE_APP" commit -qm 'add private evidence to app fixture'
check 'private application fixture is classified as private-evidence' \
  "( cd '$PRIVATE_APP' && '$GATES' explain --json | jq -e '.effective_class==\"private-evidence\"' >/dev/null )"
check 'application source target cannot release private-evidence changes' \
  "rc 3 '$PRIVATE_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json"

TOOLKIT_APP="$TMP/toolkit-application"
newrepo "$TOOLKIT_APP" u2giants/ai-devops
( cd "$TOOLKIT_APP" && "$GATES" start --class deployment >/dev/null 2>&1 )
mkdir -p "$TOOLKIT_APP/.ai-devops"
printf '%s\n' '{"schema_version":1,"gates":{"deployment":{"required":["cloud-build-release-review"]}}}' > "$TOOLKIT_APP/.ai-devops/task-gates.json"
cp "$APP/.ai-devops/application-release-target.json" "$TOOLKIT_APP/.ai-devops/application-release-target.json"
printf 'steps: []\n' > "$TOOLKIT_APP/cloudbuild.yaml"
git -C "$TOOLKIT_APP" add .ai-devops cloudbuild.yaml && git -C "$TOOLKIT_APP" commit -qm 'add toolkit target fixture'
TOOLKIT_APPROVAL="$(appr "$TOOLKIT_APP" deploy "$(git -C "$TOOLKIT_APP" rev-parse HEAD)")"
check 'application source target cannot authorize a toolkit repository' \
  "out '$TOOLKIT_APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$TOOLKIT_APPROVAL' 2>&1 | grep -q 'limited to canonical popcre/designflow-backend'"

APP_OLD_APPROVAL="$APP_APPROVAL"
printf 'source moved after review\n' >> "$APP/README.md"
git -C "$APP" add README.md && git -C "$APP" commit -qm 'move source after prior approval'
APP_HEAD="$(git -C "$APP" rev-parse HEAD)"
APP_APPROVAL="$(appr "$APP" deploy "$APP_HEAD")"
check 'application source route rejects an approval for the previous source HEAD' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_OLD_APPROVAL'"
APP_STATE="$(state_file_for "$APP")"
APP_STATE_BEFORE="$TMP/app-state-before-publication-failure.json"
cp "$APP_STATE" "$APP_STATE_BEFORE"
APP_REAL_MV="$(command -v mv)"
mkdir "$TMP/app-mv-fail"
cat > "$TMP/app-mv-fail/mv" <<'EOF'
#!/usr/bin/env bash
destination=""
for argument in "$@"; do destination="$argument"; done
[ "$destination" != "$AI_TEST_ATOMIC_TARGET" ] || exit 1
exec "$AI_TEST_REAL_MV" "$@"
EOF
chmod +x "$TMP/app-mv-fail/mv"
APP_WRITE_OUT="$(cd "$APP" && PATH="$TMP/app-mv-fail:$PATH" AI_TEST_ATOMIC_TARGET="$APP_STATE" AI_TEST_REAL_MV="$APP_REAL_MV" "$GATES" check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval "$APP_APPROVAL" 2>&1)"; APP_WRITE_RC=$?
check 'application source route fails closed when exact override state cannot be recorded' \
  "[ '$APP_WRITE_RC' -eq 3 ] && printf '%s' \"\$APP_WRITE_OUT\" | grep -q 'exact application source-release proof could not be recorded' && cmp -s '$APP_STATE' '$APP_STATE_BEFORE' && ! jq -e --arg h '$APP_HEAD' '.overrides | any(.kind==\"application-source-release\" and (.reason|contains(\"head=\"+\$h)))' '$APP_STATE' >/dev/null"

cp "$APP/.ai-devops/application-release-target.json" "$TMP/valid-application-manifest.json"
for schema_value in true 1.0 '"1"'; do
  cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
  python3 - "$APP/.ai-devops/application-release-target.json" "$APP/manifest.tmp" "$schema_value" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value["schema_version"] = json.loads(sys.argv[3])
pathlib.Path(sys.argv[2]).write_text(json.dumps(value) + "\n", encoding="utf-8")
PY
  mv "$APP/manifest.tmp" "$APP/.ai-devops/application-release-target.json"
  git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'invalid application manifest version type'
  APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
  check "application source route rejects schema_version type $schema_value in a committed manifest" \
    "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
done
for field in repository route branch project region service; do
  cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
  case "$field" in
    *) jq --arg k "$field" '.[$k]="unapproved"' "$APP/.ai-devops/application-release-target.json" > "$APP/manifest.tmp" ;;
  esac
  mv "$APP/manifest.tmp" "$APP/.ai-devops/application-release-target.json"
  git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'invalid application manifest target binding'
  APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
  check "application source route rejects a wrong $field binding" \
    "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
done
cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
printf '{"schema_version":1,"schema_version":1,"repository":"popcre/designflow-backend","route":"cloud-build-branch-push","branch":"sandbox-albert","project":"lithe-breaker-323913","region":"us-east4","service":"popcre-albert-core-sandbox"}\n' > "$APP/.ai-devops/application-release-target.json"
git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'duplicate application manifest key'
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
check 'application source route rejects duplicate manifest keys' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
printf '{broken\n' > "$APP/.ai-devops/application-release-target.json"
git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'malformed application manifest JSON'
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
check 'application source route rejects malformed manifest JSON' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'restore valid application manifest'
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
printf ' ' >> "$APP/.ai-devops/application-release-target.json"
check 'application source route rejects a dirty manifest even when its values remain valid' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
rm "$APP/.ai-devops/application-release-target.json"
ln -s README.md "$APP/.ai-devops/application-release-target.json"
check 'application source route rejects a symlink manifest' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
rm "$APP/.ai-devops/application-release-target.json"
check 'application source route rejects a missing manifest' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
jq '.extra="unapproved"' "$APP/.ai-devops/application-release-target.json" > "$APP/manifest.tmp"
mv "$APP/manifest.tmp" "$APP/.ai-devops/application-release-target.json"
check 'application source route rejects an extra manifest property' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
git -C "$APP" checkout -q -- .ai-devops/application-release-target.json
git -C "$APP" rm -q .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'remove application target manifest'
cp "$TMP/valid-application-manifest.json" "$APP/.ai-devops/application-release-target.json"
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
check 'application source route rejects an untracked manifest' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
git -C "$APP" add .ai-devops/application-release-target.json && git -C "$APP" commit -qm 'restore application target manifest'
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
printf '{"schema_version":1,"gates":{"deployment":{"required":[]}}}\n' > "$APP/.ai-devops/task-gates.json"
check 'application source route requires the consumer declaration gate' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
git -C "$APP" checkout -q -- .ai-devops/task-gates.json
jq '.gates.deployment.forbidden_actions=["deploy"]' "$APP/.ai-devops/task-gates.json" > "$APP/policy.tmp"
mv "$APP/policy.tmp" "$APP/.ai-devops/task-gates.json"
git -C "$APP" add .ai-devops/task-gates.json && git -C "$APP" commit -qm 'consumer forbids application deploy'
APP_APPROVAL="$(appr "$APP" deploy "$(git -C "$APP" rev-parse HEAD)")"
check 'application source target cannot bypass consumer forbidden deploy action' \
  "rc 3 '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL'"
git -C "$APP" remote set-url origin https://github.com/popcre/other.git
 ( cd "$APP" && "$GATES" start --class deployment >/dev/null 2>&1 )
check 'application source route rejects a foreign GitHub origin' \
  "out '$APP' check --before deploy --application-release-target .ai-devops/application-release-target.json --reviewer-approval '$APP_APPROVAL' 2>&1 | grep -q 'limited to canonical popcre/designflow-backend'"
git -C "$APP" remote set-url origin https://github.com/popcre/designflow-backend.git

# A flag given without its value must fail fast, never spin: on 2026-09-17 an
# orphaned `start --class` burned 11 CPU-hours and starved the local GLM server.
for args in 'start --class' 'start --class prose --reason' 'start --base' 'check --before' 'check --acknowledge' 'check --reviewer-approval' 'check --base' 'check --application-release-target'; do
  check "missing value for '$args' fails fast instead of looping" \
    "out=\$(timeout 10 bash '$GATES' $args 2>&1); rc=\$?; [ \$rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'requires a value'"
done

# Owner ruling 2026-10-14 ("Our own safety rules require a second AI to
# approve database writes. Remove that rule."): database writes open without
# an AI reviewer. --small-owner-entry remains optional history only.
newrepo "$TMP/small-entry" popcre/some-app
( cd "$TMP/small-entry" && "$GATES" start --class code >/dev/null 2>&1 )
SMALL_URL='https://github.com/popcre/some-app/issues/7'
SMALL_Q='add the three Hasbro contacts'
mkdir -p "$TMP/small-gh"
jq -n --arg u "$SMALL_URL" '{url:$u, author:{login:"u2giants"}, body:"Owner request (verbatim): \"add the three Hasbro contacts\"", comments:[]}' > "$TMP/small-gh/7.json"
jq -n '{url:"https://github.com/popcre/some-app/issues/8", author:{login:"someone"}, body:"x", comments:[{author:{login:"stranger"}, body:"add the three Hasbro contacts"}]}' > "$TMP/small-gh/8.json"
jq -n '{url:"https://github.com/popcre/some-app/issues/10", user:{login:"someone"}, body:"x", comments:[{user:{login:"popcre"}, body:"please add the two Mattel licensor rows"}]}' > "$TMP/small-gh/10.json"
jq -n '{url:"https://github.com/popcre/some-app/issues/1",author:{login:"u2giants"}, body:"add the three Hasbro contacts", comments:[]}' > "$TMP/small-gh/9.json"
cat > "$TMP/small-gh/gh" <<EOF
#!/usr/bin/env bash
# Fake real gh behind ai-gh: serves issue JSON fixtures by number.
[ "\$1 \$2" = "issue view" ] || { [ "\$1" = api ] && { echo '{"resources":{"core":{"limit":5000,"remaining":5000,"reset":0}}}'; exit 0; }; exit 0; }
f="$TMP/small-gh/\$3.json"; [ -f "\$f" ] && cat "\$f" || exit 1
EOF
chmod +x "$TMP/small-gh/gh"
export AI_GH_REAL_GH="$TMP/small-gh/gh" AI_GH_STATE_DIR="$TMP/small-gh/state" AI_GH_MIN_SPACING_SECONDS=0 AI_GH_NO_WAIT=1
SMALL="--before database --small-owner-entry"
check 'database without reviewer or small entry is allowed (owner ruling 2026-10-14)' \
  "out '$TMP/small-entry' check --before database | grep -q 'skip second-AI approval' && rc 0 '$TMP/small-entry' check --before database"
check 'a 3-row owner entry records optional history without a reviewer' \
  "out '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q' | grep -q 'optional small owner entry'"
check 'a 10-row owner entry is still valid optional history' \
  "rc 0 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 10 --owner-quote '$SMALL_Q'"
check 'a 390-row owner entry has no size cap' \
  "rc 0 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 390 --owner-quote '$SMALL_Q'"
newrepo "$TMP/prod-entry" popcre/some-app
( cd "$TMP/prod-entry" && "$GATES" start --class production >/dev/null 2>&1 )
check 'a 390-row owner-requested write in a production task passes without a reviewer' \
  "out '$TMP/prod-entry' check $SMALL '$SMALL_URL' --row-count 390 --owner-quote '$SMALL_Q' | grep -q 'no AI reviewer' && jq -e '.overrides|map(select(.kind==\"small-owner-entry\"))|length>0' \"\$(state_file_for '$TMP/prod-entry')\" >/dev/null"
echo change > "$TMP/prod-entry/app.txt"
check 'with a changed file the 390-row production owner entry still passes without a reviewer' \
  "out '$TMP/prod-entry' check $SMALL '$SMALL_URL' --row-count 390 --owner-quote '$SMALL_Q' | grep -q 'no AI reviewer'"
check 'a production database write without an owner entry stays sealed' \
  "rc 3 '$TMP/prod-entry' check --before database"
check 'a production owner entry with an unverified quote stays sealed' \
  "rc 3 '$TMP/prod-entry' check $SMALL '$SMALL_URL' --row-count 390 --owner-quote 'delete every contact row'"
check 'a production owner entry never opens the production action' \
  "rc 3 '$TMP/prod-entry' check --before production --small-owner-entry '$SMALL_URL' --row-count 390 --owner-quote '$SMALL_Q'"
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
check 'an owner request quoted only in an owner comment (REST user.login) qualifies' \
  "rc 0 '$TMP/small-entry' check $SMALL 'https://github.com/popcre/some-app/issues/10' --row-count 2 --owner-quote 'add the two Mattel licensor rows'"
check 'a whitespace-padded quote under 12 real characters is refused' \
  "rc 3 '$TMP/small-entry' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote 'add the     '"
newrepo "$TMP/small-infra" popcre/some-app
( cd "$TMP/small-infra" && "$GATES" start --class code >/dev/null 2>&1 )
mkdir -p "$TMP/small-infra/infra"; printf 'x\n' > "$TMP/small-infra/infra/main.tf"
check 'an infrastructure change set never qualifies as a small owner entry' \
  "! rc 0 '$TMP/small-infra' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q'"
newrepo "$TMP/small-structural" popcre/some-app
( cd "$TMP/small-structural" && "$GATES" start --class code >/dev/null 2>&1 )
mkdir -p "$TMP/small-structural/db/migrations"; printf 'select 1;\n' > "$TMP/small-structural/db/migrations/001.sql"
check 'a structural change set escalates and never uses the small-entry path' \
  "! rc 0 '$TMP/small-structural' check $SMALL '$SMALL_URL' --row-count 3 --owner-quote '$SMALL_Q' && ! jq -e '(.overrides // [])|map(select(.kind==\"small-owner-entry\"))|length>0' \"\$(state_file_for '$TMP/small-structural')\" >/dev/null 2>&1"
unset AI_GH_REAL_GH AI_GH_STATE_DIR AI_GH_MIN_SPACING_SECONDS AI_GH_NO_WAIT
for args in 'check --small-owner-entry' 'check --row-count' 'check --owner-quote'; do
  check "missing value for '$args' fails fast instead of looping" \
    "out=\$(timeout 10 bash '$GATES' $args 2>&1); rc=\$?; [ \$rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'requires a value'"
done

# #1355: `explain --paths-from FILE` reuses an earlier answer only while every
# input is byte-identical; any change to them is a fresh classification.
newrepo "$TMP/xcache" popcre/ai-devops
XC="$TMP/xcache"; XP="$TMP/xcache-paths"; printf 'docs/a.md\n' > "$XP"
xc_class(){ ( cd "$XC" && "$GATES" explain --json --paths-from "$XP" ) | jq -r .effective_class; }
xc_count(){ find "$AI_TASK_GATES_DIR/explain-cache" -maxdepth 1 -type f ! -name '.tmp.*' 2>/dev/null | wc -l | tr -d ' '; }
first="$(cd "$XC" && "$GATES" explain --json --paths-from "$XP")"; before="$(xc_count)"
second="$(cd "$XC" && "$GATES" explain --json --paths-from "$XP")"
uncached="$(cd "$XC" && AI_TASK_GATES_EXPLAIN_CACHE=0 "$GATES" explain --json --paths-from "$XP")"
check 'explain cache returns the uncached answer byte for byte' "[ -n '$first' ] && [ '$first' = '$second' ] && [ '$second' = '$uncached' ] && [ '$before' -ge 1 ] && [ \"\$(xc_count)\" = '$before' ]"
cp "$XP" "$XP.copy"
check 'the same inventory in a fresh temporary file reuses the answer' "[ \"\$(cd '$XC' && '$GATES' explain --json --paths-from '$XP.copy')\" = '$first' ] && [ \"\$(xc_count)\" = '$before' ]"
check 'explain cache never applies to an explain without --paths-from FILE' "[ \"\$(cd '$XC' && '$GATES' explain --json | jq -r .effective_class)\" != '' ] && [ \"\$(xc_count)\" = '$before' ]"
printf 'bin/ai-review-lifecycle\n' > "$XP"
check 'a changed path inventory is classified afresh' "[ \"\$(xc_class)\" = reviewer-safety ]"
printf 'docs/a.md\n' > "$XP"
( cd "$XC" && "$GATES" start --class private-evidence >/dev/null 2>&1 )
check 'a newly recorded task class is honoured over a cached answer' "[ \"\$(xc_class)\" = private-evidence ]"
( cd "$XC" && "$GATES" end >/dev/null 2>&1 )
check 'clearing the task class is honoured over a cached answer' "[ \"\$(xc_class)\" != private-evidence ]"
mkdir -p "$XC/.ai-devops"; xc_class >/dev/null
printf '{"schema_version":1,"paths":[{"glob":"docs/**","class":"private-evidence"}]}\n' > "$XC/.ai-devops/task-gates.json"
check 'a changed consumer declaration is classified afresh' "[ \"\$(xc_class)\" = private-evidence ]"
printf 'not json\n' > "$XC/.ai-devops/task-gates.json"
check 'a corrupt consumer declaration still fails closed with a cache present' "! ( cd '$XC' && '$GATES' explain --json --paths-from '$XP' ) >/dev/null 2>&1"
rm -rf "$XC/.ai-devops"
cp "$AI_TASK_GATES_FILE" "$TMP/xcache-policy.json"
( cd "$XC" && AI_TASK_GATES_FILE="$TMP/xcache-policy.json" "$GATES" explain --json --paths-from "$XP" ) >/dev/null
jq '.rules += [{"match":"*/ai-devops","paths":[{"glob":"docs/**","class":"reviewer-safety"}],"gates":{}}]' "$AI_TASK_GATES_FILE" > "$TMP/xcache-policy.json"
check 'a changed central policy at the same path is classified afresh' "[ \"\$(cd '$XC' && AI_TASK_GATES_FILE='$TMP/xcache-policy.json' '$GATES' explain --json --paths-from '$XP' | jq -c .)\" = \"\$(cd '$XC' && AI_TASK_GATES_FILE='$TMP/xcache-policy.json' AI_TASK_GATES_EXPLAIN_CACHE=0 '$GATES' explain --json --paths-from '$XP' | jq -c .)\" ] && [ \"\$(cd '$XC' && AI_TASK_GATES_FILE='$TMP/xcache-policy.json' '$GATES' explain --json --paths-from '$XP' | jq -r .effective_class)\" = reviewer-safety ]"
git -C "$XC" remote set-url origin https://github.com/popcre/some-other-repo.git
check 'a changed repository identity is classified afresh' "[ \"\$(cd '$XC' && '$GATES' explain --json --paths-from '$XP' | jq -r .repository)\" = popcre/some-other-repo ]"
check 'the explain cache directory is private' "[ \"\$(stat -c %a '$AI_TASK_GATES_DIR/explain-cache' 2>/dev/null || echo 700)\" = 700 ]"

# #1355: AI_TASK_GATES_INPUTS_TO names every file an explain answer read, so
# a review can reuse that answer only while each one is unchanged. The answer
# itself is byte-identical with or without the list.
git -C "$XC" remote set-url origin https://github.com/popcre/ai-devops.git
XI="$TMP/xcache-inputs"
plain="$(cd "$XC" && AI_TASK_GATES_EXPLAIN_CACHE=0 "$GATES" explain --json --paths-from "$XP")"
listed="$(cd "$XC" && AI_TASK_GATES_EXPLAIN_CACHE=0 AI_TASK_GATES_INPUTS_TO="$XI" "$GATES" explain --json --paths-from "$XP")"
check 'explain inputs list leaves the answer byte-identical' "[ -n '$plain' ] && [ '$plain' = '$listed' ]"
( cd "$XC" && "$GATES" start --class code >/dev/null 2>&1 )
( cd "$XC" && AI_TASK_GATES_INPUTS_TO="$XI" "$GATES" explain --json --paths-from "$XP" ) >/dev/null
state_file="$(ls "$AI_TASK_GATES_DIR"/*.json | while read -r f; do jq -e --arg t "$(cd "$XC" && pwd -P)" '.' "$f" >/dev/null 2>&1 && grep -qxF "$f" "$XI" && echo "$f"; done | head -1)"
check 'explain inputs list names the task state file start wrote' "[ -n '$state_file' ] && [ -f '$state_file' ]"
check 'explain inputs list names the policy, library, program and declaration' "grep -qxF '$AI_TASK_GATES_FILE' '$XI' && grep -q '/tools/lib/task-gates.sh\$' '$XI' && grep -q '/bin/ai-task-gates\$' '$XI' && grep -q '/.ai-devops/task-gates.json\$' '$XI' && ! grep -qv '^/' '$XI'"
( cd "$XC" && "$GATES" end >/dev/null 2>&1 )
rm -f "$XI"
check 'a failed explain writes no inputs list' "! ( cd '$XC' && AI_TASK_GATES_INPUTS_TO='$XI' '$GATES' explain --json --paths-from /nonexistent ) >/dev/null 2>&1; [ ! -s '$XI' ]"

# jqr keeps jq's exact bytes (trailing blank lines, CRLF) and its exit status.
# #1355: the one-pass rule table and the per-question readers must agree. A
# non-string rule match forces the readers without changing what applies.
TABLE="$(mktemp -d)"; git init -q "$TABLE/r"; mkdir -p "$TABLE/r/.ai-devops" "$TABLE/r/src"
printf '%s' '{"paths":[{"glob":"src/**","class":"shared-db"}],"gates":{"shared-db":{"required":["zz-proof","a-proof"],"forbidden_actions":["deploy"]},"prose":{"required":["r"]}}}' > "$TABLE/r/.ai-devops/task-gates.json"
echo x > "$TABLE/r/src/a.sql"; echo y > "$TABLE/r/README.md"
jq '.rules += [{"match":5}]' "$ROOT/config/task-gates.json" > "$TABLE/fallback.json"
cp "$ROOT/config/task-gates.json" "$TABLE/fast.json"
table_run(){ (cd "$TABLE/r" && for a in review deploy ship; do AI_TASK_GATES_FILE="$TABLE/$1.json" "$GATES" check --before "$a" 2>&1; echo "rc=$?"; done); }
check 'one-pass rule table matches the per-question readers' \
  "[ \"\$(table_run fast)\" = \"\$(table_run fallback)\" ] && table_run fast | grep -q 'a-proof'"
rm -rf "$TABLE"

# Install checks swap POLICY_FILE between revisions in one process; the rule
# table must follow the swap or a revision is classified with another's globs.
SWAP="$(mktemp -d)"
cp "$ROOT/config/task-gates.json" "$SWAP/a.json"
jq '.default.paths = [{"glob":"secret/**","class":"private-evidence"}] + .default.paths' "$ROOT/config/task-gates.json" > "$SWAP/b.json"
mkdir -p "$SWAP/bin"; ln -s "$ROOT/tools" "$SWAP/tools"; sed '$d' "$GATES" > "$SWAP/bin/gates-functions"
swap_probe(){ ( set +eu; source "$SWAP/bin/gates-functions"; CONSUMER_FILE="$SWAP/none.json"
  for f in a b; do POLICY_FILE="$SWAP/$f.json"; load_policy; classify_paths local/x 'secret/k'; printf '%s ' "$OBSERVED_CLASS"; done ) 2>/dev/null; }
check 'rule table follows a POLICY_FILE swap' "swap_probe | grep -Eq '^[a-z-]+ private-evidence \$' && [ \"\$(swap_probe | cut -d' ' -f1)\" != private-evidence ]"
rm -rf "$SWAP"

JQR_FN="$(sed -n '/^jqr(){$/,/^}$/p' "$GATES")"
check 'jqr strips CR, keeps trailing blank lines, and returns jq status' "eval \"\$JQR_FN\"; a=\"\$(printf '[\"a\\\\r\",\"\",\"\"]' | jqr '.[]'; printf x)\"; [ \"\$a\" = \$'a\\n\\n\\nx' ] && ! printf 'nope' | jqr . >/dev/null 2>&1"

WF="$TMP/application-workflow"
check 'closed retry profile adversarial inputs' "python3 '$ROOT/tests/test_application_workflow_target.py'"
newrepo "$WF" popcre/designflow-backend
(cd "$WF" && "$GATES" start --class reviewer-safety >/dev/null)
mkdir -p "$WF/.ai-devops"
python3 - "$ROOT" "$WF" <<'PY'
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('target', sys.argv[1] + '/tools/application_workflow_target.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
pathlib.Path(sys.argv[2] + '/.ai-devops/application-workflow-target.json').write_text(json.dumps(mod.TARGET))
PY
git -C "$WF" add .ai-devops/application-workflow-target.json
git -C "$WF" commit -qm 'declare ordinary sandbox workflow'
WF_HEAD="$(git -C "$WF" rev-parse HEAD)"
WF_APPROVAL="$(appr "$WF" application-workflow "$WF_HEAD")"
WF_ARGS="--before application-workflow --application-workflow-target .ai-devops/application-workflow-target.json"
check 'exact independent workflow admission succeeds' "rc 0 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
WF_STATE="$(state_file_for "$WF")"
cp "$WF_STATE" "$TMP/wf-state-before"
WF_WRITE_OUT="$(cd "$WF" && PATH="$TMP/app-mv-fail:$PATH" AI_TEST_ATOMIC_TARGET="$WF_STATE" AI_TEST_REAL_MV="$APP_REAL_MV" "$GATES" check $WF_ARGS --reviewer-approval "$WF_APPROVAL" 2>&1)"; WF_WRITE_RC=$?
check 'workflow fails closed without a durable receipt' "[ '$WF_WRITE_RC' -eq 3 ] && printf '%s' \"\$WF_WRITE_OUT\" | grep -q 'receipt could not be persisted' && cmp -s '$WF_STATE' '$TMP/wf-state-before'"
check 'ordinary database action remains sealed' "rc 3 '$WF' check --before database --reviewer-approval '$WF_APPROVAL'"
check 'workflow cannot omit explicit target' "rc 3 '$WF' check --before application-workflow --reviewer-approval '$WF_APPROVAL'"
check 'workflow cannot omit review' "rc 3 '$WF' check $WF_ARGS"
check 'workflow cannot override base' "rc 3 '$WF' check $WF_ARGS --base HEAD --reviewer-approval '$WF_APPROVAL'"
check 'workflow cannot use plan review' "rc 3 '$WF' check $WF_ARGS --reviewer-approval \"\$(mint_reviewer_approval '$TMP' '$WF' plan-review '$WF_HEAD')\""
check 'workflow refuses stale approval' "rc 3 '$WF' check $WF_ARGS --reviewer-approval \"\$(appr '$WF' application-workflow '$WF_HEAD' '.stale=true')\""
check 'workflow refuses foreign digest' "rc 3 '$WF' check $WF_ARGS --reviewer-approval \"\$(appr '$WF' application-workflow '$WF_HEAD' '.source_digest=\"foreign\"')\""
check 'workflow refuses non-independent approval' "rc 3 '$WF' check $WF_ARGS --reviewer-approval \"\$(appr '$WF' application-workflow '$WF_HEAD' '.provider=.implementer_engine')\""
check 'workflow refuses an approval that carries no passing test evidence' "rc 3 '$WF' check $WF_ARGS --reviewer-approval \"\$(appr '$WF' application-workflow '$WF_HEAD' '.tests=null')\""
check 'workflow local-tests refusal names the missing test evidence' "out '$WF' check $WF_ARGS --reviewer-approval \"\$(appr '$WF' application-workflow '$WF_HEAD' '.tests=null')\" | grep -q 'local-tests'"
cp "$WF/.ai-devops/application-workflow-target.json" "$TMP/wf-original"
python3 - "$ROOT" "$WF" <<'PY'
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('target', sys.argv[1] + '/tools/application_workflow_target.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
pathlib.Path(sys.argv[2] + '/.ai-devops/application-workflow-target.json').write_text(json.dumps(mod.RECOVERY_TARGET))
PY
git -C "$WF" add .ai-devops/application-workflow-target.json
git -C "$WF" commit -qm 'declare exact audited sandbox retry'
WF_APPROVAL="$(appr "$WF" application-workflow)"
check 'exact independently reviewed retry admission succeeds' "rc 0 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
check 'retry profile still refuses SQL' "rc 3 '$WF' check --before database --reviewer-approval '$WF_APPROVAL'"
cp "$TMP/wf-original" "$WF/.ai-devops/application-workflow-target.json"
git -C "$WF" add .ai-devops/application-workflow-target.json
git -C "$WF" commit -qm 'restore original ordinary workflow'
WF_APPROVAL="$(appr "$WF" application-workflow)"
printf ' ' >> "$WF/.ai-devops/application-workflow-target.json"
check 'workflow refuses dirty manifest' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
cp "$TMP/wf-original" "$WF/.ai-devops/application-workflow-target.json"
jq '.service="production"' "$TMP/wf-original" > "$WF/.ai-devops/application-workflow-target.json"
check 'workflow refuses wrong service' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
printf '{"schema_version":1,"schema_version":1}\n' > "$WF/.ai-devops/application-workflow-target.json"
check 'workflow refuses duplicate keys' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
rm "$WF/.ai-devops/application-workflow-target.json"
ln -s "$TMP/wf-original" "$WF/.ai-devops/application-workflow-target.json"
check 'workflow refuses symlink manifest' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
rm "$WF/.ai-devops/application-workflow-target.json"
cp "$TMP/wf-original" "$WF/.ai-devops/application-workflow-target.json"
git -C "$WF" remote set-url origin https://github.com/popcre/other.git
check 'workflow refuses foreign origin before reaching admission' "rc 4 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
(cd "$WF" && "$GATES" start --class reviewer-safety >/dev/null)
check 'workflow refuses declared foreign repository at canonical identity check' "out '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL' | grep -q 'requires canonical popcre/designflow-backend'"
git -C "$WF" remote set-url origin https://github.com/popcre/designflow-backend.git
(cd "$WF" && "$GATES" start --class production >/dev/null)
check 'workflow refuses stronger production class' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
(cd "$WF" && "$GATES" start --class private-evidence >/dev/null)
check 'workflow refuses private evidence class' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"
(cd "$WF" && "$GATES" start --class reviewer-safety >/dev/null)
printf '{"schema_version":1,"gates":{"reviewer-safety":{"forbidden_actions":["application-workflow"]}}}' > "$WF/.ai-devops/task-gates.json"
git -C "$WF" add .ai-devops/task-gates.json
git -C "$WF" commit -qm 'local workflow prohibition'
WF_APPROVAL="$(appr "$WF" application-workflow)"
check 'workflow preserves consumer prohibition' "rc 3 '$WF' check $WF_ARGS --reviewer-approval '$WF_APPROVAL'"

# Public generated route keeps the class/forbidden union; no generic opening.
GEN="$TMP/generated-public"
newrepo "$GEN" popcre/designflow-backend
mkdir -p "$GEN/.ai-devops"
printf '%s\n' '{"schema_version":1,"paths":[{"glob":"plan_*.md","class":"reviewer-safety"}],"gates":{"reviewer-safety":{"required":["reviewed-generated-definition-fixture-only"],"forbidden_actions":[]}}}' > "$GEN/.ai-devops/task-gates.json"
git -C "$GEN" add .ai-devops/task-gates.json
git -C "$GEN" commit -qm 'fixture closed consumer gate'
(cd "$GEN" && "$GATES" start --class reviewer-safety --base HEAD >/dev/null)
printf '%s\n' 'fixed generated-only fixture' > "$GEN/plan_fixture.md"
check 'generated opt-in never opens ordinary reviewer-safety database' "rc 3 '$GEN' check --before database"
check 'generated opt-in never opens deploy, infrastructure, or production' \
  "rc 3 '$GEN' check --before deploy && rc 3 '$GEN' check --before infrastructure && rc 3 '$GEN' check --before production"
check 'generated opt-in cannot acknowledge protected database prohibition' \
  "rc 3 '$GEN' check --before database --acknowledge fixture"
GEN_APPROVAL="$(appr "$GEN" database)"
check 'generated route refuses missing bounded stdin even with source approval' \
  "rc 3 '$GEN' check --before database --reviewer-approval '$GEN_APPROVAL'"
check 'generated selector cannot authorize missing runtime, malformed envelope or uninstalled helper' \
  "printf '%s' '{\"fixture_id\":\"generated-definition-boundary-v1\"}' | rc 3 '$GEN' check --before database --action-manifest-stdin --reviewer-approval '$GEN_APPROVAL'"
check 'generated route cannot borrow original restoration stage' \
  "printf '%s' '{\"fixture_id\":\"generated-definition-boundary-v1\"}' | rc 3 '$GEN' check --before database --action-manifest-stdin --action-stage original-restoration --reviewer-approval '$GEN_APPROVAL'"
jq '.reviewer_release.database["reviewer-safety"]="generic-database"' "$ROOT/config/task-gates.json" > "$TMP/bad-generated-policy.json"
check 'central generated release refuses a broadened reviewer-safety gate name' \
  "AI_TASK_GATES_FILE='$TMP/bad-generated-policy.json' rc 4 '$GEN' check --before database"

check 'scoped skill gate refuses missing plan and approval' \
  "rc 3 '$TMP/rs' check --before scoped-skills-install"
check 'scoped skill gate cannot bypass universal raw archive refusal' \
  "out '$TMP/rawarchive' check --before scoped-skills-install | grep -q 'transcripts/session.jsonl'"
check 'scoped skill plan cannot be supplied to a different action' \
  "rc 1 '$TMP/rs' check --before ship --scoped-skills-plan '$TMP/not-a-plan'"

printf 'observation week merge gate (plan_reviewer-observation-week step 4)\n'
OWT="$TMP/ow"; mkdir -p "$OWT/detached"
ow_window(){ # START END CLASSES_JSON
  printf '{"start":"%s","end":"%s","allowed_classes":%s}\n' "$1" "$2" "$3" > "$OWT/window.json"
}
OW_NOW_START="$(date -u -d '-1 hour' +%FT%TZ)"; OW_NOW_END="$(date -u -d '+6 days' +%FT%TZ)"
ow_out(){ ( cd "$1" && shift && AI_OBSERVATION_WEEK_FILE="$OWT/window.json" AI_REVIEW_DETACH_DIR="$OWT/detached" \
  AI_REVIEW_SCOREBOARD_FILE="$OWT/reviews.jsonl" "$GATES" "$@" ) 2>&1; }
ow_rc(){ local want="$1" got; shift; ow_out "$@" >/dev/null; got=$?; [ "$got" -eq "$want" ]; }
newrepo "$TMP/ow-code" popcre/ow-fixture
printf 'x\n' > "$TMP/ow-code/tool.sh"; git -C "$TMP/ow-code" add -A; git -C "$TMP/ow-code" commit -qm code
( cd "$TMP/ow-code" && "$GATES" start --class code >/dev/null 2>&1 )
OW_HEAD="$(git -C "$TMP/ow-code" rev-parse HEAD)"
ow_window "$OW_NOW_START" "$OW_NOW_END" '["code","prose"]'
check 'observation_window_never_blocks_unreviewed_ordinary_code' \
  "ow_rc 0 '$TMP/ow-code' check --before ship && ow_out '$TMP/ow-code' check --before ship | grep -q 'needs none' && ! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED'"
printf '{"id":"d20261021T000000-1-1","status":"pending","head":"%s"}\n' "$OW_HEAD" > "$OWT/detached/d20261021T000000-1-1.json"
check 'observation_window_admits_code_merge_with_detached_run' \
  "ow_out '$TMP/ow-code' check --before ship | grep -qx 'MERGE-UNREVIEWED' && ow_out '$TMP/ow-code' check --before ship | grep -q 'Unreviewed merge (observation week, run d20261021T000000-1-1)'"
rm -f "$OWT/detached/"*.json
printf '{"id":"s20261021T000000-1-1","status":"all-skipped","head":"%s"}\n' "$OW_HEAD" > "$OWT/detached/s20261021T000000-1-1.json"
check 'observation_window_admits_all_skipped_75' \
  "ow_out '$TMP/ow-code' check --before ship | grep -qx 'MERGE-UNREVIEWED' && ow_out '$TMP/ow-code' check --before ship | grep -q 'all-skipped)'"
rm -f "$OWT/detached/"*.json
printf '{"provider":"muse","head":"%s","verdict":"APPROVE","stale":false,"failure_class":null}\n' "$OW_HEAD" > "$OWT/reviews.jsonl"
check 'observation_window_approved_head_merges_normally' \
  "ow_rc 0 '$TMP/ow-code' check --before ship && ! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED'"
rm -f "$OWT/reviews.jsonl"
printf '{"id":"d1","status":"pending","head":"0000000000000000000000000000000000000000"}\n' > "$OWT/detached/d1.json"
check 'unreviewed_label_without_evidence_refuses' "! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED'"
rm -f "$OWT/detached/"*.json
ow_window "$(date -u -d '-9 days' +%FT%TZ)" "$(date -u -d '-2 days' +%FT%TZ)" '["code","prose"]'
check 'observation_window_expired_refuses' \
  "ow_rc 0 '$TMP/ow-code' check --before ship && ! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED' && ow_out '$TMP/ow-code' check --before ship | grep -q 'observation week not applied (window has ended'"
printf '{"start":' > "$OWT/window.json"
check 'observation_window_malformed_refuses' \
  "! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED' && ow_out '$TMP/ow-code' check --before ship | grep -q 'window file is malformed'"
ow_window "$OW_NOW_END" "$OW_NOW_START" '["code"]'
check 'observation_window_reversed_dates_refuse' "ow_out '$TMP/ow-code' check --before ship | grep -q 'end is not after its start'"
ow_window "$OW_NOW_START" "$OW_NOW_END" '["code","shared-db"]'
check 'observation_window_rejects_protected_classes_in_file' \
  "ow_out '$TMP/ow-code' check --before ship | grep -q 'admits a protected class' && ! ow_out '$TMP/ow-code' check --before ship | grep -q 'MERGE-UNREVIEWED'"
ow_window "$OW_NOW_START" "$OW_NOW_END" '["code","prose"]'
newrepo "$TMP/ow-db" popcre/ow-fixture
mkdir -p "$TMP/ow-db/db/migrations"; printf 'select 1;\n' > "$TMP/ow-db/db/migrations/001.sql"
git -C "$TMP/ow-db" add -A; git -C "$TMP/ow-db" commit -qm migration
( cd "$TMP/ow-db" && "$GATES" start --class shared-db >/dev/null 2>&1 )
printf '{"id":"d2","status":"pending","head":"%s"}\n' "$(git -C "$TMP/ow-db" rev-parse HEAD)" > "$OWT/detached/d2.json"
check 'observation_window_never_admits_shared_db_or_production' \
  "! ow_out '$TMP/ow-db' check --before shared-db-promotion | grep -q 'MERGE-UNREVIEWED' && ow_rc 3 '$TMP/ow-db' check --before production && ! ow_out '$TMP/ow-db' check --before ship | grep -q 'MERGE-UNREVIEWED'"
newrepo "$TMP/ow-rs" popcre/ai-devops
mkdir -p "$TMP/ow-rs/bin"; printf '#!/bin/sh\n' > "$TMP/ow-rs/bin/ai-review-lifecycle"; git -C "$TMP/ow-rs" add -A; git -C "$TMP/ow-rs" commit -qm reviewer
( cd "$TMP/ow-rs" && "$GATES" start --class reviewer-safety >/dev/null 2>&1 )
check 'observation_window_freezes_reviewer_code_and_installs' \
  "ow_rc 3 '$TMP/ow-rs' check --before ship && ow_out '$TMP/ow-rs' check --before ship | grep -q 'are frozen'"
check 'observation_window_still_lets_reviews_start' "! ow_out '$TMP/ow-rs' check --before review | grep -q 'are frozen'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
