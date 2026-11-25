#!/usr/bin/env bash
# Offline suite for bin/ai-github-backup. A stub `gh` and a local bare repo
# stand in for GitHub; the NAS and Dropbox are local folders. Never touches
# the network, the real drive, or systemd.
set -u
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo "SKIP: GitHub backup runs only on the Ubuntu backup host"; exit 0;; esac
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
tool="$here/../bin/ai-github-backup"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export HOME="$work/home"; mkdir -p "$HOME" "$work/stub"
export GIT_CONFIG_GLOBAL="$work/gitconfig"; printf '[user]\n\tname=t\n\temail=t@t\n[credential "https://github.com"]\n\thelper=\n' > "$GIT_CONFIG_GLOBAL"
export GITHUB_BACKUP_ROOT="$work/root" GITHUB_BACKUP_NAS="$work/nas" GITHUB_BACKUP_DROPBOX="$work/dropbox"
export GITHUB_BACKUP_GIT_BASE="$work/gh" GITHUB_BACKUP_GH="$work/stub/gh"

# Fake GitHub: one repository with two commits and a tag.
mkdir -p "$work/gh/acme" && git init -q --bare "$work/gh/acme/app.git"
git clone -q "$work/gh/acme/app.git" "$work/src" 2>/dev/null
( cd "$work/src" && echo a > f && git add f && git commit -qm one && git tag v1 && echo b >> f && git commit -qam two && git push -q origin HEAD --tags && git push -q origin HEAD:refs/pull/1/head ) 2>/dev/null

cat > "$work/stub/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1" = api ] || exit 1; shift
[ "$1" = --paginate ] && shift
[ -n "${GITHUB_BACKUP_FAIL_META:-}" ] && case "$1" in repos/*) exit 1 ;; esac
case "$1" in
  user/repos*) printf 'acme/app\tfalse\n' ;;
  repos/acme/app) echo '{"full_name":"acme/app"}' ;;
  repos/acme/app/issues\?*) echo '[{"number":1,"title":"bug"}]'; echo '[{"number":2,"title":"page2"}]' ;;
  repos/acme/app/*) echo '[]' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$work/stub/gh"; export PATH="$work/stub:$PATH"

bash "$tool" run >"$work/out1" 2>&1; check "first run exits 0" '[ $? -eq 0 ]'
check "mirror has full history and tags" '[ "$(git -C "$work/root/mirrors/acme/app.git" rev-list --all --count)" = 2 ] && git -C "$work/root/mirrors/acme/app.git" rev-parse -q --verify v1 >/dev/null'
check "issues pages merged into one array" '[ "$(jq length "$work/root/meta/acme/app/issues.json")" = 2 ]'
check "bundle restores the repository" 'git clone -q "$work/root/bundles/acme/app.bundle" "$work/restored" 2>/dev/null && cmp -s "$work/src/f" "$work/restored/f"'
check "NAS copy has bundle and meta" '[ -f "$work/nas/bundles/acme/app.bundle" ] && [ -f "$work/nas/meta/acme/app/issues.json" ]'
check "Dropbox copy has bundle and meta" '[ -f "$work/dropbox/bundles/acme/app.bundle" ] && [ -f "$work/dropbox/meta/acme/app/pulls.json" ]'
check "check reports fresh success" 'bash "$tool" --check | grep -q "^OK"'

check "NAS bundle restores" 'git clone -q "$work/nas/bundles/acme/app.bundle" "$work/r2" 2>/dev/null'

# A branch deleted on GitHub must stay in the backup.
( cd "$work/src" && git push -q origin HEAD:refs/heads/side && git push -q origin --delete side ) 2>/dev/null
git -C "$work/root/mirrors/acme/app.git" update-ref refs/heads/side HEAD
bash "$tool" run >/dev/null 2>&1
check "deleted remote branch kept" 'git -C "$work/root/mirrors/acme/app.git" rev-parse -q --verify refs/heads/side >/dev/null'

# NAS unreachable -> run fails and does not record success.
rm -f "$work/root/last-success"
GITHUB_BACKUP_NAS="/proc/nope/nas" bash "$tool" run >/dev/null 2>&1; check "NAS failure exits nonzero" '[ $? -ne 0 ]'
check "failed run records no success" '[ ! -f "$work/root/last-success" ] && jq -e ".status==\"failed\"" "$work/root/last-run.json" >/dev/null'
check "check fails with no success" '! bash "$tool" --check >/dev/null'

# A failing API call must not wipe the last good metadata.
GITHUB_BACKUP_FAIL_META=1 bash "$tool" run >/dev/null 2>&1
check "failed metadata fetch keeps last good repo.json and issues.json" 'jq -e .full_name "$work/root/meta/acme/app/repo.json" >/dev/null && [ "$(jq length "$work/root/meta/acme/app/issues.json")" = 2 ]'
check "no temp files leak into copied trees" '! find "$work/root/meta" "$work/nas" -name "*.tmp" | grep -q .'

# A sharply shrunk repository list fails the run.
printf 'acme/app\tfalse\n%.0s' 1 2 3 4 5 6 7 8 9 10 > "$work/root/repos.tsv"
bash "$tool" run >/dev/null 2>&1; check "repository list shrink fails the run" '[ $? -ne 0 ]'
GITHUB_BACKUP_ACCEPT_SHRINK=1 bash "$tool" run >/dev/null 2>&1; check "accepted shrink succeeds" '[ $? -eq 0 ]'
check "open-PR refs are mirrored" 'git -C "$work/root/mirrors/acme/app.git" rev-parse -q --verify refs/pull/1/head >/dev/null'

check "install skips on another host" 'GITHUB_BACKUP_HOST=not-this-host bash "$tool" --install | grep -q "^SKIP"'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
