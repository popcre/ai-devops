#!/usr/bin/env bash
# Offline Linux installer/updater front-door tests. No /etc or GitHub access.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
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
while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase) phase="$2"; shift 2 ;;
    --owner-request) owner="$2"; shift 2 ;;
    --caller-pinned) caller_pinned=1; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "$phase" >> "$TEST_LOG"
[ "$phase" != preflight ] || [ "$(git rev-parse --show-toplevel)" = "$PWD" ] || exit 48
[ "${TEST_GATE_DENY_PHASE:-}" != "$phase" ] || exit 41
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

# Same-source maintenance forwards its explicit owner request; the gate decides.
if TEST_REQUIRE_OWNER=1 "$TMP/installed/install.sh" --test-authorization-only >/dev/null 2>&1; then
  fail 'same-source install accepted missing owner request'
fi
TEST_REQUIRE_OWNER=1 "$TMP/installed/install.sh" --owner-request 'fixture approval' \
  --test-authorization-only >/dev/null

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
"$(dirname "$0")/bin/ai-task-gates" install-verify --phase stages-complete \
  --target-head "$(git -C "$(dirname "$0")" rev-parse HEAD)" \
  --installed-checkout "$(dirname "$0")" \
  --installed-launcher /usr/local/bin/ai-task-gates
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
  >/dev/null 2>&1; then fail 'ordinary preflight accepted missing owner request'; fi
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
"$TMP/installed/update.sh" --expected-head "$target" --owner-request 'fixture approval' >/dev/null
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
  --owner-request 'fixture first rollout' >/dev/null
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
echo 'PASS: Linux installer authorization, checkout pin, lock, and update order'
