#!/usr/bin/env bash
# Focused cases owned and invoked by test-ai-grok-review.sh; no second CI lane.
# Offline credential-link concurrency regressions; fixture text is not a secret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
sed -n '/^prepare_auth_link()/,/^}/p' "$ROOT/bin/ai-grok-review" > "$TMP/auth.sh"
. "$TMP/auth.sh"
printf 'fixture-auth\n' > "$TMP/source"
mkdir "$TMP/home"
ln "$TMP/source" "$TMP/home/auth.json"
# A reader retains the credential inode while a second session initializes.
# Reject ANY mutation of the existing destination, including an unlink/relink
# that would finish with the same inode and fool a final-state-only assertion.
(
  rm() { echo 'unexpected unlink of valid auth' >&2; return 1; }
  ln() { echo 'unexpected relink of valid auth' >&2; return 1; }
  mv() { echo 'unexpected replacement of valid auth' >&2; return 1; }
  prepare_auth_link "$TMP/source" "$TMP/home"
  test "$TMP/source" -ef "$TMP/home/auth.json"
)
echo 'ok valid hardlink remains reachable without mutation'

mkdir "$TMP/concurrent"
(
  # Deterministically let B finish while A is about to publish. Both see a
  # complete credential inode; the publication cannot unlink B's live path.
  mv() {
    (
      unset -f mv
      prepare_auth_link "$TMP/source" "$TMP/concurrent"
      test "$TMP/source" -ef "$TMP/concurrent/auth.json"
    )
    command mv "$@"
    test "$TMP/source" -ef "$TMP/concurrent/auth.json"
  }
  prepare_auth_link "$TMP/source" "$TMP/concurrent"
)
test "$TMP/source" -ef "$TMP/concurrent/auth.json"
test -z "$(find "$TMP/concurrent" -name '.auth-link.*' -print)"
echo 'ok interleaved initializers publish one credential inode and clean candidates'

mkdir "$TMP/refused"
(
  ln() { return 1; }
  ! prepare_auth_link "$TMP/source" "$TMP/refused"
  test ! -e "$TMP/refused/auth.json"
  test -z "$(find "$TMP/refused" -name '.auth-link.*' -print)"
)
echo 'ok unavailable link creation refuses without copying credentials'

mkdir "$TMP/hardlink-fallback"
(
  ln() {
    if [ "${1:-}" = -s ]; then
      [[ "$MSYS" = *winsymlinks:nativestrict ]] || exit 1
      return 1
    fi
    command ln "$@"
  }
  prepare_auth_link "$TMP/source" "$TMP/hardlink-fallback"
  test ! -L "$TMP/hardlink-fallback/auth.json"
  test "$TMP/source" -ef "$TMP/hardlink-fallback/auth.json"
)
echo 'ok denied native symlink uses a hardlink without copy emulation'

mkdir "$TMP/replace"
printf 'stale-fixture\n' > "$TMP/replace/auth.json"
prepare_auth_link "$TMP/source" "$TMP/replace"
test "$TMP/source" -ef "$TMP/replace/auth.json"
echo 'ok stale copied credential is replaced by the source inode'

mkdir "$TMP/publish-failed"
printf 'old-fixture\n' > "$TMP/publish-failed/auth.json"
(
  mv() { return 1; }
  ! prepare_auth_link "$TMP/source" "$TMP/publish-failed"
  grep -qx old-fixture "$TMP/publish-failed/auth.json"
  test -z "$(find "$TMP/publish-failed" -name '.auth-link.*' -print)"
)
echo 'ok failed publication preserves existing destination and refuses'

sed -n '/^cleanup()/,/^}/p' "$ROOT/tests/test-ai-grok-review.sh" > "$TMP/cleanup.sh"
mkdir "$TMP/failed-suite"
printf '23\n' > "$TMP/failed-suite/ask-a.rc"
printf 'fixture initialization failed\n' > "$TMP/failed-suite/ask-a.err"
(
  . "$TMP/cleanup.sh"
  REPO_ROOT="$ROOT"; TMP="$TMP/failed-suite"; FAIL=1
  cleanup
) 2> "$TMP/diagnostics"
grep -q 'fixture diagnostic: ask-a.rc' "$TMP/diagnostics"
grep -qx 23 "$TMP/diagnostics"
grep -qx 'fixture initialization failed' "$TMP/diagnostics"
test ! -d "$TMP/failed-suite"
echo 'ok failing concurrency fixture preserves owner diagnostics before cleanup'
echo '7 passed, 0 failed, 0 skipped'
