#!/usr/bin/env bash
# #2709: on a Windows host update.sh must route to the reviewed target
# worktree's bin/install-ai-devops-windows.ps1 instead of the POSIX install
# path (install-public-git.py, install.sh, the /usr/local/bin launcher gates),
# keeping the candidate pin contract and propagating the installer's exit code.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
fail(){ printf '  FAIL %s\n' "$1" >&2; exit 1; }

# The shims make the Windows branch deterministic on every OS: uname reports
# MSYS, cygpath emulates -w and delegates the rest to the real cygpath (so
# update.sh's own path identity still works), and the PowerShell stubs record
# which shell the route preferred along with its argv.
REAL_CYGPATH="$(command -v cygpath || true)"
export REAL_CYGPATH
shims="$TMP/shims"
mkdir -p "$shims"
printf '%s\n' '#!/usr/bin/env bash' 'printf "MINGW64_NT-10.0\n"' > "$shims/uname"
cat > "$shims/cygpath" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *" -w "*)
    for arg in "$@"; do case "$arg" in -*) ;; *) printf 'WIN:%s\n' "$arg";; esac; done
    exit 0 ;;
esac
if [ -n "${REAL_CYGPATH:-}" ] && [ -x "$REAL_CYGPATH" ]; then exec "$REAL_CYGPATH" "$@"; fi
for arg in "$@"; do case "$arg" in -*) ;; *) printf '%s\n' "$arg";; esac; done
EOF
cat > "$shims/pwsh" <<'EOF'
#!/usr/bin/env bash
printf 'stub=pwsh\n' > "${STUB_PS_LOG:?}"
printf '%s\n' "$@" >> "${STUB_PS_LOG:?}"
exit "${STUB_PS_RC:-0}"
EOF
cat > "$shims/powershell.exe" <<'EOF'
#!/usr/bin/env bash
printf 'stub=powershell.exe\n' > "${STUB_PS_LOG:?}"
printf '%s\n' "$@" >> "${STUB_PS_LOG:?}"
exit "${STUB_PS_RC:-0}"
EOF
chmod +x "$shims/uname" "$shims/cygpath" "$shims/pwsh" "$shims/powershell.exe"

installed="$TMP/installed"
mkdir -p "$installed/bin" "$installed/tools/lib"
cp "$ROOT/update.sh" "$installed/update.sh"
cp "$ROOT/tools/lib/path-identity.sh" "$installed/tools/lib/path-identity.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$installed/bin/install-ai-devops-windows.ps1"
git -C "$installed" init -q -b main
git -C "$installed" config user.name Test
git -C "$installed" config user.email t@example.com
git -C "$installed" config core.autocrlf false
git -C "$installed" add -A
git -C "$installed" commit -qm fixture
target="$(git -C "$installed" rev-parse HEAD)"
git -C "$installed" commit -qm later --allow-empty
wrong_target="$(git -C "$installed" rev-parse HEAD)"
candidate="$TMP/candidate"
git -C "$installed" worktree add -q --detach "$candidate" "$target"
# update.sh resolves REPO_ROOT with pwd -P and SOURCE_ROOT with pwd.
installed_resolved="$(cd "$installed" && pwd -P)"
candidate_resolved="$(cd "$candidate" && pwd)"

run_update() {
  local log="$1"; shift
  STUB_PS_LOG="$log" PATH="$shims:$PATH" bash ./update.sh "$@"
}
stub_called() { [ -s "$1" ]; }

# The pinned candidate route reaches the Windows installer with the approved
# candidate as the script source and the installed checkout as its target.
rc=0
(cd "$candidate" && run_update "$TMP/ps-full.log" \
  --installed-checkout "$installed_resolved" --expected-head "$target") || rc=$?
[ "$rc" -eq 0 ] || fail "pinned route exits 0 (got $rc)"
grep -Fxq -- 'stub=pwsh' "$TMP/ps-full.log" || fail 'route prefers PowerShell 7 when both shells exist'
grep -Fxq -- '-File' "$TMP/ps-full.log" || fail 'route passes -File'
grep -Fxq -- "WIN:$candidate_resolved/bin/install-ai-devops-windows.ps1" "$TMP/ps-full.log" \
  || fail 'route runs the approved candidate installer'
grep -Fxq -- '-RepoPath' "$TMP/ps-full.log" || fail 'route passes -RepoPath'
grep -Fxq -- "WIN:$installed_resolved" "$TMP/ps-full.log" || fail 'route targets the installed checkout'
grep -Fxq -- '-ExpectedHead' "$TMP/ps-full.log" || fail 'route passes -ExpectedHead'
grep -Fxq -- "$target" "$TMP/ps-full.log" || fail 'route pins the approved target'
ok 'pinned candidate route maps update.sh to the Windows installer'

# The installer's exit code is update.sh's exit code.
rc=0
(cd "$candidate" && STUB_PS_LOG="$TMP/ps-rc.log" STUB_PS_RC=7 PATH="$shims:$PATH" \
  bash ./update.sh --installed-checkout "$installed_resolved" --expected-head "$target") || rc=$?
[ "$rc" -eq 7 ] || fail "installer exit code propagates (got $rc)"
ok 'installer exit code propagates'

# A pin that is not the candidate's HEAD is refused before the installer runs.
rc=0
(cd "$candidate" && run_update "$TMP/ps-wrong.log" \
  --installed-checkout "$installed_resolved" --expected-head "$wrong_target") || rc=$?
[ "$rc" -eq 1 ] || fail "wrong pin is refused (got $rc)"
stub_called "$TMP/ps-wrong.log" && fail 'wrong pin never reaches the installer'
ok 'wrong pin is refused before routing'

# Linux install.sh options are refused on the Windows route, not silently dropped.
rc=0
(cd "$candidate" && run_update "$TMP/ps-secrets.log" \
  --installed-checkout "$installed_resolved" --expected-head "$target" --skip-secrets) || rc=$?
[ "$rc" -eq 2 ] || fail "install.sh flags are refused (got $rc)"
stub_called "$TMP/ps-secrets.log" && fail 'refused flags never reach the installer'
ok 'Linux install.sh flags are refused on the Windows route'

# GLM formal activation is a Linux operation and is refused before routing.
rc=0
(cd "$candidate" && run_update "$TMP/ps-glm.log" \
  --installed-checkout "$installed_resolved" --expected-head "$target" --activate-glm-formal) || rc=$?
[ "$rc" -eq 2 ] || fail "--activate-glm-formal is refused off Linux (got $rc)"
stub_called "$TMP/ps-glm.log" && fail 'refused flag never reaches the installer'
ok 'GLM formal activation is refused off Linux'

printf 'update-windows-route: %d checks passed\n' "$PASS"
