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
[ "${TEST_GATE_DENY_PHASE:-}" != "$phase" ] || exit 41
if [ "$phase" = resume ] && [ "${TEST_REQUIRE_OWNER:-0}" = 1 ]; then
  [ -n "$owner" ] || exit 42
fi
if [ "$phase" = preflight ] && [ "${TEST_REQUIRE_PIN:-0}" = 1 ]; then
  [ "$caller_pinned" = 1 ] || exit 43
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
[ "$(cat "$TEST_LOG")" = preflight ] || fail 'preflight did not precede checkout advance'
[ "$(git -C "$TMP/installed" rev-parse refs/remotes/origin/main)" = "$target" ] ||
  fail 'fetch did not pin origin/main to candidate target'

: > "$TEST_LOG"
if TEST_REQUIRE_PIN=1 "$TMP/installed/update.sh" >/dev/null 2>&1; then
  fail 'protected range accepted update without caller pin'
fi
check_head "$before"
[ "$(cat "$TEST_LOG")" = preflight ] || fail 'unpinned update passed preflight'

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
if TEST_REQUALIFY_FAIL=1 "$TMP/requal/install.sh" >/dev/null 2>&1; then
  fail 'direct retry accepted failed requalification'
fi
if grep -q '^finalize$' "$TEST_LOG"; then fail 'failed direct retry finalized'; fi
"$TMP/requal/install.sh" >/dev/null
[ "$(grep -c '^finalize$' "$TEST_LOG")" = 1 ] ||
  fail 'successful direct retry did not finalize exactly once'

: > "$TEST_LOG"
"$TMP/installed/update.sh" --expected-head "$target" >/dev/null
check_head "$target"
[ "$(paste -sd, "$TEST_LOG")" = 'preflight,install,resume,requalify,finalize' ] ||
  fail 'update did not run gate/install/requalification in order'

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
echo 'PASS: Linux installer authorization, checkout pin, lock, and update order'
