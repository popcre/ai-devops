#!/usr/bin/env bash
# Offline Linux installer/updater front-door tests. No /etc or GitHub access.
set -euo pipefail
[ "$(uname -s)" = Linux ] || { echo 'SKIP: Linux installer authorization tests are Linux-only'; exit 0; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
printf '{"schema_version":1,"verdict":"APPROVE"}\n' > "$TMP/approval.json"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" TEST_LOG="$TMP/gate.log"
mkdir -p "$HOME" "$TMP/src/bin"

cat > "$TMP/src/bin/ai-task-gates" <<'GATE'
#!/usr/bin/env bash
set -eu
if [ "${1:-}" = start ]; then
  [ "$(git rev-parse --show-toplevel)" = "$PWD" ] || exit 45
  printf 'start\n' >> "$TEST_LOG"
  [ "${TEST_GATE_DENY_PHASE:-}" != start ] || exit 46
  [ "${2:-}" = --class ] && [ "${3:-}" = installation ] || exit 47
  exit 0
fi
phase=''
owner=''
caller_pinned=0
stage_report=''
target=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase) phase="$2"; shift 2 ;;
    --reviewer-approval) owner="$2"; shift 2 ;;
    --caller-pinned) caller_pinned=1; shift ;;
    --stage-report) stage_report="$2"; shift 2 ;;
    --target-head) target="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' "$phase" >> "$TEST_LOG"
if [ -n "${TEST_CAPTURE_UMASK_FILE:-}" ]; then
  umask > "$TEST_CAPTURE_UMASK_FILE"
fi
[ "$phase" != preflight ] || [ "$(git rev-parse --show-toplevel)" = "$PWD" ] || exit 48
[ "${TEST_GATE_DENY_PHASE:-}" != "$phase" ] || exit 41
if [ "${TEST_GATE_RECOVER_PHASE:-}" = "$phase" ]; then
  printf 'AI_DEVOPS_INSTALL_RECOVERED=%s\n' "$target"
  exit 0
fi
if [ "${TEST_ASSERT_GATE_CWD:-0}" = 1 ]; then
  [ "$(git rev-parse --show-toplevel)" = "$PWD" ] || exit 50
fi
if [ "$phase" = stages-complete ]; then
  [ -f "$stage_report" ] && [ "$(stat -c %a "$stage_report")" = 600 ] || exit 49
fi
if [ "$phase" = resume ] && [ "${TEST_REQUIRE_OWNER:-0}" = 1 ]; then
  [ -n "$owner" ] || exit 42
fi
if [ "$phase" = preflight ] && [ "${TEST_REQUIRE_PIN:-0}" = 1 ]; then
  [ "$caller_pinned" = 1 ] || exit 43
fi
if [ "$phase" = preflight ] && [ "${TEST_REQUIRE_OWNER_PREFLIGHT:-0}" = 1 ]; then
  [ -n "$owner" ] || exit 44
fi
GATE
chmod +x "$TMP/src/bin/ai-task-gates"
cp "$ROOT/install.sh" "$ROOT/update.sh" "$TMP/src/"
git -C "$TMP/src" init -q -b main
git -C "$TMP/src" config user.name Fixture
git -C "$TMP/src" config user.email fixture@example.invalid
git -C "$TMP/src" add install.sh update.sh bin/ai-task-gates
git -C "$TMP/src" commit -qm baseline
git init -q --bare "$TMP/remote.git"
git -C "$TMP/src" remote add origin "$TMP/remote.git"
git -C "$TMP/src" push -q -u origin main
git clone -q -b main "$TMP/remote.git" "$TMP/installed"

fail() { echo "FAIL: $*" >&2; exit 1; }
check_head() { [ "$(git -C "$TMP/installed" rev-parse HEAD)" = "$1" ] || fail 'installed HEAD changed'; }
grep -Fq 'run_stage required "Reviewer requalification"' "$ROOT/install.sh" ||
  fail 'installer must require reviewer requalification before finalize'
before="$(git -C "$TMP/installed" rev-parse HEAD)"

# A direct installer must refuse before any stage on an authorization failure.
: > "$TEST_LOG"
if TEST_GATE_DENY_PHASE=resume "$TMP/installed/install.sh" --test-authorization-only >/dev/null 2>&1; then
  fail 'direct installer accepted denied resume'
fi
check_head "$before"
[ "$(cat "$TEST_LOG")" = resume ] || fail 'direct installer did not check resume'

# Same-source maintenance forwards its assigned AI reviewer approval; the gate decides.
if TEST_REQUIRE_OWNER=1 "$TMP/installed/install.sh" --test-authorization-only >/dev/null 2>&1; then
  fail 'same-source install accepted missing reviewer approval'
fi
TEST_REQUIRE_OWNER=1 TEST_ASSERT_GATE_CWD=1 "$TMP/installed/install.sh" --reviewer-approval "$TMP/approval.json" \
  --test-authorization-only >/dev/null
(
  umask 022
  TEST_CAPTURE_UMASK_FILE="$TMP/installer-umask" "$TMP/installed/install.sh" --reviewer-approval "$TMP/approval.json" \
    --test-authorization-only >/dev/null
)
[ "$(cat "$TMP/installer-umask")" = 0022 ] || fail 'installer leaked private lock umask into later stages'
[ "$(stat -c %a "$HOME/.local/state/ai-devops/task-gates")" = 700 ] || fail 'installation lock directory is not private'
lock_file=("$HOME"/.local/state/ai-devops/task-gates/install-*.lock)
[ "${#lock_file[@]}" -eq 1 ] && [ "$(stat -c %a "${lock_file[0]}")" = 600 ] || fail 'installation lock file is not private'
: > "$TEST_LOG"
TEST_GATE_RECOVER_PHASE=resume "$TMP/installed/install.sh" --test-authorization-only > "$TMP/recovered-direct-output"
grep -Fq 'Prior installation of' "$TMP/recovered-direct-output" || fail 'direct installer ignored recovered completion'
[ "$(cat "$TEST_LOG")" = resume ] || fail 'recovered direct install ran stages after resume'

# A second direct installer cannot pass the checkout lock even if its gate
# would have accepted it. The first holder retains the fd for this test.
lock_dir="$HOME/.local/state/ai-devops/task-gates"
lock_file="$lock_dir/install-$(printf '%s' "$TMP/installed" | sha256sum | cut -c1-16).lock"
exec 8>"$lock_file"
flock -n 8
count_before="$(wc -l < "$TEST_LOG")"
if "$TMP/installed/install.sh" --test-authorization-only >/dev/null 2>&1; then
  fail 'second installer ignored checkout lock'
fi
[ "$(wc -l < "$TEST_LOG")" = "$count_before" ] || fail 'second installer reached gate while locked'
flock -u 8
exec 8>&-

# Candidate target contains an inert install stub, so update.sh can exercise
# its pinned fetch/preflight/advance/finalize sequence without machine writes.
cat > "$TMP/src/install.sh" <<'INSTALL'
#!/usr/bin/env bash
set -eu
printf 'install\n' >> "$TEST_LOG"
"$(dirname "$0")/bin/ai-task-gates" install-verify --phase resume \
  --target-head "$(git -C "$(dirname "$0")" rev-parse HEAD)" \
  --installed-checkout "$(dirname "$0")" \
  --installed-launcher /usr/local/bin/ai-task-gates
if [ "${TEST_INSTALL_FAIL:-0}" = 1 ]; then
  printf '%s\n' "$(git -C "$(dirname "$0")" rev-parse HEAD)" > "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE"
  exit 7
fi
"$(dirname "$0")/bin/ai-review-preflight" requalify
mkdir -p "$HOME/.local/state/ai-devops/task-gates/install-stage-reports"
report="$HOME/.local/state/ai-devops/task-gates/install-stage-reports/$(git -C "$(dirname "$0")" rev-parse HEAD).tsv"
printf 'PASS\trequired\tfixture manifest\nPASS\trequired\tfixture doctor\nPASS\trequired\tfixture reviewer\n' > "$report"
chmod 600 "$report"
"$(dirname "$0")/bin/ai-task-gates" install-verify --phase stages-complete \
  --target-head "$(git -C "$(dirname "$0")" rev-parse HEAD)" \
  --installed-checkout "$(dirname "$0")" \
  --installed-launcher /usr/local/bin/ai-task-gates --stage-report "$report"
if [ "${AI_DEVOPS_INSTALL_DEFER_FINALIZE:-0}" != 1 ]; then
  "$(dirname "$0")/bin/ai-task-gates" install-verify --phase finalize \
    --target-head "$(git -C "$(dirname "$0")" rev-parse HEAD)" \
    --installed-checkout "$(dirname "$0")" \
    --installed-launcher /usr/local/bin/ai-task-gates
fi
INSTALL
cat > "$TMP/src/bin/ai-review-preflight" <<'PREFLIGHT'
#!/usr/bin/env bash
printf 'requalify\n' >> "$TEST_LOG"
[ "${TEST_REQUALIFY_FAIL:-0}" != 1 ]
PREFLIGHT
chmod +x "$TMP/src/install.sh" "$TMP/src/bin/ai-review-preflight"
git -C "$TMP/src" add install.sh bin/ai-review-preflight
git -C "$TMP/src" commit -qm target
git -C "$TMP/src" push -q origin main
target="$(git -C "$TMP/src" rev-parse HEAD)"

: > "$TEST_LOG"
TEST_GATE_RECOVER_PHASE=preflight "$TMP/installed/update.sh" --expected-head "$target" > "$TMP/recovered-update-output"
check_head "$before"
[ "$(paste -sd, "$TEST_LOG")" = 'start,preflight' ] || fail 'recovered update advanced checkout or reran installation'
grep -Fq 'Prior installation of' "$TMP/recovered-update-output" || fail 'updater ignored recovered completion'

if "$TMP/installed/update.sh" --expected-head 0000000000000000000000000000000000000000 \
  >/dev/null 2>&1; then fail 'mismatched target pin was accepted'; fi
check_head "$before"
: > "$TEST_LOG"
if TEST_GATE_DENY_PHASE=preflight "$TMP/installed/update.sh" --expected-head "$target" \
  >/dev/null 2>&1; then fail 'denied candidate preflight was accepted'; fi
check_head "$before"
[ "$(paste -sd, "$TEST_LOG")" = 'start,preflight' ] || fail 'task start/preflight did not precede checkout advance'
[ "$(git -C "$TMP/installed" rev-parse refs/remotes/origin/main)" = "$target" ] ||
  fail 'fetch did not pin origin/main to candidate target'

: > "$TEST_LOG"
if TEST_REQUIRE_PIN=1 "$TMP/installed/update.sh" >/dev/null 2>&1; then
  fail 'protected range accepted update without caller pin'
fi
check_head "$before"
[ "$(paste -sd, "$TEST_LOG")" = 'start,preflight' ] || fail 'unpinned update passed preflight'
: > "$TEST_LOG"
if TEST_REQUIRE_OWNER_PREFLIGHT=1 "$TMP/installed/update.sh" --expected-head "$target" \
  >/dev/null 2>&1; then fail 'ordinary preflight accepted missing reviewer approval'; fi
check_head "$before"

# If the installer proves that it restored protected state, the updater returns
# to the prior clean source. The pending grant remains available for retry.
: > "$TEST_LOG"
if TEST_INSTALL_FAIL=1 "$TMP/installed/update.sh" --expected-head "$target" \
  >/dev/null 2>&1; then fail 'failed target install was accepted'; fi
check_head "$before"
[ "$(git -C "$TMP/installed" symbolic-ref --short HEAD)" = main ] ||
  fail 'branch rollback detached the installed checkout'
[ -z "$(git -C "$TMP/installed" status --porcelain)" ] || fail 'rollback left checkout dirty'

git clone -q -b main "$TMP/remote.git" "$TMP/detached"
git -C "$TMP/detached" checkout -q --detach "$before"
if TEST_INSTALL_FAIL=1 "$TMP/detached/update.sh" --expected-head "$target" \
  >/dev/null 2>&1; then fail 'failed detached install was accepted'; fi
[ "$(git -C "$TMP/detached" rev-parse HEAD)" = "$before" ] ||
  fail 'detached rollback did not restore prior SHA'
[ -z "$(git -C "$TMP/detached" symbolic-ref --short -q HEAD)" ] ||
  fail 'detached rollback changed branch state'

# A failed reviewer requalification leaves the protected target pending. A
# direct retry may finalize only after that same required stage succeeds.
git clone -q -b main "$TMP/remote.git" "$TMP/requal"
git -C "$TMP/requal" checkout -q --detach "$before"
: > "$TEST_LOG"
if TEST_REQUALIFY_FAIL=1 "$TMP/requal/update.sh" --expected-head "$target" \
  >/dev/null 2>&1; then fail 'failed requalification was accepted'; fi
[ "$(git -C "$TMP/requal" rev-parse HEAD)" = "$target" ] ||
  fail 'unproven requalification incorrectly rolled back target'
if grep -q '^finalize$' "$TEST_LOG"; then fail 'failed requalification finalized'; fi
if grep -q '^stages-complete$' "$TEST_LOG"; then fail 'failed requalification marked stages complete'; fi
if TEST_REQUALIFY_FAIL=1 "$TMP/requal/install.sh" >/dev/null 2>&1; then
  fail 'direct retry accepted failed requalification'
fi
if grep -q '^finalize$' "$TEST_LOG"; then fail 'failed direct retry finalized'; fi
"$TMP/requal/install.sh" >/dev/null
[ "$(grep -c '^finalize$' "$TEST_LOG")" = 1 ] ||
  fail 'successful direct retry did not finalize exactly once'

: > "$TEST_LOG"
(
  umask 022
  TEST_CAPTURE_UMASK_FILE="$TMP/updater-umask" "$TMP/installed/update.sh" --expected-head "$target" \
    --reviewer-approval "$TMP/approval.json" >/dev/null
)
[ "$(cat "$TMP/updater-umask")" = 0022 ] || fail 'updater leaked private lock umask into installation stages'
check_head "$target"
[ "$(paste -sd, "$TEST_LOG")" = 'start,preflight,install,resume,requalify,stages-complete,finalize' ] ||
  fail 'update did not run gate/install/requalification in order'

# First protected rollout executes the target updater from a separate worktree
# and names the old installed checkout. Wrong/foreign targets are refused.
git clone -q -b main "$TMP/remote.git" "$TMP/first"
git -C "$TMP/first" reset -q --hard "$before"
git -C "$TMP/first" worktree add -q --detach "$TMP/first-candidate" "$target"
git -C "$TMP/first" worktree add -q --detach "$TMP/wrong-candidate" "$before"
if "$TMP/wrong-candidate/update.sh" --installed-checkout "$TMP/first" \
  --expected-head "$target" >/dev/null 2>&1; then fail 'wrong candidate HEAD was accepted'; fi
check_first="$(git -C "$TMP/first" rev-parse HEAD)"
[ "$check_first" = "$before" ] || fail 'wrong candidate moved installed checkout'
if "$TMP/first-candidate/update.sh" --installed-checkout "$TMP/installed" \
  --expected-head "$target" >/dev/null 2>&1; then fail 'foreign Git common directory was accepted'; fi
[ "$(git -C "$TMP/installed" rev-parse HEAD)" = "$target" ] || fail 'foreign candidate moved checkout'
: > "$TEST_LOG"
TEST_REQUIRE_OWNER_PREFLIGHT=1 "$TMP/first-candidate/update.sh" \
  --installed-checkout "$TMP/first" --expected-head "$target" \
  --reviewer-approval "$TMP/approval.json" >/dev/null
[ "$(git -C "$TMP/first" rev-parse HEAD)" = "$target" ] ||
  fail 'candidate updater did not advance named installed checkout'
[ "$(paste -sd, "$TEST_LOG")" = 'start,preflight,install,resume,requalify,stages-complete,finalize' ] ||
  fail 'candidate updater skipped an installation stage'

# Exercise the installer's actual routing backup/restore functions in an
# isolated bin directory. A first install must restore launcher absence after
# failure so the same pending authorization can be retried safely.
eval "$(sed -n '/^backup_install_routing() {/,/^}/p' "$ROOT/install.sh")"
eval "$(sed -n '/^restore_install_routing() {/,/^}/p' "$ROOT/install.sh")"
REPO_ROOT="$ROOT" BIN_TARGET="$TMP/bin" BACKUP_DIR="$TMP/backup" SUDO=''
mkdir -p "$BIN_TARGET" "$BACKUP_DIR"
backup_install_routing
ln -s "$ROOT/bin/ai-gh" "$BIN_TARGET/ai-gh"
restore_install_routing || fail 'first-install launcher absence was not restored'
[ ! -L "$BIN_TARGET/ai-gh" ] || fail 'new launcher remained after rollback'
backup_install_routing
ln -s "$ROOT/bin/ai-gh" "$BIN_TARGET/ai-gh"
restore_install_routing || fail 'retry rollback failed'
[ ! -L "$BIN_TARGET/ai-gh" ] || fail 'retry retained new launcher'

# A preexisting foreign link is restored, but a concurrent foreign change is
# never overwritten during rollback.
ln -s "$TMP/original" "$BIN_TARGET/ai-gh"
backup_install_routing
ln -sfn "$ROOT/bin/ai-gh" "$BIN_TARGET/ai-gh"
restore_install_routing || fail 'foreign launcher target was not restored'
[ "$(readlink "$BIN_TARGET/ai-gh")" = "$TMP/original" ] || fail 'foreign launcher target changed'
ln -sfn "$TMP/other-actor" "$BIN_TARGET/ai-gh"
if restore_install_routing; then fail 'rollback overwrote concurrent foreign launcher'; fi
[ "$(readlink "$BIN_TARGET/ai-gh")" = "$TMP/other-actor" ] || fail 'concurrent foreign launcher changed'

# The copied reviewer hook is source-bound. Restore an old managed hook or
# prior absence only while the installed bytes are exactly ours. A foreign or
# concurrently changed hook must survive and withhold source rollback proof.
eval "$(sed -n '/^backup_reviewer_hook() {/,/^}/p' "$ROOT/install.sh")"
eval "$(sed -n '/^restore_reviewer_hook() {/,/^}/p' "$ROOT/install.sh")"
eval "$(sed -n '/^record_restored_state() {/,/^}/p' "$ROOT/install.sh")"
warn() { :; }
REPO_ROOT="$TMP/hook-repo"
mkdir -p "$REPO_ROOT/hooks"
cp "$ROOT/hooks/post-merge" "$REPO_ROOT/hooks/post-merge"
git -C "$REPO_ROOT" init -q -b main
hook="$REPO_ROOT/.git/hooks/post-merge"
BACKUP_DIR="$TMP/hook-backup-absent"
mkdir -p "$BACKUP_DIR"
backup_reviewer_hook || fail 'hook absence backup failed'
cp "$REPO_ROOT/hooks/post-merge" "$hook"
restore_reviewer_hook || fail 'new managed hook was not removed after failure'
[ ! -e "$hook" ] || fail 'new managed hook remained after rollback'

printf '# ai-devops-managed: reviewer auto-requalification\nold\n' > "$hook"
chmod 700 "$hook"
BACKUP_DIR="$TMP/hook-backup-managed"
mkdir -p "$BACKUP_DIR"
backup_reviewer_hook || fail 'prior managed hook backup failed'
cp "$REPO_ROOT/hooks/post-merge" "$hook"
chmod 755 "$hook"
restore_reviewer_hook || fail 'prior managed hook was not restored'
cmp -s "$BACKUP_DIR/post-merge" "$hook" || fail 'prior managed hook bytes changed'
[ "$(stat -c %a "$hook")" = 700 ] || fail 'prior managed hook mode changed'

printf 'foreign hook\n' > "$hook"
BACKUP_DIR="$TMP/hook-backup-foreign"
mkdir -p "$BACKUP_DIR"
backup_reviewer_hook || fail 'foreign hook backup failed'
restore_reviewer_hook || fail 'unchanged foreign hook was not preserved'
printf 'concurrent change\n' > "$hook"
if restore_reviewer_hook; then fail 'concurrent foreign hook was treated as restored'; fi
[ "$(cat "$hook")" = 'concurrent change' ] || fail 'concurrent hook was overwritten'
rm "$hook"
ln -s "$TMP/foreign-hook" "$hook"
if backup_reviewer_hook; then fail 'symlinked hook was accepted'; fi
rm "$hook"

AI_DEVOPS_INSTALL_LOCK_FD=9
AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE="$TMP/rollback-proof"
target_head="$target"
: > "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE"
SOURCE_ROLLBACK_SAFE=0
record_restored_state || fail 'unsafe rollback proof check errored'
[ ! -s "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE" ] || fail 'unsafe source rollback was proved'
SOURCE_ROLLBACK_SAFE=1
record_restored_state || fail 'safe rollback proof was refused'
[ "$(cat "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE")" = "$target" ] ||
  fail 'safe rollback proof omitted target'
grep -B1 -F 'run_stage required "Claude and Codex skills"' "$ROOT/install.sh" |
  grep -Fq 'SOURCE_ROLLBACK_SAFE=0' || fail 'skill copy did not end source rollback eligibility'

# The real report writer preserves exact tab-separated stage outcomes in a
# protected, mode-600 file and refuses an attacker-supplied report symlink.
eval "$(sed -n '/^publish_stage_report() {/,/^}/p' "$ROOT/install.sh")"
target_head="$target"
stage_results=('PASS\trequired\tManaged artifact manifest' 'PASS\trequired\tai-devops doctor'
  'PASS\trequired\tReviewer requalification' 'SKIP\toptional\tFixture optional')
publish_stage_report || fail 'exact stage result report was not published'
[ "$(stat -c %a "$STAGE_REPORT")" = 600 ] || fail 'stage report permissions are not private'
[ "$(wc -l < "$STAGE_REPORT")" = 4 ] || fail 'stage report omitted an outcome'
grep -Fxq $'PASS\trequired\tReviewer requalification' "$STAGE_REPORT" ||
  fail 'stage report changed required outcome'
rm "$STAGE_REPORT"
ln -s "$TMP/foreign-report" "$STAGE_REPORT"
if publish_stage_report; then fail 'symlinked stage report was overwritten'; fi
[ -L "$STAGE_REPORT" ] || fail 'foreign stage report symlink changed'

# A direct retry may start with a valid marker from a prior completed stage
# attempt. A later required-stage failure must remove only that target's
# marker before restoring the old manifest, so pending authority can resume.
eval "$(sed -n '/^invalidate_stage_marker() {/,/^}/p' "$ROOT/install.sh")"
eval "$(sed -n '/^restore_failed_install() {/,/^}/p' "$ROOT/install.sh")"
REPO_ROOT="$TMP/installed"
marker_dir="$HOME/.local/state/ai-devops/task-gates/install-stages"
mkdir -p "$marker_dir"
marker="$marker_dir/$target.json"
manifest="$TMP/retry-manifest"
printf 'target manifest\n' > "$manifest"
printf 'old manifest\n' > "$TMP/old-manifest"
restore_install_state() { cp "$TMP/old-manifest" "$manifest"; }
SOURCE_ROLLBACK_SAFE=0
printf '%s\n' "$(jq -nc --arg t "$target" --arg p "$REPO_ROOT" \
  '{schema_version:1,target_head:$t,installed_checkout:$p}')" > "$marker"
chmod 600 "$marker"
restore_failed_install || fail 'verified prior stage marker blocked rollback'
[ ! -e "$marker" ] || fail 'stale stage marker survived failed retry'
cmp -s "$TMP/old-manifest" "$manifest" || fail 'failed retry did not restore old manifest'
auth_dir="$HOME/.local/state/ai-devops/task-gates/install-authorizations"
mkdir -p "$auth_dir"
touch "$auth_dir/$target.json.consuming"
[ ! -e "$marker" ] && cmp -s "$TMP/old-manifest" "$manifest" ||
  fail 'pending retry cannot resume from restored state'
printf '%s\n' "$(jq -nc --arg t "$target" --arg p "$TMP/foreign" \
  '{schema_version:1,target_head:$t,installed_checkout:$p}')" > "$marker"
chmod 600 "$marker"
printf 'target manifest\n' > "$manifest"
if restore_failed_install; then fail 'foreign stage marker was removed'; fi
[ -f "$marker" ] && [ "$(cat "$manifest")" = 'target manifest' ] ||
  fail 'foreign marker or target manifest changed'
rm "$marker"
ln -s "$TMP/foreign-marker" "$marker"
if restore_failed_install; then fail 'symlinked stage marker was removed'; fi
[ -L "$marker" ] || fail 'symlinked stage marker changed'
echo 'PASS: Linux installer authorization, checkout pin, lock, and update order'
