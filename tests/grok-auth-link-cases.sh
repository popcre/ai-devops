#!/usr/bin/env bash
# Focused cases owned and invoked by test-ai-grok-review.sh; no second CI lane.
# Offline credential-link concurrency regressions; fixture text is not a secret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
set -E; trap 'echo "grok-auth-link-cases: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
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

make_link() { # TARGET LINK: symlink, or an NTFS junction on Git Bash without symlink rights
  ln -s "$1" "$2" 2>/dev/null && [ -L "$2" ] && return 0
  rm -rf -- "$2"
  command -v cygpath >/dev/null && MSYS2_ARG_CONV_EXCL="*" cmd /c mklink /J "$(cygpath -w "$2")" "$(cygpath -w "$1")" >/dev/null
}

# Cross-volume state directory: the isolated home must follow the credential's
# volume (a hard link cannot cross drives), and nothing is ever copied into it.
sed -n '/^grok_isolated_home()/,/^}/p; /^scrub_unselected_auth_links()/,/^}/p' "$ROOT/bin/ai-grok-review" > "$TMP/home.sh"
. "$TMP/home.sh"
mkdir -p "$TMP/xv/user/.grok" "$TMP/xv/state/isolated-home/sessions"
printf 'fixture-auth
' > "$TMP/xv/user/.grok/auth.json"
printf 'kept
' > "$TMP/xv/state/isolated-home/sessions/s1"
(
  STATE_DIR="$TMP/xv/state" HOME="$TMP/xv/user"; unset AI_GROK_AUTH_HOME
  die() { printf 'die: %s
' "$*" >&2; exit 1; }; warn() { :; }
  test "$(grok_isolated_home)" = "$STATE_DIR/isolated-home"   # same device: unchanged
  stat() { case "$*" in *"$STATE_DIR"*) echo 2;; *) echo 1;; esac; }
  got="$(grok_isolated_home)"
  test "$got" -ef "$HOME/.ai-grok-review-isolated-home"   # -ef: the resolved path may be spelled differently
  test -z "$(find "$got" -mindepth 1 -print -quit)"   # nothing copied
  prepare_auth_link "$HOME/.grok/auth.json" "$got"
  test "$HOME/.grok/auth.json" -ef "$got/auth.json"
  # A credential link stranded in the unselected home is scrubbed; the
  # original and the live link are untouched.
  ln "$HOME/.grok/auth.json" "$STATE_DIR/isolated-home/auth.json"
  scrub_unselected_auth_links "$got"
  test ! -e "$STATE_DIR/isolated-home/auth.json"
  test "$HOME/.grok/auth.json" -ef "$got/auth.json"
  test -f "$STATE_DIR/isolated-home/sessions/s1"
  # The shared home beside the credential is never scrubbed by another choice.
  scrub_unselected_auth_links "$STATE_DIR/isolated-home"
  test "$HOME/.grok/auth.json" -ef "$got/auth.json"
  rm -rf "$got"; mkdir -p "$TMP/xv/elsewhere"
  make_link "$TMP/xv/elsewhere" "$got"
  test -L "$got"
  if (grok_isolated_home) >/dev/null 2>"$TMP/xv/err"; then exit 1; fi
  grep -q 'refusing a symbolic link or junction' "$TMP/xv/err"
)
echo 'ok cross-volume state keeps the isolated home on the credential volume'

# The same rule for ai-grok-implement's throwaway investigation home.
sed -n '/^investigation_home_parent()/,/^}/p; /^investigation_home_root()/,/^}/p' "$ROOT/bin/ai-grok-implement" > "$TMP/impl.sh"
. "$TMP/impl.sh"
(
  HOME="$TMP/xv/user" IMPL_DIR="$TMP/xv/state/implement"; unset AI_GROK_AUTH_HOME
  test "$(investigation_home_parent)" = "$IMPL_DIR"          # same device: unchanged
  stat() { case "$*" in *"$IMPL_DIR"*) echo 2;; *) echo 1;; esac; }
  root="$(investigation_home_root)"
  test "$(dirname "$root")" -ef "$HOME/.ai-grok-implement-homes"
  case "$(basename "$root")" in investigate-home.?*) ;; *) exit 1 ;; esac
  test -d "$root"
  rel="$(cd "$TMP" && mkdir -p rel/.grok && AI_GROK_AUTH_HOME=rel/.grok investigation_home_parent)"
  case "$rel" in /*) ;; *) exit 1 ;; esac                     # a relative credential path is resolved
  rm -rf "$HOME/.ai-grok-implement-homes"; make_link "$TMP/xv/elsewhere" "$HOME/.ai-grok-implement-homes"
  if (investigation_home_parent) >/dev/null 2>"$TMP/xv/ierr"; then exit 1; fi
  grep -q 'refusing a linked investigation home parent' "$TMP/xv/ierr"
)
echo 'ok cross-volume investigation home follows the credential volume'
echo '9 passed, 0 failed, 0 skipped'
