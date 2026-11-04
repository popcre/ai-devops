#!/usr/bin/env bash
# Offline suite for bin/ai-transcript-upload (plan_transcript-store.md step 1).
# Synthetic fixtures only; never touches the real Dropbox or systemd.
set -u
# On Windows the tool hands off to ai-transcript-upload.ps1; this suite covers the Bash path.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo "SKIP: Windows uses the PowerShell twin"; exit 0;; esac
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
up="$here/../bin/ai-transcript-upload"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_CACHE_HOME="$work/home/.cache"
export AI_TRANSCRIPT_UPLOAD_STATE_DIR="$work/state"
# Merged main stand-in: a local folder holding the two files at their repo paths.
main="$work/main"; mkdir -p "$main/bin" "$main/tools/transcript_store"
cp "$up" "$main/bin/ai-transcript-upload"; cp "$here/../tools/transcript_store/zcode_export.py" "$main/tools/transcript_store/"
export AI_TRANSCRIPT_UPLOAD_SOURCE="$main"
mkdir -p "$HOME" "$work/db/ai/chat_transcripts"
db="$work/db"; D="$db/ai/chat_transcripts/hostx"
src="$work/src"; mkdir -p "$src/p/a"
old() { touch -d '2 hours ago' "$@"; }
run() { bash "$up" --dropbox "$db" --host hostx --map "$src/p=claude/projects" "$@"; }

printf 'one\n' > "$src/p/a/s1.jsonl"; printf 'two\n' > "$src/p/s2.jsonl"; old "$src/p/a/s1.jsonl" "$src/p/s2.jsonl"
run >/dev/null; check "first run exits 0" '[ $? -eq 0 ]'
check "copies new files" 'cmp -s "$src/p/a/s1.jsonl" "$D/claude/projects/a/s1.jsonl" && cmp -s "$src/p/s2.jsonl" "$D/claude/projects/s2.jsonl"'
check "writes .upload-last.txt with EDT/EST time and counts" 'grep -Eq "^[0-9-]{10} [0-9:]{8} E[DS]T host=hostx scanned=2 copied=2 skipped_hot=0 errors=0$" "$D/.upload-last.txt"'
check "appends the run line to the state log" '[ "$(wc -l < "$work/state/transcript-upload.log")" -eq 1 ]'

out="$(run)"
check "skips identical files" 'printf "%s" "$out" | grep -q "copied=0 skipped_hot=0 errors=0"'

printf 'two-longer\n' > "$src/p/s2.jsonl"; old "$src/p/s2.jsonl"
out="$(run)"
check "re-copies on a size change" 'cmp -s "$src/p/s2.jsonl" "$D/claude/projects/s2.jsonl" && printf "%s" "$out" | grep -q "copied=1"'

touch -d '3 hours ago' "$D/claude/projects/a/s1.jsonl"; touch -d '1 hour ago' "$src/p/a/s1.jsonl"
out="$(run)"
check "re-copies when the source is newer at equal size" 'printf "%s" "$out" | grep -q "copied=1"'

printf 'hot\n' > "$src/p/hot.jsonl"
out="$(run)"
check "skips a file modified within 15 minutes" '[ ! -e "$D/claude/projects/hot.jsonl" ] && printf "%s" "$out" | grep -q "skipped_hot=1"'
out="$(run --hot-minutes 0)"
check "takes the hot file once it is no longer hot" '[ -e "$D/claude/projects/hot.jsonl" ]'

printf 'keep\n' > "$D/claude/projects/only-in-dest.jsonl"
rm -f "$src/p/s2.jsonl"
run >/dev/null
check "never deletes in the destination" '[ -e "$D/claude/projects/only-in-dest.jsonl" ] && [ -e "$D/claude/projects/s2.jsonl" ]'

# A source that grows during the copy: a cp wrapper appends to the source after copying.
mkdir -p "$work/bin"
cat > "$work/bin/cp" <<EOF
#!/bin/sh
/bin/cp "\$@"; rc=\$?
for a in "\$@"; do last="\$a"; done
case "\$*" in *grow.jsonl*) printf 'more\n' >> "$src/p/grow.jsonl" ;; esac
exit \$rc
EOF
chmod +x "$work/bin/cp"
printf 'g\n' > "$src/p/grow.jsonl"; old "$src/p/grow.jsonl"
PATH="$work/bin:$PATH" run >/dev/null
check "never leaves a wrong-size file outside .partial/" '[ ! -e "$D/claude/projects/grow.jsonl" ]'
check "discards the partial copy after the retry" '[ -z "$(find "$D/.partial" -type f 2>/dev/null)" ]'
bad=0
while IFS= read -r -d "" f; do
  rel="${f#"$D/claude/projects/"}"; [ "$rel" = only-in-dest.jsonl ] && continue
  [ -e "$src/p/$rel" ] || continue
  [ "$(stat -c %s "$f")" = "$(stat -c %s "$src/p/$rel")" ] || bad=1
done < <(find "$D/claude/projects" -type f -print0)
check "every copied file matches its source size" '[ "$bad" -eq 0 ]'

mkdir -p "$work/real/r"; printf 'linked\n' > "$work/real/r/l.jsonl"; old "$work/real/r/l.jsonl"
ln -s "$work/real" "$work/link"
bash "$up" --dropbox "$db" --host hostx --map "$work/link=codex/sessions" >/dev/null
check "follows the symlink target" 'cmp -s "$work/real/r/l.jsonl" "$D/codex/sessions/r/l.jsonl"'

check "missing Dropbox folder fails clearly" '! bash "$up" --dropbox "$work/nodb" --host hostx --map "$src/p=x" >/dev/null 2>&1'
check "rejects a host name that leaves chat_transcripts/" '! bash "$up" --dropbox "$db" --host .. --map "$src/p=x" >/dev/null 2>&1 && ! bash "$up" --dropbox "$db" --pull "a/b" --map none >/dev/null 2>&1'
check "rejects a --map destination with .. or an absolute path" '! bash "$up" --dropbox "$db" --host hostx --map "$src/p=../esc" >/dev/null 2>&1 && ! bash "$up" --dropbox "$db" --host hostx --map "$src/p=/abs" >/dev/null 2>&1 && [ ! -e "$db/ai/esc" ]'
check "missing source folder is not an error" 'bash "$up" --dropbox "$db" --host hostx --map "$work/absent=x" >/dev/null'

# Pull mode (hetz has no Dropbox): rsync from a local stand-in root.
mkdir -p "$work/remote/root/.claude/projects/q" "$work/remote/home/ai/.codex/sessions"
printf 'r\n' > "$work/remote/root/.claude/projects/q/r.jsonl"; printf 'h\n' > "$work/remote/home/ai/.codex/sessions/hot.jsonl"
old "$work/remote/root/.claude/projects/q/r.jsonl"
AI_TRANSCRIPT_PULL_LOCAL_ROOT="$work/remote" bash "$up" --dropbox "$db" --host hostx --map none --pull hetzx >/dev/null
H="$db/ai/chat_transcripts/hetzx"
check "pull copies into chat_transcripts/<pulled host>/root/..." 'cmp -s "$work/remote/root/.claude/projects/q/r.jsonl" "$H/root/claude/projects/q/r.jsonl"'
check "pull keeps the hot-file rule" '[ ! -e "$H/ai/codex/sessions/hot.jsonl" ] && grep -q "skipped_hot=1 errors=0" "$H/.upload-last.txt"'

# Install / check / remove through a recording systemctl stub.
mkdir -p "$work/stub"; printf '#!/bin/sh\necho "$*" >> "%s/systemctl.log"\n' "$work" > "$work/stub/systemctl"; chmod +x "$work/stub/systemctl"
export AI_TRANSCRIPT_UPLOAD_SYSTEMCTL="$work/stub/systemctl"
bash "$up" --install --with-pull hetz >/dev/null; check "install succeeds" '[ $? -eq 0 ]'
u="$XDG_CONFIG_HOME/systemd/user"
check "daily timer written and enabled" 'grep -q "^OnCalendar=\*-\*-\* 06:30:00" "$u/ai-transcript-upload.timer" && grep -q "enable --now ai-transcript-upload.timer" "$work/systemctl.log"'
check "service runs the installed copy and the hetz pull" 'grep -q "transcript-upload\"$" "$u/ai-transcript-upload.service" && grep -q -- "--pull hetz --map none" "$u/ai-transcript-upload.service"'
check "--check passes after install" 'bash "$up" --check >/dev/null'
inst="$XDG_CONFIG_HOME/ai-devops/transcript-upload"
bash "$up" --install >/dev/null
check "reinstall keeps the existing pull" 'grep -q -- "--pull hetz --map none" "$u/ai-transcript-upload.service"'
bash "$up" --sync >/dev/null
check "--sync on an installed host keeps the pull" 'grep -q -- "--pull hetz --map none" "$u/ai-transcript-upload.service"'
cp "$inst" "$work/inst.lf"; sed 's/$/\r/' "$work/inst.lf" > "$inst"
check "line endings alone are not stale" 'bash "$up" --check >/dev/null'
cp "$work/inst.lf" "$inst"

# Staleness and self-update against merged main.
printf '# merged change\n' >> "$main/bin/ai-transcript-upload"
out="$(bash "$inst" --check)"; rc=$?
check "--check reports a copy stale against main" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "stale"'
out="$(AI_TRANSCRIPT_UPLOAD_SOURCE="$work/nowhere" bash "$inst" --check)"; rc=$?
check "--check fails when main cannot be read" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q "unverified"'
bash "$inst" --dropbox "$db" --host hostx --map "$src/p=claude/projects" >/dev/null
check "a run updates the installed copy from main" 'cmp -s "$main/bin/ai-transcript-upload" "$inst"'
check "--check passes once updated" 'bash "$inst" --check >/dev/null'
cp "$inst" "$work/inst.keep"
printf 'if then fi (\n' >> "$main/bin/ai-transcript-upload"
bash "$inst" --dropbox "$db" --host hostx --map "$src/p=claude/projects" >/dev/null; rc=$?
check "a broken main is refused, the upload still runs and logs it" '[ "$rc" -eq 0 ] && cmp -s "$work/inst.keep" "$inst" && grep -q "self_update=failed" "$D/.upload-last.txt"'
cp "$work/inst.keep" "$main/bin/ai-transcript-upload"
bash "$up" --remove >/dev/null
out="$(HOME="$work/empty" XDG_CONFIG_HOME="$work/empty/.config" bash "$up" --sync)"
check "--sync skips a host with no Dropbox and no timer" 'printf "%s" "$out" | grep -q "^SKIP" && [ ! -e "$work/empty/.config/systemd" ]'
check "--check fails after remove" '! bash "$up" --check >/dev/null'

check "bash script has LF line endings" '! grep -q $'"'"'\r'"'"' "$up"'
check ".cmd launcher runs its own script" 'grep -q "\"%~dpn0\" %\*" "$here/../bin/ai-transcript-upload.cmd"'

# ZCode: the default map exports the sqlite sessions, then uploads the export.
if command -v python3 >/dev/null 2>&1; then
  zh="$work/zhome"; mkdir -p "$zh/.zcode/cli/db"; zd="$work/zdb"; mkdir -p "$zd/ai/chat_transcripts"
  python3 - "$zh/.zcode/cli/db/db.sqlite" <<'PY'
import json, sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.executescript("CREATE TABLE session (id, directory, parent_id); CREATE TABLE message (id, session_id, time_created, time_updated, data);"
                "CREATE TABLE part (id, message_id, session_id, time_created, data);")
c.execute("INSERT INTO session VALUES ('ses_1', '/repos/demo', NULL)")
c.execute("INSERT INTO message VALUES ('m1', 'ses_1', 1700000000000, 1700000000000, ?)", (json.dumps({"role": "user"}),))
c.execute("INSERT INTO part VALUES ('p1', 'm1', 'ses_1', 1700000000000, ?)", (json.dumps({"type": "text", "text": "synthetic question long enough to keep"}),))
c.commit()
PY
  HOME="$zh" AI_TRANSCRIPT_UPLOAD_STATE_DIR="$work/zstate" bash "$up" --dropbox "$zd" --host hostz >/dev/null
  check "ZCode sqlite sessions reach the upload folder" '[ -s "$zd/ai/chat_transcripts/hostz/zcode/sessions/ses_1.jsonl" ]'
  # Pull mode: hetz ZCode sessions are exported here from a copy of its database.
  mkdir -p "$work/remote/home/ai/.zcode/cli/db"; cp "$zh/.zcode/cli/db/db.sqlite" "$work/remote/home/ai/.zcode/cli/db/db.sqlite"
  AI_TRANSCRIPT_PULL_LOCAL_ROOT="$work/remote" bash "$up" --dropbox "$zd" --host hostz --map none --pull hetzz >/dev/null
  zp="$zd/ai/chat_transcripts/hetzz"
  check "pull uploads the other host's ZCode sessions" '[ -s "$zp/ai/zcode/sessions/ses_1.jsonl" ] && grep -q "errors=0" "$zp/.upload-last.txt"'
  check "pull with no ZCode under one account is not an error" '[ ! -e "$zp/root/zcode" ]'
  check "ZCode database itself is not uploaded" '[ -z "$(find "$zd" -name "*.sqlite")" ]'
  # MiMo: same tables, its own database and folder.
  mkdir -p "$zh/.local/share/mimocode"; cp "$zh/.zcode/cli/db/db.sqlite" "$zh/.local/share/mimocode/mimocode.db"
  HOME="$zh" AI_TRANSCRIPT_UPLOAD_STATE_DIR="$work/zstate" bash "$up" --dropbox "$zd" --host hostz >/dev/null
  check "MiMo sqlite sessions reach the upload folder" '[ -s "$zd/ai/chat_transcripts/hostz/mimo/sessions/ses_1.jsonl" ]'
  check "MiMo database itself is not uploaded" '[ -z "$(find "$zd" -name "*.db")" ]'
  printf 'not a database
' > "$zh/.local/share/mimocode/mimocode.db"
  check "a failed MiMo export reports an error" '! HOME="$zh" AI_TRANSCRIPT_UPLOAD_STATE_DIR="$work/zstate" bash "$up" --dropbox "$zd" --host hostz >/dev/null'
  rm -f "$zh/.local/share/mimocode/mimocode.db"
  printf 'not a database
' > "$zh/.zcode/cli/db/db.sqlite"
  check "a failed ZCode export reports an error" '! HOME="$zh" AI_TRANSCRIPT_UPLOAD_STATE_DIR="$work/zstate" bash "$up" --dropbox "$zd" --host hostz >/dev/null'
else
  skip "ZCode export checks" "python3 not installed"
fi

check "ps1 exports the MiMo database" 'grep -Fq ".local\share\mimocode\mimocode.db" "$here/../bin/ai-transcript-upload.ps1"'
check "ps1 names the checkout exporter path" 'grep -Fq "tools\transcript_store\zcode_export.py" "$here/../bin/ai-transcript-upload.ps1"'

# Windows twin, when PowerShell is available (CI Linux runners may lack it).
if command -v pwsh >/dev/null 2>&1; then
  wsrc="$work/wsrc"; mkdir -p "$wsrc/a" "$work/lad"; printf 'w\n' > "$wsrc/a/w.jsonl"; old "$wsrc/a/w.jsonl"
  printf 'wh\n' > "$wsrc/hot.jsonl"
  wdb="$work/wdb"; mkdir -p "$wdb/ai/chat_transcripts"
  ln -s "$wsrc" "$work/wlink"
  LOCALAPPDATA="$work/lad" pwsh -NoProfile -File "$here/../bin/ai-transcript-upload.ps1" -DropboxRoot "$wdb" -HostName hostw -Map "$work/wlink=claude/projects" >/dev/null 2>&1
  W="$wdb/ai/chat_transcripts/hostw"
  check "ps1: copies through the symlink target" 'cmp -s "$wsrc/a/w.jsonl" "$W/claude/projects/a/w.jsonl"'
  check "ps1: skips the hot file and logs 0 errors" '[ ! -e "$W/claude/projects/hot.jsonl" ] && grep -Eq "E[DS]T host=hostw scanned=2 copied=1 skipped_hot=1 errors=0" "$W/.upload-last.txt"'
  printf 'keep\n' > "$W/claude/projects/dest-only.jsonl"
  out="$(LOCALAPPDATA="$work/lad" pwsh -NoProfile -File "$here/../bin/ai-transcript-upload.ps1" -DropboxRoot "$wdb" -HostName hostw -Map "$work/wlink=claude/projects" 2>&1)"
  check "ps1: skips identical and never deletes" 'printf "%s" "$out" | grep -q "copied=0" && [ -e "$W/claude/projects/dest-only.jsonl" ]'
  check "ps1: rejects an unsafe -Map destination" '! LOCALAPPDATA="$work/lad" pwsh -NoProfile -File "$here/../bin/ai-transcript-upload.ps1" -DropboxRoot "$wdb" -HostName hostw -Map "$work/wlink=../esc" >/dev/null 2>&1 && [ ! -e "$wdb/ai/esc" ]'
  # Self-update of the installed copy against the main stand-in.
  wla="$work/wlad"; mkdir -p "$wla/ai-devops"; ps1main="$main/bin/ai-transcript-upload.ps1"
  { cat "$here/../bin/ai-transcript-upload.ps1"; printf '# merged change
'; } > "$ps1main"
  cp "$here/../bin/ai-transcript-upload.ps1" "$wla/ai-devops/ai-transcript-upload.ps1"
  cp "$here/../tools/transcript_store/zcode_export.py" "$wla/ai-devops/zcode_export.py"
  LOCALAPPDATA="$wla" pwsh -NoProfile -File "$wla/ai-devops/ai-transcript-upload.ps1" -DropboxRoot "$wdb" -HostName hostw -Map "$work/wlink=claude/projects" >/dev/null 2>&1
  check "ps1: a run updates the installed copy from main" 'cmp -s "$ps1main" "$wla/ai-devops/ai-transcript-upload.ps1" && grep -q "errors=0$" "$W/.upload-last.txt"'
  printf 'function {
' >> "$ps1main"
  LOCALAPPDATA="$wla" pwsh -NoProfile -File "$wla/ai-devops/ai-transcript-upload.ps1" -DropboxRoot "$wdb" -HostName hostw -Map "$work/wlink=claude/projects" >/dev/null 2>&1
  check "ps1: a broken main is refused and logged" '! grep -q "^function {" "$wla/ai-devops/ai-transcript-upload.ps1" && grep -q "self_update=failed" "$W/.upload-last.txt"'
else
  skip "ps1 checks" "pwsh not installed"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
